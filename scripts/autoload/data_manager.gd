extends Node

## 全局数据管理器
##
## 启动时加载 data/*.json，提供只读访问。
## 接口契约见 docs/接口文档.md。
## 实现相对接口文档的偏离记录在 PR 描述中（fail-fast / id 索引 / map_size 缺省报错 / faction 分桶）。

const TERRAIN_PATH := "res://data/terrain.json"
const UNITS_PATH := "res://data/units.json"
const CITIES_PATH := "res://data/cities.json"
const EVENTS_PATH := "res://data/events.json"
const BUILDINGS_PATH := "res://data/buildings.json"
const BALANCE_PARAMS_PATH := "res://data/balance_params.json"
const WONDERS_PATH := "res://data/wonders.json"
const FACTIONS_PATH := "res://data/factions.json"
const DIPLOMACY_PATH := "res://data/diplomacy.json"
const TECH_TREE_PATH := "res://data/tech_tree.json"
const TACTICAL_SKIRMISH_MVP_PATH := "res://data/tactical_skirmish_mvp.json"

var _terrains: Dictionary = {}
var _units: Dictionary = {}
var _cities: Dictionary = {}
var _events: Dictionary = {}
var _buildings: Dictionary = {}
var _balance_params: Dictionary = {}
var _wonders: Dictionary = {}
var _factions: Dictionary = {}
var _diplomacy: Dictionary = {}
var _tech_tree: Dictionary = {}
var _tactical_skirmish_mvp: Dictionary = {}

var _terrain_index: Dictionary = {}
var _unit_type_index: Dictionary = {}
var _city_index: Dictionary = {}
var _cities_by_faction: Dictionary = {}
var _building_index: Dictionary = {}
var _wonder_index: Dictionary = {}
var _faction_index: Dictionary = {}
var _tech_index: Dictionary = {}


func _ready() -> void:
	_load_all_data()
	_build_indices()
	assert(validate_data(), "DataManager: 数据校验失败，启动中止")


func _load_all_data() -> void:
	_terrains = _load_json(TERRAIN_PATH)
	_units = _load_json(UNITS_PATH)
	_cities = _load_json(CITIES_PATH)
	_events = _load_json(EVENTS_PATH)
	_buildings = _load_json(BUILDINGS_PATH)
	_balance_params = _load_json(BALANCE_PARAMS_PATH)
	_wonders = _load_json(WONDERS_PATH)
	_factions = _load_json(FACTIONS_PATH)
	_diplomacy = _load_json(DIPLOMACY_PATH)
	_tech_tree = _load_json(TECH_TREE_PATH)
	_tactical_skirmish_mvp = _load_json(TACTICAL_SKIRMISH_MVP_PATH)


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	assert(file != null, "DataManager: 无法打开 %s" % path)
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	assert(err == OK, "DataManager: JSON 解析失败 %s (err=%d)" % [path, err])
	return json.data


func _build_indices() -> void:
	_terrain_index.clear()
	for t in _terrains.get("terrains", []):
		_terrain_index[t["id"]] = t

	_unit_type_index.clear()
	for u in _units.get("unit_types", []):
		_unit_type_index[u["id"]] = u

	_city_index.clear()
	_cities_by_faction.clear()
	for c in _cities.get("cities", []):
		_city_index[c["id"]] = c
		var fid: String = c["faction_id"]
		if not _cities_by_faction.has(fid):
			_cities_by_faction[fid] = []
		_cities_by_faction[fid].append(c)

	_building_index.clear()
	for b in _buildings.get("buildings", []):
		_building_index[b["id"]] = b

	_wonder_index.clear()
	for w in _wonders.get("wonders", []):
		_wonder_index[w["id"]] = w

	_faction_index.clear()
	for f in _factions.get("factions", []):
		_faction_index[f["id"]] = f

	_tech_index.clear()
	for t in _tech_tree.get("techs", []):
		_tech_index[t["id"]] = t


# ============= 地形接口 =============

func get_terrain(terrain_id: String) -> Dictionary:
	if _terrain_index.has(terrain_id):
		return _terrain_index[terrain_id]
	push_warning("DataManager: 未找到地形 %s" % terrain_id)
	return {}


func get_all_terrains() -> Array:
	return _terrains.get("terrains", [])


# ============= 兵种接口 =============

func get_unit_type(unit_id: String) -> Dictionary:
	if _unit_type_index.has(unit_id):
		return _unit_type_index[unit_id]
	push_warning("DataManager: 未找到兵种 %s" % unit_id)
	return {}


func get_faction_variant(faction_id: String, base_unit_id: String) -> Dictionary:
	if _units.has("faction_variants"):
		for v in _units["faction_variants"]:
			if v["faction_id"] == faction_id and v["base_unit"] == base_unit_id:
				var base: Dictionary = get_unit_type(base_unit_id).duplicate()
				if base.is_empty():
					return {}
				var overrides: Dictionary = v.get("stat_overrides", {})
				for key in overrides:
					base[key] = overrides[key]
				base["variant_id"] = v["variant_id"]
				base["variant_name"] = v["variant_name"]
				base["special_description"] = v["special_description"]
				return base
	return get_unit_type(base_unit_id)


