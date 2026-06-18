@tool
extends Control

const DocumentScript := preload("res://addons/skirmish_scenario_editor/scenario_document.gd")
const MapCanvasScript := preload("res://addons/skirmish_scenario_editor/scenario_map_canvas.gd")

var _editor_interface: EditorInterface = null
var _document: SkirmishScenarioDocument = DocumentScript.new()
var _current_index: int = -1
var _selected_cell: Vector2i = Vector2i(-1, -1)
var _selected_unit_index: int = -1
var _selected_city_key: String = ""
var _suppress_ui: bool = false
var _pending_action: String = ""
var _pending_target_index: int = -1
var _left_buttons: Dictionary = {}

var _scenario_list: ItemList
var _save_button: Button
var _reload_button: Button
var _map_canvas: SkirmishScenarioMapCanvas
var _mode_option: OptionButton
var _terrain_option: OptionButton
var _city_option: OptionButton
var _scenario_id_edit: LineEdit
var _scenario_name_edit: LineEdit
var _scenario_desc_edit: TextEdit
var _mechanics_edit: TextEdit
var _width_spin: SpinBox
var _height_spin: SpinBox
var _player_faction_option: OptionButton
var _enemy_faction_option: OptionButton
var _validation_output: RichTextLabel
var _selection_title: Label
var _selection_info: Label
var _unit_section: VBoxContainer
var _unit_id_edit: LineEdit
var _unit_type_option: OptionButton
var _unit_faction_option: OptionButton
var _unit_delete_button: Button
var _city_section: VBoxContainer
var _city_level_spin: SpinBox
var _city_capital_check: CheckBox
var _city_side_label: Label
var _status_label: Label
var _alert_dialog: AcceptDialog
var _confirm_dialog: ConfirmationDialog


func set_editor_interface(editor_interface: EditorInterface) -> void:
	_editor_interface = editor_interface


func _ready() -> void:
	_build_ui()
	_connect_ui()
	_load_document()


func has_unsaved_changes() -> bool:
	return _document != null and _document.is_dirty()


