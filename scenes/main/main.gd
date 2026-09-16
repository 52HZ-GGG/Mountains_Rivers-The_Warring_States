extends Node

## 主场景脚本 — 连接 UI 和游戏系统

var _diplomacy_scene: PackedScene = preload("res://scenes/ui/diplomacy/diplomacy_panel.tscn")
var _diplomacy_panel: Panel = null
var _minister_panel_scene: PackedScene = preload("res://scenes/ui/minister_panel/minister_panel.tscn")
var _minister_panel: Panel = null
var _big_map_scene: PackedScene = preload("res://scenes/ui/big_map/big_map_panel.tscn")
var _big_map_panel: CanvasLayer = null
var _city_panel_scene: PackedScene = preload("res://scenes/ui/city_panel/city_panel.tscn")
var _city_panel: Panel = null
var _last_big_map_city_focus_id: String = ""
var _formal_demo_big_map_opened: bool = false
var _event_popup_scene: PackedScene = preload("res://scenes/ui/event_popup/event_popup.tscn")
var _event_popup: Panel = null
var _event_test_scene: PackedScene = preload("res://scenes/ui/event_test/event_test_panel.tscn")
var _event_test_panel: Panel = null
var _scenario_panel_scene: PackedScene = preload("res://scenes/ui/skirmish/skirmish_scenario_panel.tscn")
var _scenario_panel: CanvasLayer = null
var _skirmish_panel_scene: PackedScene = preload("res://scenes/ui/skirmish/skirmish_mvp_panel.tscn")
var _active_skirmish_panel: CanvasLayer = null
var _demo_objective_scene: PackedScene = preload("res://scenes/ui/demo/demo_objective_panel.tscn")
var _demo_victory_scene: PackedScene = preload("res://scenes/ui/demo/demo_victory_popup.tscn")
var _demo_layer: CanvasLayer = null
var _demo_objective_panel: PanelContainer = null
var _demo_victory_popup: PanelContainer = null
var _demo_expand_btn: Button = null
var _resource_bar: Control = null
var _event_test_btn: Button = null
var _return_mode_btn: Button = null
var _toolbar_elements: Array[Control] = []
var _debug_tools_enabled: bool = false
var _hub_scene: PackedScene = preload("res://scenes/ui/hub/hub_scene.tscn")
var _hub_panel: Control = null

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

const DEMO_CHEAT_ATTACK_MULTIPLIER: float = 20.0


func _ready() -> void:
	_debug_tools_enabled = OS.has_feature("debug")
	StartupFlow.trace("Main._ready begin phase=%s pending=%s mode=%s faction=%s" % [
		GameManager.Phase.keys()[GameManager.get_current_phase()],
		str(StartupFlow.is_game_start_pending()),
		StartupFlow.selected_mode,
		StartupFlow.selected_faction,
	])
	_resource_bar = $ResourceBar as Control
	_resource_bar.visible = false

	_init_game()

	_event_popup = _event_popup_scene.instantiate() as Panel
	add_child(_event_popup)

	if _debug_tools_enabled:
		_event_test_btn = SkirmishTileTextures.styled_button("事件测试(Debug)")
		_event_test_btn.pressed.connect(_on_event_test_button_pressed)
		add_child(_event_test_btn)

	_return_mode_btn = SkirmishTileTextures.styled_button("返回模式")
	_return_mode_btn.pressed.connect(_on_return_mode_pressed)
	add_child(_return_mode_btn)

	_create_turn_info_popup()
	_create_persistent_end_btn()
	_set_end_turn_visible(false)
	_hub_panel = _hub_scene.instantiate() as Control
	_hub_panel.name = "FrameworkHub"
	add_child(_hub_panel)
	_toolbar_elements = [_hub_panel]
	_connect_hub_signals()
	if DemoFlow.is_enabled():
		_create_demo_ui()
		if not DemoFlow.requires_strategy_preparation():
			call_deferred("_auto_start_skirmish_demo")
	if StartupFlow.selected_mode == StartupFlow.MODE_FULL_DEMO:
		call_deferred("_enter_formal_demo_big_map")
	if not TacticalSkirmishManager.skirmish_ended.is_connected(_on_skirmish_ended):
		TacticalSkirmishManager.skirmish_ended.connect(_on_skirmish_ended)
	StartupFlow.trace("Main._ready end phase=%s demo=%s" % [
		GameManager.Phase.keys()[GameManager.get_current_phase()],
		str(DemoFlow.is_enabled()),
	])


