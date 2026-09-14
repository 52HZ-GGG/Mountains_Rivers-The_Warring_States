extends Node

## 大夫管理器
## - 文大夫：城市经营/安定/减腐
## - 武大夫：首都驻防，提供攻防加成
## - 外交大夫：派驻目标国，提供好感/降成本

var _civil_ministers_by_faction: Dictionary = {}
var _military_ministers_by_faction: Dictionary = {}
var _diplomat_ministers_by_faction: Dictionary = {}
var _city_assignments: Dictionary = {}
var _diplomat_assignments: Dictionary = {}  # minister_id -> target_faction_id
var _minister_index: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	reset()


func reset() -> void:
	_civil_ministers_by_faction.clear()
	_military_ministers_by_faction.clear()
	_diplomat_ministers_by_faction.clear()
	_city_assignments.clear()
	_diplomat_assignments.clear()
	_minister_index.clear()


## 战斗胜利/占城时尝试招募武大夫
func try_acquire_military_minister(faction_id: String) -> Dictionary:
	var capacity: int = int(DataManager.get_balance_param("minister.capacity.military"))
	var current: int = (_military_ministers_by_faction.get(faction_id, []) as Array).size()
	if current >= capacity:
		return {"success": false, "reason": "CAPACITY_FULL"}
	var chance: float = float(DataManager.get_balance_param("minister.acquisition.battle_win_chance"))
	if _rng.randf() > chance:
		return {"success": false, "reason": "NO_ROLL"}
	if not _military_ministers_by_faction.has(faction_id):
		_military_ministers_by_faction[faction_id] = []
	var minister: Dictionary = _create_initial_military_minister(faction_id, {})
	if minister.is_empty():
		return {"success": false, "reason": "CREATE_FAILED"}
	var mid: String = str(minister.get("id", ""))
	_minister_index[mid] = minister
	(_military_ministers_by_faction[faction_id] as Array).append(mid)
	return {"success": true, "minister": minister, "minister_id": mid}


## 外交行动成功时尝试招募外交大夫
func try_acquire_diplomat_minister(faction_id: String) -> Dictionary:
	var capacity: int = int(DataManager.get_balance_param("minister.capacity.diplomat"))
	var current: int = (_diplomat_ministers_by_faction.get(faction_id, []) as Array).size()
	if current >= capacity:
		return {"success": false, "reason": "CAPACITY_FULL"}
	var chance: float = float(DataManager.get_balance_param("minister.acquisition.diplomacy_action_chance"))
	if _rng.randf() > chance:
		return {"success": false, "reason": "NO_ROLL"}
	if not _diplomat_ministers_by_faction.has(faction_id):
		_diplomat_ministers_by_faction[faction_id] = []
	var minister: Dictionary = _create_initial_diplomat_minister(faction_id, {})
	if minister.is_empty():
		return {"success": false, "reason": "CREATE_FAILED"}
	var did: String = str(minister.get("id", ""))
	_minister_index[did] = minister
	(_diplomat_ministers_by_faction[faction_id] as Array).append(did)
	return {"success": true, "minister": minister, "minister_id": did}


func get_save_data() -> Dictionary:
	return {
		"civil_ministers_by_faction": _civil_ministers_by_faction.duplicate(true),
		"military_ministers_by_faction": _military_ministers_by_faction.duplicate(true),
		"diplomat_ministers_by_faction": _diplomat_ministers_by_faction.duplicate(true),
		"city_assignments": _city_assignments.duplicate(true),
		"diplomat_assignments": _diplomat_assignments.duplicate(true),
		"minister_index": _minister_index.duplicate(true),
	}


func load_save_data(data: Dictionary) -> void:
	_civil_ministers_by_faction = _load_dict(data, "civil_ministers_by_faction")
	_military_ministers_by_faction = _load_dict(data, "military_ministers_by_faction")
	_diplomat_ministers_by_faction = _load_dict(data, "diplomat_ministers_by_faction")
	_city_assignments = _load_dict(data, "city_assignments")
	_diplomat_assignments = _load_dict(data, "diplomat_assignments")
	_minister_index = _load_dict(data, "minister_index")


