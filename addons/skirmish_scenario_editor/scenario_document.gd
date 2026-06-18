@tool
extends RefCounted
class_name SkirmishScenarioDocument

const DEFAULT_PATH: String = "res://data/skirmish_scenarios.json"
const TERRAIN_PATH: String = "res://data/terrain.json"
const UNITS_PATH: String = "res://data/units.json"
const FACTIONS_PATH: String = "res://data/factions.json"

const UNIT_ID_ALIASES: Dictionary = {
	"catapult": "siege",
	"dayi": "great_wing",
	"louchuan": "tower_ship",
}

const UNIT_ID_ALIAS_NAMES: Dictionary = {
	"catapult": "投石车（兼容 ID）",
	"dayi": "大翼（兼容 ID）",
	"louchuan": "楼船（兼容 ID）",
}

var _source_path: String = DEFAULT_PATH
var _document: Dictionary = {}
var _terrain_names: Dictionary = {}
var _unit_names: Dictionary = {}
var _faction_names: Dictionary = {}
var _saved_scenario_ids: Dictionary = {}
var _dirty: bool = false


func _init() -> void:
	_load_reference_data()


static func normalize_unit_type_id(unit_type_id: String) -> String:
	return str(UNIT_ID_ALIASES.get(unit_type_id, unit_type_id))


func load_from_path(path: String = DEFAULT_PATH) -> bool:
	_source_path = path
	var data: Dictionary = _load_json(path)
	if data.is_empty():
		return false
	_document = data.duplicate(true)
	if not _document.has("scenarios") or not (_document["scenarios"] is Array):
		_document["scenarios"] = []
	var scenarios: Array = _document["scenarios"] as Array
	for i: int in range(scenarios.size()):
		var scenario: Dictionary = scenarios[i] as Dictionary
		_normalize_scenario_shape(scenario)
	_save_current_ids_as_locked()
	_dirty = false
	return true


func reload() -> bool:
	return load_from_path(_source_path)


func save() -> Dictionary:
	return save_to_path(_source_path)


func save_to_path(path: String) -> Dictionary:
	var validation_errors: Array[String] = validate_document()
	if not validation_errors.is_empty():
		return {
			"ok": false,
			"error": "校验失败，无法保存。",
			"errors": validation_errors,
		}
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {
			"ok": false,
			"error": "无法写入 %s" % path,
		}
	file.store_string(to_pretty_json())
	file.flush()
	_source_path = path
	_save_current_ids_as_locked()
	_dirty = false
	return {
		"ok": true,
		"path": path,
	}


func to_pretty_json() -> String:
	return JSON.stringify(_document, "\t") + "\n"


func is_dirty() -> bool:
	return _dirty


func mark_dirty() -> void:
	_dirty = true


func get_source_path() -> String:
	return _source_path


func get_schema_version() -> String:
	return str(_document.get("schema_version", ""))


func get_top_description() -> String:
	return str(_document.get("description", ""))


func get_scenarios() -> Array:
	return _document.get("scenarios", [])


func get_scenario_count() -> int:
	return get_scenarios().size()


func get_scenario(index: int) -> Dictionary:
	var scenarios: Array = get_scenarios()
	if index < 0 or index >= scenarios.size():
		return {}
	return scenarios[index] as Dictionary


func is_saved_scenario_id_locked(index: int) -> bool:
	var scenario: Dictionary = get_scenario(index)
	if scenario.is_empty():
		return true
	return bool(_saved_scenario_ids.get(str(scenario.get("id", "")), false))


func get_terrain_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var keys: Array = _terrain_names.keys()
	keys.sort()
	for key_v: Variant in keys:
		var terrain_id: String = str(key_v)
		options.append({
			"id": terrain_id,
			"name": str(_terrain_names.get(terrain_id, terrain_id)),
		})
	return options