func _exit_tree() -> void:
	StartupFlow.trace("Main._exit_tree begin")
	if TacticalSkirmishManager.skirmish_ended.is_connected(_on_skirmish_ended):
		TacticalSkirmishManager.skirmish_ended.disconnect(_on_skirmish_ended)
	if is_instance_valid(_active_skirmish_panel):
		_active_skirmish_panel.queue_free()
		_active_skirmish_panel = null
	StartupFlow.trace("Main._exit_tree end")


func _close_big_map() -> void:
	if is_instance_valid(_big_map_panel):
		_reclaim_resource_bar()
		_big_map_panel.close()
		_big_map_panel = null


func _close_diplomacy() -> void:
	if is_instance_valid(_diplomacy_panel):
		_diplomacy_panel.queue_free()
		_diplomacy_panel = null
	if is_instance_valid(_diplomacy_layer):
		_diplomacy_layer.visible = false


func _close_city_panel() -> void:
	if is_instance_valid(_city_panel):
		_reclaim_resource_bar()
		_city_panel.close()
		_city_panel = null
	if is_instance_valid(_city_layer):
		_city_layer.visible = false


func _init_game() -> void:
	StartupFlow.trace("Main._init_game begin phase=%s pending=%s auto=%s" % [
		GameManager.Phase.keys()[GameManager.get_current_phase()],
		str(StartupFlow.is_game_start_pending()),
		str(StartupFlow.should_main_auto_start_game()),
	])
	StartupFlow.trace("Main._init_game skip always")


func _embed_resource_bar(target_vbox: VBoxContainer) -> void:
	if _resource_bar.get_parent() != null:
		_resource_bar.get_parent().remove_child(_resource_bar)
	target_vbox.add_child(_resource_bar)
	target_vbox.move_child(_resource_bar, 1)
	_resource_bar.visible = true
	_refresh_resource_bar()


func _reclaim_resource_bar() -> void:
	if _resource_bar.get_parent() != null and _resource_bar.get_parent() != self:
		_resource_bar.get_parent().remove_child(_resource_bar)
		add_child(_resource_bar)
	_resource_bar.visible = false


func _set_toolbar_visible(is_visible: bool) -> void:
	for elem: Control in _toolbar_elements:
		if is_instance_valid(elem):
			elem.visible = is_visible


func _set_end_turn_visible(is_visible: bool) -> void:
	if is_instance_valid(_end_turn_layer):
		_end_turn_layer.visible = is_visible
	if is_instance_valid(_persistent_end_btn):
		_persistent_end_btn.visible = is_visible


func _refresh_resource_bar() -> void:
	if _resource_bar != null and _resource_bar.has_method("refresh"):
		_resource_bar.refresh()


func _should_show_tutorial_guidance_ui() -> bool:
	# 仅新手教程展示「完整 Demo 目标」面板；正式试玩/战略中枢不显示
	return DemoFlow.is_tutorial_enabled()


func _auto_start_skirmish_demo() -> void:
	# 直接启动，不再额外 await，保证测试/启动下一帧即可拿到面板
	if not DemoFlow.is_enabled() or DemoFlow.requires_strategy_preparation():
		return
	_on_demo_sortie_requested()


func _enter_formal_demo_big_map() -> void:
	if _formal_demo_big_map_opened:
		return
	_formal_demo_big_map_opened = true
	_set_toolbar_visible(false)
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


