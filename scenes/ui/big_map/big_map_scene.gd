extends Control
class_name BigMapScene

## 大地图独立场景 — 自 scenes/main/main.gd 迁出的「大地图及其相关调度」。
## 职责：大地图面板、叠层（城池/外交/科技/大夫）、资源栏搬移、回合控制、
##       事件弹窗、Debug 事件测试按钮、返回模式按钮、建筑放置流程。
##
## 入口：启动流程按模式分流直进本场景（full_demo / 默认模式），或从中枢场景切换进入；
##       独立场景模式下 resource_bar / tech_tree_panel 为空，由本场景自建/缺省。
## 宿主协作：当被 main 容器（旧测试路径）实例化时，通过三个信号与宿主协作：
##   - hub_visibility_requested(visible)     请求显示/隐藏中枢工具栏（hub 是 main 的子节点）
##   - hub_panel_action_requested(action)    请求在中枢内打开框架页（schools / save）
##   - return_to_mode_requested              返回模式选择

signal return_to_mode_requested
signal hub_visibility_requested(is_visible: bool)
signal hub_panel_action_requested(action: String)

# ── 宿主注入引用（main 在 add_child 前设置）────────────────────────
## 资源栏（main.tscn 的 ResourceBar）；独立场景模式下为空，由 _ensure_resource_bar 自建。
var resource_bar: Control = null
## 科技树面板（main.tscn 预置的 TechTreePanel）；独立场景模式下为空（科技叠层不可用）。
var tech_tree_panel: Control = null

const _RESOURCE_BAR_SCRIPT: Script = preload("res://scenes/ui/resource_bar/resource_bar.gd")
const _DIPLOMACY_SCENE: PackedScene = preload("res://scenes/ui/diplomacy/diplomacy_panel.tscn")
const _MINISTER_PANEL_SCENE: PackedScene = preload("res://scenes/ui/minister_panel/minister_panel.tscn")
const _BIG_MAP_PANEL_SCENE: PackedScene = preload("res://scenes/ui/big_map/big_map_panel.tscn")
const _CITY_PANEL_SCENE: PackedScene = preload("res://scenes/ui/city_panel/city_panel.tscn")
const _EVENT_POPUP_SCENE: PackedScene = preload("res://scenes/ui/event_popup/event_popup.tscn")
const _EVENT_TEST_SCENE: PackedScene = preload("res://scenes/ui/event_test/event_test_panel.tscn")

var _diplomacy_panel: Panel = null
var _minister_panel: Panel = null
var _big_map_panel: CanvasLayer = null
var _city_panel: Panel = null
var _last_big_map_city_focus_id: String = ""
var _formal_demo_big_map_opened: bool = false
var _event_popup: Panel = null
var _event_test_panel: Panel = null
var _event_test_btn: Button = null
var _return_mode_btn: Button = null
var _debug_tools_enabled: bool = false

var _turn_info_layer: CanvasLayer = null
var _turn_info_panel: PanelContainer = null
var _turn_info_title: Label = null
var _turn_info_season: Label = null
var _turn_info_faction: Label = null
var _turn_info_status: Label = null
var _turn_info_tween: Tween = null

var _end_turn_layer: CanvasLayer = null
var _persistent_end_btn: Button = null
var _culture_hud_label: Label = null
var _is_processing_turn: bool = false

## 高层级 UI 容器：科技/城池等普通 Control 必须放进 CanvasLayer，否则被大地图/中枢盖住
var _tech_layer: CanvasLayer = null
var _city_layer: CanvasLayer = null
var _diplomacy_layer: CanvasLayer = null
var _minister_layer: CanvasLayer = null
const _UI_LAYER_TECH: int = 90
const _UI_LAYER_DIPLOMACY: int = 91
const _UI_LAYER_CITY: int = 92
const _UI_LAYER_MINISTER: int = 93

const SEASON_NAMES: Dictionary = {
	"spring": "春",
	"summer": "夏",
	"autumn": "秋",
	"winter": "冬",
}

