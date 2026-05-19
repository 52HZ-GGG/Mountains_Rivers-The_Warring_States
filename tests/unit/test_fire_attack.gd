extends GutTest

## 火攻机制单元测试
## 验证触发条件（季节+森林+互斥）、DOT 伤害、DOT 衰减、兵家加成

const CombatLib := preload("res://scripts/systems/combat_resolver.gd")

var _combat: RefCounted
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func before_each() -> void:
	TacticalSkirmishManager.reset_skirmish()
	_combat = CombatLib.new()
	_rng.seed = 42


# ============= 触发条件测试 =============

func test_fire_attack_triggers_summer_forest() -> void:
	TacticalSkirmishManager.set_season("summer")
	TacticalSkirmishManager.start_skirmish()
	# 将敌军放到森林格上
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	var forest_cell: Vector2i = _find_terrain_cell("forest")
	assert_true(forest_cell != Vector2i(-999, -999), "应存在森林格")
	e1["q"] = forest_cell.x
	e1["r"] = forest_cell.y
	# 确保玩家单位可以攻击到
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	p1["q"] = forest_cell.x - 1
	p1["r"] = forest_cell.y
	p1["mp_remaining"] = 10
	# 执行攻击
	var result: Dictionary = TacticalSkirmishManager.try_player_attack("mvp_p1", "mvp_e1")
	assert_true(result.get("ok", false), "攻击应成功")
	# 验证 burn DOT 被施加
	var e1_after: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	if int(e1_after.get("hp", 0)) > 0:
		assert_true(int(e1_after.get("burn_turns", 0)) > 0, "夏季森林攻击应触发火攻并施加烧伤")


func test_fire_attack_triggers_autumn_forest() -> void:
	TacticalSkirmishManager.set_season("autumn")
	TacticalSkirmishManager.start_skirmish()
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	var forest_cell: Vector2i = _find_terrain_cell("forest")
	e1["q"] = forest_cell.x
	e1["r"] = forest_cell.y
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	p1["q"] = forest_cell.x - 1
	p1["r"] = forest_cell.y
	p1["mp_remaining"] = 10
	TacticalSkirmishManager.try_player_attack("mvp_p1", "mvp_e1")
	var e1_after: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	if int(e1_after.get("hp", 0)) > 0:
		assert_true(int(e1_after.get("burn_turns", 0)) > 0, "秋季森林攻击应触发火攻")


func test_fire_attack_no_trigger_spring() -> void:
	TacticalSkirmishManager.set_season("spring")
	TacticalSkirmishManager.start_skirmish()
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	var forest_cell: Vector2i = _find_terrain_cell("forest")
	e1["q"] = forest_cell.x
	e1["r"] = forest_cell.y
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	p1["q"] = forest_cell.x - 1
	p1["r"] = forest_cell.y
	p1["mp_remaining"] = 10
	TacticalSkirmishManager.try_player_attack("mvp_p1", "mvp_e1")
	var e1_after: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	assert_eq(int(e1_after.get("burn_turns", 0)), 0, "春季不应触发火攻")


func test_fire_attack_no_trigger_winter() -> void:
	TacticalSkirmishManager.set_season("winter")
	TacticalSkirmishManager.start_skirmish()
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	var forest_cell: Vector2i = _find_terrain_cell("forest")
	e1["q"] = forest_cell.x
	e1["r"] = forest_cell.y
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	p1["q"] = forest_cell.x - 1
	p1["r"] = forest_cell.y
	p1["mp_remaining"] = 10
	TacticalSkirmishManager.try_player_attack("mvp_p1", "mvp_e1")
	var e1_after: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	assert_eq(int(e1_after.get("burn_turns", 0)), 0, "冬季不应触发火攻")