func _build_ui() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var root: HBoxContainer = HBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(root)

	var left_panel: VBoxContainer = VBoxContainer.new()
	left_panel.custom_minimum_size = Vector2(230, 0)
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(left_panel)

	var left_title: Label = Label.new()
	left_title.text = "场景列表"
	left_panel.add_child(left_title)

	_scenario_list = ItemList.new()
	_scenario_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scenario_list.select_mode = ItemList.SELECT_SINGLE
	left_panel.add_child(_scenario_list)

	var left_button_grid: GridContainer = GridContainer.new()
	left_button_grid.columns = 2
	left_panel.add_child(left_button_grid)
	for config: Dictionary in [
		{"name": "NewBtn", "text": "新建"},
		{"name": "CopyBtn", "text": "复制"},
		{"name": "DeleteBtn", "text": "删除"},
		{"name": "ReloadBtn", "text": "放弃改动"},
		{"name": "SaveBtn", "text": "保存"},
		{"name": "ResizeBtn", "text": "应用尺寸"},
	]:
		var button: Button = Button.new()
		button.name = str(config["name"])
		button.text = str(config["text"])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left_button_grid.add_child(button)
		_left_buttons[button.name] = button

	var center_panel: VBoxContainer = VBoxContainer.new()
	center_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(center_panel)

	var center_title: Label = Label.new()
	center_title.text = "地图画布（odd-R 列/行坐标）"
	center_panel.add_child(center_title)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_panel.add_child(scroll)

	_map_canvas = MapCanvasScript.new()
	_map_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_map_canvas)

	_status_label = Label.new()
	_status_label.text = "状态：未加载"
	center_panel.add_child(_status_label)

	var right_scroll: ScrollContainer = ScrollContainer.new()
	right_scroll.custom_minimum_size = Vector2(340, 0)
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(right_scroll)

	var right_panel: VBoxContainer = VBoxContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.add_child(right_panel)

	right_panel.add_child(_section_label("场景元信息"))
	_scenario_id_edit = _labeled_line_edit(right_panel, "ID")
	_scenario_name_edit = _labeled_line_edit(right_panel, "名称")
	_scenario_desc_edit = _labeled_text_edit(right_panel, "描述", 80)
	_mechanics_edit = _labeled_text_edit(right_panel, "Mechanics（每行一项）", 90)
	_width_spin = _labeled_spinbox(right_panel, "地图宽度", 1, 99)
	_height_spin = _labeled_spinbox(right_panel, "地图高度", 1, 99)
	_player_faction_option = _labeled_option_button(right_panel, "我方势力")
	_enemy_faction_option = _labeled_option_button(right_panel, "敌方势力")

	right_panel.add_child(_section_label("当前画笔"))
	_mode_option = _labeled_option_button(right_panel, "编辑模式")
	_mode_option.add_item("地形")
	_mode_option.add_item("单位")
	_mode_option.add_item("城池")
	_terrain_option = _labeled_option_button(right_panel, "地形画笔")
	_city_option = _labeled_option_button(right_panel, "城池对象")
	_city_option.add_item("player_city")
	_city_option.add_item("enemy_city")

	right_panel.add_child(_section_label("当前选择"))
	_selection_title = Label.new()
	_selection_title.text = "未选择"
	right_panel.add_child(_selection_title)
	_selection_info = Label.new()
	_selection_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_panel.add_child(_selection_info)

	_unit_section = VBoxContainer.new()
	right_panel.add_child(_unit_section)
	_unit_section.add_child(_section_label("单位属性"))
	_unit_id_edit = _labeled_line_edit(_unit_section, "单位 ID")
	_unit_type_option = _labeled_option_button(_unit_section, "兵种")
	_unit_faction_option = _labeled_option_button(_unit_section, "所属势力")
	_unit_delete_button = Button.new()
	_unit_delete_button.text = "删除单位"
	_unit_section.add_child(_unit_delete_button)

	_city_section = VBoxContainer.new()
	right_panel.add_child(_city_section)
	_city_section.add_child(_section_label("城池属性"))
	_city_side_label = Label.new()
	_city_side_label.text = "当前："
	_city_section.add_child(_city_side_label)
	_city_level_spin = _labeled_spinbox(_city_section, "城池等级", 1, 5)
	_city_capital_check = CheckBox.new()
	_city_capital_check.text = "is_capital"
	_city_section.add_child(_city_capital_check)

	right_panel.add_child(_section_label("校验结果"))
	_validation_output = RichTextLabel.new()
	_validation_output.fit_content = true
	_validation_output.custom_minimum_size = Vector2(0, 220)
	_validation_output.scroll_active = true
	right_panel.add_child(_validation_output)

	_save_button = left_button_grid.get_node("SaveBtn") as Button
	_reload_button = left_button_grid.get_node("ReloadBtn") as Button

	_alert_dialog = AcceptDialog.new()
	_alert_dialog.title = "提示"
	add_child(_alert_dialog)

	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.title = "未保存改动"
	_confirm_dialog.dialog_text = "当前有未保存改动，是否放弃？"
	add_child(_confirm_dialog)


