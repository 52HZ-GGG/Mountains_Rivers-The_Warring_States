extends GutTest

const MAIN_SCENE: PackedScene = preload("res://scenes/main/main.tscn")
const _HexAxial := preload("res://scripts/systems/hex_axial.gd")
const PROJECT_CONFIG_PATH: String = "res://project.godot"
const FRAMEWORK_QUICK_SAVE_PATH: String = "user://framework_quick_save.json"


func before_each() -> void:
	GameManager.reset()
	CityManager.reset()
	SchoolManager.reset()
	DemoFlow.reset()
	DemoFlow.set_full_demo_enabled(true)
	TacticalSkirmishManager.set_demo_attack_multiplier(1.0)
	EventManager.set_muted(true)
	_remove_framework_quick_save()


func after_each() -> void:
	_remove_framework_quick_save()


func test_end_turn_button_hidden_on_main_view() -> void:
	var main_scene: Node = add_child_autofree(MAIN_SCENE.instantiate())
	var end_turn_btn: Button = main_scene.get("_persistent_end_btn") as Button

	assert_not_null(end_turn_btn, "主场景应创建持久化结束回合按钮")
	assert_false(end_turn_btn.visible, "主界面不应显示结束回合按钮")


func test_project_starts_from_splash_flow() -> void:
	var config: ConfigFile = ConfigFile.new()
	var err: Error = config.load(PROJECT_CONFIG_PATH)
	assert_eq(err, OK, "应能读取 project.godot")

	var main_scene_path: String = str(config.get_value("application", "run/main_scene", ""))

	assert_eq(main_scene_path, "res://scenes/ui/splash/splash_screen.tscn", "Release 入口应先进入开场动画与模式选择")


func test_framework_hub_exposes_formal_game_modules() -> void:
	var main_scene: Node = add_child_autofree(MAIN_SCENE.instantiate())
	var framework_hub: Control = main_scene.get("_framework_hub") as Control

	assert_not_null(framework_hub, "主场景应创建正式版框架 Hub")
	assert_true(framework_hub.visible, "框架 Hub 应作为主界面默认可见")
	for module_id: String in [
		"big_map",
		"city",
		"military",
		"diplomacy",
		"tech",
		"events",
		"schools",
		"ministers",
		"intelligence",
		"resources",
		"save",
		"settings",
	]:
		assert_not_null(
			_find_descendant_by_name(framework_hub, "HubModule_%s" % module_id),
			"框架 Hub 应暴露正式版模块入口：%s" % module_id
		)

	var briefing_text: RichTextLabel = _find_descendant_by_name(framework_hub, "BriefingText") as RichTextLabel
	assert_not_null(briefing_text, "框架 Hub 应包含试玩骨架说明")
	assert_true(briefing_text.text.contains("推荐试玩顺序"), "框架 Hub 应给出统一试玩顺序提示")
	assert_not_null(_find_descendant_by_name(framework_hub, "HubScroll"), "框架 Hub 应支持滚动查看完整内容")
	assert_not_null(_find_descendant_by_name(framework_hub, "HubZoomInButton"), "框架 Hub 应提供放大按钮")
	assert_not_null(_find_descendant_by_name(framework_hub, "HubZoomOutButton"), "框架 Hub 应提供缩小按钮")


func test_framework_placeholder_opens_for_unfinished_modules() -> void:
	var main_scene: Node = add_child_autofree(MAIN_SCENE.instantiate())

	main_scene.call("_on_framework_module_pressed", "unknown_module")
	var placeholder_layer: CanvasLayer = main_scene.get("_framework_placeholder_layer") as CanvasLayer
	var placeholder_title: Label = main_scene.get("_framework_placeholder_title") as Label
	var placeholder_body: RichTextLabel = main_scene.get("_framework_placeholder_body") as RichTextLabel

	assert_true(placeholder_layer.visible, "未完成模块应打开统一占位面板，而不是静默无响应")
	assert_eq(placeholder_title.text, "unknown_module", "未知模块占位面板标题应对应被点击模块")
	assert_true(placeholder_body.text.contains("模块入口已预留"), "占位面板应说明该模块还没有接入正式面板")


func test_framework_events_module_uses_real_event_data() -> void:
	var main_scene: Node = add_child_autofree(MAIN_SCENE.instantiate())
	EventManager._cooldowns["evt_harvest_bumper"] = 2
	EventManager._chain_states["chain_zhangyi_lianheng"] = {"current_index": 1}
	EventManager._record_recent_event(DataManager.get_event("evt_harvest_bumper"), "triggered")

	main_scene.call("_on_framework_module_pressed", "events")
	var placeholder_title: Label = main_scene.get("_framework_placeholder_title") as Label
	var placeholder_body: RichTextLabel = main_scene.get("_framework_placeholder_body") as RichTextLabel

	assert_eq(placeholder_title.text, "事件总览", "事件入口应升级为真实数据总览")
	assert_true(placeholder_body.text.contains("试玩说明"), "事件总览应统一提供试玩说明")
	assert_true(placeholder_body.text.contains("事件总数"), "事件总览应展示事件数据统计")
	assert_true(placeholder_body.text.contains("五谷丰登"), "事件总览应展示已有事件样例")
	assert_true(placeholder_body.text.contains("运行态事件"), "事件总览应展示最近运行态事件")
	assert_true(placeholder_body.text.contains("冷却中的事件"), "事件总览应展示冷却中的事件")
	assert_true(placeholder_body.text.contains("事件链进度"), "事件总览应展示事件链推进状态")
	assert_true(placeholder_body.text.contains("张仪连横"), "事件总览应展示具体事件链名称")


func test_framework_schools_module_uses_real_school_data() -> void:
	GameManager.start_game(GameManager.FACTION_IDS, "qin")
	SchoolManager.add_school_exp("qin", 60)
	SchoolManager.activate_policy("qin", "leg_surveillance")
	var main_scene: Node = add_child_autofree(MAIN_SCENE.instantiate())

	main_scene.call("_on_framework_module_pressed", "schools")
	var placeholder_title: Label = main_scene.get("_framework_placeholder_title") as Label
	var placeholder_body: RichTextLabel = main_scene.get("_framework_placeholder_body") as RichTextLabel
	var actions: HBoxContainer = main_scene.get("_framework_placeholder_actions") as HBoxContainer

	assert_eq(placeholder_title.text, "学派 / 文化总览", "学派入口应升级为真实数据总览")
	assert_true(placeholder_body.text.contains("试玩说明"), "学派总览应统一提供试玩说明")
	assert_true(placeholder_body.text.contains("学派数量"), "学派总览应展示学派数据统计")
	assert_true(placeholder_body.text.contains("儒家"), "学派总览应展示已有学派")
	assert_true(placeholder_body.text.contains("当前运行时学派"), "学派总览应展示当前势力的运行时学派")
	assert_true(placeholder_body.text.contains("法家"), "秦国默认学派应显示为法家")
	assert_true(placeholder_body.text.contains("当前等级：2"), "学派总览应展示运行时等级")
	assert_true(placeholder_body.text.contains("什伍连坐"), "学派总览应展示已激活的运行时政策")
	assert_not_null(_find_descendant_by_name(actions, "OpenSchoolEventsButton"), "学派总览应提供相关事件入口")
	assert_not_null(_find_descendant_by_name(actions, "OpenSchoolTechButton"), "学派总览应提供科技入口")