func _load_dict(data: Dictionary, key: String) -> Dictionary:
	var v: Variant = data.get(key, {})
	return (v as Dictionary).duplicate(true) if v is Dictionary else {}


func initialize_factions(active_factions: Array[String]) -> void:
	reset()
	var used_source_ids: Dictionary = {}
	var civil_capacity: int = int(DataManager.get_balance_param("minister.capacity.civil"))
	var military_capacity: int = int(DataManager.get_balance_param("minister.capacity.military"))
	var diplomat_capacity: int = int(DataManager.get_balance_param("minister.capacity.diplomat"))
	for faction_id in active_factions:
		_civil_ministers_by_faction[faction_id] = []
		_military_ministers_by_faction[faction_id] = []
		_diplomat_ministers_by_faction[faction_id] = []
		if civil_capacity > 0:
			var minister: Dictionary = _create_initial_civil_minister(faction_id, used_source_ids)
			if not minister.is_empty():
				var minister_id: String = str(minister.get("id", ""))
				_minister_index[minister_id] = minister
				(_civil_ministers_by_faction[faction_id] as Array).append(minister_id)
				var capital: Dictionary = CityManager.get_capital_state(faction_id)
				if not capital.is_empty():
					assign_civil_minister(str(capital.get("id", "")), minister_id)
		if military_capacity > 0:
			var mmin: Dictionary = _create_initial_military_minister(faction_id, used_source_ids)
			if not mmin.is_empty():
				var mid: String = str(mmin.get("id", ""))
				_minister_index[mid] = mmin
				(_military_ministers_by_faction[faction_id] as Array).append(mid)
		if diplomat_capacity > 0:
			var dmin: Dictionary = _create_initial_diplomat_minister(faction_id, used_source_ids)
			if not dmin.is_empty():
				var did: String = str(dmin.get("id", ""))
				_minister_index[did] = dmin
				(_diplomat_ministers_by_faction[faction_id] as Array).append(did)


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


# ============= 武大夫 =============

func get_faction_military_ministers(faction_id: String) -> Array:
	var result: Array = []
	for minister_id in _military_ministers_by_faction.get(faction_id, []):
		var minister: Dictionary = get_minister(str(minister_id))
		if not minister.is_empty():
			result.append(minister)
	return result


func get_faction_military_attack_bonus(faction_id: String) -> float:
	return _sum_stat_pct(_military_ministers_by_faction.get(faction_id, []), "勇武")


func get_faction_military_defense_bonus(faction_id: String) -> float:
	return _sum_stat_pct(_military_ministers_by_faction.get(faction_id, []), "韬略")


func _sum_stat_pct(minister_ids: Array, stat_name: String) -> float:
	var total: float = 0.0
	for minister_id in minister_ids:
		var minister: Dictionary = _minister_index.get(str(minister_id), {})
		if minister.is_empty():
			continue
		if str(minister.get("status", "")) == "dead" or str(minister.get("status", "")) == "captured":
			continue
		var stats: Dictionary = minister.get("stats", {})
		total += float(stats.get(stat_name, 0)) / 100.0
	return total


# ============= 外交大夫 =============

func get_faction_diplomat_ministers(faction_id: String) -> Array:
	var result: Array = []
	for minister_id in _diplomat_ministers_by_faction.get(faction_id, []):
		var minister: Dictionary = get_minister(str(minister_id))
		if not minister.is_empty():
			result.append(minister)
	return result


func assign_diplomat_to_faction(minister_id: String, target_faction_id: String) -> bool:
	if not _minister_index.has(minister_id):
		return false
	var minister: Dictionary = _minister_index[minister_id]
	if str(minister.get("type", "")) != "diplomat":
		return false
	if str(minister.get("faction_id", "")) == target_faction_id:
		return false
	if str(minister.get("status", "")) in ["dead", "captured", "hostage"]:
		return false
	_diplomat_assignments[minister_id] = target_faction_id
	minister["status"] = "assigned"
	minister["assigned_faction_id"] = target_faction_id
	return true


