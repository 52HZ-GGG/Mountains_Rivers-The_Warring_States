extends Control
## 势力选择界面
## 布局：上方势力卡片行 + 下方详情面板

signal faction_selected(faction_id: String)

@onready var bg: TextureRect = $Background
@onready var title_label: Label = $TitleLabel
@onready var cards_container: HBoxContainer = $CardsContainer
@onready var detail_panel: PanelContainer = $DetailPanel
@onready var portrait_rect: TextureRect = $DetailPanel/HBox/Portrait
@onready var info_label: Label = $DetailPanel/HBox/Info
@onready var back_btn: Button = $Buttons/BackButton
@onready var start_btn: Button = $Buttons/StartButton

# 势力数据（从 factions.json 运行时读取，或硬编码作为 fallback）
const FACTIONS := [
	{"id": "qin",  "name": "秦国", "desc": "虎狼之秦，变法图强", "unit": "锐士",     "bonus": "攻击力+15%"},
	{"id": "zhao", "name": "赵国", "desc": "胡服骑射，尚武之邦", "unit": "胡服骑兵", "bonus": "骑兵移动力+1"},
	{"id": "qi",   "name": "齐国", "desc": "文风鼎盛，稷下学宫", "unit": "技击手",   "bonus": "金钱收入+20%"},
	{"id": "chu",  "name": "楚国", "desc": "浪漫主义，地广人众", "unit": "申息之师", "bonus": "人口增长+10%"},
	{"id": "wei",  "name": "魏国", "desc": "武卒传统，变法先驱", "unit": "武卒",     "bonus": "防御力+15%"},
	{"id": "yan",  "name": "燕国", "desc": "复仇情结，坚韧不拔", "unit": "辽东弓骑", "bonus": "视野+1"},
	{"id": "han",  "name": "韩国", "desc": "精工巧匠，劲弩之国", "unit": "劲弩",     "bonus": "攻城伤害+20%"},
]

var _selected_faction: String = ""
var _card_buttons: Array[Button] = []

func _ready() -> void:
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main/main.tscn"))
	start_btn.pressed.connect(_on_start)
	start_btn.disabled = true
	_create_cards()

func _create_cards() -> void:
	for f in FACTIONS:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(96, 128)
		btn.text = f["name"].substr(0, 2)  # 取"秦"字
		btn.add_theme_font_size_override("font_size", 24)

		# 加载卡片纹理（如有）
		var card_path := "res://assets/ui/panels/ui_faction_card_%s.png" % f["id"]
		if ResourceLoader.exists(card_path):
			btn.icon = load(card_path)
			btn.expand_icon = true
			btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP

		var fid := f["id"]
		btn.pressed.connect(func(): _select_faction(fid))
		cards_container.add_child(btn)
		_card_buttons.append(btn)

func _select_faction(faction_id: String) -> void:
	_selected_faction = faction_id
	start_btn.disabled = false

	# 更新详情面板
	var f := _get_faction(faction_id)
	if f:
		info_label.text = "%s\n%s\n\n特色兵种：%s\n势力加成：%s" % [f["name"], f["desc"], f["unit"], f["bonus"]]

	# 加载头像
	var portrait_path := "res://photos/portrait/portrait_monarch_%s_hires.png" % faction_id
	if ResourceLoader.exists(portrait_path):
		portrait_rect.texture = load(portrait_path)

	# 更新卡片视觉
	for i in _card_buttons.size():
		var btn := _card_buttons[i]
		if FACTIONS[i]["id"] == faction_id:
			btn.modulate = Color(1, 1, 1, 1)
			btn.scale = Vector2(1.1, 1.1)
		else:
			btn.modulate = Color(0.7, 0.7, 0.7, 0.8)
			btn.scale = Vector2(1.0, 1.0)

	# 详情面板淡入
	detail_panel.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(detail_panel, "modulate:a", 1.0, 0.3)

func _on_start() -> void:
	if _selected_faction == "":
		return
	faction_selected.emit(_selected_faction)
	StartupFlow.on_faction_selected(_selected_faction)

func _get_faction(id: String) -> Dictionary:
	for f in FACTIONS:
		if f["id"] == id:
			return f
	return {}
