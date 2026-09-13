extends GutTest

## 奇观建造竞赛最小测试


func before_each() -> void:
	GameManager.reset()
	CityManager.reset()
	MinisterManager.reset()
	SchoolManager.reset()
	WonderManager.reset()
	TechSystem.reset()
	DiplomacySystem.reset()
	EventManager.set_muted(true)
	GameManager.start_game(["qin", "zhao"], "qin")


func _fund(faction_id: String) -> void:
	GameManager.apply_faction_resource_delta(faction_id, "gold", 5000)
	GameManager.apply_faction_resource_delta(faction_id, "wood", 3000)
	GameManager.apply_faction_resource_delta(faction_id, "building_materials", 500)


func test_start_build_deducts_and_completes() -> void:
	_fund("qin")
	var result: Dictionary = WonderManager.start_build_wonder("qin", "terracotta_army")
	assert_true(bool(result.get("success", false)), "应能开工，reason=%s" % str(result.get("reason", "")))
	assert_eq(WonderManager.get_build_projects().size(), 1, "应有在建项目")
	# 强制完工
	for i in 30:
		WonderManager.tick_build_projects("qin")
	assert_true(WonderManager.has_wonder("qin", "terracotta_army"), "完工后应获得奇观")
	assert_eq(WonderManager.get_build_projects().size(), 0, "完工后队列应清空")


func test_already_built_rejects_second_owner() -> void:
	_fund("qin")
	_fund("zhao")
	assert_true(bool(WonderManager.start_build_wonder("qin", "dujiangyan").get("success", false)))
	for i in 30:
		WonderManager.tick_build_projects("qin")
	assert_true(WonderManager.has_wonder("qin", "dujiangyan"))
	var zhao_try: Dictionary = WonderManager.start_build_wonder("zhao", "dujiangyan")
	assert_false(bool(zhao_try.get("success", true)), "已建成奇观不可再开工")
	assert_eq(str(zhao_try.get("reason", "")), "ALREADY_BUILT")


func test_insufficient_resources_rejected() -> void:
	var result: Dictionary = WonderManager.start_build_wonder("qin", "terracotta_army")
	assert_false(bool(result.get("success", true)), "资源不足应拒绝")
	assert_eq(str(result.get("reason", "")), "INSUFFICIENT_RESOURCES")
