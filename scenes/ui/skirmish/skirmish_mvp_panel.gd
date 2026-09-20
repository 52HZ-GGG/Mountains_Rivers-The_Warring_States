extends CanvasLayer

## 阶段1战术演武 UI：odd-R 矩形蜂巢密铺（JSON 列/行 → 轴向寻路）+ 地形/兵种贴图 + 悬停信息栏
## 选中己方单位后：可走格移动，或直接点击射程内敌军攻击（无需切换模式）

signal panel_closed

## 六角外接圆半径基准（像素）；实际半径按战术区可用尺寸换算，使蜂巢棋盘尽量大、看得清
const _HEX_RADIUS_BASE_PX: float = 60.0
## 棋盘外沿留白（像素）；过小易导致裁切，过大浪费可视面积
const _HEX_BOARD_PAD_PX: float = 8.0
## 递增后下次打开面板会重建六角格（修正布局/绘制逻辑后避免沿用旧节点）
const _HEX_BOARD_LAYOUT_VERSION: int = 12

const _HexAxial := preload("res://scripts/systems/hex_axial.gd")
const UnitMoraleRules := preload("res://scripts/systems/unit_morale_rules.gd")
const _ResourceBarScript: Script = preload("res://scenes/ui/resource_bar/resource_bar.gd")
const _CityPanelScene: PackedScene = preload("res://scenes/ui/city_panel/city_panel.tscn")
const _BuildingPlacementHighlight := preload("res://scripts/ui/building_placement_highlight.gd")
const _BigMapPoliticalControl := preload("res://scripts/systems/big_map_political_control.gd")

const _CLR_EMPTY_REACH: Color = Color(0.72, 1.0, 0.90)
const _CLR_PLAYER_UNIT: Color = Color(0.88, 0.93, 1.0)
const _CLR_ENEMY_UNIT: Color = Color(1.0, 0.88, 0.88)
const _CLR_ATTACKABLE: Color = Color(1.0, 0.78, 0.58)
const _CLR_SELECTED: Color = Color(1.0, 0.96, 0.62)
const _CLR_PLAYER_CITY: Color = Color(0.9, 0.93, 1.0)
const _CLR_ENEMY_CITY: Color = Color(1.0, 0.9, 0.9)

@onready var _hex_board: Control = %HexBoard
@onready var _log_view: RichTextLabel = %SkirmishLog
@onready var _hint: Label = %HintLabel
@onready var _hover_info: RichTextLabel = %HexHoverInfo
@onready var _season_label: Label = %SeasonLabel

var _selected_unit_id: String = ""
var _reachable: Dictionary = {}
var _hex_refit_pending: bool = false
var _refresh_suspended: bool = false
var _panel_cfg: Dictionary = {}
var _panel_season: String = "summer"
var _unit_frames_cache: Dictionary = {}  # "unit_type_id:faction_id" -> SpriteFrames
var _effect_frames_cache: Dictionary = {}  # effect_id -> SpriteFrames
var _political_map_btn: Button = null
var _skirmish_save_btn: Button = null
var _skirmish_load_btn: Button = null
var _formal_resource_bar: HBoxContainer = null
var _resource_hover_hint: Label = null
var _formal_resource_formula: RichTextLabel = null
var _formula_summary_row: HBoxContainer = null
var _formula_detail_btn: Button = null
var _formula_detail_panel: PanelContainer = null
var _formal_city_panel: Panel = null
var _political_mode: bool = false
var _political_grid: Dictionary = {}
var _placement_city_id: String = ""
var _placement_building_id: String = ""
## 演武盘面可见的建筑图标：战术格 axial -> building_id（点击落点 + 城格汇总）
var _visual_building_marks: Dictionary = {}


func _debug_log(message: String) -> void:
	if OS.has_feature("debug"):
		print(message)


func _ready() -> void:
	visible = false
	SkirmishTileTextures.style_scene_button($MarginContainer/MainVBox/ButtonRow/EndTurnBtn)
	SkirmishTileTextures.style_scene_button($MarginContainer/MainVBox/ButtonRow/RestartBtn)
	SkirmishTileTextures.style_scene_button($MarginContainer/MainVBox/ButtonRow/CloseBtn)
	_create_tutorial_formal_buttons()
	$MarginContainer/MainVBox/ButtonRow/EndTurnBtn.pressed.connect(_on_end_turn_pressed)
	$MarginContainer/MainVBox/ButtonRow/RestartBtn.pressed.connect(_on_restart_pressed)
	$MarginContainer/MainVBox/ButtonRow/CloseBtn.pressed.connect(_on_close_pressed)
	TacticalSkirmishManager.skirmish_ended.connect(_on_skirmish_ended_unified)
	TacticalSkirmishManager.state_changed.connect(_refresh_display)
	TacticalSkirmishManager.log_appended.connect(_on_mgr_log)
	TacticalSkirmishManager.combat_effect_requested.connect(_play_combat_effect)
	SignalBus.city_occupied.connect(_on_campaign_city_ownership_changed)


func open_panel() -> void:
	_debug_log("[SkirmishPanel] open_panel 开始")
	show()
	if not TacticalSkirmishManager.is_active():
		TacticalSkirmishManager.start_skirmish()
	_prepare_panel_for_active_skirmish()
	_debug_log("[SkirmishPanel] open_panel 完成")


func open_panel_with_config(cfg: Dictionary, season: String) -> void:
	_debug_log("[SkirmishPanel] open_panel_with_config 开始")
	_panel_cfg = cfg.duplicate(true)
	_panel_season = season
	show()
	_refresh_suspended = true
	TacticalSkirmishManager.reset_skirmish()
	TacticalSkirmishManager.start_skirmish_with_config(cfg, season)
	_refresh_suspended = false
	_prepare_panel_for_active_skirmish()
	_debug_log("[SkirmishPanel] open_panel_with_config 完成")


func _prepare_panel_for_active_skirmish() -> void:
	_hex_board.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_hex_board.set_meta("_hex_layout_v", 0)
	_ensure_hex_buttons()
	_debug_log("[SkirmishPanel] hex buttons 创建完成")
	_ensure_board_backdrop()
	_selected_unit_id = ""
	_reachable.clear()
	_log_view.clear()
	_hint.text = _initial_hint_text()
	_update_season_label()
	_update_tutorial_formal_ui()
	_hover_info.text = _default_hover_text()
	_refresh_display()
	_hex_refit_pending = true
	call_deferred("_deferred_refit_hex_radius_if_needed")


func close_panel() -> void:
	_close_formal_overlays()
	_reclaim_formal_resource_bar()
	TacticalSkirmishManager.reset_skirmish()
	visible = false
	panel_closed.emit()



func _create_tutorial_formal_buttons() -> void:
	var row: HBoxContainer = $MarginContainer/MainVBox/ButtonRow as HBoxContainer
	_political_map_btn = Button.new()
	_political_map_btn.name = "PoliticalBtn"
	_political_map_btn.text = "政治地图：关"
	_political_map_btn.custom_minimum_size = Vector2(132, 0)
	_political_map_btn.tooltip_text = "切换当前战术地图的政治归属显示，口径与正式大地图一致"
	_political_map_btn.pressed.connect(_on_political_toggle)
	SkirmishTileTextures.style_scene_button(_political_map_btn)
	row.add_child(_political_map_btn)
	row.move_child(_political_map_btn, 0)

	# 演武存档/读档（演武快照 + 战役档；Demo 与普通演武均可用）
	_skirmish_save_btn = Button.new()
	_skirmish_save_btn.name = "SkirmishSaveBtn"
	_skirmish_save_btn.text = "存档"
	_skirmish_save_btn.tooltip_text = "保存当前演武快照，并写入战役存档槽位 1"
	_skirmish_save_btn.pressed.connect(_on_skirmish_save_pressed)
	SkirmishTileTextures.style_scene_button(_skirmish_save_btn)
	row.add_child(_skirmish_save_btn)
	row.move_child(_skirmish_save_btn, 0)

	_skirmish_load_btn = Button.new()
	_skirmish_load_btn.name = "SkirmishLoadBtn"
	_skirmish_load_btn.text = "读档"
	_skirmish_load_btn.tooltip_text = "读取演武快照槽位 1；无快照时尝试战役槽位 1"
	_skirmish_load_btn.pressed.connect(_on_skirmish_load_pressed)
	SkirmishTileTextures.style_scene_button(_skirmish_load_btn)
	row.add_child(_skirmish_load_btn)
	row.move_child(_skirmish_load_btn, 1)


func _update_tutorial_formal_ui() -> void:
	if DemoFlow.is_tutorial_enabled():
		_ensure_formal_resource_bar()
	else:
		_close_formal_overlays()
		_reclaim_formal_resource_bar()


func _ensure_formal_resource_bar() -> void:
	if _formal_resource_bar == null:
		_formal_resource_bar = HBoxContainer.new()
		_formal_resource_bar.name = "FormalTutorialResourceBar"
		_formal_resource_bar.set_script(_ResourceBarScript)
	var main_vbox: VBoxContainer = $MarginContainer/MainVBox as VBoxContainer
	if _formal_resource_bar.get_parent() == null:
		main_vbox.add_child(_formal_resource_bar)
		main_vbox.move_child(_formal_resource_bar, 1)
	_formal_resource_bar.visible = true
	_ensure_resource_hover_hint()
	_ensure_resource_formula_panel()
	_refresh_formal_resource_bar()


func _refresh_formal_resource_bar() -> void:
	if _formal_resource_bar != null and _formal_resource_bar.has_method("refresh"):
		_formal_resource_bar.refresh()
	if _formal_resource_formula != null:
		_formal_resource_formula.text = _resource_formula_text()


