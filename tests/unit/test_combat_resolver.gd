extends GutTest

## Phase 1 测试：伤害公式重构
## 验证加法层、克制、崩溃态、远程精度、动能、反击

const CombatLib := preload("res://scripts/systems/combat_resolver.gd")

var _combat: RefCounted
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func before_each() -> void:
	_combat = CombatLib.new()
	_rng.seed = 42


# ============= 攻击加法层 =============

func test_atk_buff_base_is_1_0() -> void:
	var buff: float = CombatLib._calc_atk_buff({})
	assert_eq(buff, 1.0, "空上下文 atk_buff 应为 1.0")

func test_atk_buff_terrain_offset() -> void:
	var buff: float = CombatLib._calc_atk_buff({"terrain_atk_offset": -0.1})
	assert_almost_eq(buff, 0.9, 0.01, "地形 atk_mod=0.9 → offset=-0.1 → buff=0.9")

func test_atk_buff_morale_offset() -> void:
	var buff: float = CombatLib._calc_atk_buff({"morale_atk_offset": 0.1})
	assert_almost_eq(buff, 1.1, 0.01, "高士气 +0.1 → buff=1.1")

func test_atk_buff_ambush_bonus() -> void:
	var buff: float = CombatLib._calc_atk_buff({"is_ambush": true, "ambush_bonus": 0.3})
	assert_almost_eq(buff, 1.3, 0.01, "伏击 +0.3 → buff=1.3")

func test_atk_buff_fire_bonus() -> void:
	var buff: float = CombatLib._calc_atk_buff({"is_fire_attack": true, "fire_bonus": 0.4})
	assert_almost_eq(buff, 1.4, 0.01, "火攻 +0.4 → buff=1.4")

func test_atk_buff_ambush_fire_exclusive() -> void:
	var ambush_only: float = CombatLib._calc_atk_buff({"is_ambush": true, "ambush_bonus": 0.3})
	var both: float = CombatLib._calc_atk_buff({"is_ambush": true, "is_fire_attack": true, "ambush_bonus": 0.3, "fire_bonus": 0.4})
	assert_almost_eq(both, ambush_only, 0.01, "伏击与火攻互斥时伏击优先")

func test_atk_buff_multiple_modifiers() -> void:
	var buff: float = CombatLib._calc_atk_buff({
		"terrain_atk_offset": -0.1,
		"morale_atk_offset": 0.1,
		"faction_atk": 0.05,
	})
	assert_almost_eq(buff, 1.05, 0.01, "地形-0.1 + 士气+0.1 + 派系+0.05 = 1.05")


# ============= 防御加法层 =============

func test_def_buff_base_is_1_0() -> void:
	var buff: float = CombatLib._calc_def_buff({})
	assert_eq(buff, 1.0, "空上下文 def_buff 应为 1.0")

func test_def_buff_terrain_offset() -> void:
	var buff: float = CombatLib._calc_def_buff({"terrain_def_offset": 0.2})
	assert_almost_eq(buff, 1.2, 0.01, "地形 def_mod=1.2 → offset=0.2 → buff=1.2")

func test_def_buff_combined() -> void:
	var buff: float = CombatLib._calc_def_buff({
		"terrain_def_offset": 0.1,
		"building_def": 0.15,
	})
	assert_almost_eq(buff, 1.25, 0.01, "地形+0.1 + 城墙+0.15 = 1.25")


# ============= 克制关系 =============

func test_counter_infantry_vs_cavalry() -> void:
	var m: float = _combat.compute_counter_multiplier("infantry", "cavalry")
	assert_eq(m, 0.8, "步兵对骑兵 0.8")

func test_counter_cavalry_vs_infantry() -> void:
	var m: float = _combat.compute_counter_multiplier("cavalry", "infantry")
	assert_eq(m, 1.3, "骑兵对步兵 1.3")

func test_counter_anti_cavalry_override() -> void:
	var m: float = _combat.compute_counter_multiplier("spear", "cavalry")
	assert_eq(m, 1.2, "枪刺兵对骑兵应使用 special_value=1.2，覆盖分类克制表")

