@tool
extends Control

const DocumentScript := preload("res://addons/big_map_editor/big_map_document.gd")
const CanvasScript := preload("res://addons/big_map_editor/big_map_editor_canvas.gd")
const HexAxial := preload("res://scripts/systems/hex_axial.gd")

var _editor_interface: EditorInterface = null
var _document: BigMapDocument = DocumentScript.new()
var _selected_city_index: int = -1
var _selected_cell: Vector2i = Vector2i(-1, -1)
var _selected_axial: Vector2i = Vector2i.ZERO
var _suppress_ui: bool = false
var _pending_action: String = ""
var _zoom_level: float = 1.0
var _show_grid: bool = true
var _show_political: bool = true

var _city_search_edit: LineEdit
var _city_list: ItemList
var _canvas: BigMapEditorCanvas
var _mode_option: OptionButton
var _terrain_option: OptionButton
var _control_option: OptionButton
var _show_grid_check: CheckBox
var _show_political_check: CheckBox
var _zoom_label: Label
var _hover_label: Label
var _undo_button: Button
var _redo_button: Button
var _map_info_label: Label
var _map_width_spin: SpinBox
var _map_height_spin: SpinBox
var _map_resize_button: Button
var _cell_info_label: Label
var _city_id_edit: LineEdit
var _city_name_edit: LineEdit
var _city_faction_option: OptionButton
var _city_q_spin: SpinBox
var _city_r_spin: SpinBox
var _city_radius_spin: SpinBox
var _city_resource_edit: LineEdit
var _city_capital_check: CheckBox
var _city_development_spin: SpinBox
var _city_level_spin: SpinBox
var _city_population_spin: SpinBox
var _validation_output: RichTextLabel
var _status_label: Label
var _city_form: VBoxContainer
var _alert_dialog: AcceptDialog
var _confirm_dialog: ConfirmationDialog
var _map_scroll: ScrollContainer
var _hover_cell: Vector2i = Vector2i(-1, -1)
var _hover_axial: Vector2i = Vector2i.ZERO


func set_editor_interface(editor_interface: EditorInterface) -> void:
	_editor_interface = editor_interface


func _ready() -> void:
	_build_ui()
	_connect_ui()
	_load_document()


func has_unsaved_changes() -> bool:
	return _document != null and _document.is_dirty()


