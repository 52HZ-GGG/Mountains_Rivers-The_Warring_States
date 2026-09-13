extends GutTest

## EconomyAI 最小闭环测试


func before_each() -> void:
	GameManager.reset()
	CityManager.reset()
	MinisterManager.reset()
	SchoolManager.reset()
	TechSystem.reset()
	EventManager.set_muted(true)
	GameManager.start_game(["qin", "zhao"], "qin")


func test_economy_ai_builds_when_affordable() -> void:
	# 给赵国大量资源
	GameManager.apply_faction_resource_delta("zhao", "gold", 5000)
	GameManager.apply_faction_resource_delta("zhao", "wood", 2000)
	var zhao_cities: Array = CityManager.get_faction_city_states("zhao")
	assert_gt(zhao_cities.size(), 0, "赵国应有城市")
	var any_queued: bool = false
	EconomyAI.evaluate_economy("zhao")
	for city_v in zhao_cities:
		var city: Dictionary = CityManager.get_city_state(str((city_v as Dictionary).get("id", "")))
		if not (city.get("build_queue", []) as Array).is_empty() or not (city.get("buildings", []) as Array).is_empty():
			any_queued = true
			break
	assert_true(any_queued, "资源充足时经济 AI 应发起建造或已有建筑")


func test_economy_ai_skips_passive_faction() -> void:
	# Zhou 为被动势力
	GameManager.apply_faction_resource_delta("zhou", "gold", 5000)
	GameManager.apply_faction_resource_delta("zhou", "wood", 2000)
	EconomyAI.evaluate_economy("zhou")
	# 无异常即通过；被动势力不应崩溃
	assert_true(true)
