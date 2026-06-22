extends Node

## 大夫管理器（最小经营闭环）
##
## 当前只实现文大夫：
## - 开局为各激活势力初始化 1 名文大夫
## - 自动派驻到首都
## - 提供城市经营/安定/减腐查询接口
## - 城破时处理驻城文大夫命运，避免残留错误驻城状态

var _civil_ministers_by_faction: Dictionary = {}
var _city_assignments: Dictionary = {}
var _minister_index: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	reset()


func reset() -> void:
	_civil_ministers_by_faction.clear()
	_city_assignments.clear()
	_minister_index.clear()


func get_save_data() -> Dictionary:
	return {
		"civil_ministers_by_faction": _civil_ministers_by_faction.duplicate(true),
		"city_assignments": _city_assignments.duplicate(true),
		"minister_index": _minister_index.duplicate(true),
	}


func load_save_data(data: Dictionary) -> void:
	var civil_states: Variant = data.get("civil_ministers_by_faction", {})
	var city_assignments: Variant = data.get("city_assignments", {})
	var minister_index: Variant = data.get("minister_index", {})
	if civil_states is Dictionary:
		_civil_ministers_by_faction = (civil_states as Dictionary).duplicate(true)
	else:
		_civil_ministers_by_faction.clear()
	if city_assignments is Dictionary:
		_city_assignments = (city_assignments as Dictionary).duplicate(true)
	else:
		_city_assignments.clear()
	if minister_index is Dictionary:
		_minister_index = (minister_index as Dictionary).duplicate(true)
	else:
		_minister_index.clear()


func initialize_factions(active_factions: Array[String]) -> void:
	reset()
	var used_source_ids: Dictionary = {}
	var civil_capacity: int = int(DataManager.get_balance_param("minister.capacity.civil"))
	for faction_id in active_factions:
		_civil_ministers_by_faction[faction_id] = []
		if civil_capacity <= 0:
			continue
		var minister: Dictionary = _create_initial_civil_minister(faction_id, used_source_ids)
		if minister.is_empty():
			continue
		var minister_id: String = str(minister.get("id", ""))
		_minister_index[minister_id] = minister
		(_civil_ministers_by_faction[faction_id] as Array).append(minister_id)
		var capital: Dictionary = CityManager.get_capital_state(faction_id)
		if not capital.is_empty():
			assign_civil_minister(str(capital.get("id", "")), minister_id)


func get_faction_civil_ministers(faction_id: String) -> Array:
	var result: Array = []
	for minister_id in _civil_ministers_by_faction.get(faction_id, []):
		var minister: Dictionary = get_minister(str(minister_id))
		if not minister.is_empty():
			result.append(minister)
	return result


func get_minister(minister_id: String) -> Dictionary:
	if not _minister_index.has(minister_id):
		return {}
	return (_minister_index[minister_id] as Dictionary).duplicate(true)


func get_city_civil_minister(city_id: String) -> Dictionary:
	var minister: Dictionary = _get_city_civil_minister_ref(city_id)
	if minister.is_empty():
		return {}
	return minister.duplicate(true)


func assign_civil_minister(city_id: String, minister_id: String) -> bool:
	var city: Dictionary = CityManager.get_city_state(city_id)
	if city.is_empty():
		return false
	if not _minister_index.has(minister_id):
		return false
	var minister: Dictionary = _minister_index[minister_id]
	if str(minister.get("type", "")) != "civil":
		return false
	if str(minister.get("faction_id", "")) != str(city.get("current_faction_id", "")):
		return false
	var status: String = str(minister.get("status", "idle"))
	if status == "dead" or status == "captured" or status == "hostage":
		return false
	var previous_city_id: String = str(minister.get("assigned_city_id", ""))
	if previous_city_id != "":
		_city_assignments.erase(previous_city_id)
	var existing_minister_id: String = str(_city_assignments.get(city_id, ""))
	if existing_minister_id != "" and _minister_index.has(existing_minister_id):
		var existing_minister: Dictionary = _minister_index[existing_minister_id]
		existing_minister["assigned_city_id"] = ""
		existing_minister["status"] = "idle"
	_city_assignments[city_id] = minister_id
	minister["assigned_city_id"] = city_id
	minister["status"] = "assigned"
	return true