func _reclaim_formal_resource_bar() -> void:
	if _formal_resource_bar != null:
		if _formal_resource_bar.get_parent() != null:
			_formal_resource_bar.get_parent().remove_child(_formal_resource_bar)
		_formal_resource_bar.queue_free()
		_formal_resource_bar = null
	if _resource_hover_hint != null:
		if _resource_hover_hint.get_parent() != null:
			_resource_hover_hint.get_parent().remove_child(_resource_hover_hint)
		_resource_hover_hint.queue_free()
		_resource_hover_hint = null
	if _formal_resource_formula != null:
		if _formal_resource_formula.get_parent() != null:
			_formal_resource_formula.get_parent().remove_child(_formal_resource_formula)
		_formal_resource_formula.queue_free()
		_formal_resource_formula = null
	if _formula_summary_row != null:
		if _formula_summary_row.get_parent() != null:
			_formula_summary_row.get_parent().remove_child(_formula_summary_row)
		_formula_summary_row.queue_free()
		_formula_summary_row = null
	if _formula_detail_btn != null:
		if _formula_detail_btn.get_parent() != null:
			_formula_detail_btn.get_parent().remove_child(_formula_detail_btn)
		_formula_detail_btn.queue_free()
		_formula_detail_btn = null
	if _formula_detail_panel != null:
		if _formula_detail_panel.get_parent() != null:
			_formula_detail_panel.get_parent().remove_child(_formula_detail_panel)
		_formula_detail_panel.queue_free()
		_formula_detail_panel = null


func _ensure_resource_hover_hint() -> void:
	if _resource_hover_hint == null:
		_resource_hover_hint = Label.new()
		_resource_hover_hint.name = "ResourceHoverHint"
		_resource_hover_hint.text = ""
	_resource_hover_hint.visible = false


func _ensure_resource_formula_panel() -> void:
	var main_vbox: VBoxContainer = $MarginContainer/MainVBox as VBoxContainer
	if _formula_summary_row == null:
		_formula_summary_row = HBoxContainer.new()
		_formula_summary_row.name = "ResourceFormulaSummaryRow"
		_formula_summary_row.add_theme_constant_override("separation", 8)
	if _formula_summary_row.get_parent() == null:
		main_vbox.add_child(_formula_summary_row)
		main_vbox.move_child(_formula_summary_row, 3)
	if _formal_resource_formula == null:
		_formal_resource_formula = RichTextLabel.new()
		_formal_resource_formula.name = "ResourceFormulaPanel"
		_formal_resource_formula.bbcode_enabled = true
		_formal_resource_formula.fit_content = true
		_formal_resource_formula.scroll_active = false
		_formal_resource_formula.custom_minimum_size = Vector2(0, 26)
		_formal_resource_formula.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_formal_resource_formula.add_theme_font_size_override("normal_font_size", 12)
		_formal_resource_formula.add_theme_color_override("default_color", Color(0.88, 0.9, 0.78, 1))
	if _formal_resource_formula.get_parent() == null:
		_formula_summary_row.add_child(_formal_resource_formula)
	_formal_resource_formula.visible = true
	if _formula_detail_btn == null:
		_formula_detail_btn = Button.new()
		_formula_detail_btn.name = "ResourceFormulaDetailButton"
		_formula_detail_btn.text = "详细"
		_formula_detail_btn.custom_minimum_size = Vector2(76, 0)
		_formula_detail_btn.pressed.connect(_toggle_resource_formula_detail)
		SkirmishTileTextures.style_scene_button(_formula_detail_btn)
	if _formula_detail_btn.get_parent() == null:
		_formula_summary_row.add_child(_formula_detail_btn)
	_formula_detail_btn.visible = true


func _toggle_resource_formula_detail() -> void:
	if _formula_detail_panel != null and _formula_detail_panel.visible:
		_formula_detail_panel.visible = false
		return
	_ensure_resource_formula_detail_panel()
	_formula_detail_panel.visible = true


func _ensure_resource_formula_detail_panel() -> void:
	if _formula_detail_panel != null:
		return
	_formula_detail_panel = PanelContainer.new()
	_formula_detail_panel.name = "ResourceFormulaDetailPanel"
	_formula_detail_panel.z_index = 1200
	_formula_detail_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_formula_detail_panel.offset_left = 32
	_formula_detail_panel.offset_top = 104
	_formula_detail_panel.offset_right = -32
	_formula_detail_panel.offset_bottom = 344
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_formula_detail_panel.add_child(box)
	var text: RichTextLabel = RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = false
	text.scroll_active = true
	text.custom_minimum_size = Vector2(0, 190)
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("normal_font_size", 12)
	text.text = _resource_formula_detail_text()
	box.add_child(text)
	var close_btn: Button = Button.new()
	close_btn.text = "收起说明"
	close_btn.pressed.connect(func() -> void:
		if _formula_detail_panel != null:
			_formula_detail_panel.visible = false
	)
	SkirmishTileTextures.style_scene_button(close_btn)
	box.add_child(close_btn)
	add_child(_formula_detail_panel)
	_formula_detail_panel.visible = false


func _resource_formula_detail_text() -> String:
	return "[b]资源计算详细说明[/b]\n" \
		+ "1. 全国税基：先汇总所有己方城市。每城粮/金基础值 = 人口 × food_per_pop/gold_per_pop；木材有 city_base_wood。建筑会提供百分比加成或固定产出，官员、特产、安定度、服役人口占比、学派全产出、儒家民心繁荣会继续修正。粮食还会扣人口口粮消耗，食物消耗减免会降低这项消耗。\n" \
		+ "2. 季节与全国修正：城市产出汇总后进入季节修正，春/夏/秋/冬分别影响粮、金、木、工匠、建材；科技资源修正和奇观资源修正再作用于全国总量。\n" \
		+ "3. 税后应入库：粮/金按 税后应入库 = 全国税基 × 当前税率 × 税收效率。税收效率 = 基础税效 × 民心档位 × 腐败修正 × 建筑税收 × 奇观税收。\n" \
		+ "4. 腐败来源：城市数、总人口、边境城市数提高腐败；科技、建筑、官员、奇观降低腐败。腐败会降低税收效率，也可能影响民心。\n" \
		+ "5. 上限截断：粮食受国家粮仓上限影响，金币受金库上限影响，木材和帛书也有上限。接近上限时，税后应入库可能很高，但实际入库只会补到上限。\n" \
		+ "6. 最终变化：实际入库之后再扣兵种维护、马匹耗粮、建筑维护。建造、取消建造、征兵会在点击时即时改变资源，不等回合结算。"


func _resource_formula_text() -> String:
	var preview: Dictionary = GameManager.preview_faction_turn_income(DemoFlow.get_player_faction_id())
	var prod: Dictionary = preview.get("production", {})
	var upkeep: Dictionary = preview.get("upkeep", {})
	var deltas: Dictionary = preview.get("deltas", {})
	var actual_income: Dictionary = preview.get("actual_income", {})
	var before: Dictionary = preview.get("before", {})
	var after_income: Dictionary = preview.get("after_income", {})
	var caps: Dictionary = preview.get("caps", {})
	return "资源摘要：粮 %+d（税后%d，粮仓%d/%d，维护%d）；金 %+d（税后%d，金库%d/%d，维护%d）。" % [
		int(deltas.get("food", 0)),
		int(prod.get("food_taxed", 0)),
		int(before.get("food", 0)),
		int(caps.get("food", -1)),
		int(upkeep.get("food", 0)),
		int(deltas.get("gold", 0)),
		int(prod.get("gold_taxed", 0)),
		int(before.get("gold", 0)),
		int(caps.get("gold", -1)),
		int(upkeep.get("gold", 0)) + int(upkeep.get("building_gold", 0)),
	]


func _resource_formula_factor_text() -> String:
	return "影响项：税基=城市人口基础产出、建筑百分比/固定产出、官员城市产出、特产、安定度、服役人口占比、学派全产出、儒家民心繁荣、人口口粮消耗、食物消耗减免、季节修正、科技资源修正、奇观资源修正、建筑完工/升级/拆除/取消；税收效率=税率、基础税效、民心档位、腐败、建筑税收、奇观税收；腐败=城市数、总人口、边境城市数、科技/建筑/官员/奇观减腐；上限=粮仓/市场/伐木场/帛书建筑等资源上限；扣除=兵种维护、马匹耗粮、建筑维护、征兵与建造即时花费。"


func _close_formal_overlays() -> void:
	if is_instance_valid(_formal_city_panel):
		_detach_formal_resource_bar()
		_formal_city_panel.close()
		_formal_city_panel = null


func _open_formal_capital_panel() -> void:
	var capital: Dictionary = CityManager.get_capital_state(DemoFlow.get_player_faction_id())
	var city_id: String = str(capital.get("id", "xianyang"))
	if city_id == "":
		city_id = "xianyang"
	_open_formal_city_panel(city_id)


func _open_formal_city_panel(city_id: String) -> void:
	if city_id.is_empty() or CityManager.get_city_state(city_id).is_empty():
		return
	var owner_check: String = str(CityManager.get_city_state(city_id).get("current_faction_id", ""))
	var player_check: String = TacticalSkirmishManager.get_player_faction()
	if player_check == "":
		player_check = GameManager.get_player_faction()
	if not DemoFlow.is_tutorial_enabled():
		if owner_check != player_check and owner_check != GameManager.get_player_faction():
			return
	_close_formal_overlays()
	_formal_city_panel = _CityPanelScene.instantiate() as Panel
	_formal_city_panel.name = "FormalTutorialCityPanel"
	_formal_city_panel.z_index = 1000
	add_child(_formal_city_panel)
	_formal_city_panel.return_to_map.connect(_on_formal_city_panel_return_to_skirmish)
	_formal_city_panel.panel_closed.connect(_on_formal_city_panel_closed)
	if _formal_city_panel.has_signal("place_building_requested"):
		_formal_city_panel.place_building_requested.connect(_on_place_building_requested_in_skirmish)
	_formal_city_panel.open(city_id)
	if _formal_city_panel.has_method("set_back_button_text"):
		_formal_city_panel.set_back_button_text("返回演武")
	_embed_formal_resource_bar(_formal_city_panel.get_resource_bar_slot())


## 演武=小号大地图：与主地图相同的放置模式
func _on_place_building_requested_in_skirmish(city_id: String, building_id: String) -> void:
	_placement_city_id = city_id
	_placement_building_id = building_id
	if is_instance_valid(_formal_city_panel):
		_detach_formal_resource_bar()
		_formal_city_panel.close()
	_formal_city_panel = null
	_ensure_formal_resource_bar()
	var bname: String = str(DataManager.get_building(building_id).get("name", building_id))
	_refresh_display()
	_hover_info.text = _build_placement_hover_text()


func _cancel_skirmish_building_placement() -> void:
	if _placement_city_id == "":
		return
	_placement_city_id = ""
	_placement_building_id = ""
	_refresh_display()
	_hover_info.text = _default_hover_text()


