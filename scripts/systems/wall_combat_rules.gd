class_name WallCombatRules

## 城墙/攻城共享规则（演武与大地图统一规范 §7）
## 大地图 SiegeResolver 与演武攻击管线必须共用本模块，禁止各拼一套伤害分流。
## 数值一律读 data/balance_params.json。

const CombatLib := preload("res://scripts/systems/combat_resolver.gd")


## 器械倍率：siege 兵种/特殊为 city_combat.siege_damage_multiplier，否则 1.0
static func siege_multiplier(unit_type_id: String) -> float:
	var udata: Dictionary = DataManager.get_unit_type(unit_type_id)
	if udata.is_empty():
		return 1.0
	var special: String = str(udata.get("special", ""))
	var is_siege: bool = special == "siege" or special == "siege_bonus" or str(udata.get("category", "")) == "siege"
	if not is_siege:
		return 1.0
	var mult_v: Variant = DataManager.get_balance_param("city_combat.siege_damage_multiplier")
	return float(mult_v) if mult_v != null else 3.0


static func is_siege_unit(unit_type_id: String) -> bool:
	return siege_multiplier(unit_type_id) > 1.0 + 0.0001 or _flag_is_siege(unit_type_id)


static func _flag_is_siege(unit_type_id: String) -> bool:
	var udata: Dictionary = DataManager.get_unit_type(unit_type_id)
	if udata.is_empty():
		return false
	var special: String = str(udata.get("special", ""))
	return special == "siege" or special == "siege_bonus" or str(udata.get("category", "")) == "siege"


## 城墙结构防御（按城级）
static func wall_struct_def(city_level: int) -> float:
	var wsdef_v: Variant = DataManager.get_balance_param("city_combat.wall_struct_def_by_level")
	if wsdef_v is Dictionary:
		var lv_val: Variant = (wsdef_v as Dictionary).get(str(city_level), null)
		if lv_val != null:
			return float(lv_val)
	return 8.0


## 城防基数（city_levels[level].city_defense）；缺省时用演武历史默认 45
static func city_defense_base(city_level: int) -> float:
	var clv: Variant = DataManager.get_balance_param("city_levels")
	if clv is Dictionary:
		var cld: Dictionary = (clv as Dictionary).get(str(city_level), {})
		if cld is Dictionary and not cld.is_empty():
			return float(cld.get("city_defense", 45))
	return 45.0


## 将总伤害按统一公式拆到城墙/城体（有墙时）
## wall_hp>=0 表示存在城墙段；返回 {wall_damage, city_damage}
static func split_damage_to_wall(
	total_damage: int,
	unit_type_id: String,
	city_level: int,
	has_wall: bool
) -> Dictionary:
	if total_damage <= 0:
		return {"wall_damage": 0, "city_damage": 0}
	if not has_wall:
		return {"wall_damage": 0, "city_damage": total_damage}
	var split_wall_v: Variant = DataManager.get_balance_param("city_combat.damage_split_wall")
	var split_wall: float = float(split_wall_v) if split_wall_v != null else 0.5
	var siege_factor: float = siege_multiplier(unit_type_id)
	var coeff: float = 20.0
	var wall_def: float = wall_struct_def(city_level)
	var wall_dmg: int = maxi(0, int(float(total_damage) * split_wall * siege_factor * coeff / (coeff + wall_def)))
	var city_dmg: int = maxi(0, total_damage - wall_dmg)
	return {"wall_damage": wall_dmg, "city_damage": city_dmg}


## 直接对墙/城体的攻城伤害（城墙未破打墙；已破打城体）
## base_attack 为单位面板攻击（可已乘演示倍率等场景系数）
static func direct_wall_or_city_damage(
	base_attack: float,
	unit_type_id: String,
	city_level: int,
	wall_hp: int
) -> int:
	var siege_factor: float = siege_multiplier(unit_type_id)
	var coeff: float = 20.0
	if wall_hp > 0:
		var wdef: float = wall_struct_def(city_level)
		return maxi(1, int(base_attack * siege_factor * coeff / (coeff + wdef)))
	var cdef: float = city_defense_base(city_level)
	return maxi(1, int(base_attack * siege_factor * coeff / (coeff + cdef)))


## 城防对单位战斗的 def 加成比例（墙 HP 比例 × city_defense / 100，下限 wall_defense_min_ratio）
static func wall_defense_buff(wall_hp: int, wall_max_hp: int, city_defense_base_val: float) -> float:
	if wall_hp <= 0:
		return 0.0
	var wr: float = float(wall_hp) / float(wall_max_hp) if wall_max_hp > 0 else 1.0
	var mrv: Variant = DataManager.get_balance_param("city_combat.wall_defense_min_ratio")
	var mr: float = float(mrv) if mrv != null else 0.5
	return city_defense_base_val * maxf(wr, mr) / 100.0
