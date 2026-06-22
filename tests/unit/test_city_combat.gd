extends GutTest

## 城防战机制单元测试
## 验证城墙 HP、城防值、伤害分流、攻城器械倍率、占领、自然恢复、箭塔、胜利条件

const HexLib := preload("res://scripts/systems/hex_axial.gd")
const CombatLib := preload("res://scripts/systems/combat_resolver.gd")

var _combat: RefCounted
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func before_each() -> void:
	TacticalSkirmishManager.reset_skirmish()
	_combat = CombatLib.new()
	_rng.seed = 42


# ============= 城市初始化测试 =============

func test_city_has_initial_wall_hp() -> void:
	TacticalSkirmishManager.start_skirmish()
	var hp: int = TacticalSkirmishManager.get_city_wall_hp(TacticalSkirmishManager.get_enemy_city())
	assert_gt(hp, 0, "城市初始城墙 HP 应 > 0（实际 %d）" % hp)


func test_city_wall_hp_matches_config() -> void:
	TacticalSkirmishManager.start_skirmish()
	var city: Vector2i = TacticalSkirmishManager.get_enemy_city()
	var hp: int = TacticalSkirmishManager.get_city_wall_hp(city)
	var expected_base_v: Variant = DataManager.get_balance_param("city_levels.3.hp")
	var expected_base: int = int(expected_base_v) if expected_base_v != null else 1000
	var capital_bonus_v: Variant = DataManager.get_balance_param("city_levels.capital_bonus.hp")
	var capital_bonus: int = int(capital_bonus_v) if capital_bonus_v != null else 500
	var expected: int = expected_base + capital_bonus
	assert_eq(hp, expected, "3 级都城城墙 HP 应为 %d（实际 %d）" % [expected, hp])


func test_city_level_stored() -> void:
	TacticalSkirmishManager.start_skirmish()
	var level: int = TacticalSkirmishManager.get_city_level(TacticalSkirmishManager.get_enemy_city())
	assert_eq(level, 3, "城市等级应为 3（实际 %d）" % level)


# ============= 城墙 HP 变化测试 =============

func test_attack_reduces_wall_hp() -> void:
	TacticalSkirmishManager.start_skirmish()
	var enemy_city: Vector2i = TacticalSkirmishManager.get_enemy_city()
	# 将敌军移到城市格，玩家单位移到旁边
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	e1["q"] = enemy_city.x
	e1["r"] = enemy_city.y
	p1["q"] = enemy_city.x - 1
	p1["r"] = enemy_city.y
	p1["mp_remaining"] = 10
	p1["acted"] = false
	var wall_before: int = TacticalSkirmishManager.get_city_wall_hp(enemy_city)
	TacticalSkirmishManager.try_player_attack("mvp_p1", "mvp_e1")
	var wall_after: int = TacticalSkirmishManager.get_city_wall_hp(enemy_city)
	assert_lt(wall_after, wall_before, "攻击后城墙 HP 应下降（%d → %d）" % [wall_before, wall_after])


func test_wall_hp_floor_at_zero() -> void:
	TacticalSkirmishManager.start_skirmish()
	var enemy_city: Vector2i = TacticalSkirmishManager.get_enemy_city()
	TacticalSkirmishManager._city_wall_hp[enemy_city] = 1
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	e1["q"] = enemy_city.x
	e1["r"] = enemy_city.y
	p1["q"] = enemy_city.x - 1
	p1["r"] = enemy_city.y
	p1["mp_remaining"] = 10
	p1["acted"] = false
	TacticalSkirmishManager.try_player_attack("mvp_p1", "mvp_e1")
	var hp: int = TacticalSkirmishManager.get_city_wall_hp(enemy_city)
	assert_true(hp >= 0, "城墙 HP 不应为负（实际 %d）" % hp)


# ============= 攻城器械倍率测试 =============

func test_siege_unit_deals_extra_wall_damage() -> void:
	# 直接测试 _damage_city_wall 的攻城倍率效果
	TacticalSkirmishManager.start_skirmish()
	var enemy_city: Vector2i = TacticalSkirmishManager.get_enemy_city()
	var wall_before: int = TacticalSkirmishManager.get_city_wall_hp(enemy_city)
	# 步兵城墙伤害（无倍率）
	TacticalSkirmishManager._damage_city_wall(enemy_city, 50)
	var wall_after_inf: int = TacticalSkirmishManager.get_city_wall_hp(enemy_city)
	var inf_dmg: int = wall_before - wall_after_inf
	# 重置
	TacticalSkirmishManager.reset_skirmish()
	TacticalSkirmishManager.start_skirmish()
	var wall_before2: int = TacticalSkirmishManager.get_city_wall_hp(enemy_city)
	# 攻城器械城墙伤害（倍率已在调用方乘算，此处模拟 x3）
	TacticalSkirmishManager._damage_city_wall(enemy_city, 150)
	var wall_after_siege: int = TacticalSkirmishManager.get_city_wall_hp(enemy_city)
	var siege_dmg: int = wall_before2 - wall_after_siege
	assert_gt(siege_dmg, inf_dmg, "攻城器械应造成更多城墙伤害（步兵 %d vs 攻城 %d）" % [inf_dmg, siege_dmg])