func _placement_highlight_map() -> Dictionary:
	## 与大地图同一套 BuildingPlacementHighlight：先标战役辖区 axial；
	## 战术板看不到的辖区，再以场景城格为中心画视觉环，保证演武放置可见。
	var campaign: Dictionary = _BuildingPlacementHighlight.highlight_for_jurisdiction(
		_placement_city_id, _placement_building_id
	)
	var out: Dictionary = campaign.duplicate()
	var cfg: Dictionary = TacticalSkirmishManager.get_active_config()
	var w: int = int(cfg.get("map_width", 0))
	var h: int = int(cfg.get("map_height", 0))
	if w <= 0 or h <= 0:
		return out
	var center: Vector2i = _tactical_city_cell_for(_placement_city_id)
	if center == Vector2i(-9999, -9999):
		return out
	var free_check: Dictionary = CityManager.can_build(_placement_city_id, _placement_building_id)
	var has_free: bool = bool(free_check.get("allowed", false))
	var off: Vector2i = _HexAxial.axial_to_offset_odd_r(center.x, center.y)
	for nb: Vector2i in _HexAxial.offset_visual_neighbors(off.x, off.y):
		if nb.x < 0 or nb.y < 0 or nb.x >= w or nb.y >= h:
			continue
		var axial: Vector2i = _HexAxial.offset_odd_r_to_axial(nb.x, nb.y)
		if out.has(axial):
			continue
		out[axial] = _BuildingPlacementHighlight.CLR_OK if has_free else _BuildingPlacementHighlight.CLR_BAD
	return out


func _tactical_city_cell_for(city_id: String) -> Vector2i:
	var cfg: Dictionary = TacticalSkirmishManager.get_active_config()
	var pc: Dictionary = cfg.get("player_city", {}) as Dictionary
	var ec: Dictionary = cfg.get("enemy_city", {}) as Dictionary
	if str(pc.get("city_id", "")) == city_id:
		return TacticalSkirmishManager.get_player_city()
	if str(ec.get("city_id", "")) == city_id:
		return TacticalSkirmishManager.get_enemy_city()
	if city_id != "" and not CityManager.get_city_state(city_id).is_empty():
		var owner: String = str(CityManager.get_city_state(city_id).get("current_faction_id", ""))
		if owner == TacticalSkirmishManager.get_player_faction():
			return TacticalSkirmishManager.get_player_city()
		if owner == TacticalSkirmishManager.get_enemy_faction():
			return TacticalSkirmishManager.get_enemy_city()
	return Vector2i(-9999, -9999)


func _try_place_building_in_skirmish(axial: Vector2i) -> void:
	if _placement_city_id == "" or _placement_building_id == "":
		return
	var bid: String = _placement_building_id
	# 1) 与大地图相同：点击战役辖区格直接落点
	if CityManager.start_build(_placement_city_id, bid, axial):
		_visual_building_marks[axial] = bid
		_finish_skirmish_placement(axial)
		return
	# 2) 战术视觉环：映射到战役城池空闲辖区格（同一 CityManager API）
	var auto: Dictionary = CityManager.can_build(_placement_city_id, bid)
	if bool(auto.get("allowed", false)):
		var place: Vector2i = Vector2i(int(auto.get("hex_q", -9999)), int(auto.get("hex_r", -9999)))
		if place.x > -9000 and CityManager.start_build(_placement_city_id, bid, place):
			# 图标画在玩家点击的战术格上（演武盘面可见）
			_visual_building_marks[axial] = bid
			_finish_skirmish_placement(place, axial)
			return
	var check: Dictionary = CityManager.can_build(_placement_city_id, bid, axial)
	_hover_info.text = "无法放置：%s" % str(check.get("reason", "不在辖区"))


func _finish_skirmish_placement(campaign_axial: Vector2i, visual_axial: Vector2i = Vector2i(-9999, -9999)) -> void:
	var cid: String = _placement_city_id
	_placement_city_id = ""
	_placement_building_id = ""
	if visual_axial.x > -9000:
		# 已在 try_place 中写入 building_id
		pass
	_refresh_display()
	var show_ax: Vector2i = visual_axial if visual_axial.x > -9000 else campaign_axial
	_hover_info.text = "已放置建筑（战役辖区 %d,%d；盘面 %d,%d）" % [
		campaign_axial.x, campaign_axial.y, show_ax.x, show_ax.y
	]
	_open_formal_city_panel(cid)


func _build_placement_hover_text() -> String:
	if _placement_city_id == "" or _placement_building_id == "":
		return _default_hover_text()
	var bname: String = str(DataManager.get_building(_placement_building_id).get("name", _placement_building_id))
	return "放置模式：点击绿色格建造「%s」（右键取消）" % bname


func _embed_formal_resource_bar(target_vbox: VBoxContainer) -> void:
	_ensure_formal_resource_bar()
	if _formal_resource_bar == null:
		return
	if _formal_resource_bar.get_parent() != null:
		_formal_resource_bar.get_parent().remove_child(_formal_resource_bar)
	target_vbox.add_child(_formal_resource_bar)
	target_vbox.move_child(_formal_resource_bar, 1)
	_formal_resource_bar.visible = true
	_refresh_formal_resource_bar()


func _detach_formal_resource_bar() -> void:
	if _formal_resource_bar != null and _formal_resource_bar.get_parent() != null:
		_formal_resource_bar.get_parent().remove_child(_formal_resource_bar)


func _on_formal_city_panel_closed() -> void:
	if is_instance_valid(_formal_city_panel):
		_detach_formal_resource_bar()
		_formal_city_panel.close()
	_formal_city_panel = null
	_ensure_formal_resource_bar()


func _on_formal_city_panel_return_to_skirmish() -> void:
	if is_instance_valid(_formal_city_panel):
		_detach_formal_resource_bar()
		_formal_city_panel.close()
	_formal_city_panel = null
	_ensure_formal_resource_bar()
	_hint.text = "已返回战术演武小地图。可继续经营咸阳，或选择部队攻打洛邑城墙。"


func _default_hover_text() -> String:
	if TacticalSkirmishManager.is_active():
		if DemoFlow.is_tutorial_enabled():
			return "点城格经营；右键取消。"
		if DemoFlow.is_enabled():
			return "悬停看格；点城格进城。"
	return "悬停格子查看信息。"


func _initial_hint_text() -> String:
	return _demo_skirmish_briefing()


func _demo_skirmish_briefing() -> String:
	if not TacticalSkirmishManager.is_active():
		return ""
	var target_city_name: String = DemoFlow.get_target_city_name()
	if target_city_name == "":
		target_city_name = "敌城"
	var enemy_city: Vector2i = TacticalSkirmishManager.get_enemy_city()
	var wall_hp: int = TacticalSkirmishManager.get_city_wall_hp(enemy_city)
	var wall_max: int = TacticalSkirmishManager.get_city_wall_max_hp(enemy_city)
	if wall_hp > 0:
		return "Demo 作战简报：将%s城市 HP 打到 0（%d/%d）后进驻占领。" % [target_city_name, wall_hp, wall_max]
	if wall_max > 0:
		return "Demo 作战简报：%s城市 HP=0，直接进驻即可占领。" % target_city_name
	if DemoFlow.is_enabled():
		return "Demo 作战简报：向%s推进，破墙进城。" % target_city_name
	return ""


func _on_close_pressed() -> void:
	close_panel()


func _on_campaign_city_ownership_changed(_city_id: String, _old_faction: String, _new_faction: String) -> void:
	if _political_mode:
		_rebuild_political_grid()
		if visible:
			_refresh_display()


func _on_political_toggle() -> void:
	_political_mode = not _political_mode
	if _political_map_btn != null:
		_political_map_btn.text = "政治地图：开" if _political_mode else "政治地图：关"
	if _political_mode:
		_rebuild_political_grid()
	_refresh_display()


## 与大地图同一套 BigMapPoliticalControl 影响力填充（战术坐标 + 场景/战役城池）
func _rebuild_political_grid() -> void:
	var cfg: Dictionary = TacticalSkirmishManager.get_active_config()
	var w: int = int(cfg.get("map_width", 0))
	var h: int = int(cfg.get("map_height", 0))
	if w <= 0 or h <= 0:
		_political_grid = {}
		return
	var cities: Array = []
	_append_political_city(cities, cfg.get("player_city", {}), TacticalSkirmishManager.get_player_faction())
	_append_political_city(cities, cfg.get("enemy_city", {}), TacticalSkirmishManager.get_enemy_faction())
	var terrain_rows: Array = []
	for row: int in range(h):
		var arr: Array = []
		for col: int in range(w):
			arr.append(TacticalSkirmishManager.terrain_at(_HexAxial.offset_odd_r_to_axial(col, row)))
		terrain_rows.append(arr)
	var rules: Dictionary = DataManager.get_big_map_political_control()
	_political_grid = _BigMapPoliticalControl.build_resolved_control_grid(
		cities,
		[],
		Vector2i(w, h),
		rules,
		terrain_rows
	)


func _append_political_city(cities: Array, ccfg: Variant, fallback_fid: String) -> void:
	if not (ccfg is Dictionary):
		return
	var d: Dictionary = ccfg as Dictionary
	var city_id: String = str(d.get("city_id", ""))
	var fid: String = fallback_fid
	var level: int = int(d.get("level", 1))
	var is_cap: bool = bool(d.get("is_capital", false))
	var development: int = 0
	if city_id != "" and not CityManager.get_city_state(city_id).is_empty():
		var st: Dictionary = CityManager.get_city_state(city_id)
		fid = str(st.get("current_faction_id", fallback_fid))
		level = int(st.get("city_level", level))
		is_cap = bool(st.get("is_capital", is_cap))
		development = int(st.get("development", 0))
	cities.append({
		"hex_q": int(d.get("q", 0)),
		"hex_r": int(d.get("r", 0)),
		"current_faction_id": fid,
		"city_level": level,
		"is_capital": is_cap,
		"development": development,
	})


func _do_standby_selected() -> void:
	if _selected_unit_id == "":
		return
	TacticalSkirmishManager.finalize_player_unit_action(_selected_unit_id)
	_selected_unit_id = ""
	_reachable.clear()
	_refresh_display()


func _do_retreat_unit(unit_id: String) -> void:
	if unit_id.is_empty():
		return
	var res: Dictionary = TacticalSkirmishManager.try_retreat(unit_id)
	_selected_unit_id = ""
	_reachable.clear()
	_refresh_display()