const FACTION_NAMES: Dictionary = {
	"qin": "秦国",
	"zhao": "赵国",
	"qi": "齐国",
	"chu": "楚国",
	"wei": "魏国",
	"yan": "燕国",
	"han": "韩国",
	"zhou": "周室",
	"neutral": "中立",
}


func _ready() -> void:
	_debug_tools_enabled = OS.has_feature("debug")
	_event_popup = _EVENT_POPUP_SCENE.instantiate() as Panel
	add_child(_event_popup)

	if _debug_tools_enabled:
		_event_test_btn = SkirmishTileTextures.styled_button("事件测试(Debug)")
		_event_test_btn.pressed.connect(_on_event_test_button_pressed)
		add_child(_event_test_btn)

	_return_mode_btn = SkirmishTileTextures.styled_button("返回模式")
	_return_mode_btn.pressed.connect(return_to_mode)
	add_child(_return_mode_btn)

	_create_turn_info_popup()
	_create_persistent_end_btn()
	_set_end_turn_visible(false)

	# 独立场景模式（full_demo 直进或中枢「切换」进入）：总是自动打开大地图；
	# 仅 full_demo 额外定位首都，其余模式由玩家自行点选城池/顶栏功能。
	if get_tree().current_scene == self:
		if StartupFlow.selected_mode == StartupFlow.MODE_FULL_DEMO:
			call_deferred("_enter_formal_demo_big_map")
		else:
			call_deferred("open_big_map")


# ── 资源栏 ──────────────────────────────────────────────────

## 获取资源栏：宿主已注入则直接用；独立场景模式自建（无 resource_bar.tscn，用脚本自组）。
func _ensure_resource_bar() -> Control:
	if resource_bar == null:
		var rb := HBoxContainer.new()
		rb.set_script(_RESOURCE_BAR_SCRIPT)
		resource_bar = rb
		add_child(rb)
		rb.visible = false
	return resource_bar


func _embed_resource_bar(target_vbox: VBoxContainer) -> void:
	var rb: Control = _ensure_resource_bar()
	if rb.get_parent() != null:
		rb.get_parent().remove_child(rb)
	target_vbox.add_child(rb)
	target_vbox.move_child(rb, 1)
	rb.visible = true
	_refresh_resource_bar()


func _reclaim_resource_bar() -> void:
	if resource_bar == null:
		return
	if resource_bar.get_parent() != null and resource_bar.get_parent() != self:
		resource_bar.get_parent().remove_child(resource_bar)
		add_child(resource_bar)
	resource_bar.visible = false


func _refresh_resource_bar() -> void:
	if resource_bar != null and resource_bar.has_method("refresh"):
		resource_bar.refresh()


# ── 回合控制 ────────────────────────────────────────────────

func set_end_turn_visible(is_visible: bool) -> void:
	_set_end_turn_visible(is_visible)


func _set_end_turn_visible(is_visible: bool) -> void:
	if is_instance_valid(_end_turn_layer):
		_end_turn_layer.visible = is_visible
	if is_instance_valid(_persistent_end_btn):
		_persistent_end_btn.visible = is_visible


func _create_persistent_end_btn() -> void:
	_end_turn_layer = CanvasLayer.new()
	_end_turn_layer.layer = 5
	add_child(_end_turn_layer)

	_persistent_end_btn = Button.new()
	_persistent_end_btn.text = "结束回合"
	SkirmishTileTextures.style_scene_button(_persistent_end_btn)
	_persistent_end_btn.custom_minimum_size = Vector2(140, 44)
	_persistent_end_btn.pressed.connect(_on_next_turn_pressed)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end_turn_layer.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_END
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(hbox)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_END
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(vbox)

	_culture_hud_label = Label.new()
	_culture_hud_label.name = "CultureHud"
	_culture_hud_label.add_theme_font_size_override("font_size", 13)
	_culture_hud_label.add_theme_color_override("font_color", Color(0.92, 0.88, 0.72, 0.95))
	_culture_hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_culture_hud_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_culture_hud_label)

	vbox.add_child(_persistent_end_btn)
	_refresh_culture_hud()
	SignalBus.turn_started.connect(_on_culture_hud_turn)
	SignalBus.culture_mainstream_changed.connect(_on_culture_mainstream_changed)
	SignalBus.city_occupied.connect(func(_c: String, _o: String, _n: String) -> void: _refresh_culture_hud())


