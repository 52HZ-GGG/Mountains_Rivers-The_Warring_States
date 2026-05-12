extends RefCounted

## 战术战斗结算 — 对齐 docs/数值公式.md §1（阶段 1 MVP：将领/派系加成固定为 1.0）

static func morale_attack_multiplier(attacker_morale: int) -> float:
	var floor_v: Variant = DataManager.get_balance_param("combat.morale_atk_floor")
	var ceil_v: Variant = DataManager.get_balance_param("combat.morale_atk_ceil")
	var f: float = float(floor_v) if floor_v != null else 0.7
	var c: float = float(ceil_v) if ceil_v != null else 1.0
	var mor: float = clampf(float(attacker_morale) / 100.0, 0.0, 1.0)
	return f + (c - f) * mor


static func compute_damage(
	p_attacker_type_id: String,
	p_defender_type_id: String,
	p_defender_terrain_id: String,
	p_attacker_morale: int,
	_p_defender_morale: int,
	p_rng: RandomNumberGenerator,
) -> Dictionary:
	var atk_unit: Dictionary = DataManager.get_unit_type(p_attacker_type_id)
	var def_unit: Dictionary = DataManager.get_unit_type(p_defender_type_id)
	var terrain: Dictionary = DataManager.get_terrain(p_defender_terrain_id)
	if atk_unit.is_empty() or def_unit.is_empty():
		return {"damage": 0, "was_ambush": false, "skipped": true}

	var atk_general_mod: float = 1.0
	var atk_faction_mod: float = 1.0
	var terrain_atk_mod: float = float(terrain.get("atk_mod", 1.0))
	var morale_atk_mod: float = morale_attack_multiplier(p_attacker_morale)

	var base_dmg: float = float(atk_unit.get("attack", 0))
	base_dmg *= atk_general_mod * terrain_atk_mod * atk_faction_mod * morale_atk_mod

	var def_general_mod: float = 1.0
	var def_faction_mod: float = 1.0
	var terrain_def_mod: float = float(terrain.get("def_mod", 1.0))

	var base_def: float = float(def_unit.get("defense", 0))
	base_def *= def_general_mod * terrain_def_mod * def_faction_mod

	var raw_dmg: float = maxf(base_dmg - base_def, 1.0)

	var rmin: Variant = DataManager.get_balance_param("combat.random_damage_min")
	var rmax: Variant = DataManager.get_balance_param("combat.random_damage_max")
	var rd_lo: float = float(rmin) if rmin != null else 0.9
	var rd_hi: float = float(rmax) if rmax != null else 1.1
	var spread: float = p_rng.randf_range(rd_lo, rd_hi)
	var dmg: float = raw_dmg * spread

	var counter: float = DataManager.get_counter_multiplier(p_attacker_type_id, p_defender_type_id)
	dmg *= counter

	var ambush_base: Variant = DataManager.get_balance_param("combat.ambush_base_chance")
	var ab: float = float(ambush_base) if ambush_base != null else 0.05
	var terrain_ambush: float = float(terrain.get("ambush_chance", 0.0))
	var ambush_p: float = clampf(ab + terrain_ambush, 0.0, 0.95)
	var was_ambush: bool = p_rng.randf() < ambush_p
	var ambush_mult_v: Variant = DataManager.get_balance_param("combat.ambush_damage_multiplier")
	var amb_mult: float = float(ambush_mult_v) if ambush_mult_v != null else 2.0
	if was_ambush:
		dmg *= amb_mult

	return {"damage": int(floor(dmg)), "was_ambush": was_ambush, "skipped": false}
