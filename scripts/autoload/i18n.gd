extends Node

## 轻量 i18n：CSV 词条表 + TranslationServer locale。
## 数据：data/i18n/translations.csv
## 列：key,zh_CN,en_US

var _table: Dictionary = {}
var _locale: String = "zh-CN"


func _ready() -> void:
	_load_table()
	_apply_locale("zh-CN")


func _load_table() -> void:
	_table.clear()
	var file := FileAccess.open("res://data/i18n/translations.csv", FileAccess.READ)
	if file == null:
		push_warning("I18n: translations.csv 不存在")
		return
	# 跳过表头
	file.get_line()
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var parts: PackedStringArray = line.split(",", true)
		if parts.size() < 2:
			continue
		var key: String = parts[0].strip_edges()
		var zh: String = parts[1].strip_edges()
		var en: String = parts[2].strip_edges() if parts.size() > 2 else zh
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
