extends Control
## 模式选择界面（新游戏时选择游戏模式）
## Demo 阶段模式选择：开放新手教程与完整试玩，保留测试主菜单入口。

signal mode_selected(mode_id: String)

const ANNOUNCEMENT_POPUP_SCENE: PackedScene = preload("res://scenes/ui/splash/announcement_popup.tscn")
const MODE_SELECT_ANNOUNCEMENT_TITLE: String = "公开试玩说明"
const MODE_SELECT_ANNOUNCEMENT_BODY: String = "《山河策》当前试玩已集成城市经营、大地图行军、政治疆域、征兵与战术演武等核心链路。\n\n目前版本仍处于持续制作阶段，部分数值、美术占位与后续系统仍会继续打磨，但正式试玩与新手教程都已经可以完整上手。\n\n游玩流程：\n正式试玩：选择模式 -> 选择国家 -> 进入大地图 -> 经营城池、推进回合、出征作战。\n新手教程：直接进入教学战场，学习经营、征兵、攻城与占领。\n战略中枢：作为系统总览入口，便于快速查看当前框架内容。"

@onready var title_label: Label = $TitleLabel
@onready var cards_container: GridContainer = $CardsContainer
@onready var back_btn: Button = $Buttons/BackButton
@onready var next_btn: Button = $Buttons/NextButton

const MODES := [
	{"id": "full_demo", "name": "正式试玩", "subtitle": "选国开局 + 大地图", "desc": "选择任一战国势力\n直接进入正式大地图", "turns": "15~25 分钟", "diff": "★★★", "tag": "推荐", "locked": false},
	{"id": "demo", "name": "新手教程", "subtitle": "经营 + 军事教学", "desc": "学习经营准备\n再进入洛邑战斗", "turns": "10~15 分钟", "diff": "★", "tag": "推荐新手", "locked": false},
	{"id": "strategy_hub", "name": "战略中枢", "subtitle": "系统总览入口", "desc": "进入控制中枢\n查看各系统入口", "turns": "自由体验", "diff": "★", "tag": "功能入口", "locked": false},
	{"id": "story", "name": "合纵连横", "subtitle": "剧情模式", "desc": "历史战役重现\n后续开放", "turns": "~20 回合", "diff": "★★★★", "tag": "暂未开放", "locked": true},
]

var _selected_mode: String = ""
var _cards: Array[PanelContainer] = []
var _hint_label: Label = null
var _announcement_popup: Control = null
var _announcement_closed: bool = false

func _debug_log(message: String) -> void:
	if OS.has_feature("debug"):
		print(message)


func _ready() -> void:
	_debug_log("[ModeSelect] _ready 开始")
	focus_mode = Control.FOCUS_ALL
	title_label.text = "选择公开试玩内容"
	SkirmishTileTextures.style_scene_button(back_btn)
	SkirmishTileTextures.style_scene_button(next_btn)
	back_btn.text = "测试主菜单"
	back_btn.visible = OS.has_feature("debug")
	back_btn.pressed.connect(func():
		_debug_log("[ModeSelect] 进入测试主菜单")
		StartupFlow.goto_test_menu()
	)
	next_btn.pressed.connect(func():
		_debug_log("[ModeSelect] 下一步按钮被点击")
		_on_next()
	)
	next_btn.text = "开始 Demo"
	next_btn.disabled = true
	SkirmishTileTextures.update_button_disabled(next_btn)
	_create_hint_label()
	_create_cards()
	_select_mode(StartupFlow.MODE_FULL_DEMO)
	_show_mode_select_announcement()
	grab_focus()
	_debug_log("[ModeSelect] _ready 完成, back_btn=%s next_btn=%s" % [str(back_btn), str(next_btn)])


func _create_hint_label() -> void:
	_hint_label = Label.new()
	_hint_label.name = "DemoHintLabel"
	_hint_label.text = ""
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.add_theme_font_size_override("font_size", 16)
	_hint_label.add_theme_color_override("font_color", Color("E8D5B0"))
	_hint_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hint_label.offset_left = -360.0
	_hint_label.offset_top = 92.0
	_hint_label.offset_right = 360.0
	_hint_label.offset_bottom = 146.0
	add_child(_hint_label)


func _create_cards() -> void:
	for m in MODES:
		var card := _build_card(m)
		cards_container.add_child(card)
		_cards.append(card)