func get_diplomat_cost_reduction(actor: String, target: String) -> float:
	for minister_id in _diplomat_ministers_by_faction.get(actor, []):
		if str(_diplomat_assignments.get(str(minister_id), "")) != target:
			continue
		var minister: Dictionary = _minister_index.get(str(minister_id), {})
		if minister.is_empty():
			continue
		var stats: Dictionary = minister.get("stats", {})
		return clampf(float(stats.get("辩才", 0)) / 100.0, 0.0, 0.5)
	return 0.0


func get_diplomat_opinion_gain(actor: String, target: String) -> float:
	for minister_id in _diplomat_ministers_by_faction.get(actor, []):
		if str(_diplomat_assignments.get(str(minister_id), "")) != target:
			continue
		var minister: Dictionary = _minister_index.get(str(minister_id), {})
		if minister.is_empty():
			continue
		var stats: Dictionary = minister.get("stats", {})
		return float(stats.get("亲和", 0)) / 10.0
	return 0.0


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


func _create_initial_military_minister(faction_id: String, used_source_ids: Dictionary) -> Dictionary:
	var pool: Dictionary = DataManager.get_minister_pool()
	var military_pool: Dictionary = pool.get("military", {})
	var quality_order: Array[String] = ["legendary", "rare", "common"]
	var template: Dictionary = {}
	var quality: String = "common"
	for q in quality_order:
		var list: Array = military_pool.get(q, []) as Array
		if list.is_empty():
			continue
		for candidate in list:
			var t: Dictionary = candidate as Dictionary
			if used_source_ids.has(str(t.get("id", ""))):
				continue
			template = t
			quality = q
			break
		if not template.is_empty():
			break
	if template.is_empty():
		template = {"id": "military_template", "name": "武大夫", "base_stats": {"勇武": [15, 40], "韬略": [10, 35]}}
	var source_id: String = str(template.get("id", "military_template"))
	used_source_ids[source_id] = true
	return {
		"id": "%s__%s" % [faction_id, source_id],
		"source_id": source_id,
		"type": "military",
		"name": _resolve_minister_name(template),
		"school": template.get("school", null),
		"quality": quality,
		"faction_id": faction_id,
		"stats": {
			"勇武": _resolve_stat_value(template.get("base_stats", {}).get("勇武", [15, 40]), quality),
			"韬略": _resolve_stat_value(template.get("base_stats", {}).get("韬略", [10, 35]), quality),
		},
		"skills": [],
		"skill_levels": {},
		"assigned_city_id": "",
		"status": "idle",
		"captured_by": "",
	}


func _create_initial_diplomat_minister(faction_id: String, used_source_ids: Dictionary) -> Dictionary:
	var pool: Dictionary = DataManager.get_minister_pool()
	var diplomat_pool: Dictionary = pool.get("diplomat", {})
	var quality_order: Array[String] = ["legendary", "rare", "common"]
	var template: Dictionary = {}
	var quality: String = "common"
	for q in quality_order:
		var list: Array = diplomat_pool.get(q, []) as Array
		if list.is_empty():
			continue
		for candidate in list:
			var t: Dictionary = candidate as Dictionary
			if used_source_ids.has(str(t.get("id", ""))):
				continue
			template = t
			quality = q
			break
		if not template.is_empty():
			break
	if template.is_empty():
		template = {"id": "diplomat_template", "name": "外交大夫", "base_stats": {"辩才": [10, 40], "亲和": [10, 35]}}
	var source_id: String = str(template.get("id", "diplomat_template"))
	used_source_ids[source_id] = true
	return {
		"id": "%s__%s" % [faction_id, source_id],
		"source_id": source_id,
		"type": "diplomat",
		"name": _resolve_minister_name(template),
		"school": template.get("school", null),
		"quality": quality,
		"faction_id": faction_id,
		"stats": {
			"辩才": _resolve_stat_value(template.get("base_stats", {}).get("辩才", [10, 40]), quality),
			"亲和": _resolve_stat_value(template.get("base_stats", {}).get("亲和", [10, 35]), quality),
		},
		"skills": [],
		"skill_levels": {},
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
