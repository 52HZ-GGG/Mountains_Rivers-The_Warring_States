class_name SiegeResolver

## 共享攻城结算（统一规范 §7）
## 器械倍率、城防乘法模型、城墙伤害分流、驻军反击。
## 预检（宣战/acted/距离）由适配层完成。

const HexLib := preload("res://scripts/systems/hex_axial.gd")
const CombatLib := preload("res://scripts/systems/combat_resolver.gd")
const CtxLib := preload("res://scripts/systems/combat_ctx_builder.gd")
const WallLib := preload("res://scripts/systems/wall_combat_rules.gd")
const CarrierLib := preload("res://scripts/systems/defense_carrier_rules.gd")


static func is_siege_unit(unit_type_id: String) -> bool:
	return WallLib.is_siege_unit(unit_type_id)


static func siege_multiplier(unit_type_id: String) -> float:
	return WallLib.siege_multiplier(unit_type_id)


## 关隘结构攻城（共享：地形×0.5 + 器械倍率 + COEFF 模型）
static func compute_pass_attack(attacker_unit: Dictionary, pass_axial: Vector2i) -> Dictionary:
	var unit_type_id: String = str(attacker_unit.get("unit_type_id", ""))
	var a_type: Dictionary = DataManager.get_unit_type(unit_type_id)
	var faction_id: String = str(attacker_unit.get("faction_id", ""))
	var skills: Array = attacker_unit.get("skills", []) if attacker_unit.get("skills") is Array else []
	var atk_ctx: Dictionary = CtxLib.build_attack_ctx(faction_id, unit_type_id, skills)
	var base_atk: float = float(a_type.get("attack", 10))
	var tech_atk: float = float(atk_ctx.get("tech_atk", 0.0))
	var school_atk: float = float(atk_ctx.get("school_atk", 0.0))
	var faction_atk: float = float(atk_ctx.get("faction_atk", 0.0))
	var minister_pct: float = float(atk_ctx.get("minister_bravery_pct", 0.0))
	base_atk *= (1.0 + tech_atk + school_atk + faction_atk + minister_pct)
	base_atk += float(atk_ctx.get("unit_ability_bonus", 0.0))
	var dmg: int = CarrierLib.pass_structure_damage(base_atk, unit_type_id)
	var res: Dictionary = PassManager.damage_pass(pass_axial, dmg)
	return {
		"ok": bool(res.get("ok", false)),
		"damage": dmg,
		"hp": int(res.get("hp", -1)),
		"destroyed": bool(res.get("destroyed", false)),
		"owner": PassManager.get_pass_owner(pass_axial),
	}


## 防御建筑结构攻城（buildings.json struct_def + 可选地形）
static func compute_fortification_attack(attacker_unit: Dictionary, target_axial: Vector2i) -> Dictionary:
	var unit_type_id: String = str(attacker_unit.get("unit_type_id", ""))
	var a_type: Dictionary = DataManager.get_unit_type(unit_type_id)
	var faction_id: String = str(attacker_unit.get("faction_id", ""))
	var skills: Array = attacker_unit.get("skills", []) if attacker_unit.get("skills") is Array else []
	var atk_ctx: Dictionary = CtxLib.build_attack_ctx(faction_id, unit_type_id, skills)
	var base_atk: float = float(a_type.get("attack", 10))
	var tech_atk2: float = float(atk_ctx.get("tech_atk", 0.0))
	var school_atk2: float = float(atk_ctx.get("school_atk", 0.0))
	var faction_atk2: float = float(atk_ctx.get("faction_atk", 0.0))
	var minister_pct2: float = float(atk_ctx.get("minister_bravery_pct", 0.0))
	base_atk *= (1.0 + tech_atk2 + school_atk2 + faction_atk2 + minister_pct2)
	base_atk += float(atk_ctx.get("unit_ability_bonus", 0.0))
	var b: Dictionary = CityManager.get_building_at_hex(target_axial)
	if b.is_empty():
		return {"ok": false, "reason": "NOT_DEFENSE_BUILDING"}
	var bid: String = str(b.get("building_id", ""))
	var level: int = int(b.get("level", 1))
	var off: Vector2i = HexLib.axial_to_offset_odd_r(target_axial.x, target_axial.y)
	var terrain_id: String = CityManager.get_big_map_terrain_id(off.x, off.y)
	var dmg: int = CarrierLib.building_structure_damage(base_atk, unit_type_id, bid, level, terrain_id)
	var result: Dictionary = CityManager.damage_building_at_hex(target_axial, dmg)
	return {
		"ok": true,
		"damage": dmg,
		"destroyed": bool(result.get("destroyed", false)),
		"remaining_hp": int(result.get("remaining_hp", 0)),
		"building_id": bid,
		"owner": str(result.get("owner", "")),
	}