func _build_ui() -> void:
	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_EXPAND_FILL

	var root: HBoxContainer = HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 0.0
	root.offset_top = 0.0
	root.offset_right = 0.0
	root.offset_bottom = 0.0
	root.size_flags_horizontal = SIZE_EXPAND_FILL
	root.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(root)

	var left_panel: VBoxContainer = VBoxContainer.new()
	left_panel.custom_minimum_size = Vector2(260, 0)
	left_panel.size_flags_horizontal = SIZE_FILL
	left_panel.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_child(left_panel)

	var left_title: Label = Label.new()
	left_title.text = "城市列表"
	left_panel.add_child(left_title)

	_city_search_edit = LineEdit.new()
	_city_search_edit.placeholder_text = "搜索城市 / 势力 / ID"
	_city_search_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	left_panel.add_child(_city_search_edit)

	_city_list = ItemList.new()
	_city_list.size_flags_horizontal = SIZE_EXPAND_FILL
	_city_list.size_flags_vertical = SIZE_EXPAND_FILL
	_city_list.custom_minimum_size = Vector2(0, 320)
	_city_list.select_mode = ItemList.SELECT_SINGLE
	_city_list.add_theme_color_override("font_color", Color(0.93, 0.94, 0.96, 1.0))
	_city_list.add_theme_color_override("font_selected_color", Color(1.0, 1.0, 1.0, 1.0))
	left_panel.add_child(_city_list)

	var left_buttons: GridContainer = GridContainer.new()
	left_buttons.columns = 2
	left_buttons.size_flags_horizontal = SIZE_EXPAND_FILL
	left_panel.add_child(left_buttons)
	for config: Dictionary in [
		{"name": "NewBtn", "text": "新建"},
		{"name": "CopyBtn", "text": "复制"},
		{"name": "DeleteBtn", "text": "删除"},
		{"name": "SaveBtn", "text": "保存"},
		{"name": "ReloadBtn", "text": "重载"},
	]:
		var button: Button = Button.new()
		button.name = str(config["name"])
		button.text = str(config["text"])
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		left_buttons.add_child(button)

	var center_right_split: HSplitContainer = HSplitContainer.new()
	center_right_split.size_flags_horizontal = SIZE_EXPAND_FILL
	center_right_split.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_child(center_right_split)

	var center_panel: VBoxContainer = VBoxContainer.new()
	center_panel.size_flags_horizontal = SIZE_EXPAND_FILL
	center_panel.size_flags_vertical = SIZE_EXPAND_FILL
	center_right_split.add_child(center_panel)

	var toolbar: HBoxContainer = HBoxContainer.new()
	toolbar.size_flags_horizontal = SIZE_EXPAND_FILL
	center_panel.add_child(toolbar)

	toolbar.add_child(_toolbar_label("模式"))
	_mode_option = OptionButton.new()
	_mode_option.add_item("地形")
	_mode_option.set_item_metadata(0, "terrain")
	_mode_option.add_item("城市")
	_mode_option.set_item_metadata(1, "city")
	_mode_option.add_item("统治范围")
	_mode_option.set_item_metadata(2, "control")
	toolbar.add_child(_mode_option)

	toolbar.add_child(_toolbar_label("地形笔刷"))
	_terrain_option = OptionButton.new()
	toolbar.add_child(_terrain_option)

	toolbar.add_child(_toolbar_label("统治画笔"))
	_control_option = OptionButton.new()
	toolbar.add_child(_control_option)

	_show_grid_check = CheckBox.new()
	_show_grid_check.text = "网格"
	_show_grid_check.button_pressed = true
	toolbar.add_child(_show_grid_check)

	_show_political_check = CheckBox.new()
	_show_political_check.text = "政治叠加"
	_show_political_check.button_pressed = true
	toolbar.add_child(_show_political_check)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	toolbar.add_child(spacer)

	_undo_button = Button.new()
	_undo_button.text = "撤回"
	toolbar.add_child(_undo_button)
	_redo_button = Button.new()
	_redo_button.text = "还原"
	toolbar.add_child(_redo_button)

	_hover_label = Label.new()
	_hover_label.text = "悬停：-"
	toolbar.add_child(_hover_label)

	var zoom_out: Button = Button.new()
	zoom_out.name = "ZoomOutBtn"
	zoom_out.text = "-"
	toolbar.add_child(zoom_out)
	_zoom_label = Label.new()
	_zoom_label.text = "100%"
	toolbar.add_child(_zoom_label)
	var zoom_in: Button = Button.new()
	zoom_in.name = "ZoomInBtn"
	zoom_in.text = "+"
	toolbar.add_child(zoom_in)
	var zoom_reset: Button = Button.new()
	zoom_reset.name = "ZoomResetBtn"
	zoom_reset.text = "重置"
	toolbar.add_child(zoom_reset)

	_map_scroll = ScrollContainer.new()
	_map_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	_map_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	_map_scroll.custom_minimum_size = Vector2(720, 420)
	_map_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_map_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	center_panel.add_child(_map_scroll)

	_canvas = CanvasScript.new()
	_map_scroll.add_child(_canvas)

	_status_label = Label.new()
	_status_label.text = "状态：未加载"
	center_panel.add_child(_status_label)

	var right_scroll: ScrollContainer = ScrollContainer.new()
	right_scroll.custom_minimum_size = Vector2(380, 0)
	right_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	center_right_split.add_child(right_scroll)

	var right_panel: VBoxContainer = VBoxContainer.new()
	right_panel.size_flags_horizontal = SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = SIZE_EXPAND_FILL
	right_panel.custom_minimum_size = Vector2(360, 700)
	right_scroll.add_child(right_panel)

	right_panel.add_child(_section_label("地图信息"))
	_map_info_label = _info_label(right_panel)
	_map_width_spin = _labeled_spinbox(right_panel, "地图宽度", 1, 300)
	_map_height_spin = _labeled_spinbox(right_panel, "地图高度", 1, 300)
	_map_resize_button = Button.new()
	_map_resize_button.text = "应用地图尺寸"
	right_panel.add_child(_map_resize_button)

	right_panel.add_child(_section_label("当前格"))
	_cell_info_label = _info_label(right_panel)

	right_panel.add_child(_section_label("城市属性"))
	_city_form = VBoxContainer.new()
	right_panel.add_child(_city_form)
	_city_id_edit = _labeled_line_edit(_city_form, "ID")
	_city_name_edit = _labeled_line_edit(_city_form, "名称")
	_city_faction_option = _labeled_option_button(_city_form, "势力")
	_city_q_spin = _labeled_spinbox(_city_form, "地图列 q", 0, 300)
	_city_r_spin = _labeled_spinbox(_city_form, "地图行 r", 0, 300)
	_city_radius_spin = _labeled_spinbox(_city_form, "辖区半径", 0, 20)
	_city_resource_edit = _labeled_line_edit(_city_form, "特产（留空=null）")
	_city_capital_check = CheckBox.new()
	_city_capital_check.text = "首都"
	_city_form.add_child(_city_capital_check)
	_city_development_spin = _labeled_spinbox(_city_form, "发展度", 0, 999)
	_city_level_spin = _labeled_spinbox(_city_form, "城市等级", 0, 99)
	_city_population_spin = _labeled_spinbox(_city_form, "初始人口", 0, 999)

	right_panel.add_child(_section_label("校验结果"))
	_validation_output = RichTextLabel.new()
	_validation_output.custom_minimum_size = Vector2(0, 260)
	_validation_output.fit_content = true
	_validation_output.scroll_active = true
	right_panel.add_child(_validation_output)

	_alert_dialog = AcceptDialog.new()
	_alert_dialog.title = "提示"
	add_child(_alert_dialog)

	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.title = "未保存改动"
	_confirm_dialog.dialog_text = "当前有未保存改动，是否放弃？"
	add_child(_confirm_dialog)