func test_framework_school_switch_panel_can_change_runtime_school() -> void:
	GameManager.start_game(GameManager.FACTION_IDS, "qin")
	var main_scene: Node = add_child_autofree(MAIN_SCENE.instantiate())

	main_scene.call("_open_school_switch_panel")
	var actions: HBoxContainer = main_scene.get("_framework_placeholder_actions") as HBoxContainer
	var scroll: ScrollContainer = main_scene.get("_framework_placeholder_scroll") as ScrollContainer
	var switch_button: Button = _find_descendant_by_name(actions, "SchoolSwitch_confucianism") as Button

	assert_not_null(switch_button, "学派切换面板应提供儒家切换按钮")
	assert_not_null(scroll, "学派切换面板应支持滚动查看长内容")
	switch_button.pressed.emit()
	await wait_frames(1)
	assert_eq(SchoolManager.get_current_school("qin"), "confucianism", "点击切换按钮后应变更当前学派")


func test_framework_ministers_module_uses_real_minister_data() -> void:
	GameManager.start_game(GameManager.FACTION_IDS, "qin")
	var main_scene: Node = add_child_autofree(MAIN_SCENE.instantiate())

	main_scene.call("_on_framework_module_pressed", "ministers")
	var placeholder_title: Label = main_scene.get("_framework_placeholder_title") as Label
	var placeholder_body: RichTextLabel = main_scene.get("_framework_placeholder_body") as RichTextLabel
	var actions: HBoxContainer = main_scene.get("_framework_placeholder_actions") as HBoxContainer

	assert_eq(placeholder_title.text, "官员 / 大夫总览", "官员入口应升级为真实数据总览")
	assert_true(placeholder_body.text.contains("试玩说明"), "官员总览应统一提供试玩说明")
	assert_true(placeholder_body.text.contains("官员条目"), "官员总览应展示官员数据统计")
	assert_true(placeholder_body.text.contains("商鞅"), "官员总览应展示已有历史人物")
	assert_true(placeholder_body.text.contains("当前势力关注"), "官员总览应展示当前势力的官员关注方向")
	assert_true(placeholder_body.text.contains("秦国"), "秦国试玩路径下应展示玩家势力信息")
	assert_true(placeholder_body.text.contains("法家"), "秦国默认学派关联人物应指向法家")
	assert_not_null(_find_descendant_by_name(actions, "OpenMinisterCityButton"), "官员总览应提供城市入口")
	assert_not_null(_find_descendant_by_name(actions, "OpenMinisterDiplomacyButton"), "官员总览应提供外交入口")


func test_framework_minister_assign_panel_can_reassign_capital_minister() -> void:
	GameManager.start_game(GameManager.FACTION_IDS, "qin")
	var capital_id: String = str(CityManager.get_capital_state("qin").get("id", ""))
	var before: Dictionary = MinisterManager.get_city_civil_minister(capital_id)
	var main_scene: Node = add_child_autofree(MAIN_SCENE.instantiate())

	main_scene.call("_open_minister_assign_panel")
	var actions: HBoxContainer = main_scene.get("_framework_placeholder_actions") as HBoxContainer
	var assign_button: Button = _find_descendant_by_name(actions, "MinisterAssignCapitalButton") as Button

	assert_not_null(assign_button, "大夫派驻面板应提供首都派驻按钮")
	assign_button.pressed.emit()
	await wait_frames(1)
	var after: Dictionary = MinisterManager.get_city_civil_minister(capital_id)
	assert_false(after.is_empty(), "首都应保持有派驻文大夫")
	assert_ne(str(before.get("id", "")), "", "派驻前应存在文大夫")
	assert_ne(str(after.get("id", "")), "", "派驻后应存在文大夫")


func test_framework_intelligence_module_uses_existing_strategy_data() -> void:
	GameManager.start_game(GameManager.FACTION_IDS, "qin")
	var main_scene: Node = add_child_autofree(MAIN_SCENE.instantiate())

	main_scene.call("_on_framework_module_pressed", "intelligence")
	var placeholder_title: Label = main_scene.get("_framework_placeholder_title") as Label
	var placeholder_body: RichTextLabel = main_scene.get("_framework_placeholder_body") as RichTextLabel
	var actions: HBoxContainer = main_scene.get("_framework_placeholder_actions") as HBoxContainer

	assert_eq(placeholder_title.text, "情报总览", "情报入口应升级为基于现有战略数据的总览")
	assert_true(placeholder_body.text.contains("试玩说明"), "情报总览应统一提供试玩说明")
	assert_true(placeholder_body.text.contains("势力档案"), "情报总览应展示势力数据来源")
	assert_true(placeholder_body.text.contains("赵国"), "情报总览应展示已有势力情报")
	assert_true(placeholder_body.text.contains("当前外交态势"), "情报总览应展示运行态外交态势")
	assert_not_null(_find_descendant_by_name(actions, "OpenIntelMapButton"), "情报总览应提供跳转到大地图的动作")
	assert_not_null(_find_descendant_by_name(actions, "OpenIntelDiplomacyButton"), "情报总览应提供跳转到外交的动作")


func test_framework_save_module_exposes_quick_save_actions() -> void:
	var main_scene: Node = add_child_autofree(MAIN_SCENE.instantiate())

	main_scene.call("_on_framework_module_pressed", "save")
	var placeholder_title: Label = main_scene.get("_framework_placeholder_title") as Label
	var placeholder_body: RichTextLabel = main_scene.get("_framework_placeholder_body") as RichTextLabel
	var actions: HBoxContainer = main_scene.get("_framework_placeholder_actions") as HBoxContainer

	assert_eq(placeholder_title.text, "存档 / 读档", "存档入口应打开专用快照面板")
	assert_true(placeholder_body.text.contains("快速存档槽"), "存档面板应说明单槽快照状态")
	assert_not_null(_find_descendant_by_name(actions, "QuickSaveButton"), "存档面板应提供快速存档按钮")
	assert_not_null(_find_descendant_by_name(actions, "QuickLoadButton"), "存档面板应提供快速读档按钮")


