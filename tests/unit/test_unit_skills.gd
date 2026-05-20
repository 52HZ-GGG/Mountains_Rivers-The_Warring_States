extends GutTest

## 兵种技能执行单元测试
## 验证 4 种技能类型：passive、terrain_move_modifier、combat_on_kill、move_after_attack

const CombatLib := preload("res://scripts/systems/combat_resolver.gd")


func before_each() -> void:
	TacticalSkirmishManager.reset_skirmish()


# ============= passive 技能测试 =============

func test_passive_skill_bonus_empty() -> void:
	var bonus: float = TacticalSkirmishManager._get_passive_skill_bonus([])
	assert_almost_eq(bonus, 0.0, 0.01, "无技能时 bonus 应为 0")


func test_passive_skill_bonus_single() -> void:
	var skills: Array = [{"type": "passive", "value": 1.5}]
	var bonus: float = TacticalSkirmishManager._get_passive_skill_bonus(skills)
	assert_almost_eq(bonus, 1.5, 0.01, "单个被动技能 bonus=1.5")


func test_passive_skill_bonus_ignores_non_passive() -> void:
	var skills: Array = [
		{"type": "passive", "value": 1.0},
		{"type": "combat_on_kill", "recover_ratio": 0.05},
		{"type": "passive", "value": 0.5},
	]
	var bonus: float = TacticalSkirmishManager._get_passive_skill_bonus(skills)
	assert_almost_eq(bonus, 1.5, 0.01, "应累加所有 passive 技能值")


func test_passive_bonus_applied_to_attack_ctx() -> void:
	var buff: float = CombatLib._calc_atk_buff({"unit_ability_bonus": 1.5})
	assert_almost_eq(buff, 2.5, 0.01, "unit_ability_bonus=1.5 应使 atk_buff=2.5")


# ============= terrain_move_modifier 技能测试 =============

func test_terrain_move_modifier_forest_march() -> void:
	TacticalSkirmishManager.start_skirmish()
	var skills: Array = [{"id": "forest_march", "type": "passive", "terrain_move_modifier": {"forest": -1}}]
	var forest_cell: Vector2i = _find_terrain_cell("forest")
	assert_true(forest_cell != Vector2i(-999, -999), "应存在森林格")
	var base_cost: int = TacticalSkirmishManager._tile_move_cost_cell(forest_cell, "cavalry", [])
	var mod_cost: int = TacticalSkirmishManager._tile_move_cost_cell(forest_cell, "cavalry", skills)
	assert_eq(base_cost, 2, "骑兵森林基础消耗应为 2")
	assert_eq(mod_cost, 1, "林地行军后森林消耗应为 1")


func test_terrain_move_modifier_no_effect_on_plains() -> void:
	TacticalSkirmishManager.start_skirmish()
	var skills: Array = [{"id": "forest_march", "type": "passive", "terrain_move_modifier": {"forest": -1}}]
	var plains_cell: Vector2i = _find_terrain_cell("plains")
	assert_true(plains_cell != Vector2i(-999, -999), "应存在平原格")
	var base_cost: int = TacticalSkirmishManager._tile_move_cost_cell(plains_cell, "cavalry", [])
	var mod_cost: int = TacticalSkirmishManager._tile_move_cost_cell(plains_cell, "cavalry", skills)
	assert_eq(base_cost, mod_cost, "平原消耗不应受森林技能影响")


func test_terrain_move_modifier_minimum_one() -> void:
	TacticalSkirmishManager.start_skirmish()
	var skills: Array = [{"id": "test", "type": "passive", "terrain_move_modifier": {"plains": -10}}]
	var plains_cell: Vector2i = _find_terrain_cell("plains")
	var mod_cost: int = TacticalSkirmishManager._tile_move_cost_cell(plains_cell, "infantry", skills)
	assert_true(mod_cost >= 1, "移动力消耗应保底为 1（实际 %d）" % mod_cost)


# ============= combat_on_kill 技能测试 =============

func test_combat_on_kill_recovers_hp() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	p1["skills"] = [{"id": "wuzu_recover", "type": "combat_on_kill", "recover_ratio": 0.05}]
	p1["hp"] = 50
	var max_hp: int = int(p1["max_hp"])
	TacticalSkirmishManager._apply_combat_on_kill(p1)
	var expected_heal: int = maxi(1, int(float(max_hp) * 0.05))
	assert_eq(int(p1["hp"]), mini(50 + expected_heal, max_hp), "应恢复 5%% HP")