func _connect_ui() -> void:
	_city_search_edit.text_changed.connect(_refresh_city_list)
	_city_list.item_selected.connect(_on_city_list_selected)
	_canvas.cell_clicked.connect(_on_canvas_cell_clicked)
	_canvas.cell_hovered.connect(_on_canvas_cell_hovered)
	_canvas.hover_exited.connect(_on_canvas_hover_exited)
	_mode_option.item_selected.connect(_refresh_canvas)
	_terrain_option.item_selected.connect(_refresh_canvas)
	_control_option.item_selected.connect(_refresh_canvas)
	_show_grid_check.toggled.connect(_on_show_grid_toggled)
	_show_political_check.toggled.connect(_on_show_political_toggled)
	_find_button("NewBtn").pressed.connect(_on_new_city_pressed)
	_find_button("CopyBtn").pressed.connect(_on_copy_city_pressed)
	_find_button("DeleteBtn").pressed.connect(_on_delete_city_pressed)
	_find_button("SaveBtn").pressed.connect(_on_save_pressed)
	_find_button("ReloadBtn").pressed.connect(_on_reload_pressed)
	_find_button("ZoomOutBtn").pressed.connect(func() -> void: _apply_zoom(_zoom_level - 0.15))
	_find_button("ZoomInBtn").pressed.connect(func() -> void: _apply_zoom(_zoom_level + 0.15))
	_find_button("ZoomResetBtn").pressed.connect(func() -> void: _apply_zoom(1.0))
	_undo_button.pressed.connect(_on_undo_pressed)
	_redo_button.pressed.connect(_on_redo_pressed)
	_map_resize_button.pressed.connect(_on_resize_map_pressed)
	_confirm_dialog.confirmed.connect(_on_confirm_pending_action)

	_map_width_spin.value_changed.connect(_on_map_size_spin_changed)
	_map_height_spin.value_changed.connect(_on_map_size_spin_changed)
	_city_id_edit.text_changed.connect(_on_city_id_changed)
	_city_name_edit.text_changed.connect(_on_city_name_changed)
	_city_faction_option.item_selected.connect(_on_city_faction_selected)
	_city_q_spin.value_changed.connect(_on_city_position_changed)
	_city_r_spin.value_changed.connect(_on_city_position_changed)
	_city_radius_spin.value_changed.connect(_on_city_radius_changed)
	_city_resource_edit.text_changed.connect(_on_city_resource_changed)
	_city_capital_check.toggled.connect(_on_city_capital_toggled)
	_city_development_spin.value_changed.connect(_on_city_development_changed)
	_city_level_spin.value_changed.connect(_on_city_level_changed)
	_city_population_spin.value_changed.connect(_on_city_population_changed)