func get_unit_type_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var canonical_ids: Array = _unit_names.keys()
	canonical_ids.sort()
	for canonical_v: Variant in canonical_ids:
		var unit_id: String = str(canonical_v)
		options.append({
			"id": unit_id,
			"name": str(_unit_names.get(unit_id, unit_id)),
		})
	var alias_ids: Array = UNIT_ID_ALIASES.keys()
	alias_ids.sort()
	for alias_v: Variant in alias_ids:
		var alias_id: String = str(alias_v)
		options.append({
			"id": alias_id,
			"name": str(UNIT_ID_ALIAS_NAMES.get(alias_id, alias_id)),
		})
	return options


func get_faction_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var keys: Array = _faction_names.keys()
	keys.sort()
	for key_v: Variant in keys:
		var faction_id: String = str(key_v)
		options.append({
			"id": faction_id,
			"name": str(_faction_names.get(faction_id, faction_id)),
		})
	return options


func get_terrain_name(terrain_id: String) -> String:
	return str(_terrain_names.get(terrain_id, terrain_id))


func get_unit_name(unit_type_id: String) -> String:
	if UNIT_ID_ALIAS_NAMES.has(unit_type_id):
		return str(UNIT_ID_ALIAS_NAMES[unit_type_id])
	var canonical_id: String = normalize_unit_type_id(unit_type_id)
	return str(_unit_names.get(canonical_id, unit_type_id))


func get_faction_name(faction_id: String) -> String:
	return str(_faction_names.get(faction_id, faction_id))


func create_new_scenario() -> int:
	var scenario: Dictionary = _build_default_scenario()
	get_scenarios().append(scenario)
	_dirty = true
	return get_scenario_count() - 1


func duplicate_scenario(index: int) -> int:
	var scenario: Dictionary = get_scenario(index)
	if scenario.is_empty():
		return -1
	var copy: Dictionary = scenario.duplicate(true)
	var base_id: String = str(scenario.get("id", "scenario"))
	copy["id"] = _generate_unique_scenario_id(base_id + "_copy")
	get_scenarios().append(copy)
	_dirty = true
	return get_scenario_count() - 1


func delete_scenario(index: int) -> bool:
	var scenarios: Array = get_scenarios()
	if index < 0 or index >= scenarios.size():
		return false
	scenarios.remove_at(index)
	_dirty = true
	return true


func set_scenario_field(index: int, field_name: String, value: Variant) -> bool:
	var scenario: Dictionary = get_scenario(index)
	if scenario.is_empty():
		return false
	scenario[field_name] = value
	_dirty = true
	return true


func set_scenario_id(index: int, new_id: String) -> bool:
	if is_saved_scenario_id_locked(index):
		return false
	return set_scenario_field(index, "id", new_id.strip_edges())


func set_scenario_mechanics_from_text(index: int, mechanics_text: String) -> bool:
	var lines: PackedStringArray = mechanics_text.split("\n", false)
	var mechanics: Array[String] = []
	for line: String in lines:
		var cleaned: String = line.strip_edges()
		if cleaned.is_empty():
			continue
		mechanics.append(cleaned)
	return set_scenario_field(index, "mechanics", mechanics)


func get_scenario_mechanics_text(index: int) -> String:
	var scenario: Dictionary = get_scenario(index)
	if scenario.is_empty():
		return ""
	var lines: PackedStringArray = PackedStringArray()
	for item_v: Variant in scenario.get("mechanics", []):
		lines.append(str(item_v))
	return "\n".join(lines)