func _create_demo_ui() -> void:
	_demo_layer = CanvasLayer.new()
	_demo_layer.layer = 120
	add_child(_demo_layer)

	_demo_objective_panel = _demo_objective_scene.instantiate() as PanelContainer
	_demo_layer.add_child(_demo_objective_panel)
	if _demo_objective_panel.has_signal("sortie_requested"):
		_demo_objective_panel.sortie_requested.connect(_on_demo_sortie_requested)
	if _demo_objective_panel.has_signal("cheat_attack_requested"):
		_demo_objective_panel.cheat_attack_requested.connect(_on_demo_cheat_attack_requested)
	if _demo_objective_panel.has_signal("panel_collapsed"):
		_demo_objective_panel.panel_collapsed.connect(_on_demo_objective_collapsed)
	if _demo_objective_panel.has_method("open") and _should_show_tutorial_guidance_ui():
		_demo_objective_panel.open()
	elif is_instance_valid(_demo_objective_panel):
		_demo_objective_panel.visible = false

	_demo_victory_popup = _demo_victory_scene.instantiate() as PanelContainer
	_demo_layer.add_child(_demo_victory_popup)
	if _demo_victory_popup.has_signal("return_to_hub_requested"):
		_demo_victory_popup.return_to_hub_requested.connect(_on_demo_victory_return_to_hub_requested)
	if _demo_victory_popup.has_signal("replay_requested"):
		_demo_victory_popup.replay_requested.connect(_on_demo_victory_replay_requested)
	if _demo_victory_popup.has_signal("inspect_result_requested"):
		_demo_victory_popup.inspect_result_requested.connect(_on_demo_victory_inspect_result_requested)

	_demo_expand_btn = Button.new()
	_demo_expand_btn.text = "展开目标"
	_demo_expand_btn.custom_minimum_size = Vector2(112, 38)
	_demo_expand_btn.offset_left = 24.0
	_demo_expand_btn.offset_top = 24.0
	_demo_expand_btn.offset_right = 136.0
	_demo_expand_btn.offset_bottom = 62.0
	_demo_expand_btn.visible = false
	SkirmishTileTextures.style_scene_button(_demo_expand_btn)
	_demo_expand_btn.pressed.connect(_on_demo_objective_expand_requested)
	_demo_layer.add_child(_demo_expand_btn)


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
		_show_turn_info(I18n.t("hud.culture_flip") % [city_name, _faction_display_name(new_faction)])


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


func _ensure_big_map() -> void:
	if is_instance_valid(_big_map_panel):
		return

	_big_map_panel = _big_map_scene.instantiate() as CanvasLayer
	add_child(_big_map_panel)
	_big_map_panel.city_clicked.connect(_on_city_clicked)
	_big_map_panel.map_closed.connect(_on_big_map_closed)
	_big_map_panel.hub_action_requested.connect(_on_big_map_hub_action)


## 大地图顶栏功能入口：全部叠层，不销毁大地图
func _on_big_map_hub_action(action: String) -> void:
	match action:
		"tech":
			_ensure_tech_layer()
			var panel := _tech_layer.get_node_or_null("TechTreePanel") as Control
			if panel != null:
				panel.visible = true
				_tech_layer.visible = true
		"diplomacy":
			_hide_framework_hub()
			_open_diplomacy_overlay()
		"ministers":
			_hide_framework_hub()
			_open_minister_overlay()
		"schools":
			_hide_framework_hub()
			_set_end_turn_visible(true)
			_hub_panel.call("_show_schools_panel")
		"save":
			_hub_panel.call("_show_save_load_panel")


func _hide_framework_hub() -> void:
	if is_instance_valid(_hub_panel):
		_hub_panel.visible = false
	_set_toolbar_visible(false)


