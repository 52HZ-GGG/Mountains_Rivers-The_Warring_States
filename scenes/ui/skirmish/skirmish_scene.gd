extends Control
class_name SkirmishScene

## 演武独立场景 — 自 scenes/main/main.gd 迁出的「演武（战术战役）/ Demo」职责。
## 职责：演武场景选择器、演武主面板、Demo 教学 UI（目标面板/胜利弹窗/展开按钮）、
##       演武结算与资源注入、返回模式按钮、Demo 直进演武自动启动。
##
## 入口：启动流程按模式分流直进本场景（demo / 新手教程），或从中枢「军事」模块切入
##       （StartupFlow.pending_skirmish 置位，_ready 消费后打开军事入口）。
## 宿主交互：当被 main 容器（旧测试路径）实例化时注入 big_map_scene 引用（关闭叠层/回合按钮/回合提示）；
##           本场景通过信号与宿主协作：
##   - hub_visibility_requested(visible)  请求显示/隐藏中枢工具栏（hub 是 main 的子节点）
##   - return_to_mode_requested           返回模式选择

signal return_to_mode_requested
signal hub_visibility_requested(is_visible: bool)

## 宿主注入：大地图场景引用（main 在 add_child 前设置）；独立场景模式下为空，由本场景缺省跳过。
var big_map_scene: BigMapScene = null

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

const DEMO_CHEAT_ATTACK_MULTIPLIER: float = 20.0


func _ready() -> void:
	if StartupFlow.pending_skirmish:
		# 从中枢「军事」模块切入：清标志并打开军事入口
		# （DemoFlow 启用时直进洛邑演武，否则打开演武场景选择器）。
		StartupFlow.pending_skirmish = false
		if DemoFlow.is_enabled():
			_create_demo_ui()
		call_deferred("open_military")
	elif DemoFlow.is_enabled():
		# Demo 模式：创建教学 UI；若无需战略准备（新手教程）则自动进入演武。
		_create_demo_ui()
		if not DemoFlow.requires_strategy_preparation():
			call_deferred("_auto_start_skirmish_demo")
	if not TacticalSkirmishManager.skirmish_ended.is_connected(_on_skirmish_ended):
		TacticalSkirmishManager.skirmish_ended.connect(_on_skirmish_ended)


func _exit_tree() -> void:
	if TacticalSkirmishManager.skirmish_ended.is_connected(_on_skirmish_ended):
		TacticalSkirmishManager.skirmish_ended.disconnect(_on_skirmish_ended)
	if is_instance_valid(_active_skirmish_panel):
		_active_skirmish_panel.queue_free()
		_active_skirmish_panel = null


# ── 公共入口（中枢 / 宿主调用）──────────────────────────────

## 中枢「军事」入口：Demo 走洛邑演武，普通模式走演武场景选择。
func open_military() -> void:
	if DemoFlow.is_enabled():
		_on_demo_sortie_requested()
	else:
		_on_skirmish_button_pressed()


## 刷新 Demo 目标面板（中枢请求）。
func update_demo_objective() -> void:
	if is_instance_valid(_demo_objective_panel) and _demo_objective_panel.has_method("update_panel"):
		_demo_objective_panel.update_panel()


## 返回模式选择：清理本场景叠层后交给 StartupFlow 切换。
func return_to_mode() -> void:
	StartupFlow.trace("SkirmishScene.return_to_mode")
	return_to_mode_requested.emit()
	StartupFlow.return_to_mode_select()


# ── 演武 / Demo ────────────────────────────────────────────

func _should_show_tutorial_guidance_ui() -> bool:
	# 仅新手教程展示「完整 Demo 目标」面板；正式试玩/战略中枢不显示
	return DemoFlow.is_tutorial_enabled()


func _auto_start_skirmish_demo() -> void:
	# 直接启动，不再额外 await，保证测试/启动下一帧即可拿到面板
	if not DemoFlow.is_enabled() or DemoFlow.requires_strategy_preparation():
		return
	_on_demo_sortie_requested()


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


func _on_skirmish_button_pressed() -> void:
	hub_visibility_requested.emit(false)
	if big_map_scene != null:
		big_map_scene.set_end_turn_visible(false)

	if not is_instance_valid(_scenario_panel):
		_scenario_panel = _scenario_panel_scene.instantiate() as CanvasLayer
		add_child(_scenario_panel)
		_scenario_panel.panel_closed.connect(_on_skirmish_scenario_closed)
		_scenario_panel.skirmish_started.connect(_on_scenario_skirmish_started)

	_scenario_panel.open_panel()


func _on_skirmish_scenario_closed() -> void:
	if big_map_scene != null:
		big_map_scene.set_end_turn_visible(false)
	if TacticalSkirmishManager.is_active():
		# 演武进行中：保持演武 UI，不恢复战略工具栏
		return
	hub_visibility_requested.emit(true)


func _on_scenario_skirmish_started(scenario_id: String, season: String) -> void:
	_start_skirmish_scenario(scenario_id, season)


