extends Control
## 势力选择界面
## 布局：上方势力卡片行 + 下方详情面板

signal faction_selected(faction_id: String)

@onready var bg: TextureRect = $Background
@onready var title_label: Label = $TitleLabel
@onready var cards_container: HBoxContainer = $CardsContainer
@onready var detail_panel: PanelContainer = $DetailPanel
@onready var portrait_rect: TextureRect = $DetailPanel/VBox/HBox/Portrait
@onready var info_label: Label = $DetailPanel/VBox/HBox/Info
@onready var history_label: Label = $DetailPanel/VBox/History
@onready var back_btn: Button = $Buttons/BackButton
@onready var start_btn: Button = $Buttons/StartButton

# 势力数据（从 factions.json 运行时读取，或硬编码作为 fallback）
const FACTIONS := [
	{"id": "qin",  "name": "秦国", "desc": "虎狼之秦，变法图强", "unit": "锐士",     "bonus": "攻击力+15%", "history": "战国初期的秦国仍居西陲，凭关中沃土与函谷险要自守。魏国一度强压秦东线，但秦廷已经开始重视法制、军功与集权，正处在由守转攻的临界点。"},
	{"id": "zhao", "name": "赵国", "desc": "胡服骑射，尚武之邦", "unit": "胡服骑兵", "bonus": "骑兵移动力+1", "history": "战国初期的赵国刚从三家分晋的格局中站稳脚跟，北面接胡地、南面争中原，兼具边地骑战压力与中原争霸野心，是一支正在成形的强军国家。"},
	{"id": "qi",   "name": "齐国", "desc": "文风鼎盛，稷下学宫", "unit": "技击手",   "bonus": "金钱收入+20%", "history": "齐国据东方海岱之利，工商与盐铁富庶，临淄繁华。战国初期的齐国尚未完全卷入西方连年大战，更像一位财力深厚、谋而后动的东方霸主候选者。"},
	{"id": "chu",  "name": "楚国", "desc": "浪漫主义，地广人众", "unit": "申息之师", "bonus": "人口增长+10%", "history": "楚国在战国初期版图最广、腹地最深，从江汉到淮泗都拥有影响力。它兵源丰厚、地方色彩浓重，强在纵深与人口，但也常因疆域过大而显得调度迟缓。"},
	{"id": "wei",  "name": "魏国", "desc": "武卒传统，变法先驱", "unit": "武卒",     "bonus": "防御力+15%", "history": "战国初期的魏国是最先完成强国转型的一员。凭借李悝变法与魏武卒，它率先压制诸侯、据有河东河内，是中原秩序的主导者，也是秦赵韩共同警惕的对象。"},
	{"id": "yan",  "name": "燕国", "desc": "复仇情结，坚韧不拔", "unit": "辽东弓骑", "bonus": "视野+1", "history": "燕国地处北方边缘，核心在蓟城，既要防范山戎胡骑，也要提防齐赵压力。战国初期的燕国国力不及中原强邻，但边地经验丰富，适合以韧性与机动寻找生机。"},
	{"id": "han",  "name": "韩国", "desc": "精工巧匠，劲弩之国", "unit": "劲弩",     "bonus": "攻城伤害+20%", "history": "韩国处在天下腹心，也是三晋中疆域最小的一国。战国初期它凭借弩兵、冶铁与工匠传统维持竞争力，却必须在魏楚秦赵夹缝中精打细算，每一步都很关键。"},
]

var _selected_faction: String = ""
var _card_buttons: Array[Button] = []

func _ready() -> void:
	SkirmishTileTextures.style_scene_button(back_btn)
	SkirmishTileTextures.style_scene_button(start_btn)
	back_btn.pressed.connect(func():
		StartupFlow.goto_mode_select()
	)
	start_btn.pressed.connect(_on_start)
	start_btn.disabled = true
	SkirmishTileTextures.update_button_disabled(start_btn)
	_create_cards()

func _create_cards() -> void:
	for f in FACTIONS:
		var btn := SkirmishTileTextures.styled_button(f["name"].substr(0, 2))
		btn.custom_minimum_size = Vector2(96, 128)
		btn.add_theme_font_size_override("font_size", 24)

		# 加载卡片纹理（如有）
		var card_path := "res://assets/ui/panels/ui_faction_card_%s.png" % f["id"]
		if ResourceLoader.exists(card_path):
			btn.icon = load(card_path)
			btn.expand_icon = true
			btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP

		var fid: String = str(f["id"])
		btn.pressed.connect(func(): _select_faction(fid))
		cards_container.add_child(btn)
		_card_buttons.append(btn)

func _select_faction(faction_id: String) -> void:
	_selected_faction = faction_id
	start_btn.disabled = false
	detail_panel.visible = true

	# 更新详情面板
	var f := _get_faction(faction_id)
	if f:
		info_label.text = "%s\n%s\n\n特色兵种：%s\n势力加成：%s" % [f["name"], f["desc"], f["unit"], f["bonus"]]
		history_label.text = "时代背景（战国初期）\n%s" % str(f.get("history", ""))

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
