extends Panel

## 外交面板 — 阶段2最小可用UI
##
## 左侧：国家列表（显示声望等级、好感度）
## 右侧：选中国家的外交状态 + 可用动作按钮

signal diplomacy_panel_closed

var _selected_faction: String = ""
var _faction_buttons: Array[Button] = []


func _ready() -> void:
	if ClassDB.class_exists("ArtUiSkin"):
		ArtUiSkin.apply_full_skin(self, "diplomacy")
	_build_ui()


func _build_ui() -> void:
	# 主布局
	var main_vbox := VBoxContainer.new()
	main_vbox.name = "MainVBox"
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(main_vbox)

	# 标题栏
	var title_bar := HBoxContainer.new()
	title_bar.name = "TitleBar"
	main_vbox.add_child(title_bar)

	var title := Label.new()
	title.text = I18n.t("diplomacy.title")
	title.add_theme_font_size_override("font_size", 24)
	title_bar.add_child(title)

	var close_button := SkirmishTileTextures.styled_button(I18n.t("ui.close"))
	close_button.pressed.connect(_on_close_pressed)
	title_bar.add_child(close_button)

	# 内容区
	var content := HSplitContainer.new()
	content.name = "Content"
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(content)

	# 左侧：国家列表
	var left_panel := VBoxContainer.new()
	left_panel.name = "LeftPanel"
	left_panel.custom_minimum_size.x = 200
	content.add_child(left_panel)

	var faction_label := Label.new()
	faction_label.text = I18n.t("diplomacy.faction_list")
	left_panel.add_child(faction_label)

	var faction_list := VBoxContainer.new()
	faction_list.name = "FactionList"
	left_panel.add_child(faction_list)

	# 右侧：详情面板
	var right_panel := VBoxContainer.new()
	right_panel.name = "RightPanel"
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(right_panel)

	var detail_label := Label.new()
	detail_label.text = I18n.t("diplomacy.detail")
	right_panel.add_child(detail_label)

	var detail_container := VBoxContainer.new()
	detail_container.name = "DetailContainer"
	detail_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_child(detail_container)

	# 动作按钮区
	var action_bar := HBoxContainer.new()
	action_bar.name = "ActionBar"
	right_panel.add_child(action_bar)

	# 创建动作按钮
	_create_action_button(action_bar, I18n.t("diplomacy.gift"), _on_gift_pressed)
	_create_action_button(action_bar, I18n.t("diplomacy.declare_war"), _on_declare_war_pressed)
	_create_action_button(action_bar, I18n.t("diplomacy.ceasefire"), _on_ceasefire_pressed)
	_create_action_button(action_bar, I18n.t("diplomacy.non_aggression"), _on_non_aggression_pressed)
	_create_action_button(action_bar, I18n.t("diplomacy.alliance"), _on_alliance_pressed)
	_create_action_button(action_bar, I18n.t("diplomacy.military_access"), _on_military_access_pressed)
	_create_action_button(action_bar, I18n.t("diplomacy.trade_route"), _on_trade_route_pressed)

	# 填充国家列表
	_populate_faction_list()


func _create_action_button(parent: Node, text: String, callback: Callable) -> void:
	var btn := SkirmishTileTextures.styled_button(text)
	btn.pressed.connect(callback)
	parent.add_child(btn)


func _populate_faction_list() -> void:
	var faction_list := $MainVBox/Content/LeftPanel/FactionList
	for child in faction_list.get_children():
		child.queue_free()
	_faction_buttons.clear()

	var player_faction: String = GameManager.get_player_faction()
	for fid in GameManager.FACTION_IDS:
		if fid == player_faction:
			continue
		var btn := SkirmishTileTextures.styled_button()
		var faction_data: Dictionary = DataManager.get_faction(fid)
		var name: String = faction_data.get("name", fid)
		var opinion: int = DiplomacySystem.get_opinion(player_faction, fid)
		var rep_level: String = DiplomacySystem.get_reputation_level(fid)
		var war_status := ""
		if DiplomacySystem.are_at_war(player_faction, fid):
			war_status = " [战争]"
		elif DiplomacySystem.are_allied(player_faction, fid):
			war_status = " [盟友]"
		btn.text = "%s (好感:%d) %s%s" % [name, opinion, _rep_level_text(rep_level), war_status]
		btn.pressed.connect(_on_faction_selected.bind(fid))
		faction_list.add_child(btn)
		_faction_buttons.append(btn)


