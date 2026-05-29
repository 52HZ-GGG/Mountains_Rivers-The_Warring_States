class_name CombatResolver
extends RefCounted

## 战斗伤害结算器 — 对齐 docs/机制概览/战斗系统.md §2
##
## 纯函数模块，所有状态通过参数传入，无副作用。
## 公式流程：攻防加法层 → 克制乘算 → 扣减防御 → 随机波动 → 崩溃态乘算

# ============= 攻击加法层（纯计算，无 DataManager 依赖）============

static func _calc_atk_buff(ctx: Dictionary) -> float:
	var buff: float = 1.0
	buff += ctx.get("terrain_atk_offset", 0.0)
	buff += ctx.get("minister_bravery_pct", 0.0)
	buff += ctx.get("faction_atk", 0.0)
	buff += ctx.get("morale_atk_offset", 0.0)
	if ctx.get("is_ambush", false):
		buff += ctx.get("ambush_bonus", 0.3)
	elif ctx.get("is_fire_attack", false):
		buff += ctx.get("fire_bonus", 0.4)
	buff += ctx.get("school_atk", 0.0)
	buff += ctx.get("tech_atk", 0.0)
	buff += ctx.get("unit_ability_bonus", 0.0)
	return buff


# ============= 防御加法层（纯计算，无 DataManager 依赖）============

static func _calc_def_buff(ctx: Dictionary) -> float:
	var buff: float = 1.0
	buff += ctx.get("terrain_def_offset", 0.0)
	buff += ctx.get("minister_strategy_pct", 0.0)
	buff += ctx.get("faction_def", 0.0)
	buff += ctx.get("school_def", 0.0)
	buff += ctx.get("tech_def", 0.0)
	buff += ctx.get("building_def", 0.0)
	return buff


# ============= 士气攻击偏移（纯计算，无 DataManager 依赖）============

static func _get_morale_atk_offset(morale: int, params: Dictionary) -> float:
	var high_threshold: int = int(params.get("high_morale_threshold", 130))
	var low_threshold: int = int(params.get("low_morale_threshold", 50))
	var high_bonus: float = float(params.get("high_morale_atk_bonus", 0.1))
	var low_penalty: float = float(params.get("low_morale_atk_penalty", -0.1))
	var break_threshold: int = int(params.get("morale_break_threshold", 20))

	if morale < break_threshold:
		return 0.0
	if morale >= high_threshold:
		return high_bonus
	if morale < low_threshold:
		return low_penalty
	return 0.0


# ============= 克制乘算（需要 DataManager）=============

func compute_counter_multiplier(attacker_type_id: String, defender_type_id: String) -> float:
	var atk_unit: Dictionary = DataManager.get_unit_type(attacker_type_id)
	var def_unit: Dictionary = DataManager.get_unit_type(defender_type_id)
	if atk_unit.is_empty() or def_unit.is_empty():
		return 1.0

	# anti_cavalry 覆盖：枪刺兵对骑兵类强制 1.2
	var atk_special = atk_unit.get("special", "")
	if atk_special == "anti_cavalry":
		var def_cat = def_unit.get("category", "")
		if def_cat == "cavalry":
			return float(atk_unit.get("special_value", 1.2))

	return DataManager.get_counter_multiplier(attacker_type_id, defender_type_id)


# ============= 崩溃态士气修正（纯计算，无 DataManager 依赖）============

static func morale_defense_multiplier(defender_morale: int, break_threshold: int = 20) -> float:
	if defender_morale < break_threshold:
		return 0.5
	return 1.0


# ============= 远程判断（需要 DataManager）=============

func is_ranged_unit(unit_type_id: String) -> bool:
	var unit: Dictionary = DataManager.get_unit_type(unit_type_id)
	if unit.is_empty():
		return false
	return unit.get("special", "") == "ranged" or unit.get("ranged_attack_mode", "") == "no_counter"


# ============= 远程精度修正（需要 DataManager）=============

func compute_ranged_spread(
	base_lo: float,
	base_hi: float,
	terrain_id: String,
	is_ranged: bool,
) -> Vector2:
	if not is_ranged:
		return Vector2(base_lo, base_hi)
	var terrain: Dictionary = DataManager.get_terrain(terrain_id)
	var accuracy: float = float(terrain.get("ranged_accuracy_mod", 0))
	var factor_v: Variant = DataManager.get_balance_param("combat.accuracy_spread_factor")
	var factor: float = float(factor_v) if factor_v != null else 0.001
	var offset: float = accuracy * factor
	return Vector2(base_lo + offset, base_hi + offset)