func _connect_ui() -> void:
	_scenario_list.item_selected.connect(_on_scenario_selected)
	_map_canvas.cell_clicked.connect(_on_map_cell_clicked)
	(_left_buttons.get("NewBtn") as Button).pressed.connect(_on_new_pressed)
	(_left_buttons.get("CopyBtn") as Button).pressed.connect(_on_copy_pressed)
	(_left_buttons.get("DeleteBtn") as Button).pressed.connect(_on_delete_pressed)
	_reload_button.pressed.connect(_on_reload_pressed)
	_save_button.pressed.connect(_on_save_pressed)
	(_left_buttons.get("ResizeBtn") as Button).pressed.connect(_on_resize_pressed)
	_confirm_dialog.confirmed.connect(_on_confirm_pending_action)

	_scenario_id_edit.text_changed.connect(_on_scenario_id_changed)
	_scenario_name_edit.text_changed.connect(_on_scenario_name_changed)
	_scenario_desc_edit.text_changed.connect(_on_scenario_desc_changed)
	_mechanics_edit.text_changed.connect(_on_mechanics_changed)
	_width_spin.value_changed.connect(_on_size_spin_changed)
	_height_spin.value_changed.connect(_on_size_spin_changed)
	_player_faction_option.item_selected.connect(_on_player_faction_selected)
	_enemy_faction_option.item_selected.connect(_on_enemy_faction_selected)
	_mode_option.item_selected.connect(_refresh_selection_state)
	_city_option.item_selected.connect(_refresh_selection_state)
	_unit_id_edit.text_changed.connect(_on_unit_id_changed)
	_unit_type_option.item_selected.connect(_on_unit_type_selected)
	_unit_faction_option.item_selected.connect(_on_unit_faction_selected)
	_unit_delete_button.pressed.connect(_on_delete_unit_pressed)
	_city_level_spin.value_changed.connect(_on_city_level_changed)
	_city_capital_check.toggled.connect(_on_city_capital_toggled)


func _load_document() -> void:
	if not _document.load_from_path():
		_show_alert("无法加载 data/skirmish_scenarios.json")
		return
	_current_index = 0 if _document.get_scenario_count() > 0 else -1
	_rebuild_options()
	_refresh_scenario_list()
	_select_current_scenario()


func _rebuild_options() -> void:
	_suppress_ui = true
	_terrain_option.clear()
	for terrain_info: Dictionary in _document.get_terrain_options():
		_terrain_option.add_item("%s（%s）" % [str(terrain_info["name"]), str(terrain_info["id"])])
		_terrain_option.set_item_metadata(_terrain_option.item_count - 1, str(terrain_info["id"]))
	_unit_type_option.clear()
	for unit_info: Dictionary in _document.get_unit_type_options():
		_unit_type_option.add_item("%s（%s）" % [str(unit_info["name"]), str(unit_info["id"])])
		_unit_type_option.set_item_metadata(_unit_type_option.item_count - 1, str(unit_info["id"]))
	_player_faction_option.clear()
	_enemy_faction_option.clear()
	for faction_info: Dictionary in _document.get_faction_options():
		var label: String = "%s（%s）" % [str(faction_info["name"]), str(faction_info["id"])]
		_player_faction_option.add_item(label)
		_player_faction_option.set_item_metadata(_player_faction_option.item_count - 1, str(faction_info["id"]))
		_enemy_faction_option.add_item(label)
		_enemy_faction_option.set_item_metadata(_enemy_faction_option.item_count - 1, str(faction_info["id"]))
	if _mode_option.item_count > 0:
		_mode_option.select(0)
	if _city_option.item_count > 0:
		_city_option.select(0)
	if _terrain_option.item_count > 0:
		_terrain_option.select(0)
	_suppress_ui = false


func _refresh_scenario_list() -> void:
	var selected_id: String = ""
	if _current_index >= 0:
		selected_id = str(_document.get_scenario(_current_index).get("id", ""))
	_scenario_list.clear()
	for i: int in range(_document.get_scenario_count()):
		var scenario: Dictionary = _document.get_scenario(i)
		var title: String = "%s | %s" % [str(scenario.get("id", "")), str(scenario.get("name", ""))]
		if _document.is_saved_scenario_id_locked(i):
			title += " [锁]"
		_scenario_list.add_item(title)
		if str(scenario.get("id", "")) == selected_id:
			_current_index = i
	if _current_index >= 0 and _current_index < _scenario_list.item_count:
		_scenario_list.select(_current_index)