func test_framework_quick_save_and_load_snapshot() -> void:
	GameManager.start_game(GameManager.FACTION_IDS, "qin")
	SchoolManager.add_school_exp("qin", 130)
	SchoolManager.activate_policy("qin", "leg_reform")
	WonderManager.set_wonder_owner("honggou", "qin")
	var main_scene: Node = add_child_autofree(MAIN_SCENE.instantiate())

	main_scene.call("_on_framework_module_pressed", "save")
	var actions: HBoxContainer = main_scene.get("_framework_placeholder_actions") as HBoxContainer
	var placeholder_body: RichTextLabel = main_scene.get("_framework_placeholder_body") as RichTextLabel
	var quick_save_button: Button = _find_descendant_by_name(actions, "QuickSaveButton") as Button
	var quick_load_button: Button = _find_descendant_by_name(actions, "QuickLoadButton") as Button

	quick_save_button.pressed.emit()
	await wait_frames(1)

	assert_true(FileAccess.file_exists(FRAMEWORK_QUICK_SAVE_PATH), "快速存档应写入 user:// 单槽文件")
	assert_true(placeholder_body.text.contains("保存成功"), "快速存档后应向玩家反馈保存成功")

	quick_load_button.pressed.emit()
	await wait_frames(1)

	assert_true(placeholder_body.text.contains("读取成功"), "快速读档应读取快照并展示成功反馈")
	assert_true(placeholder_body.text.contains("秦国"), "快速读档摘要应展示玩家势力")
	assert_eq(SchoolManager.get_current_school("qin"), "legalism", "快速读档后应恢复学派状态")
	assert_eq(SchoolManager.get_school_level("qin"), 3, "快速读档后应恢复学派等级")
	assert_eq(SchoolManager.get_active_policies("qin").size(), 1, "快速读档后应恢复激活政策")
	assert_true(WonderManager.has_wonder("qin", "honggou"), "快速读档后应恢复奇观归属")


func test_framework_settings_module_exposes_basic_actions() -> void:
	var main_scene: Node = add_child_autofree(MAIN_SCENE.instantiate())

	main_scene.call("_on_framework_module_pressed", "settings")
	var placeholder_title: Label = main_scene.get("_framework_placeholder_title") as Label
	var placeholder_body: RichTextLabel = main_scene.get("_framework_placeholder_body") as RichTextLabel
	var actions: HBoxContainer = main_scene.get("_framework_placeholder_actions") as HBoxContainer

	assert_eq(placeholder_title.text, "设置", "设置入口应打开专用设置面板")
	assert_true(placeholder_body.text.contains("音频"), "设置面板应显示音频状态")
	assert_true(placeholder_body.text.contains("显示"), "设置面板应显示窗口状态")
	assert_true(placeholder_body.text.contains("测试开关"), "设置面板应显示测试开关状态")
	assert_not_null(_find_descendant_by_name(actions, "ToggleMuteButton"), "设置面板应提供静音切换按钮")
	assert_not_null(_find_descendant_by_name(actions, "ToggleFullscreenButton"), "设置面板应提供全屏切换按钮")
	assert_not_null(_find_descendant_by_name(actions, "ToggleDemoCheatButton"), "设置面板应提供 Demo 作弊切换按钮")


func test_framework_settings_can_toggle_demo_cheat() -> void:
	var main_scene: Node = add_child_autofree(MAIN_SCENE.instantiate())

	main_scene.call("_on_framework_module_pressed", "settings")
	var actions: HBoxContainer = main_scene.get("_framework_placeholder_actions") as HBoxContainer
	var placeholder_body: RichTextLabel = main_scene.get("_framework_placeholder_body") as RichTextLabel
	var toggle_cheat_button: Button = _find_descendant_by_name(actions, "ToggleDemoCheatButton") as Button

	assert_eq(TacticalSkirmishManager.get_demo_attack_multiplier(), 1.0, "默认不应启用 Demo 作弊")

	toggle_cheat_button.pressed.emit()
	await wait_frames(1)

	assert_eq(TacticalSkirmishManager.get_demo_attack_multiplier(), 20.0, "设置面板应能开启 Demo 作弊倍率")
	assert_true(placeholder_body.text.contains("开启"), "开启作弊后设置面板应刷新状态")

	toggle_cheat_button.pressed.emit()
	await wait_frames(1)

	assert_eq(TacticalSkirmishManager.get_demo_attack_multiplier(), 1.0, "设置面板应能关闭 Demo 作弊倍率")
	assert_true(placeholder_body.text.contains("关闭"), "关闭作弊后设置面板应刷新状态")


func test_end_turn_advances_turn_and_shows_success_popup() -> void:
	GameManager.start_game(GameManager.FACTION_IDS, "qin")
	var main_scene: Node = add_child_autofree(MAIN_SCENE.instantiate())
	var initial_turn: int = GameManager.get_current_turn()
	var initial_faction: String = GameManager.get_current_faction()
	var end_turn_btn: Button = main_scene.get("_persistent_end_btn") as Button
	main_scene.call("_on_big_map_button_pressed")
	main_scene.call("_on_next_turn_pressed")
	await wait_until(func() -> bool:
		return not end_turn_btn.disabled
	, 2.0, "等待结束回合异步推进完成")

	var turn_info_panel: PanelContainer = main_scene.get("_turn_info_panel") as PanelContainer
	var turn_info_status: Label = main_scene.get("_turn_info_status") as Label
	var current_turn: int = GameManager.get_current_turn()
	var current_faction: String = GameManager.get_current_faction()

	assert_true(end_turn_btn.visible, "进入大地图后结束回合按钮应可见")
	assert_false(end_turn_btn.disabled, "回合推进完成后按钮应重新可点击")
	assert_true(turn_info_panel.visible, "成功切换回合后应显示回合提示弹窗")
	assert_eq(turn_info_status.text, "回合切换成功", "弹窗应明确提示切换成功")
	assert_true(
		current_turn > initial_turn or current_faction != initial_faction,
		"点击结束回合后，当前回合或当前势力至少应推进一次"
	)


func test_end_turn_can_be_triggered_multiple_times() -> void:
	GameManager.start_game(GameManager.FACTION_IDS, "qin")
	var main_scene: Node = add_child_autofree(MAIN_SCENE.instantiate())
	var end_turn_btn: Button = main_scene.get("_persistent_end_btn") as Button
	main_scene.call("_on_big_map_button_pressed")
	main_scene.call("_on_next_turn_pressed")
	await wait_until(func() -> bool:
		return not end_turn_btn.disabled
	, 2.0, "等待第一次结束回合同步完成")
	var turn_after_first: int = GameManager.get_current_turn()
	var faction_after_first: String = GameManager.get_current_faction()
	main_scene.call("_on_next_turn_pressed")
	await wait_until(func() -> bool:
		return not end_turn_btn.disabled
	, 2.0, "等待第二次结束回合同步完成")

	var turn_after_second: int = GameManager.get_current_turn()
	var faction_after_second: String = GameManager.get_current_faction()

	assert_false(end_turn_btn.disabled, "连续推进后按钮仍应可点击")
	assert_true(
		turn_after_second > turn_after_first or faction_after_second != faction_after_first,
		"连续点击两次结束回合后，状态应继续推进，而不是第一次后卡住"
	)


