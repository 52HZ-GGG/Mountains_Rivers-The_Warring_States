@tool
extends RefCounted
class_name BigMapDocument

const TERRAIN_SOURCE_PATH: String = "res://data/terrain.json"
const FACTIONS_SOURCE_PATH: String = "res://data/factions.json"
const BIG_MAP_TERRAIN_PATH: String = "res://data/big_map_terrain.json"
const CITIES_PATH: String = "res://data/cities.json"
const BIG_MAP_CONTROL_PATH: String = "res://data/big_map_political_control.json"
const BigMapPoliticalControl := preload("res://scripts/systems/big_map_political_control.gd")
const HexAxial := preload("res://scripts/systems/hex_axial.gd")

var _terrain_doc: Dictionary = {}
var _cities_doc: Dictionary = {}
var _control_doc: Dictionary = {}
var _terrain_defs: Dictionary = {}
var _faction_defs: Dictionary = {}
var _terrain_names: Dictionary = {}
var _faction_names: Dictionary = {}
var _faction_colors: Dictionary = {}
var _dirty: bool = false
var _resolved_control_cache: Dictionary = {}
var _resolved_control_dirty: bool = true
var _undo_stack: Array[Dictionary] = []
var _redo_stack: Array[Dictionary] = []
var _history_suspended: bool = false
var _history_limit: int = 50


func _init() -> void:
	_load_reference_defs()


func load_all() -> bool:
	return load_from_paths(BIG_MAP_TERRAIN_PATH, CITIES_PATH, BIG_MAP_CONTROL_PATH)


func load_from_paths(terrain_path: String, cities_path: String, control_path: String) -> bool:
	_terrain_doc = _load_json(terrain_path)
	_cities_doc = _load_json(cities_path)
	_control_doc = _load_json(control_path)
	if _terrain_doc.is_empty() or _cities_doc.is_empty():
		return false
	if _control_doc.is_empty():
		_control_doc = _build_default_control_doc()
	_normalize_docs()
	_undo_stack.clear()
	_redo_stack.clear()
	_dirty = false
	_resolved_control_dirty = true
	return true


func save_all() -> Dictionary:
	return save_to_paths(BIG_MAP_TERRAIN_PATH, CITIES_PATH, BIG_MAP_CONTROL_PATH)


func save_to_paths(terrain_path: String, cities_path: String, control_path: String) -> Dictionary:
	var errors: Array[String] = validate_document()
	if not errors.is_empty():
		return {
			"ok": false,
			"error": "校验失败，无法保存。",
			"errors": errors,
		}
	if not _save_json(terrain_path, _build_terrain_save_doc()):
		return {"ok": false, "error": "无法写入 %s" % terrain_path}
	if not _save_json(cities_path, _build_cities_save_doc()):
		return {"ok": false, "error": "无法写入 %s" % cities_path}
	if not _save_json(control_path, _build_control_save_doc()):
		return {"ok": false, "error": "无法写入 %s" % control_path}
	_dirty = false
	return {"ok": true}


func is_dirty() -> bool:
	return _dirty


func can_undo() -> bool:
	return not _undo_stack.is_empty()


func can_redo() -> bool:
	return not _redo_stack.is_empty()


func undo() -> bool:
	if _undo_stack.is_empty():
		return false
	_redo_stack.append(_capture_snapshot())
	_restore_snapshot(_undo_stack.pop_back())
	_dirty = true
	return true


func redo() -> bool:
	if _redo_stack.is_empty():
		return false
	_undo_stack.append(_capture_snapshot())
	_restore_snapshot(_redo_stack.pop_back())
	_dirty = true
	return true


func get_map_width() -> int:
	return int(_terrain_doc.get("map_width", 0))


func get_map_height() -> int:
	return int(_terrain_doc.get("map_height", 0))


func get_map_size() -> Vector2i:
	return Vector2i(get_map_width(), get_map_height())


func get_rows() -> Array:
	return _terrain_doc.get("rows", [])


func get_all_cities() -> Array:
	return _cities_doc.get("cities", [])


func get_city_count() -> int:
	return get_all_cities().size()