func _on_culture_hud_turn(_turn: int, _faction: String) -> void:
	_refresh_culture_hud()


func _refresh_culture_hud() -> void:
	if not is_instance_valid(_culture_hud_label):
		return
	var player: String = _resolve_player_faction_id()
	if player.is_empty():
		_culture_hud_label.text = ""
		return
	var ratio: float = CityManager.get_culture_coverage_ratio(player)
	var cfg: Dictionary = DataManager.get_balance_param("victory.cultural")
	var target: float = float(cfg.get("city_ratio", 0.7))
	var maintain: int = int(cfg.get("maintain_turns", 10))
	var held: int = GameManager.get_cultural_victory_hold_turns(player)
	var pct: int = int(round(ratio * 100.0))
	var target_pct: int = int(round(target * 100.0))
	if ratio >= target:
		_culture_hud_label.text = I18n.t("hud.culture_progress_active") % [pct, target_pct, held, maintain]
		_culture_hud_label.add_theme_color_override("font_color", Color(0.55, 0.92, 0.55, 1.0))
	else:
		_culture_hud_label.text = I18n.t("hud.culture_progress") % [pct, target_pct]
		_culture_hud_label.add_theme_color_override("font_color", Color(0.92, 0.88, 0.72, 0.95))


func _on_culture_mainstream_changed(city_id: String, old_faction: String, new_faction: String) -> void:
	_refresh_culture_hud()
	var city: Dictionary = CityManager.get_city_state(city_id)
	var city_name: String = str(city.get("name", city_id))
	var player: String = _resolve_player_faction_id()
	if new_faction == player or old_faction == player or str(city.get("current_faction_id", "")) == player:
		show_turn_info(I18n.t("hud.culture_flip") % [city_name, _faction_display_name(new_faction)])


# ── 回合信息弹层 ────────────────────────────────────────────

func _create_turn_info_popup() -> void:
	_turn_info_layer = CanvasLayer.new()
	_turn_info_layer.layer = 10

	_turn_info_panel = PanelContainer.new()
	_turn_info_panel.visible = false
	_turn_info_panel.custom_minimum_size = Vector2(340, 190)
	_turn_info_panel.set_anchors_preset(Control.PRESET_CENTER)
	_turn_info_panel.offset_left = -170
	_turn_info_panel.offset_right = 170
	_turn_info_panel.offset_top = -95
	_turn_info_panel.offset_bottom = 95

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.10, 0.08, 0.06, 0.92)
	bg.border_color = Color(0.45, 0.38, 0.24, 1.0)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(6)
	bg.content_margin_left = 20.0
	bg.content_margin_right = 20.0
	bg.content_margin_top = 16.0
	bg.content_margin_bottom = 16.0
	_turn_info_panel.add_theme_stylebox_override("panel", bg)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)

	_turn_info_title = Label.new()
	_turn_info_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_info_title.add_theme_font_size_override("font_size", 22)
	_turn_info_title.add_theme_color_override("font_color", Color("C8A84E"))
	vbox.add_child(_turn_info_title)

	_turn_info_season = Label.new()
	_turn_info_season.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_info_season.add_theme_font_size_override("font_size", 18)
	_turn_info_season.add_theme_color_override("font_color", Color("E8D5B0"))
	vbox.add_child(_turn_info_season)

	_turn_info_faction = Label.new()
	_turn_info_faction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_info_faction.add_theme_font_size_override("font_size", 16)
	_turn_info_faction.add_theme_color_override("font_color", Color("A08060"))
	vbox.add_child(_turn_info_faction)

	_turn_info_status = Label.new()
	_turn_info_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_info_status.add_theme_font_size_override("font_size", 16)
	_turn_info_status.add_theme_color_override("font_color", Color("9FCE7C"))
	vbox.add_child(_turn_info_status)

	_turn_info_panel.add_child(vbox)
	_turn_info_layer.add_child(_turn_info_panel)
	add_child(_turn_info_layer)