func test_demo_sortie_opens_skirmish_panel() -> void:
	DemoFlow.set_enabled(true)
	var main_scene: Node = add_child_autofree(MAIN_SCENE.instantiate())
	var demo_objective_panel: Control = main_scene.get("_demo_objective_panel") as Control

	main_scene.call("_on_demo_sortie_requested")
	var skirmish_panel: CanvasLayer = main_scene.get("_active_skirmish_panel") as CanvasLayer

	assert_true(TacticalSkirmishManager.is_active(), "点击出征洛邑后应启动演武管理器")
	assert_not_null(skirmish_panel, "点击出征洛邑后应动态创建置顶演武面板")
	assert_true(skirmish_panel.visible, "点击出征洛邑后应显示演武面板")
	assert_true(demo_objective_panel.visible, "演武打开时保留 Demo 目标面板，避免黑屏时缺少状态锚点")
	assert_gt(
		int((main_scene.get("_demo_layer") as CanvasLayer).layer),
		int(skirmish_panel.layer),
		"Demo 目标面板层级应高于演武面板，进入演武后仍能看到目标说明"
	)


func test_demo_strategy_preparation_tracks_map_and_capital() -> void:
	DemoFlow.set_enabled(true)
	var main_scene: Node = add_child_autofree(MAIN_SCENE.instantiate())
	var demo_objective_panel: Control = main_scene.get("_demo_objective_panel") as Control
	var sortie_button: Button = demo_objective_panel.get_node("Margin/VBox/SortieButton") as Button

	assert_true(sortie_button.disabled, "完整 Demo 初始应要求先完成经营准备")

	main_scene.call("_on_big_map_button_pressed")
	assert_true(DemoFlow.is_step_completed(DemoFlow.STEP_OPEN_BIG_MAP), "打开大地图应推进版图确认步骤")
	assert_false(DemoFlow.is_step_completed(DemoFlow.STEP_PREPARE_QIN), "尚未打开首都经营时不应完成经营准备")
	assert_true(sortie_button.disabled, "只看版图后仍不能直接出征")

	main_scene.call("_open_player_capital_panel")
	assert_true(DemoFlow.is_step_completed(DemoFlow.STEP_MANAGE_CAPITAL), "打开玩家首都应推进经营准备步骤")
	assert_true(DemoFlow.is_step_completed(DemoFlow.STEP_PREPARE_QIN), "版图和首都都查看后应完成经营准备")
	assert_false(sortie_button.disabled, "经营准备完成后应允许从任务面板出征")


func test_framework_demo_briefing_shows_full_strategy_scope() -> void:
	StartupFlow.start_demo_game_direct()
	var main_scene: Node = add_child_autofree(MAIN_SCENE.instantiate())
	var framework_hub: Control = main_scene.get("_framework_hub") as Control
	var briefing_text: RichTextLabel = _find_descendant_by_name(framework_hub, "BriefingText") as RichTextLabel

	assert_not_null(briefing_text, "战略中枢应包含 Demo 简报")
	assert_true(briefing_text.text.contains("七国同场"), "Demo 简报应明确不是两国演武")
	assert_true(briefing_text.text.contains("周室/中立城市"), "Demo 简报应展示周室和中立城市也在战略层")
	assert_true(briefing_text.text.contains("经营秦国"), "Demo 简报应把经营作为战斗前置链路")


func test_demo_cheat_button_raises_skirmish_attack_multiplier() -> void:
	DemoFlow.set_enabled(true)
	var main_scene: Node = add_child_autofree(MAIN_SCENE.instantiate())
	var demo_objective_panel: Control = main_scene.get("_demo_objective_panel") as Control
	var cheat_attack_button: Button = demo_objective_panel.get_node("Margin/VBox/CheatAttackButton") as Button

	assert_eq(TacticalSkirmishManager.get_demo_attack_multiplier(), 1.0, "默认不应启用测试作弊")
	assert_true(cheat_attack_button.visible, "正式试玩包也应显示 Demo 作弊按钮，方便快速验收")
	main_scene.call("_on_demo_cheat_attack_requested")

	assert_eq(TacticalSkirmishManager.get_demo_attack_multiplier(), 20.0, "测试作弊应提高我方演武伤害")


func test_demo_objective_panel_shows_wall_hp_during_skirmish() -> void:
	DemoFlow.set_enabled(true)
	var main_scene: Node = add_child_autofree(MAIN_SCENE.instantiate())

	main_scene.call("_on_demo_sortie_requested")
	var demo_objective_panel: Control = main_scene.get("_demo_objective_panel") as Control
	var guidance_label: Label = demo_objective_panel.get_node("Margin/VBox/Guidance") as Label
	var win_skirmish_label: Label = demo_objective_panel.get_node("Margin/VBox/Steps/WinSkirmish") as Label
	var enemy_city: Vector2i = TacticalSkirmishManager.get_enemy_city()
	TacticalSkirmishManager._city_wall_hp[enemy_city] = 675
	TacticalSkirmishManager.state_changed.emit()
	await wait_frames(1)

	assert_true(guidance_label.text.contains("洛邑城墙：675"), "目标提示应显示洛邑城墙剩余 HP")
	assert_true(win_skirmish_label.text.contains("继续攻击洛邑城墙"), "步骤 2 应提示继续攻击城墙，而不是笼统未完成")


func test_demo_skirmish_panel_shows_public_playtest_briefing() -> void:
	DemoFlow.set_enabled(true)
	var main_scene: Node = add_child_autofree(MAIN_SCENE.instantiate())

	main_scene.call("_on_demo_sortie_requested")
	var skirmish_panel: CanvasLayer = main_scene.get("_active_skirmish_panel") as CanvasLayer
	var hint_label: Label = skirmish_panel.get_node("MarginContainer/MainVBox/HintLabel") as Label
	var hover_info: RichTextLabel = skirmish_panel.get_node("MarginContainer/MainVBox/HexHoverInfo") as RichTextLabel

	assert_true(hint_label.text.contains("Demo 作战简报"), "Demo 演武打开后应直接显示作战简报")
	assert_true(hint_label.text.contains("洛邑城墙"), "作战简报应明确攻击目标是洛邑城墙")
	assert_true(hint_label.text.contains("进入洛邑城格"), "作战简报应明确最终胜利动作")
	assert_true(hover_info.text.contains("攻城器械"), "默认悬停提示应说明推荐使用攻城器械")