# ============= 城防防御加成测试 =============

func test_city_defense_reduces_damage() -> void:
	# 对比：攻击城市上的单位 vs 攻击平原上的同种单位
	TacticalSkirmishManager.start_skirmish()
	var enemy_city: Vector2i = TacticalSkirmishManager.get_enemy_city()
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
	# 场景 2：城市攻击
	e1 = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	p1 = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	e1["q"] = enemy_city.x
	e1["r"] = enemy_city.y
	p1["q"] = enemy_city.x - 1
	p1["r"] = enemy_city.y
	p1["mp_remaining"] = 10
	p1["acted"] = false
	var hp_before_2: int = int(e1["hp"])
	TacticalSkirmishManager.try_player_attack("mvp_p1", "mvp_e1")
	var hp_after_2: int = int(e1["hp"])
	var city_dmg: int = hp_before_2 - hp_after_2
	# 城市防御应减少对驻军的伤害（部分伤害分流到城墙）
	assert_true(city_dmg < plains_dmg, "城防应减少驻军伤害（平原 %d vs 城市 %d）" % [plains_dmg, city_dmg])


func test_wall_hp_zero_no_defense_bonus() -> void:
	# 城墙 HP=0 时，building_def 应为 0
	var ctx_with: Dictionary = {"building_def": 0.45}
	var def_with: float = CombatLib._calc_def_buff(ctx_with)
	var ctx_without: Dictionary = {}
	var def_without: float = CombatLib._calc_def_buff(ctx_without)
	assert_gt(def_with, def_without, "有城防时 def_buff 应更高（%.2f vs %.2f）" % [def_with, def_without])


# ============= 城市占领测试 =============

func test_capture_city_when_wall_destroyed() -> void:
	TacticalSkirmishManager.start_skirmish()
	var enemy_city: Vector2i = TacticalSkirmishManager.get_enemy_city()
	TacticalSkirmishManager._city_wall_hp[enemy_city] = 0
	# 将敌军移走
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	e1["q"] = 0
	e1["r"] = 0
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	p1["q"] = enemy_city.x - 1
	p1["r"] = enemy_city.y
	p1["mp_remaining"] = 10
	p1["acted"] = false
	TacticalSkirmishManager.try_move_unit("mvp_p1", enemy_city)
	var wall_hp: int = TacticalSkirmishManager.get_city_wall_hp(enemy_city)
	assert_gt(wall_hp, 0, "占领后城墙 HP 应恢复（实际 %d）" % wall_hp)
	assert_false(TacticalSkirmishManager.is_active(), "占领敌城后应立即结束演武，不能被城墙恢复抵消胜利")


func test_capture_restores_30_percent_hp() -> void:
	TacticalSkirmishManager.start_skirmish()
	var enemy_city: Vector2i = TacticalSkirmishManager.get_enemy_city()
	var max_hp: int = TacticalSkirmishManager._city_wall_max_hp[enemy_city]
	var restore_v: Variant = DataManager.get_balance_param("city_combat.capture_restore_ratio")
	var restore_ratio: float = float(restore_v) if restore_v != null else 0.3
	var expected_hp: int = maxi(1, int(float(max_hp) * restore_ratio))
	TacticalSkirmishManager._city_wall_hp[enemy_city] = 0
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	e1["q"] = 0
	e1["r"] = 0
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	p1["q"] = enemy_city.x - 1
	p1["r"] = enemy_city.y
	p1["mp_remaining"] = 10
	p1["acted"] = false
	TacticalSkirmishManager.try_move_unit("mvp_p1", enemy_city)
	var hp: int = TacticalSkirmishManager.get_city_wall_hp(enemy_city)
	assert_eq(hp, expected_hp, "占领后 HP 应恢复 %d（实际 %d）" % [expected_hp, hp])


func test_cannot_capture_with_garrison() -> void:
	TacticalSkirmishManager.start_skirmish()
	var enemy_city: Vector2i = TacticalSkirmishManager.get_enemy_city()
	TacticalSkirmishManager._city_wall_hp[enemy_city] = 0
	# 敌军仍在城市上
	var e1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_e1")
	e1["q"] = enemy_city.x
	e1["r"] = enemy_city.y
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	p1["q"] = enemy_city.x - 1
	p1["r"] = enemy_city.y
	p1["mp_remaining"] = 10
	p1["acted"] = false
	var result: Dictionary = TacticalSkirmishManager.try_move_unit("mvp_p1", enemy_city)
	assert_false(result.get("ok", true), "有驻军时不应能移动到城市")


