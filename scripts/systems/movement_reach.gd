class_name MovementReach

## 共享移动可达（统一规范 §6）
## 地形 move_cost、骑兵/水军限制、ZOC 额外消耗。
## 适配层负责：占用格、城墙挡格、地图边界。

const HexLib := preload("res://scripts/systems/hex_axial.gd")
const BIG_MOVE: int = 9999


static func generates_zoc(unit: Dictionary) -> bool:
	var type_id: String = str(unit.get("unit_type_id", ""))
	var udata: Dictionary = DataManager.get_unit_type(type_id)
	if udata.is_empty():
		return false
	var category: String = str(udata.get("category", ""))
	var zoc_data: Variant = DataManager.get_balance_param("zoc.generates_zoc")
	if zoc_data is Dictionary:
		return bool(zoc_data.get(category, false))
	return false


static func is_zoc_immune(unit_type_id: String) -> bool:
	var udata: Dictionary = DataManager.get_unit_type(unit_type_id)
	if udata.is_empty():
		return false
	var special: Variant = udata.get("special", null)
	if special != null and str(special) == "recon":
		return true
	var category: String = str(udata.get("category", ""))
	if category == "navy":
		var navy_v: Variant = DataManager.get_balance_param("zoc.navy_immune_to_land_zoc")
		return bool(navy_v) if navy_v != null else true
	return false


## cell 是否在敌方 ZOC 内（units 为 UnitState 数组）
static func is_in_enemy_zoc(cell: Vector2i, moving_faction: String, units: Array) -> bool:
	var base_range_v: Variant = DataManager.get_balance_param("zoc.base_range")
	var base_range: int = int(base_range_v) if base_range_v != null else 1
	for u: Variant in units:
		var unit: Dictionary = u as Dictionary
		if str(unit.get("faction_id", "")) == moving_faction:
			continue
		if not generates_zoc(unit):
			continue
		var enemy_pos: Vector2i = Vector2i(int(unit.get("q", 0)), int(unit.get("r", 0)))
		if HexLib.hex_distance_hex(cell, enemy_pos) <= base_range:
			return true
	return false


static func zoc_extra_move_cost() -> int:
	var zoc_cost_v: Variant = DataManager.get_balance_param("zoc.extra_move_cost")
	return int(zoc_cost_v) if zoc_cost_v != null else 1


## 地形移动消耗；不可通行返回 BIG_MOVE
static func terrain_move_cost(cell_offset: Vector2i, unit_type_id: String, terrain_id_provider: Callable = Callable()) -> int:
	var terrain_id: String = ""
	if terrain_id_provider.is_valid():
		terrain_id = str(terrain_id_provider.call(cell_offset.x, cell_offset.y))
	else:
		terrain_id = CityManager.get_big_map_terrain_id(cell_offset.x, cell_offset.y)
	var terrain: Dictionary = DataManager.get_terrain(terrain_id)
	if terrain.is_empty():
		return BIG_MOVE
	var move_cost: int = int(terrain.get("move_cost", 1))
	if move_cost < 0:
		return BIG_MOVE
	var udata: Dictionary = DataManager.get_unit_type(unit_type_id)
	var category: String = str(udata.get("category", "")) if not udata.is_empty() else ""
	if category == "cavalry" and not bool(terrain.get("cavalry_allowed", true)):
		return BIG_MOVE
	return maxi(1, move_cost)


## 大地图 Dijkstra 可达格
## occupied_checker: Callable(axial) -> bool，true=不可通过
## wall_blocker: Callable(axial) -> bool，true=不可通过（城墙等）
static func dijkstra_reachable(
	origin: Vector2i,
	mp_budget: int,
	unit_type_id: String,
	moving_faction: String,
	units_for_zoc: Array,
	bounds_min: Vector2i,
	bounds_max: Vector2i,
	occupied_checker: Callable = Callable(),
	wall_blocker: Callable = Callable(),
	terrain_id_provider: Callable = Callable()
) -> Dictionary:
	var result: Dictionary = {}
	if mp_budget <= 0:
		return result
	var best: Dictionary = {origin: 0}
	var frontier: Array = [{"cell": origin, "cost": 0}]
	var zoc_immune: bool = is_zoc_immune(unit_type_id)
	var use_zoc: bool = moving_faction != "" and not zoc_immune
	while not frontier.is_empty():
		frontier.sort_custom(func(a: Variant, b: Variant) -> bool:
			return int((a as Dictionary).get("cost", 0)) < int((b as Dictionary).get("cost", 0)))
		var node: Variant = frontier.pop_front()
		if not (node is Dictionary):
			continue
		var node_dict: Dictionary = node as Dictionary
		var cell: Vector2i = node_dict["cell"] as Vector2i
		var cost: int = int(node_dict.get("cost", 0))
		if cost > mp_budget:
			continue
		if best.has(cell) and int(best[cell]) < cost:
			continue
		for neighbor: Vector2i in HexLib.neighbors_hex(cell):
			var offset: Vector2i = HexLib.axial_to_offset_odd_r(neighbor.x, neighbor.y)
			if offset.x < bounds_min.x or offset.y < bounds_min.y \
				or offset.x > bounds_max.x or offset.y > bounds_max.y:
				continue
			if occupied_checker.is_valid() and bool(occupied_checker.call(neighbor)):
				continue
			if wall_blocker.is_valid() and bool(wall_blocker.call(neighbor)):
				continue
			var move_cost: int = terrain_move_cost(offset, unit_type_id, terrain_id_provider)
			if move_cost >= BIG_MOVE:
				continue
			if use_zoc and is_in_enemy_zoc(neighbor, moving_faction, units_for_zoc):
				move_cost += zoc_extra_move_cost()
			var new_cost: int = cost + move_cost
			if new_cost > mp_budget:
				continue
			if best.has(neighbor) and int(best[neighbor]) <= new_cost:
				continue
			best[neighbor] = new_cost
			frontier.append({"cell": neighbor, "cost": new_cost})
	for cell: Vector2i in best:
		if cell == origin:
			continue
		result[cell] = int(best[cell])
	return result


## 远程有效射程（统一规范 §6）：低处向高处射击，高程差减射程
static func effective_range(attacker_cell_offset: Vector2i, defender_cell_offset: Vector2i, base_range: int) -> int:
	if base_range <= 1:
		return base_range
	var atk_terrain: String = CityManager.get_big_map_terrain_id(attacker_cell_offset.x, attacker_cell_offset.y)
	var def_terrain: String = CityManager.get_big_map_terrain_id(defender_cell_offset.x, defender_cell_offset.y)
	return effective_range_terrain(atk_terrain, def_terrain, base_range)


static func effective_range_terrain(attacker_terrain_id: String, defender_terrain_id: String, base_range: int) -> int:
	if base_range <= 1:
		return base_range
	var atk_elev: int = int(DataManager.get_terrain(attacker_terrain_id).get("elevation", 0))
	var def_elev: int = int(DataManager.get_terrain(defender_terrain_id).get("elevation", 0))
	var diff: int = def_elev - atk_elev
	if diff > 0:
		return maxi(0, base_range - diff)
	return base_range