## 连接中枢信号到 main 的调度方法
func _connect_hub_signals() -> void:
	_hub_panel.open_big_map_requested.connect(_on_big_map_button_pressed)
	_hub_panel.open_city_requested.connect(_on_city_clicked)
	_hub_panel.open_diplomacy_requested.connect(_on_diplomacy_button_pressed)
	_hub_panel.open_tech_requested.connect(_on_tech_button_pressed)
	_hub_panel.open_military_requested.connect(_on_hub_military_requested)
	_hub_panel.open_minister_requested.connect(_open_minister_overlay)
	_hub_panel.return_to_mode_requested.connect(_on_return_mode_pressed)
	_hub_panel.hub_visibility_changed.connect(_on_hub_visibility_changed)
	_hub_panel.demo_objective_update_requested.connect(_on_hub_demo_objective_update_requested)


func _on_hub_military_requested() -> void:
	# 与中枢原 military 模块分支保持一致：Demo 走洛邑演武，普通模式走演武场景选择
	if DemoFlow.is_enabled():
		_on_demo_sortie_requested()
	else:
		_on_skirmish_button_pressed()


func _on_hub_visibility_changed(show_hub: bool) -> void:
	if not show_hub:
		return
	# 大地图仍开着时，关闭占位层即可；否则恢复中枢与工具栏
	if is_instance_valid(_big_map_panel):
		return
	_set_toolbar_visible(true)
	_set_end_turn_visible(false)


func _on_hub_demo_objective_update_requested() -> void:
	if is_instance_valid(_demo_objective_panel) and _demo_objective_panel.has_method("update_panel"):
		_demo_objective_panel.update_panel()


## 大夫面板关闭：清理并恢复中枢（自中枢区迁回 main，因面板归属 main）
func _on_minister_panel_closed() -> void:
	if is_instance_valid(_minister_panel):
		_minister_panel.queue_free()
		_minister_panel = null
	if is_instance_valid(_minister_layer):
		_minister_layer.visible = false
	# 大地图仍开着：保持图上；否则回控制中枢
	if not is_instance_valid(_big_map_panel):
		if is_instance_valid(_hub_panel):
			_hub_panel.visible = true
		_set_toolbar_visible(true)
		_set_end_turn_visible(false)


func _resolve_player_faction_id() -> String:
	var player_faction_id: String = GameManager.get_player_faction()
	if player_faction_id == "":
		player_faction_id = DemoFlow.get_player_faction_id()
	return player_faction_id


func _faction_display_name(faction_id: String) -> String:
	if faction_id == "":
		return "未初始化"
	return str(FACTION_NAMES.get(faction_id, faction_id))


func _ensure_diplomacy_layer() -> void:
	if is_instance_valid(_diplomacy_layer):
		return
	_diplomacy_layer = CanvasLayer.new()
	_diplomacy_layer.name = "DiplomacyLayer"
	_diplomacy_layer.layer = _UI_LAYER_DIPLOMACY
	_diplomacy_layer.visible = false
	add_child(_diplomacy_layer)


func _ensure_minister_layer() -> void:
	if is_instance_valid(_minister_layer):
		return
	_minister_layer = CanvasLayer.new()
	_minister_layer.name = "MinisterLayer"
	_minister_layer.layer = _UI_LAYER_MINISTER
	_minister_layer.visible = false
	add_child(_minister_layer)


## 外交面板叠层打开（大地图/中枢共用）
func _open_diplomacy_overlay() -> void:
	_close_city_panel()
	_hide_framework_hub()
	_set_end_turn_visible(not is_instance_valid(_big_map_panel))
	_ensure_diplomacy_layer()
	if not is_instance_valid(_diplomacy_panel):
		_diplomacy_panel = _diplomacy_scene.instantiate() as Panel
		_diplomacy_panel.diplomacy_panel_closed.connect(_on_diplomacy_closed)
		_diplomacy_layer.add_child(_diplomacy_panel)
	_diplomacy_layer.visible = true
	_diplomacy_panel.visible = true
	_diplomacy_panel.open()