func _rep_level_text(level: String) -> String:
	match level:
		"very_low": return "声望:极低"
		"low": return "声望:低"
		"mid": return "声望:中"
		"high": return "声望:高"
		"very_high": return "声望:极高"
	return "声望:中"


func _on_faction_selected(faction_id: String) -> void:
	_selected_faction = faction_id
	_update_detail_panel()


func _update_detail_panel() -> void:
	var detail := $MainVBox/Content/RightPanel/DetailContainer
	for child in detail.get_children():
		child.queue_free()

	if _selected_faction.is_empty():
		return

	var player_faction: String = GameManager.get_player_faction()
	var faction_data: Dictionary = DataManager.get_faction(_selected_faction)

	# 基本信息
	var info_label := Label.new()
	info_label.text = "国家: %s (%s)" % [faction_data.get("name", _selected_faction), faction_data.get("description", "")]
	detail.add_child(info_label)

	# 好感度
	var opinion_label := Label.new()
	var opinion: int = DiplomacySystem.get_opinion(player_faction, _selected_faction)
	var opinion_reverse: int = DiplomacySystem.get_opinion(_selected_faction, player_faction)
	opinion_label.text = "好感度: %d (对方对我: %d)" % [opinion, opinion_reverse]
	detail.add_child(opinion_label)

	# 声望
	var rep_label := Label.new()
	var rep: int = DiplomacySystem.get_reputation(_selected_faction)
	rep_label.text = "声望: %d (%s)" % [rep, _rep_level_text(DiplomacySystem.get_reputation_level(_selected_faction))]
	detail.add_child(rep_label)

	# 关系状态
	var status_label := Label.new()
	var status := I18n.t("diplomacy.peace")
	if DiplomacySystem.are_at_war(player_faction, _selected_faction):
		status = I18n.t("diplomacy.at_war")
	elif DiplomacySystem.are_allied(player_faction, _selected_faction):
		status = I18n.t("diplomacy.allied")
	elif DiplomacySystem.have_non_aggression(player_faction, _selected_faction):
		status = I18n.t("diplomacy.non_aggression")
	elif DiplomacySystem.have_trade_route(player_faction, _selected_faction):
		status = I18n.t("diplomacy.trading")
	status_label.text = "关系: %s" % status
	detail.add_child(status_label)

	# 边境关系
	var border_label := Label.new()
	var border_text := I18n.t("diplomacy.not_bordering")
	if DiplomacySystem.are_bordering(player_faction, _selected_faction):
		border_text = I18n.t("diplomacy.bordering")
	border_label.text = "边境: %s" % border_text
	detail.add_child(border_label)

	# 附庸状态
	if DiplomacySystem.is_vassal(_selected_faction):
		var vassal_label := Label.new()
		vassal_label.text = "附庸于: %s" % DataManager.get_faction(DiplomacySystem.get_vassal_master(_selected_faction)).get("name", "")
		detail.add_child(vassal_label)

	# 商路状态
	if DiplomacySystem.have_trade_route(player_faction, _selected_faction):
		var trade_label := Label.new()
		trade_label.text = "商路: 开通中"
		detail.add_child(trade_label)

	# 通行权状态
	if DiplomacySystem.have_military_access(player_faction, _selected_faction):
		var access_label := Label.new()
		access_label.text = "通行权: 有"
		detail.add_child(access_label)


