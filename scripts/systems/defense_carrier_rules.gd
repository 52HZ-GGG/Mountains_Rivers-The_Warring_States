class_name DefenseCarrierRules

## 防御地块载体统一规则：城市 / 关隘 / 防御建筑
## 共享攻城结构伤害与占领条件（战斗系统 §7）

const COEFF: float = 20.0


static func siege_mult(unit_type_id: String) -> float:
	var udata: Dictionary = DataManager.get_unit_type(unit_type_id)
	if udata.is_empty():
		return 1.0
	var special: String = str(udata.get("special", ""))
	var cat: String = str(udata.get("category", ""))
	if special == "siege" or special == "siege_bonus" or cat == "siege":
		var v: Variant = DataManager.get_balance_param("city_combat.siege_damage_multiplier")
		return float(v) if v != null else 3.0
	return 1.0


static func terrain_atk_mod(terrain_id: String) -> float:
	var t: Dictionary = DataManager.get_terrain(terrain_id)
	return float(t.get("atk_mod", 1.0))


static func terrain_def_mod(terrain_id: String) -> float:
	var t: Dictionary = DataManager.get_terrain(terrain_id)
	return float(t.get("def_mod", 1.0))


## 结构伤害：effective_atk × terrain_atk × siege_mult × COEFF/(COEFF+struct_def)
static func structure_damage(
	base_atk: float,
	unit_type_id: String,
	struct_def: float,
	terrain_id: String = "",
	apply_terrain: bool = true
) -> int:
	var atk: float = maxf(0.0, base_atk)
	if apply_terrain and terrain_id != "":
		atk *= terrain_atk_mod(terrain_id)
	var mult: float = siege_mult(unit_type_id)
	var def: float = maxf(0.0, struct_def)
	var dmg: float = atk * mult * COEFF / (COEFF + def)
	return maxi(1, int(floor(dmg)))


## 关隘结构伤（地形始终生效）
static func pass_structure_damage(base_atk: float, unit_type_id: String) -> int:
	var sdef_v: Variant = DataManager.get_balance_param("fortification.pass_struct_def")
	var sdef: float = float(sdef_v) if sdef_v != null else 10.0
	return structure_damage(base_atk, unit_type_id, sdef, "pass", true)


## 建筑结构伤（buildings.json levels effects.structure 防御或默认）
static func building_structure_damage(
	base_atk: float,
	unit_type_id: String,
	building_id: String,
	level: int,
	terrain_id: String = ""
) -> int:
	var sdef: float = building_struct_def(building_id, level)
	return structure_damage(base_atk, unit_type_id, sdef, terrain_id, terrain_id != "")


static func building_struct_def(building_id: String, level: int) -> float:
	var b: Dictionary = DataManager.get_building(building_id)
	if b.is_empty():
		return 5.0
	var effects_key: String = "structure_def"
	var levels: Array = b.get("levels", []) as Array
	var lv: int = clampi(level, 1, maxi(levels.size(), 1))
	if lv >= 1 and lv <= levels.size():
		var effects: Dictionary = (levels[lv - 1] as Dictionary).get("effects", {}) as Dictionary
		if effects.has(effects_key):
			return float(effects[effects_key])
		if effects.has("structure_hp"):
			# 无显式防御时，用结构血量弱相关推断，避免硬编码 5 过弱/过强
			return clampf(float(effects["structure_hp"]) / 30.0, 4.0, 16.0)
	return 5.0


## 占领条件：结构 HP≤0 且无驻军；调用方再要求己方单位上格
static func can_capture_structure(structure_hp: int, has_garrison: bool) -> bool:
	return structure_hp <= 0 and not has_garrison


## 建筑独立占领：不改变城主；改建筑 owner + HP 恢复 30%
static func capture_building_entry(entry: Dictionary, new_owner: String) -> Dictionary:
	if entry.is_empty():
		return {"ok": false, "reason": "NO_ENTRY"}
	if int(entry.get("structure_hp", 1)) > 0:
		return {"ok": false, "reason": "STRUCTURE_STANDING"}
	var max_hp: int = int(entry.get("max_structure_hp", entry.get("structure_hp", 0)))
	var ratio_v: Variant = DataManager.get_balance_param("city_combat.capture_restore_ratio")
	var ratio: float = float(ratio_v) if ratio_v != null else 0.3
	entry["owner"] = new_owner
	entry["structure_hp"] = maxi(1, int(float(maxi(max_hp, 1)) * ratio))
	entry["disabled"] = false
	return {"ok": true, "entry": entry, "owner": new_owner}