## 大夫面板叠层打开
func _open_minister_overlay() -> void:
	_hide_framework_hub()
	_set_end_turn_visible(not is_instance_valid(_big_map_panel))
	_ensure_minister_layer()
	if is_instance_valid(_minister_panel):
		_minister_panel.queue_free()
	_minister_panel = _minister_panel_scene.instantiate() as Panel
	_minister_panel.panel_closed.connect(_on_minister_panel_closed)
	_minister_layer.add_child(_minister_panel)
	_minister_layer.visible = true
	_minister_panel.open(_resolve_player_faction_id())


func _on_diplomacy_button_pressed() -> void:
	_close_big_map()
	_open_diplomacy_overlay()


func _on_diplomacy_closed() -> void:
	if is_instance_valid(_diplomacy_panel):
		_diplomacy_panel.queue_free()
		_diplomacy_panel = null
	if is_instance_valid(_diplomacy_layer):
		_diplomacy_layer.visible = false
	# 大地图仍开着：保持图上；否则回控制中枢
	if not is_instance_valid(_big_map_panel):
		if is_instance_valid(_hub_panel):
			_hub_panel.visible = true
		_set_toolbar_visible(true)
		_set_end_turn_visible(false)


func _on_tech_button_pressed() -> void:
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
	# 把场景树里的 TechTreePanel 迁到高层 CanvasLayer
	var panel := $TechTreePanel as Control
	if panel != null:
		remove_child(panel)
		panel.name = "TechTreePanel"
		_tech_layer.add_child(panel)
		panel.visible = false


func _on_skirmish_button_pressed() -> void:
	_set_toolbar_visible(false)
	_set_end_turn_visible(false)

	if not is_instance_valid(_scenario_panel):
		_scenario_panel = _scenario_panel_scene.instantiate() as CanvasLayer
		add_child(_scenario_panel)
		_scenario_panel.panel_closed.connect(_on_skirmish_scenario_closed)
		_scenario_panel.skirmish_started.connect(_on_scenario_skirmish_started)

	_scenario_panel.open_panel()


func _on_skirmish_scenario_closed() -> void:
	_set_end_turn_visible(false)
	if TacticalSkirmishManager.is_active():
		# 演武进行中：保持演武 UI，不恢复战略工具栏
		return
	_set_toolbar_visible(true)


func _on_big_map_button_pressed() -> void:
	if DemoFlow.is_enabled():
		DemoFlow.mark_step_completed(DemoFlow.STEP_OPEN_BIG_MAP)
		DemoFlow.mark_strategy_prepared_if_ready()
	_close_diplomacy()
	_close_city_panel()
	_set_toolbar_visible(false)
	_set_end_turn_visible(true)
	_ensure_big_map()
	_big_map_panel.open()
	_last_big_map_city_focus_id = ""
	_embed_resource_bar(_big_map_panel.get_resource_bar_slot())


func _on_big_map_closed() -> void:
	# 用户主动关大地图：回到控制中枢
	_set_end_turn_visible(false)
	if is_instance_valid(_hub_panel):
		_hub_panel.visible = true
	_set_toolbar_visible(true)
	_close_big_map()


func _on_city_clicked(city_id: String) -> void:
	if DemoFlow.is_enabled() and city_id == DemoFlow.get_target_city_id():
		DemoFlow.mark_step_completed(DemoFlow.STEP_INSPECT_LUOYI)
		if DemoFlow.is_step_completed(DemoFlow.STEP_CAPTURE_LUOYI):
			DemoFlow.mark_result_reviewed()
	_close_big_map()
	_close_city_panel()
	_set_toolbar_visible(false)
	_set_end_turn_visible(true)
	_last_big_map_city_focus_id = city_id

	_ensure_city_layer()
	_city_panel = _city_panel_scene.instantiate() as Panel
	_city_layer.add_child(_city_panel)
	_city_layer.visible = true
	_city_panel.return_to_map.connect(_on_city_panel_back)
	_city_panel.panel_closed.connect(_on_city_panel_closed)
	if _city_panel.has_signal("place_building_requested"):
		_city_panel.place_building_requested.connect(_on_place_building_requested)
	_city_panel.open(city_id)
	_embed_resource_bar(_city_panel.get_resource_bar_slot())


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


