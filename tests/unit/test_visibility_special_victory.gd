extends GutTest


func before_each() -> void:
	GameManager.reset()
	CityManager.reset()
	MinisterManager.reset()
	TechSystem.reset()
	SchoolManager.reset()
	DiplomacySystem.reset()
	DisasterManager.reset()
	EventManager.set_muted(true)
	GameManager.start_game(["qin", "zhao", "qi", "chu", "wei"], "qin")


func test_unit_info_visibility_neutral_shows_attack_defense() -> void:
	var vis: Dictionary = DiplomacySystem.get_unit_info_visibility("qin", "zhao")
	assert_true(bool(vis.get("unit_name", false)), "兵种名始终可见")
	assert_true(bool(vis.get("hp_status", false)), "血量状态始终可见")
	# 中立默认应能看攻防
	assert_true(bool(vis.get("attack_defense", false)), "中立状态可见攻防")
	assert_false(bool(vis.get("minister_skills", false)), "中立不可见大夫技能")


func test_unit_info_visibility_allied_full_skills() -> void:
	DiplomacySystem.change_opinion("qin", "zhao", 50)
	DiplomacySystem.change_opinion("zhao", "qin", 50)
	DiplomacySystem.form_alliance("qin", "zhao")
	var vis: Dictionary = DiplomacySystem.get_unit_info_visibility("qin", "zhao")
	assert_eq(DiplomacySystem.get_diplomatic_state("qin", "zhao"), "allied")
	assert_true(bool(vis.get("minister_skills", false)), "结盟可见大夫技能")
	assert_true(bool(vis.get("attack_defense", false)))


func test_unit_info_visibility_war_shows_minister_name() -> void:
	DiplomacySystem.declare_war("qin", "zhao")
	var vis: Dictionary = DiplomacySystem.get_unit_info_visibility("qin", "zhao")
	assert_true(bool(vis.get("minister_name", false)), "交战可见大夫名字")
	assert_false(bool(vis.get("minister_skills", false)), "交战不可见大夫技能")


func test_can_attack_requires_war() -> void:
	assert_false(DiplomacySystem.can_attack_faction("qin", "zhao"), "未宣战不可攻击")
	DiplomacySystem.declare_war("qin", "zhao")
	assert_true(DiplomacySystem.can_attack_faction("qin", "zhao"))


func test_special_victory_grant_and_check() -> void:
	assert_false(GameManager.has_special_victory("qin"))
	assert_true(GameManager.grant_special_victory("qin", "nine_tripods"))
	assert_true(GameManager.has_special_victory("qin"))
	assert_eq(str(GameManager.get_special_victories().get("qin", "")), "nine_tripods")
	# 文化/征服未触发时，特殊胜利应决出胜者
	var winner: String = GameManager.check_victory()
	assert_eq(winner, "qin", "特殊胜利应返回该势力")


func test_special_victory_save_round_trip() -> void:
	GameManager.grant_special_victory("qin", "mandate_of_heaven")
	var save: Dictionary = GameManager.get_save_data()
	GameManager.reset()
	GameManager.start_game(["qin", "zhao", "qi", "chu", "wei"], "qin")
	GameManager.load_save_data(save)
	assert_true(GameManager.has_special_victory("qin"), "存档应恢复特殊胜利")


func test_strategic_attack_blocked_without_war() -> void:
	# 生成两支不同势力单位
	var u1: Dictionary = StrategicMapManager.spawn_unit_at_city("qin", "infantry", 10, 10)
	var u2: Dictionary = StrategicMapManager.spawn_unit_at_city("zhao", "infantry", 11, 10)
	assert_true(bool(u1.get("success", false)), "秦单位应生成")
	assert_true(bool(u2.get("success", false)), "赵单位应生成")
	var result: Dictionary = StrategicMapManager.try_attack_unit(str(u1.get("unit_id", "")), str(u2.get("unit_id", "")))
	assert_false(bool(result.get("ok", false)))
	assert_eq(str(result.get("reason", "")), "NOT_AT_WAR")


func test_i18n_toggle_and_keys() -> void:
	assert_gt(I18n.get_key_count(), 10, "应加载词条表")
	assert_true(I18n.has_key("ui.diplomacy"))
	var before: String = I18n.get_locale()
	var after: String = I18n.toggle_locale()
	assert_ne(before, after, "切换应改变 locale")
	I18n.toggle_locale()
	assert_eq(I18n.get_locale(), before, "再切应还原")
