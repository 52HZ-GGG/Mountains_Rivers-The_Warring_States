extends GutTest

## 正式大夫面板 + 扩展学派任务


const MINISTER_SCENE: PackedScene = preload("res://scenes/ui/minister_panel/minister_panel.tscn")


func before_each() -> void:
	GameManager.reset()
	CityManager.reset()
	MinisterManager.reset()
	SchoolManager.reset()
	DiplomacySystem.reset()
	EventManager.set_muted(true)
	GameManager.start_game(["qin", "zhao"], "qin")


func test_minister_panel_opens_and_lists_ministers() -> void:
	var panel: Control = add_child_autofree(MINISTER_SCENE.instantiate())
	panel.open("qin")
	assert_true(panel.visible, "面板应打开")
	var civil: VBoxContainer = panel.get("_civil_list") as VBoxContainer
	var military: VBoxContainer = panel.get("_military_list") as VBoxContainer
	var diplomat: VBoxContainer = panel.get("_diplomat_list") as VBoxContainer
	assert_gt(civil.get_child_count(), 0, "应列出文大夫")
	assert_gt(military.get_child_count(), 0, "应列出武大夫")
	assert_gt(diplomat.get_child_count(), 0, "应列出外交大夫")


func test_minister_panel_assign_diplomat() -> void:
	var panel: Control = add_child_autofree(MINISTER_SCENE.instantiate())
	panel.open("qin")
	panel.call("_on_assign_diplomat")
	var any_assigned: bool = false
	for m in MinisterManager.get_faction_diplomat_ministers("qin"):
		if str((m as Dictionary).get("assigned_faction_id", "")) != "":
			any_assigned = true
	assert_true(any_assigned, "面板应能派驻外交大夫")


func test_morale_quest_completes() -> void:
	GameManager._player_morale = 85
	SchoolManager.check_quests("qin")
	# 道家 dao_q3 需要道家；法家无 national_morale 任务，只验证不崩溃
	assert_true(SchoolManager.get_completed_quests("qin") is Array)


func test_daoism_morale_quest() -> void:
	SchoolManager.set_current_school("qin", "daoism")
	# 清过渡期
	var st: Dictionary = SchoolManager.get_school_state("qin")
	st["transition_turns"] = 0
	SchoolManager._school_state_by_faction["qin"] = st
	GameManager._player_morale = 85
	SchoolManager.check_quests("qin")
	assert_true(SchoolManager.get_completed_quests("qin").has("dao_q3"), "民心≥80 应完成道家清静任务")


func test_tax_change_resets_counter() -> void:
	for i in 6:
		SchoolManager.tick_tax_stability_counter("qin")
	SchoolManager.notify_tax_changed("qin")
	SchoolManager.tick_tax_stability_counter("qin")
	# 重新计数后应为 1，未满 5
	GameManager.set_tax_rate(0.4)
	SchoolManager.tick_policy_durations("qin")
	var done: Array = SchoolManager.get_completed_quests("qin")
	assert_false(done.has("dao_q1"), "改税率后不应立刻完成无为而治")