func show_turn_info(status_text: String = "回合切换成功") -> void:
	_show_turn_info(status_text)


func _show_turn_info(status_text: String = "回合切换成功") -> void:
	if _turn_info_panel == null:
		return

	if is_instance_valid(_turn_info_tween):
		_turn_info_tween.kill()

	var turn: int = GameManager.get_current_turn()
	var faction: String = GameManager.get_current_faction()
	var season: String = CityManager.get_current_season(turn)

	_turn_info_title.text = "第 %d 回合" % turn
	_turn_info_season.text = "时节：%s" % SEASON_NAMES.get(season, season)
	_turn_info_faction.text = "%s 的回合" % FACTION_NAMES.get(faction, faction)
	_turn_info_status.text = status_text
	_turn_info_panel.visible = true
	_turn_info_panel.modulate.a = 1.0

	_turn_info_tween = create_tween()
	_turn_info_tween.tween_interval(1.5)
	_turn_info_tween.tween_property(_turn_info_panel, "modulate:a", 0.0, 0.5)
	_turn_info_tween.tween_callback(func() -> void: _turn_info_panel.visible = false)


func _on_next_turn_pressed() -> void:
	if _is_processing_turn:
		return

	_is_processing_turn = true
	_persistent_end_btn.disabled = true

	if GameManager.get_current_phase() != GameManager.Phase.ACTION:
		push_warning("[BigMapScene] 当前阶段 %s，无法结束回合" % GameManager.get_current_phase())
		_reenable_end_btn()
		return

	GameManager.end_current_turn()
	while GameManager.get_current_phase() == GameManager.Phase.ACTION and not GameManager.is_player_faction(GameManager.get_current_faction()):
		GameManager.process_ai_turn()

	_refresh_resource_bar()

	if GameManager.get_current_phase() == GameManager.Phase.GAME_OVER:
		_set_end_turn_visible(false)
		_reenable_end_btn()
		return

	show_turn_info("回合切换成功")
	_reenable_end_btn()


func _reenable_end_btn() -> void:
	_is_processing_turn = false
	if _persistent_end_btn != null:
		_persistent_end_btn.disabled = false


# ── 大地图 ──────────────────────────────────────────────────

## 打开大地图（中枢/独立场景入口）。
func open_big_map() -> void:
	if DemoFlow.is_enabled():
		DemoFlow.mark_step_completed(DemoFlow.STEP_OPEN_BIG_MAP)
		DemoFlow.mark_strategy_prepared_if_ready()
	_close_diplomacy()
	_close_city_panel()
	hub_visibility_requested.emit(false)
	_set_end_turn_visible(true)
	_ensure_big_map()
	_big_map_panel.open()
	_last_big_map_city_focus_id = ""
	_embed_resource_bar(_big_map_panel.get_resource_bar_slot())


## 直接关闭大地图（演武等外部流程调用）。
func close_big_map() -> void:
	_close_big_map()


func is_big_map_open() -> bool:
	return is_instance_valid(_big_map_panel)


func _close_big_map() -> void:
	if is_instance_valid(_big_map_panel):
		_reclaim_resource_bar()
		_big_map_panel.close()
		_big_map_panel = null