func get_city(index: int) -> Dictionary:
	var cities: Array = get_all_cities()
	if index < 0 or index >= cities.size():
		return {}
	return cities[index] as Dictionary


func get_city_index_at_offset(col: int, row: int) -> int:
	var cities: Array = get_all_cities()
	for city_index: int in range(cities.size()):
		var city: Dictionary = cities[city_index] as Dictionary
		if int(city.get("hex_q", -9999)) == col and int(city.get("hex_r", -9999)) == row:
			return city_index
	return -1


func get_city_index_at_axial(q: int, r: int) -> int:
	var cities: Array = get_all_cities()
	for city_index: int in range(cities.size()):
		var city: Dictionary = cities[city_index] as Dictionary
		var city_axial: Vector2i = HexAxial.offset_odd_r_to_axial(int(city.get("hex_q", 0)), int(city.get("hex_r", 0)))
		if city_axial.x == q and city_axial.y == r:
			return city_index
	return -1


func get_terrain_at_offset(col: int, row: int) -> String:
	var rows: Array = get_rows()
	if row < 0 or row >= rows.size():
		return ""
	var row_data: Variant = rows[row]
	if row_data is not Array:
		return ""
	var cells: Array = row_data as Array
	if col < 0 or col >= cells.size():
		return ""
	return str(cells[col])


func set_terrain_at_offset(col: int, row: int, terrain_id: String) -> bool:
	if not _is_offset_in_bounds(col, row):
		return false
	_push_history_snapshot()
	var rows: Array = get_rows()
	var row_data: Array = rows[row] as Array
	row_data[col] = terrain_id
	_mark_dirty()
	return true


func resize_map(new_width: int, new_height: int) -> Dictionary:
	if new_width <= 0 or new_height <= 0:
		return {
			"ok": false,
			"error": "地图尺寸必须为正整数。",
		}
	var clip_error: String = _get_resize_clip_error(new_width, new_height)
	if not clip_error.is_empty():
		return {
			"ok": false,
			"error": clip_error,
		}
	_push_history_snapshot()
	var old_rows: Array = get_rows()
	var new_rows: Array = []
	for row: int in range(new_height):
		var new_row: Array[String] = []
		for col: int in range(new_width):
			var terrain_id: String = "plains"
			if row < old_rows.size():
				var old_row_v: Variant = old_rows[row]
				if old_row_v is Array and col < (old_row_v as Array).size():
					terrain_id = str((old_row_v as Array)[col])
			new_row.append(terrain_id)
		new_rows.append(new_row)
	_terrain_doc["map_width"] = new_width
	_terrain_doc["map_height"] = new_height
	_terrain_doc["rows"] = new_rows
	_cities_doc["map_width"] = new_width
	_cities_doc["map_height"] = new_height
	_control_doc["map_width"] = new_width
	_control_doc["map_height"] = new_height
	_mark_dirty()
	return {"ok": true}


func get_terrain_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var ids: Array = _terrain_names.keys()
	ids.sort()
	for id_v: Variant in ids:
		var terrain_id: String = str(id_v)
		options.append({
			"id": terrain_id,
			"name": str(_terrain_names.get(terrain_id, terrain_id)),
		})
	return options


func get_faction_options(include_neutral: bool = true) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var ids: Array = _faction_names.keys()
	ids.sort()
	for id_v: Variant in ids:
		var faction_id: String = str(id_v)
		options.append({
			"id": faction_id,
			"name": str(_faction_names.get(faction_id, faction_id)),
		})
	if include_neutral:
		options.append({
			"id": "neutral",
			"name": "中立",
		})
	return options


func get_terrain_name(terrain_id: String) -> String:
	return str(_terrain_names.get(terrain_id, terrain_id))


func get_faction_name(faction_id: String) -> String:
	if faction_id.is_empty():
		return "无归属"
	if faction_id == "neutral":
		return "中立"
	return str(_faction_names.get(faction_id, faction_id))


func get_faction_color(faction_id: String) -> Color:
	if faction_id.is_empty():
		return Color(0.28, 0.30, 0.33, 1.0)
	if faction_id == "neutral":
		return Color(0.55, 0.55, 0.55, 1.0)
	var color_code: String = str(_faction_colors.get(faction_id, "#888888"))
	return Color.html(color_code)