func _on_close_pressed() -> void:
	diplomacy_panel_closed.emit()
	queue_free()


func open() -> void:
	_populate_faction_list()
	if _selected_faction.is_empty() and GameManager.FACTION_IDS.size() > 1:
		_selected_faction = GameManager.FACTION_IDS[0] if GameManager.FACTION_IDS[0] != GameManager.get_player_faction() else GameManager.FACTION_IDS[1]
	_update_detail_panel()


# ============= 外交动作 =============

func _on_gift_pressed() -> void:
	if _selected_faction.is_empty():
		return
	var player_faction: String = GameManager.get_player_faction()
	# 默认礼档（数据驱动，diplomacy.json ui_defaults.default_gift_tier）
	var tier: int = int(DataManager.get_diplomacy_param("ui_defaults.default_gift_tier"))
	var result: Dictionary = DiplomacySystem.send_gift(player_faction, _selected_faction, tier)
	if result["success"]:
		_populate_faction_list()
		_update_detail_panel()


func _on_declare_war_pressed() -> void:
	if _selected_faction.is_empty():
		return
	var player_faction: String = GameManager.get_player_faction()
	var result: Dictionary = DiplomacySystem.declare_war(player_faction, _selected_faction)
	if result["success"]:
		_populate_faction_list()
		_update_detail_panel()


func _on_ceasefire_pressed() -> void:
	if _selected_faction.is_empty():
		return
	var player_faction: String = GameManager.get_player_faction()
	if not DiplomacySystem.are_at_war(player_faction, _selected_faction):
		return
	# 打开谈判弹窗（默认赔款金额数据驱动，diplomacy.json ui_defaults.default_ceasefire_gold_offer）
	var default_gold: int = int(DataManager.get_diplomacy_param("ui_defaults.default_ceasefire_gold_offer"))
	var terms: Dictionary = {"gold": default_gold, "city_id": "", "vassal": false}
	var result: Dictionary = DiplomacySystem.propose_ceasefire(player_faction, _selected_faction, terms)
	if result["success"]:
		# 自动接受（简化，完整版用谈判弹窗）
		DiplomacySystem.accept_ceasefire(player_faction, _selected_faction, terms)
		_populate_faction_list()
		_update_detail_panel()


func _on_non_aggression_pressed() -> void:
	if _selected_faction.is_empty():
		return
	var player_faction: String = GameManager.get_player_faction()
	# 默认时长数据驱动（diplomacy.json ui_defaults.default_non_aggression_duration）
	var duration: int = int(DataManager.get_diplomacy_param("ui_defaults.default_non_aggression_duration"))
	var result: Dictionary = DiplomacySystem.sign_non_aggression(player_faction, _selected_faction, duration)
	if result["success"]:
		_populate_faction_list()
		_update_detail_panel()


func _on_alliance_pressed() -> void:
	if _selected_faction.is_empty():
		return
	var player_faction: String = GameManager.get_player_faction()
	var result: Dictionary = DiplomacySystem.form_alliance(player_faction, _selected_faction)
	if result["success"]:
		_populate_faction_list()
		_update_detail_panel()


func _on_military_access_pressed() -> void:
	if _selected_faction.is_empty():
		return
	var player_faction: String = GameManager.get_player_faction()
	# 默认通行单位数数据驱动（diplomacy.json ui_defaults.default_military_access_units）
	var units: int = int(DataManager.get_diplomacy_param("ui_defaults.default_military_access_units"))
	var result: Dictionary = DiplomacySystem.grant_military_access(_selected_faction, player_faction, units)
	if result["success"]:
		_populate_faction_list()
		_update_detail_panel()


func _on_trade_route_pressed() -> void:
	if _selected_faction.is_empty():
		return
	var player_faction: String = GameManager.get_player_faction()
	var result: Dictionary = DiplomacySystem.open_trade_route(player_faction, _selected_faction)
	if result["success"]:
		_populate_faction_list()
		_update_detail_panel()
