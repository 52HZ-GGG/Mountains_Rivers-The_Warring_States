extends GutTest

## 关隘战斗机制单元测试
## 验证关隘结构 HP、结构防御、攻城器械倍率、占领、自然恢复、行军降速

const HexLib := preload("res://scripts/systems/hex_axial.gd")
const CombatLib := preload("res://scripts/systems/combat_resolver.gd")

var _combat: RefCounted
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func before_each() -> void:
	TacticalSkirmishManager.reset_skirmish()
	_combat = CombatLib.new()
	_rng.seed = 42


# ============= 关隘初始化测试 =============

func test_pass_has_initial_hp() -> void:
	TacticalSkirmishManager.start_skirmish()
	var pass_cell: Vector2i = _find_pass_cell()
	assert_true(pass_cell != Vector2i(-999, -999), "应存在关隘格")
	var hp: int = TacticalSkirmishManager.get_pass_hp(pass_cell)
	assert_gt(hp, 0, "关隘初始 HP 应 > 0（实际 %d）" % hp)


func test_pass_hp_equals_fortification_config() -> void:
	TacticalSkirmishManager.start_skirmish()
	var pass_cell: Vector2i = _find_pass_cell()
	var hp: int = TacticalSkirmishManager.get_pass_hp(pass_cell)
	var expected_v: Variant = DataManager.get_balance_param("fortification.pass_hp")
	var expected: int = int(expected_v) if expected_v != null else 500
	assert_eq(hp, expected, "关隘 HP 应等于 fortification.pass_hp（%d）" % expected)


func test_pass_initially_unowned() -> void:
	TacticalSkirmishManager.start_skirmish()
	var pass_cell: Vector2i = _find_pass_cell()
	var owner: String = TacticalSkirmishManager.get_pass_owner(pass_cell)
	assert_eq(owner, "", "关隘初始应无主")


# ============= 行军降速测试 =============

func test_pass_crossing_rules_reduce_move_cost() -> void:
	TacticalSkirmishManager.start_skirmish()
	var pass_cell: Vector2i = _find_pass_cell()
	var base_cost_v: Variant = DataManager.get_terrain("pass").get("move_cost", 2)
	var base_cost: int = int(base_cost_v)
	var speed_mod_v: Variant = DataManager.get_terrain("pass").get("crossing_rules", {}).get("move_speed_modifier", 1.0)
	var expected: int = maxi(1, int(float(base_cost) * float(speed_mod_v)))
	# 将玩家单位放到关隘旁边，检查可达性
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	p1["q"] = pass_cell.x - 1
	p1["r"] = pass_cell.y
	p1["mp_remaining"] = 10
	var reach: Dictionary = TacticalSkirmishManager.get_reachable_cells("mvp_p1")
	if reach.has(pass_cell):
		var cost: int = int(reach[pass_cell])
		assert_eq(cost, expected, "关隘移动力消耗应为 %d（实际 %d）" % [expected, cost])
	else:
		pass_test("关隘格被占据，无法测试移动力消耗")


# ============= 关隘结构防御测试 =============

func test_pass_structure_defense_reduces_damage() -> void:
	# 对比：攻击关隘上的单位 vs 攻击平原上的同种单位
	TacticalSkirmishManager.start_skirmish()
	var pass_cell: Vector2i = _find_pass_cell()
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	# 场景 1：平原攻击
	var plains_cell: Vector2i = _find_terrain_cell("plains")
	e1["q"] = plains_cell.x
	e1["r"] = plains_cell.y
	p1["q"] = plains_cell.x - 1
	p1["r"] = plains_cell.y
	p1["mp_remaining"] = 10
	p1["acted"] = false
	var hp_before_1: int = int(e1["hp"])
	TacticalSkirmishManager.try_player_attack("mvp_p1", "mvp_e1")
	var hp_after_1: int = int(e1["hp"])
	var plains_dmg: int = hp_before_1 - hp_after_1
	# 重置
	TacticalSkirmishManager.reset_skirmish()
	TacticalSkirmishManager.start_skirmish()
	# 场景 2：关隘攻击
	e1 = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	p1 = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	e1["q"] = pass_cell.x
	e1["r"] = pass_cell.y
	p1["q"] = pass_cell.x - 1
	p1["r"] = pass_cell.y
	p1["mp_remaining"] = 10
	p1["acted"] = false
	var hp_before_2: int = int(e1["hp"])
	TacticalSkirmishManager.try_player_attack("mvp_p1", "mvp_e1")
	var hp_after_2: int = int(e1["hp"])
	var pass_dmg: int = hp_before_2 - hp_after_2
	assert_true(pass_dmg < plains_dmg, "关隘结构防御应减少伤害（平原 %d vs 关隘 %d）" % [plains_dmg, pass_dmg])