func _build_card(mode: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "ModeCard_%s" % str(mode.get("id", "unknown"))
	panel.custom_minimum_size = Vector2(240, 320)
	panel.size_flags_horizontal = Control.SIZE_EXPAND
	var is_locked: bool = bool(mode.get("locked", false))

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)

	# 模式名
	var name_label := Label.new()
	name_label.text = mode["name"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color("C8A84E"))
	vbox.add_child(name_label)

	# 副标题
	var sub_label := Label.new()
	sub_label.text = mode["subtitle"]
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.add_theme_font_size_override("font_size", 14)
	sub_label.add_theme_color_override("font_color", Color("A08060"))
	vbox.add_child(sub_label)

	# 分隔
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# 描述
	var desc_label := Label.new()
	desc_label.text = mode["desc"]
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", Color("E8D5B0"))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_label)

	# 回合数
	var turns_label := Label.new()
	turns_label.text = mode["turns"]
	turns_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turns_label.add_theme_font_size_override("font_size", 13)
	turns_label.add_theme_color_override("font_color", Color("A08060"))
	vbox.add_child(turns_label)

	# 难度
	var diff_label := Label.new()
	diff_label.text = "难度：%s" % mode["diff"]
	diff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diff_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(diff_label)

	# 标签
	var tag_label := Label.new()
	tag_label.text = "[ %s ]" % mode["tag"]
	tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag_label.add_theme_font_size_override("font_size", 12)
	tag_label.add_theme_color_override("font_color", Color("7F7F7F") if is_locked else Color("C8A84E"))
	vbox.add_child(tag_label)

	panel.add_child(vbox)
	panel.modulate = Color(0.42, 0.42, 0.42, 0.72) if is_locked else Color(1, 1, 1, 1)
	panel.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN if is_locked else Control.CURSOR_POINTING_HAND

	# 点击选中
	var mid: String = str(mode["id"])
	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			if is_locked:
				_show_locked_mode_hint(str(mode.get("name", "该模式")))
				return
			_select_mode(mid)
	)
	panel.mouse_entered.connect(func():
		if is_locked:
			return
		if _selected_mode != mid:
			var tw := create_tween()
			tw.tween_property(panel, "scale", Vector2(1.05, 1.05), 0.2)
	)
	panel.mouse_exited.connect(func():
		if is_locked:
			return
		if _selected_mode != mid:
			var tw := create_tween()
			tw.tween_property(panel, "scale", Vector2.ONE, 0.2)
	)

	return panel

func _select_mode(mode_id: String) -> void:
	_selected_mode = mode_id
	next_btn.disabled = false
	next_btn.text = "开始完整试玩" if mode_id == StartupFlow.MODE_FULL_DEMO else "开始新手教程" if mode_id == StartupFlow.MODE_DEMO else "下一步"
	if is_instance_valid(_hint_label):
		if mode_id == StartupFlow.MODE_FULL_DEMO:
			_hint_label.text = "正式试玩会先进入势力选择；选定国家后直接进入大地图，并定位到该国首都。"
		elif mode_id == StartupFlow.MODE_DEMO:
			_hint_label.text = "新手教程会直接进入洛邑演武，在战场中教学城市经营、征兵、回合推进和攻城。"
		elif mode_id == StartupFlow.MODE_STRATEGY_HUB:
			_hint_label.text = "战略中枢保留为独立入口，用于查看系统入口、资源状态和框架功能。"
		else:
			_hint_label.text = "该模式已放入正式版框架，后续逐步开放。"

	for i in _cards.size():
		var card := _cards[i]
		var is_selected: bool = str(MODES[i]["id"]) == mode_id
		var is_locked: bool = bool(MODES[i].get("locked", false))
		var tw := create_tween().set_parallel(true)
		if is_selected:
			tw.tween_property(card, "scale", Vector2(1.05, 1.05), 0.3)
			card.modulate = Color(1, 1, 1, 1)
			# 边框高亮（通过 modulate 模拟）
		elif is_locked:
			tw.tween_property(card, "scale", Vector2.ONE, 0.3)
			card.modulate = Color(0.42, 0.42, 0.42, 0.72)
		else:
			tw.tween_property(card, "scale", Vector2.ONE, 0.3)
			card.modulate = Color(0.7, 0.7, 0.7, 0.7)

	mode_selected.emit(mode_id)


func _show_locked_mode_hint(mode_name: String) -> void:
	if is_instance_valid(_hint_label):
		_hint_label.text = "%s 暂未开放。当前可选：新手教程，或完整试玩 Demo。" % mode_name


func _on_next() -> void:
	if _selected_mode == "":
		return
	StartupFlow.on_mode_selected(_selected_mode)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_on_next()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
		_select_mode_by_step(-1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
		_select_mode_by_step(1)
		get_viewport().set_input_as_handled()


func _select_mode_by_step(step: int) -> void:
	if MODES.is_empty():
		return
	var current_index: int = 0
	for i: int in range(MODES.size()):
		var mode: Dictionary = MODES[i] as Dictionary
		if str(mode.get("id", "")) == _selected_mode:
			current_index = i
			break
	var next_index: int = posmod(current_index + step, MODES.size())
	var next_mode: Dictionary = MODES[next_index] as Dictionary
	if bool(next_mode.get("locked", false)):
		_show_locked_mode_hint(str(next_mode.get("name", "该模式")))
		return
	_select_mode(str(next_mode.get("id", "")))


func _show_mode_select_announcement() -> void:
	_announcement_closed = false
	_announcement_popup = ANNOUNCEMENT_POPUP_SCENE.instantiate()
	add_child(_announcement_popup)
	_announcement_popup.announced.connect(_on_mode_select_announcement_closed)
	_announcement_popup.call_deferred(
		"show_announcement",
		MODE_SELECT_ANNOUNCEMENT_TITLE,
		MODE_SELECT_ANNOUNCEMENT_BODY
	)


func _on_mode_select_announcement_closed() -> void:
	_announcement_closed = true
	if is_instance_valid(_announcement_popup):
		_announcement_popup.queue_free()
		_announcement_popup = null