func test_main_menu_can_open_and_close_big_map() -> void:
	GameManager.start_game(GameManager.FACTION_IDS, "qin")
	var main_scene: Node = add_child_autofree(MAIN_SCENE.instantiate())

	main_scene.call("_on_big_map_button_pressed")
	var big_map_panel: CanvasLayer = main_scene.get("_big_map_panel") as CanvasLayer
	var end_turn_btn: Button = main_scene.get("_persistent_end_btn") as Button

	assert_not_null(big_map_panel, "点击大地图后应创建大地图面板")
	assert_true(big_map_panel.visible, "大地图面板应可见")
	assert_not_null(_find_descendant_by_text(big_map_panel, "政治地图：关"), "正式大地图应提供政治地图开关")
	assert_true(end_turn_btn.visible, "大地图打开时应显示结束回合按钮")
	_assert_toolbar_visible(main_scene, false, "大地图打开时")

	main_scene.call("_on_big_map_closed")
	big_map_panel = main_scene.get("_big_map_panel") as CanvasLayer

	assert_null(big_map_panel, "关闭大地图后应释放大地图面板引用")
	assert_false(end_turn_btn.visible, "关闭大地图后应隐藏结束回合按钮")
	_assert_toolbar_visible(main_scene, true, "大地图关闭后")


func test_main_menu_can_open_city_panel_and_return_to_map() -> void:
	GameManager.start_game(GameManager.FACTION_IDS, "qin")
	var main_scene: Node = add_child_autofree(MAIN_SCENE.instantiate())

	main_scene.call("_on_city_clicked", "xianyang")
	var city_panel: Panel = main_scene.get("_city_panel") as Panel
	var end_turn_btn: Button = main_scene.get("_persistent_end_btn") as Button

	assert_not_null(city_panel, "点击城市后应创建城池面板")
	assert_true(city_panel.visible, "城池面板应可见")
	assert_true(end_turn_btn.visible, "城池面板打开时应显示结束回合按钮")
	_assert_toolbar_visible(main_scene, false, "城池面板打开时")

	main_scene.call("_on_city_panel_back")
	var big_map_panel: CanvasLayer = main_scene.get("_big_map_panel") as CanvasLayer
	city_panel = main_scene.get("_city_panel") as Panel

	assert_null(city_panel, "返回大地图后应释放城池面板引用")
	assert_not_null(big_map_panel, "返回大地图后应重新打开大地图面板")
	assert_true(big_map_panel.visible, "返回后的大地图面板应可见")
	assert_true(end_turn_btn.visible, "返回大地图后结束回合按钮仍应可见")

	main_scene.call("_on_big_map_closed")
	assert_false(end_turn_btn.visible, "关闭返回后的大地图后应隐藏结束回合按钮")
	_assert_toolbar_visible(main_scene, true, "返回路径关闭后")


func test_main_menu_can_open_and_close_diplomacy() -> void:
	GameManager.start_game(GameManager.FACTION_IDS, "qin")
	var main_scene: Node = add_child_autofree(MAIN_SCENE.instantiate())

	main_scene.call("_on_diplomacy_button_pressed")
	var diplomacy_panel: Panel = main_scene.get("_diplomacy_panel") as Panel
	var end_turn_btn: Button = main_scene.get("_persistent_end_btn") as Button

	assert_not_null(diplomacy_panel, "点击外交后应创建外交面板")
	assert_true(diplomacy_panel.visible, "外交面板应可见")
	assert_true(end_turn_btn.visible, "外交面板打开时应显示结束回合按钮")
	_assert_toolbar_visible(main_scene, false, "外交面板打开时")

	main_scene.call("_on_diplomacy_closed")

	assert_null(main_scene.get("_diplomacy_panel"), "关闭外交后应清空外交面板引用")
	assert_false(end_turn_btn.visible, "关闭外交后应隐藏结束回合按钮")
	_assert_toolbar_visible(main_scene, true, "外交关闭后")


func test_main_menu_can_toggle_tech_tree() -> void:
	var main_scene: Node = add_child_autofree(MAIN_SCENE.instantiate())
	var tech_panel: Control = main_scene.get_node("TechTreePanel") as Control

	assert_false(tech_panel.visible, "科技树默认应隐藏")
	main_scene.call("_on_tech_button_pressed")
	assert_true(tech_panel.visible, "点击科技后应显示科技树")
	main_scene.call("_on_tech_button_pressed")
	assert_false(tech_panel.visible, "再次点击科技后应隐藏科技树")


func test_main_menu_can_open_and_close_skirmish_scenario_panel() -> void:
	var main_scene: Node = add_child_autofree(MAIN_SCENE.instantiate())

	main_scene.call("_on_skirmish_button_pressed")
	var scenario_panel: CanvasLayer = main_scene.get("_scenario_panel") as CanvasLayer
	var end_turn_btn: Button = main_scene.get("_persistent_end_btn") as Button

	assert_not_null(scenario_panel, "点击战术演武后应创建场景选择面板")
	assert_true(scenario_panel.visible, "场景选择面板应可见")
	assert_false(end_turn_btn.visible, "场景选择面板打开时不应显示结束回合按钮")
	_assert_toolbar_visible(main_scene, false, "场景选择面板打开时")

	scenario_panel.call("close_panel")
	await wait_frames(1)

	assert_false(scenario_panel.visible, "关闭场景选择后面板应隐藏")
	assert_false(end_turn_btn.visible, "关闭场景选择后结束回合按钮仍应隐藏")
	_assert_toolbar_visible(main_scene, true, "场景选择关闭后")


func test_main_menu_can_open_and_close_event_test_panel() -> void:
	var main_scene: Node = add_child_autofree(MAIN_SCENE.instantiate())

	main_scene.call("_on_event_test_button_pressed")
	var event_test_panel: Panel = main_scene.get("_event_test_panel") as Panel
	var end_turn_btn: Button = main_scene.get("_persistent_end_btn") as Button

	assert_not_null(event_test_panel, "点击事件测试后应创建事件测试面板")
	assert_true(event_test_panel.visible, "事件测试面板应可见")
	assert_false(end_turn_btn.visible, "事件测试面板打开时不应显示结束回合按钮")
	_assert_toolbar_visible(main_scene, false, "事件测试面板打开时")

	event_test_panel.call("_on_close_pressed")
	await wait_frames(1)

	assert_false(event_test_panel.visible, "关闭事件测试后面板应隐藏")
	assert_false(end_turn_btn.visible, "关闭事件测试后结束回合按钮仍应隐藏")
	_assert_toolbar_visible(main_scene, true, "事件测试关闭后")


