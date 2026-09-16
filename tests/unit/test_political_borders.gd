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


func test_are_bordering_uses_empty_guard() -> void:
	assert_false(DiplomacySystem.are_bordering("", "qin"))
	assert_false(DiplomacySystem.are_bordering("qin", "qin"))


func test_are_bordering_reflects_runtime_ownership() -> void:
	# 开局：秦赵应接壤（数据上邻近）
	var before: bool = DiplomacySystem.are_bordering("qin", "zhao")
	if before:
		# 把秦全部城给齐，秦应不再与赵接壤
		var qin_cities: Array = CityManager.get_faction_cities("qin").duplicate()
		for city in qin_cities:
			CityManager.occupy_city(str(city.get("id", "")), "qi")
		assert_false(
			DiplomacySystem.are_bordering("qin", "zhao"),
			"秦失城后不应再与赵接壤"
		)
		assert_true(
			DiplomacySystem.are_bordering("qi", "zhao"),
			"齐接管秦城后应与赵接壤"
		)
	else:
		# 若开局本就不接壤：只占赵一座城给秦，赵仍保有其他城
		var zhao_cities: Array = CityManager.get_faction_cities("zhao").duplicate()
		assert_gt(zhao_cities.size(), 1, "赵应有多城，便于部分占领")
		CityManager.occupy_city(str((zhao_cities[0] as Dictionary).get("id", "")), "qin")
		assert_false(CityManager.is_faction_eliminated("zhao"), "赵不应被灭国")
		assert_true(
			DiplomacySystem.are_bordering("qin", "zhao"),
			"秦占赵一城后应接壤"
		)


func test_border_changed_signal_exists() -> void:
	assert_true(SignalBus.has_signal("border_changed"))