func _start_skirmish_scenario(scenario_id: String, season: String) -> bool:
	StartupFlow.trace("SkirmishScene._start_skirmish_scenario id=%s season=%s" % [scenario_id, season])
	var cfg: Dictionary = DataManager.get_skirmish_scenario(scenario_id)
	if cfg.is_empty():
		push_error("SkirmishScene: 未找到场景 %s" % scenario_id)
		StartupFlow.trace("SkirmishScene._start_skirmish_scenario missing cfg")
		return false
	if DemoFlow.is_full_demo_enabled():
		_inject_player_recruited_units_into_skirmish(cfg)

	var panel: CanvasLayer = _ensure_active_skirmish_panel()
	StartupFlow.trace("SkirmishScene._start_skirmish_scenario panel=%s layer=%d visible=%s" % [
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
		StartupFlow.trace("SkirmishScene._ensure_active_skirmish_panel reuse")
		return _active_skirmish_panel
	StartupFlow.trace("SkirmishScene._ensure_active_skirmish_panel create")
	_active_skirmish_panel = _skirmish_panel_scene.instantiate() as CanvasLayer
	_active_skirmish_panel.name = "ActiveSkirmishPanel"
	_active_skirmish_panel.layer = 100
	add_child(_active_skirmish_panel)
	if _active_skirmish_panel.has_signal("panel_closed") and not _active_skirmish_panel.panel_closed.is_connected(_on_skirmish_panel_closed):
		_active_skirmish_panel.panel_closed.connect(_on_skirmish_panel_closed)
	StartupFlow.trace("SkirmishScene._ensure_active_skirmish_panel created layer=%d" % _active_skirmish_panel.layer)
	return _active_skirmish_panel


func _on_skirmish_ended(winner_faction_id: String) -> void:
	var completed: bool = DemoFlow.apply_skirmish_victory(winner_faction_id)
	if not completed:
		if DemoFlow.is_enabled() and winner_faction_id != "":
			if big_map_scene != null:
				big_map_scene.show_turn_info("演武失利：可重置演武后再战")
		return
	if DemoFlow.is_enabled():
		_finish_demo_skirmish()
	if big_map_scene != null:
		big_map_scene.show_turn_info("Demo 完成：洛邑已归秦")


func _finish_demo_skirmish() -> void:
	if is_instance_valid(_active_skirmish_panel):
		_active_skirmish_panel.queue_free()
		_active_skirmish_panel = null
	if big_map_scene != null:
		big_map_scene.set_end_turn_visible(false)
	hub_visibility_requested.emit(true)
	if _should_show_tutorial_guidance_ui() and is_instance_valid(_demo_objective_panel):
		_demo_objective_panel.visible = true
		if _demo_objective_panel.has_method("update_panel"):
			_demo_objective_panel.update_panel()
	if is_instance_valid(_demo_victory_popup) and _demo_victory_popup.has_method("show_victory"):
		_demo_victory_popup.show_victory()


func _on_demo_victory_return_to_hub_requested() -> void:
	if big_map_scene != null:
		big_map_scene.close_big_map()
		big_map_scene.close_diplomacy()
		big_map_scene.close_city_panel()
		big_map_scene.set_end_turn_visible(false)
	hub_visibility_requested.emit(true)
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
	if big_map_scene != null:
		big_map_scene.close_big_map()
		big_map_scene.close_diplomacy()
		big_map_scene.close_city_panel()
		big_map_scene.set_end_turn_visible(true)
		big_map_scene.open_city(DemoFlow.get_target_city_id())


func _on_skirmish_panel_closed() -> void:
	StartupFlow.trace("SkirmishScene._on_skirmish_panel_closed")
	if is_instance_valid(_active_skirmish_panel):
		_active_skirmish_panel.queue_free()
		_active_skirmish_panel = null
	if big_map_scene != null:
		big_map_scene.set_end_turn_visible(false)
	hub_visibility_requested.emit(true)
	if _should_show_tutorial_guidance_ui() and is_instance_valid(_demo_objective_panel):
		_demo_objective_panel.visible = true


func _on_demo_sortie_requested() -> void:
	StartupFlow.trace("SkirmishScene._on_demo_sortie_requested begin demo=%s phase=%s" % [
		str(DemoFlow.is_enabled()),
		GameManager.Phase.keys()[GameManager.get_current_phase()],
	])
	if not DemoFlow.is_enabled():
		StartupFlow.trace("SkirmishScene._on_demo_sortie_requested ignored demo disabled")
		return
	if big_map_scene != null:
		big_map_scene.close_big_map()
		big_map_scene.close_diplomacy()
		big_map_scene.close_city_panel()
		big_map_scene.set_end_turn_visible(false)
	DemoFlow.mark_step_completed(DemoFlow.STEP_START_CAMPAIGN)
	var scenario_id: String = DemoFlow.get_recommended_scenario_id()
	var season: String = DemoFlow.get_recommended_season()
	if DemoFlow.is_tutorial_enabled():
		season = CityManager.get_current_season(GameManager.get_current_turn())
	if not _start_skirmish_scenario(scenario_id, season):
		if _should_show_tutorial_guidance_ui() and is_instance_valid(_demo_objective_panel):
			_demo_objective_panel.visible = true
		hub_visibility_requested.emit(true)
		if big_map_scene != null:
			big_map_scene.show_turn_info("出征失败：未能打开演武")
		StartupFlow.trace("SkirmishScene._on_demo_sortie_requested failed")
	else:
		StartupFlow.trace("SkirmishScene._on_demo_sortie_requested success active=%s" % str(TacticalSkirmishManager.is_active()))


func _on_demo_cheat_attack_requested() -> void:
	TacticalSkirmishManager.set_demo_attack_multiplier(DEMO_CHEAT_ATTACK_MULTIPLIER)
	if _should_show_tutorial_guidance_ui() and is_instance_valid(_demo_objective_panel) and _demo_objective_panel.has_method("update_panel"):
		_demo_objective_panel.update_panel()
	if big_map_scene != null:
		big_map_scene.show_turn_info("测试作弊已开启：我方演武伤害 ×%d" % int(DEMO_CHEAT_ATTACK_MULTIPLIER))


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
