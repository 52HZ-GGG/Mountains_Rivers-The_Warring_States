extends GutTest

## 治疗/回复单元测试
## 验证脱战回复、战斗标记、敌军干扰、崩溃态禁止、位置加成、上限

func before_each() -> void:
	TacticalSkirmishManager.reset_skirmish()


# ============= 基础治疗测试 =============

func test_heal_out_of_combat() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	# 设置 HP 受伤，高士气，非战斗
	p1["hp"] = 50
	p1["morale"] = 100
	p1["in_combat_this_turn"] = false
	# 移走敌军避免干扰
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	e1["q"] = 10
	e1["r"] = 10
	var e2: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e2")
	e2["q"] = 10
	e2["r"] = 11
	TacticalSkirmishManager.process_morale_for_test()
	assert_true(int(p1["hp"]) > 50, "脱战单位应恢复 HP（50 → %d）" % int(p1["hp"]))


func test_no_heal_in_combat() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	p1["hp"] = 50
	p1["morale"] = 100
	p1["in_combat_this_turn"] = true  # 本回合参与战斗
	# 移走敌军
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	e1["q"] = 10
	e1["r"] = 10
	var e2: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e2")
	e2["q"] = 10
	e2["r"] = 11
	TacticalSkirmishManager.process_morale_for_test()
	assert_eq(int(p1["hp"]), 50, "战斗中的单位不应恢复 HP")


func test_no_heal_when_adjacent_enemy() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	p1["q"] = 3
	p1["r"] = 3
	p1["hp"] = 50
	p1["morale"] = 100
	p1["in_combat_this_turn"] = false
	# 敌军在旁边
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	e1["q"] = 4
	e1["r"] = 3
	e1["morale"] = 100
	# 移走第二个敌军
	var e2: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e2")
	e2["q"] = 10
	e2["r"] = 10
	# 移走友军弓兵避免干扰
	var p2: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p2")
	p2["q"] = -10
	p2["r"] = -10
	TacticalSkirmishManager.process_morale_for_test()
	assert_eq(int(p1["hp"]), 50, "旁边有敌军时不应恢复 HP")


func test_no_heal_when_morale_broken() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	p1["hp"] = 50
	p1["morale"] = 10  # 崩溃态
	p1["in_combat_this_turn"] = false
	# 移走敌军
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	e1["q"] = 10
	e1["r"] = 10
	var e2: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e2")
	e2["q"] = 10
	e2["r"] = 11
	var hp_before: int = int(p1["hp"])
	TacticalSkirmishManager.process_morale_for_test()
	# 崩溃态不回复（还可能因崩溃扣 HP）
	assert_true(int(p1["hp"]) <= hp_before, "崩溃态不应恢复 HP（前=%d，后=%d）" % [hp_before, int(p1["hp"])])


func test_heal_capped_at_max_hp() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	var max_hp: int = int(p1.get("max_hp", 100))
	# HP 只差 3 点就满
	p1["hp"] = max_hp - 3
	p1["morale"] = 100
	p1["in_combat_this_turn"] = false
	# 移走敌军
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	e1["q"] = 10
	e1["r"] = 10
	var e2: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e2")
	e2["q"] = 10
	e2["r"] = 11
	TacticalSkirmishManager.process_morale_for_test()
	assert_eq(int(p1["hp"]), max_hp, "治疗不应超过 max_hp（期望 %d，实际 %d）" % [max_hp, int(p1["hp"])])


# ============= 位置加成测试 =============

func test_heal_inside_city() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	var city: Vector2i = TacticalSkirmishManager.get_player_city()
	# 放到友方城市上
	p1["q"] = city.x
	p1["r"] = city.y
	p1["hp"] = 50
	p1["morale"] = 100
	p1["in_combat_this_turn"] = false
	# 移走敌军
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	e1["q"] = 10
	e1["r"] = 10
	var e2: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e2")
	e2["q"] = 10
	e2["r"] = 11
	# 移走弓兵
	var p2: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p2")
	p2["q"] = -10
	p2["r"] = -10
	TacticalSkirmishManager.process_morale_for_test()
	assert_eq(int(p1["hp"]), 70, "城内应恢复 20 HP（50 → 70），实际: %d" % int(p1["hp"]))


func test_heal_outskirts() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	# 放到远离城市的开阔位置（轴向 (3,0)，距玩家城市 (-1,3) 距离 4）
	p1["q"] = 3
	p1["r"] = 0
	p1["hp"] = 50
	p1["morale"] = 100
	p1["in_combat_this_turn"] = false
	# 确认不在城市或城市区域
	var city: Vector2i = TacticalSkirmishManager.get_player_city()
	var dist_to_city: int = HexAxial.hex_distance_hex(Vector2i(3, 0), city)
	assert_true(dist_to_city > 2, "测试位置应远离城市（距离 %d）" % dist_to_city)
	# 移走敌军
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	e1["q"] = 10
	e1["r"] = 10
	var e2: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e2")
	e2["q"] = 10
	e2["r"] = 11
	# 移走弓兵
	var p2: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p2")
	p2["q"] = -10
	p2["r"] = -10
	TacticalSkirmishManager.process_morale_for_test()
	assert_eq(int(p1["hp"]), 60, "野外应恢复 10 HP（50 → 60），实际: %d" % int(p1["hp"]))


# ============= 战斗标记重置测试 =============

func test_combat_flag_resets_each_turn() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	p1["hp"] = 50
	p1["morale"] = 100
	p1["in_combat_this_turn"] = true  # 本回合战斗过
	# 移走敌军
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	e1["q"] = 10
	e1["r"] = 10
	var e2: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e2")
	e2["q"] = 10
	e2["r"] = 11
	# 第一轮：战斗标记为 true，不应治疗
	TacticalSkirmishManager.process_morale_for_test()
	assert_eq(int(p1["hp"]), 50, "战斗标记为 true 时不应治疗")
	# 模拟回合切换：手动重置标记（真实流程中 begin_player_phase 会重置）
	p1["in_combat_this_turn"] = false
	# 第二轮：标记已重置，应治疗
	p1["hp"] = 50
	TacticalSkirmishManager.process_morale_for_test()
	assert_true(int(p1["hp"]) > 50, "标记重置后应恢复 HP（50 → %d）" % int(p1["hp"]))
