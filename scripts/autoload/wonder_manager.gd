extends Node

## 奇观运行时管理器
## - 记录归属
## - 国家级效果汇总
## - 最小建造竞赛：多势力可同时开工，先完工者获得

var _wonder_owners: Dictionary = {}
var _build_projects: Array = []  # [{wonder_id, faction_id, turns_left, city_id}]


func _ready() -> void:
	SignalBus.turn_started.connect(_on_turn_started)


func reset() -> void:
	_wonder_owners.clear()
	_build_projects.clear()


func _on_turn_started(_turn_number: int, faction_id: String) -> void:
	tick_build_projects(faction_id)


func set_wonder_owner(wonder_id: String, faction_id: String) -> bool:
	if DataManager.get_wonder(wonder_id).is_empty():
		return false
	if faction_id != "" and faction_id != "neutral" and DataManager.get_faction(faction_id).is_empty():
		return false
	if faction_id == "" or faction_id == "neutral":
		_wonder_owners.erase(wonder_id)
	else:
		_wonder_owners[wonder_id] = faction_id
	return true


func get_wonder_owner(wonder_id: String) -> String:
	return str(_wonder_owners.get(wonder_id, ""))


func get_faction_wonders(faction_id: String) -> Array[String]:
	var result: Array[String] = []
	for wonder_id in _wonder_owners:
		if str(_wonder_owners[wonder_id]) == faction_id:
			result.append(str(wonder_id))
	return result


func has_wonder(faction_id: String, wonder_id: String) -> bool:
	return get_wonder_owner(wonder_id) == faction_id


func get_effect_float(faction_id: String, effect_key: String) -> float:
	var total: float = 0.0
	for wonder_id in get_faction_wonders(faction_id):
		var wonder: Dictionary = DataManager.get_wonder(wonder_id)
		if wonder.is_empty():
			continue
		var effects: Dictionary = wonder.get("effects", {})
		total += float(effects.get(effect_key, 0.0))
	return total


func get_effect_int(faction_id: String, effect_key: String) -> int:
	return int(round(get_effect_float(faction_id, effect_key)))


func get_owned_wonders() -> Dictionary:
	return _wonder_owners.duplicate(true)


## 开始建造奇观。成功则扣资源并入队。
func start_build_wonder(faction_id: String, wonder_id: String, city_id: String = "") -> Dictionary:
	var wonder: Dictionary = DataManager.get_wonder(wonder_id)
	if wonder.is_empty():
		return {"success": false, "reason": "INVALID_WONDER"}
	if get_wonder_owner(wonder_id) != "":
		return {"success": false, "reason": "ALREADY_BUILT"}
	for project: Dictionary in _build_projects:
		if str(project.get("wonder_id", "")) == wonder_id and str(project.get("faction_id", "")) == faction_id:
			return {"success": false, "reason": "ALREADY_BUILDING"}
	var gold: int = int(wonder.get("cost_gold", 0))
	var wood: int = int(wonder.get("cost_wood", 0))
	var materials: int = int(wonder.get("cost_building_materials", 0))
	if GameManager.get_faction_resource(faction_id, "gold") < gold \
		or GameManager.get_faction_resource(faction_id, "wood") < wood \
		or GameManager.get_faction_resource(faction_id, "building_materials") < materials:
		return {"success": false, "reason": "INSUFFICIENT_RESOURCES"}
	GameManager.apply_faction_resource_delta(faction_id, "gold", -gold)
	GameManager.apply_faction_resource_delta(faction_id, "wood", -wood)
	GameManager.apply_faction_resource_delta(faction_id, "building_materials", -materials)
	var turns: int = int(wonder.get("build_turns", 20))
	if wonder.get("wonder_type", "") == "map":
		turns = maxi(1, int(wonder.get("map_length", 10)) * 2)
	_build_projects.append({
		"wonder_id": wonder_id,
		"faction_id": faction_id,
		"turns_left": turns,
		"city_id": city_id,
	})
	SignalBus.diplomacy_action_performed.emit("wonder_build_started", faction_id, wonder_id)
	return {"success": true, "turns_left": turns}


func get_build_projects() -> Array:
	return _build_projects.duplicate(true)


func tick_build_projects(faction_id: String) -> void:
	var remaining: Array = []
	for project_v in _build_projects:
		var project: Dictionary = (project_v as Dictionary).duplicate(true)
		if str(project.get("faction_id", "")) != faction_id:
			remaining.append(project)
			continue
		if get_wonder_owner(str(project.get("wonder_id", ""))) != "":
			# 已被他人抢先建成，退还一半资源
			_refund_half(faction_id, str(project.get("wonder_id", "")))
			continue
		project["turns_left"] = int(project.get("turns_left", 1)) - 1
		if int(project.get("turns_left", 0)) <= 0:
			set_wonder_owner(str(project.get("wonder_id", "")), faction_id)
			SignalBus.diplomacy_action_performed.emit("wonder_completed", faction_id, str(project.get("wonder_id", "")))
			continue
		remaining.append(project)
	_build_projects = remaining


func _refund_half(faction_id: String, wonder_id: String) -> void:
	var wonder: Dictionary = DataManager.get_wonder(wonder_id)
	if wonder.is_empty():
		return
	GameManager.apply_faction_resource_delta(faction_id, "gold", int(wonder.get("cost_gold", 0)) / 2)
	GameManager.apply_faction_resource_delta(faction_id, "wood", int(wonder.get("cost_wood", 0)) / 2)
	GameManager.apply_faction_resource_delta(faction_id, "building_materials", int(wonder.get("cost_building_materials", 0)) / 2)


func get_save_data() -> Dictionary:
	return {
		"wonder_owners": _wonder_owners.duplicate(true),
		"build_projects": _build_projects.duplicate(true),
	}


func load_save_data(data: Dictionary) -> void:
	var owners: Variant = data.get("wonder_owners", {})
	if owners is Dictionary:
		_wonder_owners = (owners as Dictionary).duplicate(true)
	else:
		_wonder_owners.clear()
	var projects: Variant = data.get("build_projects", [])
	if projects is Array:
		_build_projects = (projects as Array).duplicate(true)
	else:
		_build_projects.clear()