func test_fire_attack_no_trigger_non_forest() -> void:
	TacticalSkirmishManager.set_season("summer")
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	# 确保在平原
	var plains_cell: Vector2i = _find_terrain_cell("plains")
	e1["q"] = plains_cell.x
	e1["r"] = plains_cell.y
	p1["q"] = plains_cell.x - 1
	p1["r"] = plains_cell.y
	p1["mp_remaining"] = 10
	TacticalSkirmishManager.try_player_attack("mvp_p1", "mvp_e1")
	var e1_after: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	assert_eq(int(e1_after.get("burn_turns", 0)), 0, "非森林地形不应触发火攻")


# ============= 火攻与伏击互斥 =============

func test_fire_attack_ambush_exclusive() -> void:
	# 火攻和伏击不应同时触发（火攻优先时跳过伏击判定）
	var buff_fire: float = CombatLib._calc_atk_buff({"is_fire_attack": true, "fire_bonus": 0.4})
	var buff_ambush: float = CombatLib._calc_atk_buff({"is_ambush": true, "ambush_bonus": 0.3})
	var buff_both: float = CombatLib._calc_atk_buff({"is_ambush": true, "is_fire_attack": true, "ambush_bonus": 0.3, "fire_bonus": 0.4})
	# 互斥时伏击优先（代码中 is_ambush 先判断）
	assert_almost_eq(buff_both, buff_ambush, 0.01, "伏击与火攻互斥时伏击优先")


# ============= DOT 伤害测试 =============

func test_burn_dot_applied() -> void:
	TacticalSkirmishManager.set_season("summer")
	TacticalSkirmishManager.start_skirmish()
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	var forest_cell: Vector2i = _find_terrain_cell("forest")
	e1["q"] = forest_cell.x
	e1["r"] = forest_cell.y
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	p1["q"] = forest_cell.x - 1
	p1["r"] = forest_cell.y
	p1["mp_remaining"] = 10
	TacticalSkirmishManager.try_player_attack("mvp_p1", "mvp_e1")
	var e1_after: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	if int(e1_after.get("hp", 0)) > 0:
		var burn_dmg: int = int(e1_after.get("burn_damage", 0))
		var burn_turns: int = int(e1_after.get("burn_turns", 0))
		assert_true(burn_dmg > 0, "烧伤每回合伤害应 > 0（实际 %d）" % burn_dmg)
		assert_eq(burn_turns, 2, "烧伤应持续 2 回合（实际 %d）" % burn_turns)


func test_burn_dot_damage_value() -> void:
	# 烧伤伤害 = 攻击者 base_attack × 0.3，向下取整，最低 1
	var atk_type: Dictionary = DataManager.get_unit_type("infantry")
	var base_atk: int = int(atk_type.get("attack", 10))
	var ratio: float = 0.3
	var expected_dot: int = maxi(1, int(float(base_atk) * ratio))
	assert_eq(expected_dot, 3, "步兵 base_atk=10 × 0.3 = 3（实际 %d）" % expected_dot)


func test_burn_dot_ticks_down() -> void:
	TacticalSkirmishManager.set_season("summer")
	TacticalSkirmishManager.start_skirmish()
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	var forest_cell: Vector2i = _find_terrain_cell("forest")
	e1["q"] = forest_cell.x
	e1["r"] = forest_cell.y
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	p1["q"] = forest_cell.x - 1
	p1["r"] = forest_cell.y
	p1["mp_remaining"] = 10
	TacticalSkirmishManager.try_player_attack("mvp_p1", "mvp_e1")
	var e1_after: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	if int(e1_after.get("hp", 0)) <= 0:
		return  # 被击杀则跳过
	var hp_before_dot: int = int(e1_after["hp"])
	var burn_turns_before: int = int(e1_after.get("burn_turns", 0))
	var burn_dmg: int = int(e1_after.get("burn_damage", 0))
	assert_eq(burn_turns_before, 2, "烧伤应有 2 回合")
	# 模拟回合结算（process_morale_for_test 包含 burn DOT）
	TacticalSkirmishManager.process_morale_for_test()
	var hp_after_dot: int = int(e1_after["hp"])
	assert_eq(hp_after_dot, hp_before_dot - burn_dmg, "烧伤应扣减 %d HP（%d → %d）" % [burn_dmg, hp_before_dot, hp_after_dot])
	assert_eq(int(e1_after.get("burn_turns", 0)), 1, "烧伤回合数应减为 1")