func remove_civil_minister_from_city(city_id: String) -> void:
	var minister_id: String = str(_city_assignments.get(city_id, ""))
	if minister_id == "":
		return
	_city_assignments.erase(city_id)
	if not _minister_index.has(minister_id):
		return
	var minister: Dictionary = _minister_index[minister_id]
	minister["assigned_city_id"] = ""
	if str(minister.get("status", "")) == "assigned":
		minister["status"] = "idle"


func get_city_gold_bonus(city_id: String) -> float:
	var minister: Dictionary = _get_city_civil_minister_ref(city_id)
	if minister.is_empty():
		return 0.0
	var stats: Dictionary = minister.get("stats", {})
	return float(stats.get("理财", 0)) / 100.0


func get_city_stability_bonus(city_id: String) -> int:
	var minister: Dictionary = _get_city_civil_minister_ref(city_id)
	if minister.is_empty():
		return 0
	var stats: Dictionary = minister.get("stats", {})
	return int(stats.get("安民", 0))


func get_city_food_flat_bonus(city_id: String) -> int:
	return int(round(_get_city_skill_value(city_id, "劝农")))


func get_city_gold_flat_bonus(city_id: String) -> int:
	return int(round(_get_city_skill_value(city_id, "兴商")))


func get_city_output_bonus(city_id: String) -> float:
	return _get_city_skill_value(city_id, "变法")


func get_city_stability_regen_bonus(city_id: String) -> int:
	return int(round(_get_city_skill_value(city_id, "教化")))


func get_faction_corruption_reduction(faction_id: String) -> float:
	var total: float = 0.0
	for minister_id in _civil_ministers_by_faction.get(faction_id, []):
		var minister: Dictionary = _minister_index.get(str(minister_id), {})
		if minister.is_empty():
			continue
		if str(minister.get("assigned_city_id", "")) == "":
			continue
		var value: float = _get_skill_value(minister, "肃贪")
		if value < 0.0:
			total += -value
		else:
			total += value
	return total


func handle_city_lost(city_id: String, old_faction: String, new_faction: String) -> void:
	var minister_id: String = str(_city_assignments.get(city_id, ""))
	if minister_id == "":
		return
	remove_civil_minister_from_city(city_id)
	if not _minister_index.has(minister_id):
		return
	var minister: Dictionary = _minister_index[minister_id]
	if str(minister.get("faction_id", "")) != old_faction:
		return
	var fate_cfg: Dictionary = DataManager.get_balance_param("minister.fate")
	var roll: float = _rng.randf()
	var death_chance: float = float(fate_cfg.get("death_chance", 0.0))
	var capture_chance: float = float(fate_cfg.get("capture_chance", 0.0))
	if roll < death_chance:
		minister["status"] = "dead"
		minister["captured_by"] = ""
	elif roll < death_chance + capture_chance:
		minister["status"] = "captured"
		minister["captured_by"] = new_faction if new_faction != "neutral" else ""
		DiplomacySystem.add_prisoner(old_faction, minister_id)
	else:
		minister["status"] = "idle"
		minister["captured_by"] = ""


func send_minister_hostage(minister_id: String, receiver_faction: String) -> bool:
	if not _minister_index.has(minister_id):
		return false
	var minister: Dictionary = _minister_index[minister_id]
	var status: String = str(minister.get("status", "idle"))
	if status == "dead" or status == "captured":
		return false
	var assigned_city_id: String = str(minister.get("assigned_city_id", ""))
	if assigned_city_id != "":
		_city_assignments.erase(assigned_city_id)
		minister["assigned_city_id"] = ""
	minister["status"] = "hostage"
	minister["captured_by"] = receiver_faction
	return true


func release_minister_hostage(minister_id: String) -> bool:
	if not _minister_index.has(minister_id):
		return false
	var minister: Dictionary = _minister_index[minister_id]
	minister["status"] = "idle"
	minister["captured_by"] = ""
	return true


