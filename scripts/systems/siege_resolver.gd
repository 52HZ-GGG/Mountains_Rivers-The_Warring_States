class_name SiegeResolver

## 共享攻城结算（统一规范 §7）
## 器械倍率、城防乘法模型、城墙伤害分流、驻军反击。
## 预检（宣战/acted/距离）由适配层完成。

const HexLib := preload("res://scripts/systems/hex_axial.gd")
const CombatLib := preload("res://scripts/systems/combat_resolver.gd")
const CtxLib := preload("res://scripts/systems/combat_ctx_builder.gd")
const WallLib := preload("res://scripts/systems/wall_combat_rules.gd")


static func is_siege_unit(unit_type_id: String) -> bool:
	return WallLib.is_siege_unit(unit_type_id)


static func siege_multiplier(unit_type_id: String) -> float:
	return WallLib.siege_multiplier(unit_type_id)


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