func get_city_list_label(index: int) -> String:
	var city: Dictionary = get_city(index)
	if city.is_empty():
		return ""
	return "%s｜%s｜%s,%s" % [
		get_faction_name(str(city.get("faction_id", ""))),
		str(city.get("name", "")),
		str(city.get("hex_q", "")),
		str(city.get("hex_r", "")),
	]


func create_city() -> int:
	_push_history_snapshot()
	var cities: Array = get_all_cities()
	var cell: Vector2i = _find_first_free_offset()
	var city: Dictionary = {
		"id": _generate_unique_city_id("new_city"),
		"name": "新城市",
		"faction_id": "qin",
		"hex_q": cell.x,
		"hex_r": cell.y,
		"jurisdiction_radius": 1,
		"special_resource": null,
		"is_capital": false,
		"development": 10,
		"city_level": 1,
		"initial_population": 1,
	}
	cities.append(city)
	_mark_dirty()
	return cities.size() - 1


func duplicate_city(index: int) -> int:
	var source: Dictionary = get_city(index)
	if source.is_empty():
		return -1
	_push_history_snapshot()
	var cities: Array = get_all_cities()
	var copy: Dictionary = source.duplicate(true)
	copy["id"] = _generate_unique_city_id(str(source.get("id", "city")) + "_copy")
	cities.append(copy)
	_mark_dirty()
	return cities.size() - 1


func delete_city(index: int) -> bool:
	var cities: Array = get_all_cities()
	if index < 0 or index >= cities.size():
		return false
	_push_history_snapshot()
	cities.remove_at(index)
	_mark_dirty()
	return true


func set_city_field(index: int, field_name: String, value: Variant) -> bool:
	var city: Dictionary = get_city(index)
	if city.is_empty():
		return false
	_push_history_snapshot()
	city[field_name] = value
	_mark_dirty()
	return true


func move_city(index: int, q: int, r: int) -> bool:
	if not BigMapPoliticalControl.is_axial_in_big_map_bounds(q, r, get_map_size()):
		return false
	var city: Dictionary = get_city(index)
	if city.is_empty():
		return false
	_push_history_snapshot()
	var offset: Vector2i = HexAxial.axial_to_offset_odd_r(q, r)
	city["hex_q"] = offset.x
	city["hex_r"] = offset.y
	_mark_dirty()
	return true


func get_override_owner_at_axial(q: int, r: int) -> Variant:
	var overrides: Array = get_overrides()
	for entry_v: Variant in overrides:
		if entry_v is not Dictionary:
			continue
		var entry: Dictionary = entry_v as Dictionary
		if int(entry.get("q", 0)) == q and int(entry.get("r", 0)) == r:
			return entry.get("owner_faction_id", null)
	return "__missing__"


func has_override_at_axial(q: int, r: int) -> bool:
	return get_override_owner_at_axial(q, r) != "__missing__"


func get_overrides() -> Array:
	return _control_doc.get("overrides", [])


func set_override_owner(q: int, r: int, owner_faction_id: Variant) -> void:
	_push_history_snapshot()
	var overrides: Array = get_overrides()
	for entry_v: Variant in overrides:
		if entry_v is not Dictionary:
			continue
		var entry: Dictionary = entry_v as Dictionary
		if int(entry.get("q", 0)) == q and int(entry.get("r", 0)) == r:
			entry["owner_faction_id"] = owner_faction_id
			_mark_dirty()
			return
	overrides.append({
		"q": q,
		"r": r,
		"owner_faction_id": owner_faction_id,
	})
	_mark_dirty()


func clear_override(q: int, r: int) -> void:
	var overrides: Array = get_overrides()
	for index: int in range(overrides.size() - 1, -1, -1):
		var entry_v: Variant = overrides[index]
		if entry_v is not Dictionary:
			continue
		var entry: Dictionary = entry_v as Dictionary
		if int(entry.get("q", 0)) == q and int(entry.get("r", 0)) == r:
			_push_history_snapshot()
			overrides.remove_at(index)
			_mark_dirty()
			return