func _select_current_scenario() -> void:
	var scenario: Dictionary = _document.get_scenario(_current_index)
	if scenario.is_empty():
		_clear_scenario_ui()
		return
	_suppress_ui = true
	_scenario_id_edit.text = str(scenario.get("id", ""))
	_scenario_id_edit.editable = not _document.is_saved_scenario_id_locked(_current_index)
	_scenario_name_edit.text = str(scenario.get("name", ""))
	_scenario_desc_edit.text = str(scenario.get("description", ""))
	_mechanics_edit.text = _document.get_scenario_mechanics_text(_current_index)
	_width_spin.value = int(scenario.get("map_width", 7))
	_height_spin.value = int(scenario.get("map_height", 7))
	_select_option_by_metadata(_player_faction_option, str(scenario.get("player_faction_id", "")))
	_select_option_by_metadata(_enemy_faction_option, str(scenario.get("enemy_faction_id", "")))
	_suppress_ui = false
	_selected_cell = Vector2i(-1, -1)
	_selected_unit_index = -1
	_selected_city_key = ""
	_refresh_canvas()
	_refresh_selection_state()
	_refresh_validation_view()
	_update_status("已载入 %s" % str(scenario.get("id", "")))


func _refresh_canvas() -> void:
	var scenario: Dictionary = _document.get_scenario(_current_index)
	if scenario.is_empty():
		_map_canvas.clear_scene()
		return
	_map_canvas.set_scenario_data(scenario, _selected_cell, _selected_unit_index, _selected_city_key)


func _refresh_selection_state(_arg: Variant = null) -> void:
	var scenario: Dictionary = _document.get_scenario(_current_index)
	if scenario.is_empty():
		_unit_section.visible = false
		_city_section.visible = false
		_selection_title.text = "未选择"
		_selection_info.text = "当前没有可编辑场景。"
		return
	var mode: String = _current_mode()
	_unit_section.visible = _selected_unit_index >= 0
	_city_section.visible = not _selected_city_key.is_empty()
	if _selected_unit_index >= 0:
		var unit: Dictionary = _document.get_unit(_current_index, _selected_unit_index)
		_selection_title.text = "单位：%s" % str(unit.get("id", ""))
		_selection_info.text = "坐标：(%d,%d)" % [int(unit.get("q", 0)), int(unit.get("r", 0))]
		_suppress_ui = true
		_unit_id_edit.text = str(unit.get("id", ""))
		_select_option_by_metadata(_unit_type_option, str(unit.get("unit_type_id", "")))
		_rebuild_unit_faction_options()
		_select_option_by_metadata(_unit_faction_option, str(unit.get("faction_id", "")))
		_suppress_ui = false
	elif not _selected_city_key.is_empty():
		var city: Dictionary = _document.get_city(_current_index, _selected_city_key)
		_selection_title.text = "城池：%s" % _selected_city_key
		_selection_info.text = "坐标：(%d,%d)" % [int(city.get("q", 0)), int(city.get("r", 0))]
		_city_side_label.text = "当前：%s" % _selected_city_key
		_suppress_ui = true
		_city_level_spin.value = int(city.get("level", 3))
		_city_capital_check.button_pressed = bool(city.get("is_capital", true))
		_suppress_ui = false
	elif _selected_cell.x >= 0 and _selected_cell.y >= 0:
		_selection_title.text = "格子：(%d,%d)" % [_selected_cell.x, _selected_cell.y]
		_selection_info.text = "地形：%s | 模式：%s" % [
			_document.get_terrain_name(_document.get_cell_terrain(_current_index, _selected_cell.x, _selected_cell.y)),
			mode,
		]
	else:
		_selection_title.text = "未选择"
		_selection_info.text = "点击地图选择格子、单位或城池。"
	_refresh_canvas()


func _refresh_validation_view() -> void:
	var errors: Array[String] = _document.validate_document()
	if errors.is_empty():
		_validation_output.text = "[color=green]校验通过[/color]"
	else:
		var lines: PackedStringArray = PackedStringArray()
		for err: String in errors:
			lines.append("• %s" % err)
		_validation_output.text = "[color=red]%s[/color]" % "\n".join(lines)


func _current_mode() -> String:
	match _mode_option.selected:
		1:
			return "unit"
		2:
			return "city"
		_:
			return "terrain"