func _ensure_city_layer() -> void:
	if is_instance_valid(_city_layer):
		return
	_city_layer = CanvasLayer.new()
	_city_layer.name = "CityLayer"
	_city_layer.layer = _UI_LAYER_CITY
	_city_layer.visible = false
	add_child(_city_layer)


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
	_set_toolbar_visible(true)
	_close_city_panel()


func _on_event_test_button_pressed() -> void:
	if not _debug_tools_enabled:
		return
	_set_toolbar_visible(false)
	_set_end_turn_visible(false)

	if not is_instance_valid(_event_test_panel):
		_event_test_panel = _event_test_scene.instantiate() as Panel
		add_child(_event_test_panel)
		_event_test_panel.test_panel_closed.connect(_on_event_test_closed)

	_event_test_panel.open()


func _on_event_test_closed() -> void:
	_set_end_turn_visible(false)
	_set_toolbar_visible(true)


func _on_return_mode_pressed() -> void:
	StartupFlow.trace("Main._on_return_mode_pressed")
	_close_big_map()
	_close_diplomacy()
	_close_city_panel()
	if is_instance_valid(_event_test_panel):
		_event_test_panel.queue_free()
		_event_test_panel = null
	StartupFlow.return_to_mode_select()


func _on_demo_sortie_requested() -> void:
	StartupFlow.trace("Main._on_demo_sortie_requested begin demo=%s phase=%s" % [
		str(DemoFlow.is_enabled()),
		GameManager.Phase.keys()[GameManager.get_current_phase()],
	])
	if not DemoFlow.is_enabled():
		StartupFlow.trace("Main._on_demo_sortie_requested ignored demo disabled")
		return
	_close_big_map()
	_close_diplomacy()
	_close_city_panel()
	_set_end_turn_visible(false)
	DemoFlow.mark_step_completed(DemoFlow.STEP_START_CAMPAIGN)
	var scenario_id: String = DemoFlow.get_recommended_scenario_id()
	var season: String = DemoFlow.get_recommended_season()
	if DemoFlow.is_tutorial_enabled():
		season = CityManager.get_current_season(GameManager.get_current_turn())
	if not _start_skirmish_scenario(scenario_id, season):
		if _should_show_tutorial_guidance_ui() and is_instance_valid(_demo_objective_panel):
			_demo_objective_panel.visible = true
		_set_toolbar_visible(true)
		_show_turn_info("出征失败：未能打开演武")
		StartupFlow.trace("Main._on_demo_sortie_requested failed")
	else:
		StartupFlow.trace("Main._on_demo_sortie_requested success active=%s" % str(TacticalSkirmishManager.is_active()))


func _on_demo_cheat_attack_requested() -> void:
	TacticalSkirmishManager.set_demo_attack_multiplier(DEMO_CHEAT_ATTACK_MULTIPLIER)
	if _should_show_tutorial_guidance_ui() and is_instance_valid(_demo_objective_panel) and _demo_objective_panel.has_method("update_panel"):
		_demo_objective_panel.update_panel()
	_show_turn_info("测试作弊已开启：我方演武伤害 ×%d" % int(DEMO_CHEAT_ATTACK_MULTIPLIER))


func _on_demo_objective_collapsed() -> void:
	if not _should_show_tutorial_guidance_ui():
		return
	if is_instance_valid(_demo_objective_panel):
		_demo_objective_panel.visible = false
	if is_instance_valid(_demo_expand_btn):
		_demo_expand_btn.visible = true