func get_resolved_control_grid() -> Dictionary:
	_ensure_resolved_control()
	return _resolved_control_cache


func get_resolved_owner_at_offset(col: int, row: int) -> String:
	var axial: Vector2i = HexAxial.offset_odd_r_to_axial(col, row)
	return get_resolved_owner_at_axial(axial.x, axial.y)


func get_resolved_owner_at_axial(q: int, r: int) -> String:
	_ensure_resolved_control()
	return str(_resolved_control_cache.get(Vector2i(q, r), ""))


func validate_document() -> Array[String]:
	var errors: Array[String] = []
	var map_width: int = get_map_width()
	var map_height: int = get_map_height()
	if map_width <= 0 or map_height <= 0:
		errors.append("大地图尺寸必须为正整数。")
	var rows: Array = get_rows()
	if rows.size() != map_height:
		errors.append("big_map_terrain rows 行数与 map_height 不一致。")
	for row_index: int in range(rows.size()):
		var row_data: Variant = rows[row_index]
		if row_data is not Array or (row_data as Array).size() != map_width:
			errors.append("big_map_terrain 第 %d 行列数与 map_width 不一致。" % row_index)
			continue
		for terrain_v: Variant in row_data:
			var terrain_id: String = str(terrain_v)
			if not _terrain_names.has(terrain_id):
				errors.append("地形未知：%s" % terrain_id)
	var cities_width: int = int(_cities_doc.get("map_width", -1))
	var cities_height: int = int(_cities_doc.get("map_height", -1))
	if cities_width != map_width or cities_height != map_height:
		errors.append("cities.json 的地图尺寸必须与 big_map_terrain.json 一致。")
	var seen_city_ids: Dictionary = {}
	var capital_counts: Dictionary = {}
	var seen_city_cells: Dictionary = {}
	var cities: Array = get_all_cities()
	for city_index: int in range(cities.size()):
		var city: Dictionary = cities[city_index] as Dictionary
		var city_id: String = str(city.get("id", "")).strip_edges()
		if city_id.is_empty():
			errors.append("城市 #%d 的 id 不能为空。" % city_index)
		elif seen_city_ids.has(city_id):
			errors.append("城市 id 重复：%s" % city_id)
		else:
			seen_city_ids[city_id] = true
		var faction_id: String = str(city.get("faction_id", "")).strip_edges()
		if not _is_valid_faction_id(faction_id):
			errors.append("城市 %s 使用了未知势力：%s" % [city_id, faction_id])
		var q: int = int(city.get("hex_q", 0))
		var r: int = int(city.get("hex_r", 0))
		if q < 0 or q >= map_width or r < 0 or r >= map_height:
			errors.append("城市 %s 坐标越界：(%d, %d)" % [city_id, q, r])
		var cell_key: String = "%d,%d" % [q, r]
		if seen_city_cells.has(cell_key):
			errors.append("城市不能重叠：%s" % cell_key)
		else:
			seen_city_cells[cell_key] = true
		var radius: int = int(city.get("jurisdiction_radius", 0))
		if radius < 0:
			errors.append("城市 %s 的 jurisdiction_radius 不能小于 0。" % city_id)
		if int(city.get("city_level", 0)) < 0:
			errors.append("城市 %s 的 city_level 不能为负数。" % city_id)
		if int(city.get("development", 0)) < 0:
			errors.append("城市 %s 的 development 不能为负数。" % city_id)
		if int(city.get("initial_population", 0)) < 0:
			errors.append("城市 %s 的 initial_population 不能为负数。" % city_id)
		if bool(city.get("is_capital", false)):
			capital_counts[faction_id] = int(capital_counts.get(faction_id, 0)) + 1
	for faction_id_v: Variant in capital_counts.keys():
		var faction_id: String = str(faction_id_v)
		if int(capital_counts[faction_id]) > 1:
			errors.append("势力 %s 不能拥有多个首都。" % get_faction_name(faction_id))
	var control_width: int = int(_control_doc.get("map_width", -1))
	var control_height: int = int(_control_doc.get("map_height", -1))
	if control_width != map_width or control_height != map_height:
		errors.append("big_map_political_control.json 的尺寸必须与大地图一致。")
	var seen_override_cells: Dictionary = {}
	var overrides: Array = get_overrides()
	for override_index: int in range(overrides.size()):
		var entry_v: Variant = overrides[override_index]
		if entry_v is not Dictionary:
			errors.append("覆盖层第 %d 项不是字典。" % override_index)
			continue
		var entry: Dictionary = entry_v as Dictionary
		var q: int = int(entry.get("q", 0))
		var r: int = int(entry.get("r", 0))
		if not BigMapPoliticalControl.is_axial_in_big_map_bounds(q, r, get_map_size()):
			errors.append("覆盖层坐标越界：(%d, %d)" % [q, r])
		var cell_key: String = "%d,%d" % [q, r]
		if seen_override_cells.has(cell_key):
			errors.append("覆盖层存在重复坐标：%s" % cell_key)
		else:
			seen_override_cells[cell_key] = true
		var owner: Variant = entry.get("owner_faction_id", null)
		if owner != null and not _is_valid_faction_id(str(owner)):
			errors.append("覆盖层使用了未知势力：%s" % str(owner))
	return errors


