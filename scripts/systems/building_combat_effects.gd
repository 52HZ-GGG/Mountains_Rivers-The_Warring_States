class_name BuildingCombatEffects

## 建筑战斗效果共享（演武与大地图统一）
## 大地图 CityManager 与演武场景城池共用：从建筑列表汇总攻/防/箭塔/城墙结构。
## 数据：data/buildings.json levels[].effects；场景可自带 buildings 或绑定 city_id。

const WallLib := preload("res://scripts/systems/wall_combat_rules.gd")

const _DEFAULT_TOWER_ATTACK: int = 12


## 从建筑条目列表汇总某一 effects 键（level 对应 levels[level-1]）
static func sum_effect(buildings: Array, effect_key: String) -> float:
	var total: float = 0.0
	for b_v: Variant in buildings:
		if b_v is not Dictionary:
			continue
		var e: Dictionary = b_v as Dictionary
		if bool(e.get("disabled", false)):
			continue
		var bid: String = str(e.get("building_id", e.get("id", "")))
		if bid.is_empty():
			continue
		var bdata: Dictionary = DataManager.get_building(bid)
		if bdata.is_empty():
			continue
		var level: int = int(e.get("level", 1))
		var levels: Array = bdata.get("levels", [])
		if level < 1 or level > levels.size():
			continue
		var effects: Dictionary = (levels[level - 1] as Dictionary).get("effects", {})
		if effects.has(effect_key):
			total += float(effects[effect_key])
	return total


static func defense_bonus_from_buildings(buildings: Array) -> float:
	return sum_effect(buildings, "defense_bonus")


static func attack_bonus_from_buildings(buildings: Array) -> float:
	return sum_effect(buildings, "attack_bonus")


static func tower_attack_from_buildings(buildings: Array) -> float:
	var t: float = sum_effect(buildings, "tower_attack")
	if t <= 0.0:
		return 0.0
	return t


## 城墙 structure_hp：wall 建筑逐条 structure_hp 之和（未禁用）
static func wall_structure_hp_from_buildings(buildings: Array) -> int:
	var total: int = 0
	var any: bool = false
	for b_v: Variant in buildings:
		if b_v is not Dictionary:
			continue
		var e: Dictionary = b_v as Dictionary
		if bool(e.get("disabled", false)):
			continue
		if str(e.get("building_id", e.get("id", ""))) != "wall":
			continue
		any = true
		total += maxi(0, int(e.get("structure_hp", _wall_lv_structure_hp(int(e.get("level", 1))))))
	if not any:
		return 0
	return total


static func _wall_lv_structure_hp(level: int) -> int:
	var wall: Dictionary = DataManager.get_building("wall")
	var levels: Array = wall.get("levels", []) if wall is Dictionary else []
	var lv: int = clampi(level, 1, maxi(1, levels.size()))
	if lv >= 1 and lv <= levels.size():
		return int((levels[lv - 1] as Dictionary).get("effects", {}).get("structure_hp", 150))
	return 150


## 按城级推导默认战斗建筑（场景未写 buildings 时）
## 墙等级默认 1（场景可 wall_level 指定）；城级≥4 有箭塔；≥3 有兵营
static func default_buildings_for_level(city_level: int, is_capital: bool = false, wall_level: int = 1) -> Array:
	var out: Array = []
	var wall_lv: int = clampi(wall_level, 1, 3)
	out.append({"building_id": "wall", "level": wall_lv})
	if city_level >= 3:
		out.append({"building_id": "barracks", "level": 1})
	if city_level >= 4:
		out.append({"building_id": "arrow_tower", "level": clampi(city_level - 3, 1, 3)})
	if is_capital:
		out.append({"building_id": "academy", "level": 1})
	return out


## 从 CityManager 运行时城池拷贝建筑列表（大地图经营结果进演武）
static func buildings_from_city_id(city_id: String) -> Array:
	if city_id.is_empty() or not CityManager.has_method("get_city_state"):
		return []
	var city: Dictionary = CityManager.get_city_state(city_id)
	if city.is_empty():
		return []
	var src: Variant = city.get("buildings", [])
	if src is Array:
		return (src as Array).duplicate(true)
	return []


## 场景 JSON 城配置 → 建筑列表
## 优先级：city_id（读 CityManager）> buildings 字段 > 按城级默认
static func resolve_city_buildings(city_cfg: Dictionary) -> Array:
	var city_id: String = str(city_cfg.get("city_id", ""))
	if city_id != "":
		var from_mgr: Array = buildings_from_city_id(city_id)
		if not from_mgr.is_empty():
			return from_mgr
	if city_cfg.get("buildings") is Array:
		return (city_cfg.get("buildings") as Array).duplicate(true)
	return default_buildings_for_level(
		int(city_cfg.get("level", 3)),
		bool(city_cfg.get("is_capital", false)),
		int(city_cfg.get("wall_level", 1))
	)


## 城防 def 加成：建筑 defense_bonus + 墙 HP 比例城防（WallCombatRules 公式）
## 返回可直接加入 def_ctx["building_def"] 的数值
static func city_building_def_buff(buildings: Array, wall_hp: int, wall_max_hp: int, city_level: int) -> float:
	var base_def: float = WallLib.city_defense_base(city_level)
	# 建筑 defense_bonus 按乘法并入城防基数，再按墙 HP 比例缩放（与大地图 get_city_defense 语义一致）
	var b_bonus: float = defense_bonus_from_buildings(buildings)
	var scaled_base: float = base_def * (1.0 + b_bonus)
	return WallLib.wall_defense_buff(wall_hp, wall_max_hp, scaled_base)


## 城攻击（驻军/城反击）：基数 + 建筑 attack_bonus
static func city_attack_with_buildings(city_level: int, buildings: Array, garrison: int = 0) -> int:
	var cfg: Variant = DataManager.get_balance_param("city_levels")
	var base_atk: int = 10
	if cfg is Dictionary:
		base_atk = int((cfg as Dictionary).get(str(city_level), {}).get("attack", 5))
	var mult: float = 1.0 + attack_bonus_from_buildings(buildings)
	var total: int = int(float(base_atk) * mult)
	if garrison > 0:
		var per: float = float(DataManager.get_balance_param("stability.garrison_atk_per_unit"))
		total += int(garrison * per)
	return total