func _load_document() -> void:
	if not _document.load_all():
		_show_alert("无法加载大地图数据文件。")
		return
	_rebuild_options()
	_selected_city_index = 0 if _document.get_city_count() > 0 else -1
	_refresh_selection_from_city()
	_refresh_all("已载入大地图数据")


func _rebuild_options() -> void:
	_suppress_ui = true
	_terrain_option.clear()
	for terrain_info: Dictionary in _document.get_terrain_options():
		_terrain_option.add_item("%s（%s）" % [str(terrain_info["name"]), str(terrain_info["id"])])
		_terrain_option.set_item_metadata(_terrain_option.item_count - 1, str(terrain_info["id"]))
	_control_option.clear()
	for faction_info: Dictionary in _document.get_faction_options(true):
		_control_option.add_item("%s（%s）" % [str(faction_info["name"]), str(faction_info["id"])])
		_control_option.set_item_metadata(_control_option.item_count - 1, str(faction_info["id"]))
	_control_option.add_item("无归属（覆盖）")
	_control_option.set_item_metadata(_control_option.item_count - 1, "__unowned__")
	_control_option.add_item("清除覆盖")
	_control_option.set_item_metadata(_control_option.item_count - 1, "__clear__")
	_city_faction_option.clear()
	for faction_info2: Dictionary in _document.get_faction_options(true):
		_city_faction_option.add_item("%s（%s）" % [str(faction_info2["name"]), str(faction_info2["id"])])
		_city_faction_option.set_item_metadata(_city_faction_option.item_count - 1, str(faction_info2["id"]))
	if _terrain_option.item_count > 0:
		_terrain_option.select(0)
	if _control_option.item_count > 0:
		_control_option.select(0)
	if _mode_option.item_count > 0:
		_mode_option.select(0)
	_suppress_ui = false


func _refresh_all(status_text: String = "") -> void:
	_refresh_city_list(_city_search_edit.text)
	_refresh_map_info()
	_refresh_cell_info()
	_refresh_city_form()
	_refresh_validation()
	_refresh_canvas()
	_refresh_history_buttons()
	if not status_text.is_empty():
		_update_status(status_text)


func _refresh_city_list(_text: String = "") -> void:
	var selected_id: String = str(_document.get_city(_selected_city_index).get("id", "")) if _selected_city_index >= 0 else ""
	_city_list.clear()
	var keyword: String = _city_search_edit.text.strip_edges().to_lower()
	for city_index: int in range(_document.get_city_count()):
		var city: Dictionary = _document.get_city(city_index)
		var haystack: String = "%s %s %s" % [
			str(city.get("id", "")),
			str(city.get("name", "")),
			_document.get_faction_name(str(city.get("faction_id", ""))),
		]
		if not keyword.is_empty() and not haystack.to_lower().contains(keyword):
			continue
		_city_list.add_item(_document.get_city_list_label(city_index))
		_city_list.set_item_metadata(_city_list.item_count - 1, city_index)
		if str(city.get("id", "")) == selected_id:
			_city_list.select(_city_list.item_count - 1)