func test_demo_objective_panel_can_collapse() -> void:
	DemoFlow.set_enabled(true)
	var main_scene: Node = add_child_autofree(MAIN_SCENE.instantiate())
	var demo_objective_panel: Control = main_scene.get("_demo_objective_panel") as Control
	var collapse_button: Button = demo_objective_panel.get_node("Margin/VBox/Header/CollapseButton") as Button

	collapse_button.pressed.emit()
	await wait_frames(1)
	var demo_expand_btn: Button = main_scene.get("_demo_expand_btn") as Button

	assert_false(demo_objective_panel.visible, "任务面板收起后应隐藏完整黑框，避免继续遮挡左上角")
	assert_not_null(demo_expand_btn, "任务面板收起后应显示独立展开按钮")
	assert_true(demo_expand_btn.visible, "独立展开按钮应可见")

	demo_expand_btn.pressed.emit()
	await wait_frames(1)

	assert_true(demo_objective_panel.visible, "点击独立展开按钮后应恢复完整任务面板")
	assert_false(demo_expand_btn.visible, "完整任务面板展开后应隐藏独立展开按钮")


func test_demo_skirmish_victory_returns_to_main_and_shows_popup() -> void:
	DemoFlow.set_enabled(true)
	var main_scene: Node = add_child_autofree(MAIN_SCENE.instantiate())

	main_scene.call("_on_demo_sortie_requested")
	var skirmish_panel_before: CanvasLayer = main_scene.get("_active_skirmish_panel") as CanvasLayer
	assert_not_null(skirmish_panel_before, "出征后应存在演武面板")

	main_scene.call("_on_skirmish_ended", DemoFlow.get_player_faction_id())
	await wait_frames(1)

	var skirmish_panel_after: CanvasLayer = main_scene.get("_active_skirmish_panel") as CanvasLayer
	var demo_objective_panel: Control = main_scene.get("_demo_objective_panel") as Control
	var demo_victory_popup: Control = main_scene.get("_demo_victory_popup") as Control
	var luoyi: Dictionary = CityManager.get_city_state(DemoFlow.get_target_city_id())

	assert_null(skirmish_panel_after, "Demo 演武胜利后应关闭演武面板，避免遮住胜利反馈")
	assert_true(demo_objective_panel.visible, "Demo 演武胜利后应回到主界面并显示任务面板")
	assert_true(demo_victory_popup.visible, "Demo 演武胜利后应显示胜利弹窗")
	assert_eq(luoyi.get("current_faction_id", ""), DemoFlow.get_player_faction_id(), "Demo 演武胜利后洛邑应归秦")
	assert_false(DemoFlow.is_demo_complete(), "Demo 演武胜利后还需查看经营结果才完成闭环")


func test_public_playtest_demo_smoke_path_to_luoyi_result() -> void:
	DemoFlow.set_enabled(true)
	var main_scene: Node = add_child_autofree(MAIN_SCENE.instantiate())
	var demo_objective_panel: Control = main_scene.get("_demo_objective_panel") as Control
	var sortie_button: Button = demo_objective_panel.get_node("Margin/VBox/SortieButton") as Button

	main_scene.call("_on_big_map_button_pressed")
	main_scene.call("_open_player_capital_panel")
	await wait_frames(1)

	sortie_button.pressed.emit()
	await wait_frames(1)

	var skirmish_panel: CanvasLayer = main_scene.get("_active_skirmish_panel") as CanvasLayer
	var hint_label: Label = skirmish_panel.get_node("MarginContainer/MainVBox/HintLabel") as Label

	assert_true(TacticalSkirmishManager.is_active(), "公开试玩路径：点击出征后应进入洛邑演武")
	assert_true(hint_label.text.contains("Demo 作战简报"), "公开试玩路径：进入演武后应看到作战简报")
	assert_true(hint_label.text.contains("洛邑城墙"), "公开试玩路径：作战简报应明确洛邑城墙目标")

	main_scene.call("_on_skirmish_ended", DemoFlow.get_player_faction_id())
	await wait_frames(1)

	var demo_victory_popup: Control = main_scene.get("_demo_victory_popup") as Control
	var inspect_button: Button = demo_victory_popup.get_node("Margin/VBox/ActionRow/InspectButton") as Button
	var luoyi_after_victory: Dictionary = CityManager.get_city_state(DemoFlow.get_target_city_id())

	assert_true(demo_victory_popup.visible, "公开试玩路径：胜利后应显示收束弹窗")
	assert_eq(luoyi_after_victory.get("current_faction_id", ""), DemoFlow.get_player_faction_id(), "公开试玩路径：胜利后洛邑应归秦")

	inspect_button.pressed.emit()
	await wait_frames(1)

	var city_panel: Panel = main_scene.get("_city_panel") as Panel

	assert_false(demo_victory_popup.visible, "公开试玩路径：查看结果后应关闭胜利弹窗")
	assert_not_null(city_panel, "公开试玩路径：查看结果应打开洛邑城池面板")
	assert_true(city_panel.visible, "公开试玩路径：洛邑城池面板应可见")
	assert_true(DemoFlow.is_demo_complete(), "公开试玩路径：查看洛邑经营结果后才算 Demo 完成")


func test_demo_victory_popup_can_inspect_luoyi_result() -> void:
	DemoFlow.set_enabled(true)
	var main_scene: Node = add_child_autofree(MAIN_SCENE.instantiate())

	main_scene.call("_on_demo_sortie_requested")
	main_scene.call("_on_skirmish_ended", DemoFlow.get_player_faction_id())
	await wait_frames(1)

	var demo_victory_popup: Control = main_scene.get("_demo_victory_popup") as Control
	var inspect_button: Button = demo_victory_popup.get_node("Margin/VBox/ActionRow/InspectButton") as Button
	inspect_button.pressed.emit()
	await wait_frames(1)

	var city_panel: Panel = main_scene.get("_city_panel") as Panel
	var luoyi: Dictionary = CityManager.get_city_state(DemoFlow.get_target_city_id())

	assert_false(demo_victory_popup.visible, "查看结果后应关闭胜利弹窗")
	assert_not_null(city_panel, "查看洛邑结果应打开城池面板")
	assert_true(city_panel.visible, "洛邑结果城池面板应可见")
	assert_eq(luoyi.get("current_faction_id", ""), DemoFlow.get_player_faction_id(), "查看结果时洛邑仍应归秦")
	assert_true(DemoFlow.is_demo_complete(), "查看洛邑结果后应标记 Demo 完成")