func _try_open_city_panel_at(cell: Vector2i) -> bool:
	var cfg: Dictionary = TacticalSkirmishManager.get_active_config()
	var matched: Dictionary = {}
	for key: String in ["player_city", "enemy_city"]:
		var ccfg: Dictionary = cfg.get(key, {}) as Dictionary
		if ccfg.is_empty():
			continue
		var axial: Vector2i = _HexAxial.offset_odd_r_to_axial(int(ccfg.get("q", -99)), int(ccfg.get("r", -99)))
		if axial == cell:
			matched = ccfg
			break
	if matched.is_empty():
		return false
	var city_id: String = str(matched.get("city_id", ""))
	if city_id.is_empty() or CityManager.get_city_state(city_id).is_empty():
		return false
	var owner: String = str(CityManager.get_city_state(city_id).get("current_faction_id", ""))
	var player: String = TacticalSkirmishManager.get_player_faction()
	if player == "":
		player = GameManager.get_player_faction()
	if owner != player and owner != GameManager.get_player_faction():
		return false
	_open_formal_city_panel(city_id)
	return true


func _on_hex_right_clicked(_q: int, _r: int) -> void:
	if _placement_city_id != "":
		_cancel_skirmish_building_placement()
		return
	if _selected_unit_id != "":
		_selected_unit_id = ""
		_reachable.clear()
		_refresh_display()


func _update_season_label() -> void:
	var season: String = TacticalSkirmishManager.get_current_season()
	var names: Dictionary = {"spring": "春", "summer": "夏", "autumn": "秋", "winter": "冬"}
	_season_label.text = "季节：%s" % names.get(season, season)


func _on_restart_pressed() -> void:
	if not _panel_cfg.is_empty():
		open_panel_with_config(_panel_cfg.duplicate(true), _panel_season)
		return
	TacticalSkirmishManager.reset_skirmish()
	TacticalSkirmishManager.start_skirmish()
	_prepare_panel_for_active_skirmish()


## 演武 Demo/演武：存档（局中快照 + 战役结果，演武=战役）
func _on_skirmish_save_pressed() -> void:
	var parts: Array[String] = []
	if TacticalSkirmishManager.is_active():
		var sres: Dictionary = SkirmishSaveManager.save_to_slot(0)
		if bool(sres.get("success", false)):
			parts.append("演武快照槽1")
		else:
			parts.append("演武快照失败:%s" % str(sres.get("reason", "")))
	var cres: Dictionary = SaveManager.save_to_slot(0)
	if bool(cres.get("success", false)):
		parts.append("战役槽1")
	else:
		parts.append("战役失败:%s" % str(cres.get("reason", "")))
	_hint.text = "已存档：「%s」。" % " + ".join(parts)
	_update_season_label()
	_refresh_formal_resource_bar()


## 读档：优先演武快照（续打）；否则读战役档
func _on_skirmish_load_pressed() -> void:
	if SkirmishSaveManager.has_save(0):
		var lres: Dictionary = SkirmishSaveManager.load_from_slot(0)
		if bool(lres.get("success", false)):
			_selected_unit_id = ""
			_reachable.clear()
			show()
			_prepare_panel_for_active_skirmish()
			_hint.text = "已读取演武快照槽1（场景 %s，单位 %s）。" % [
				str(lres.get("scenario_id", "")), str(lres.get("units", 0))
			]
			return
		_hint.text = "演武读档失败：%s" % str(lres.get("reason", ""))
		return
	if SaveManager.has_save(0):
		var cres: Dictionary = SaveManager.load_from_slot(0)
		if bool(cres.get("success", false)):
			# 战役档已恢复；演武需重新开局（结果在战役城池里）
			if not TacticalSkirmishManager.is_active():
				if not _panel_cfg.is_empty():
					TacticalSkirmishManager.start_skirmish_with_config(_panel_cfg.duplicate(true), _panel_season)
				else:
					TacticalSkirmishManager.start_skirmish()
			_prepare_panel_for_active_skirmish()
			_hint.text = "已读取战役槽1（第 %s 回合）。演武局中无快照，已按当前场景重开。" % str(cres.get("turn", 0))
			return
		_hint.text = "战役读档失败：%s" % str(cres.get("reason", ""))
		return
	_hint.text = "槽位 1 无演武快照，也无战役存档。"


func _on_end_turn_pressed() -> void:
	if TacticalSkirmishManager.is_active():
		TacticalSkirmishManager.end_player_turn()
	if DemoFlow.is_tutorial_enabled():
		_advance_formal_turn_for_tutorial()
	_selected_unit_id = ""
	_reachable.clear()
	_refresh_display()


func _advance_formal_turn_for_tutorial() -> void:
	if GameManager.get_current_phase() != GameManager.Phase.ACTION:
		return
	# 战役季节权威：CityManager；演武季节展示：TacticalSkirmishManager
	var old_season: String = CityManager.get_current_season(GameManager.get_current_turn())
	if old_season == "":
		old_season = TacticalSkirmishManager.get_current_season()
	GameManager.run_ai_continuation()
	var new_season: String = CityManager.get_current_season(GameManager.get_current_turn())
	TacticalSkirmishManager.set_season(new_season)
	_update_season_label()
	_refresh_formal_resource_bar()
	if is_instance_valid(_formal_city_panel):
		if _formal_city_panel.has_method("refresh"):
			_formal_city_panel.refresh()
	var names: Dictionary = {"spring": "春", "summer": "夏", "autumn": "秋", "winter": "冬"}
	_hint.text = "正式回合已结算：第 %d 回合，季节 %s → %s；资源、征兵池和城市经营已刷新。" % [
		GameManager.get_current_turn(),
		str(names.get(old_season, old_season)),
		str(names.get(new_season, new_season)),
	]


func _ensure_hex_buttons() -> void:
	var cfg: Dictionary = TacticalSkirmishManager.get_active_config()
	var w: int = int(cfg.get("map_width", 7))
	var h: int = int(cfg.get("map_height", 7))
	var expected_cells: int = w * h
	var existing_hex_cells: int = 0
	for ch: Node in _hex_board.get_children():
		if ch is SkirmishHexCell:
			existing_hex_cells += 1
	if (
		existing_hex_cells == expected_cells
		and int(_hex_board.get_meta("_hex_layout_v", 0)) == _HEX_BOARD_LAYOUT_VERSION
	):
		return
	while _hex_board.get_child_count() > 0:
		_hex_board.get_child(0).free()
	var pad: float = _HEX_BOARD_PAD_PX
	var radius_px: float = _compute_hex_radius_px(w, h, pad)
	var sqrt3: float = sqrt(3.0)
	## 平顶六角外包：宽 2R、高 √3·R，矩形布局
	var cell_w: float = radius_px * 2.0
	var cell_h: float = radius_px * sqrt3
	var min_tl_x: float = INF
	var min_tl_y: float = INF
	var max_br_x: float = -INF
	var max_br_y: float = -INF
	var row_scan: int = 0
	while row_scan < h:
		var col_scan: int = 0
		while col_scan < w:
			var tl_s: Vector2 = _HexAxial.offset_odd_r_flat_top_cell_top_left_rect(col_scan, row_scan, radius_px)
			min_tl_x = minf(min_tl_x, tl_s.x)
			min_tl_y = minf(min_tl_y, tl_s.y)
			max_br_x = maxf(max_br_x, tl_s.x + cell_w)
			max_br_y = maxf(max_br_y, tl_s.y + cell_h)
			col_scan += 1
		row_scan += 1
	var origin_shift: Vector2 = Vector2(min_tl_x, min_tl_y)
	var row_var: int = 0
	while row_var < h:
		var col_var: int = 0
		while col_var < w:
			var axial_pos: Vector2i = _HexAxial.offset_odd_r_to_axial(col_var, row_var)
			var tl: Vector2 = _HexAxial.offset_odd_r_flat_top_cell_top_left_rect(col_var, row_var, radius_px)
			var cell: SkirmishHexCell = SkirmishHexCell.new()
			cell.configure(axial_pos.x, axial_pos.y, radius_px, cell_w, cell_h)
			cell.set_board_bounds(w, h)
			var pos: Vector2 = tl - origin_shift + Vector2(pad, pad)
			cell.position = pos.snapped(Vector2(0.5, 0.5))
			var cap: Label = Label.new()
			cap.name = "CellCaption"
			cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cap.set_anchors_preset(Control.PRESET_FULL_RECT)
			cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cap.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			cap.add_theme_font_size_override("font_size", clampi(int(radius_px * 0.26), 11, 19))
			cap.add_theme_color_override("font_color", Color(1, 1, 1, 1))
			cap.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.1, 1))
			cap.add_theme_constant_override("outline_size", 2)
			cap.z_index = 5
			cell.add_child(cap)
			var aq: int = axial_pos.x
			var ar: int = axial_pos.y
			cell.hex_clicked.connect(_on_hex_pressed)
			cell.hex_double_clicked.connect(_on_hex_double_clicked)
			cell.hex_right_clicked.connect(_on_hex_right_clicked)
			cell.mouse_entered.connect(func() -> void:
				_on_hex_mouse_enter(aq, ar)
			)
			cell.mouse_exited.connect(_on_hex_mouse_exit)
			_hex_board.add_child(cell)
			cell.notify_size_changed()
			col_var += 1
		row_var += 1
	var bb_w: float = max_br_x - min_tl_x + pad * 2.0
	var bb_h: float = max_br_y - min_tl_y + pad * 2.0
	_hex_board.custom_minimum_size = Vector2(bb_w, bb_h)
	_hex_board.size = _hex_board.custom_minimum_size
	_hex_board.set_meta("_hex_layout_v", _HEX_BOARD_LAYOUT_VERSION)
	_hex_board.set_meta("_hex_radius_applied", radius_px)


func _hex_play_area_avail_px() -> Vector2:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var sc: Control = $MarginContainer/MainVBox/Scroll as Control
	var ss: Vector2 = sc.size
	var from_vp: Vector2 = Vector2(
		clampf(vp.x * 0.96 - 36.0, 720.0, 2000.0),
		clampf(vp.y * 0.86 - 40.0, 480.0, 1400.0)
	)
	if ss.x >= 100.0 and ss.y >= 100.0:
		return Vector2(maxf(ss.x, from_vp.x), maxf(ss.y, from_vp.y))
	return from_vp


