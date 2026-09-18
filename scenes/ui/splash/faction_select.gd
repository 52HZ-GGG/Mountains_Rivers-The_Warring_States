extends Control
## 势力选择界面
## 布局：上方势力卡片行 + 下方详情面板
## 数据全部来自 DataManager（factions.json + units.json 势力变体），无硬编码。

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

var _selected_faction: String = ""
var _card_buttons: Array[Button] = []
## 可选的势力 id 列表（排除被动势力，如周天子）
var _faction_ids: Array[String] = []


func _ready() -> void:
	SkirmishTileTextures.style_scene_button(back_btn)
	SkirmishTileTextures.style_scene_button(start_btn)
	back_btn.pressed.connect(func():
		StartupFlow.goto_mode_select()
	)
	start_btn.pressed.connect(_on_start)
	start_btn.disabled = true
	SkirmishTileTextures.update_button_disabled(start_btn)
	_build_faction_ids()
	_create_cards()


func _build_faction_ids() -> void:
	_faction_ids.clear()
	for faction in DataManager.get_all_factions():
		var fid: String = str(faction.get("id", ""))
		if fid == "":
			continue
		if bool(faction.get("is_passive", false)):
			continue
		_faction_ids.append(fid)


func _create_cards() -> void:
	for fid in _faction_ids:
		var f: Dictionary = DataManager.get_faction(fid)
		var btn := SkirmishTileTextures.styled_button(str(f.get("name", fid)).substr(0, 2))
		btn.custom_minimum_size = Vector2(96, 128)
		btn.add_theme_font_size_override("font_size", 24)

		# 加载卡片纹理（如有）
		var card_path := "res://assets/ui/panels/ui_faction_card_%s.png" % fid
		if ResourceLoader.exists(card_path):
			btn.icon = load(card_path)
			btn.expand_icon = true
			btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP

		btn.pressed.connect(func(): _select_faction(fid))
		cards_container.add_child(btn)
		_card_buttons.append(btn)


func _select_faction(faction_id: String) -> void:
	_selected_faction = faction_id
	start_btn.disabled = false
	detail_panel.visible = true

	# 更新详情面板
	var f := DataManager.get_faction(faction_id)
	if not f.is_empty():
		info_label.text = "%s\n%s\n\n特色兵种：%s\n势力加成：%s" % [
			str(f.get("name", faction_id)),
			str(f.get("description", "")),
			_get_variant_name(faction_id),
			_get_variant_bonus(faction_id),
		]
		history_label.text = "时代背景（战国初期）\n%s" % str(f.get("history", ""))

	# 加载头像
	var portrait_path := "res://assets/units/portraits_hires/portrait_monarch_%s_hires.png" % faction_id
	if ResourceLoader.exists(portrait_path):
		portrait_rect.texture = load(portrait_path)

	# 更新卡片视觉
	for i in _card_buttons.size():
		var btn := _card_buttons[i]
		if _faction_ids[i] == faction_id:
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


## 特色兵种名：取 units.json 中该势力第一个变体的 variant_name。
func _get_variant_name(faction_id: String) -> String:
	var variants: Array = DataManager.get_faction_variants(faction_id)
	if variants.is_empty():
		return "（无特色兵种）"
	return str((variants[0] as Dictionary).get("variant_name", ""))


## 势力加成：直接使用 units.json 变体的 special_description（真实机制效果）。
func _get_variant_bonus(faction_id: String) -> String:
	var variants: Array = DataManager.get_faction_variants(faction_id)
	if variants.is_empty():
		return "（无势力加成）"
	return str((variants[0] as Dictionary).get("special_description", ""))
