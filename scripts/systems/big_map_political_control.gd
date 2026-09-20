extends RefCounted
class_name BigMapPoliticalControl

## 政治疆域：影响力填充 + 填洞（决策 #200-#204，P0 强化）
## 详见 docs/机制概览/地理与天堑系统.md §14
## P0 口径：
## - 城池格锁定归属城主（中立城格保持中立，不可被吸收）
## - 中立城也是影响力源（弱源）
## - 关隘为较弱独立影响力源，读 PassManager 归属

const _HexAxial := preload("res://scripts/systems/hex_axial.gd")

const NEUTRAL_ID: String = "neutral"


## 构建全图归属网格。key=axial(Vector2i)，value=faction_id 或 ""（中立）
## passes_override：可选，[{axial_q, axial_r, owner}...]；为空时尝试读 PassManager
static func build_resolved_control_grid(
	cities: Array,
	overrides: Array,
	map_size: Vector2i,
	rules: Dictionary = {},
	terrain_rows: Array = [],
	passes_override: Array = []
) -> Dictionary:
	var mode: String = str(rules.get("mode", "influence"))
	if mode != "influence":
		return _build_voronoi_grid(cities, overrides, map_size, rules)
	return _build_influence_grid(cities, overrides, map_size, rules, terrain_rows, passes_override)


# ============= 影响力模式 =============