func _deferred_refit_hex_radius_if_needed() -> void:
	if not visible or not _hex_refit_pending:
		return
	_hex_refit_pending = false
	var cfg: Dictionary = TacticalSkirmishManager.get_active_config()
	var w: int = int(cfg.get("map_width", 7))
	var h: int = int(cfg.get("map_height", 7))
	var pad: float = _HEX_BOARD_PAD_PX
	var r_new: float = _compute_hex_radius_px(w, h, pad)
	var r_old: float = float(_hex_board.get_meta("_hex_radius_applied", -1.0))
	if r_old < 0.0 or absf(r_new - r_old) >= 1.5:
		_hex_board.set_meta("_hex_layout_v", 0)
		_ensure_hex_buttons()
		_ensure_board_backdrop()
		_refresh_display()


func _map_bbox_unit(w: int, h: int, pad: float, radius: float) -> Vector2:
	var sqrt3: float = sqrt(3.0)
	var cell_w: float = radius * 2.0
	var cell_h: float = radius * sqrt3
	var min_tl_x: float = INF
	var min_tl_y: float = INF
	var max_br_x: float = -INF
	var max_br_y: float = -INF
	var row_scan: int = 0
	while row_scan < h:
		var col_scan: int = 0
		while col_scan < w:
			var tl_scan: Vector2 = _HexAxial.offset_odd_r_flat_top_cell_top_left_rect(col_scan, row_scan, radius)
			min_tl_x = minf(min_tl_x, tl_scan.x)
			min_tl_y = minf(min_tl_y, tl_scan.y)
			max_br_x = maxf(max_br_x, tl_scan.x + cell_w)
			max_br_y = maxf(max_br_y, tl_scan.y + cell_h)
			col_scan += 1
		row_scan += 1
	return Vector2(max_br_x - min_tl_x + pad * 2.0, max_br_y - min_tl_y + pad * 2.0)


func _compute_hex_radius_px(w: int, h: int, pad: float) -> float:
	var bb_unit: Vector2 = _map_bbox_unit(w, h, pad, 1.0)
	if bb_unit.x < 1.0 or bb_unit.y < 1.0:
		return _HEX_RADIUS_BASE_PX
	var avail: Vector2 = _hex_play_area_avail_px()
	var s: float = minf(avail.x / bb_unit.x, avail.y / bb_unit.y) * 0.99
	s = clampf(s, 64.0, 260.0)
	return s


func _ensure_board_backdrop() -> void:
	var bg: ColorRect = _hex_board.get_node_or_null("BoardBackdrop") as ColorRect
	if bg == null:
		bg = ColorRect.new()
		bg.name = "BoardBackdrop"
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.z_index = -100
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.offset_left = 0.0
		bg.offset_top = 0.0
		bg.offset_right = 0.0
		bg.offset_bottom = 0.0
		_hex_board.add_child(bg)
		_hex_board.move_child(bg, 0)
	bg.color = Color(0.50, 0.55, 0.45, 1.0)
	_ensure_hex_map_canvas()


func _ensure_hex_map_canvas() -> void:
	var cv: HexMapCanvas = _hex_board.get_node_or_null("HexMapCanvas") as HexMapCanvas
	if cv == null:
		cv = HexMapCanvas.new()
		cv.name = "HexMapCanvas"
		_hex_board.add_child(cv)
	var backdrop: Node = _hex_board.get_node_or_null("BoardBackdrop")
	if backdrop != null:
		var bi: int = backdrop.get_index()
		if cv.get_index() != bi + 1:
			_hex_board.move_child(cv, bi + 1)
	elif cv.get_index() != 0:
		_hex_board.move_child(cv, 0)
	cv.custom_minimum_size = _hex_board.custom_minimum_size
	cv.size = _hex_board.custom_minimum_size
	cv.queue_redraw()


func _on_hex_mouse_enter(q: int, r: int) -> void:
	if _placement_city_id != "":
		var cell: Vector2i = Vector2i(q, r)
		var highlight: Dictionary = _placement_highlight_map()
		var bname: String = str(DataManager.get_building(_placement_building_id).get("name", _placement_building_id))
		if highlight.has(cell):
			var check: Dictionary = CityManager.can_build(_placement_city_id, _placement_building_id, cell)
			if bool(check.get("allowed", false)):
				_hover_info.text = "点击放置「%s」于战役辖区 (%d,%d)" % [bname, q, r]
			else:
				var auto: Dictionary = CityManager.can_build(_placement_city_id, _placement_building_id)
				if bool(auto.get("allowed", false)):
					_hover_info.text = "点击放置「%s」→ 战役辖区 (%d,%d)" % [
						bname, int(auto.get("hex_q", q)), int(auto.get("hex_r", r))
					]
				else:
					_hover_info.text = "(%d,%d) 不可放置：%s" % [q, r, str(check.get("reason", ""))]
		else:
			_hover_info.text = "(%d,%d) 不在放置范围" % [q, r]
		return
	_hover_info.text = _build_hover_text(Vector2i(q, r))


func _on_hex_mouse_exit() -> void:
	if _placement_city_id != "":
		_hover_info.text = _build_placement_hover_text()
		return
	_hover_info.text = _default_hover_text()


func _build_hover_text(cell: Vector2i) -> String:
	var t_id: String = TacticalSkirmishManager.terrain_at(cell)
	var tdata: Dictionary = DataManager.get_terrain(t_id)
	var t_name: String = str(tdata.get("name", t_id))
	var mc: Variant = tdata.get("move_cost", 1)
	var mc_str: String = "不可通行" if int(mc) < 0 else str(mc)
	var atk_m: float = float(tdata.get("atk_mod", 1.0))
	var def_m: float = float(tdata.get("def_mod", 1.0))
	var amb: float = float(tdata.get("ambush_chance", 0.0))
	var amb_str: String = ("伏击+%d%%" % int(round(amb * 100.0))) if amb > 0.001 else ""
	var lines: PackedStringArray = []
	var terrain_line: String = "地形：%s ｜ 移耗%s ｜ 攻×%.2f 守×%.2f" % [t_name, mc_str, atk_m, def_m]
	if amb_str != "":
		terrain_line += " ｜ " + amb_str
	lines.append(terrain_line)
	# 城市信息
	var pc: Vector2i = TacticalSkirmishManager.get_player_city()
	var ec: Vector2i = TacticalSkirmishManager.get_enemy_city()
	var wall_hp: int = TacticalSkirmishManager.get_city_wall_hp(cell)
	var wall_max: int = TacticalSkirmishManager.get_city_wall_max_hp(cell)
	if _political_mode:
		if _political_grid.is_empty():
			_rebuild_political_grid()
		var pol_fid: String = str(_political_grid.get(cell, ""))
		if pol_fid == "":
			lines.append("政治归属：中立/缓冲")
		else:
			lines.append("政治归属：%s" % _faction_display_name(pol_fid))
	if cell == pc or cell == ec:
		var owner_str: String = "己方" if cell == pc else "敌方"
		var city_line: String = "据点：%s城格" % owner_str
		if wall_hp >= 0:
			if wall_hp > 0:
				city_line += " ｜ 城市 HP %d/%d" % [wall_hp, wall_max]
			else:
				city_line += " ｜ 城市 HP=0（可进驻占领）"
		var binfo: Dictionary = _building_icon_info(cell)
		if not binfo.is_empty():
			city_line += " ｜ 建筑×%d（%s）" % [int(binfo.get("count", 1)), str(binfo.get("name", ""))]
		lines.append(city_line)
	elif wall_hp > 0:
		lines.append("城墙：%d/%d" % [wall_hp, wall_max])
	var cell_pass_hp: int = TacticalSkirmishManager.get_pass_hp(cell)
	if cell_pass_hp >= 0:
		var cell_pass_owner: String = TacticalSkirmishManager.get_pass_owner(cell)
		lines.append("关隘：%s ｜ 结构 %d ｜ 规则与大地图相同（破结构后进驻可占）" % [
			_faction_display_name(cell_pass_owner) if cell_pass_owner != "" else "中立",
			cell_pass_hp,
		])
	# 单位信息
	var uu: Dictionary = _unit_at_cell(cell)
	if not uu.is_empty():
		var fid: String = str(uu["faction_id"])
		var fac_name: String = _faction_display_name(fid)
		var ut: Dictionary = DataManager.get_unit_type(str(uu["unit_type_id"]))
		var ut_name: String = str(ut.get("name", uu["unit_type_id"]))
		var base_atk: int = int(ut.get("attack", 10))
		var base_def: int = int(ut.get("defense", 10))
		var rng: int = int(ut.get("range", 1))
		var cat: String = str(ut.get("category", ""))
		var spd: int = int(uu.get("speed", 3))
		var rem: int = int(uu.get("mp_remaining", spd))
		var acted: bool = bool(uu.get("acted", false))
		var act_str: String = "已行动" if acted else "待命"
		lines.append("[ %s · %s ] %s" % [fac_name, ut_name, act_str])
		lines.append("HP %d/%d ｜ 攻击 %d ｜ 防御 %d ｜ 射程 %d ｜ 移动力 %d/%d" % [
			int(uu["hp"]), int(uu["max_hp"]), base_atk, base_def, rng, rem, spd
		])
		var uid: String = str(uu["id"])
		var morale_val: int = TacticalSkirmishManager.get_unit_morale(uid)
		var burn_val: int = TacticalSkirmishManager.get_unit_burn(uid)
		var supplied: bool = TacticalSkirmishManager.get_unit_supply(uid)
		var status_parts: PackedStringArray = []
		status_parts.append(UnitMoraleRules.format_morale_info(morale_val))
		if not supplied:
			status_parts.append("[color=red]断粮[/color]")
		if burn_val > 0:
			status_parts.append("[color=orange]烧伤(%d回合)[/color]" % burn_val)
		# 技能
		var skills: Array = uu.get("skills", [])
		if not skills.is_empty():
			var skill_names: PackedStringArray = []
			for sk: Variant in skills:
				var sd: Dictionary = sk as Dictionary
				skill_names.append(str(sd.get("name", sd.get("type", "?"))))
			status_parts.append("技能：%s" % ", ".join(skill_names))
		lines.append("状态：%s" % " | ".join(status_parts))
		# 选中己方单位时：攻击预览
		if _selected_unit_id != "" and fid == TacticalSkirmishManager.get_enemy_faction():
			_append_attack_preview(lines, _selected_unit_id, str(uu["id"]), false)
	# 选中己方单位 + 城墙格：攻城预览
	if _selected_unit_id != "" and wall_hp > 0 and uu.is_empty():
		_append_attack_preview(lines, _selected_unit_id, cell, true)
	return "\n".join(lines)