func resize_scenario(index: int, new_width: int, new_height: int) -> Dictionary:
	var scenario: Dictionary = get_scenario(index)
	if scenario.is_empty():
		return {
			"ok": false,
			"error": "未找到场景。",
		}
	if new_width <= 0 or new_height <= 0:
		return {
			"ok": false,
			"error": "地图尺寸必须为正整数。",
		}
	var bounds_error: String = _get_resize_bounds_error(scenario, new_width, new_height)
	if not bounds_error.is_empty():
		return {
			"ok": false,
			"error": bounds_error,
		}
	var old_rows: Array = scenario.get("rows", [])
	var new_rows: Array = []
	for row: int in range(new_height):
		var new_row: Array[String] = []
		for col: int in range(new_width):
			var terrain_id: String = "plains"
			if row < old_rows.size():
				var old_row: Variant = old_rows[row]
				if old_row is Array and col < (old_row as Array).size():
					terrain_id = str((old_row as Array)[col])
			new_row.append(terrain_id)
		new_rows.append(new_row)
	scenario["map_width"] = new_width
	scenario["map_height"] = new_height
	scenario["rows"] = new_rows
	_dirty = true
	return {
		"ok": true,
	}


func set_cell_terrain(index: int, col: int, row: int, terrain_id: String) -> bool:
	var scenario: Dictionary = get_scenario(index)
	if scenario.is_empty():
		return false
	if not _is_in_bounds(scenario, col, row):
		return false
	var rows: Array = scenario.get("rows", [])
	var target_row: Array = rows[row] as Array
	target_row[col] = terrain_id
	_dirty = true
	return true


func get_cell_terrain(index: int, col: int, row: int) -> String:
	var scenario: Dictionary = get_scenario(index)
	if scenario.is_empty():
		return ""
	if not _is_in_bounds(scenario, col, row):
		return ""
	var rows: Array = scenario.get("rows", [])
	var target_row: Array = rows[row] as Array
	return str(target_row[col])


func get_unit_index_at(index: int, col: int, row: int) -> int:
	var scenario: Dictionary = get_scenario(index)
	if scenario.is_empty():
		return -1
	var units: Array = scenario.get("initial_units", [])
	for unit_index: int in range(units.size()):
		var unit: Dictionary = units[unit_index] as Dictionary
		if int(unit.get("q", -1)) == col and int(unit.get("r", -1)) == row:
			return unit_index
	return -1


func get_unit(index: int, unit_index: int) -> Dictionary:
	var scenario: Dictionary = get_scenario(index)
	if scenario.is_empty():
		return {}
	var units: Array = scenario.get("initial_units", [])
	if unit_index < 0 or unit_index >= units.size():
		return {}
	return units[unit_index] as Dictionary


func add_unit(index: int, col: int, row: int) -> Dictionary:
	var scenario: Dictionary = get_scenario(index)
	if scenario.is_empty():
		return {
			"ok": false,
			"error": "未找到场景。",
		}
	if not _is_in_bounds(scenario, col, row):
		return {
			"ok": false,
			"error": "坐标越界。",
		}
	if get_unit_index_at(index, col, row) >= 0:
		return {
			"ok": false,
			"error": "该格已有单位。",
		}
	if _is_city_at(scenario, col, row):
		return {
			"ok": false,
			"error": "城池格不能放置单位。",
		}
	var units: Array = scenario.get("initial_units", [])
	var new_unit: Dictionary = {
		"id": _generate_unique_unit_id(scenario, "unit"),
		"faction_id": str(scenario.get("player_faction_id", "qin")),
		"unit_type_id": "infantry",
		"q": col,
		"r": row,
	}
	units.append(new_unit)
	_dirty = true
	return {
		"ok": true,
		"unit_index": units.size() - 1,
	}


func remove_unit(index: int, unit_index: int) -> bool:
	var scenario: Dictionary = get_scenario(index)
	if scenario.is_empty():
		return false
	var units: Array = scenario.get("initial_units", [])
	if unit_index < 0 or unit_index >= units.size():
		return false
	units.remove_at(unit_index)
	_dirty = true
	return true


func set_unit_field(index: int, unit_index: int, field_name: String, value: Variant) -> bool:
	var unit: Dictionary = get_unit(index, unit_index)
	if unit.is_empty():
		return false
	unit[field_name] = value
	_dirty = true
	return true