static func _build_influence_grid(
	cities: Array,
	overrides: Array,
	map_size: Vector2i,
	rules: Dictionary,
	terrain_rows: Array,
	passes_override: Array = []
) -> Dictionary:
	var override_map: Dictionary = _build_override_map(overrides)
	var terrain_mul: Dictionary = rules.get("terrain_influence", {}) as Dictionary
	var threshold: float = float(rules.get("ownership_threshold", 8.0))
	var dominance: float = float(rules.get("dominance_ratio", 1.25))
	var frontier_min: float = float(rules.get("frontier_min_score", 4.0))
	var hole_neighbors: int = int(rules.get("hole_fill_neighbor_count", 5))
	var hole_rounds: int = int(rules.get("hole_fill_rounds", 3))
	var lock_city_cells: bool = bool(rules.get("city_cell_lock", true))
	var protect_neutral: bool = bool(rules.get("neutral_city_protected", true))
	var core_boost: float = float(rules.get("core_boost", 1.0))

	var city_cells: Dictionary = {}
	var city_owner_at: Dictionary = {}
	var core_ring_owner: Dictionary = {}
	for city_v: Variant in cities:
		if city_v is not Dictionary:
			continue
		var city: Dictionary = city_v as Dictionary
		var axial: Vector2i = _HexAxial.offset_odd_r_to_axial(int(city.get("hex_q", 0)), int(city.get("hex_r", 0)))
		var owner: String = str(city.get("current_faction_id", city.get("faction_id", "")))
		if owner.is_empty():
			owner = NEUTRAL_ID
		city_cells[axial] = true
		city_owner_at[axial] = owner
		# 城市辖区：必须与建筑放置同一套「视觉邻格」（奇数列下移），不能用轴向 6 邻格
		if lock_city_cells:
			var col: int = int(city.get("hex_q", 0))
			var row: int = int(city.get("hex_r", 0))
			var juris_radius: int = maxi(1, int(city.get("jurisdiction_radius", 1)))
			for nb_off: Vector2i in _HexAxial.offset_visual_neighbors(col, row):
				if juris_radius != 1:
					continue
				var nb_axial: Vector2i = _HexAxial.offset_odd_r_to_axial(nb_off.x, nb_off.y)
				if not is_axial_in_big_map_bounds(nb_axial.x, nb_axial.y, map_size):
					continue
				if city_cells.has(nb_axial):
					continue
				if not core_ring_owner.has(nb_axial):
					core_ring_owner[nb_axial] = owner

	var pass_sources: Array = _collect_pass_sources(passes_override, rules)
	var pass_at: Dictionary = {}
	for ps: Variant in pass_sources:
		var pd: Dictionary = ps as Dictionary
		pass_at[pd["axial"]] = pd

	var top1_owner: Dictionary = {}
	var top1_score: Dictionary = {}
	var top2_score: Dictionary = {}
	var protected_neutral: Dictionary = {}

	for row: int in range(map_size.y):
		for col: int in range(map_size.x):
			var axial: Vector2i = _HexAxial.offset_odd_r_to_axial(col, row)
			if override_map.has(axial):
				var forced: Variant = override_map[axial]
				top1_owner[axial] = str(forced) if forced != null else NEUTRAL_ID
				top1_score[axial] = 9999.0
				top2_score[axial] = 0.0
				continue
			# 城池格：强制城主（中立城=中立，禁止吸收）
			if lock_city_cells and city_cells.has(axial):
				top1_owner[axial] = str(city_owner_at[axial])
				top1_score[axial] = 9999.0
				top2_score[axial] = 0.0
				if protect_neutral and str(city_owner_at[axial]) == NEUTRAL_ID:
					protected_neutral[axial] = true
				continue
			# 城市辖区环（城周 1 格）：强制归城主
			if lock_city_cells and core_ring_owner.has(axial):
				var ring_owner: String = str(core_ring_owner[axial])
				top1_owner[axial] = ring_owner
				top1_score[axial] = 9999.0
				top2_score[axial] = 0.0
				if protect_neutral and ring_owner == NEUTRAL_ID:
					protected_neutral[axial] = true
				continue
			# 关隘格：归属锁边
			if pass_at.has(axial) and bool((pass_at[axial] as Dictionary).get("lock_self", false)):
				var p_owner: String = str((pass_at[axial] as Dictionary).get("owner", NEUTRAL_ID))
				if p_owner != NEUTRAL_ID and not p_owner.is_empty():
					top1_owner[axial] = p_owner
					top1_score[axial] = 9999.0
					top2_score[axial] = 0.0
					continue
			var terrain_id: String = _terrain_at_offset(terrain_rows, col, row)
			var scores: Dictionary = _influence_scores_for_axial(
				axial, cities, rules, terrain_id, terrain_mul, pass_sources, core_boost, city_owner_at
			)
			var ranked: Array = _rank_scores(scores)
			if ranked.is_empty():
				top1_owner[axial] = NEUTRAL_ID
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
			var axial2: Vector2i = _HexAxial.offset_odd_r_to_axial(col, row)
			var owner2: String = str(top1_owner.get(axial2, NEUTRAL_ID))
			var s1: float = float(top1_score.get(axial2, 0.0))
			var s2: float = float(top2_score.get(axial2, 0.0))
			if owner2.is_empty() or owner2 == NEUTRAL_ID:
				resolved[axial2] = ""
				if protect_neutral and s1 > 0.0:
					protected_neutral[axial2] = true
				continue
			if s1 <= 0.0:
				resolved[axial2] = ""
				continue
			if s1 >= 9999.0:
				# 锁定格：城主 / 关隘 / override
				resolved[axial2] = owner2
				continue
			var clear: bool = s1 >= threshold and (s2 <= 0.0 or s1 / maxf(s2, 0.001) >= dominance)
			if clear:
				resolved[axial2] = owner2
			elif s1 >= threshold and s2 >= frontier_min and s1 / maxf(s2, 0.001) < dominance:
				resolved[axial2] = ""
				buffer_cells[axial2] = true
			else:
				resolved[axial2] = ""

	# 填洞：中立格邻域多数同属 → 归该势力；不得吸收城格/关隘锁定/中立保护区
	for _round: int in range(maxi(0, hole_rounds)):
		var to_fill: Dictionary = {}
		for axial_v: Variant in resolved:
			var cell: Vector2i = axial_v as Vector2i
			if str(resolved[cell]) != "":
				continue
			if buffer_cells.has(cell):
				continue
			if protected_neutral.has(cell) or city_cells.has(cell):
				continue
			if core_ring_owner.has(cell):
				continue
			if pass_at.has(cell) and bool((pass_at[cell] as Dictionary).get("lock_self", false)):
				continue
			# 邻接中立城/保护区的格：仅当中立不是 top 时才可考虑填洞，且不得由他国填入保护圈
			if _adjacent_to_protected(cell, protected_neutral):
				continue
			var counts: Dictionary = {}
			for nb: Vector2i in _HexAxial.visual_neighbor_axials(cell):
				if not resolved.has(nb):
					continue
				var no: String = str(resolved[nb])
				if no.is_empty() or no == NEUTRAL_ID:
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
			var fill_cell: Vector2i = cell_v as Vector2i
			if city_cells.has(fill_cell) or protected_neutral.has(fill_cell):
				continue
			resolved[fill_cell] = str(to_fill[fill_cell])

	return resolved