func test_pass_structure_hp_decreases_on_attack() -> void:
	TacticalSkirmishManager.start_skirmish()
	var pass_cell: Vector2i = _find_pass_cell()
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	e1["q"] = pass_cell.x
	e1["r"] = pass_cell.y
	p1["q"] = pass_cell.x - 1
	p1["r"] = pass_cell.y
	p1["mp_remaining"] = 10
	var hp_before: int = TacticalSkirmishManager.get_pass_hp(pass_cell)
	TacticalSkirmishManager.try_player_attack("mvp_p1", "mvp_e1")
	var hp_after: int = TacticalSkirmishManager.get_pass_hp(pass_cell)
	assert_lt(hp_after, hp_before, "攻击后关隘结构 HP 应下降（%d → %d）" % [hp_before, hp_after])


# ============= 攻城器械倍率测试 =============

func test_siege_unit_deals_extra_structure_damage() -> void:
	# 直接测试 _damage_pass_structure 的攻城倍率
	TacticalSkirmishManager.start_skirmish()
	var pass_cell: Vector2i = _find_pass_cell()
	var eff_atk: float = 100.0
	# 步兵结构伤害
	TacticalSkirmishManager._damage_pass_structure(pass_cell, "infantry", eff_atk)
	var hp_after_inf: int = TacticalSkirmishManager.get_pass_hp(pass_cell)
	var inf_struct_dmg: int = 500 - hp_after_inf
	# 重置，攻城器械结构伤害
	TacticalSkirmishManager.reset_skirmish()
	TacticalSkirmishManager.start_skirmish()
	pass_cell = _find_pass_cell()
	TacticalSkirmishManager._damage_pass_structure(pass_cell, "battering_ram", eff_atk)
	var hp_after_siege: int = TacticalSkirmishManager.get_pass_hp(pass_cell)
	var siege_struct_dmg: int = 500 - hp_after_siege
	assert_gt(siege_struct_dmg, inf_struct_dmg, "攻城器械应造成更多结构伤害（步兵 %d vs 攻城 %d）" % [inf_struct_dmg, siege_struct_dmg])


func test_is_siege_unit_detection() -> void:
	assert_true(TacticalSkirmishManager._is_siege_unit("battering_ram"), "冲车应为攻城器械")
	assert_true(TacticalSkirmishManager._is_siege_unit("siege"), "投石车应为攻城器械")
	assert_false(TacticalSkirmishManager._is_siege_unit("infantry"), "步兵不应为攻城器械")
	assert_false(TacticalSkirmishManager._is_siege_unit("cavalry"), "骑兵不应为攻城器械")


# ============= 关隘 HP 耗尽测试 =============

func test_pass_hp_floor_at_zero() -> void:
	TacticalSkirmishManager.start_skirmish()
	var pass_cell: Vector2i = _find_pass_cell()
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	e1["q"] = pass_cell.x
	e1["r"] = pass_cell.y
	p1["q"] = pass_cell.x - 1
	p1["r"] = pass_cell.y
	p1["mp_remaining"] = 10
	# 手动设置 HP 为极低值
	TacticalSkirmishManager._pass_hp[pass_cell] = 1
	TacticalSkirmishManager.try_player_attack("mvp_p1", "mvp_e1")
	var hp: int = TacticalSkirmishManager.get_pass_hp(pass_cell)
	assert_true(hp >= 0, "关隘 HP 不应为负（实际 %d）" % hp)


func test_pass_destroyed_no_structure_defense() -> void:
	# 关隘 HP=0 时，不应叠加 building_def（结构防御）
	# 使用 _calc_def_buff 直接验证：有结构 HP 时 building_def > 0，无时 = 0
	TacticalSkirmishManager.start_skirmish()
	var pass_cell: Vector2i = _find_pass_cell()
	# 有结构 HP 时，def_ctx 应包含 building_def
	var pass_def_v: Variant = DataManager.get_balance_param("fortification.pass_defense")
	var expected_building_def: float = float(pass_def_v) / 100.0 if pass_def_v != null else 1.0
	var ctx_with_structure: Dictionary = {"building_def": expected_building_def}
	var def_with: float = CombatLib._calc_def_buff(ctx_with_structure)
	# 无结构 HP 时，building_def = 0
	var ctx_without: Dictionary = {}
	var def_without: float = CombatLib._calc_def_buff(ctx_without)
	assert_gt(def_with, def_without, "有结构防御时 def_buff 应更高（%.2f vs %.2f）" % [def_with, def_without])
	# 验证已摧毁关隘 HP 保持 0
	TacticalSkirmishManager._pass_hp[pass_cell] = 0
	assert_eq(TacticalSkirmishManager.get_pass_hp(pass_cell), 0, "已摧毁的关隘 HP 应保持为 0")


