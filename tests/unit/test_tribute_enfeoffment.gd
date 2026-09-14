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


func test_send_tribute_costs_gold_and_raises_tribute() -> void:
	GameManager.apply_gold_delta(200)
	var tribute_before: int = DiplomacySystem.get_tribute("qin")
	var rep_before: int = DiplomacySystem.get_reputation("qin")
	var result: Dictionary = DiplomacySystem.send_tribute("qin", "small")
	assert_true(bool(result.get("success", false)), "reason=%s" % str(result.get("reason", "")))
	assert_gt(DiplomacySystem.get_tribute("qin"), tribute_before, "小朝贡应提升朝贡度")
	assert_true(DiplomacySystem.get_reputation("qin") >= rep_before, "小朝贡应不降声望")
	assert_true(DiplomacySystem.is_tribute_on_cooldown("qin", "small"), "朝贡后应进入冷却")


func test_tribute_cooldown_blocks_repeat() -> void:
	GameManager.apply_gold_delta(500)
	assert_true(bool(DiplomacySystem.send_tribute("qin", "small").get("success", false)))
	var again: Dictionary = DiplomacySystem.send_tribute("qin", "small")
	assert_false(bool(again.get("success", false)))
	assert_eq(str(again.get("reason", "")), "cooldown")


func test_enfeoffment_requires_tribute_and_once() -> void:
	# 朝贡度不足
	var fail: Dictionary = DiplomacySystem.request_enfeoffment("qin", "vassal")
	assert_false(bool(fail.get("success", false)))
	assert_eq(str(fail.get("reason", "")), "tribute_too_low")

	DiplomacySystem.set_tribute("qin", 50)
	# 声望不足会失败并扣朝贡
	DiplomacySystem._change_reputation("qin", -20)
	var low_rep: Dictionary = DiplomacySystem.request_enfeoffment("qin", "vassal")
	# 声望可能仍 >=40（初始50-20=30），若失败应为 reputation_too_low
	if not bool(low_rep.get("success", false)):
		assert_eq(str(low_rep.get("reason", "")), "reputation_too_low")

	# 确保声望够
	DiplomacySystem._change_reputation("qin", 50)
	DiplomacySystem.set_tribute("qin", 50)
	var ok: Dictionary = DiplomacySystem.request_enfeoffment("qin", "vassal")
	assert_true(bool(ok.get("success", false)), "reason=%s" % str(ok.get("reason", "")))
	assert_true(DiplomacySystem.has_enfeoffment("qin", "vassal"))
	var again: Dictionary = DiplomacySystem.request_enfeoffment("qin", "vassal")
	assert_false(bool(again.get("success", false)), "每种册封每局一次")
	assert_eq(str(again.get("reason", "")), "already_enfeoffed")


func test_hegemon_enfeoffment_applies_global_opinion() -> void:
	DiplomacySystem.set_tribute("qin", 90)
	DiplomacySystem._change_reputation("qin", 50)
	var op_before: int = DiplomacySystem.get_opinion("zhao", "qin")
	var result: Dictionary = DiplomacySystem.request_enfeoffment("qin", "hegemon")
	assert_true(bool(result.get("success", false)), "reason=%s" % str(result.get("reason", "")))
	assert_true(DiplomacySystem.get_opinion("zhao", "qin") >= op_before, "霸主应对他国好感不降")
	var effects: Dictionary = DiplomacySystem.get_enfeoffment_effects("qin")
	assert_gt(float(effects.get("alliance_cost_reduction", 0.0)), 0.0)


func test_regional_lord_reduces_war_reputation_penalty() -> void:
	DiplomacySystem.set_tribute("qin", 70)
	DiplomacySystem._change_reputation("qin", 50)
	assert_true(bool(DiplomacySystem.request_enfeoffment("qin", "regional_lord").get("success", false)))
	var base: int = -20
	var adjusted: int = DiplomacySystem.get_war_reputation_penalty("qin", base)
	assert_gt(adjusted, base, "方伯册封应减轻宣战声望惩罚")


func test_attack_zhou_applies_heavy_penalty() -> void:
	var tribute_before: int = DiplomacySystem.get_tribute("qin")
	DiplomacySystem.apply_attack_zhou_penalty("qin")
	assert_lt(DiplomacySystem.get_tribute("qin"), tribute_before, "攻周应大降朝贡度")


func test_building_diplomacy_reputation_bonus() -> void:
	# 手动塞一座王宫
	var cities: Array = CityManager.get_faction_cities("qin")
	assert_false(cities.is_empty())
	var city_id: String = str(cities[0].get("id", ""))
	var state: Dictionary = CityManager.get_city_state(city_id)
	state["buildings"] = [{"building_id": "palace", "level": 1}]
	DiplomacySystem._apply_building_diplomacy_effects()
	assert_gt(DiplomacySystem.get_building_diplomacy_reputation_bonus("qin"), 0, "王宫应提供外交声望加成")


func test_tribute_enfeoffment_save_round_trip() -> void:
	GameManager.apply_gold_delta(300)
	DiplomacySystem.send_tribute("qin", "small")
	DiplomacySystem.set_tribute("qin", 50)
	DiplomacySystem._change_reputation("qin", 50)
	DiplomacySystem.request_enfeoffment("qin", "vassal")
	var save: Dictionary = DiplomacySystem.get_save_data()
	DiplomacySystem.reset()
	DiplomacySystem.load_save_data(save)
	assert_true(DiplomacySystem.has_enfeoffment("qin", "vassal"), "存档应恢复册封")
	assert_true(DiplomacySystem.is_tribute_on_cooldown("qin", "small"), "存档应恢复冷却")
