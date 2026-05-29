extends GutTest

## 战斗修正值连接测试
## 验证科技/学派加成通过 context 正确传入 combat_resolver 并影响伤害

const CombatLib := preload("res://scripts/systems/combat_resolver.gd")

var _combat: RefCounted
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func before_each() -> void:
	_combat = CombatLib.new()
	_rng.seed = 42


# ============= 科技加成测试 =============

func test_tech_attack_bonus_increases_damage() -> void:
	var base: Dictionary = _combat.compute_damage("infantry", "infantry", "plains", 100, 100, _rng, {}, {})
	var with_tech: Dictionary = _combat.compute_damage("infantry", "infantry", "plains", 100, 100, _rng, {"tech_atk": 0.1}, {})
	assert_gt(int(with_tech["damage"]), int(base["damage"]), "科技攻击 +10%% 应增加伤害（%d → %d）" % [int(base["damage"]), int(with_tech["damage"])])


func test_tech_defense_bonus_decreases_damage() -> void:
	# 使用克制关系（骑兵 vs 步兵 1.3x）+ 更大防御差确保效果可见
	var base: Dictionary = _combat.compute_damage("cavalry", "infantry", "plains", 100, 100, _rng, {}, {})
	var rng2: RandomNumberGenerator = RandomNumberGenerator.new()
	rng2.seed = 42
	var with_tech: Dictionary = _combat.compute_damage("cavalry", "infantry", "plains", 100, 100, rng2, {}, {"tech_def": 0.3})
	assert_gt(int(base["damage"]), 1, "基础伤害应 > 1（实际 %d）" % int(base["damage"]))
	assert_lt(int(with_tech["damage"]), int(base["damage"]), "科技防御 +30%% 应减少伤害（%d → %d）" % [int(base["damage"]), int(with_tech["damage"])])


func test_tech_attack_bonus_value_accuracy() -> void:
	var buff: float = CombatLib._calc_atk_buff({"tech_atk": 0.15})
	assert_almost_eq(buff, 1.15, 0.01, "tech_atk=0.15 应使 atk_buff = 1.15")


func test_tech_defense_bonus_value_accuracy() -> void:
	var buff: float = CombatLib._calc_def_buff({"tech_def": 0.2})
	assert_almost_eq(buff, 1.2, 0.01, "tech_def=0.2 应使 def_buff = 1.2")


# ============= 学派加成测试 =============

func test_school_defense_bonus_increases_def_buff() -> void:
	var buff: float = CombatLib._calc_def_buff({"school_def": 0.25})
	assert_almost_eq(buff, 1.25, 0.01, "墨家 def_combat_bonus=0.25 应使 def_buff = 1.25")


func test_school_defense_bonus_reduces_damage() -> void:
	var base: Dictionary = _combat.compute_damage("cavalry", "infantry", "plains", 100, 100, _rng, {}, {})
	var with_school: Dictionary = _combat.compute_damage("cavalry", "infantry", "plains", 100, 100, _rng, {}, {"school_def": 0.25})
	assert_gt(int(base["damage"]), 1, "基础伤害应 > 1")
	assert_lt(int(with_school["damage"]), int(base["damage"]), "学派防御 +25%% 应减少伤害（%d → %d）" % [int(base["damage"]), int(with_school["damage"])])


# ============= 多重加成叠加测试 =============

func test_multiple_modifiers_stack() -> void:
	# 验证攻防加成分别正确叠加
	var atk_buff: float = CombatLib._calc_atk_buff({"tech_atk": 0.1})
	var def_buff: float = CombatLib._calc_def_buff({"tech_def": 0.1, "school_def": 0.25})
	assert_almost_eq(atk_buff, 1.1, 0.01, "tech_atk=0.1 → atk_buff=1.1")
	assert_almost_eq(def_buff, 1.35, 0.01, "tech_def=0.1 + school_def=0.25 → def_buff=1.35")


func test_modifiers_with_terrain() -> void:
	var terrain_only: Dictionary = _combat.compute_damage("infantry", "infantry", "forest", 100, 100, _rng, {}, {})
	var terrain_plus_tech: Dictionary = _combat.compute_damage("infantry", "infantry", "forest", 100, 100, _rng, {"tech_atk": 0.1}, {})
	assert_gt(int(terrain_plus_tech["damage"]), int(terrain_only["damage"]), "森林地形下科技攻击加成仍应生效")


# ============= 学派数据加载测试 =============

func test_school_data_loaded() -> void:
	var school: Dictionary = DataManager.get_school("mohism")
	assert_false(school.is_empty(), "墨家学派数据应已加载")
	assert_eq(str(school.get("id", "")), "mohism", "学派 id 应为 mohism")


func test_school_global_effects_accessible() -> void:
	var school: Dictionary = DataManager.get_school("mohism")
	var lv2: Dictionary = school.get("level_effects", {}).get("2", {})
	var effects: Dictionary = lv2.get("effects", {})
	var def_bonus: float = float(effects.get("defense_bonus", 0.0))
	assert_almost_eq(def_bonus, 0.25, 0.01, "墨家 level2 defense_bonus 应为 0.25")


func test_all_schools_loaded() -> void:
	var schools: Array = DataManager.get_all_schools()
	assert_gt(schools.size(), 0, "应加载至少 1 个学派")


func test_nonexistent_school_returns_empty() -> void:
	var school: Dictionary = DataManager.get_school("nonexistent_school")
	assert_true(school.is_empty(), "不存在的学派应返回空字典")