func test_combat_on_kill_caps_at_max_hp() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	p1["skills"] = [{"id": "wuzu_recover", "type": "combat_on_kill", "recover_ratio": 0.05}]
	p1["hp"] = int(p1["max_hp"]) - 1
	TacticalSkirmishManager._apply_combat_on_kill(p1)
	assert_eq(int(p1["hp"]), int(p1["max_hp"]), "恢复不应超过 max_hp")


func test_combat_on_kill_no_skill_no_effect() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	p1["skills"] = []
	p1["hp"] = 50
	TacticalSkirmishManager._apply_combat_on_kill(p1)
	assert_eq(int(p1["hp"]), 50, "无技能时不应恢复 HP")


# ============= move_after_attack 技能测试 =============

func test_move_after_attack_skill_lookup() -> void:
	var skills: Array = [
		{"id": "hit_and_run", "type": "move_after_attack", "attack_move_cost": 2, "per_turn_limit": 1},
	]
	var maa: Dictionary = TacticalSkirmishManager._get_move_after_attack_skill(skills)
	assert_false(maa.is_empty(), "应找到 move_after_attack 技能")
	assert_eq(int(maa.get("attack_move_cost", 0)), 2, "attack_move_cost 应为 2")
	assert_eq(int(maa.get("per_turn_limit", 0)), 1, "per_turn_limit 应为 1")


func test_move_after_attack_skill_lookup_empty() -> void:
	var skills: Array = [{"id": "forest_march", "type": "passive"}]
	var maa: Dictionary = TacticalSkirmishManager._get_move_after_attack_skill(skills)
	assert_true(maa.is_empty(), "非 move_after_attack 技能应返回空")


func test_move_after_attack_integration() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	p1["skills"] = [{"id": "hit_and_run", "type": "move_after_attack", "attack_move_cost": 2, "per_turn_limit": 1}]
	p1["mp_remaining"] = 6
	e1["q"] = int(p1["q"]) + 1
	e1["r"] = int(p1["r"])
	var result: Dictionary = TacticalSkirmishManager.try_player_attack("mvp_p1", "mvp_e1")
	assert_true(result.get("ok", false), "攻击应成功（实际 %s）" % str(result))
	assert_false(bool(p1.get("acted", false)), "move_after_attack 攻击后不应设 acted=true")
	assert_eq(int(p1.get("attacks_this_turn", 0)), 1, "attacks_this_turn 应为 1")
	assert_eq(int(p1.get("mp_remaining", 0)), 4, "应扣除 2 移动力（6→4）")


func test_move_after_attack_per_turn_limit() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	p1["skills"] = [{"id": "hit_and_run", "type": "move_after_attack", "attack_move_cost": 2, "per_turn_limit": 1}]
	p1["mp_remaining"] = 10
	p1["attacks_this_turn"] = 1
	e1["q"] = int(p1["q"]) + 1
	e1["r"] = int(p1["r"])
	var result: Dictionary = TacticalSkirmishManager.try_player_attack("mvp_p1", "mvp_e1")
	assert_false(result.get("ok", false), "已达攻击上限时应拒绝攻击")
	assert_eq(str(result.get("reason", "")), "attack_limit_reached", "原因应为 attack_limit_reached")


func test_move_after_attack_acted_when_mp_zero() -> void:
	TacticalSkirmishManager.start_skirmish()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	p1["skills"] = [{"id": "hit_and_run", "type": "move_after_attack", "attack_move_cost": 2, "per_turn_limit": 1}]
	p1["mp_remaining"] = 2
	e1["q"] = int(p1["q"]) + 1
	e1["r"] = int(p1["r"])
	TacticalSkirmishManager.try_player_attack("mvp_p1", "mvp_e1")
	assert_true(bool(p1.get("acted", false)), "移动力耗尽时应自动设 acted=true")


# ============= 辅助函数 =============

func _find_terrain_cell(terrain_id: String) -> Vector2i:
	var units: Array[Dictionary] = TacticalSkirmishManager.get_units()
	var occupied: Array[Vector2i] = []
	for u: Dictionary in units:
		occupied.append(Vector2i(int(u["q"]), int(u["r"])))
	for row: int in range(7):
		for col: int in range(7):
			var cell: Vector2i = HexAxial.offset_odd_r_to_axial(col, row)
			if cell in occupied:
				continue
			if TacticalSkirmishManager.terrain_at(cell) == terrain_id:
				return cell
	return Vector2i(-999, -999)
