extends RefCounted
class_name BigMapPoliticalControl

## 政治疆域：影响力填充 + 填洞（决策 #200-#204）
## 详见 docs/机制概览/地理与天堑系统.md §14

const _HexAxial := preload("res://scripts/systems/hex_axial.gd")


## 构建全图归属网格。key=axial(Vector2i)，value=faction_id 或 ""（中立）
static func build_resolved_control_grid(
	cities: Array,
	overrides: Array,
	map_size: Vector2i,
	rules: Dictionary = {},
	terrain_rows: Array = []
) -> Dictionary:
	var mode: String = str(rules.get("mode", "voronoi"))
	if mode != "influence":
		return _build_voronoi_grid(cities, overrides, map_size, rules)
	return _build_influence_grid(cities, overrides, map_size, rules, terrain_rows)


# ============= 影响力模式 =============

static func _build_influence_grid(
	cities: Array,
	overrides: Array,
	map_size: Vector2i,
	rules: Dictionary,
	terrain_rows: Array
) -> Dictionary:
	var override_map: Dictionary = _build_override_map(overrides)
	var terrain_mul: Dictionary = rules.get("terrain_influence", {}) as Dictionary
	var threshold: float = float(rules.get("ownership_threshold", 8.0))
	var dominance: float = float(rules.get("dominance_ratio", 1.25))
	var frontier_min: float = float(rules.get("frontier_min_score", 4.0))
	var hole_neighbors: int = int(rules.get("hole_fill_neighbor_count", 5))
	var hole_rounds: int = int(rules.get("hole_fill_rounds", 3))

	var top1_owner: Dictionary = {}
	var top1_score: Dictionary = {}
	var top2_score: Dictionary = {}

	for row: int in range(map_size.y):
		for col: int in range(map_size.x):
			var axial: Vector2i = _HexAxial.offset_odd_r_to_axial(col, row)
			if override_map.has(axial):
				var forced: Variant = override_map[axial]
				top1_owner[axial] = str(forced) if forced != null else ""
				top1_score[axial] = 9999.0
				top2_score[axial] = 0.0
				continue
			var terrain_id: String = _terrain_at_offset(terrain_rows, col, row)
			var scores: Dictionary = _influence_scores_for_axial(axial, cities, rules, terrain_id, terrain_mul)
			var ranked: Array = _rank_scores(scores)
			if ranked.is_empty():
				top1_owner[axial] = ""
				top1_score[axial] = 0.0
				top2_score[axial] = 0.0
				continue
			top1_owner[axial] = str((ranked[0] as Dictionary)["id"])
			top1_score[axial] = float((ranked[0] as Dictionary)["v"])
			top2_score[axial] = float((ranked[1] as Dictionary)["v"]) if ranked.size() > 1 else 0.0

	var resolved: Dictionary = {}
	var buffer_cells: Dictionary = {}
	for row: int in range(map_size.y):
		for col: int in range(map_size.x):
			var axial: Vector2i = _HexAxial.offset_odd_r_to_axial(col, row)
			var owner: String = str(top1_owner.get(axial, ""))
			var s1: float = float(top1_score.get(axial, 0.0))
			var s2: float = float(top2_score.get(axial, 0.0))
			if owner.is_empty() or s1 <= 0.0:
				resolved[axial] = ""
				continue
			# override 已强制
			if s1 >= 9999.0:
				resolved[axial] = owner
				continue
			var clear: bool = s1 >= threshold and (s2 <= 0.0 or s1 / maxf(s2, 0.001) >= dominance)
			if clear:
				resolved[axial] = owner
			elif s1 >= threshold and s2 >= frontier_min and s1 / maxf(s2, 0.001) < dominance:
				resolved[axial] = ""
				buffer_cells[axial] = true
			elif s1 >= frontier_min * 0.5:
				# 低分但可能是腹地，先标候选，交给填洞
				resolved[axial] = ""
			else:
				resolved[axial] = ""

	# 填洞：中立格邻域多数同属 → 归该势力
	for _round: int in range(maxi(0, hole_rounds)):
		var to_fill: Dictionary = {}
		for axial_v: Variant in resolved:
			var cell: Vector2i = axial_v as Vector2i
			if str(resolved[cell]) != "":
				continue
			if buffer_cells.has(cell):
				continue
			var counts: Dictionary = {}
			for nb: Vector2i in _HexAxial.neighbors_hex(cell):
				if not resolved.has(nb):
					continue
				var no: String = str(resolved[nb])
				if no.is_empty():
					continue
				counts[no] = int(counts.get(no, 0)) + 1
			if counts.is_empty():
				continue
			var best_f: String = ""
			var best_n: int = 0
			for fid in counts:
				var n: int = int(counts[fid])
				if n > best_n:
					best_n = n
					best_f = str(fid)
			if best_n >= hole_neighbors:
				to_fill[cell] = best_f
		if to_fill.is_empty():
			break
		for cell_v: Variant in to_fill:
			resolved[cell_v as Vector2i] = str(to_fill[cell_v])

	return resolved


