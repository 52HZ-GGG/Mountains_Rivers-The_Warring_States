extends Node

## 轻量 i18n：JSON 词条表 + TranslationServer locale。
## 数据：data/i18n/translations.json
## 结构：{key: {"zh-CN": ..., "en-US": ...}}

var _table: Dictionary = {}
var _locale: String = "zh-CN"


func _ready() -> void:
	_load_table()
	_apply_locale("zh-CN")


func _load_table() -> void:
	_table.clear()
	var file := FileAccess.open("res://data/i18n/translations.json", FileAccess.READ)
	if file == null:
		push_warning("I18n: translations.json 不存在")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_warning("I18n: translations.json 解析失败")
		return
	var data: Dictionary = parsed as Dictionary
	for key: String in data:
		var row: Variant = data[key]
		if not (row is Dictionary):
			continue
		var zh: String = str((row as Dictionary).get("zh-CN", key))
		var en: String = str((row as Dictionary).get("en-US", zh))
		_table[key] = {"zh-CN": zh, "en-US": en}


func _apply_locale(locale: String) -> void:
	_locale = locale
	TranslationServer.set_locale(locale)


func get_locale() -> String:
	return _locale


func toggle_locale() -> String:
	var next: String = "en-US" if _locale.begins_with("zh") else "zh-CN"
	_apply_locale(next)
	return next


## 翻译词条；无词条时原样返回 key
func t(key: String) -> String:
	if not _table.has(key):
		return key
	var row: Dictionary = _table[key]
	return str(row.get(_locale if row.has(_locale) else "zh-CN", key))


func has_key(key: String) -> bool:
	return _table.has(key)


func get_key_count() -> int:
	return _table.size()
