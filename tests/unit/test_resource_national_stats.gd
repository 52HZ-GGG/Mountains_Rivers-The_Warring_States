extends GutTest

## 资源系统：全国人口汇总、开局资源不顶 cap、兵源池、征兵单账


func before_each() -> void:
	GameManager.reset()
	CityManager.reset()
	EventManager.set_muted(true)
	GameManager.start_game(["qin", "zhao"], "qin")


func test_national_population_is_sum_of_cities() -> void:
	var cities: Array = CityManager.get_faction_city_states("qin")
	var expected: int = 0
	for c in cities:
		expected += int((c as Dictionary).get("current_population", 0))
	assert_gt(expected, 0)
	assert_eq(GameManager.get_player_population(), expected, "顶栏人口应为各城人口之和")


func test_starting_gold_not_at_cap() -> void:
	var gold: int = GameManager.get_player_gold()
	var cap: int = GameManager.get_resource_cap("gold", "qin")
	assert_gt(gold, 0, "开局应有金")
	assert_lt(gold, cap, "开局金不应顶满上限 gold=%d cap=%d" % [gold, cap])


func test_starting_troops_and_conscription_pool() -> void:
	assert_gt(GameManager.get_player_troops(), 0, "开局应有驻军编制")
	assert_gt(GameManager.get_player_conscription_pool(), 0, "开局全国可服役池应预填")


func test_national_conscription_formula() -> void:
	# 机制文档 §6.1：max = 全国人口×20%；可服役+已服役≤max
	var pop: int = GameManager.get_player_population()
	var mx: int = GameManager.get_max_conscription("qin")
	var avail: int = GameManager.get_available_conscription("qin")
	var active: int = GameManager.get_total_troops("qin")
	assert_eq(mx, int(pop * 0.2), "最大征召=全国人口×20%")
	assert_true(avail + active <= mx, "可服役+已服役≤最大征召 avail=%d active=%d mx=%d" % [avail, active, mx])


func test_recruit_consumes_national_pool_not_city_pop() -> void:
	# 决策 #94：只扣可服役池与资源，不扣城人口
	var city: Dictionary = (CityManager.get_faction_cities("qin")[0] as Dictionary)
	var city_id: String = str(city.get("id", ""))
	var unlocks: Array[String] = CityManager.get_recruitable_units(city_id)
	if unlocks.is_empty():
		pass_test("无解锁兵种")
		return
	var mx: int = GameManager.get_max_conscription("qin")
	var active: int = GameManager.get_total_troops("qin")
	GameManager._national_conscription["qin"] = maxi(2, mx - active)
	CityManager.get_city_state(city_id)["current_population"] = 20
	var pop_before: int = GameManager.get_player_population()
	var city_pop_before: int = int(CityManager.get_city_state(city_id).get("current_population", 0))
	var avail_before: int = GameManager.get_available_conscription("qin")
	# 保证有资源
	GameManager.apply_gold_delta(500)
	GameManager.apply_food_delta(200)
	var res: Dictionary = GameManager.recruit_unit_from_city(city_id, unlocks[0], 1)
	assert_true(bool(res.get("success", false)), "应能征兵：%s" % str(res))
	var n: int = int(res.get("recruited", 0))
	assert_eq(GameManager.get_available_conscription("qin"), avail_before - n, "应扣全国可服役池")
	assert_eq(int(CityManager.get_city_state(city_id).get("current_population", 0)), city_pop_before, "决策#94：不扣城人口")
	assert_eq(GameManager.get_player_population(), pop_before, "全国人口不因征兵减少")


func test_recruit_blocked_when_national_pool_empty() -> void:
	var city: Dictionary = (CityManager.get_faction_cities("qin")[0] as Dictionary)
	var city_id: String = str(city.get("id", ""))
	var unlocks: Array[String] = CityManager.get_recruitable_units(city_id)
	if unlocks.is_empty():
		pass_test("无解锁兵种")
		return
	GameManager._national_conscription["qin"] = 0
	CityManager.get_city_state(city_id)["current_population"] = 50
	var res: Dictionary = GameManager.recruit_unit_from_city(city_id, unlocks[0], 1)
	assert_false(bool(res.get("success", false)), "全国池为 0 时不可征兵")
	assert_eq(str(res.get("reason", "")), "POOL_EMPTY")


func test_conscription_progress_api() -> void:
	var ratio: float = GameManager.get_conscription_progress_ratio("qin")
	assert_true(ratio >= 0.0 and ratio <= 1.0)
	var mx: int = GameManager.get_max_conscription("qin")
	assert_true(mx >= 0)
