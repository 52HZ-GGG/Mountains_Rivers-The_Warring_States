extends Panel

## 大夫正式面板：文/武/外交列表、派驻首都、派驻外交、属性与加成。

signal panel_closed

var _faction_id: String = ""
var _title_label: Label
var _civil_list: VBoxContainer
var _military_list: VBoxContainer
var _diplomat_list: VBoxContainer
var _detail_label: RichTextLabel
var _status_label: Label
var _target_option: OptionButton
var _close_btn: Button


func _ready() -> void:
	_build_ui()
	visible = false


func open(faction_id: String = "") -> void:
	_faction_id = faction_id
	if _faction_id == "":
		_faction_id = GameManager.get_player_faction()
	visible = true
	_refresh_all()


func close() -> void:
	visible = false
	panel_closed.emit()


func get_faction_id() -> String:
	return _faction_id


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 80
	offset_top = 60
	offset_right = -80
	offset_bottom = -60
	add_theme_stylebox_override("panel", _panel_style())

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	_title_label = Label.new()
	_title_label.text = "大夫府"
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)
	_close_btn = Button.new()
	_close_btn.text = "关闭"
	_close_btn.pressed.connect(func() -> void: close())
	header.add_child(_close_btn)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_status_label)

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 12)
	root.add_child(cols)

	_civil_list = _make_column(cols, "文大夫")
	_military_list = _make_column(cols, "武大夫")
	_diplomat_list = _make_column(cols, "外交大夫")

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	root.add_child(action_row)
	var assign_capital := Button.new()
	assign_capital.text = "派驻首都"
	assign_capital.pressed.connect(_on_assign_capital)
	action_row.add_child(assign_capital)
	var unassign_capital := Button.new()
	unassign_capital.text = "卸任首都"
	unassign_capital.pressed.connect(_on_unassign_capital)
	action_row.add_child(unassign_capital)
	action_row.add_child(Label.new())
	var target_label := Label.new()
	target_label.text = "外交目标："
	action_row.add_child(target_label)
	_target_option = OptionButton.new()
	_target_option.custom_minimum_size = Vector2(140, 0)
	action_row.add_child(_target_option)
	var assign_dip := Button.new()
	assign_dip.text = "派驻外交大夫"
	assign_dip.pressed.connect(_on_assign_diplomat)
	action_row.add_child(assign_dip)

	_detail_label = RichTextLabel.new()
	_detail_label.bbcode_enabled = true
	_detail_label.fit_content = true
	_detail_label.custom_minimum_size = Vector2(0, 120)
	_detail_label.text = "选择列表中的大夫查看详情。"
	root.add_child(_detail_label)