func _refresh_map_info() -> void:
	_map_info_label.text = "地图尺寸：%d × %d\n城市数量：%d\n覆盖层：%d 项" % [
		_document.get_map_width(),
		_document.get_map_height(),
		_document.get_city_count(),
		_document.get_overrides().size(),
	]
	_suppress_ui = true
	_map_width_spin.value = _document.get_map_width()
	_map_height_spin.value = _document.get_map_height()
	_suppress_ui = false


func _refresh_cell_info() -> void:
	var display_cell: Vector2i = _hover_cell if _hover_cell.x >= 0 else _selected_cell
	var display_axial: Vector2i = _hover_axial if _hover_cell.x >= 0 else _selected_axial
	if display_cell.x < 0 or display_cell.y < 0:
		_cell_info_label.text = "未选择格子"
		_hover_label.text = "悬停：-"
		return
	var terrain_id: String = _document.get_terrain_at_offset(display_cell.x, display_cell.y)
	var owner_id: String = _document.get_resolved_owner_at_offset(display_cell.x, display_cell.y)
	var override_owner: Variant = _document.get_override_owner_at_axial(display_axial.x, display_axial.y)
	var override_text: String = "未设置"
	if override_owner == null:
		override_text = "无归属（覆盖）"
	elif override_owner != "__missing__":
		override_text = _document.get_faction_name(str(override_owner))
	_hover_label.text = "悬停：偏移 %d,%d｜轴向 %d,%d" % [display_cell.x, display_cell.y, display_axial.x, display_axial.y]
	_cell_info_label.text = "偏移：%d, %d\n轴向：%d, %d\n地形：%s（%s）\n统治：%s\n覆盖：%s" % [
		display_cell.x,
		display_cell.y,
		display_axial.x,
		display_axial.y,
		_document.get_terrain_name(terrain_id),
		terrain_id,
		_document.get_faction_name(owner_id),
		override_text,
	]


func _refresh_city_form() -> void:
	var city: Dictionary = _document.get_city(_selected_city_index)
	_city_form.visible = not city.is_empty()
	if city.is_empty():
		return
	_suppress_ui = true
	_city_id_edit.text = str(city.get("id", ""))
	_city_name_edit.text = str(city.get("name", ""))
	_select_option_by_metadata(_city_faction_option, str(city.get("faction_id", "")))
	_city_q_spin.value = int(city.get("hex_q", 0))
	_city_r_spin.value = int(city.get("hex_r", 0))
	_city_radius_spin.value = int(city.get("jurisdiction_radius", 0))
	var special_resource: Variant = city.get("special_resource", null)
	_city_resource_edit.text = "" if special_resource == null else str(special_resource)
	_city_capital_check.button_pressed = bool(city.get("is_capital", false))
	_city_development_spin.value = int(city.get("development", 0))
	_city_level_spin.value = int(city.get("city_level", 0))
	_city_population_spin.value = int(city.get("initial_population", 0))
	_suppress_ui = false


func _refresh_validation() -> void:
	var errors: Array[String] = _document.validate_document()
	_validation_output.clear()
	if errors.is_empty():
		_validation_output.append_text("校验通过。")
		return
	for line: String in errors:
		_validation_output.append_text("- %s\n" % line)


func _refresh_canvas(_arg: Variant = null) -> void:
	if _document == null:
		return
	_canvas.set_view(
		_document,
		_selected_cell,
		_selected_city_index,
		_current_mode(),
		_zoom_level,
		_show_grid,
		_show_political
	)
	_zoom_label.text = "%d%%" % int(_zoom_level * 100.0)


