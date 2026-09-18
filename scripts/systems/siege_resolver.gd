class_name SiegeResolver

## 共享攻城结算（统一规范 §7）
## 器械倍率、城防乘法模型、城墙伤害分流、驻军反击。
## 预检（宣战/acted/距离）由适配层完成。

const HexLib := preload("res://scripts/systems/hex_axial.gd")
const CombatLib := preload("res://scripts/systems/combat_resolver.gd")
const CtxLib := preload("res://scripts/systems/combat_ctx_builder.gd")


static func is_siege_unit(unit_type_id: String) -> bool:
	var udata: Dictionary = DataManager.get_unit_type(unit_type_id)
	if udata.is_empty():
		return false
	if str(udata.get("special", "")) == "siege":
		return true
	return str(udata.get("category", "")) == "siege"


static func siege_multiplier(unit_type_id: String) -> float:
	if is_siege_unit(unit_type_id):
		var mult_v: Variant = DataManager.get_balance_param("city_combat.siege_damage_multiplier")
		return float(mult_v) if mult_v != null else 3.0
	return 1.0


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

	# 墙壁分流：有墙时先伤墙，余量伤城体
	var wall_hp: int = -1
	var wall_max: int = 0
	if CityManager.has_method("get_wall_hp"):
		wall_hp = CityManager.get_wall_hp(city_id)
		wall_max = CityManager.get_wall_max_hp(city_id) if CityManager.has_method("get_wall_max_hp") else 0
	var wall_dmg: int = 0
	var city_dmg: int = dmg
	if wall_hp >= 0:
		var split_wall_v: Variant = DataManager.get_balance_param("city_combat.damage_split_wall")
		var split_wall: float = float(split_wall_v) if split_wall_v != null else 0.5
		var siege_factor: float = siege_multiplier(unit_type_id)
		var coeff: float = 20.0
		var wall_struct_def: float = 8.0
		var wsdef_v: Variant = DataManager.get_balance_param("city_combat.wall_struct_def_by_level")
		if wsdef_v is Dictionary:
			var lv: int = int(CityManager.get_city_state(city_id).get("city_level", 1))
			var lv_val: Variant = (wsdef_v as Dictionary).get(str(lv), null)
			if lv_val != null:
				wall_struct_def = float(lv_val)
		wall_dmg = maxi(0, int(float(dmg) * split_wall * siege_factor * coeff / (coeff + wall_struct_def)))
		city_dmg = maxi(0, dmg - wall_dmg)

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