func _load_reference_defs() -> void:
	_terrain_defs = _load_json(TERRAIN_SOURCE_PATH)
	_faction_defs = _load_json(FACTIONS_SOURCE_PATH)
	_terrain_names.clear()
	for terrain_v: Variant in _terrain_defs.get("terrains", []):
		if terrain_v is not Dictionary:
			continue
		var terrain: Dictionary = terrain_v as Dictionary
		_terrain_names[str(terrain.get("id", ""))] = str(terrain.get("name", ""))
	_faction_names.clear()
	_faction_colors.clear()
	for faction_v: Variant in _faction_defs.get("factions", []):
		if faction_v is not Dictionary:
			continue
		var faction: Dictionary = faction_v as Dictionary
		_faction_names[str(faction.get("id", ""))] = str(faction.get("name", ""))
		_faction_colors[str(faction.get("id", ""))] = str(faction.get("color", "#888888"))


func _normalize_docs() -> void:
	if not _terrain_doc.has("rows") or _terrain_doc.get("rows", null) is not Array:
		_terrain_doc["rows"] = []
	if not _cities_doc.has("cities") or _cities_doc.get("cities", null) is not Array:
		_cities_doc["cities"] = []
	if not _control_doc.has("overrides") or _control_doc.get("overrides", null) is not Array:
		_control_doc["overrides"] = []
	_cities_doc["map_width"] = get_map_width()
	_cities_doc["map_height"] = get_map_height()
	_control_doc["map_width"] = get_map_width()
	_control_doc["map_height"] = get_map_height()


func _build_default_control_doc() -> Dictionary:
	return {
		"schema_version": "1.0",
		"description": "大地图政治统治范围覆盖层；未覆盖格按城市控制者、等级、首都、发展度推导临时影响圈",
		"map_width": int(_terrain_doc.get("map_width", 0)),
		"map_height": int(_terrain_doc.get("map_height", 0)),
		"derived_radius_rules": {
			"level_radii": {
				"1": 4,
				"2": 5,
				"3": 6,
				"4": 7,
				"5": 8,
			},
			"capital_bonus_radius": 2,
			"development_bonus_threshold": 50,
			"development_bonus_radius": 1,
			"neutral_radius": 2,
		},
		"overrides": [],
	}


func _build_terrain_save_doc() -> Dictionary:
	return {
		"schema_version": str(_terrain_doc.get("schema_version", "1.0")),
		"description": str(_terrain_doc.get("description", "")),
		"map_width": get_map_width(),
		"map_height": get_map_height(),
		"rows": get_rows(),
	}


func _build_cities_save_doc() -> Dictionary:
	return {
		"schema_version": str(_cities_doc.get("schema_version", "1.0")),
		"map_width": get_map_width(),
		"map_height": get_map_height(),
		"cities": get_all_cities(),
	}