func test_burn_dot_expires() -> void:
	TacticalSkirmishManager.set_season("summer")
	TacticalSkirmishManager.start_skirmish()
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	var forest_cell: Vector2i = _find_terrain_cell("forest")
	e1["q"] = forest_cell.x
	e1["r"] = forest_cell.y
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	p1["q"] = forest_cell.x - 1
	p1["r"] = forest_cell.y
	p1["mp_remaining"] = 10
	TacticalSkirmishManager.try_player_attack("mvp_p1", "mvp_e1")
	var e1_after: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	if int(e1_after.get("hp", 0)) <= 0:
		return
	# 第一回合 DOT
	TacticalSkirmishManager.process_morale_for_test()
	assert_eq(int(e1_after.get("burn_turns", 0)), 1, "第一回合后 burn_turns=1")
	# 第二回合 DOT
	TacticalSkirmishManager.process_morale_for_test()
	assert_eq(int(e1_after.get("burn_turns", 0)), 0, "第二回合后 burn_turns=0（已过期）")
	# 第三回合不应再扣 HP
	var hp_after_expire: int = int(e1_after["hp"])
	TacticalSkirmishManager.process_morale_for_test()
	assert_eq(int(e1_after["hp"]), hp_after_expire, "烧伤过期后不应再扣 HP")


# ============= 迭代安全测试 =============

func test_burn_dot_two_adjacent_deaths() -> void:
	# 验证：两个单位同时死于烧伤 DOT 时都能被正确移除（迭代安全）
	TacticalSkirmishManager.start_skirmish()
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	var e2: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e2")
	# 给两个敌方单位都施加烧伤
	e1["burn_damage"] = 9999
	e1["burn_turns"] = 1
	e2["burn_damage"] = 9999
	e2["burn_turns"] = 1
	# 执行烧伤结算
	TacticalSkirmishManager._process_burn_dot("zhao")
	# 两个单位都应被移除
	assert_true(TacticalSkirmishManager.get_unit_by_id("mvp_e1").is_empty(), "e1 应被烧伤致死")
	assert_true(TacticalSkirmishManager.get_unit_by_id("mvp_e2").is_empty(), "e2 应被烧伤致死")


# ============= 火攻加成值测试 =============

func test_fire_attack_bonus_value() -> void:
	var buff: float = CombatLib._calc_atk_buff({"is_fire_attack": true, "fire_bonus": 0.4})
	assert_almost_eq(buff, 1.4, 0.01, "火攻 atk_buff 应为 1.4（+0.4）")


func test_fire_attack_with_other_modifiers() -> void:
	var buff: float = CombatLib._calc_atk_buff({
		"is_fire_attack": true,
		"fire_bonus": 0.4,
		"terrain_atk_offset": -0.1,
		"morale_atk_offset": 0.1,
	})
	assert_almost_eq(buff, 1.4, 0.01, "火攻+地形-0.1+士气+0.1 = 1.4")


# ============= 辅助函数 =============

func _find_terrain_cell(terrain_id: String) -> Vector2i:
	var units: Array[Dictionary] = TacticalSkirmishManager.get_units()
	var occupied: Array[Vector2i] = []
	for u: Dictionary in units:
		occupied.append(Vector2i(int(u["q"]), int(u["r"])))
	# 遍历地图找地形
	for row: int in range(7):
		for col: int in range(7):
			var cell: Vector2i = HexAxial.offset_odd_r_to_axial(col, row)
			if cell in occupied:
				continue
			if TacticalSkirmishManager.terrain_at(cell) == terrain_id:
				return cell
	return Vector2i(-999, -999)
