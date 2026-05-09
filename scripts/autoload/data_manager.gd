extends Node

## 全局数据管理器
##
## 启动时加载 data/*.json，提供只读访问。
## 接口契约见 docs/接口文档.md。
## 实现相对接口文档的偏离记录在 PR 描述中（fail-fast / id 索引 / map_size 缺省报错 / faction 分桶）。

const TERRAIN_PATH := "res://data/terrain.json"
const UNITS_PATH := "res://data/units.json"
const CITIES_PATH := "res://data/cities.json"

var _terrains: Dictionary = {}
var _units: Dictionary = {}
var _cities: Dictionary = {}

var _terrain_index: Dictionary = {}
var _unit_type_index: Dictionary = {}
var _city_index: Dictionary = {}
var _cities_by_faction: Dictionary = {}


func _ready() -> void:
	_load_all_data()
	_build_indices()
	assert(validate_data(), "DataManager: 数据校验失败，启动中止")


func _load_all_data() -> void:
	_terrains = _load_json(TERRAIN_PATH)
	_units = _load_json(UNITS_PATH)
	_cities = _load_json(CITIES_PATH)


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


# ============= 学派 / 科技占位（阶段 3 实现）=============

func get_school(school_id: String) -> Dictionary:
	push_warning("DataManager: 学派数据尚未实现 (school_id=%s)" % school_id)
	return {}


func get_all_schools() -> Array:
	return []


func get_tech(tech_id: String) -> Dictionary:
	push_warning("DataManager: 科技数据尚未实现 (tech_id=%s)" % tech_id)
	return {}


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
	return valid