static func _adjacent_to_protected(cell: Vector2i, protected_neutral: Dictionary) -> bool:
	if protected_neutral.is_empty():
		return false
	for nb: Vector2i in _HexAxial.visual_neighbor_axials(cell):
		if protected_neutral.has(nb):
			return true
	return false


static func _collect_pass_sources(passes_override: Array, rules: Dictionary) -> Array:
	var pass_cfg: Dictionary = rules.get("pass", {}) as Dictionary
	if not bool(pass_cfg.get("as_source", true)):
		return []
	var out: Array = []
	var raw: Array = passes_override
	if raw.is_empty():
		raw = _read_passes_from_manager()
	for item_v: Variant in raw:
		if item_v is not Dictionary:
			continue
		var d: Dictionary = item_v as Dictionary
		var owner: String = str(d.get("owner", NEUTRAL_ID))
		if owner.is_empty():
			owner = NEUTRAL_ID
		var axial: Vector2i
		if d.has("axial") and d["axial"] is Vector2i:
			axial = d["axial"] as Vector2i
		else:
			# passes.json / PassManager：axial_q/r 已是轴向坐标
			axial = Vector2i(int(d.get("axial_q", d.get("q", 0))), int(d.get("axial_r", d.get("r", 0))))
		out.append({
			"axial": axial,
			"owner": owner,
			"power": float(d.get("power", pass_cfg.get("power", 7))),
			"radius": int(d.get("radius", pass_cfg.get("radius", 2))),
			"lock_self": bool(pass_cfg.get("lock_self", true)),
			"neutral_multiplier": float(pass_cfg.get("neutral_multiplier", 0.35)),
		})
	return out


static func _read_passes_from_manager() -> Array:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return []
	var pm: Node = tree.root.get_node_or_null("PassManager")
	if pm == null or not pm.has_method("get_all_passes"):
		return []
	var all: Dictionary = pm.call("get_all_passes") as Dictionary
	var out: Array = []
	for k in all:
		var entry: Dictionary = all[k] as Dictionary
		var parts: PackedStringArray = str(k).split(",")
		if parts.size() < 2:
			continue
		out.append({
			"axial_q": int(parts[0]),
			"axial_r": int(parts[1]),
			"owner": str(entry.get("owner", NEUTRAL_ID)),
			"name": str(entry.get("name", "")),
		})
	return out


static func _influence_scores_for_axial(
	axial: Vector2i,
	cities: Array,
	rules: Dictionary,
	terrain_id: String,
	terrain_mul: Dictionary,
	pass_sources: Array = [],
	core_boost: float = 1.0,
	city_owner_at: Dictionary = {}
) -> Dictionary:
	var power_cfg: Dictionary = rules.get("city_power", {}) as Dictionary
	var radius_cfg: Dictionary = rules.get("radius", {}) as Dictionary
	var pass_cfg: Dictionary = rules.get("pass", {}) as Dictionary
	var base_mul: float = float(terrain_mul.get(terrain_id, 1.0))
	var scores: Dictionary = {}

	# 城市源（含中立城）
	for city_v: Variant in cities:
		if city_v is not Dictionary:
			continue
		var city: Dictionary = city_v as Dictionary
		var owner: String = str(city.get("current_faction_id", city.get("faction_id", "")))
		if owner.is_empty():
			owner = NEUTRAL_ID
		var radius: int = _influence_radius(city, radius_cfg)
		if radius <= 0:
			continue
		var city_axial: Vector2i = _HexAxial.offset_odd_r_to_axial(int(city.get("hex_q", 0)), int(city.get("hex_r", 0)))
		var dist: int = _HexAxial.visual_distance_axial(axial.x, axial.y, city_axial.x, city_axial.y)
		if dist > radius:
			continue
		var decay: float = 1.0 - float(dist) / float(maxi(radius, 1))
		if decay <= 0.0:
			continue
		var power: float = _city_power(city, power_cfg)
		var mul: float = base_mul
		# 城主核心圈加成（视觉 1 环）
		if dist <= 1 and city_owner_at.has(city_axial):
			mul *= maxf(1.0, core_boost)
		if terrain_id == "pass":
			var pass_owner: String = _pass_owner_at(pass_sources, axial)
			if pass_owner == owner and pass_owner != NEUTRAL_ID:
				mul *= float(pass_cfg.get("owner_multiplier", 1.6))
			elif pass_owner != "" and pass_owner != NEUTRAL_ID and pass_owner != owner:
				mul *= float(pass_cfg.get("enemy_multiplier", 0.5))
		var score_key: String = NEUTRAL_ID if owner == NEUTRAL_ID else owner
		scores[score_key] = float(scores.get(score_key, 0.0)) + power * decay * mul

	# 关隘源（弱于城市）
	for ps: Variant in pass_sources:
		var pd: Dictionary = ps as Dictionary
		var p_owner: String = str(pd.get("owner", NEUTRAL_ID))
		if p_owner.is_empty() or p_owner == NEUTRAL_ID:
			continue
		var p_axial: Vector2i = pd["axial"] as Vector2i
		var p_radius: int = int(pd.get("radius", 2))
		if p_radius <= 0:
			continue
		var p_dist: int = _HexAxial.visual_distance_axial(axial.x, axial.y, p_axial.x, p_axial.y)
		if p_dist > p_radius:
			continue
		var p_decay: float = 1.0 - float(p_dist) / float(maxi(p_radius, 1))
		if p_decay <= 0.0:
			continue
		var p_power: float = float(pd.get("power", 7.0))
		var p_mul: float = base_mul
		if p_dist <= 1:
			p_mul *= 1.0 + float(pass_cfg.get("adjacent_owner_bonus", 0.2))
		scores[p_owner] = float(scores.get(p_owner, 0.0)) + p_power * p_decay * p_mul

	return scores


