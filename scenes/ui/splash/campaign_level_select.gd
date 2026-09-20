extends Control

## 合纵连横 · 战役关卡选择
## 进入战役模式后列出关卡；当前可玩：第一关（新手教程）。

signal level_start_requested(level_id: String)
signal back_requested

const LEVELS_PATH: String = "res://data/campaign_levels.json"

@onready var _title_label: Label = $TitleLabel
@onready var _subtitle_label: Label = $SubtitleLabel
@onready var _levels_container: HBoxContainer = $LevelsContainer
@onready var _hint_label: Label = $HintLabel
@onready var _back_btn: Button = $Buttons/BackButton
@onready var _start_btn: Button = $Buttons/StartButton

var _selected_level_id: String = ""
var _cards: Array[PanelContainer] = []
var _levels: Array = []


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	_title_label.text = CampaignFlow.get_campaign_name()
	_subtitle_label.text = "%s ｜ 选择关卡" % CampaignFlow.get_campaign_subtitle()
	SkirmishTileTextures.style_scene_button(_back_btn)
	SkirmishTileTextures.style_scene_button(_start_btn)
	_back_btn.text = "返回模式"
	_start_btn.text = "开始关卡"
	_back_btn.pressed.connect(func():
		back_requested.emit()
		StartupFlow.return_to_mode_select()
	)
	_start_btn.pressed.connect(_on_start_pressed)
	_levels = CampaignFlow.get_levels()
	if _levels.is_empty():
		CampaignFlow.reload()
		_levels = CampaignFlow.get_levels()
	_create_level_cards()
	var prefer: String = CampaignFlow.get_selected_level_id()
	if prefer == "" or CampaignFlow.is_level_locked(prefer):
		prefer = _first_unlocked_level_id()
	_select_level(prefer)
	grab_focus()


func _first_unlocked_level_id() -> String:
	for lv: Variant in _levels:
		var d: Dictionary = lv as Dictionary
		if not bool(d.get("locked", true)):
			return str(d.get("id", ""))
	return ""


func _create_level_cards() -> void:
	for child in _levels_container.get_children():
		child.queue_free()
	_cards.clear()
	for lv: Variant in _levels:
		var card: PanelContainer = _build_level_card(lv as Dictionary)
		_levels_container.add_child(card)
		_cards.append(card)


func _build_level_card(level: Dictionary) -> PanelContainer:
	var locked: bool = bool(level.get("locked", true))
	var panel := PanelContainer.new()
	panel.name = "LevelCard_%s" % str(level.get("id", "unknown"))
	panel.custom_minimum_size = Vector2(260, 280)
	panel.size_flags_horizontal = Control.SIZE_EXPAND
	panel.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN if locked else Control.CURSOR_POINTING_HAND

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)

	var name_label := Label.new()
	name_label.text = str(level.get("name", "关卡"))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color("C8A84E"))
	vbox.add_child(name_label)

	var sub_label := Label.new()
	sub_label.text = str(level.get("subtitle", ""))
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.add_theme_font_size_override("font_size", 14)
	sub_label.add_theme_color_override("font_color", Color("A08060"))
	vbox.add_child(sub_label)

	vbox.add_child(HSeparator.new())

	var desc_label := Label.new()
	desc_label.text = str(level.get("desc", ""))
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", Color("E8D5B0"))
	vbox.add_child(desc_label)

	var meta := Label.new()
	meta.text = "时长：%s ｜ 难度：%s" % [str(level.get("duration", "—")), str(level.get("difficulty", "—"))]
	meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meta.add_theme_font_size_override("font_size", 13)
	vbox.add_child(meta)

	var tag_label := Label.new()
	tag_label.text = "[ %s ]" % str(level.get("tag", "锁定" if locked else "可进入"))
	tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag_label.add_theme_font_size_override("font_size", 12)
	tag_label.add_theme_color_override("font_color", Color("7F7F7F") if locked else Color("C8A84E"))
	vbox.add_child(tag_label)

	panel.add_child(vbox)
	panel.modulate = Color(0.42, 0.42, 0.42, 0.72) if locked else Color(1, 1, 1, 1)

	var level_id: String = str(level.get("id", ""))
	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			if locked:
				_hint_label.text = "该关卡尚未开放。当前可玩：第一关新手教程。"
				return
			_select_level(level_id)
	)
	return panel


func _select_level(level_id: String) -> void:
	_selected_level_id = level_id
	CampaignFlow.set_selected_level_id(level_id)
	var lv: Dictionary = CampaignFlow.get_level(level_id)
	var locked: bool = bool(lv.get("locked", true)) if not lv.is_empty() else true
	_start_btn.disabled = locked or level_id.is_empty()
	SkirmishTileTextures.update_button_disabled(_start_btn)
	if level_id.is_empty():
		_hint_label.text = "暂无关卡可进入。"
	elif locked:
		_hint_label.text = "「%s」尚未开放。" % str(lv.get("name", level_id))
	else:
		_hint_label.text = "已选择「%s」。点击「开始关卡」进入战役。" % str(lv.get("name", level_id))
	for i: int in range(_cards.size()):
		var card: PanelContainer = _cards[i]
		var mid: String = str((_levels[i] as Dictionary).get("id", ""))
		var is_locked: bool = bool((_levels[i] as Dictionary).get("locked", true))
		var is_selected: bool = mid == level_id
		if is_selected and not is_locked:
			card.modulate = Color(1, 1, 1, 1)
			var tw := create_tween()
			tw.tween_property(card, "scale", Vector2(1.04, 1.04), 0.2)
		elif is_locked:
			card.modulate = Color(0.42, 0.42, 0.42, 0.72)
			card.scale = Vector2.ONE
		else:
			card.modulate = Color(0.75, 0.75, 0.75, 0.85)
			card.scale = Vector2.ONE


func _on_start_pressed() -> void:
	if _selected_level_id == "":
		return
	if CampaignFlow.is_level_locked(_selected_level_id):
		_hint_label.text = "该关卡尚未开放。"
		return
	level_start_requested.emit(_selected_level_id)
	StartupFlow.on_campaign_level_selected(_selected_level_id)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_on_start_pressed()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		StartupFlow.return_to_mode_select()
		get_viewport().set_input_as_handled()
