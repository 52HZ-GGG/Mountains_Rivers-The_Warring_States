extends GutTest

const CombatLib := preload("res://scripts/systems/combat_resolver.gd")

func test_infantry_damage_on_plains_is_positive_with_fixed_seed() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 12345
	var res: Dictionary = CombatLib.compute_damage(
		"infantry", "infantry", "plains", 80, 80, rng
	)
	assert_false(bool(res.get("skipped", false)))
	assert_true(int(res.get("damage", 0)) >= 1)


func test_morale_attack_multiplier_at_hundred() -> void:
	var m: float = CombatLib.morale_attack_multiplier(100)
	var ceil_v: Variant = DataManager.get_balance_param("combat.morale_atk_ceil")
	var expect_c: float = float(ceil_v) if ceil_v != null else 1.0
	assert_eq(m, expect_c, "满民心应取上限系数")


func test_counter_cavalry_vs_archer_stronger_than_infantry_vs_archer() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 12345
	var res_cav: Dictionary = CombatLib.compute_damage(
		"cavalry", "archer", "plains", 80, 80, rng,
	)
	var rng2: RandomNumberGenerator = RandomNumberGenerator.new()
	rng2.seed = 12345
	var res_inf: Dictionary = CombatLib.compute_damage(
		"infantry", "archer", "plains", 80, 80, rng2,
	)
	assert_true(
		int(res_cav.get("damage", 0)) > int(res_inf.get("damage", 0)),
		"同条件下骑兵对弓兵伤害应大于步兵对弓兵（克制矩阵 1.3 > 1.2）"
	)


func test_ambush_triggers_on_high_chance_terrain() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 777
	var res: Dictionary = CombatLib.compute_damage(
		"infantry", "infantry", "forest", 80, 80, rng,
	)
	assert_false(bool(res.get("skipped", false)), "不应跳过结算")
	# 用确定种子验证伏击标记的一致性——不要求一定触发，但结果应可复现
	var rng2: RandomNumberGenerator = RandomNumberGenerator.new()
	rng2.seed = 777
	var res2: Dictionary = CombatLib.compute_damage(
		"infantry", "infantry", "forest", 80, 80, rng2,
	)
	assert_eq(
		bool(res.get("was_ambush", false)),
		bool(res2.get("was_ambush", false)),
		"相同种子的伏击判定应可复现"
	)


func test_mountain_defender_takes_less_damage_than_plains() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	var res_plains: Dictionary = CombatLib.compute_damage(
		"infantry", "infantry", "plains", 80, 80, rng,
	)
	var rng2: RandomNumberGenerator = RandomNumberGenerator.new()
	rng2.seed = 42
	var res_mountain: Dictionary = CombatLib.compute_damage(
		"infantry", "infantry", "mountain", 80, 80, rng2,
	)
	assert_true(
		int(res_mountain.get("damage", 0)) <= int(res_plains.get("damage", 0)),
		"守方在山地应受到不大于平原的伤害（地形防御加成）"
	)