func _make_column(parent: Control, title: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	var label := Label.new()
	label.text = "── %s ──" % title
	label.add_theme_color_override("font_color", Color(0.86, 0.7, 0.55, 1))
	box.add_child(label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	return list


func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.10, 0.08, 0.96)
	sb.border_color = Color(0.55, 0.42, 0.22, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


func _refresh_all() -> void:
	_title_label.text = "大夫府 — %s" % _faction_display(_faction_id)
	_status_label.text = "武大夫攻防加成：+%d%% / +%d%%" % [
		int(MinisterManager.get_faction_military_attack_bonus(_faction_id) * 100),
		int(MinisterManager.get_faction_military_defense_bonus(_faction_id) * 100),
	]
	_clear_list(_civil_list)
	_clear_list(_military_list)
	_clear_list(_diplomat_list)
	for m in MinisterManager.get_faction_civil_ministers(_faction_id):
		_add_minister_row(_civil_list, m as Dictionary, "civil")
	for m in MinisterManager.get_faction_military_ministers(_faction_id):
		_add_minister_row(_military_list, m as Dictionary, "military")
	for m in MinisterManager.get_faction_diplomat_ministers(_faction_id):
		_add_minister_row(_diplomat_list, m as Dictionary, "diplomat")
	_refresh_target_options()


func _refresh_target_options() -> void:
	_target_option.clear()
	for fid in GameManager.FACTION_IDS:
		if fid == _faction_id:
			continue
		_target_option.add_item(_faction_display(fid))
		_target_option.set_item_metadata(_target_option.item_count - 1, fid)


func _clear_list(list: VBoxContainer) -> void:
	for ch in list.get_children():
		ch.queue_free()


func _add_minister_row(list: VBoxContainer, minister: Dictionary, type: String) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_child(row)
	var btn := Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.text = _minister_title(minister, type)
	btn.pressed.connect(_on_minister_selected.bind(minister, type))
	row.add_child(btn)


func _minister_title(minister: Dictionary, type: String) -> String:
	var stats: Dictionary = minister.get("stats", {})
	var parts: Array[String] = []
	match type:
		"civil":
			parts.append("理财%s 安民%s" % [str(stats.get("理财", 0)), str(stats.get("安民", 0))])
		"military":
			parts.append("勇武%s 韬略%s" % [str(stats.get("勇武", 0)), str(stats.get("韬略", 0))])
		"diplomat":
			parts.append("辩才%s 亲和%s" % [str(stats.get("辩才", 0)), str(stats.get("亲和", 0))])
	return "%s（%s）" % [str(minister.get("name", "?")), "、".join(parts)]


func _on_minister_selected(minister: Dictionary, type: String) -> void:
	var stats: Dictionary = minister.get("stats", {})
	var lines: Array[String] = []
	lines.append("[b]%s[/b]（%s）" % [str(minister.get("name", "?")), str(minister.get("quality", ""))])
	lines.append("状态：%s" % str(minister.get("status", "idle")))
	if type == "civil":
		var city_id: String = str(minister.get("assigned_city_id", ""))
		lines.append("驻城：%s" % (_city_name(city_id) if city_id != "" else "未派驻"))
		lines.append("属性：理财 %s / 安民 %s" % [str(stats.get("理财", 0)), str(stats.get("安民", 0))])
	elif type == "military":
		lines.append("属性：勇武 %s / 韬略 %s" % [str(stats.get("勇武", 0)), str(stats.get("韬略", 0))])
		lines.append("效果：全军攻击 +%d%%、防御 +%d%%" % [
			int(MinisterManager.get_faction_military_attack_bonus(_faction_id) * 100),
			int(MinisterManager.get_faction_military_defense_bonus(_faction_id) * 100),
		])
	else:
		var target: String = str(minister.get("assigned_faction_id", ""))
		lines.append("派驻目标：%s" % (_faction_display(target) if target != "" else "未派驻"))
		lines.append("属性：辩才 %s / 亲和 %s" % [str(stats.get("辩才", 0)), str(stats.get("亲和", 0))])
		if target != "":
			lines.append("效果：对目标外交成本 -%d%%，好感增长更快" % int(MinisterManager.get_diplomat_cost_reduction(_faction_id, target) * 100))
	_detail_label.text = "\n".join(lines)


func _on_assign_capital() -> void:
	var capital: Dictionary = CityManager.get_capital_state(_faction_id)
	if capital.is_empty():
		_status_label.text = "未找到首都。"
		return
	var chosen: String = ""
	for m in MinisterManager.get_faction_civil_ministers(_faction_id):
		var mid: String = str((m as Dictionary).get("id", ""))
		if mid == "":
			continue
		chosen = mid
		break
	if chosen == "":
		_status_label.text = "没有可派驻的文大夫。"
		return
	var ok: bool = MinisterManager.assign_civil_minister(str(capital.get("id", "")), chosen)
	_status_label.text = "派驻首都成功。" if ok else "派驻失败。"
	_refresh_all()


func _on_unassign_capital() -> void:
	var capital: Dictionary = CityManager.get_capital_state(_faction_id)
	if not capital.is_empty():
		MinisterManager.remove_civil_minister_from_city(str(capital.get("id", "")))
		_status_label.text = "已卸任首都大夫。"
	_refresh_all()


func _on_assign_diplomat() -> void:
	if _target_option.item_count <= 0:
		_status_label.text = "没有可派驻的外交目标。"
		return
	var target: String = str(_target_option.get_item_metadata(_target_option.selected))
	for m in MinisterManager.get_faction_diplomat_ministers(_faction_id):
		var mid: String = str((m as Dictionary).get("id", ""))
		if mid == "":
			continue
		if MinisterManager.assign_diplomat_to_faction(mid, target):
			_status_label.text = "已派驻外交大夫至 %s。" % _faction_display(target)
			_refresh_all()
			return
	_status_label.text = "派驻外交大夫失败。"


func _city_name(city_id: String) -> String:
	return str(CityManager.get_city_state(city_id).get("name", city_id))


func _faction_display(fid: String) -> String:
	if fid == "":
		return "—"
	var f: Dictionary = DataManager.get_faction(fid)
	return str(f.get("name", fid)) if not f.is_empty() else fid
