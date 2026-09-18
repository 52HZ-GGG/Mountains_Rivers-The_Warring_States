extends Node

## 演武独立存档管理器（与大地图战役 SaveManager 完全分离）
## 只序列化/恢复 TacticalSkirmishManager 局内状态。
## 文件：user://shanhece_skirmish_save_*.json
## 原则：演武是演武——规则共享内核，状态与存档不写入战役档。

const SCHEMA_VERSION: int = 1
const SLOT_COUNT: int = 3
const AUTO_SLOT: int = -1


func get_slot_path(slot: int) -> String:
	if slot == AUTO_SLOT:
		return "user://shanhece_skirmish_save_auto.json"
	return "user://shanhece_skirmish_save_slot%d.json" % slot


func has_save(slot: int = 0) -> bool:
	return FileAccess.file_exists(get_slot_path(slot))


func quick_save(slot: int = 0) -> Dictionary:
	return save_to_slot(slot)


func quick_load(slot: int = 0) -> Dictionary:
	return load_from_slot(slot)


func build_save_data() -> Dictionary:
	var body: Dictionary = TacticalSkirmishManager.get_save_data()
	body["schema_version"] = SCHEMA_VERSION
	body["kind"] = "skirmish"
	body["saved_at_unix"] = int(Time.get_unix_time_from_system())
	body["scenario_id"] = str((TacticalSkirmishManager.get_active_config() as Dictionary).get("id", ""))
	body["scenario_name"] = str((TacticalSkirmishManager.get_active_config() as Dictionary).get("name", ""))
	return body


func save_to_slot(slot: int) -> Dictionary:
	if not TacticalSkirmishManager.is_active():
		return {"success": false, "reason": "SKIRMISH_NOT_ACTIVE", "slot": slot}
	var data: Dictionary = build_save_data()
	var path: String = get_slot_path(slot)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"success": false, "reason": "WRITE_FAILED", "path": path}
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return {
		"success": true,
		"path": path,
		"slot": slot,
		"scenario_id": str(data.get("scenario_id", "")),
		"units": (data.get("units", []) as Array).size(),
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


func load_from_slot(slot: int) -> Dictionary:
	var data: Dictionary = read_save_file(slot)
	if data.is_empty():
		return {"success": false, "reason": "NO_SAVE", "slot": slot}
	if str(data.get("kind", "")) != "skirmish":
		return {"success": false, "reason": "NOT_SKIRMISH_SAVE", "slot": slot}
	if int(data.get("schema_version", 0)) > SCHEMA_VERSION:
		return {"success": false, "reason": "SAVE_VERSION_TOO_NEW", "slot": slot}
	var err: String = TacticalSkirmishManager.apply_save_data(data)
	if err != "":
		return {"success": false, "reason": err, "slot": slot}
	return {
		"success": true,
		"slot": slot,
		"scenario_id": str(data.get("scenario_id", "")),
		"units": (TacticalSkirmishManager.get_units() as Array).size(),
	}


func delete_slot(slot: int) -> bool:
	var path: String = get_slot_path(slot)
	if not FileAccess.file_exists(path):
		return false
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _slot_info(slot: int) -> Dictionary:
	var path: String = get_slot_path(slot)
	var exists: bool = FileAccess.file_exists(path)
	var scenario_id: String = ""
	var units: int = 0
	var saved_at: int = 0
	if exists:
		var data: Dictionary = read_save_file(slot)
		scenario_id = str(data.get("scenario_id", ""))
		units = (data.get("units", []) as Array).size()
		saved_at = int(data.get("saved_at_unix", 0))
	return {
		"slot": slot,
		"label": "演武自动" if slot == AUTO_SLOT else "演武槽位 %d" % (slot + 1),
		"exists": exists,
		"scenario_id": scenario_id,
		"units": units,
		"saved_at_unix": saved_at,
		"path": path,
	}


func list_slots() -> Array:
	var out: Array = []
	for slot in range(SLOT_COUNT):
		out.append(_slot_info(slot))
	out.append(_slot_info(AUTO_SLOT))
	return out


func format_slots_text() -> String:
	var lines: Array[String] = []
	for info: Dictionary in list_slots():
		if bool(info.get("exists", false)):
			lines.append("%s：%s | 单位 %d" % [
				str(info.get("label", "")),
				str(info.get("scenario_id", "")),
				int(info.get("units", 0)),
			])
		else:
			lines.append("%s：空" % str(info.get("label", "")))
	return "\n".join(lines)


## 演武结束时可选自动槽（由 UI/流程决定是否调用；默认不自动写，保持与战役档无关）
func auto_save_if_active() -> Dictionary:
	if not TacticalSkirmishManager.is_active():
		return {"success": false, "reason": "SKIRMISH_NOT_ACTIVE"}
	return save_to_slot(AUTO_SLOT)