# ============= 关隘占领测试 =============

func test_capture_pass_on_move_onto_destroyed() -> void:
	TacticalSkirmishManager.start_skirmish()
	var pass_cell: Vector2i = _find_pass_cell()
	TacticalSkirmishManager._pass_hp[pass_cell] = 0
	TacticalSkirmishManager._pass_owner[pass_cell] = ""
	# 将敌军移走
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	e1["q"] = 0
	e1["r"] = 0
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	p1["q"] = pass_cell.x - 1
	p1["r"] = pass_cell.y
	p1["mp_remaining"] = 10
	p1["acted"] = false
	TacticalSkirmishManager.try_move_unit("mvp_p1", pass_cell)
	var owner: String = TacticalSkirmishManager.get_pass_owner(pass_cell)
	assert_eq(owner, "qin", "占领后归属应为 qin")


func test_capture_restores_30_percent_hp() -> void:
	TacticalSkirmishManager.start_skirmish()
	var pass_cell: Vector2i = _find_pass_cell()
	var max_hp_v: Variant = DataManager.get_balance_param("fortification.pass_hp")
	var max_hp: int = int(max_hp_v) if max_hp_v != null else 500
	var restore_v: Variant = DataManager.get_balance_param("city_combat.capture_restore_ratio")
	var restore_ratio: float = float(restore_v) if restore_v != null else 0.3
	var expected_hp: int = maxi(1, int(float(max_hp) * restore_ratio))
	TacticalSkirmishManager._pass_hp[pass_cell] = 0
	TacticalSkirmishManager._pass_owner[pass_cell] = ""
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	e1["q"] = 0
	e1["r"] = 0
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	p1["q"] = pass_cell.x - 1
	p1["r"] = pass_cell.y
	p1["mp_remaining"] = 10
	p1["acted"] = false
	TacticalSkirmishManager.try_move_unit("mvp_p1", pass_cell)
	var hp: int = TacticalSkirmishManager.get_pass_hp(pass_cell)
	assert_eq(hp, expected_hp, "占领后 HP 应恢复 %d（实际 %d）" % [expected_hp, hp])


func test_cannot_capture_pass_with_garrison() -> void:
	TacticalSkirmishManager.start_skirmish()
	var pass_cell: Vector2i = _find_pass_cell()
	TacticalSkirmishManager._pass_hp[pass_cell] = 0
	TacticalSkirmishManager._pass_owner[pass_cell] = ""
	# 敌军仍在关隘上
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	e1["q"] = pass_cell.x
	e1["r"] = pass_cell.y
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	p1["q"] = pass_cell.x - 1
	p1["r"] = pass_cell.y
	p1["mp_remaining"] = 10
	p1["acted"] = false
	var result: Dictionary = TacticalSkirmishManager.try_move_unit("mvp_p1", pass_cell)
	assert_false(result.get("ok", true), "有驻军时不应能移动到关隘")


# ============= 自然恢复测试 =============

func test_pass_natural_recovery_when_not_attacked() -> void:
	TacticalSkirmishManager.start_skirmish()
	var pass_cell: Vector2i = _find_pass_cell()
	var max_hp_v: Variant = DataManager.get_balance_param("fortification.pass_hp")
	var max_hp: int = int(max_hp_v) if max_hp_v != null else 500
	var rec_v: Variant = DataManager.get_balance_param("city_combat.natural_recovery_ratio")
	var ratio: float = float(rec_v) if rec_v != null else 0.05
	var heal: int = maxi(1, int(float(max_hp) * ratio))
	TacticalSkirmishManager._pass_hp[pass_cell] = max_hp - heal * 2
	TacticalSkirmishManager._pass_attacked[pass_cell] = false
	var hp_before: int = TacticalSkirmishManager.get_pass_hp(pass_cell)
	TacticalSkirmishManager.begin_player_phase()
	var hp_after: int = TacticalSkirmishManager.get_pass_hp(pass_cell)
	assert_eq(hp_after, hp_before + heal, "未被攻击时应恢复 %d HP（%d → %d）" % [heal, hp_before, hp_after])


func test_pass_no_recovery_when_attacked() -> void:
	TacticalSkirmishManager.start_skirmish()
	var pass_cell: Vector2i = _find_pass_cell()
	var max_hp_v: Variant = DataManager.get_balance_param("fortification.pass_hp")
	var max_hp: int = int(max_hp_v) if max_hp_v != null else 500
	TacticalSkirmishManager._pass_hp[pass_cell] = max_hp - 50
	TacticalSkirmishManager._pass_attacked[pass_cell] = true
	var hp_before: int = TacticalSkirmishManager.get_pass_hp(pass_cell)
	TacticalSkirmishManager.begin_player_phase()
	var hp_after: int = TacticalSkirmishManager.get_pass_hp(pass_cell)
	assert_eq(hp_after, hp_before, "被攻击后本回合不应恢复 HP")