func test_counter_anti_cavalry_vs_non_cavalry() -> void:
	var m: float = _combat.compute_counter_multiplier("spear", "infantry")
	assert_eq(m, 1.0, "枪刺兵对步兵走分类克制 1.0")


# ============= 崩溃态独立乘算 =============

func test_broken_morale_def_multiplier() -> void:
	var m: float = CombatLib.morale_defense_multiplier(15, 20)
	assert_eq(m, 0.5, "崩溃态防御 x0.5")

func test_normal_morale_def_multiplier() -> void:
	var m: float = CombatLib.morale_defense_multiplier(100, 20)
	assert_eq(m, 1.0, "正常士气防御 x1.0")


# ============= 远程精度修正 =============

func test_ranged_spread_no_ranged() -> void:
	var v: Vector2 = _combat.compute_ranged_spread(0.9, 1.1, "plains", false)
	assert_almost_eq(v.x, 0.9, 0.01, "非远程不受精度修正影响(lo)")
	assert_almost_eq(v.y, 1.1, 0.01, "非远程不受精度修正影响(hi)")

func test_ranged_spread_plains() -> void:
	var v: Vector2 = _combat.compute_ranged_spread(0.9, 1.1, "plains", true)
	assert_almost_eq(v.x, 0.9, 0.01, "平原精度 0，lo=0.9")
	assert_almost_eq(v.y, 1.1, 0.01, "平原精度 0，hi=1.1")

func test_ranged_spread_forest() -> void:
	var v: Vector2 = _combat.compute_ranged_spread(0.9, 1.1, "forest", true)
	assert_almost_eq(v.x, 0.88, 0.01, "森林精度 -20，lo=0.88")
	assert_almost_eq(v.y, 1.08, 0.01, "森林精度 -20，hi=1.08")

func test_ranged_spread_pass() -> void:
	var v: Vector2 = _combat.compute_ranged_spread(0.9, 1.1, "pass", true)
	assert_almost_eq(v.x, 0.915, 0.01, "关隘精度 +15，lo=0.915")
	assert_almost_eq(v.y, 1.115, 0.01, "关隘精度 +15，hi=1.115")


# ============= 动能攻击 =============

func test_momentum_zero_tiles() -> void:
	var b: float = _combat.get_momentum_bonus(0)
	assert_eq(b, 0.0, "移动 0 格无动能加成")

func test_momentum_three_tiles() -> void:
	var b: float = _combat.get_momentum_bonus(3)
	assert_almost_eq(b, 0.15, 0.01, "移动 3 格 +15%")

func test_momentum_cap() -> void:
	var b: float = _combat.get_momentum_bonus(10)
	assert_almost_eq(b, 0.25, 0.01, "移动 10 格封顶 +25%")


# ============= 远程判断 =============

func test_is_ranged_unit_archer() -> void:
	assert_true(_combat.is_ranged_unit("archer"), "archer 应为远程单位")

func test_is_ranged_unit_infantry() -> void:
	assert_false(_combat.is_ranged_unit("infantry"), "infantry 不应为远程单位")


# ============= 反击触发判断 =============

func test_counter_trigger_melee() -> void:
	assert_true(CombatLib.should_trigger_counter("infantry", false), "近战攻击应触发反击")

func test_counter_trigger_ranged_attack() -> void:
	assert_false(CombatLib.should_trigger_counter("archer", true), "远程主动攻击不应触发反击")


# ============= 士气攻击偏移 =============

func test_morale_offset_normal() -> void:
	var params: Dictionary = {"high_morale_threshold": 130, "low_morale_threshold": 50, "high_morale_atk_bonus": 0.1, "low_morale_atk_penalty": -0.1, "morale_break_threshold": 20}
	var offset: float = CombatLib._get_morale_atk_offset(80, params)
	assert_eq(offset, 0.0, "正常士气 80 无偏移")