func get_faction_variants(faction_id: String) -> Array:
	var result: Array = []
	if _units.has("faction_variants"):
		for v in _units["faction_variants"]:
			if v["faction_id"] == faction_id:
				result.append(v)
	return result


func get_all_unit_types() -> Array:
	return _units.get("unit_types", [])


# ============= 城市接口 =============

func get_city(city_id: String) -> Dictionary:
	if _city_index.has(city_id):
		return _city_index[city_id]
	push_warning("DataManager: 未找到城市 %s" % city_id)
	return {}


func get_all_cities() -> Array:
	return _cities.get("cities", [])


func get_faction_cities(faction_id: String) -> Array:
	return _cities_by_faction.get(faction_id, [])


func get_capital(faction_id: String) -> Dictionary:
	for c in get_faction_cities(faction_id):
		if c.get("is_capital", false):
			return c
	push_warning("DataManager: 未找到 %s 的首都" % faction_id)
	return {}


func get_map_size() -> Vector2i:
	if not _cities.has("map_width") or not _cities.has("map_height"):
		push_error("DataManager: cities.json 缺少 map_width / map_height 字段")
		return Vector2i.ZERO
	return Vector2i(_cities["map_width"], _cities["map_height"])


# ============= 事件接口 =============

func get_all_events() -> Array:
	return _events.get("events", [])


func get_event(event_id: String) -> Dictionary:
	for evt in get_all_events():
		if evt["id"] == event_id:
			return evt
	push_warning("DataManager: 未找到事件 %s" % event_id)
	return {}


func get_event_chains() -> Array:
	return _events.get("event_chains", [])


func get_event_chain(chain_id: String) -> Dictionary:
	for chain in get_event_chains():
		if chain["id"] == chain_id:
			return chain
	push_warning("DataManager: 未找到事件链 %s" % chain_id)
	return {}


# ============= 建筑接口 =============

func get_building(building_id: String) -> Dictionary:
	if _building_index.has(building_id):
		return _building_index[building_id]
	push_warning("DataManager: 未找到建筑 %s" % building_id)
	return {}


func get_all_buildings() -> Array:
	return _buildings.get("buildings", [])


func get_buildings_by_category(category: String) -> Array:
	var result: Array = []
	for b in get_all_buildings():
		if b.get("category", "") == category:
			result.append(b)
	return result


# ============= 奇观接口 =============

func get_all_wonders() -> Array:
	return _wonders.get("wonders", [])


func get_wonder(wonder_id: String) -> Dictionary:
	if _wonder_index.has(wonder_id):
		return _wonder_index[wonder_id]
	push_warning("DataManager: 未找到奇观 %s" % wonder_id)
	return {}


# ============= 平衡参数接口 =============

func get_balance_param(path: String) -> Variant:
	var parts: PackedStringArray = path.split(".")
	var current: Variant = _balance_params
	for part in parts:
		if current is Dictionary and current.has(part):
			current = current[part]
		else:
			push_warning("DataManager: 未找到平衡参数 %s" % path)
			return null
	return current


func get_counter_multiplier(attacker_id: String, defender_id: String) -> float:
	var matrix: Dictionary = _balance_params.get("counter_matrix", {})
	if matrix.has(attacker_id) and matrix[attacker_id] is Dictionary:
		return matrix[attacker_id].get(defender_id, 1.0)
	return 1.0


func get_current_season(turn_number: int) -> String:
	var seasons: Array = _balance_params.get("season_cycle", {}).get("seasons", ["spring", "summer", "autumn", "winter"])
	var idx: int = (turn_number - 1) % seasons.size()
	return seasons[idx]


# ============= 国家接口 =============

func get_faction(faction_id: String) -> Dictionary:
	if _faction_index.has(faction_id):
		return _faction_index[faction_id]
	push_warning("DataManager: 未找到国家 %s" % faction_id)
	return {}


func get_all_factions() -> Array:
	return _factions.get("factions", [])


func get_initial_relations(faction_a: String, faction_b: String) -> int:
	var relations: Dictionary = _factions.get("initial_relations", {})
	if relations.has(faction_a) and relations[faction_a] is Dictionary:
		return relations[faction_a].get(faction_b, 0)
	return 0


func get_ai_personality(faction_id: String) -> Dictionary:
	var faction := get_faction(faction_id)
	return faction.get("ai_personality", {"aggression": 2, "greed": 2, "honesty": 2, "diplomacy": 2})


# ============= 外交参数接口 =============

func get_diplomacy_param(path: String) -> Variant:
	var parts: PackedStringArray = path.split(".")
	var current: Variant = _diplomacy
	for part in parts:
		if current is Dictionary and current.has(part):
			current = current[part]
		else:
			push_warning("DataManager: 未找到外交参数 %s" % path)
			return null
	return current


func get_gift_tiers() -> Array:
	return _diplomacy.get("gift_tiers", [])


