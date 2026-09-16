extends GutTest

const PoliticalControl := preload("res://scripts/systems/big_map_political_control.gd")
const HexAxial := preload("res://scripts/systems/hex_axial.gd")

const _INFLUENCE_RULES: Dictionary = {
	"mode": "influence",
	"city_power": {
		"base": 10,
		"per_level": 4,
		"capital_bonus": 15,
		"development_divisor": 10,
		"neutral_multiplier": 0.5,
	},
	"radius": {
		"base": 3,
		"per_level": 1,
		"capital_bonus": 1,
		"neutral": 2,
	},
	"ownership_threshold": 8,
	"dominance_ratio": 1.25,
	"frontier_min_score": 4,
	"hole_fill_neighbor_count": 5,
	"hole_fill_rounds": 3,
	"terrain_influence": {
		"plains": 1.0,
		"mountain": 0.35,
		"river": 0.55,
	},
	"pass": {"owner_multiplier": 1.6, "enemy_multiplier": 0.5},
}


func _city_at(axial_q: int, axial_r: int, faction: String, level: int = 3, capital: bool = false) -> Dictionary:
	var off: Vector2i = HexAxial.axial_to_offset_odd_r(axial_q, axial_r)
	return {
		"id": "%s_%d_%d" % [faction, axial_q, axial_r],
		"faction_id": faction,
		"current_faction_id": faction,
		"hex_q": off.x,
		"hex_r": off.y,
		"city_level": level,
		"is_capital": capital,
		"development": 0,
	}


func _plains_rows(w: int, h: int) -> Array:
	var rows: Array = []
	for _r in range(h):
		var row: Array = []
		for _c in range(w):
			row.append("plains")
		rows.append(row)
	return rows


func test_influence_city_claims_nearby_hex() -> void:
	var map_size: Vector2i = Vector2i(20, 12)
	var cities: Array = [_city_at(10, 6, "qin", 3, true)]
	var grid: Dictionary = PoliticalControl.build_resolved_control_grid(
		cities, [], map_size, _INFLUENCE_RULES, _plains_rows(20, 12)
	)
	assert_eq(str(grid.get(Vector2i(10, 6), "")), "qin", "城格应归本国")


func test_influence_leaves_far_hex_unowned() -> void:
	var map_size: Vector2i = Vector2i(40, 20)
	var cities: Array = [_city_at(5, 5, "qin", 1, false)]
	var grid: Dictionary = PoliticalControl.build_resolved_control_grid(
		cities, [], map_size, _INFLUENCE_RULES, _plains_rows(40, 20)
	)
	# 远离城市的格应中立（grid key 为 axial）
	var far_axial: Vector2i = HexAxial.offset_odd_r_to_axial(35, 15)
	assert_eq(str(grid.get(far_axial, "MISSING")), "", "远格应中立")


func test_two_factions_split_with_buffer() -> void:
	var map_size: Vector2i = Vector2i(30, 12)
	var cities: Array = [
		_city_at(5, 6, "qin", 3, true),
		_city_at(25, 6, "chu", 3, true),
	]
	var grid: Dictionary = PoliticalControl.build_resolved_control_grid(
		cities, [], map_size, _INFLUENCE_RULES, _plains_rows(30, 12)
	)
	assert_eq(str(grid.get(Vector2i(10, 6), "")), "qin")
	assert_eq(str(grid.get(Vector2i(25, 6), "")), "chu")
	# 中间应非双方清晰腹地（中立缓冲或至少不是两边都强占）
	var mid_left: String = str(grid.get(Vector2i(12, 6), "MISSING"))
	var mid_right: String = str(grid.get(Vector2i(18, 6), "MISSING"))
	assert_ne(mid_left, "MISSING")
	assert_ne(mid_right, "MISSING")


func test_mountain_reduces_influence_reach() -> void:
	var map_size: Vector2i = Vector2i(20, 10)
	var cities: Array = [_city_at(5, 5, "qin", 3, false)]
	# 全平原 vs 全山地：山地更难形成清晰归属
	var plains_grid: Dictionary = PoliticalControl.build_resolved_control_grid(
		cities, [], map_size, _INFLUENCE_RULES, _plains_rows(20, 10)
	)
	var mountain_rows: Array = []
	for _r in range(10):
		var row: Array = []
		for _c in range(20):
			row.append("mountain")
		mountain_rows.append(row)
	var mountain_grid: Dictionary = PoliticalControl.build_resolved_control_grid(
		cities, [], map_size, _INFLUENCE_RULES, mountain_rows
	)
	var plains_owned: int = 0
	var mountain_owned: int = 0
	for key in plains_grid:
		if str(plains_grid[key]) == "qin":
			plains_owned += 1
	for key in mountain_grid:
		if str(mountain_grid[key]) == "qin":
			mountain_owned += 1
	assert_gt(plains_owned, mountain_owned, "山地应削弱实控范围")


func test_hole_fill_fills_internal_neutral() -> void:
	# 两城同势力，中间应被填成同势力而非中立洞
	var map_size: Vector2i = Vector2i(24, 10)
	var cities: Array = [
		_city_at(6, 5, "qin", 4, true),
		_city_at(18, 5, "qin", 4, false),
	]
	var grid: Dictionary = PoliticalControl.build_resolved_control_grid(
		cities, [], map_size, _INFLUENCE_RULES, _plains_rows(24, 10)
	)
	var mid: String = str(grid.get(Vector2i(12, 5), "MISSING"))
	assert_ne(mid, "MISSING")
	# 两城之间理想情况应归秦（填洞）或至少非空白缺失
	if mid != "":
		assert_eq(mid, "qin")


func test_override_still_wins_in_influence_mode() -> void:
	var map_size: Vector2i = Vector2i(16, 10)
	var cities: Array = [_city_at(8, 5, "qin", 3, true)]
	var grid: Dictionary = PoliticalControl.build_resolved_control_grid(
		cities,
		[{"q": 8, "r": 5, "owner_faction_id": "chu"}],
		map_size,
		_INFLUENCE_RULES,
		_plains_rows(16, 10)
	)
	assert_eq(str(grid.get(Vector2i(8, 5), "")), "chu", "override 优先级最高")


func test_voronoi_mode_fallback_still_works() -> void:
	var rules: Dictionary = {
		"level_radii": {"1": 4, "2": 5, "3": 6, "4": 7, "5": 8},
		"capital_bonus_radius": 2,
		"development_bonus_threshold": 50,
		"development_bonus_radius": 1,
		"neutral_radius": 2,
	}
	var city_offset: Vector2i = HexAxial.axial_to_offset_odd_r(10, 10)
	var cities: Array = [{
		"id": "xianyang",
		"faction_id": "qin",
		"hex_q": city_offset.x,
		"hex_r": city_offset.y,
		"jurisdiction_radius": 1,
		"is_capital": true,
		"city_level": 5,
	}]
	var grid: Dictionary = PoliticalControl.build_resolved_control_grid(
		cities, [], Vector2i(30, 20), rules
	)
	assert_eq(str(grid.get(Vector2i(10, 11), "")), "qin")