func _current_city_target() -> String:
	return "player" if _city_option.selected == 0 else "enemy"


func _on_new_pressed() -> void:
	var new_index: int = _document.create_new_scenario()
	_refresh_scenario_list()
	_current_index = new_index
	_scenario_list.select(_current_index)
	_select_current_scenario()


func _on_copy_pressed() -> void:
	if _current_index < 0:
		return
	var copy_index: int = _document.duplicate_scenario(_current_index)
	if copy_index < 0:
		return
	_refresh_scenario_list()
	_current_index = copy_index
	_scenario_list.select(_current_index)
	_select_current_scenario()


func _on_delete_pressed() -> void:
	if _current_index < 0:
		return
	_pending_action = "delete"
	_pending_target_index = _current_index
	_confirm_dialog.dialog_text = "删除当前场景？此操作不会自动同步测试指南或文档。"
	_confirm_dialog.popup_centered()


func _on_reload_pressed() -> void:
	_pending_action = "reload"
	_pending_target_index = -1
	_confirm_dialog.dialog_text = "放弃当前所有未保存改动并重新加载 JSON？"
	_confirm_dialog.popup_centered()


func _on_save_pressed() -> void:
	var result: Dictionary = _document.save()
	if not bool(result.get("ok", false)):
		var errors: Array = result.get("errors", [])
		if not errors.is_empty():
			_refresh_validation_view()
			var error_lines: PackedStringArray = PackedStringArray()
			for err_v: Variant in errors:
				error_lines.append(str(err_v))
			_show_alert("保存失败：\n%s" % "\n".join(error_lines))
		else:
			_show_alert(str(result.get("error", "保存失败。")))
		return
	if _editor_interface != null:
		var fs: EditorFileSystem = _editor_interface.get_resource_filesystem()
		if fs != null:
			fs.scan()
	_refresh_scenario_list()
	_select_current_scenario()
	_update_status("已保存到 %s" % _document.get_source_path())


func _on_resize_pressed() -> void:
	if _current_index < 0:
		return
	var result: Dictionary = _document.resize_scenario(_current_index, int(_width_spin.value), int(_height_spin.value))
	if not bool(result.get("ok", false)):
		_show_alert(str(result.get("error", "尺寸调整失败。")))
		return
	_refresh_canvas()
	_refresh_validation_view()
	_update_status("地图尺寸已更新。")


func _on_confirm_pending_action() -> void:
	match _pending_action:
		"delete":
			if _document.delete_scenario(_pending_target_index):
				if _document.get_scenario_count() <= 0:
					_current_index = -1
				else:
					_current_index = mini(_pending_target_index, _document.get_scenario_count() - 1)
				_refresh_scenario_list()
				if _current_index >= 0:
					_scenario_list.select(_current_index)
				_select_current_scenario()
		"reload":
			_document.reload()
			_current_index = 0 if _document.get_scenario_count() > 0 else -1
			_refresh_scenario_list()
			_select_current_scenario()
		"switch":
			_current_index = _pending_target_index
			_scenario_list.select(_current_index)
			_select_current_scenario()
	_pending_action = ""
	_pending_target_index = -1


func _on_scenario_selected(index: int) -> void:
	if _suppress_ui:
		return
	if index == _current_index:
		return
	if _document.is_dirty():
		_pending_action = "switch"
		_pending_target_index = index
		_confirm_dialog.dialog_text = "切换场景会保留内存中的改动，但当前选择状态会重置。继续切换？"
		_confirm_dialog.popup_centered()
		_suppress_ui = true
		if _current_index >= 0 and _current_index < _scenario_list.item_count:
			_scenario_list.select(_current_index)
		_suppress_ui = false
		return
	_current_index = index
	_select_current_scenario()


