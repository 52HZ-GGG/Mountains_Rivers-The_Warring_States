extends Node

## 单槽完整存档管理器。
## 汇总 GameManager / CityManager / Diplomacy / Tech / School / Minister / Wonder / Event / Demo。

const SAVE_PATH: String = "user://shanhece_save_slot0.json"
const SCHEMA_VERSION: int = 2


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func get_save_path() -> String:
	return SAVE_PATH


func quick_save() -> Dictionary:
	var data: Dictionary = build_save_data()
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return {"success": false, "reason": "WRITE_FAILED", "path": SAVE_PATH}
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return {"success": true, "path": SAVE_PATH, "turn": int(data.get("turn", 0))}


func quick_load() -> Dictionary:
	var data: Dictionary = read_save_file()
	if data.is_empty():
		return {"success": false, "reason": "NO_SAVE"}
	var err: String = apply_save_data(data)
	if err != "":
		return {"success": false, "reason": err}
	return {
		"success": true,
		"turn": GameManager.get_current_turn(),
		"player_faction": GameManager.get_player_faction(),
	}


func build_save_data() -> Dictionary:
	var player_faction: String = GameManager.get_player_faction()
	if player_faction == "":
		player_faction = DemoFlow.get_player_faction_id()
	var target_city: Dictionary = CityManager.get_city_state(DemoFlow.get_target_city_id())
	return {
		"schema_version": SCHEMA_VERSION,
		"saved_at_unix": int(Time.get_unix_time_from_system()),
		"turn": GameManager.get_current_turn(),
		"player_faction": player_faction,
		"game": GameManager.get_save_data(),
		"cities": CityManager.get_save_data(),
		"diplomacy": DiplomacySystem.get_save_data(),
		"tech": TechSystem.get_save_data(),
		"school": SchoolManager.get_save_data(),
		"ministers": MinisterManager.get_save_data(),
		"wonders": WonderManager.get_save_data(),
		"events": EventManager.get_save_data(),
		"demo": {
			"enabled": DemoFlow.is_enabled(),
			"complete": DemoFlow.is_demo_complete(),
			"completed_steps": DemoFlow.get_completed_steps(),
			"full_demo_enabled": DemoFlow.is_full_demo_enabled() if DemoFlow.has_method("is_full_demo_enabled") else false,
		},
		"target_city_id": DemoFlow.get_target_city_id(),
		"target_city_owner": str(target_city.get("current_faction_id", "")),
	}


func read_save_file() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


func apply_save_data(data: Dictionary) -> String:
	if int(data.get("schema_version", 0)) > SCHEMA_VERSION:
		return "SAVE_VERSION_TOO_NEW"
	CityManager.load_save_data(data.get("cities", {}) as Dictionary)
	GameManager.load_save_data(data.get("game", {}) as Dictionary)
	TechSystem.load_save_data(data.get("tech", {}) as Dictionary)
	DiplomacySystem.load_save_data(data.get("diplomacy", {}) as Dictionary)
	SchoolManager.load_save_data(data.get("school", {}) as Dictionary)
	MinisterManager.load_save_data(data.get("ministers", {}) as Dictionary)
	WonderManager.load_save_data(data.get("wonders", {}) as Dictionary)
	EventManager.load_save_data(data.get("events", {}) as Dictionary)
	var demo: Dictionary = data.get("demo", {}) as Dictionary
	if DemoFlow.has_method("restore_demo_flags"):
		DemoFlow.restore_demo_flags(bool(demo.get("enabled", false)), bool(demo.get("complete", false)))
	elif DemoFlow.has_method("set_enabled"):
		DemoFlow.set_enabled(bool(demo.get("enabled", false)))
	if DemoFlow.has_method("restore_completed_steps"):
		DemoFlow.restore_completed_steps(demo.get("completed_steps", {}))
	return ""


func get_summary() -> String:
	var data: Dictionary = read_save_file()
	if data.is_empty():
		return "无存档"
	var resources: Dictionary = (data.get("game", {}) as Dictionary).get("faction_resources", {})
	var player_res: Dictionary = resources.get(str(data.get("player_faction", "")), {})
	if player_res.is_empty():
		# 玩家资源在 game 顶层字段
		var g: Dictionary = data.get("game", {}) as Dictionary
		player_res = {
			"food": g.get("player_food", 0),
			"gold": g.get("player_gold", 0),
			"wood": g.get("player_wood", 0),
			"morale": g.get("player_morale", 0),
			"population": g.get("player_population", 0),
			"troops": g.get("player_troops", 0),
		}
	return "回合 %s | 势力 %s | 粮%s 金%s 士气%s | 城归属 %s" % [
		str(data.get("turn", 0)),
		str(data.get("player_faction", "")),
		str(int(player_res.get("food", 0))),
		str(int(player_res.get("gold", 0))),
		str(int(player_res.get("morale", 0))),
		str(data.get("target_city_owner", "")),
	]
