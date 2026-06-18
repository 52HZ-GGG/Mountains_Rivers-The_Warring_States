extends GutTest

const MAIN_SCENE: PackedScene = preload("res://scenes/main/main.tscn")


func before_each() -> void:
	GameManager.reset()
	CityManager.reset()
	EventManager.set_muted(true)


func test_end_turn_button_hidden_on_main_view() -> void:
	var main_scene: Node = add_child_autofree(MAIN_SCENE.instantiate())
	var end_turn_btn: Button = main_scene.get("_persistent_end_btn") as Button

	assert_not_null(end_turn_btn, "主场景应创建持久化结束回合按钮")
	assert_false(end_turn_btn.visible, "主界面不应显示结束回合按钮")


func test_end_turn_advances_turn_and_shows_success_popup() -> void:
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
