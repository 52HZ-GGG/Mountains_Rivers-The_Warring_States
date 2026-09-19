extends Node

## 完整存档管理器：战役（大地图）多槽位 + 自动存档。
## 汇总 GameManager / CityManager / Diplomacy / Tech / School / Minister / Wonder / Event / Strategic / Disaster。
## **不含演武**：演武状态由 SkirmishSaveManager 独立存档（演武是演武）。

const SCHEMA_VERSION: int = 2
const SLOT_COUNT: int = 3
const AUTO_SLOT: int = -1


func _ready() -> void:
	SignalBus.turn_ended.connect(_on_turn_ended)


func get_slot_path(slot: int) -> String:
	if slot == AUTO_SLOT:
		return "user://shanhece_save_auto.json"
	return "user://shanhece_save_slot%d.json" % slot


func has_save(slot: int = 0) -> bool:
	return FileAccess.file_exists(get_slot_path(slot))


func get_save_path(slot: int = 0) -> String:
	return get_slot_path(slot)


func quick_save(slot: int = 0) -> Dictionary:
	return save_to_slot(slot)


func quick_load(slot: int = 0) -> Dictionary:
	return load_from_slot(slot)


func save_to_slot(slot: int) -> Dictionary:
	var data: Dictionary = build_save_data()
	var path: String = get_slot_path(slot)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"success": false, "reason": "WRITE_FAILED", "path": path}
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return {"success": true, "path": path, "slot": slot, "turn": int(data.get("turn", 0))}


## 把快照写入 user:// 指定文件名（兼容旧单槽镜像测试路径）
func write_snapshot_file(file_name: String, data: Dictionary) -> bool:
	var file: FileAccess = FileAccess.open("user://" + file_name, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true


func load_from_slot(slot: int) -> Dictionary:
	var data: Dictionary = read_save_file(slot)
	if data.is_empty():
		return {"success": false, "reason": "NO_SAVE", "slot": slot}
	var err: String = apply_save_data(data)
	if err != "":
		return {"success": false, "reason": err, "slot": slot}
	return {
		"success": true,
		"slot": slot,
		"turn": GameManager.get_current_turn(),
		"player_faction": GameManager.get_player_faction(),
	}


func delete_slot(slot: int) -> bool:
	var path: String = get_slot_path(slot)
	if not FileAccess.file_exists(path):
		return false
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func list_slots() -> Array:
	var out: Array = []
	for slot in range(SLOT_COUNT):
		out.append(_slot_info(slot))
	out.append(_slot_info(AUTO_SLOT))
	return out


func _slot_info(slot: int) -> Dictionary:
	var path: String = get_slot_path(slot)
	var exists: bool = FileAccess.file_exists(path)
	var turn: int = 0
	var player: String = ""
	var saved_at: int = 0
	if exists:
		var data: Dictionary = read_save_file(slot)
		turn = int(data.get("turn", 0))
		player = str(data.get("player_faction", ""))
		saved_at = int(data.get("saved_at_unix", 0))
	return {
		"slot": slot,
		"label": "自动" if slot == AUTO_SLOT else "槽位 %d" % (slot + 1),
		"exists": exists,
		"turn": turn,
		"player_faction": player,
		"saved_at_unix": saved_at,
		"path": path,
	}


func _on_turn_ended(_turn_number: int, faction_id: String) -> void:
	# 玩家回合结束时写自动存档
	if faction_id == GameManager.get_player_faction():
		save_to_slot(AUTO_SLOT)


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
		"strategic_units": StrategicMapManager.get_save_data(),
		"disasters": DisasterManager.get_save_data(),
		"passes": PassManager.get_save_data() if PassManager != null else {},
		"demo": {
			"enabled": DemoFlow.is_enabled(),
			"complete": DemoFlow.is_demo_complete(),
			"completed_steps": DemoFlow.get_completed_steps(),
		},
		"target_city_id": DemoFlow.get_target_city_id(),
		"target_city_owner": str(target_city.get("current_faction_id", "")),
	}


func read_save_file(slot: int = 0) -> Dictionary:
	var path: String = get_slot_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
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
	StrategicMapManager.load_save_data(data.get("strategic_units", {}) as Dictionary)
	DisasterManager.load_save_data(data.get("disasters", {}) as Dictionary)
	if PassManager != null:
		PassManager.load_save_data(data.get("passes", {}) as Dictionary)
	var demo: Dictionary = data.get("demo", {}) as Dictionary
	if DemoFlow.has_method("restore_demo_flags"):
		DemoFlow.restore_demo_flags(bool(demo.get("enabled", false)), bool(demo.get("complete", false)))
	elif DemoFlow.has_method("set_enabled"):
		DemoFlow.set_enabled(bool(demo.get("enabled", false)))
	if DemoFlow.has_method("restore_completed_steps"):
		DemoFlow.restore_completed_steps(demo.get("completed_steps", {}))
	return ""


func get_summary(slot: int = 0) -> String:
	var data: Dictionary = read_save_file(slot)
	if data.is_empty():
		return "无存档"
	var g: Dictionary = data.get("game", {}) as Dictionary
	return "回合 %s | 势力 %s | 粮%s 金%s 士气%s | 洛邑 %s" % [
		str(data.get("turn", 0)),
		str(data.get("player_faction", "")),
		str(int(g.get("player_food", 0))),
		str(int(g.get("player_gold", 0))),
		str(int(g.get("player_morale", 0))),
		str(data.get("target_city_owner", "")),
	]


func format_slots_text() -> String:
	var lines: Array[String] = []
	for info: Dictionary in list_slots():
		if bool(info.get("exists", false)):
			lines.append("%s：回合 %d | %s | %s" % [
				str(info.get("label", "")),
				int(info.get("turn", 0)),
				str(info.get("player_faction", "")),
				get_summary(int(info.get("slot", 0))),
			])
		else:
			lines.append("%s：空" % str(info.get("label", "")))
	return "\n".join(lines)