func get_city(index: int, city_key: String) -> Dictionary:
	var scenario: Dictionary = get_scenario(index)
	if scenario.is_empty():
		return {}
	var key: String = _city_dict_key(city_key)
	var city_v: Variant = scenario.get(key, {})
	if city_v is Dictionary:
		return city_v as Dictionary
	return {}


func place_city(index: int, city_key: String, col: int, row: int) -> Dictionary:
	var scenario: Dictionary = get_scenario(index)
	if scenario.is_empty():
		return {
			"ok": false,
			"error": "未找到场景。",
		}
	if not _is_in_bounds(scenario, col, row):
		return {
			"ok": false,
			"error": "坐标越界。",
		}
	var other_city_key: String = "enemy" if city_key == "player" else "player"
	var other_city: Dictionary = get_city(index, other_city_key)
	if int(other_city.get("q", -1)) == col and int(other_city.get("r", -1)) == row:
		return {
			"ok": false,
			"error": "两座城池不能重叠。",
		}
	if get_unit_index_at(index, col, row) >= 0:
		return {
			"ok": false,
			"error": "单位格不能放置城池。",
		}
	var city: Dictionary = get_city(index, city_key)
	if city.is_empty():
		city = {"q": col, "r": row, "level": 3, "is_capital": true}
		get_scenario(index)[_city_dict_key(city_key)] = city
	else:
		city["q"] = col
		city["r"] = row
	_dirty = true
	return {
		"ok": true,
	}


func set_city_level(index: int, city_key: String, level: int) -> bool:
	var city: Dictionary = get_city(index, city_key)
	if city.is_empty():
		return false
	city["level"] = clampi(level, 1, 5)
	_dirty = true
	return true


func set_city_is_capital(index: int, city_key: String, is_capital: bool) -> bool:
	var city: Dictionary = get_city(index, city_key)
	if city.is_empty():
		return false
	city["is_capital"] = is_capital
	_dirty = true
	return true