func get_action_effects(action: String) -> Dictionary:
	var effects: Dictionary = _diplomacy.get("action_effects", {})
	return effects.get(action, {})


func get_difficulty_settings(difficulty: String) -> Dictionary:
	return _diplomacy.get("difficulty", {}).get(difficulty, {"resource_mod": 0.0, "initial_gold_bonus": 0})


# ============= 学派占位（阶段 3 实现）=============

func get_school(school_id: String) -> Dictionary:
	push_warning("DataManager: 学派数据尚未实现 (school_id=%s)" % school_id)
	return {}


func get_all_schools() -> Array:
	return []


# ============= 科技接口 =============

func get_tech(tech_id: String) -> Dictionary:
	if _tech_index.has(tech_id):
		return _tech_index[tech_id]
	push_warning("DataManager: 未找到科技 %s" % tech_id)
	return {}


func get_all_techs() -> Array:
	return _tech_tree.get("techs", [])


func get_techs_by_category(category: String) -> Array:
	var result: Array = []
	for t in get_all_techs():
		if t.get("category", "") == category:
			result.append(t)
	return result


func get_techs_by_era(era: String) -> Array:
	var result: Array = []
	for t in get_all_techs():
		if t.get("era", "") == era:
			result.append(t)
	return result


func get_tactical_skirmish_mvp() -> Dictionary:
	return _tactical_skirmish_mvp


func get_tech_cost(tech_id: String) -> int:
	var tech := get_tech(tech_id)
	return tech.get("cost_gold", 0)


func get_tech_prerequisites(tech_id: String) -> Array:
	var tech := get_tech(tech_id)
	return tech.get("prerequisites", [])


# ============= 数据校验 =============

func validate_data() -> bool:
	var valid := true
	for t in get_all_terrains():
		if not t.has("id") or not t.has("move_cost"):
			push_error("DataManager: 地形数据缺少必要字段: %s" % t)
			valid = false
	for u in get_all_unit_types():
		if not u.has("id") or not u.has("attack"):
			push_error("DataManager: 兵种数据缺少必要字段: %s" % u)
			valid = false
	for c in get_all_cities():
		if not c.has("id") or not c.has("hex_q") or not c.has("hex_r"):
			push_error("DataManager: 城市数据缺少必要字段: %s" % c)
			valid = false
	for b in get_all_buildings():
		if not b.has("id") or not b.has("cost_gold"):
			push_error("DataManager: 建筑数据缺少必要字段: %s" % b)
			valid = false
	for e in get_all_events():
		if not e.has("id") or not e.has("trigger"):
			push_error("DataManager: 事件数据缺少必要字段: %s" % e)
			valid = false
	for w in get_all_wonders():
		if not w.has("id") or not w.has("cost_gold"):
			push_error("DataManager: 奇观数据缺少必要字段: %s" % w)
			valid = false
	for f in get_all_factions():
		if not f.has("id") or not f.has("name"):
			push_error("DataManager: 国家数据缺少必要字段: %s" % f)
			valid = false
		if not f.has("ai_personality"):
			push_error("DataManager: 国家数据缺少ai_personality: %s" % f)
			valid = false
	if _diplomacy.is_empty():
		push_error("DataManager: 外交参数数据为空")
		valid = false
	for t in get_all_techs():
		if not t.has("id") or not t.has("name") or not t.has("category"):
			push_error("DataManager: 科技数据缺少必要字段: %s" % t)
			valid = false
		if not t.has("effects") or not t["effects"].has("type"):
			push_error("DataManager: 科技数据缺少effects: %s" % t)
			valid = false
	if not _tactical_skirmish_mvp.is_empty():
		if not _validate_tactical_skirmish_mvp():
			valid = false
	return valid


func _validate_tactical_skirmish_mvp() -> bool:
	var cfg: Dictionary = _tactical_skirmish_mvp
	var ok: bool = true
	if not cfg.has("map_width") or not cfg.has("map_height"):
		push_error("DataManager: tactical_skirmish_mvp 缺少 map_width / map_height")
		return false
	var w: int = int(cfg["map_width"])
	var h: int = int(cfg["map_height"])
	if not cfg.has("rows"):
		push_error("DataManager: tactical_skirmish_mvp 缺少 rows")
		return false
	var rows: Array = cfg["rows"]
	if rows.size() != h:
		push_error("DataManager: tactical_skirmish_mvp rows 行数与 map_height 不符")
		ok = false
	for i in range(rows.size()):
		var row: Variant = rows[i]
		if row is Array and (row as Array).size() == w:
			continue
		push_error("DataManager: tactical_skirmish_mvp rows[%d] 列数与 map_width 不符" % i)
		ok = false
	if not cfg.has("player_city") or not cfg.has("enemy_city"):
		push_error("DataManager: tactical_skirmish_mvp 缺少 player_city / enemy_city")
		ok = false
	if not cfg.has("initial_units"):
		push_error("DataManager: tactical_skirmish_mvp 缺少 initial_units")
		ok = false
	return ok
