extends HBoxContainer

## 资源栏：显示玩家当前资源数值。
## 每回合自动刷新，也可手动调用 refresh() 强制更新。

var _labels: Dictionary = {}


func _ready() -> void:
	add_to_group("resource_bar")
	_add_resource_cell("food", "粮食")
	_add_resource_cell("gold", "金币")
	_add_resource_cell("iron", "铁")
	_add_resource_cell("horse", "马匹")
	_add_resource_cell("refined_iron", "精铁")
	_add_resource_cell("troops", "兵力")
	_add_resource_cell("population", "人口")
	_add_resource_cell("morale", "民心")
	add_theme_constant_override("separation", 16)
	SignalBus.turn_started.connect(_on_turn_started)
	call_deferred("refresh")


func _add_resource_cell(key: String, display_name: String) -> void:
	var cell := HBoxContainer.new()
	cell.add_theme_constant_override("separation", 4)
	var icon := Label.new()
	icon.text = _resource_icon(key)
	icon.add_theme_font_size_override("font_size", 16)
	cell.add_child(icon)
	var name_lbl := Label.new()
	name_lbl.text = display_name
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8, 1))
	cell.add_child(name_lbl)
	var val_lbl := Label.new()
	val_lbl.text = "0"
	val_lbl.add_theme_font_size_override("font_size", 15)
	val_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	cell.add_child(val_lbl)
	add_child(cell)
	_labels[key] = val_lbl


func _resource_icon(key: String) -> String:
	match key:
		"food": return "🌾"
		"gold": return "💰"
		"iron": return "⚙"
		"horse": return "🐎"
		"refined_iron": return "⚔"
		"troops": return "🛡"
		"population": return "👥"
		"morale": return "🔥"
		_: return "?"


func _on_turn_started(_turn: int, _faction: String) -> void:
	refresh()


## 刷新所有资源数值。
func refresh() -> void:
	_set_val("food", GameManager.get_player_food())
	_set_val("gold", GameManager.get_player_gold())
	_set_val("iron", GameManager.get_player_iron())
	_set_val("horse", GameManager.get_player_horse())
	_set_val("refined_iron", GameManager.get_player_refined_iron())
	_set_val("troops", GameManager.get_player_troops())
	_set_val("population", GameManager.get_player_population())
	_set_val("morale", GameManager.get_player_morale())


func _set_val(key: String, value: int) -> void:
	if _labels.has(key):
		_labels[key].text = _format_number(value)


func _format_number(n: int) -> String:
	if n >= 10000:
		return "%.1f万" % (n / 10000.0)
	return str(n)
