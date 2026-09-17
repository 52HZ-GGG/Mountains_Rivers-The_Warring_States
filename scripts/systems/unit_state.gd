class_name UnitState

## UnitState 权威 schema（演武与大地图统一规范 §3）
## schema_version 3：mp/max_mp 为序列化字段名；补 skills/is_supplied/attacks_this_turn 等。

const SCHEMA_VERSION: int = 3


static func make(
	faction_id: String,
	unit_type_id: String,
	axial_q: int,
	axial_r: int,
	hp: int,
	max_mp: int,
	count: int = 1,
	unit_id: String = "",
	col: int = -1,
	row: int = -1,
	skills: Array = []
) -> Dictionary:
	return {
		"id": unit_id,
		"faction_id": faction_id,
		"unit_type_id": unit_type_id,
		"q": axial_q,
		"r": axial_r,
		"col": col,
		"row": row,
		"hp": hp,
		"max_hp": hp,
		"mp": max_mp,
		"max_mp": max_mp,
		"morale": 100,
		"count": maxi(1, count),
		"acted": false,
		"skills": skills.duplicate() if skills is Array else [],
		"is_supplied": true,
		"attacks_this_turn": 0,
		"burn_turns": 0,
		"burn_damage": 0,
		"stranded_turns": 0,
		"flanking_penalty": 0,
	}


## 将任意来源单位 dict 规范为 v3 权威字段（就地修改并返回同一引用）
static func normalize(unit: Dictionary) -> Dictionary:
	if unit.is_empty():
		return unit
	# max_mp：优先 speed（上限），否则 max_mp / mp
	if not unit.has("max_mp"):
		if unit.has("speed"):
			unit["max_mp"] = maxi(1, int(unit["speed"]))
		else:
			unit["max_mp"] = maxi(1, int(unit.get("mp", 3)))
	# mp：优先 mp_remaining（当前），否则 mp / max_mp
	if not unit.has("mp"):
		if unit.has("mp_remaining"):
			unit["mp"] = int(unit["mp_remaining"])
		else:
			unit["mp"] = int(unit.get("max_mp", 3))
	# 默认字段
	if not unit.has("count"):
		unit["count"] = 1
	if not unit.has("skills") or not (unit["skills"] is Array):
		unit["skills"] = []
	if not unit.has("is_supplied"):
		unit["is_supplied"] = true
	if not unit.has("attacks_this_turn"):
		unit["attacks_this_turn"] = 0
	if not unit.has("burn_turns"):
		unit["burn_turns"] = 0
	if not unit.has("burn_damage"):
		unit["burn_damage"] = 0
	if not unit.has("stranded_turns"):
		unit["stranded_turns"] = 0
	if not unit.has("flanking_penalty"):
		unit["flanking_penalty"] = 0
	if not unit.has("morale"):
		unit["morale"] = 100
	if not unit.has("acted"):
		unit["acted"] = false
	if not unit.has("col") or not unit.has("row"):
		# 无 odd-R 时由 axial 反推（调用方也可后补）
		pass
	unit["schema_v"] = SCHEMA_VERSION
	return unit


static func normalize_list(units: Array) -> Array:
	for i in range(units.size()):
		if units[i] is Dictionary:
			units[i] = normalize(units[i] as Dictionary)
	return units