static func _pass_owner_at(pass_sources: Array, axial: Vector2i) -> String:
	for ps: Variant in pass_sources:
		var pd: Dictionary = ps as Dictionary
		if pd.get("axial") == axial:
			return str(pd.get("owner", NEUTRAL_ID))
	return ""


## 兼容旧调用：无 pass 列表时用 PassManager
static func _influence_scores_for_axial_legacy(
	axial: Vector2i,
	cities: Array,
	rules: Dictionary,
	terrain_id: String,
	terrain_mul: Dictionary
) -> Dictionary:
	return _influence_scores_for_axial(axial, cities, rules, terrain_id, terrain_mul)


static func _city_power(city: Dictionary, cfg: Dictionary) -> float:
	var owner: String = str(city.get("current_faction_id", city.get("faction_id", "")))
	var power: float = float(cfg.get("base", 10))
	power += float(int(city.get("city_level", 1))) * float(cfg.get("per_level", 4))
	if bool(city.get("is_capital", false)):
		power += float(cfg.get("capital_bonus", 15))
	var div: float = maxf(float(cfg.get("development_divisor", 10)), 1.0)
	power += floor(float(int(city.get("development", 0))) / div)
	if owner.is_empty() or owner == NEUTRAL_ID:
		power *= float(cfg.get("neutral_multiplier", 0.45))
	return power


static func _influence_radius(city: Dictionary, cfg: Dictionary) -> int:
	var owner: String = str(city.get("current_faction_id", city.get("faction_id", "")))
	if owner.is_empty() or owner == NEUTRAL_ID:
		# 中立城：参与辐射，半径略小但不为 0
		return maxi(1, int(cfg.get("neutral", 3)))
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
	# 城格锁定（Voronoi 路径同样遵守）
	for city_v: Variant in cities:
		if city_v is not Dictionary:
			continue
		var c: Dictionary = city_v as Dictionary
		var c_off: Vector2i = Vector2i(int(c.get("hex_q", 0)), int(c.get("hex_r", 0)))
		var c_ax: Vector2i = _HexAxial.offset_odd_r_to_axial(c_off.x, c_off.y)
		if c_ax == cell:
			var o: String = str(c.get("current_faction_id", c.get("faction_id", "")))
			return o if not o.is_empty() else ""
	var best_city: Dictionary = {}
	var best_distance: int = 999999
	for city_v2: Variant in cities:
		if city_v2 is not Dictionary:
			continue
		var city: Dictionary = city_v2 as Dictionary
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
	if owner_id.is_empty() or owner_id == NEUTRAL_ID:
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