func _on_map_cell_clicked(col: int, row: int) -> void:
	if _current_index < 0:
		return
	_selected_cell = Vector2i(col, row)
	var mode: String = _current_mode()
	match mode:
		"terrain":
			var terrain_id: String = str(_terrain_option.get_item_metadata(_terrain_option.selected))
			_document.set_cell_terrain(_current_index, col, row, terrain_id)
			_selected_unit_index = -1
			_selected_city_key = ""
		"unit":
			var unit_index: int = _document.get_unit_index_at(_current_index, col, row)
			if unit_index >= 0:
				_selected_unit_index = unit_index
				_selected_city_key = ""
			else:
				var result: Dictionary = _document.add_unit(_current_index, col, row)
				if not bool(result.get("ok", false)):
					_show_alert(str(result.get("error", "无法新增单位。")))
				else:
					_selected_unit_index = int(result.get("unit_index", -1))
					_selected_city_key = ""
		"city":
			var city_key: String = _current_city_target()
			var city_result: Dictionary = _document.place_city(_current_index, city_key, col, row)
			if not bool(city_result.get("ok", false)):
				_show_alert(str(city_result.get("error", "无法放置城池。")))
			else:
				_selected_unit_index = -1
				_selected_city_key = city_key
	_refresh_selection_state()
	_refresh_validation_view()


func _on_scenario_id_changed(text: String) -> void:
	if _suppress_ui or _current_index < 0:
		return
	_document.set_scenario_id(_current_index, text)
	_refresh_scenario_list()
	_refresh_validation_view()


func _on_scenario_name_changed(text: String) -> void:
	if _suppress_ui or _current_index < 0:
		return
	_document.set_scenario_field(_current_index, "name", text)
	_refresh_scenario_list()
	_refresh_validation_view()


func _on_scenario_desc_changed() -> void:
	if _suppress_ui or _current_index < 0:
		return
	_document.set_scenario_field(_current_index, "description", _scenario_desc_edit.text)


func _on_mechanics_changed() -> void:
	if _suppress_ui or _current_index < 0:
		return
	_document.set_scenario_mechanics_from_text(_current_index, _mechanics_edit.text)


func _on_size_spin_changed(_value: float) -> void:
	if _suppress_ui:
		return
	_update_status("已修改尺寸输入，点击“应用尺寸”后生效。")


func _on_player_faction_selected(index: int) -> void:
	if _suppress_ui or _current_index < 0:
		return
	_document.set_scenario_field(_current_index, "player_faction_id", str(_player_faction_option.get_item_metadata(index)))
	_rebuild_unit_faction_options()
	_refresh_validation_view()
	_refresh_canvas()


func _on_enemy_faction_selected(index: int) -> void:
	if _suppress_ui or _current_index < 0:
		return
	_document.set_scenario_field(_current_index, "enemy_faction_id", str(_enemy_faction_option.get_item_metadata(index)))
	_rebuild_unit_faction_options()
	_refresh_validation_view()
	_refresh_canvas()


func _rebuild_unit_faction_options() -> void:
	_unit_faction_option.clear()
	var scenario: Dictionary = _document.get_scenario(_current_index)
	if scenario.is_empty():
		return
	for faction_id: String in [str(scenario.get("player_faction_id", "")), str(scenario.get("enemy_faction_id", ""))]:
		if faction_id.is_empty():
			continue
		_unit_faction_option.add_item("%s（%s）" % [_document.get_faction_name(faction_id), faction_id])
		_unit_faction_option.set_item_metadata(_unit_faction_option.item_count - 1, faction_id)
	if _unit_faction_option.item_count > 0 and _unit_faction_option.selected < 0:
		_unit_faction_option.select(0)


func _on_unit_id_changed(text: String) -> void:
	if _suppress_ui or _current_index < 0 or _selected_unit_index < 0:
		return
	_document.set_unit_field(_current_index, _selected_unit_index, "id", text.strip_edges())
	_refresh_validation_view()
	_refresh_selection_state()


func _on_unit_type_selected(index: int) -> void:
	if _suppress_ui or _current_index < 0 or _selected_unit_index < 0:
		return
	_document.set_unit_field(_current_index, _selected_unit_index, "unit_type_id", str(_unit_type_option.get_item_metadata(index)))
	_refresh_validation_view()
	_refresh_canvas()


