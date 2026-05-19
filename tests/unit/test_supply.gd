extends GutTest

## 补给与断粮系统单元测试
## 验证 BFS 连通性检测、断粮效果（士气/HP 损失）

func before_each() -> void:
	TacticalSkirmishManager.reset_skirmish()


# ============= 补给连通性测试 =============

func test_unit_near_city_is_supplied() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	assert_false(p1.is_empty(), "mvp_p1 应存在")
	var supplied: bool = TacticalSkirmishManager._check_supply(p1)
	assert_true(supplied, "玩家城市附近的单位应有补给")


func test_unit_on_city_is_supplied() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	var player_city: Vector2i = TacticalSkirmishManager.get_player_city()
	p1["q"] = player_city.x
	p1["r"] = player_city.y
	var supplied: bool = TacticalSkirmishManager._check_supply(p1)
	assert_true(supplied, "在城市上的单位应有补给")


func test_unit_far_away_is_cut_off() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	p1["q"] = 99
	p1["r"] = 99
	var supplied: bool = TacticalSkirmishManager._check_supply(p1)
	assert_false(supplied, "地图外的单位应被切断补给")


func test_enemy_faction_also_tracked() -> void:
	TacticalSkirmishManager.start_skirmish()
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	assert_false(e1.is_empty(), "mvp_e1 应存在")
	var supplied: bool = TacticalSkirmishManager._check_supply(e1)
	assert_true(supplied, "敌方城市附近的单位应有补给")


# ============= 断粮效果测试 =============

func test_supply_effects_morale_loss() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	p1["q"] = 99
	p1["r"] = 99
	var morale_before: int = int(p1.get("morale", 100))
	TacticalSkirmishManager._process_supply_effects("qin")
	var morale_after: int = int(p1.get("morale", 100))
	assert_eq(morale_after, morale_before - 10, "断粮应使士气 -10（%d → %d）" % [morale_before, morale_after])


func test_supply_effects_hp_loss() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	p1["q"] = 99
	p1["r"] = 99
	var hp_before: int = int(p1["hp"])
	var max_hp: int = int(p1["max_hp"])
	TacticalSkirmishManager._process_supply_effects("qin")
	var hp_after: int = int(p1["hp"])
	var expected_loss: int = maxi(1, int(float(max_hp) * 0.05))
	assert_eq(hp_after, hp_before - expected_loss, "断粮应扣 %d HP（%d → %d）" % [expected_loss, hp_before, hp_after])


func test_supplied_unit_no_effect() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	var morale_before: int = int(p1.get("morale", 100))
	var hp_before: int = int(p1["hp"])
	TacticalSkirmishManager._process_supply_effects("qin")
	assert_eq(int(p1.get("morale", 100)), morale_before, "有补给时不应损失士气")
	assert_eq(int(p1["hp"]), hp_before, "有补给时不应损失 HP")
	assert_true(bool(p1.get("is_supplied", false)), "有补给时 is_supplied 应为 true")


func test_cut_off_unit_marked_unsupplied() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	p1["q"] = 99
	p1["r"] = 99
	TacticalSkirmishManager._process_supply_effects("qin")
	assert_false(bool(p1.get("is_supplied", true)), "断粮时 is_supplied 应为 false")


func test_supply_effects_can_kill() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	p1["q"] = 99
	p1["r"] = 99
	p1["hp"] = 1
	TacticalSkirmishManager._process_supply_effects("qin")
	var p1_after: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	assert_true(p1_after.is_empty(), "断粮致死的单位应被移除")


func test_enemy_supply_effects() -> void:
	TacticalSkirmishManager.start_skirmish()
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	e1["q"] = 99
	e1["r"] = 99
	var morale_before: int = int(e1.get("morale", 100))
	TacticalSkirmishManager._process_supply_effects("zhao")
	assert_true(int(e1.get("morale", 100)) < morale_before, "敌方断粮也应损失士气")


func test_supply_two_adjacent_deaths() -> void:
	# 验证：两个单位同时因断粮致死时都能被正确移除（迭代安全）
	TacticalSkirmishManager.start_skirmish()
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	var e2: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e2")
	e1["q"] = 99
	e1["r"] = 99
	e1["hp"] = 1
	e2["q"] = 100
	e2["r"] = 100
	e2["hp"] = 1
	TacticalSkirmishManager._process_supply_effects("zhao")
	assert_true(TacticalSkirmishManager.get_unit_by_id("mvp_e1").is_empty(), "e1 应因断粮致死")
	assert_true(TacticalSkirmishManager.get_unit_by_id("mvp_e2").is_empty(), "e2 应因断粮致死")