## 追加攻击预览信息（单位攻击或攻城）
func _append_attack_preview(lines: PackedStringArray, attacker_id: String, target: Variant, is_wall: bool) -> void:
	var preview: Dictionary = TacticalSkirmishManager.compute_attack_preview(attacker_id, target)
	if preview.is_empty():
		return
	var base_a: int = int(preview["base_atk"])
	var eff_a: float = float(preview["effective_atk"])
	var atk_parts: PackedStringArray = []
	atk_parts.append("基础 %d" % base_a)
	for d: String in preview["atk_details"]:
		atk_parts.append(d)
	lines.append("── 攻击：%s → 实际 %.0f" % [" + ".join(atk_parts), eff_a])
	if not is_wall:
		var base_d: int = int(preview["base_def"])
		var eff_d: float = float(preview["effective_def"])
		var def_parts: PackedStringArray = []
		def_parts.append("基础 %d" % base_d)
		for d2: String in preview["def_details"]:
			def_parts.append(d2)
		lines.append("── 防御：%s → 实际 %.0f" % [" + ".join(def_parts), eff_d])
		var counter: float = float(preview["counter"])
		var counter_str: String = ""
		if counter > 1.05:
			counter_str = "（克制 ×%.1f）" % counter
		elif counter < 0.95:
			counter_str = "（被克 ×%.1f）" % counter
		var dmg_lo: int = int(preview.get("expected_dmg_lo", preview["expected_dmg"]))
		var dmg_hi: int = int(preview.get("expected_dmg_hi", preview["expected_dmg"]))
		lines.append("── 公式：(攻%.0f × 克制%.1f - 防%.0f) ≈ [color=yellow]预期伤害 %d~%d[/color]" % [
			eff_a, counter, eff_d, dmg_lo, dmg_hi
		])
		if counter_str != "":
			lines.append("── %s" % counter_str)
		# 反击预览
		if bool(preview.get("can_counter", false)):
			var c_dmg: int = int(preview.get("counter_atk_dmg", 0))
			var c_dmg_lo: int = int(preview.get("counter_atk_dmg_lo", c_dmg))
			var c_dmg_hi: int = int(preview.get("counter_atk_dmg_hi", c_dmg))
			var c_parts: PackedStringArray = []
			for cd: String in preview.get("counter_details", []):
				c_parts.append(cd)
			lines.append("── 反伤：%s → [color=orange]预计受到 %d~%d 反击伤害[/color]" % [
				" + ".join(c_parts) if not c_parts.is_empty() else "—", c_dmg_lo, c_dmg_hi
			])
		else:
			lines.append("── [color=gray]远程攻击不触发反击[/color]")
	else:
		var siege_mult_v: Variant = DataManager.get_balance_param("city_combat.siege_damage_multiplier")
		var siege_mult: float = float(siege_mult_v) if siege_mult_v != null else 3.0
		var a_unit2: Dictionary = TacticalSkirmishManager.get_unit_by_id(attacker_id)
		var a_utype: Dictionary = DataManager.get_unit_type(str(a_unit2.get("unit_type_id", "")))
		var is_siege: bool = str(a_utype.get("special", "")) == "siege_bonus" or str(a_utype.get("category", "")) == "siege"
		var siege_note: String = "（攻城器械 ×%.0f）" % siege_mult if is_siege else ""
		lines.append("── 公式：攻%.0f × 50%% → [color=yellow]预期城墙伤害 %d[/color]%s" % [
			eff_a, int(preview["wall_dmg"]), siege_note
		])
	# 可攻击提示
	var can_atk: bool = false
	if not is_wall:
		can_atk = TacticalSkirmishManager.list_attack_targets(attacker_id).has(str(target))
	else:
		var a_unit: Dictionary = TacticalSkirmishManager.get_unit_by_id(attacker_id)
		if not a_unit.is_empty():
			var ac: Vector2i = Vector2i(int(a_unit["q"]), int(a_unit["r"]))
			var dc: Vector2i = target as Vector2i
			var dq: int = ac.x - dc.x
			var dr: int = ac.y - dc.y
			var dist: int = maxi(abs(dq), maxi(abs(dr), abs(dq + dr)))
			var ug: Dictionary = DataManager.get_unit_type(str(a_unit["unit_type_id"]))
			var rng2: int = int(ug.get("range", 1))
			can_atk = dist >= 1 and dist <= rng2
	if can_atk:
		lines.append("[color=green]可攻击[/color]")
	else:
		lines.append("[color=gray]超出射程或移动力不足[/color]")


func _faction_display_name(faction_id: String) -> String:
	var f: Dictionary = DataManager.get_faction(faction_id)
	if not f.is_empty():
		return str(f.get("name", faction_id))
	match faction_id:
		"qin":
			return "秦国"
		"zhao":
			return "赵国"
		_:
			return faction_id


func _on_hex_pressed(q: int, r: int) -> void:
	if not TacticalSkirmishManager.is_active():
		return
	var cell: Vector2i = Vector2i(q, r)
	if _placement_city_id != "":
		_try_place_building_in_skirmish(cell)
		return
	var occ: Dictionary = _unit_at_cell(cell)
	# 点己方单位：切换选中；再次点击已选中单位＝待命结束
	if not occ.is_empty() and str(occ.get("faction_id", "")) == TacticalSkirmishManager.get_player_faction():
		if bool(occ.get("acted", false)):
			return
		if str(occ["id"]) == _selected_unit_id:
			_do_standby_selected()
			return
		_selected_unit_id = str(occ["id"])
		_reachable = TacticalSkirmishManager.get_reachable_cells(_selected_unit_id)
		_refresh_display()
		return
	# 点城：打开己方城市面板（与大地图一致）
	if _try_open_city_panel_at(cell):
		return
	# 已选中己方：优先攻击射程内敌军
	if _selected_unit_id != "":
		if not occ.is_empty() and str(occ.get("faction_id", "")) == TacticalSkirmishManager.get_enemy_faction():
			var res: Dictionary = TacticalSkirmishManager.try_player_attack(_selected_unit_id, str(occ["id"]))
			if bool(res.get("ok", false)):
				_selected_unit_id = ""
				_reachable.clear()
			_refresh_display()
			return
	# 已选中己方：攻击敌关隘 / 城墙 / 可走格移动（与大地图同一套占领规则）
	if _selected_unit_id != "":
		if occ.is_empty():
			var pass_hp: int = TacticalSkirmishManager.get_pass_hp(cell)
			if pass_hp >= 0:
				var powner: String = TacticalSkirmishManager.get_pass_owner(cell)
				if powner != TacticalSkirmishManager.get_player_faction() and pass_hp > 0:
					var atk_pass: Dictionary = TacticalSkirmishManager.try_attack_pass(_selected_unit_id, cell)
					if bool(atk_pass.get("ok", false)):
						if bool(atk_pass.get("destroyed", false)):
							_selected_unit_id = ""
							_reachable.clear()
						else:
							_reachable = TacticalSkirmishManager.get_reachable_cells(_selected_unit_id)
					_refresh_display()
					return
			if _reachable.has(cell):
				var moving_id: String = _selected_unit_id
				var mv: Dictionary = TacticalSkirmishManager.try_move_unit(moving_id, cell)
				if bool(mv.get("ok", false)):
					_selected_unit_id = moving_id
					_reachable = TacticalSkirmishManager.get_reachable_cells(moving_id)
				else:
					_selected_unit_id = ""
					_reachable.clear()
				_refresh_display()
				return
			var wall_hp: int = TacticalSkirmishManager.get_city_wall_hp(cell)
			if wall_hp > 0:
				var atk_res: Dictionary = TacticalSkirmishManager.try_attack_city_wall(_selected_unit_id, cell)
				if bool(atk_res.get("ok", false)):
					_selected_unit_id = ""
					_reachable.clear()
		_refresh_display()
		return
	# 未选中且非己方单位：清空选择（与大地图一致）
	_selected_unit_id = ""
	_reachable.clear()
	_refresh_display()


func _on_hex_double_clicked(q: int, r: int) -> void:
	if not TacticalSkirmishManager.is_active() or _placement_city_id != "":
		return
	var cell: Vector2i = Vector2i(q, r)
	var occ: Dictionary = _unit_at_cell(cell)
	if occ.is_empty() or str(occ.get("faction_id", "")) != TacticalSkirmishManager.get_player_faction():
		return
	_do_retreat_unit(str(occ.get("id", "")))


func _unit_at_cell(cell: Vector2i) -> Dictionary:
	for u: Dictionary in TacticalSkirmishManager.get_units():
		if Vector2i(int(u["q"]), int(u["r"])) == cell:
			return u
	return {}


func _is_attackable_enemy_cell(cell: Vector2i) -> bool:
	if _selected_unit_id == "":
		return false
	var occ: Dictionary = _unit_at_cell(cell)
	if occ.is_empty():
		return false
	if str(occ.get("faction_id", "")) != TacticalSkirmishManager.get_enemy_faction():
		return false
	return TacticalSkirmishManager.list_attack_targets(_selected_unit_id).has(str(occ["id"]))