func _refresh_selection_from_city() -> void:
	var city: Dictionary = _document.get_city(_selected_city_index)
	if city.is_empty():
		if _document.get_map_width() > 0 and _document.get_map_height() > 0:
			_selected_cell = Vector2i(0, 0)
			_selected_axial = HexAxial.offset_odd_r_to_axial(0, 0)
		return
	_selected_cell = Vector2i(int(city.get("hex_q", 0)), int(city.get("hex_r", 0)))
	_selected_axial = HexAxial.offset_odd_r_to_axial(_selected_cell.x, _selected_cell.y)


func _on_city_list_selected(item_index: int) -> void:
	var city_index: int = int(_city_list.get_item_metadata(item_index))
	_selected_city_index = city_index
	_refresh_selection_from_city()
	_refresh_all("已选择城市：%s" % str(_document.get_city(city_index).get("name", "")))
	call_deferred("_center_preview_on_selected_city")


func _on_canvas_cell_clicked(col: int, row: int, axial_q: int, axial_r: int) -> void:
	_selected_cell = Vector2i(col, row)
	_selected_axial = Vector2i(axial_q, axial_r)
	match _current_mode():
		"terrain":
			var terrain_id: String = _selected_option_metadata(_terrain_option)
			if not terrain_id.is_empty():
				_document.set_terrain_at_offset(col, row, terrain_id)
		"city":
			var city_index: int = _document.get_city_index_at_axial(axial_q, axial_r)
			if city_index >= 0:
				_selected_city_index = city_index
			elif _selected_city_index >= 0:
				_document.move_city(_selected_city_index, axial_q, axial_r)
		"control":
			var brush: String = _selected_option_metadata(_control_option)
			if brush == "__clear__":
				_document.clear_override(axial_q, axial_r)
			elif brush == "__unowned__":
				_document.set_override_owner(axial_q, axial_r, null)
			elif not brush.is_empty():
				_document.set_override_owner(axial_q, axial_r, brush)
	if _current_mode() == "city":
		_refresh_selection_from_city()
	_refresh_all()


func _on_canvas_cell_hovered(col: int, row: int, axial_q: int, axial_r: int) -> void:
	_hover_cell = Vector2i(col, row)
	_hover_axial = Vector2i(axial_q, axial_r)
	_refresh_cell_info()


func _on_canvas_hover_exited() -> void:
	_hover_cell = Vector2i(-1, -1)
	_refresh_cell_info()


func _on_show_grid_toggled(enabled: bool) -> void:
	_show_grid = enabled
	_refresh_canvas()


func _on_show_political_toggled(enabled: bool) -> void:
	_show_political = enabled
	_refresh_canvas()


func _on_new_city_pressed() -> void:
	_selected_city_index = _document.create_city()
	_refresh_selection_from_city()
	_refresh_all("已新建城市")
	call_deferred("_center_preview_on_selected_city")


func _on_copy_city_pressed() -> void:
	if _selected_city_index < 0:
		return
	_selected_city_index = _document.duplicate_city(_selected_city_index)
	_refresh_selection_from_city()
	_refresh_all("已复制城市")
	call_deferred("_center_preview_on_selected_city")


func _on_delete_city_pressed() -> void:
	if _selected_city_index < 0:
		return
	_document.delete_city(_selected_city_index)
	_selected_city_index = mini(_selected_city_index, _document.get_city_count() - 1)
	_refresh_selection_from_city()
	_refresh_all("已删除城市")


func _on_save_pressed() -> void:
	var result: Dictionary = _document.save_all()
	if not bool(result.get("ok", false)):
		_refresh_validation()
		_show_alert(str(result.get("error", "保存失败。")))
		return
	if _editor_interface != null:
		var fs: EditorFileSystem = _editor_interface.get_resource_filesystem()
		if fs != null:
			fs.scan()
	_refresh_all("保存成功")