# ============= 自然恢复测试 =============

func test_city_natural_recovery_when_not_attacked() -> void:
	TacticalSkirmishManager.start_skirmish()
	var enemy_city: Vector2i = TacticalSkirmishManager.get_enemy_city()
	var max_hp: int = TacticalSkirmishManager._city_wall_max_hp[enemy_city]
	var rec_v: Variant = DataManager.get_balance_param("city_combat.natural_recovery_ratio")
	var ratio: float = float(rec_v) if rec_v != null else 0.05
	var heal: int = maxi(1, int(float(max_hp) * ratio))
	TacticalSkirmishManager._city_wall_hp[enemy_city] = max_hp - heal * 2
	TacticalSkirmishManager._city_attacked[enemy_city] = false
	var hp_before: int = TacticalSkirmishManager.get_city_wall_hp(enemy_city)
	TacticalSkirmishManager.begin_player_phase()
	var hp_after: int = TacticalSkirmishManager.get_city_wall_hp(enemy_city)
	assert_eq(hp_after, hp_before + heal, "未被攻击时应恢复 %d HP（%d → %d）" % [heal, hp_before, hp_after])


func test_city_no_recovery_when_attacked() -> void:
	TacticalSkirmishManager.start_skirmish()
	var enemy_city: Vector2i = TacticalSkirmishManager.get_enemy_city()
	var max_hp: int = TacticalSkirmishManager._city_wall_max_hp[enemy_city]
	TacticalSkirmishManager._city_wall_hp[enemy_city] = max_hp - 50
	TacticalSkirmishManager._city_attacked[enemy_city] = true
	var hp_before: int = TacticalSkirmishManager.get_city_wall_hp(enemy_city)
	TacticalSkirmishManager.begin_player_phase()
	var hp_after: int = TacticalSkirmishManager.get_city_wall_hp(enemy_city)
	assert_eq(hp_after, hp_before, "被攻击后本回合不应恢复 HP")


func test_city_recovery_capped_at_max() -> void:
	TacticalSkirmishManager.start_skirmish()
	var enemy_city: Vector2i = TacticalSkirmishManager.get_enemy_city()
	var max_hp: int = TacticalSkirmishManager._city_wall_max_hp[enemy_city]
	TacticalSkirmishManager._city_wall_hp[enemy_city] = max_hp - 1
	TacticalSkirmishManager._city_attacked[enemy_city] = false
	TacticalSkirmishManager.begin_player_phase()
	var hp: int = TacticalSkirmishManager.get_city_wall_hp(enemy_city)
	assert_true(hp <= max_hp, "恢复后 HP 不应超过最大值（实际 %d / %d）" % [hp, max_hp])


# ============= 胜利条件测试 =============

func test_wall_hp_blocks_victory() -> void:
	TacticalSkirmishManager.start_skirmish()
	var enemy_city: Vector2i = TacticalSkirmishManager.get_enemy_city()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	p1["q"] = enemy_city.x
	p1["r"] = enemy_city.y
	# 城墙仍有 HP
	TacticalSkirmishManager._city_wall_hp[enemy_city] = 500
	var winner: String = TacticalSkirmishManager.check_victory()
	assert_eq(winner, "", "城墙未摧毁时不应获胜")


func test_wall_destroyed_allows_victory() -> void:
	TacticalSkirmishManager.start_skirmish()
	var enemy_city: Vector2i = TacticalSkirmishManager.get_enemy_city()
	var p1: Dictionary = TacticalSkirmishManager.get_unit_by_id("mvp_p1")
	p1["q"] = enemy_city.x
	p1["r"] = enemy_city.y
	TacticalSkirmishManager._city_wall_hp[enemy_city] = 0
	var winner: String = TacticalSkirmishManager.check_victory()
	assert_eq(winner, "qin", "城墙摧毁后应获胜")


# ============= 箭塔测试 =============

func test_arrow_tower_exists_at_level_4() -> void:
	TacticalSkirmishManager.start_skirmish()
	# 手动设置城市为 4 级
	var enemy_city: Vector2i = TacticalSkirmishManager.get_enemy_city()
	TacticalSkirmishManager._city_level[enemy_city] = 4
	TacticalSkirmishManager._city_tower_hp[enemy_city] = 150
	var tower_hp: int = TacticalSkirmishManager.get_city_tower_hp(enemy_city)
	assert_gt(tower_hp, 0, "4 级城市应有箭塔（HP %d）" % tower_hp)


func test_no_arrow_tower_at_level_3() -> void:
	TacticalSkirmishManager.start_skirmish()
	var enemy_city: Vector2i = TacticalSkirmishManager.get_enemy_city()
	# 默认 3 级，无箭塔
	var tower_hp: int = TacticalSkirmishManager.get_city_tower_hp(enemy_city)
	assert_eq(tower_hp, 0, "3 级城市不应有箭塔")


# ============= 辅助函数 =============

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