func _build_control_save_doc() -> Dictionary:
	var overrides: Array = get_overrides().duplicate(true)
	overrides.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ar: int = int(a.get("r", 0))
		var br: int = int(b.get("r", 0))
		if ar != br:
			return ar < br
		return int(a.get("q", 0)) < int(b.get("q", 0))
	)
	return {
		"schema_version": str(_control_doc.get("schema_version", "1.0")),
		"description": str(_control_doc.get("description", "")),
		"map_width": get_map_width(),
		"map_height": get_map_height(),
		"derived_radius_rules": (_control_doc.get("derived_radius_rules", {}) as Dictionary).duplicate(true),
		"overrides": overrides,
	}


func _get_resize_clip_error(new_width: int, new_height: int) -> String:
	for city_v: Variant in get_all_cities():
		if city_v is not Dictionary:
			continue
		var city: Dictionary = city_v as Dictionary
		var city_col: int = int(city.get("hex_q", 0))
		var city_row: int = int(city.get("hex_r", 0))
		if city_col >= new_width or city_row >= new_height:
			return "缩小后会裁掉城市：%s" % str(city.get("name", city.get("id", "")))
	for entry_v: Variant in get_overrides():
		if entry_v is not Dictionary:
			continue
		var entry: Dictionary = entry_v as Dictionary
		var offset: Vector2i = HexAxial.axial_to_offset_odd_r(int(entry.get("q", 0)), int(entry.get("r", 0)))
		if offset.x >= new_width or offset.y >= new_height:
			return "缩小后会裁掉统治覆盖格：(%d, %d)" % [int(entry.get("q", 0)), int(entry.get("r", 0))]
	return ""


func _is_offset_in_bounds(col: int, row: int) -> bool:
	return col >= 0 and col < get_map_width() and row >= 0 and row < get_map_height()


func _is_valid_faction_id(faction_id: String) -> bool:
	return faction_id == "neutral" or _faction_names.has(faction_id)


func _generate_unique_city_id(base_id: String) -> String:
	var clean_base: String = base_id.strip_edges()
	if clean_base.is_empty():
		clean_base = "city"
	var candidate: String = clean_base
	var suffix: int = 1
	while _has_city_id(candidate):
		candidate = "%s_%03d" % [clean_base, suffix]
		suffix += 1
	return candidate


func _has_city_id(city_id: String) -> bool:
	for city_v: Variant in get_all_cities():
		if city_v is not Dictionary:
			continue
		if str((city_v as Dictionary).get("id", "")) == city_id:
			return true
	return false


func _find_first_free_offset() -> Vector2i:
	for row: int in range(get_map_height()):
		for col: int in range(get_map_width()):
			if get_city_index_at_offset(col, row) == -1:
				return Vector2i(col, row)
	return Vector2i.ZERO


func _mark_dirty() -> void:
	_dirty = true
	_resolved_control_dirty = true


func _ensure_resolved_control() -> void:
	if not _resolved_control_dirty:
		return
	_resolved_control_cache = BigMapPoliticalControl.build_resolved_control_grid(
		get_all_cities(),
		get_overrides(),
		get_map_size(),
		_control_doc.get("derived_radius_rules", {})
	)
	_resolved_control_dirty = false


func _load_json(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is not Dictionary:
		return {}
	return (parsed as Dictionary).duplicate(true)


func _save_json(path: String, payload: Dictionary) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload, "\t") + "\n")
	file.flush()
	return true


func _push_history_snapshot() -> void:
	if _history_suspended:
		return
	_undo_stack.append(_capture_snapshot())
	if _undo_stack.size() > _history_limit:
		_undo_stack.remove_at(0)
	_redo_stack.clear()


func _capture_snapshot() -> Dictionary:
	return {
		"terrain_doc": _terrain_doc.duplicate(true),
		"cities_doc": _cities_doc.duplicate(true),
		"control_doc": _control_doc.duplicate(true),
	}


func _restore_snapshot(snapshot: Dictionary) -> void:
	_history_suspended = true
	_terrain_doc = (snapshot.get("terrain_doc", {}) as Dictionary).duplicate(true)
	_cities_doc = (snapshot.get("cities_doc", {}) as Dictionary).duplicate(true)
	_control_doc = (snapshot.get("control_doc", {}) as Dictionary).duplicate(true)
	_normalize_docs()
	_resolved_control_dirty = true
	_history_suspended = false