# ============= 反击触发判断（纯逻辑）=============

static func should_trigger_counter(_defender_type_id: String, is_ranged_attack: bool) -> bool:
	if is_ranged_attack:
		return false
	return true


# ============= 动能攻击（需要 DataManager）=============

func get_momentum_bonus(tiles_moved: int) -> float:
	if tiles_moved <= 0:
		return 0.0
	var max_bonus_v: Variant = DataManager.get_balance_param("combat.momentum_max_bonus")
	var max_bonus: float = float(max_bonus_v) if max_bonus_v != null else 0.25
	var bonus: float = tiles_moved * 0.05
	return minf(bonus, max_bonus)


# ============= 完整伤害计算（需要 DataManager）=============

func compute_damage(
	p_attacker_type_id: String,
	p_defender_type_id: String,
	p_defender_terrain_id: String,
	p_attacker_morale: int,
	p_defender_morale: int,
	p_rng: RandomNumberGenerator,
	p_atk_ctx: Dictionary = {},
	p_def_ctx: Dictionary = {},
) -> Dictionary:
	var atk_unit: Dictionary = DataManager.get_unit_type(p_attacker_type_id)
	var def_unit: Dictionary = DataManager.get_unit_type(p_defender_type_id)
	var terrain: Dictionary = DataManager.get_terrain(p_defender_terrain_id)
	if atk_unit.is_empty() or def_unit.is_empty() or terrain.is_empty():
		return {"damage": 0, "was_ambush": false, "skipped": true}

	# 士气参数
	var morale_params: Dictionary = {}
	var bp: Variant = DataManager.get_balance_param("unit_morale")
	if bp is Dictionary:
		morale_params = bp

	# --- 攻击加法层 ---
	var atk_ctx: Dictionary = p_atk_ctx.duplicate()
	atk_ctx["terrain_atk_offset"] = float(terrain.get("atk_mod", 1.0)) - 1.0
	atk_ctx["morale_atk_offset"] = _get_morale_atk_offset(p_attacker_morale, morale_params)
	var atk_buff: float = _calc_atk_buff(atk_ctx)
	var base_atk_val: float = float(p_atk_ctx.get("override_attack", atk_unit.get("attack", 0)))
	var effective_atk: float = base_atk_val * atk_buff

	# 崩溃态独立乘算（攻击）
	var break_threshold: int = int(morale_params.get("morale_break_threshold", 20))
	effective_atk *= morale_defense_multiplier(p_attacker_morale, break_threshold)

	# --- 防御加法层 ---
	var def_ctx: Dictionary = p_def_ctx.duplicate()
	def_ctx["terrain_def_offset"] = float(terrain.get("def_mod", 1.0)) - 1.0
	var def_buff: float = _calc_def_buff(def_ctx)
	var effective_def: float = float(def_unit.get("defense", 0)) * def_buff

	# 崩溃态独立乘算（防御）
	effective_def *= morale_defense_multiplier(p_defender_morale, break_threshold)

	# --- 克制乘算 ---
	var counter: float = compute_counter_multiplier(p_attacker_type_id, p_defender_type_id)
	var counter_dmg: float = effective_atk * counter

	# --- 扣减防御，保底 1 ---
	var raw_dmg: float = maxf(counter_dmg - effective_def, 1.0)

	# --- 随机波动（受远程精度修正影响）---
	var rmin: Variant = DataManager.get_balance_param("combat.base_random_spread_lo")
	var rmax: Variant = DataManager.get_balance_param("combat.base_random_spread_hi")
	var rd_lo: float = float(rmin) if rmin != null else 0.9
	var rd_hi: float = float(rmax) if rmax != null else 1.1
	var ranged: bool = is_ranged_unit(p_attacker_type_id)
	var spread: Vector2 = compute_ranged_spread(rd_lo, rd_hi, p_defender_terrain_id, ranged)
	var rand_spread: float = p_rng.randf_range(spread.x, spread.y)
	var dmg: float = raw_dmg * rand_spread

	# --- 伏击判定 ---
	var was_ambush: bool = false
	if not atk_ctx.get("is_fire_attack", false):
		var ambush_base_v: Variant = DataManager.get_balance_param("combat.ambush_base_chance")
		var ab: float = float(ambush_base_v) if ambush_base_v != null else 0.05
		var terrain_ambush: float = float(terrain.get("ambush_chance", 0.0))
		var cap_v: Variant = DataManager.get_balance_param("combat.ambush_chance_cap")
		var cap: float = float(cap_v) if cap_v != null else 0.95
		var ambush_p: float = clampf(ab + terrain_ambush, 0.0, cap)
		was_ambush = p_rng.randf() < ambush_p

	return {"damage": int(floor(dmg)), "was_ambush": was_ambush, "skipped": false, "effective_atk": effective_atk}