func _on_reload_pressed() -> void:
	if _document.is_dirty():
		_pending_action = "reload"
		_confirm_dialog.popup_centered()
		return
	_reload_document_now()


func _on_confirm_pending_action() -> void:
	if _pending_action == "reload":
		_reload_document_now()
	_pending_action = ""


func _reload_document_now() -> void:
	if not _document.load_all():
		_show_alert("重载失败。")
		return
	if _selected_city_index >= _document.get_city_count():
		_selected_city_index = _document.get_city_count() - 1
	_refresh_selection_from_city()
	_refresh_all("已重载")


func _on_resize_map_pressed() -> void:
	var result: Dictionary = _document.resize_map(int(_map_width_spin.value), int(_map_height_spin.value))
	if not bool(result.get("ok", false)):
		_show_alert(str(result.get("error", "地图尺寸调整失败。")))
		_refresh_map_info()
		return
	_selected_city_index = _document.get_city_index_at_axial(_selected_axial.x, _selected_axial.y)
	if _selected_city_index < 0 and _document.get_city_count() > 0:
		_selected_city_index = 0
	_refresh_selection_from_city()
	_refresh_all("已调整地图尺寸")
	call_deferred("_center_preview_on_selected_city")


func _on_undo_pressed() -> void:
	if not _document.undo():
		return
	_clamp_selection_after_history()
	_refresh_all("已撤回上一步操作")
	call_deferred("_center_preview_on_selected_city")


func _on_redo_pressed() -> void:
	if not _document.redo():
		return
	_clamp_selection_after_history()
	_refresh_all("已还原上一步操作")
	call_deferred("_center_preview_on_selected_city")


func _on_map_size_spin_changed(_value: float) -> void:
	if _suppress_ui:
		return
	_update_status("地图尺寸待应用")


func _on_city_id_changed(new_text: String) -> void:
	if _suppress_ui or _selected_city_index < 0:
		return
	_document.set_city_field(_selected_city_index, "id", new_text.strip_edges())
	_refresh_all()


func _on_city_name_changed(new_text: String) -> void:
	if _suppress_ui or _selected_city_index < 0:
		return
	_document.set_city_field(_selected_city_index, "name", new_text)
	_refresh_all()


func _on_city_faction_selected(_index: int) -> void:
	if _suppress_ui or _selected_city_index < 0:
		return
	_document.set_city_field(_selected_city_index, "faction_id", _selected_option_metadata(_city_faction_option))
	_refresh_all()


func _on_city_position_changed(_value: float) -> void:
	if _suppress_ui or _selected_city_index < 0:
		return
	_document.set_city_field(_selected_city_index, "hex_q", int(_city_q_spin.value))
	_document.set_city_field(_selected_city_index, "hex_r", int(_city_r_spin.value))
	_refresh_selection_from_city()
	_refresh_all()


func _on_city_radius_changed(value: float) -> void:
	if _suppress_ui or _selected_city_index < 0:
		return
	_document.set_city_field(_selected_city_index, "jurisdiction_radius", int(value))
	_refresh_all()


func _on_city_resource_changed(new_text: String) -> void:
	if _suppress_ui or _selected_city_index < 0:
		return
	_document.set_city_field(_selected_city_index, "special_resource", null if new_text.strip_edges().is_empty() else new_text.strip_edges())
	_refresh_all()


func _on_city_capital_toggled(enabled: bool) -> void:
	if _suppress_ui or _selected_city_index < 0:
		return
	_document.set_city_field(_selected_city_index, "is_capital", enabled)
	_refresh_all()


func _on_city_development_changed(value: float) -> void:
	if _suppress_ui or _selected_city_index < 0:
		return
	_document.set_city_field(_selected_city_index, "development", int(value))
	_refresh_all()