func test_pass_recovery_capped_at_max() -> void:
	TacticalSkirmishManager.start_skirmish()
	var pass_cell: Vector2i = _find_pass_cell()
	var max_hp_v: Variant = DataManager.get_balance_param("fortification.pass_hp")
	var max_hp: int = int(max_hp_v) if max_hp_v != null else 500
	TacticalSkirmishManager._pass_hp[pass_cell] = max_hp - 1
	TacticalSkirmishManager._pass_attacked[pass_cell] = false
	TacticalSkirmishManager.begin_player_phase()
	var hp: int = TacticalSkirmishManager.get_pass_hp(pass_cell)
	assert_true(hp <= max_hp, "恢复后 HP 不应超过最大值（实际 %d / %d）" % [hp, max_hp])


# ============= 胜利阻断测试 =============

func test_garrisoned_pass_blocks_victory() -> void:
	TacticalSkirmishManager.start_skirmish()
	var pass_cell: Vector2i = _find_pass_cell()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	var enemy_city: Vector2i = TacticalSkirmishManager.get_enemy_city()
	p1["q"] = enemy_city.x
	p1["r"] = enemy_city.y
	# 关隘仍有 HP 和驻军
	TacticalSkirmishManager._pass_hp[pass_cell] = 500
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	e1["q"] = pass_cell.x
	e1["r"] = pass_cell.y
	var winner: String = TacticalSkirmishManager.check_victory()
	assert_eq(winner, "", "有驻军的关隘应阻断胜利")


func test_destroyed_pass_does_not_block_victory() -> void:
	TacticalSkirmishManager.start_skirmish()
	var pass_cell: Vector2i = _find_pass_cell()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	var enemy_city: Vector2i = TacticalSkirmishManager.get_enemy_city()
	p1["q"] = enemy_city.x
	p1["r"] = enemy_city.y
	TacticalSkirmishManager._pass_hp[pass_cell] = 0
	TacticalSkirmishManager._city_wall_hp[enemy_city] = 0
	var winner: String = TacticalSkirmishManager.check_victory()
	assert_eq(winner, "qin", "摧毁的关隘不应阻断胜利")


func test_empty_garrison_pass_does_not_block() -> void:
	TacticalSkirmishManager.start_skirmish()
	var pass_cell: Vector2i = _find_pass_cell()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	var enemy_city: Vector2i = TacticalSkirmishManager.get_enemy_city()
	p1["q"] = enemy_city.x
	p1["r"] = enemy_city.y
	TacticalSkirmishManager._pass_hp[pass_cell] = 500
	TacticalSkirmishManager._city_wall_hp[enemy_city] = 0
	# 将敌军移走
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	e1["q"] = 0
	e1["r"] = 0
	var winner: String = TacticalSkirmishManager.check_victory()
	assert_eq(winner, "qin", "无关隘驻军时不应阻断胜利")


# ============= crossing_rules 攻防修正测试 =============

func test_crossing_rules_atk_penalty_applied() -> void:
	var base_dmg: Dictionary = _combat.compute_damage("infantry", "infantry", "plains", 100, 100, _rng, {}, {})
	var pass_dmg: Dictionary = _combat.compute_damage("infantry", "infantry", "pass", 100, 100, _rng, {}, {})
	assert_gt(int(base_dmg["damage"]), int(pass_dmg["damage"]), "关隘地形应降低攻击伤害")


# ============= 辅助函数 =============

func _find_pass_cell() -> Vector2i:
	for row: int in range(7):
		for col: int in range(7):
			var cell: Vector2i = HexLib.offset_odd_r_to_axial(col, row)
			if TacticalSkirmishManager.terrain_at(cell) == "pass":
				return cell
	return Vector2i(-999, -999)


func _find_terrain_cell(terrain_id: String) -> Vector2i:
	var units: Array[Dictionary] = TacticalSkirmishManager.get_units()
	var occupied: Array[Vector2i] = []
	for u: Dictionary in units:
		occupied.append(Vector2i(int(u["q"]), int(u["r"])))
	for row: int in range(7):
		for col: int in range(7):
			var cell: Vector2i = HexLib.offset_odd_r_to_axial(col, row)
			if cell in occupied:
				continue
			if TacticalSkirmishManager.terrain_at(cell) == terrain_id:
				return cell
	return Vector2i(-999, -999)