static func _influence_scores_for_axial(
	axial: Vector2i,
	cities: Array,
	rules: Dictionary,
	terrain_id: String,
	terrain_mul: Dictionary
) -> Dictionary:
	var power_cfg: Dictionary = rules.get("city_power", {}) as Dictionary
	var radius_cfg: Dictionary = rules.get("radius", {}) as Dictionary
	var pass_cfg: Dictionary = rules.get("pass", {}) as Dictionary
	var base_mul: float = float(terrain_mul.get(terrain_id, 1.0))
	var scores: Dictionary = {}
	for city_v: Variant in cities:
		if city_v is not Dictionary:
			continue
		var city: Dictionary = city_v as Dictionary
		var owner: String = str(city.get("current_faction_id", city.get("faction_id", "")))
		if owner.is_empty() or owner == "neutral":
			# 中立城弱影响，记入独立槽位，不参与势力归属
			continue
		var radius: int = _influence_radius(city, radius_cfg)
		if radius <= 0:
			continue
		var city_axial: Vector2i = _HexAxial.offset_odd_r_to_axial(int(city.get("hex_q", 0)), int(city.get("hex_r", 0)))
		var dist: int = _HexAxial.hex_distance_axial(axial.x, axial.y, city_axial.x, city_axial.y)
		if dist > radius:
			continue
		var decay: float = 1.0 - float(dist) / float(maxi(radius, 1))
		if decay <= 0.0:
			continue
		var power: float = _city_power(city, power_cfg)
		var mul: float = base_mul
		if terrain_id == "pass":
			# 关隘：归属城势力加成，其它削弱（简化：按是否与该城同势力已在 scores 内，此处按全局）
			var pass_owner: String = _pass_controlling_faction(cities, axial)
			if pass_owner == owner:
				mul *= float(pass_cfg.get("owner_multiplier", 1.6))
			elif pass_owner != "":
				mul *= float(pass_cfg.get("enemy_multiplier", 0.5))
		scores[owner] = float(scores.get(owner, 0.0)) + power * decay * mul
	return scores


static func _pass_controlling_faction(cities: Array, pass_axial: Vector2i) -> String:
	# 权威：PassManager（passes.json 初始 + 占领后持久）
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		var pm: Node = tree.root.get_node_or_null("PassManager")
		if pm != null and pm.has_method("has_pass") and pm.has_method("get_pass_owner"):
			if bool(pm.call("has_pass", pass_axial)):
				return str(pm.call("get_pass_owner", pass_axial))
	# 无 PassManager 时退回最近城（仅调试）
	var best_f: String = ""
	var best_d: int = 999999
	for city_v: Variant in cities:
		if city_v is not Dictionary:
			continue
		var city: Dictionary = city_v as Dictionary
		var city_axial: Vector2i = _HexAxial.offset_odd_r_to_axial(int(city.get("hex_q", 0)), int(city.get("hex_r", 0)))
		var d: int = _HexAxial.hex_distance_axial(pass_axial.x, pass_axial.y, city_axial.x, city_axial.y)
		if d < best_d:
			best_d = d
			best_f = str(city.get("current_faction_id", city.get("faction_id", "")))
	return best_f


static func _city_power(city: Dictionary, cfg: Dictionary) -> float:
	var owner: String = str(city.get("current_faction_id", city.get("faction_id", "")))
	var power: float = float(cfg.get("base", 10))
	power += float(int(city.get("city_level", 1))) * float(cfg.get("per_level", 4))
	if bool(city.get("is_capital", false)):
		power += float(cfg.get("capital_bonus", 15))
	var div: float = maxf(float(cfg.get("development_divisor", 10)), 1.0)
	power += floor(float(int(city.get("development", 0))) / div)
	if owner == "neutral":
		power *= float(cfg.get("neutral_multiplier", 0.5))
	return power


static func _influence_radius(city: Dictionary, cfg: Dictionary) -> int:
	var owner: String = str(city.get("current_faction_id", city.get("faction_id", "")))
	if owner == "neutral":
		return int(cfg.get("neutral", 2))
	var radius: int = int(cfg.get("base", 3)) + int(city.get("city_level", 1)) * int(cfg.get("per_level", 1))
	if bool(city.get("is_capital", false)):
		radius += int(cfg.get("capital_bonus", 1))
	return maxi(1, radius)


static func _rank_scores(scores: Dictionary) -> Array:
	var ranked: Array = []
	for fid in scores:
		ranked.append({"id": str(fid), "v": float(scores[fid])})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["v"]) > float(b["v"])
	)
	return ranked


static func _terrain_at_offset(terrain_rows: Array, col: int, row: int) -> String:
	if terrain_rows.is_empty() or row < 0 or row >= terrain_rows.size():
		return "plains"
	var row_data: Variant = terrain_rows[row]
	if row_data is not Array:
		return "plains"
	var arr: Array = row_data as Array
	if col < 0 or col >= arr.size():
		return "plains"
	return str(arr[col])


# ============= 旧 Voronoi 模式（fallback / mode!=influence） =============

static func _build_voronoi_grid(cities: Array, overrides: Array, map_size: Vector2i, rules: Dictionary) -> Dictionary:
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
		var distance: int = _HexAxial.hex_distance_axial(q, r, city_axial.x, city_axial.y)
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