func validate_document() -> Array[String]:
	var errors: Array[String] = []
	if not _document.has("scenarios") or not (_document["scenarios"] is Array):
		errors.append("顶层缺少 scenarios 数组。")
		return errors
	var seen_ids: Dictionary = {}
	var scenarios: Array = _document["scenarios"] as Array
	for index: int in range(scenarios.size()):
		var scenario: Dictionary = scenarios[index] as Dictionary
		var prefix: String = "场景 #%d" % (index + 1)
		var scenario_id: String = str(scenario.get("id", "")).strip_edges()
		if scenario_id.is_empty():
			errors.append("%s 缺少 id。" % prefix)
		elif seen_ids.has(scenario_id):
			errors.append("场景 id 重复：%s" % scenario_id)
		else:
			seen_ids[scenario_id] = true
		var scenario_name: String = str(scenario.get("name", "")).strip_edges()
		if scenario_name.is_empty():
			errors.append("%s（%s）缺少 name。" % [prefix, scenario_id])
		var width: int = int(scenario.get("map_width", 0))
		var height: int = int(scenario.get("map_height", 0))
		if width <= 0 or height <= 0:
			errors.append("%s（%s）地图尺寸必须为正整数。" % [prefix, scenario_id])
		var rows_v: Variant = scenario.get("rows", [])
		if not (rows_v is Array):
			errors.append("%s（%s）rows 必须是数组。" % [prefix, scenario_id])
			continue
		var rows: Array = rows_v as Array
		if rows.size() != height:
			errors.append("%s（%s）rows 行数与 map_height 不符。" % [prefix, scenario_id])
		for row: int in range(rows.size()):
			var row_v: Variant = rows[row]
			if not (row_v is Array):
				errors.append("%s（%s）rows[%d] 不是数组。" % [prefix, scenario_id, row])
				continue
			var terrain_row: Array = row_v as Array
			if terrain_row.size() != width:
				errors.append("%s（%s）rows[%d] 列数与 map_width 不符。" % [prefix, scenario_id, row])
			for col: int in range(terrain_row.size()):
				var terrain_id: String = str(terrain_row[col])
				if not _terrain_names.has(terrain_id):
					errors.append("%s（%s）地形未知：(%d,%d)=%s" % [prefix, scenario_id, col, row, terrain_id])
		var player_faction_id: String = str(scenario.get("player_faction_id", ""))
		var enemy_faction_id: String = str(scenario.get("enemy_faction_id", ""))
		if not _faction_names.has(player_faction_id):
			errors.append("%s（%s）玩家势力未知：%s" % [prefix, scenario_id, player_faction_id])
		if not _faction_names.has(enemy_faction_id):
			errors.append("%s（%s）敌方势力未知：%s" % [prefix, scenario_id, enemy_faction_id])
		if not player_faction_id.is_empty() and player_faction_id == enemy_faction_id:
			errors.append("%s（%s）玩家势力与敌方势力不能相同。" % [prefix, scenario_id])
		var player_city: Dictionary = _extract_city_dict(scenario.get("player_city", null))
		var enemy_city: Dictionary = _extract_city_dict(scenario.get("enemy_city", null))
		if player_city.is_empty():
			errors.append("%s（%s）缺少 player_city。" % [prefix, scenario_id])
		if enemy_city.is_empty():
			errors.append("%s（%s）缺少 enemy_city。" % [prefix, scenario_id])
		if not player_city.is_empty():
			_validate_city(errors, prefix, scenario_id, "player_city", player_city, width, height)
		if not enemy_city.is_empty():
			_validate_city(errors, prefix, scenario_id, "enemy_city", enemy_city, width, height)
		if not player_city.is_empty() and not enemy_city.is_empty():
			if int(player_city.get("q", -1)) == int(enemy_city.get("q", -2)) and int(player_city.get("r", -1)) == int(enemy_city.get("r", -2)):
				errors.append("%s（%s）player_city 与 enemy_city 不能重叠。" % [prefix, scenario_id])
		var units_v: Variant = scenario.get("initial_units", [])
		if not (units_v is Array):
			errors.append("%s（%s）initial_units 必须是数组。" % [prefix, scenario_id])
			continue
		var unit_ids: Dictionary = {}
		var occupied_cells: Dictionary = {}
		var units: Array = units_v as Array
		for unit_index: int in range(units.size()):
			var unit_v: Variant = units[unit_index]
			if not (unit_v is Dictionary):
				errors.append("%s（%s）initial_units[%d] 不是对象。" % [prefix, scenario_id, unit_index])
				continue
			var unit: Dictionary = unit_v as Dictionary
			var unit_id: String = str(unit.get("id", "")).strip_edges()
			if unit_id.is_empty():
				errors.append("%s（%s）第 %d 个单位缺少 id。" % [prefix, scenario_id, unit_index + 1])
			elif unit_ids.has(unit_id):
				errors.append("%s（%s）单位 id 重复：%s" % [prefix, scenario_id, unit_id])
			else:
				unit_ids[unit_id] = true
			var raw_unit_type_id: String = str(unit.get("unit_type_id", ""))
			var normalized_unit_type_id: String = normalize_unit_type_id(raw_unit_type_id)
			if not _unit_names.has(normalized_unit_type_id):
				errors.append("%s（%s）单位 %s 的兵种未知：%s" % [prefix, scenario_id, unit_id, raw_unit_type_id])
			var unit_faction_id: String = str(unit.get("faction_id", ""))
			if unit_faction_id != player_faction_id and unit_faction_id != enemy_faction_id:
				errors.append("%s（%s）单位 %s 的 faction_id 必须是当前玩家或敌方势力。" % [prefix, scenario_id, unit_id])
			var q: int = int(unit.get("q", -1))
			var r: int = int(unit.get("r", -1))
			if q < 0 or q >= width or r < 0 or r >= height:
				errors.append("%s（%s）单位 %s 坐标越界：(%d,%d)" % [prefix, scenario_id, unit_id, q, r])
			var cell_key: String = "%d,%d" % [q, r]
			if occupied_cells.has(cell_key):
				errors.append("%s（%s）单位不能重叠：(%d,%d)" % [prefix, scenario_id, q, r])
			else:
				occupied_cells[cell_key] = true
			if _is_same_cell(player_city, q, r) or _is_same_cell(enemy_city, q, r):
				errors.append("%s（%s）单位 %s 不能与城池重叠：(%d,%d)" % [prefix, scenario_id, unit_id, q, r])
	return errors


