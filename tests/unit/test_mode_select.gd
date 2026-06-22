extends GutTest

const MODE_SELECT_SCENE: PackedScene = preload("res://scenes/ui/splash/mode_select.tscn")


func before_each() -> void:
	StartupFlow.selected_mode = ""
	StartupFlow.selected_faction = ""
	DemoFlow.reset()


func test_public_demo_is_selected_by_default() -> void:
	var mode_select: Control = add_child_autofree(MODE_SELECT_SCENE.instantiate()) as Control
	var next_button: Button = mode_select.get_node("Buttons/NextButton") as Button
	var hint_label: Label = mode_select.get_node("DemoHintLabel") as Label
	var selected_mode: String = str(mode_select.get("_selected_mode"))

	assert_eq(selected_mode, StartupFlow.MODE_FULL_DEMO, "公开试玩入口应默认选中完整 Demo")
	assert_false(next_button.disabled, "默认选中 Demo 后，开始按钮应立即可用")
	assert_eq(next_button.text, "开始完整试玩", "按钮文案应明确进入完整试玩 Demo")
	assert_true(hint_label.text.contains("经营秦国"), "模式选择界面应直接说明完整 Demo 目标")


func test_locked_modes_show_public_demo_hint() -> void:
	var mode_select: Control = add_child_autofree(MODE_SELECT_SCENE.instantiate()) as Control
	var hint_label: Label = mode_select.get_node("DemoHintLabel") as Label

	mode_select.call("_show_locked_mode_hint", "征战天下")

	assert_true(hint_label.text.contains("暂未开放"), "锁定模式应给出明确反馈")
	assert_true(hint_label.text.contains("新手教程"), "锁定模式提示应引导玩家回到当前可试玩内容")


func test_public_playtest_exposes_tutorial_and_full_demo_modes() -> void:
	var mode_select: Control = add_child_autofree(MODE_SELECT_SCENE.instantiate()) as Control
	var modes: Array = mode_select.get_script().get("MODES")
	var open_count: int = 0
	var locked_count: int = 0
	var open_ids: Array[String] = []

	for mode_v: Variant in modes:
		var mode: Dictionary = mode_v as Dictionary
		if bool(mode.get("locked", false)):
			locked_count += 1
		else:
			open_count += 1
			open_ids.append(str(mode.get("id", "")))

	assert_eq(open_count, 2, "公开试玩阶段应开放新手教程和完整试玩两个模式")
	assert_true(open_ids.has(StartupFlow.MODE_DEMO), "应开放新手教程")
	assert_true(open_ids.has(StartupFlow.MODE_FULL_DEMO), "应开放经营 + 大地图完整 Demo")
	assert_gt(locked_count, 0, "其余正式版模式应保留为锁定状态")


func test_keyboard_accept_starts_public_demo() -> void:
	var mode_select: Control = add_child_autofree(MODE_SELECT_SCENE.instantiate()) as Control

	StartupFlow.selected_mode = ""
	mode_select.call("_unhandled_input", InputEventAction.new())
	var accept_event := InputEventAction.new()
	accept_event.action = "ui_accept"
	accept_event.pressed = true
	mode_select.call("_unhandled_input", accept_event)

	assert_eq(StartupFlow.selected_mode, StartupFlow.MODE_FULL_DEMO, "键盘确认应直接启动默认选中的完整 Demo 模式")


func test_can_select_tutorial_mode() -> void:
	var mode_select: Control = add_child_autofree(MODE_SELECT_SCENE.instantiate()) as Control
	StartupFlow.selected_mode = ""

	mode_select.call("_select_mode", StartupFlow.MODE_DEMO)
	mode_select.call("_on_next")

	assert_eq(StartupFlow.selected_mode, StartupFlow.MODE_DEMO, "选择新手教程应启动教程模式")


func test_public_demo_autostart_method_advances_demo_selection() -> void:
	var mode_select: Control = add_child_autofree(MODE_SELECT_SCENE.instantiate()) as Control
	StartupFlow.selected_mode = ""
	if not OS.has_feature("debug"):
		mode_select.call("_auto_enter_public_demo")
		assert_eq(StartupFlow.selected_mode, StartupFlow.MODE_FULL_DEMO, "公开试玩包的自动进入逻辑应直接推进完整 Demo")
	else:
		assert_true(true, "调试包不强制自动进入 Demo")