func test_morale_offset_high() -> void:
	var params: Dictionary = {"high_morale_threshold": 130, "low_morale_threshold": 50, "high_morale_atk_bonus": 0.1, "low_morale_atk_penalty": -0.1, "morale_break_threshold": 20}
	var offset: float = CombatLib._get_morale_atk_offset(130, params)
	assert_almost_eq(offset, 0.1, 0.01, "高士气 130 → +0.1")

func test_morale_offset_low() -> void:
	var params: Dictionary = {"high_morale_threshold": 130, "low_morale_threshold": 50, "high_morale_atk_bonus": 0.1, "low_morale_atk_penalty": -0.1, "morale_break_threshold": 20}
	var offset: float = CombatLib._get_morale_atk_offset(30, params)
	assert_almost_eq(offset, -0.1, 0.01, "低士气 30 → -0.1")

func test_morale_offset_broken() -> void:
	var params: Dictionary = {"high_morale_threshold": 130, "low_morale_threshold": 50, "high_morale_atk_bonus": 0.1, "low_morale_atk_penalty": -0.1, "morale_break_threshold": 20}
	var offset: float = CombatLib._get_morale_atk_offset(15, params)
	assert_eq(offset, 0.0, "崩溃态不返回 offset（由独立乘算处理）")


# ============= 完整伤害计算集成 =============

func test_compute_damage_basic() -> void:
	var res: Dictionary = _combat.compute_damage(
		"infantry", "infantry", "plains", 100, 100, _rng,
	)
	assert_false(bool(res.get("skipped", false)))
	assert_true(int(res.get("damage", 0)) >= 1)

func test_compute_damage_with_context() -> void:
	var atk_ctx: Dictionary = {"faction_atk": 0.1}
	var def_ctx: Dictionary = {"building_def": 0.15}
	var res: Dictionary = _combat.compute_damage(
		"infantry", "infantry", "plains", 100, 100, _rng, atk_ctx, def_ctx,
	)
	assert_true(int(res.get("damage", 0)) >= 1)

func test_compute_damage_broken_morale_reduced() -> void:
	var rng2: RandomNumberGenerator = RandomNumberGenerator.new()
	rng2.seed = 42
	var normal: Dictionary = _combat.compute_damage(
		"infantry", "infantry", "plains", 100, 100, rng2,
	)
	rng2.seed = 42
	var broken: Dictionary = _combat.compute_damage(
		"infantry", "infantry", "plains", 15, 100, rng2,
	)
	assert_true(int(broken.get("damage", 0)) < int(normal.get("damage", 0)),
		"崩溃态伤害应低于正常态")

func test_compute_damage_high_morale_bonus() -> void:
	var rng2: RandomNumberGenerator = RandomNumberGenerator.new()
	rng2.seed = 42
	var normal: Dictionary = _combat.compute_damage(
		"infantry", "infantry", "plains", 100, 100, rng2,
	)
	rng2.seed = 42
	var high: Dictionary = _combat.compute_damage(
		"infantry", "infantry", "plains", 130, 100, rng2,
	)
	assert_true(int(high.get("damage", 0)) > int(normal.get("damage", 0)),
		"高士气伤害应高于正常态")

func test_compute_damage_terrain_defense() -> void:
	var rng2: RandomNumberGenerator = RandomNumberGenerator.new()
	rng2.seed = 42
	var plains: Dictionary = _combat.compute_damage(
		"infantry", "infantry", "plains", 100, 100, rng2,
	)
	rng2.seed = 42
	var mountain: Dictionary = _combat.compute_damage(
		"infantry", "infantry", "mountain", 100, 100, rng2,
	)
	assert_true(int(mountain.get("damage", 0)) <= int(plains.get("damage", 0)),
		"山地防御应使伤害不高于平原")

func test_compute_counter_attack() -> void:
	var res: Dictionary = _combat.compute_counter_attack(
		"infantry", "infantry", "plains", 100, 100, _rng,
	)
	assert_true(int(res.get("damage", 0)) >= 1, "反击伤害应 >= 1")