func test_demo_victory_popup_can_replay_demo() -> void:
	DemoFlow.set_enabled(true)
	var main_scene: Node = add_child_autofree(MAIN_SCENE.instantiate())

	main_scene.call("_on_demo_sortie_requested")
	main_scene.call("_on_skirmish_ended", DemoFlow.get_player_faction_id())
	await wait_frames(1)

	var demo_victory_popup: Control = main_scene.get("_demo_victory_popup") as Control
	var replay_button: Button = demo_victory_popup.get_node("Margin/VBox/ActionRow/ReplayButton") as Button
	replay_button.pressed.emit()
	await wait_frames(1)

	var active_skirmish_panel: CanvasLayer = main_scene.get("_active_skirmish_panel") as CanvasLayer
	var luoyi: Dictionary = CityManager.get_city_state(DemoFlow.get_target_city_id())

	assert_false(demo_victory_popup.visible, "再战一次后应关闭胜利弹窗")
	assert_true(TacticalSkirmishManager.is_active(), "再战一次应重新启动洛邑演武")
	assert_not_null(active_skirmish_panel, "再战一次应重新创建演武面板")
	assert_false(DemoFlow.is_demo_complete(), "再战一次应重置 Demo 完成状态")
	assert_ne(luoyi.get("current_faction_id", ""), DemoFlow.get_player_faction_id(), "再战一次应重置洛邑归属")


func test_demo_victory_popup_can_return_to_hub() -> void:
	DemoFlow.set_enabled(true)
	var main_scene: Node = add_child_autofree(MAIN_SCENE.instantiate())

	main_scene.call("_on_demo_sortie_requested")
	main_scene.call("_on_skirmish_ended", DemoFlow.get_player_faction_id())
	await wait_frames(1)

	var demo_victory_popup: Control = main_scene.get("_demo_victory_popup") as Control
	var return_button: Button = demo_victory_popup.get_node("Margin/VBox/CloseButton") as Button
	return_button.pressed.emit()
	await wait_frames(1)

	var demo_objective_panel: Control = main_scene.get("_demo_objective_panel") as Control
	var active_skirmish_panel: CanvasLayer = main_scene.get("_active_skirmish_panel") as CanvasLayer

	assert_false(demo_victory_popup.visible, "返回战略中枢后应关闭胜利弹窗")
	assert_true(demo_objective_panel.visible, "返回战略中枢后应恢复 Demo 目标面板")
	assert_null(active_skirmish_panel, "返回战略中枢后不应残留演武面板")


func test_main_does_not_auto_start_while_startup_flow_has_pending_game() -> void:
	StartupFlow.selected_mode = StartupFlow.MODE_DEMO
	StartupFlow.selected_faction = DemoFlow.get_player_faction_id()
	StartupFlow.call("set", "_game_start_pending", true)

	var _main_scene: Node = add_child_autofree(MAIN_SCENE.instantiate())

	assert_eq(
		GameManager.get_current_phase(),
		GameManager.Phase.GAME_INIT,
		"StartupFlow 等待统一开局时，Main 不应抢先自启默认七国局"
	)
	StartupFlow.call("set", "_game_start_pending", false)
	StartupFlow.selected_mode = ""
	StartupFlow.selected_faction = ""


func test_demo_direct_start_uses_full_faction_rotation() -> void:
	StartupFlow.start_demo_game_direct()

	assert_eq(GameManager.get_player_faction(), "qin", "Demo 直开时玩家仍应为秦国")
	assert_eq(GameManager.get_current_faction(), "qin", "Demo 开局当前行动方应为秦国")
	assert_eq(GameManager.get_faction_resources("zhao").is_empty(), false, "Demo 仍应包含赵国")
	assert_eq(GameManager.get_faction_resources("qi").is_empty(), false, "Demo 应接入完整多国轮转，而不只保留两国")
	assert_true(DemoFlow.is_full_demo_enabled(), "默认直达 Demo 应进入经营 + 大地图完整试玩")