func _on_demo_objective_expand_requested() -> void:
	if not _should_show_tutorial_guidance_ui():
		return
	if is_instance_valid(_demo_expand_btn):
		_demo_expand_btn.visible = false
	if is_instance_valid(_demo_objective_panel):
		_demo_objective_panel.visible = true
		if _demo_objective_panel.has_method("update_panel"):
			_demo_objective_panel.update_panel()


func _on_scenario_skirmish_started(scenario_id: String, season: String) -> void:
	_start_skirmish_scenario(scenario_id, season)


func _start_skirmish_scenario(scenario_id: String, season: String) -> bool:
	StartupFlow.trace("Main._start_skirmish_scenario id=%s season=%s" % [scenario_id, season])
	var cfg: Dictionary = DataManager.get_skirmish_scenario(scenario_id)
	if cfg.is_empty():
		push_error("Main: 未找到场景 %s" % scenario_id)
		StartupFlow.trace("Main._start_skirmish_scenario missing cfg")
		return false
	if DemoFlow.is_full_demo_enabled():
		_inject_player_recruited_units_into_skirmish(cfg)

	var panel: CanvasLayer = _ensure_active_skirmish_panel()
	StartupFlow.trace("Main._start_skirmish_scenario panel=%s layer=%d visible=%s" % [
		panel.name,
		panel.layer,
		str(panel.visible),
	])
	if panel.has_method("open_panel_with_config"):
		panel.open_panel_with_config(cfg.duplicate(true), season)
	else:
		TacticalSkirmishManager.start_skirmish_with_config(cfg.duplicate(true), season)
		panel.open_panel()
	return true


func _inject_player_recruited_units_into_skirmish(cfg: Dictionary) -> void:
	var player_faction_id: String = str(cfg.get("player_faction_id", GameManager.get_player_faction()))
	var player_city: Dictionary = cfg.get("player_city", {}) as Dictionary
	if player_city.is_empty():
		return
	var initial_units_variant: Variant = cfg.get("initial_units", [])
	if initial_units_variant is not Array:
		return
	var initial_units: Array = initial_units_variant as Array
	var current_composition: Dictionary = GameManager.get_unit_composition(player_faction_id)
	if current_composition.is_empty():
		return

	var scenario_counts: Dictionary = {}
	for raw_unit: Variant in initial_units:
		if raw_unit is not Dictionary:
			continue
		var unit_entry: Dictionary = raw_unit as Dictionary
		if str(unit_entry.get("faction_id", "")) != player_faction_id:
			continue
		var unit_type_id: String = str(unit_entry.get("unit_type_id", ""))
		scenario_counts[unit_type_id] = int(scenario_counts.get(unit_type_id, 0)) + 1

	var spawn_index: int = 1
	for unit_type_id_variant: Variant in current_composition.keys():
		var unit_type_id: String = str(unit_type_id_variant)
		var current_count: int = int(current_composition.get(unit_type_id, 0))
		var baseline_count: int = int(scenario_counts.get(unit_type_id, 0))
		var extra_count: int = max(current_count - baseline_count, 0)
		var added: int = 0
		while added < extra_count:
			initial_units.append({
				"id": "demo_extra_%s_%d" % [unit_type_id, spawn_index],
				"faction_id": player_faction_id,
				"unit_type_id": unit_type_id,
				"q": int(player_city.get("q", 0)),
				"r": int(player_city.get("r", 0))
			})
			added += 1
			spawn_index += 1
	cfg["initial_units"] = initial_units