func _ensure_big_map() -> void:
	if is_instance_valid(_big_map_panel):
		return

	_big_map_panel = _BIG_MAP_PANEL_SCENE.instantiate() as CanvasLayer
	add_child(_big_map_panel)
	_big_map_panel.city_clicked.connect(_on_city_clicked)
	_big_map_panel.map_closed.connect(_on_big_map_closed)
	_big_map_panel.hub_action_requested.connect(_on_big_map_hub_action)


## 用户主动关大地图：回到控制中枢（结束回合隐藏 + 恢复 hub）。
## 独立场景模式（无中枢可恢复）：直接返回主菜单，避免黑屏。
func _on_big_map_closed() -> void:
	_set_end_turn_visible(false)
	if get_tree() != null and get_tree().current_scene == self:
		return_to_mode()
		return
	hub_visibility_requested.emit(true)
	_close_big_map()


## 正式试玩启动：自动打开大地图并定位首都。
func _enter_formal_demo_big_map() -> void:
	if _formal_demo_big_map_opened:
		return
	_formal_demo_big_map_opened = true
	hub_visibility_requested.emit(false)
	_set_end_turn_visible(true)
	_ensure_big_map()
	_big_map_panel.open()
	var capital: Dictionary = CityManager.get_capital_state(GameManager.get_player_faction())
	var capital_id: String = str(capital.get("id", ""))
	if capital_id != "":
		_last_big_map_city_focus_id = capital_id
		if _big_map_panel.has_method("focus_city"):
			_big_map_panel.focus_city(capital_id)
	_embed_resource_bar(_big_map_panel.get_resource_bar_slot())


## 大地图顶栏功能入口：全部叠层，不销毁大地图。
func _on_big_map_hub_action(action: String) -> void:
	match action:
		"tech":
			_ensure_tech_layer()
			var panel := _tech_layer.get_node_or_null("TechTreePanel") as Control
			if panel != null:
				panel.visible = true
				_tech_layer.visible = true
		"diplomacy":
			_hide_hub()
			_open_diplomacy_overlay()
		"ministers":
			_hide_hub()
			open_minister_overlay()
		"schools":
			_hide_hub()
			_set_end_turn_visible(true)
			hub_panel_action_requested.emit("schools")
		"save":
			hub_panel_action_requested.emit("save")


## 请求宿主隐藏中枢/工具栏（中枢是 main 的子节点）。
func _hide_hub() -> void:
	hub_visibility_requested.emit(false)


# ── 城池面板 ────────────────────────────────────────────────

## 打开城池面板（中枢/外部入口）。
func open_city(city_id: String) -> void:
	_on_city_clicked(city_id)


func close_city_panel() -> void:
	_close_city_panel()


func _close_city_panel() -> void:
	if is_instance_valid(_city_panel):
		_reclaim_resource_bar()
		_city_panel.close()
		_city_panel = null
	if is_instance_valid(_city_layer):
		_city_layer.visible = false


func _ensure_city_layer() -> void:
	if is_instance_valid(_city_layer):
		return
	_city_layer = CanvasLayer.new()
	_city_layer.name = "CityLayer"
	_city_layer.layer = _UI_LAYER_CITY
	_city_layer.visible = false
	add_child(_city_layer)


func _on_city_clicked(city_id: String) -> void:
	if DemoFlow.is_enabled() and city_id == DemoFlow.get_target_city_id():
		DemoFlow.mark_step_completed(DemoFlow.STEP_INSPECT_LUOYI)
		if DemoFlow.is_step_completed(DemoFlow.STEP_CAPTURE_LUOYI):
			DemoFlow.mark_result_reviewed()
	_close_big_map()
	_close_city_panel()
	hub_visibility_requested.emit(false)
	_set_end_turn_visible(true)
	_last_big_map_city_focus_id = city_id

	_ensure_city_layer()
	_city_panel = _CITY_PANEL_SCENE.instantiate() as Panel
	_city_layer.add_child(_city_panel)
	_city_layer.visible = true
	_city_panel.return_to_map.connect(_on_city_panel_back)
	_city_panel.panel_closed.connect(_on_city_panel_closed)
	if _city_panel.has_signal("place_building_requested"):
		_city_panel.place_building_requested.connect(_on_place_building_requested)
	_city_panel.open(city_id)
	_embed_resource_bar(_city_panel.get_resource_bar_slot())