func _validate_city(errors: Array[String], prefix: String, scenario_id: String, city_name: String, city: Dictionary, width: int, height: int) -> void:
	var q: int = int(city.get("q", -1))
	var r: int = int(city.get("r", -1))
	if q < 0 or q >= width or r < 0 or r >= height:
		errors.append("%s（%s）%s 坐标越界：(%d,%d)" % [prefix, scenario_id, city_name, q, r])
	var level: int = int(city.get("level", 0))
	if level < 1 or level > 5:
		errors.append("%s（%s）%s 的 level 必须在 1..5 之间。" % [prefix, scenario_id, city_name])


func _load_reference_data() -> void:
	_terrain_names.clear()
	_unit_names.clear()
	_faction_names.clear()
	var terrain_doc: Dictionary = _load_json(TERRAIN_PATH)
	for terrain_v: Variant in terrain_doc.get("terrains", []):
		if terrain_v is Dictionary:
			var terrain: Dictionary = terrain_v as Dictionary
			_terrain_names[str(terrain.get("id", ""))] = str(terrain.get("name", terrain.get("id", "")))
	var unit_doc: Dictionary = _load_json(UNITS_PATH)
	for unit_v: Variant in unit_doc.get("unit_types", []):
		if unit_v is Dictionary:
			var unit: Dictionary = unit_v as Dictionary
			_unit_names[str(unit.get("id", ""))] = str(unit.get("name", unit.get("id", "")))
	var faction_doc: Dictionary = _load_json(FACTIONS_PATH)
	for faction_v: Variant in faction_doc.get("factions", []):
		if faction_v is Dictionary:
			var faction: Dictionary = faction_v as Dictionary
			_faction_names[str(faction.get("id", ""))] = str(faction.get("name", faction.get("id", "")))


