extends RefCounted
class_name BigMapPoliticalControl

const _HexAxial := preload("res://scripts/systems/hex_axial.gd")


static func build_resolved_control_grid(cities: Array, overrides: Array, map_size: Vector2i, rules: Dictionary = {}) -> Dictionary:
	var resolved: Dictionary = {}
	var override_map: Dictionary = _build_override_map(overrides)
	for row: int in range(map_size.y):
		for col: int in range(map_size.x):
			var axial: Vector2i = _HexAxial.offset_odd_r_to_axial(col, row)
			var owner: Variant = resolve_owner_for_axial(axial.x, axial.y, cities, override_map, rules)
			resolved[axial] = owner if owner != null else ""
	return resolved


static func resolve_owner_for_axial(q: int, r: int, cities: Array, override_map: Dictionary, rules: Dictionary = {}) -> Variant:
	var cell: Vector2i = Vector2i(q, r)
	if override_map.has(cell):
		return override_map[cell]
	var best_city: Dictionary = {}
	var best_distance: int = 999999
	for city_v: Variant in cities:
		if city_v is not Dictionary:
			continue
		var city: Dictionary = city_v as Dictionary
		var radius: int = effective_jurisdiction_radius(city, rules)
		var city_offset: Vector2i = Vector2i(int(city.get("hex_q", 0)), int(city.get("hex_r", 0)))
		var city_axial: Vector2i = _HexAxial.offset_odd_r_to_axial(city_offset.x, city_offset.y)
		var city_q: int = city_axial.x
		var city_r: int = city_axial.y
		var distance: int = _HexAxial.hex_distance_axial(q, r, city_q, city_r)
		if distance > radius:
			continue
		if best_city.is_empty() or _is_city_better(city, distance, best_city, best_distance):
			best_city = city
			best_distance = distance
	if best_city.is_empty():
		return null
	return str(best_city.get("current_faction_id", best_city.get("faction_id", "")))


static func effective_jurisdiction_radius(city: Dictionary, rules: Dictionary = {}) -> int:
	var authored_radius: int = maxi(0, int(city.get("jurisdiction_radius", 0)))
	var owner_id: String = str(city.get("current_faction_id", city.get("faction_id", "")))
	if owner_id == "neutral":
		return maxi(authored_radius, int(rules.get("neutral_radius", 2)))

	var level: int = maxi(1, int(city.get("city_level", 1)))
	var level_radii: Dictionary = rules.get("level_radii", {}) as Dictionary
	var inferred_radius: int = int(level_radii.get(str(level), level + 3))
	if bool(city.get("is_capital", false)):
		inferred_radius += int(rules.get("capital_bonus_radius", 2))
	var development: int = int(city.get("development", 0))
	if development >= int(rules.get("development_bonus_threshold", 50)):
		inferred_radius += int(rules.get("development_bonus_radius", 1))
	return maxi(authored_radius, inferred_radius)


static func is_axial_in_big_map_bounds(q: int, r: int, map_size: Vector2i) -> bool:
	var offset: Vector2i = _HexAxial.axial_to_offset_odd_r(q, r)
	return offset.x >= 0 and offset.x < map_size.x and offset.y >= 0 and offset.y < map_size.y


static func _build_override_map(overrides: Array) -> Dictionary:
	var out: Dictionary = {}
	for entry_v: Variant in overrides:
		if entry_v is not Dictionary:
			continue
		var entry: Dictionary = entry_v as Dictionary
		var cell: Vector2i = Vector2i(int(entry.get("q", 0)), int(entry.get("r", 0)))
		out[cell] = entry.get("owner_faction_id", null)
	return out


static func _is_city_better(candidate: Dictionary, candidate_distance: int, incumbent: Dictionary, incumbent_distance: int) -> bool:
	if candidate_distance != incumbent_distance:
		return candidate_distance < incumbent_distance
	var candidate_capital: bool = bool(candidate.get("is_capital", false))
	var incumbent_capital: bool = bool(incumbent.get("is_capital", false))
	if candidate_capital != incumbent_capital:
		return candidate_capital
	var candidate_level: int = int(candidate.get("city_level", 0))
	var incumbent_level: int = int(incumbent.get("city_level", 0))
	if candidate_level != incumbent_level:
		return candidate_level > incumbent_level
	return str(candidate.get("id", "")) < str(incumbent.get("id", ""))