func _on_city_panel_back() -> void:
	_close_city_panel()
	_set_end_turn_visible(true)
	_ensure_big_map()
	_big_map_panel.open()
	if _last_big_map_city_focus_id != "" and _big_map_panel.has_method("focus_city"):
		_big_map_panel.focus_city(_last_big_map_city_focus_id)
	_embed_resource_bar(_big_map_panel.get_resource_bar_slot())


func _on_city_panel_closed() -> void:
	_set_end_turn_visible(false)
	hub_visibility_requested.emit(true)
	_close_city_panel()


# ── 建筑放置流程 ────────────────────────────────────────────

func _on_place_building_requested(city_id: String, building_id: String) -> void:
	# 关城池 → 开大地图放置模式
	_close_city_panel()
	_set_end_turn_visible(true)
	_ensure_big_map()
	_big_map_panel.open()
	if not _big_map_panel.building_placed.is_connected(_on_building_placed_on_map):
		_big_map_panel.building_placed.connect(_on_building_placed_on_map)
	if not _big_map_panel.building_placement_cancelled.is_connected(_on_building_placement_cancelled):
		_big_map_panel.building_placement_cancelled.connect(_on_building_placement_cancelled)
	_big_map_panel.begin_building_placement(city_id, building_id)
	_embed_resource_bar(_big_map_panel.get_resource_bar_slot())
	_last_big_map_city_focus_id = city_id


func _on_building_placed_on_map(city_id: String, _building_id: String, _hex_q: int, _hex_r: int) -> void:
	# 放置完成 → 回城池面板刷新
	_close_big_map()
	_on_city_clicked(city_id)


func _on_building_placement_cancelled() -> void:
	var city_id: String = _last_big_map_city_focus_id
	_close_big_map()
	if city_id != "":
		_on_city_clicked(city_id)


# ── 外交面板 ────────────────────────────────────────────────

func open_diplomacy() -> void:
	_close_big_map()
	_open_diplomacy_overlay()


func close_diplomacy() -> void:
	_close_diplomacy()


func _close_diplomacy() -> void:
	if is_instance_valid(_diplomacy_panel):
		_diplomacy_panel.queue_free()
		_diplomacy_panel = null
	if is_instance_valid(_diplomacy_layer):
		_diplomacy_layer.visible = false


func _ensure_diplomacy_layer() -> void:
	if is_instance_valid(_diplomacy_layer):
		return
	_diplomacy_layer = CanvasLayer.new()
	_diplomacy_layer.name = "DiplomacyLayer"
	_diplomacy_layer.layer = _UI_LAYER_DIPLOMACY
	_diplomacy_layer.visible = false
	add_child(_diplomacy_layer)


## 外交面板叠层打开（大地图/中枢共用）
func _open_diplomacy_overlay() -> void:
	_close_city_panel()
	_hide_hub()
	_set_end_turn_visible(not is_big_map_open())
	_ensure_diplomacy_layer()
	if not is_instance_valid(_diplomacy_panel):
		_diplomacy_panel = _DIPLOMACY_SCENE.instantiate() as Panel
		_diplomacy_panel.diplomacy_panel_closed.connect(_on_diplomacy_closed)
		_diplomacy_layer.add_child(_diplomacy_panel)
	_diplomacy_layer.visible = true
	_diplomacy_panel.visible = true
	_diplomacy_panel.open()


func _on_diplomacy_closed() -> void:
	if is_instance_valid(_diplomacy_panel):
		_diplomacy_panel.queue_free()
		_diplomacy_panel = null
	if is_instance_valid(_diplomacy_layer):
		_diplomacy_layer.visible = false
	# 大地图仍开着：保持图上；否则回控制中枢
	if not is_big_map_open():
		hub_visibility_requested.emit(true)
		_set_end_turn_visible(false)