# ============= 反击伤害计算（需要 DataManager）=============

func compute_counter_attack(
	p_counter_attacker_type_id: String,
	p_counter_defender_type_id: String,
	p_counter_defender_terrain_id: String,
	p_counter_attacker_morale: int,
	p_counter_defender_morale: int,
	p_rng: RandomNumberGenerator,
	p_atk_ctx: Dictionary = {},
	p_def_ctx: Dictionary = {},
) -> Dictionary:
	return compute_damage(
		p_counter_attacker_type_id,
		p_counter_defender_type_id,
		p_counter_defender_terrain_id,
		p_counter_attacker_morale,
		p_counter_defender_morale,
		p_rng,
		p_atk_ctx,
		p_def_ctx,
	)


# ============= 攻城伤害计算（Phase 4）=============

## 计算军队对城池的伤害。
## 公式：damage = (军队总攻击力 × 攻城加成 - 城池防御) × 随机波动，保底 1。
static func compute_siege_damage(
	attacker_unit_id: String,
	attacker_count: int,
	city_defense: int,
	city_hp: int,
	p_rng: RandomNumberGenerator,
	atk_ctx: Dictionary = {},
) -> Dictionary:
	var unit_data: Dictionary = DataManager.get_unit_type(attacker_unit_id)
	if unit_data.is_empty() or attacker_count <= 0:
		return {"damage": 0, "city_destroyed": false}
	var base_atk: float = float(unit_data.get("attack", 0)) * attacker_count
	# 攻城加成（special = "siege"）
	var siege_bonus: float = 1.0
	if unit_data.get("special", "") == "siege":
		siege_bonus = float(unit_data.get("special_value", 2.0))
	# 攻击加法层
	var atk_buff: float = 1.0
	atk_buff += atk_ctx.get("tech_atk", 0.0)
	atk_buff += atk_ctx.get("faction_atk", 0.0)
	atk_buff += atk_ctx.get("morale_atk_offset", 0.0)
	var effective_atk: float = base_atk * atk_buff * siege_bonus
	# 扣减城防
	var raw_dmg: float = maxf(effective_atk - float(city_defense), 1.0)
	# 随机波动
	var rmin: Variant = DataManager.get_balance_param("combat.base_random_spread_lo")
	var rmax: Variant = DataManager.get_balance_param("combat.base_random_spread_hi")
	var rd_lo: float = float(rmin) if rmin != null else 0.9
	var rd_hi: float = float(rmax) if rmax != null else 1.1
	var rand_spread: float = p_rng.randf_range(rd_lo, rd_hi)
	var dmg: float = raw_dmg * rand_spread
	var final_dmg: int = int(floor(maxf(dmg, 1.0)))
	return {"damage": final_dmg, "city_destroyed": final_dmg >= city_hp}


## 计算城池对攻城军队的反击伤害。
## 公式：damage = (城池攻击 × 城级) - (军队总防御 × 数量 × 0.1)，保底 1。
static func compute_city_counter_damage(
	city_attack: int,
	city_level: int,
	defender_unit_id: String,
	defender_count: int,
	p_rng: RandomNumberGenerator,
) -> Dictionary:
	var unit_data: Dictionary = DataManager.get_unit_type(defender_unit_id)
	if unit_data.is_empty() or defender_count <= 0:
		return {"damage": 0}
	var base_city_atk: float = float(city_attack) * float(city_level)
	var unit_def: float = float(unit_data.get("defense", 0)) * defender_count * 0.1
	var raw_dmg: float = maxf(base_city_atk - unit_def, 1.0)
	var rmin: Variant = DataManager.get_balance_param("combat.base_random_spread_lo")
	var rmax: Variant = DataManager.get_balance_param("combat.base_random_spread_hi")
	var rd_lo: float = float(rmin) if rmin != null else 0.9
	var rd_hi: float = float(rmax) if rmax != null else 1.1
	var rand_spread: float = p_rng.randf_range(rd_lo, rd_hi)
	var dmg: float = raw_dmg * rand_spread
	return {"damage": int(floor(maxf(dmg, 1.0)))}