func _on_city_level_changed(value: float) -> void:
	if _suppress_ui or _selected_city_index < 0:
		return
	_document.set_city_field(_selected_city_index, "city_level", int(value))
	_refresh_all()


func _on_city_population_changed(value: float) -> void:
	if _suppress_ui or _selected_city_index < 0:
		return
	_document.set_city_field(_selected_city_index, "initial_population", int(value))
	_refresh_all()


func _apply_zoom(new_zoom: float) -> void:
	_zoom_level = clampf(new_zoom, 0.4, 2.4)
	_refresh_canvas()
	call_deferred("_center_preview_on_selected_city")


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		if key_event.ctrl_pressed and key_event.keycode == KEY_Z:
			_on_undo_pressed()
			accept_event()
		elif key_event.ctrl_pressed and key_event.keycode == KEY_Y:
			_on_redo_pressed()
			accept_event()


func _current_mode() -> String:
	return _selected_option_metadata(_mode_option)


func _selected_option_metadata(option: OptionButton) -> String:
	if option.selected < 0:
		return ""
	return str(option.get_item_metadata(option.selected))


func _select_option_by_metadata(option: OptionButton, metadata: String) -> void:
	for item_index: int in range(option.item_count):
		if str(option.get_item_metadata(item_index)) == metadata:
			option.select(item_index)
			return


func _find_button(name: String) -> Button:
	return find_child(name, true, false) as Button


func _section_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	return label


func _toolbar_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	return label


func _info_label(parent: Control) -> Label:
	var label: Label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func _labeled_line_edit(parent: Control, label_text: String) -> LineEdit:
	var label: Label = Label.new()
	label.text = label_text
	parent.add_child(label)
	var edit: LineEdit = LineEdit.new()
	parent.add_child(edit)
	return edit


func _labeled_option_button(parent: Control, label_text: String) -> OptionButton:
	var label: Label = Label.new()
	label.text = label_text
	parent.add_child(label)
	var option: OptionButton = OptionButton.new()
	parent.add_child(option)
	return option


func _labeled_spinbox(parent: Control, label_text: String, min_value: float, max_value: float) -> SpinBox:
	var label: Label = Label.new()
	label.text = label_text
	parent.add_child(label)
	var spin: SpinBox = SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = 1.0
	parent.add_child(spin)
	return spin


func _update_status(text: String) -> void:
	_status_label.text = "状态：%s%s" % [text, " *" if _document.is_dirty() else ""]


func _show_alert(text: String) -> void:
	_alert_dialog.dialog_text = text
	_alert_dialog.popup_centered()


func _refresh_history_buttons() -> void:
	if _undo_button != null:
		_undo_button.disabled = not _document.can_undo()
	if _redo_button != null:
		_redo_button.disabled = not _document.can_redo()


func _clamp_selection_after_history() -> void:
	if _selected_city_index >= _document.get_city_count():
		_selected_city_index = _document.get_city_count() - 1
	if _selected_city_index < 0 and _document.get_city_count() > 0:
		_selected_city_index = 0
	_refresh_selection_from_city()


func _center_preview_on_selected_city() -> void:
	if _map_scroll == null or _canvas == null or _selected_city_index < 0:
		return
	var city: Dictionary = _document.get_city(_selected_city_index)
	if city.is_empty():
		return
	var offset: Vector2i = Vector2i(int(city.get("hex_q", 0)), int(city.get("hex_r", 0)))
	var cell_top_left: Vector2 = _canvas.call("_cell_top_left", offset.x, offset.y)
	var target_center: Vector2 = cell_top_left + Vector2(_canvas.call("_radius"), sqrt(3.0) * float(_canvas.call("_radius")) * 0.5)
	var viewport_size: Vector2 = _map_scroll.size
	_map_scroll.scroll_horizontal = maxi(0, int(target_center.x - viewport_size.x * 0.5))
	_map_scroll.scroll_vertical = maxi(0, int(target_center.y - viewport_size.y * 0.5))