func _refresh_display() -> void:
	if _refresh_suspended:
		return
	if not visible or _hex_board == null:
		return
	_update_tutorial_formal_ui()
	_refresh_formal_resource_bar()
	# 文案精简：空提示不占布局
	if _hint != null:
		_hint.visible = not _hint.text.is_empty()
		if not _hint.visible:
			_hint.custom_minimum_size = Vector2(0, 0)
			_hint.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var cfg: Dictionary = TacticalSkirmishManager.get_active_config()
	var w: int = int(cfg.get("map_width", 7))
	var h: int = int(cfg.get("map_height", 7))
	_debug_log("[SkirmishPanel] _refresh_display: w=%d h=%d active=%s" % [w, h, str(TacticalSkirmishManager.is_active())])
	var by_axial: Dictionary = {}
	var hex_count: int = 0
	for ch: Node in _hex_board.get_children():
		if ch is SkirmishHexCell:
			var hc: SkirmishHexCell = ch as SkirmishHexCell
			by_axial[Vector2i(hc.cell_q, hc.cell_r)] = hc
			hex_count += 1
	_debug_log("[SkirmishPanel] _refresh_display: hex_count=%d expected=%d" % [hex_count, w * h])
	if hex_count < w * h:
		return
	var row_var: int = 0
	while row_var < h:
		var col_var: int = 0
		while col_var < w:
			var cell_axial: Vector2i = _HexAxial.offset_odd_r_to_axial(col_var, row_var)
			var hex_cell: SkirmishHexCell = by_axial.get(cell_axial, null) as SkirmishHexCell
			if hex_cell == null:
				push_error("SkirmishMVP: 缺少轴向格 (%d,%d) col=%d row=%d" % [cell_axial.x, cell_axial.y, col_var, row_var])
				return
			var t_id: String = TacticalSkirmishManager.terrain_at(cell_axial)
			var uu: Dictionary = _unit_at_cell(cell_axial)
			var cap: Label = hex_cell.get_node_or_null("CellCaption") as Label
			var tex: Texture2D = SkirmishTileTextures.terrain_texture(t_id)
			var terrain_color: Color = SkirmishTileTextures.terrain_fallback_color(t_id)
			hex_cell.set_terrain_style(tex, terrain_color)
			hex_cell.set_tint_color(_cell_tint_color(cell_axial, uu))
			var tag: String = ""
			if cell_axial == TacticalSkirmishManager.get_player_city():
				var wh: int = TacticalSkirmishManager.get_city_wall_hp(cell_axial)
				var wm: int = TacticalSkirmishManager.get_city_wall_max_hp(cell_axial)
				if wh > 0:
					tag = "秦城\nHP %d/%d" % [wh, wm]
				else:
					tag = "秦城（HP=0）"
			elif cell_axial == TacticalSkirmishManager.get_enemy_city():
				var enemy_city_name: String = DemoFlow.get_target_city_name() if DemoFlow.is_enabled() else "敌城"
				var eh: int = TacticalSkirmishManager.get_city_wall_hp(cell_axial)
				var em: int = TacticalSkirmishManager.get_city_wall_max_hp(cell_axial)
				if eh > 0:
					tag = "%s\nHP %d/%d" % [enemy_city_name, eh, em]
				else:
					tag = "%s（HP=0）" % enemy_city_name
			# 关隘 HP 显示
			var pass_hp: int = TacticalSkirmishManager.get_pass_hp(cell_axial)
			if pass_hp >= 0:
				var powner: String = TacticalSkirmishManager.get_pass_owner(cell_axial)
				var pname: String = "关隘"
				if powner != "":
					tag = "%s %s\nHP %d" % [pname, _faction_display_name(powner), pass_hp]
				else:
					tag = "%s\nHP %d" % [pname, pass_hp]
			var line2: String = ""
			if not uu.is_empty():
				var fn: String = _faction_short(str(uu["faction_id"]))
				line2 = "%s·%s\n%d/%d" % [fn, str(uu["unit_type_id"]), int(uu["hp"]), int(uu["max_hp"])]
			var caption_text: String = ""
			if tag != "":
				caption_text = tag + ("\n" + line2 if line2 != "" else "")
			else:
				caption_text = line2
			if cap != null:
				cap.text = caption_text
			_apply_capital_badge(hex_cell, cell_axial)
			_apply_building_badge(hex_cell, cell_axial)
			_apply_unit_overlay(hex_cell, uu)
			col_var += 1
		row_var += 1
	var map_cv: HexMapCanvas = _hex_board.get_node_or_null("HexMapCanvas") as HexMapCanvas
	if map_cv != null:
		map_cv.queue_redraw()


## 演武盘面建筑图标：点击落点优先 > 战役实体格 > 场景城池建筑汇总到城格
func _building_icon_info(cell: Vector2i) -> Dictionary:
	if _visual_building_marks.has(cell):
		var marked: String = str(_visual_building_marks.get(cell, ""))
		if marked != "":
			var md: Dictionary = DataManager.get_building(marked)
			return {
				"building_id": marked,
				"category": str(md.get("category", "")),
				"name": str(md.get("name", marked)),
				"count": 1,
			}
	var entry: Dictionary = CityManager.get_building_at_hex(cell)
	if not entry.is_empty():
		var bid0: String = str(entry.get("building_id", ""))
		var bdata0: Dictionary = DataManager.get_building(bid0)
		return {
			"building_id": bid0,
			"category": str(bdata0.get("category", "")),
			"name": str(bdata0.get("name", bid0)),
			"count": 1,
		}
	var cfg: Dictionary = TacticalSkirmishManager.get_active_config()
	var city_id: String = ""
	if cell == TacticalSkirmishManager.get_player_city():
		city_id = str((cfg.get("player_city", {}) as Dictionary).get("city_id", ""))
	elif cell == TacticalSkirmishManager.get_enemy_city():
		city_id = str((cfg.get("enemy_city", {}) as Dictionary).get("city_id", ""))
	if city_id.is_empty() or CityManager.get_city_state(city_id).is_empty():
		return {}
	var st: Dictionary = CityManager.get_city_state(city_id)
	var buildings: Array = st.get("buildings", []) as Array
	var queue: Array = st.get("build_queue", []) as Array
	if buildings.is_empty() and queue.is_empty():
		return {}
	var first_bid: String = ""
	if not buildings.is_empty():
		first_bid = str((buildings[0] as Dictionary).get("building_id", ""))
	elif not queue.is_empty():
		first_bid = str((queue[0] as Dictionary).get("building_id", ""))
	if first_bid.is_empty():
		return {}
	var bdata: Dictionary = DataManager.get_building(first_bid)
	return {
		"building_id": first_bid,
		"category": str(bdata.get("category", "")),
		"name": str(bdata.get("name", first_bid)),
		"count": buildings.size() + queue.size(),
	}


func _apply_building_badge(hex_cell: Control, cell: Vector2i) -> void:
	var info: Dictionary = _building_icon_info(cell)
	var badge: TextureRect = hex_cell.get_node_or_null("BuildingBadge") as TextureRect
	if info.is_empty():
		if badge != null:
			badge.visible = false
		return
	var tex: Texture2D = SkirmishTileTextures.building_texture(str(info.get("building_id", "")), str(info.get("category", "")))
	if tex == null:
		if badge != null:
			badge.visible = false
		return
	if badge == null:
		badge = TextureRect.new()
		badge.name = "BuildingBadge"
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		badge.z_index = 3
		hex_cell.add_child(badge)
	badge.texture = tex
	# 与 CapitalBadge 相同锚点体系：PRESET_CENTER + 从中心出发的 offset
	var base: float = minf(hex_cell.custom_minimum_size.x, hex_cell.custom_minimum_size.y)
	if hex_cell.size.x > 1.0:
		base = minf(hex_cell.size.x, hex_cell.size.y)
	var s: float = base * 0.22
	badge.set_anchors_preset(Control.PRESET_CENTER)
	badge.offset_left = s * 0.55
	badge.offset_top = s * 0.65
	badge.offset_right = s * 0.55 + s * 2.0
	badge.offset_bottom = s * 0.65 + s * 2.0
	badge.visible = true


func _faction_short(fid: String) -> String:
	match fid:
		"qin":
			return "秦"
		"zhao":
			return "赵"
		_:
			return fid


## 半透明叠色（不乘到地形贴上），优先级：放置高亮 > 政治 > 选中 > 可攻击 > 可走 > 空城 > 势力占位
func _cell_tint_color(cell: Vector2i, uu: Dictionary) -> Color:
	if _placement_city_id != "":
		var place_map: Dictionary = _placement_highlight_map()
		if place_map.has(cell):
			return place_map[cell] as Color
	if _political_mode:
		return _political_tint_color(cell, uu)
	if not uu.is_empty() and str(uu["id"]) == _selected_unit_id:
		return Color(_CLR_SELECTED.r, _CLR_SELECTED.g, _CLR_SELECTED.b, 0.45)
	if _is_attackable_enemy_cell(cell):
		return Color(_CLR_ATTACKABLE.r, _CLR_ATTACKABLE.g, _CLR_ATTACKABLE.b, 0.4)
	if _reachable.has(cell) and uu.is_empty():
		return Color(_CLR_EMPTY_REACH.r, _CLR_EMPTY_REACH.g, _CLR_EMPTY_REACH.b, 0.38)
	if uu.is_empty():
		if cell == TacticalSkirmishManager.get_player_city():
			return Color(_CLR_PLAYER_CITY.r, _CLR_PLAYER_CITY.g, _CLR_PLAYER_CITY.b, 0.26)
		if cell == TacticalSkirmishManager.get_enemy_city():
			return Color(_CLR_ENEMY_CITY.r, _CLR_ENEMY_CITY.g, _CLR_ENEMY_CITY.b, 0.26)
	if not uu.is_empty():
		var fid: String = str(uu["faction_id"])
		if fid == TacticalSkirmishManager.get_player_faction():
			return Color(_CLR_PLAYER_UNIT.r, _CLR_PLAYER_UNIT.g, _CLR_PLAYER_UNIT.b, 0.18)
		elif fid == TacticalSkirmishManager.get_enemy_faction():
			return Color(_CLR_ENEMY_UNIT.r, _CLR_ENEMY_UNIT.g, _CLR_ENEMY_UNIT.b, 0.18)
	return Color(0, 0, 0, 0)


func _political_tint_color(cell: Vector2i, _uu: Dictionary) -> Color:
	if _political_grid.is_empty():
		_rebuild_political_grid()
	var fid: String = str(_political_grid.get(cell, ""))
	if fid == "":
		# 城格兜底：与大地图 political tint 相同，用城池归属
		if cell == TacticalSkirmishManager.get_player_city():
			fid = TacticalSkirmishManager.get_player_faction()
		elif cell == TacticalSkirmishManager.get_enemy_city():
			fid = TacticalSkirmishManager.get_enemy_faction()
	if fid == "":
		return Color(0.42, 0.42, 0.42, 0.28)
	var fdata: Dictionary = DataManager.get_faction(fid)
	if fdata.is_empty():
		return Color(0.42, 0.42, 0.42, 0.42)
	var is_cap: bool = (cell == TacticalSkirmishManager.get_player_city()) or (cell == TacticalSkirmishManager.get_enemy_city())
	var c: Color = Color.html(str(fdata.get("color", "#888888")))
	c.a = 0.85 if is_cap else 0.7
	return c


