extends Node

## 合纵连横战役模式状态
## 关卡目录来自 data/campaign_levels.json（数据驱动，策划可直接改表）

const LEVELS_PATH: String = "res://data/campaign_levels.json"
const LAUNCH_MODE_TUTORIAL: String = "demo"

var _config: Dictionary = {}
var _selected_level_id: String = ""


func _ready() -> void:
	reload()


func reload() -> void:
	_config = _load_json(LEVELS_PATH)
	if _selected_level_id == "" and not get_levels().is_empty():
		var first: Dictionary = get_levels()[0]
		if not bool(first.get("locked", true)):
			_selected_level_id = str(first.get("id", ""))


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("CampaignFlow: 缺少关卡配置 %s" % path)
		return {}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("CampaignFlow: 无法读取 %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		return parsed
	return {}


func get_campaign_name() -> String:
	return str(_config.get("name", "合纵连横"))


func get_campaign_subtitle() -> String:
	return str(_config.get("subtitle", "战役模式"))


func get_campaign_description() -> String:
	return str(_config.get("description", ""))


func get_levels() -> Array:
	var levels: Variant = _config.get("levels", [])
	if levels is Array:
		return levels
	return []


func get_level(level_id: String) -> Dictionary:
	for lv: Variant in get_levels():
		var d: Dictionary = lv as Dictionary
		if str(d.get("id", "")) == level_id:
			return d
	return {}


func get_selected_level_id() -> String:
	return _selected_level_id


func set_selected_level_id(level_id: String) -> void:
	_selected_level_id = level_id


func get_selected_level() -> Dictionary:
	return get_level(_selected_level_id)


func is_level_locked(level_id: String) -> bool:
	var lv: Dictionary = get_level(level_id)
	if lv.is_empty():
		return true
	return bool(lv.get("locked", true))


## 返回 StartupFlow 可启动的 mode id；锁定或未知关卡返回空串
func resolve_launch_mode(level_id: String) -> String:
	if is_level_locked(level_id):
		return ""
	return str(get_level(level_id).get("launch_mode", ""))


func has_unlocked_level() -> bool:
	for lv: Variant in get_levels():
		if not bool((lv as Dictionary).get("locked", true)):
			return true
	return false
