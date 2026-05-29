extends Panel

## 事件测试面板 — 列出所有事件，点击即可触发用于测试 UI

signal test_panel_closed

var _event_list: VBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build_ui()
	# 包裹到 CanvasLayer（layer=60）以盖住大地图（layer=50）
	var original_parent := get_parent()
	original_parent.remove_child(self)
	var layer := CanvasLayer.new()
	layer.name = "EventTestLayer"
	layer.layer = 60
	layer.add_child(self)
	original_parent.add_child(layer)


func open() -> void:
	_populate_events()
	visible = true


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# 半透明遮罩
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.5)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	# 居中容器
	var container := VBoxContainer.new()
	container.name = "Container"
	container.set_anchors_preset(Control.PRESET_CENTER)
	container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	container.grow_vertical = Control.GROW_DIRECTION_BOTH
	container.custom_minimum_size = Vector2(600, 500)
	container.offset_left = -300
	container.offset_right = 300
	container.offset_top = -280
	container.offset_bottom = 280
	container.add_theme_constant_override("separation", 6)
	add_child(container)

	# 标题栏
	var title_bar := HBoxContainer.new()
	container.add_child(title_bar)

	var title := Label.new()
	title.text = "事件测试面板"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1, 0.92, 0.7, 1))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(title)

	var close_btn := SkirmishTileTextures.styled_button("关闭")
	close_btn.pressed.connect(_on_close_pressed)
	title_bar.add_child(close_btn)

	# 提示
	var hint := Label.new()
	hint.text = "点击「触发」按钮直接打开对应事件的弹窗"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	container.add_child(hint)

	# 事件列表（滚动）
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(scroll)

	_event_list = VBoxContainer.new()
	_event_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_event_list.add_theme_constant_override("separation", 3)
	scroll.add_child(_event_list)


func _populate_events() -> void:
	for ch in _event_list.get_children():
		ch.queue_free()

	var events: Array = DataManager.get_all_events()
	for evt in events:
		var event_id: String = str(evt.get("id", ""))
		var title: String = str(evt.get("title", ""))
		var category: String = str(evt.get("category", ""))
		var has_options: bool = evt.get("options") != null

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_event_list.add_child(row)

		# 类别标签
		var cat_label := Label.new()
		cat_label.text = "[%s]" % _category_display(category)
		cat_label.add_theme_font_size_override("font_size", 12)
		cat_label.add_theme_color_override("font_color", _category_color(category))
		cat_label.custom_minimum_size = Vector2(70, 0)
		row.add_child(cat_label)

		# 事件标题
		var title_label := Label.new()
		title_label.text = title
		title_label.add_theme_font_size_override("font_size", 14)
		title_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
		title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(title_label)

		# 选项标记
		var opt_label := Label.new()
		opt_label.text = "有选项" if has_options else "无选项"
		opt_label.add_theme_font_size_override("font_size", 11)
		opt_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6, 1) if has_options else Color(0.6, 0.6, 0.6, 1))
		row.add_child(opt_label)

		# 触发按钮
		var trigger_btn := SkirmishTileTextures.styled_button("触发")
		trigger_btn.add_theme_font_size_override("font_size", 13)
		trigger_btn.pressed.connect(_on_trigger_pressed.bind(evt))
		row.add_child(trigger_btn)


func _on_trigger_pressed(evt: Dictionary) -> void:
	SignalBus.event_triggered.emit(evt)


func _on_close_pressed() -> void:
	visible = false
	test_panel_closed.emit()


func _category_display(category: String) -> String:
	match category:
		"economy": return "经济"
		"military": return "军事"
		"morale": return "民心"
		"season": return "季节"
		"politics": return "政治"
		"diplomacy": return "外交"
		"school": return "学派"
		"special": return "特殊"
		_: return category


func _category_color(category: String) -> Color:
	match category:
		"economy": return Color(0.8, 0.75, 0.4)
		"military": return Color(0.8, 0.4, 0.4)
		"morale": return Color(0.5, 0.7, 0.9)
		"season": return Color(0.5, 0.85, 0.5)
		"politics": return Color(0.7, 0.6, 0.85)
		"diplomacy": return Color(0.85, 0.7, 0.5)
		"school": return Color(0.6, 0.85, 0.85)
		"special": return Color(0.9, 0.6, 0.7)
		_: return Color(0.7, 0.7, 0.7)