func test_tutorial_enters_small_map_but_reuses_formal_strategy_components() -> void:
	StartupFlow.start_demo_game_direct(StartupFlow.MODE_DEMO)
	var main_scene: Node = add_child_autofree(MAIN_SCENE.instantiate())
	await wait_frames(2)

	var demo_objective_panel: Control = main_scene.get("_demo_objective_panel") as Control
	var skirmish_panel: CanvasLayer = main_scene.get("_active_skirmish_panel") as CanvasLayer
	var sortie_button: Button = demo_objective_panel.get_node("Margin/VBox/SortieButton") as Button

	assert_true(DemoFlow.is_tutorial_enabled(), "MODE_DEMO 应作为新手教程运行")
	assert_false(DemoFlow.requires_strategy_preparation(), "新手教程应保持独立短流程，不强制先走完整战略中枢")
	assert_true(TacticalSkirmishManager.is_active(), "新手教程应直达战术小地图")
	assert_not_null(skirmish_panel, "新手教程应自动创建演武面板")
	assert_false(sortie_button.visible, "新手教程直达演武后不应再显示出征洛邑按钮")

	var hint_label: Label = skirmish_panel.get_node("MarginContainer/MainVBox/HintLabel") as Label
	var hover_info: RichTextLabel = skirmish_panel.get_node("MarginContainer/MainVBox/HexHoverInfo") as RichTextLabel
	var tutorial_city_button: Button = _find_descendant_by_name(skirmish_panel, "TutorialCityButton") as Button
	var political_button: Button = _find_descendant_by_name(skirmish_panel, "PoliticalBtn") as Button
	var formal_resource_bar: Control = _find_descendant_by_name(skirmish_panel, "FormalTutorialResourceBar") as Control

	assert_true(hint_label.text.contains("城市/征兵"), "教程演武提示应引导打开正式经营入口")
	assert_true(hover_info.text.contains("复用正式组件"), "教程悬停提示应说明经营界面来自正式组件")
	assert_not_null(tutorial_city_button, "演武面板应提供正式城市/征兵入口")
	assert_true(tutorial_city_button.visible, "城市/征兵教程按钮只应在新手教程中显示")
	assert_not_null(political_button, "战术演武界面应提供与正式版同名的政治地图开关")
	assert_eq(political_button.text, "政治地图：关", "政治地图默认应关闭")
	assert_null(_find_descendant_by_name(skirmish_panel, "TutorialMapButton"), "战术演武教程不应提供大地图入口")
	assert_not_null(formal_resource_bar, "教程演武面板应显示正式资源栏组件")
	assert_true(formal_resource_bar.get_node("ResourceCell_food").tooltip_text.contains("公式"), "资源栏悬浮应展示真实结算公式")
	assert_null(_find_descendant_by_name(skirmish_panel, "TutorialRecruitButton"), "演武面板不应提供教程专用征兵按钮")
	assert_null(_find_descendant_by_name(skirmish_panel, "TutorialProduceSiegeButton"), "演武面板不应提供教程专用生产按钮")
	assert_null(_find_descendant_by_name(skirmish_panel, "TutorialResourceBar"), "演武面板不应自造教程资源栏")
	assert_null(_find_descendant_by_name(skirmish_panel, "TutorialPoliticalMap"), "演武面板不应自造教程政治地图")
	assert_null(_find_descendant_by_name(skirmish_panel, "TutorialCityPanel"), "演武面板不应自造教程城市面板替代正式城市面板")

	political_button.pressed.emit()
	await wait_frames(1)
	assert_eq(political_button.text, "政治地图：开", "战术演武政治地图按钮应在当前演武地图内切换显示")
	var left_owner: String = skirmish_panel.call("_temporary_split_political_owner", _HexAxial.offset_odd_r_to_axial(0, 0))
	var right_owner: String = skirmish_panel.call("_temporary_split_political_owner", _HexAxial.offset_odd_r_to_axial(6, 0))
	assert_eq(left_owner, TacticalSkirmishManager.get_player_faction(), "临时战术政治地图左半应归玩家势力")
	assert_eq(right_owner, TacticalSkirmishManager.get_enemy_faction(), "临时战术政治地图右半应归敌方势力")

	tutorial_city_button.pressed.emit()
	await wait_frames(1)

	var formal_city_panel: Panel = _find_descendant_by_name(skirmish_panel, "FormalTutorialCityPanel") as Panel
	assert_not_null(formal_city_panel, "点击城市/征兵后应打开正式城市面板")
	var info_label: Label = _find_descendant_by_name(formal_city_panel, "CityInfoLabel") as Label
	assert_not_null(info_label, "正式城市面板应包含城市信息")
	assert_true(info_label.text.contains("本城产出"), "城市面板应区分本城原始产出口径")
	assert_true(info_label.text.contains("预计国家入库"), "城市面板应展示税后/维护后的真实入库口径")
	assert_not_null(_find_descendant_by_name(formal_city_panel, "RecruitPoolLabel"), "正式城市面板应包含征兵池")
	var recruit_button: Button = _find_descendant_by_name(formal_city_panel, "RecruitButton_militia") as Button
	assert_not_null(recruit_button, "正式城市面板应提供正式征兵按钮")
	assert_false(recruit_button.disabled, "玩家城市征兵按钮应可点击，失败原因由正式征兵逻辑反馈")
	var return_to_skirmish_button: Button = _find_descendant_by_text(formal_city_panel, "返回演武") as Button
	var close_city_button: Button = _find_descendant_by_text(formal_city_panel, "关闭") as Button
	assert_not_null(return_to_skirmish_button, "教程内正式城市面板的返回按钮应改为返回演武")

	return_to_skirmish_button.pressed.emit()
	await wait_frames(1)

	assert_null(_find_descendant_by_name(skirmish_panel, "FormalTutorialCityPanel"), "点击返回演武后应关闭城市面板，回到战术小地图")

	var player_city: Vector2i = TacticalSkirmishManager.get_player_city()
	skirmish_panel.call("_on_hex_pressed", player_city.x, player_city.y)
	await wait_frames(1)

	formal_city_panel = _find_descendant_by_name(skirmish_panel, "FormalTutorialCityPanel") as Panel
	assert_not_null(formal_city_panel, "教程中未选中部队时点击己方城格也应打开正式城市面板")
	close_city_button = _find_descendant_by_text(formal_city_panel, "关闭") as Button
	assert_not_null(close_city_button, "教程内正式城市面板应保留关闭按钮")

	var end_turn_button: Button = skirmish_panel.get_node("MarginContainer/MainVBox/ButtonRow/EndTurnBtn") as Button
	var turn_before: int = GameManager.get_current_turn()
	var pool_before: int = CityManager.get_conscription_pool("xianyang")
	var season_before: String = TacticalSkirmishManager.get_current_season()

	end_turn_button.pressed.emit()
	await wait_frames(1)

	var pool_after: int = CityManager.get_conscription_pool("xianyang")
	var season_after: String = TacticalSkirmishManager.get_current_season()
	assert_gt(GameManager.get_current_turn(), turn_before, "教程战术结束回合应同步推进正式经营回合")
	assert_gt(pool_after, pool_before, "教程战术结束回合应同步刷新城市征兵池")
	assert_ne(season_after, season_before, "教程战术结束回合应同步刷新战术界面的季节显示")
	assert_true(hint_label.text.contains("季节"), "教程战术结束回合后应在提示中明确季节变化")

	close_city_button.pressed.emit()
	await wait_frames(1)

	assert_null(_find_descendant_by_name(skirmish_panel, "FormalTutorialCityPanel"), "点击关闭后应释放教程内正式城市面板")


func test_end_turn_runs_all_ai_turns_and_returns_to_player() -> void:
	StartupFlow.start_demo_game_direct()
	var main_scene: Node = add_child_autofree(MAIN_SCENE.instantiate())
	var end_turn_btn: Button = main_scene.get("_persistent_end_btn") as Button

	main_scene.call("_on_big_map_button_pressed")
	assert_true(end_turn_btn.visible, "打开大地图后应显示结束回合按钮")

	end_turn_btn.pressed.emit()
	await wait_frames(1)

	assert_eq(GameManager.get_current_faction(), GameManager.get_player_faction(), "点击一次结束回合后应自动结算全部 AI 并回到玩家回合")
	assert_eq(GameManager.get_current_turn(), 2, "点击一次结束回合后应推进到下一玩家回合")


func _assert_toolbar_visible(main_scene: Node, expected: bool, context: String) -> void:
	var toolbar_elements: Array = main_scene.get("_toolbar_elements")
	for elem: Variant in toolbar_elements:
		var control: Control = elem as Control
		assert_not_null(control, "%s工具栏元素应为 Control" % context)
		if control != null:
			assert_eq(control.visible, expected, "%s工具栏可见性应为 %s" % [context, str(expected)])


func _find_descendant_by_name(root: Node, target_name: String) -> Node:
	if root.name == target_name:
		return root
	for child: Node in root.get_children():
		var found: Node = _find_descendant_by_name(child, target_name)
		if found != null:
			return found
	return null


func _find_descendant_by_text(root: Node, target_text: String) -> Node:
	if root is Button:
		var button: Button = root as Button
		if button.text == target_text:
			return button
	for child: Node in root.get_children():
		var found: Node = _find_descendant_by_text(child, target_text)
		if found != null:
			return found
	return null


func _remove_framework_quick_save() -> void:
	if not FileAccess.file_exists(FRAMEWORK_QUICK_SAVE_PATH):
		return
	var absolute_path: String = ProjectSettings.globalize_path(FRAMEWORK_QUICK_SAVE_PATH)
	DirAccess.remove_absolute(absolute_path)