func _create_initial_civil_minister(faction_id: String, used_source_ids: Dictionary) -> Dictionary:
	var selected: Dictionary = _select_civil_template(faction_id, used_source_ids)
	if selected.is_empty():
		return {}
	var template: Dictionary = selected.get("template", {})
	var quality: String = str(selected.get("quality", "common"))
	var source_id: String = str(template.get("id", ""))
	used_source_ids[source_id] = true
	var minister_id: String = "%s__%s" % [faction_id, source_id]
	var skills: Array = []
	for skill in template.get("skills", []):
		skills.append(str(skill))
	var skill_levels: Dictionary = {}
	for skill_id in skills:
		skill_levels[skill_id] = 1
	return {
		"id": minister_id,
		"source_id": source_id,
		"type": "civil",
		"name": _resolve_minister_name(template),
		"school": template.get("school", null),
		"quality": quality,
		"faction_id": faction_id,
		"stats": {
			"理财": _resolve_stat_value(template.get("base_stats", {}).get("理财", 0), quality),
			"安民": _resolve_stat_value(template.get("base_stats", {}).get("安民", 0), quality),
		},
		"skills": skills,
		"skill_levels": skill_levels,
		"assigned_city_id": "",
		"status": "idle",
		"captured_by": "",
	}


func _select_civil_template(faction_id: String, used_source_ids: Dictionary) -> Dictionary:
	var minister_pool: Dictionary = DataManager.get_minister_pool()
	var civil_pool: Dictionary = minister_pool.get("civil", {})
	var quality_order: Array[String] = ["rare", "legendary", "common"]
	var school_id: String = SchoolManager.get_current_school(faction_id)
	for quality in quality_order:
		for candidate in civil_pool.get(quality, []):
			var template: Dictionary = candidate as Dictionary
			if used_source_ids.has(str(template.get("id", ""))):
				continue
			if str(template.get("school", "")) == school_id and bool(template.get("is_historical", false)):
				return {"template": template, "quality": quality}
	for quality in quality_order:
		for candidate in civil_pool.get(quality, []):
			var template: Dictionary = candidate as Dictionary
			if used_source_ids.has(str(template.get("id", ""))):
				continue
			if bool(template.get("is_historical", false)):
				return {"template": template, "quality": quality}
	for quality in quality_order:
		for candidate in civil_pool.get(quality, []):
			var template: Dictionary = candidate as Dictionary
			if used_source_ids.has(str(template.get("id", ""))):
				continue
			return {"template": template, "quality": quality}
	return {}


func _resolve_minister_name(template: Dictionary) -> String:
	if template.has("name"):
		return str(template.get("name", ""))
	var surnames: Array = DataManager.get_minister_pool().get("surnames", [])
	var given_names: Array = DataManager.get_minister_pool().get("given_names", [])
	if surnames.is_empty() or given_names.is_empty():
		return "文大夫"
	var surname: String = str(surnames[_rng.randi_range(0, surnames.size() - 1)])
	var given_name: String = str(given_names[_rng.randi_range(0, given_names.size() - 1)])
	return "%s%s" % [surname, given_name]


func _resolve_stat_value(source: Variant, quality: String) -> int:
	if source is int or source is float:
		return int(source)
	if source is Array and (source as Array).size() >= 2:
		var values: Array = source as Array
		return _rng.randi_range(int(values[0]), int(values[1]))
	var ranges: Dictionary = DataManager.get_balance_param("minister.stat_ranges")
	var range_cfg: Dictionary = ranges.get(quality, {})
	return _rng.randi_range(int(range_cfg.get("min", 10)), int(range_cfg.get("max", 50)))


func _get_city_civil_minister_ref(city_id: String) -> Dictionary:
	var minister_id: String = str(_city_assignments.get(city_id, ""))
	if minister_id == "":
		return {}
	return _minister_index.get(minister_id, {})


func _get_city_skill_value(city_id: String, skill_id: String) -> float:
	var minister: Dictionary = _get_city_civil_minister_ref(city_id)
	if minister.is_empty():
		return 0.0
	return _get_skill_value(minister, skill_id)


func _get_skill_value(minister: Dictionary, skill_id: String) -> float:
	var skills: Array = minister.get("skills", [])
	if not skills.has(skill_id):
		return 0.0
	var skill_levels: Dictionary = minister.get("skill_levels", {})
	var skill_level: int = int(skill_levels.get(skill_id, 1))
	var civil_skill_cfg: Dictionary = DataManager.get_balance_param("minister.skills.civil")
	var skill_cfg: Dictionary = civil_skill_cfg.get(skill_id, {})
	var values: Array = skill_cfg.get("values", [])
	if values.is_empty():
		return 0.0
	var index: int = clampi(skill_level - 1, 0, values.size() - 1)
	return float(values[index])