# ── 大夫面板 ────────────────────────────────────────────────

func open_minister_overlay() -> void:
	_hide_hub()
	_set_end_turn_visible(not is_big_map_open())
	_ensure_minister_layer()
	if is_instance_valid(_minister_panel):
		_minister_panel.queue_free()
	_minister_panel = _MINISTER_PANEL_SCENE.instantiate() as Panel
	_minister_panel.panel_closed.connect(_on_minister_panel_closed)
	_minister_layer.add_child(_minister_panel)
	_minister_layer.visible = true
	_minister_panel.open(_resolve_player_faction_id())


func _ensure_minister_layer() -> void:
	if is_instance_valid(_minister_layer):
		return
	_minister_layer = CanvasLayer.new()
	_minister_layer.name = "MinisterLayer"
	_minister_layer.layer = _UI_LAYER_MINISTER
	_minister_layer.visible = false
	add_child(_minister_layer)


## 大夫面板关闭：清理并恢复中枢（大地图仍开着则保持图上）
func _on_minister_panel_closed() -> void:
	if is_instance_valid(_minister_panel):
		_minister_panel.queue_free()
		_minister_panel = null
	if is_instance_valid(_minister_layer):
		_minister_layer.visible = false
	if not is_big_map_open():
		hub_visibility_requested.emit(true)
		_set_end_turn_visible(false)


# ── 科技树 ──────────────────────────────────────────────────

func toggle_tech() -> void:
	_ensure_tech_layer()
	var panel := _tech_layer.get_node_or_null("TechTreePanel") as Control
	if panel == null:
		return
	panel.visible = not panel.visible
	_tech_layer.visible = panel.visible


func _ensure_tech_layer() -> void:
	if is_instance_valid(_tech_layer):
		return
	_tech_layer = CanvasLayer.new()
	_tech_layer.name = "TechLayer"
	_tech_layer.layer = _UI_LAYER_TECH
	add_child(_tech_layer)
	# 把宿主（main.tscn）预置的 TechTreePanel 迁到高层 CanvasLayer
	if tech_tree_panel != null:
		var panel: Control = tech_tree_panel
		if panel.get_parent() != null:
			panel.get_parent().remove_child(panel)
		panel.name = "TechTreePanel"
		_tech_layer.add_child(panel)
		panel.visible = false


# ── 事件测试 / 返回模式 ────────────────────────────────────

func _on_event_test_button_pressed() -> void:
	if not _debug_tools_enabled:
		return
	hub_visibility_requested.emit(false)
	_set_end_turn_visible(false)

	if not is_instance_valid(_event_test_panel):
		_event_test_panel = _EVENT_TEST_SCENE.instantiate() as Panel
		add_child(_event_test_panel)
		_event_test_panel.test_panel_closed.connect(_on_event_test_closed)

	_event_test_panel.open()


func _on_event_test_closed() -> void:
	_set_end_turn_visible(false)
	hub_visibility_requested.emit(true)


## 返回模式选择：清理本场景叠层后交给 StartupFlow 切换。
func return_to_mode() -> void:
	StartupFlow.trace("BigMapScene.return_to_mode")
	_close_big_map()
	_close_diplomacy()
	_close_city_panel()
	if is_instance_valid(_event_test_panel):
		_event_test_panel.queue_free()
		_event_test_panel = null
	return_to_mode_requested.emit()
	StartupFlow.return_to_mode_select()


# ── 工具 ────────────────────────────────────────────────────

func _resolve_player_faction_id() -> String:
	var player_faction_id: String = GameManager.get_player_faction()
	if player_faction_id == "":
		player_faction_id = DemoFlow.get_player_faction_id()
	return player_faction_id


func _faction_display_name(faction_id: String) -> String:
	if faction_id == "":
		return "未初始化"
	return str(FACTION_NAMES.get(faction_id, faction_id))