func _on_unit_faction_selected(index: int) -> void:
	if _suppress_ui or _current_index < 0 or _selected_unit_index < 0:
		return
	_document.set_unit_field(_current_index, _selected_unit_index, "faction_id", str(_unit_faction_option.get_item_metadata(index)))
	_refresh_validation_view()
	_refresh_canvas()


func _on_delete_unit_pressed() -> void:
	if _current_index < 0 or _selected_unit_index < 0:
		return
	_document.remove_unit(_current_index, _selected_unit_index)
	_selected_unit_index = -1
	_refresh_selection_state()
	_refresh_validation_view()


func _on_city_level_changed(value: float) -> void:
	if _suppress_ui or _current_index < 0 or _selected_city_key.is_empty():
		return
	_document.set_city_level(_current_index, _selected_city_key, int(value))
	_refresh_validation_view()


func _on_city_capital_toggled(toggled_on: bool) -> void:
	if _suppress_ui or _current_index < 0 or _selected_city_key.is_empty():
		return
	_document.set_city_is_capital(_current_index, _selected_city_key, toggled_on)


func _select_option_by_metadata(option: OptionButton, value: String) -> void:
	for i: int in range(option.item_count):
		if str(option.get_item_metadata(i)) == value:
			option.select(i)
			return
	if option.item_count > 0:
		option.select(0)


func _section_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	return label


func _labeled_line_edit(parent: Control, text: String) -> LineEdit:
	var row: VBoxContainer = VBoxContainer.new()
	parent.add_child(row)
	var label: Label = Label.new()
	label.text = text
	row.add_child(label)
	var line_edit: LineEdit = LineEdit.new()
	row.add_child(line_edit)
	return line_edit


func _labeled_text_edit(parent: Control, text: String, min_height: int) -> TextEdit:
	var row: VBoxContainer = VBoxContainer.new()
	parent.add_child(row)
	var label: Label = Label.new()
	label.text = text
	row.add_child(label)
	var text_edit: TextEdit = TextEdit.new()
	text_edit.custom_minimum_size = Vector2(0, min_height)
	row.add_child(text_edit)
	return text_edit


func _labeled_spinbox(parent: Control, text: String, min_value: int, max_value: int) -> SpinBox:
	var row: VBoxContainer = VBoxContainer.new()
	parent.add_child(row)
	var label: Label = Label.new()
	label.text = text
	row.add_child(label)
	var spin_box: SpinBox = SpinBox.new()
	spin_box.min_value = min_value
	spin_box.max_value = max_value
	spin_box.step = 1
	spin_box.rounded = true
	row.add_child(spin_box)
	return spin_box


func _labeled_option_button(parent: Control, text: String) -> OptionButton:
	var row: VBoxContainer = VBoxContainer.new()
	parent.add_child(row)
	var label: Label = Label.new()
	label.text = text
	row.add_child(label)
	var option: OptionButton = OptionButton.new()
	row.add_child(option)
	return option


func _show_alert(message: String) -> void:
	_alert_dialog.dialog_text = message
	_alert_dialog.popup_centered_ratio(0.42)


func _update_status(message: String) -> void:
	var dirty_suffix: String = " | 有未保存改动" if _document.is_dirty() else ""
	_status_label.text = "状态：%s%s" % [message, dirty_suffix]


func _clear_scenario_ui() -> void:
	_suppress_ui = true
	_scenario_id_edit.text = ""
	_scenario_name_edit.text = ""
	_scenario_desc_edit.text = ""
	_mechanics_edit.text = ""
	_width_spin.value = 1
	_height_spin.value = 1
	_suppress_ui = false
	_selected_cell = Vector2i(-1, -1)
	_selected_unit_index = -1
	_selected_city_key = ""
	_map_canvas.clear_scene()
	_validation_output.text = "暂无场景"
	_refresh_selection_state()
	_update_status("暂无场景")
