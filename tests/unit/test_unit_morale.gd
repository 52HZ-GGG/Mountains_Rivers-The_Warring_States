extends GutTest

## Sprint 2 测试：单位独立士气系统
## 验证士气初始化、击杀/阵亡事件、四段式效果、恢复、崩溃态

const CombatLib := preload("res://scripts/systems/combat_resolver.gd")

# ============= 纯函数测试（combat_resolver） =============

func test_low_morale_atk_offset_is_negative() -> void:
	var params: Dictionary = {
		"high_morale_threshold": 130,
		"low_morale_threshold": 50,
		"high_morale_atk_bonus": 0.1,
		"low_morale_atk_penalty": -0.1,
		"morale_break_threshold": 20,
	}
	var offset: float = CombatLib._get_morale_atk_offset(30, params)
	assert_almost_eq(offset, -0.1, 0.01, "低士气(30)攻击偏移应为 -0.1")


func test_high_morale_atk_offset_is_positive() -> void:
	var params: Dictionary = {
		"high_morale_threshold": 130,
		"low_morale_threshold": 50,
		"high_morale_atk_bonus": 0.1,
		"low_morale_atk_penalty": -0.1,
		"morale_break_threshold": 20,
	}
	var offset: float = CombatLib._get_morale_atk_offset(130, params)
	assert_almost_eq(offset, 0.1, 0.01, "高士气(130)攻击偏移应为 +0.1")


func test_normal_morale_atk_offset_is_zero() -> void:
	var params: Dictionary = {
		"high_morale_threshold": 130,
		"low_morale_threshold": 50,
		"high_morale_atk_bonus": 0.1,
		"low_morale_atk_penalty": -0.1,
		"morale_break_threshold": 20,
	}
	var offset: float = CombatLib._get_morale_atk_offset(80, params)
	assert_almost_eq(offset, 0.0, 0.01, "正常士气(80)攻击偏移应为 0.0")


func test_broken_morale_atk_offset_is_zero_for_additive() -> void:
	var params: Dictionary = {
		"high_morale_threshold": 130,
		"low_morale_threshold": 50,
		"high_morale_atk_bonus": 0.1,
		"low_morale_atk_penalty": -0.1,
		"morale_break_threshold": 20,
	}
	var offset: float = CombatLib._get_morale_atk_offset(15, params)
	assert_almost_eq(offset, 0.0, 0.01, "崩溃态(15)加法层偏移应为 0.0（乘算层独立处理）")


func test_broken_morale_defense_multiplier_is_half() -> void:
	var mult: float = CombatLib.morale_defense_multiplier(15, 20)
	assert_almost_eq(mult, 0.5, 0.01, "崩溃态(15)防御乘算应为 0.5")


func test_normal_morale_defense_multiplier_is_one() -> void:
	var mult: float = CombatLib.morale_defense_multiplier(80, 20)
	assert_almost_eq(mult, 1.0, 0.01, "正常士气(80)防御乘算应为 1.0")


# ============= 集成测试（TacticalSkirmishManager） =============

func before_each() -> void:
	TacticalSkirmishManager.reset_skirmish()


func test_units_spawn_with_base_morale() -> void:
	TacticalSkirmishManager.start_skirmish()
	var units: Array[Dictionary] = TacticalSkirmishManager.get_units()
	for u: Dictionary in units:
		assert_eq(int(u.get("morale", -1)), 100, "单位 %s 初始士气应为 100" % str(u["id"]))


func test_kill_increases_attacker_morale() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	assert_false(p1.is_empty(), "玩家单位 mvp_p1 应存在")
	assert_false(e1.is_empty(), "敌方单位 mvp_e1 应存在")
	e1["hp"] = 1
	e1["q"] = int(p1["q"]) + 1
	e1["r"] = int(p1["r"])
	var morale_before: int = int(p1.get("morale", 100))
	TacticalSkirmishManager.try_player_attack("mvp_p1", "mvp_e1")
	var p1_after: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	assert_eq(int(p1_after.get("morale", 0)), morale_before + 15, "击杀后攻击者士气应 +15")


func test_ally_kill_boosts_faction_morale() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	var p2: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p2")
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	assert_false(p2.is_empty(), "玩家单位 mvp_p2 应存在")
	e1["hp"] = 1
	e1["q"] = int(p1["q"]) + 1
	e1["r"] = int(p1["r"])
	var p2_morale_before: int = int(p2.get("morale", 100))
	TacticalSkirmishManager.try_player_attack("mvp_p1", "mvp_e1")
	var p2_after: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p2")
	assert_eq(int(p2_after.get("morale", 0)), p2_morale_before + 5, "友军击杀后 p2 士气应 +5")


func test_morale_recovery_per_turn() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	p1["morale"] = 80
	TacticalSkirmishManager.process_morale_for_test()
	var p1_after: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	assert_eq(int(p1_after.get("morale", 0)), 83, "野外士气恢复 +3/回合")


func test_morale_recovery_in_city() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	# 将 p1 移到己方城市
	var player_city: Vector2i = TacticalSkirmishManager.get_player_city()
	p1["q"] = player_city.x
	p1["r"] = player_city.y
	p1["morale"] = 80
	TacticalSkirmishManager.process_morale_for_test()
	var p1_after: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	assert_eq(int(p1_after.get("morale", 0)), 88, "城中士气恢复 +8/回合")


func test_high_morale_decays_to_cap() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	p1["morale"] = 120
	TacticalSkirmishManager.process_morale_for_test()
	var p1_after: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	assert_eq(int(p1_after.get("morale", 0)), 119, "高士气(120)每回合 -1 衰减")


func test_broken_morale_loses_hp() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	p1["morale"] = 15
	var max_hp: int = int(p1.get("max_hp", 100))
	p1["hp"] = max_hp
	var expected_hp: int = max_hp - int(float(max_hp) * 0.2)
	TacticalSkirmishManager.process_morale_for_test()
	var p1_after: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	assert_eq(int(p1_after.get("hp", 0)), expected_hp, "崩溃态每回合 HP -20%")


func test_broken_morale_reduces_speed() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	p1["morale"] = 15
	var base_speed: int = int(p1.get("speed", 3))
	var expected_speed: int = maxi(1, int(float(base_speed) * 0.5))
	TacticalSkirmishManager.process_morale_for_test()
	var p1_after: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	assert_eq(int(p1_after.get("mp_remaining", 0)), expected_speed, "崩溃态速度 ×0.5")