## 计算对城池的总伤害（含 ctx 与器械倍率），并拆分到城墙/城体
static func compute_city_attack(
	attacker_unit: Dictionary,
	city_id: String,
	rng: RandomNumberGenerator
) -> Dictionary:
	var unit_type_id: String = str(attacker_unit.get("unit_type_id", ""))
	var count: int = maxi(1, int(attacker_unit.get("count", 1)))
	var city_def: int = CityManager.get_city_defense(city_id)
	var city_hp: int = CityManager.get_city_hp(city_id)
	var faction_id: String = str(attacker_unit.get("faction_id", ""))
	var skills: Array = attacker_unit.get("skills", []) if attacker_unit.get("skills") is Array else []
	var atk_ctx: Dictionary = CtxLib.build_attack_ctx(faction_id, unit_type_id, skills)
	atk_ctx["siege_mult"] = siege_multiplier(unit_type_id)

	var result: Dictionary = CombatLib.compute_siege_damage(
		unit_type_id, count, city_def, city_hp, rng, atk_ctx
	)
	var dmg: int = int(result.get("damage", 0))

	# 墙壁分流：与演武共用 WallCombatRules（统一规范 §7）
	var wall_hp: int = -1
	if CityManager.has_method("get_wall_hp"):
		wall_hp = CityManager.get_wall_hp(city_id)
	var city_state: Dictionary = CityManager.get_city_state(city_id)
	var city_level: int = int(city_state.get("city_level", 1))
	var split: Dictionary = WallLib.split_damage_to_wall(dmg, unit_type_id, city_level, wall_hp >= 0)
	var wall_dmg: int = int(split.get("wall_damage", 0))
	var city_dmg: int = int(split.get("city_damage", dmg))

	var wall_result: Dictionary = {}
	if wall_dmg > 0 and CityManager.has_method("damage_wall"):
		wall_result = CityManager.damage_wall(city_id, wall_dmg)
	if city_dmg > 0:
		var city_result: Dictionary = CityManager.damage_city(city_id, city_dmg)
		return {
			"damage": dmg,
			"wall_damage": wall_dmg,
			"city_damage": city_dmg,
			"wall_destroyed": bool(wall_result.get("destroyed", false)),
			"city_destroyed": bool(city_result.get("destroyed", false)),
			"has_wall": wall_hp >= 0,
		}
	# 仅伤墙
	return {
		"damage": dmg,
		"wall_damage": wall_dmg,
		"city_damage": city_dmg,
		"wall_destroyed": bool(wall_result.get("destroyed", false)),
		"city_destroyed": false,
		"has_wall": wall_hp >= 0,
	}


## 城防对攻城单位的反击
static func city_counter_damage(city_id: String, defender_unit: Dictionary, rng: RandomNumberGenerator) -> int:
	var city_attack: int = CityManager.get_city_attack(city_id)
	if city_attack <= 0:
		return 0
	var city_level: int = int(CityManager.get_city_state(city_id).get("city_level", 1))
	var unit_type_id: String = str(defender_unit.get("unit_type_id", "militia"))
	var count: int = maxi(1, int(defender_unit.get("count", 1)))
	var result: Dictionary = CombatLib.compute_city_counter_damage(
		city_attack, city_level, unit_type_id, count, rng
	)
	return maxi(0, int(result.get("damage", 0)))
