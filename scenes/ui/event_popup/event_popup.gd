extends Panel

## 事件弹窗 — 显示事件插画、描述、选项
##
## 监听 SignalBus.event_triggered，弹出事件 UI。
## 选择选项后调用 EventManager.resolve_event_choice()。

signal event_popup_closed

var _event_data: Dictionary = {}
var _panel: Panel
var _illustration: TextureRect
var _title_label: Label
var _desc_label: RichTextLabel
var _options_container: VBoxContainer
var _effect_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build_ui()
	# 包裹到 CanvasLayer（layer=100）以盖住大地图（layer=50）
	var original_parent := get_parent()
	original_parent.remove_child(self)
	var layer := CanvasLayer.new()
	layer.name = "EventPopupLayer"
	layer.layer = 100
	layer.add_child(self)
	original_parent.add_child(layer)
	SignalBus.event_triggered.connect(_on_event_triggered)


func _build_ui() -> void:
	# 内部 Panel 承载全部 UI
	_panel = Panel.new()
	_panel.name = "InnerPanel"
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	# 半透明遮罩 — 拦截点击，防止穿透到下层 UI
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_child(dim)

	# 居中弹窗容器
	var popup := PanelContainer.new()
	popup.name = "Popup"
	popup.set_anchors_preset(Control.PRESET_CENTER)
	popup.grow_horizontal = Control.GROW_DIRECTION_BOTH
	popup.grow_vertical = Control.GROW_DIRECTION_BOTH
	popup.custom_minimum_size = Vector2(520, 400)
	popup.offset_left = -260
	popup.offset_right = 260
	popup.offset_top = -200
	popup.offset_bottom = 200
	_panel.add_child(popup)

	# 弹窗背景图
	var bg_tex: Texture2D = SkirmishTileTextures.panel_texture("event_popup")
	if bg_tex != null:
		var bg := TextureRect.new()
		bg.name = "Background"
		bg.texture = bg_tex
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		popup.add_child(bg)

	var popup_vbox := VBoxContainer.new()
	popup_vbox.name = "PopupVBox"
	popup_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup_vbox.add_theme_constant_override("separation", 10)
	popup.add_child(popup_vbox)

	# 事件插画
	_illustration = TextureRect.new()
	_illustration.name = "Illustration"
	_illustration.custom_minimum_size = Vector2(480, 260)
	_illustration.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_illustration.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	popup_vbox.add_child(_illustration)

	# 标题
	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", Color(1, 0.92, 0.7, 1))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup_vbox.add_child(_title_label)

	# 描述
	_desc_label = RichTextLabel.new()
	_desc_label.name = "Description"
	_desc_label.bbcode_enabled = true
	_desc_label.fit_content = true
	_desc_label.custom_minimum_size = Vector2(480, 60)
	_desc_label.add_theme_font_size_override("normal_font_size", 15)
	_desc_label.add_theme_color_override("default_color", Color(0.9, 0.88, 0.82, 1))
	popup_vbox.add_child(_desc_label)

	# 选项/按钮区
	_options_container = VBoxContainer.new()
	_options_container.name = "Options"
	_options_container.add_theme_constant_override("separation", 6)
	popup_vbox.add_child(_options_container)

	# 效果提示标签（悬停选项时显示）
	_effect_label = Label.new()
	_effect_label.name = "EffectLabel"
	_effect_label.add_theme_font_size_override("font_size", 13)
	_effect_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7, 1))
	_effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_effect_label.text = ""
	popup_vbox.add_child(_effect_label)


func _on_event_triggered(event_data: Dictionary) -> void:
	_event_data = event_data
	_show_event()


func _show_event() -> void:
	var event_id: String = str(_event_data.get("id", ""))
	var category: String = str(_event_data.get("category", ""))
	var title: String = str(_event_data.get("title", "未知事件"))
	var desc: String = str(_event_data.get("description", ""))

	# 设置插画
	var tex: Texture2D = SkirmishTileTextures.event_texture(event_id, category)
	_illustration.texture = tex

	# 设置文本
	_title_label.text = title
	_desc_label.text = desc

	# 清空旧选项
	for ch in _options_container.get_children():
		ch.queue_free()

	# 构建选项按钮
	var options: Variant = _event_data.get("options")
	if options != null and options is Array and options.size() > 0:
		for opt in options:
			var opt_text: String = str(opt.get("text", opt.get("id", "")))
			var btn := SkirmishTileTextures.styled_button(opt_text)
			btn.add_theme_font_size_override("font_size", 15)
			btn.pressed.connect(_on_option_selected.bind(str(opt.get("id", ""))))
			var hint: String = _format_outcomes(opt.get("outcomes", {}))
			btn.mouse_entered.connect(func() -> void: _effect_label.text = hint)
			btn.mouse_exited.connect(func() -> void: _effect_label.text = "")
			_options_container.add_child(btn)
	else:
		# 无选项事件 — 显示效果 + 确定按钮
		_effect_label.text = _format_outcomes(_event_data.get("effects", {}))
		var btn := SkirmishTileTextures.styled_button("确定")
		btn.add_theme_font_size_override("font_size", 15)
		btn.pressed.connect(_on_confirm_pressed)
		_options_container.add_child(btn)

	visible = true


func _on_option_selected(choice_id: String) -> void:
	var event_id: String = str(_event_data.get("id", ""))
	EventManager.resolve_event_choice(event_id, choice_id)
	_close_popup()


func _on_confirm_pressed() -> void:
	_close_popup()


func _close_popup() -> void:
	visible = false
	_event_data = {}
	event_popup_closed.emit()


static var _OUTCOME_LABELS: Dictionary = {
	"food_delta": "粮食",
	"gold_delta": "金币",
	"iron_delta": "铁矿",
	"morale_delta": "民心",
	"population_delta": "人口",
	"troops_delta": "兵力",
}


func _format_outcomes(outcomes: Dictionary) -> String:
	if outcomes.is_empty():
		return "无效果"
	var lines: PackedStringArray = []
	for key in _OUTCOME_LABELS:
		var val: int = int(outcomes.get(key, 0))
		if val == 0:
			continue
		var label: String = str(_OUTCOME_LABELS[key])
		var sign: String = "+" if val > 0 else ""
		lines.append("%s %s%d" % [label, sign, val])
	if lines.is_empty():
		return "无效果"
	return "\n".join(lines)