func _ensure_active_skirmish_panel() -> CanvasLayer:
	if is_instance_valid(_active_skirmish_panel):
		StartupFlow.trace("Main._ensure_active_skirmish_panel reuse")
		return _active_skirmish_panel
	StartupFlow.trace("Main._ensure_active_skirmish_panel create")
	_active_skirmish_panel = _skirmish_panel_scene.instantiate() as CanvasLayer
	_active_skirmish_panel.name = "ActiveSkirmishPanel"
	_active_skirmish_panel.layer = 100
	add_child(_active_skirmish_panel)
	if _active_skirmish_panel.has_signal("panel_closed") and not _active_skirmish_panel.panel_closed.is_connected(_on_skirmish_panel_closed):
		_active_skirmish_panel.panel_closed.connect(_on_skirmish_panel_closed)
	StartupFlow.trace("Main._ensure_active_skirmish_panel created layer=%d" % _active_skirmish_panel.layer)
	return _active_skirmish_panel


func _on_skirmish_ended(winner_faction_id: String) -> void:
	var completed: bool = DemoFlow.apply_skirmish_victory(winner_faction_id)
	if not completed:
		if DemoFlow.is_enabled() and winner_faction_id != "":
			_show_turn_info("演武失利：可重置演武后再战")
		return
	if DemoFlow.is_enabled():
		_finish_demo_skirmish()
	_show_turn_info("Demo 完成：洛邑已归秦")


func _finish_demo_skirmish() -> void:
	if is_instance_valid(_active_skirmish_panel):
		_active_skirmish_panel.queue_free()
		_active_skirmish_panel = null
	_set_end_turn_visible(false)
	_set_toolbar_visible(true)
	if _should_show_tutorial_guidance_ui() and is_instance_valid(_demo_objective_panel):
		_demo_objective_panel.visible = true
		if _demo_objective_panel.has_method("update_panel"):
			_demo_objective_panel.update_panel()
	if is_instance_valid(_demo_victory_popup) and _demo_victory_popup.has_method("show_victory"):
		_demo_victory_popup.show_victory()


func _on_demo_victory_return_to_hub_requested() -> void:
	_close_big_map()
	_close_diplomacy()
	_close_city_panel()
	_set_end_turn_visible(false)
	_set_toolbar_visible(true)
	if _should_show_tutorial_guidance_ui() and is_instance_valid(_demo_objective_panel):
		_demo_objective_panel.visible = true
		if _demo_objective_panel.has_method("update_panel"):
			_demo_objective_panel.update_panel()


func _on_demo_victory_replay_requested() -> void:
	TacticalSkirmishManager.reset_skirmish()
	CityManager.reset()
	DemoFlow.reset()
	DemoFlow.set_enabled(true)
	if _should_show_tutorial_guidance_ui() and is_instance_valid(_demo_objective_panel):
		_demo_objective_panel.visible = true
		if _demo_objective_panel.has_method("update_panel"):
			_demo_objective_panel.update_panel()
	_on_demo_sortie_requested()


func _on_demo_victory_inspect_result_requested() -> void:
	_close_big_map()
	_close_diplomacy()
	_close_city_panel()
	_set_end_turn_visible(true)
	_on_city_clicked(DemoFlow.get_target_city_id())


func _on_skirmish_panel_closed() -> void:
	StartupFlow.trace("Main._on_skirmish_panel_closed")
	if is_instance_valid(_active_skirmish_panel):
		_active_skirmish_panel.queue_free()
		_active_skirmish_panel = null
	_set_end_turn_visible(false)
	_set_toolbar_visible(true)
	if _should_show_tutorial_guidance_ui() and is_instance_valid(_demo_objective_panel):
		_demo_objective_panel.visible = true


func _on_next_turn_pressed() -> void:
	if _is_processing_turn:
		return

	_is_processing_turn = true
	_persistent_end_btn.disabled = true

	if GameManager.get_current_phase() != GameManager.Phase.ACTION:
		push_warning("[Main] 当前阶段 %s，无法结束回合" % GameManager.get_current_phase())
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

	_show_turn_info("回合切换成功")
	_reenable_end_btn()


func _reenable_end_btn() -> void:
	_is_processing_turn = false
	if _persistent_end_btn != null:
		_persistent_end_btn.disabled = false
