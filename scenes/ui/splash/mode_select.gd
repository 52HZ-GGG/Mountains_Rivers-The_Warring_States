extends Control
## 模式选择界面（新游戏时选择游戏模式）
## 4 种模式：征战天下 / 逐鹿中原 / 合纵连横 / 自定义战役

signal mode_selected(mode_id: String)

@onready var title_label: Label = $TitleLabel
@onready var cards_container: GridContainer = $CardsContainer
@onready var back_btn: Button = $Buttons/BackButton
@onready var next_btn: Button = $Buttons/NextButton

const MODES := [
	{"id": "classic",  "name": "征战天下", "subtitle": "经典模式", "desc": "完整七国争霸\n所有系统开放", "turns": "~30 回合", "diff": "★★★", "tag": "推荐"},
	{"id": "quick",    "name": "逐鹿中原", "subtitle": "快速模式", "desc": "精简版\n三国鼎立", "turns": "~15 回合", "diff": "★★", "tag": "新手友好"},
	{"id": "story",    "name": "合纵连横", "subtitle": "剧情模式", "desc": "历史战役重现\n特殊胜利条件", "turns": "~20 回合", "diff": "★★★★", "tag": "挑战性"},
	{"id": "sandbox",  "name": "自定义战役", "subtitle": "沙盒模式", "desc": "自由配置势力\n自定义规则", "turns": "无限回合", "diff": "自选", "tag": "自由度高"},
]

var _selected_mode: String = ""
var _cards: Array[PanelContainer] = []

func _ready() -> void:
	print("[ModeSelect] _ready 开始")
	SkirmishTileTextures.style_scene_button(back_btn)
	SkirmishTileTextures.style_scene_button(next_btn)
	back_btn.pressed.connect(func():
		print("[ModeSelect] 返回按钮被点击")
		StartupFlow.is_startup_flow_active = false
		get_tree().change_scene_to_file("res://scenes/main/main.tscn")
	)
	next_btn.pressed.connect(func():
		print("[ModeSelect] 下一步按钮被点击")
		_on_next()
	)
	next_btn.disabled = true
	SkirmishTileTextures.update_button_disabled(next_btn)
	_create_cards()
	print("[ModeSelect] _ready 完成, back_btn=%s next_btn=%s" % [str(back_btn), str(next_btn)])

func _create_cards() -> void:
	for m in MODES:
		var card := _build_card(m)
		cards_container.add_child(card)
		_cards.append(card)

func _build_card(mode: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(240, 320)
	panel.size_flags_horizontal = Control.SIZE_EXPAND

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
	tag_label.add_theme_color_override("font_color", Color("C8A84E"))
	vbox.add_child(tag_label)

	panel.add_child(vbox)

	# 点击选中
	var mid: String = str(mode["id"])
	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			_select_mode(mid)
	)
	panel.mouse_entered.connect(func():
		if _selected_mode != mid:
			var tw := create_tween()
			tw.tween_property(panel, "scale", Vector2(1.05, 1.05), 0.2)
	)
	panel.mouse_exited.connect(func():
		if _selected_mode != mid:
			var tw := create_tween()
			tw.tween_property(panel, "scale", Vector2.ONE, 0.2)
	)

	return panel

func _select_mode(mode_id: String) -> void:
	_selected_mode = mode_id
	next_btn.disabled = false

	for i in _cards.size():
		var card := _cards[i]
		var is_selected: bool = str(MODES[i]["id"]) == mode_id
		var tw := create_tween().set_parallel(true)
		if is_selected:
			tw.tween_property(card, "scale", Vector2(1.05, 1.05), 0.3)
			card.modulate = Color(1, 1, 1, 1)
			# 边框高亮（通过 modulate 模拟）
		else:
			tw.tween_property(card, "scale", Vector2.ONE, 0.3)
			card.modulate = Color(0.7, 0.7, 0.7, 0.7)

	mode_selected.emit(mode_id)

func _on_next() -> void:
	if _selected_mode == "":
		return
	StartupFlow.on_mode_selected(_selected_mode)