## 秦/赵据点亮首都美术（叠在地形与描边之间，兵牌仍压在其上）
func _apply_capital_badge(hex_cell: Control, cell: Vector2i) -> void:
	var badge: TextureRect = hex_cell.get_node_or_null("CapitalBadge") as TextureRect
	var fid: String = ""
	if cell == TacticalSkirmishManager.get_player_city():
		fid = TacticalSkirmishManager.get_player_faction()
	elif cell == TacticalSkirmishManager.get_enemy_city():
		fid = TacticalSkirmishManager.get_enemy_faction()
	if fid == "":
		if badge != null:
			badge.visible = false
		return
	var cap_tex: Texture2D = SkirmishTileTextures.capital_texture(fid)
	if cap_tex == null:
		if badge != null:
			badge.visible = false
		return
	if badge == null:
		badge = TextureRect.new()
		badge.name = "CapitalBadge"
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		badge.z_index = 3
		hex_cell.add_child(badge)
	badge.texture = cap_tex
	badge.set_anchors_preset(Control.PRESET_CENTER)
	var s: float = minf(hex_cell.custom_minimum_size.x, hex_cell.custom_minimum_size.y) * 0.4
	badge.offset_left = -s
	badge.offset_top = -s * 0.88
	badge.offset_right = s
	badge.offset_bottom = s * 0.88
	badge.visible = true


func _apply_unit_overlay(btn: Control, uu: Dictionary) -> void:
	var anim_sprite: AnimatedSprite2D = btn.get_node_or_null("UnitSprite") as AnimatedSprite2D
	var stale_unit_sprite: Node = btn.get_node_or_null("UnitSprite")
	var unit_shadow: TextureRect = btn.get_node_or_null("UnitShadow") as TextureRect
	if stale_unit_sprite != null and not (stale_unit_sprite is AnimatedSprite2D):
		btn.remove_child(stale_unit_sprite)
		stale_unit_sprite.free()
		anim_sprite = null
	if uu.is_empty():
		if anim_sprite != null:
			anim_sprite.visible = false
		if unit_shadow != null:
			unit_shadow.visible = false
		return
	# 创建或复用 AnimatedSprite2D
	if anim_sprite == null:
		anim_sprite = AnimatedSprite2D.new()
		anim_sprite.name = "UnitSprite"
		anim_sprite.z_index = 4
		btn.add_child(anim_sprite)
	# 加载 SpriteFrames
	var unit_type_id: String = str(uu.get("unit_type_id", ""))
	var faction_id: String = str(uu.get("faction_id", "base"))
	var sf: SpriteFrames = _get_or_create_unit_frames(unit_type_id, faction_id)
	if sf != null:
		anim_sprite.sprite_frames = sf
		if sf.has_animation("idle") and anim_sprite.animation != "idle":
			anim_sprite.animation = "idle"
		if sf.has_animation("idle") and not anim_sprite.is_playing():
			anim_sprite.play("idle")
	else:
		var fallback_tex: Texture2D = SkirmishTileTextures.unit_texture(unit_type_id)
		if fallback_tex == null:
			anim_sprite.visible = false
			if unit_shadow != null:
				unit_shadow.visible = false
			return
		sf = SpriteFrames.new()
		sf.remove_animation("default")
		sf.add_animation("idle")
		sf.set_animation_loop("idle", true)
		sf.add_frame("idle", fallback_tex)
		anim_sprite.sprite_frames = sf
		anim_sprite.animation = "idle"
		anim_sprite.play("idle")
	# AnimatedSprite2D 是 Node2D，必须用 position/scale 控制，不能按 Control offset 拉伸。
	var cell_size: Vector2 = btn.custom_minimum_size
	if cell_size.x <= 1.0 or cell_size.y <= 1.0:
		var hc: SkirmishHexCell = btn as SkirmishHexCell
		if hc != null:
			cell_size = Vector2(hc.circumradius * 2.0, hc.circumradius * sqrt(3.0))
		else:
			cell_size = Vector2(96.0, 84.0)
	var frame_tex: Texture2D = null
	if sf.has_animation("idle") and sf.get_frame_count("idle") > 0:
		frame_tex = sf.get_frame_texture("idle", 0)
	var frame_max: float = 1.0
	if frame_tex != null:
		frame_max = maxf(float(frame_tex.get_width()), float(frame_tex.get_height()))
	var sprite_size: float = minf(cell_size.x, cell_size.y) * 0.48
	anim_sprite.centered = true
	anim_sprite.position = Vector2(cell_size.x * 0.66, cell_size.y * 0.35)
	anim_sprite.scale = Vector2.ONE * (sprite_size / frame_max)
	anim_sprite.visible = true
	# 阴影（保留 TextureRect 方案，用静态贴图做阴影）
	if unit_shadow == null:
		unit_shadow = TextureRect.new()
		unit_shadow.name = "UnitShadow"
		unit_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		unit_shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		unit_shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		unit_shadow.modulate = Color(0.06, 0.03, 0.02, 0.52)
		unit_shadow.z_index = 3
		btn.add_child(unit_shadow)
	var ut: Texture2D = SkirmishTileTextures.unit_texture(unit_type_id)
	if ut != null:
		unit_shadow.texture = ut
		unit_shadow.set_anchors_preset(Control.PRESET_TOP_LEFT)
		var shadow_size: float = sprite_size * 0.9
		var shadow_center: Vector2 = anim_sprite.position + Vector2(4.0, 6.0)
		unit_shadow.offset_left = shadow_center.x - shadow_size * 0.5
		unit_shadow.offset_top = shadow_center.y - shadow_size * 0.5
		unit_shadow.offset_right = shadow_center.x + shadow_size * 0.5
		unit_shadow.offset_bottom = shadow_center.y + shadow_size * 0.5
		unit_shadow.visible = true
	else:
		unit_shadow.visible = false
	anim_sprite.move_to_front()


func _get_or_create_unit_frames(unit_type_id: String, faction_id: String) -> SpriteFrames:
	var key: String = "%s:%s" % [unit_type_id, faction_id]
	if _unit_frames_cache.has(key):
		return _unit_frames_cache[key]
	var sf: SpriteFrames = _load_unit_sprite_frames(unit_type_id, faction_id)
	if sf != null:
		_unit_frames_cache[key] = sf
	return sf


func _load_unit_sprite_frames(unit_type_id: String, faction_id: String) -> SpriteFrames:
	var base_path: String = ""
	for candidate: String in _unit_sprite_base_paths(unit_type_id, faction_id):
		if ResourceLoader.exists(_unit_frame_path(candidate, unit_type_id, "idle", 1)):
			base_path = candidate
			break
	if base_path == "":
		return null
	var sf: SpriteFrames = SpriteFrames.new()
	sf.remove_animation("default")
	var anim_names: Array[String] = ["idle", "move", "attack", "hurt", "death"]
	var loop_anims: Array[String] = ["idle", "move"]
	var fps: float = 8.0
	for anim_name: String in anim_names:
		var frame_paths: Array[String] = _unit_frame_paths(base_path, unit_type_id, anim_name)
		if frame_paths.is_empty():
			continue
		sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, fps)
		sf.set_animation_loop(anim_name, anim_name in loop_anims)
		for frame_path: String in frame_paths:
			var tex: Texture2D = load(frame_path) as Texture2D
			if tex != null:
				sf.add_frame(anim_name, tex)
	return sf


func _normalized_unit_id(unit_id: String) -> String:
	return unit_id.trim_prefix("unit_")


func _unit_sprite_base_paths(unit_type_id: String, faction_id: String) -> Array[String]:
	var normalized_id: String = _normalized_unit_id(unit_type_id)
	var unit_dir: String = "unit_%s" % normalized_id
	return [
		"res://assets/sprites/units/%s/%s/" % [faction_id, unit_type_id],
		"res://assets/sprites/units/%s/%s/" % [faction_id, unit_dir],
		"res://assets/sprites/units/base/%s/" % unit_type_id,
		"res://assets/sprites/units/base/%s/" % unit_dir,
	]


func _unit_frame_paths(base_path: String, unit_type_id: String, anim_name: String) -> Array[String]:
	var out: Array[String] = []
	var frame_index: int = 1
	while frame_index <= 12:
		var path: String = _unit_frame_path(base_path, unit_type_id, anim_name, frame_index)
		if not ResourceLoader.exists(path):
			break
		out.append(path)
		frame_index += 1
	return out


func _unit_frame_path(base_path: String, unit_type_id: String, anim_name: String, frame_index: int) -> String:
	var normalized_id: String = _normalized_unit_id(unit_type_id)
	return "%sunit_%s_%s_%02d.png" % [base_path, normalized_id, anim_name, frame_index]


func _play_combat_effect(effect_id: String, cell: Vector2i, _attacker_cell: Vector2i) -> void:
	var hex_cell: Control = _find_hex_cell(cell)
	if hex_cell == null:
		return
	var sf: SpriteFrames = _effect_frames_cache.get(effect_id)
	if sf == null:
		sf = SkirmishTileTextures.effect_frames(effect_id)
		if sf == null:
			return
		_effect_frames_cache[effect_id] = sf
	var fx: AnimatedSprite2D = AnimatedSprite2D.new()
	fx.name = "CombatEffect"
	fx.sprite_frames = sf
	fx.z_index = 10
	hex_cell.add_child(fx)
	var cell_size: Vector2 = hex_cell.custom_minimum_size
	var fx_size: float = minf(cell_size.x, cell_size.y) * 0.8
	var frame_tex: Texture2D = null
	if sf.has_animation("play") and sf.get_frame_count("play") > 0:
		frame_tex = sf.get_frame_texture("play", 0)
	var frame_max: float = 1.0
	if frame_tex != null:
		frame_max = maxf(float(frame_tex.get_width()), float(frame_tex.get_height()))
	fx.centered = true
	fx.position = cell_size * 0.5
	fx.scale = Vector2.ONE * (fx_size / frame_max)
	fx.play("play")
	fx.animation_finished.connect(fx.queue_free)


func _find_hex_cell(cell: Vector2i) -> SkirmishHexCell:
	for ch: Node in _hex_board.get_children():
		if ch is SkirmishHexCell:
			var hc: SkirmishHexCell = ch as SkirmishHexCell
			if Vector2i(hc.cell_q, hc.cell_r) == cell:
				return hc
	return null


func _on_mgr_log(line: String) -> void:
	_log_view.append_text(line + "\n")


func _on_skirmish_ended_unified(_winner: String) -> void:
	pass