func _load_json(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("SkirmishScenarioDocument: 无法打开 %s" % path)
		return {}
	var json: JSON = JSON.new()
	var err: Error = json.parse(file.get_as_text())
	if err != OK:
		push_error("SkirmishScenarioDocument: JSON 解析失败 %s (err=%d)" % [path, err])
		return {}
	var data: Variant = json.data
	if data is Dictionary:
		return data as Dictionary
	return {}


func _normalize_scenario_shape(scenario: Dictionary) -> void:
	if not scenario.has("mechanics") or not (scenario["mechanics"] is Array):
		scenario["mechanics"] = []
	if not scenario.has("initial_units") or not (scenario["initial_units"] is Array):
		scenario["initial_units"] = []
	if not scenario.has("rows") or not (scenario["rows"] is Array):
		scenario["rows"] = []


func _save_current_ids_as_locked() -> void:
	_saved_scenario_ids.clear()
	for scenario_v: Variant in get_scenarios():
		if scenario_v is Dictionary:
			var scenario: Dictionary = scenario_v as Dictionary
			_saved_scenario_ids[str(scenario.get("id", ""))] = true


func _build_default_scenario() -> Dictionary:
	var width: int = 7
	var height: int = 7
	var center_row: int = height / 2
	return {
		"id": _generate_unique_scenario_id("new_scenario"),
		"name": "新演武场景",
		"description": "",
		"mechanics": [],
		"map_width": width,
		"map_height": height,
		"player_faction_id": "qin",
		"enemy_faction_id": "zhao",
		"player_city": {"q": 0, "r": center_row, "level": 3, "is_capital": true},
		"enemy_city": {"q": width - 1, "r": center_row, "level": 3, "is_capital": true},
		"rows": _build_plain_rows(width, height),
		"initial_units": [],
	}


func _build_plain_rows(width: int, height: int) -> Array:
	var rows: Array = []
	for row: int in range(height):
		var new_row: Array[String] = []
		for col: int in range(width):
			new_row.append("plains")
		rows.append(new_row)
	return rows


func _generate_unique_scenario_id(base_id: String) -> String:
	var cleaned_base: String = base_id.strip_edges()
	if cleaned_base.is_empty():
		cleaned_base = "new_scenario"
	var taken: Dictionary = {}
	for scenario_v: Variant in get_scenarios():
		if scenario_v is Dictionary:
			var scenario: Dictionary = scenario_v as Dictionary
			taken[str(scenario.get("id", ""))] = true
	if cleaned_base == "new_scenario":
		var counter: int = 1
		while true:
			var candidate_new: String = "new_scenario_%03d" % counter
			if not taken.has(candidate_new):
				return candidate_new
			counter += 1
	if not taken.has(cleaned_base):
		return cleaned_base
	var suffix: int = 2
	while true:
		var candidate: String = "%s_%d" % [cleaned_base, suffix]
		if not taken.has(candidate):
			return candidate
		suffix += 1
	return cleaned_base


func _generate_unique_unit_id(scenario: Dictionary, prefix: String) -> String:
	var taken: Dictionary = {}
	for unit_v: Variant in scenario.get("initial_units", []):
		if unit_v is Dictionary:
			var unit: Dictionary = unit_v as Dictionary
			taken[str(unit.get("id", ""))] = true
	var counter: int = 1
	while true:
		var candidate: String = "%s_%03d" % [prefix, counter]
		if not taken.has(candidate):
			return candidate
		counter += 1
	return prefix


func _get_resize_bounds_error(scenario: Dictionary, new_width: int, new_height: int) -> String:
	for city_key: String in ["player", "enemy"]:
		var city: Dictionary = _extract_city_dict(scenario.get(_city_dict_key(city_key), null))
		if city.is_empty():
			continue
		var city_col: int = int(city.get("q", -1))
		var city_row: int = int(city.get("r", -1))
		if city_col >= new_width or city_row >= new_height:
			return "%s_city 会超出新地图范围，请先移动城池。" % city_key
	for unit_v: Variant in scenario.get("initial_units", []):
		if unit_v is Dictionary:
			var unit: Dictionary = unit_v as Dictionary
			var col: int = int(unit.get("q", -1))
			var row: int = int(unit.get("r", -1))
			if col >= new_width or row >= new_height:
				return "缩小后会裁掉单位 %s，请先移动或删除。" % str(unit.get("id", ""))
	return ""


func _is_in_bounds(scenario: Dictionary, col: int, row: int) -> bool:
	var width: int = int(scenario.get("map_width", 0))
	var height: int = int(scenario.get("map_height", 0))
	return col >= 0 and row >= 0 and col < width and row < height


func _city_dict_key(city_key: String) -> String:
	return "player_city" if city_key == "player" else "enemy_city"


func _is_city_at(scenario: Dictionary, col: int, row: int) -> bool:
	var player_city: Dictionary = _extract_city_dict(scenario.get("player_city", null))
	var enemy_city: Dictionary = _extract_city_dict(scenario.get("enemy_city", null))
	return _is_same_cell(player_city, col, row) or _is_same_cell(enemy_city, col, row)


func _extract_city_dict(city_v: Variant) -> Dictionary:
	if city_v is Dictionary:
		return city_v as Dictionary
	return {}


func _is_same_cell(city: Dictionary, col: int, row: int) -> bool:
	if city.is_empty():
		return false
	return int(city.get("q", -1)) == col and int(city.get("r", -1)) == row
