extends GutTest

const PoliticalControl := preload("res://scripts/systems/big_map_political_control.gd")
const HexAxial := preload("res://scripts/systems/hex_axial.gd")

const _TEST_RADIUS_RULES: Dictionary = {
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
}


func test_single_city_claims_tiles_within_radius() -> void:
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
	var owner: Variant = PoliticalControl.resolve_owner_for_axial(10, 11, cities, {})
	assert_eq(owner, "qin")


func test_level_and_capital_expand_authored_radius() -> void:
	var city_offset: Vector2i = HexAxial.axial_to_offset_odd_r(10, 10)
	var cities: Array = [{
		"id": "xianyang",
		"faction_id": "qin",
		"hex_q": city_offset.x,
		"hex_r": city_offset.y,
		"jurisdiction_radius": 1,
		"is_capital": true,
		"city_level": 5,
		"development": 75,
	}]
	var owner: Variant = PoliticalControl.resolve_owner_for_axial(20, 10, cities, {}, _TEST_RADIUS_RULES)
	assert_eq(owner, "qin", "首都与高发展城市应以推导半径形成大地图势力范围")


func test_current_faction_controls_derived_political_owner() -> void:
	var city_offset: Vector2i = HexAxial.axial_to_offset_odd_r(10, 10)
	var cities: Array = [{
		"id": "luoyi",
		"faction_id": "neutral",
		"current_faction_id": "qin",
		"hex_q": city_offset.x,
		"hex_r": city_offset.y,
		"jurisdiction_radius": 1,
		"is_capital": false,
		"city_level": 3,
	}]
	var owner: Variant = PoliticalControl.resolve_owner_for_axial(14, 10, cities, {}, _TEST_RADIUS_RULES)
	assert_eq(owner, "qin", "城市易主后政治地图应使用 current_faction_id")


func test_neutral_city_uses_smaller_temporary_radius() -> void:
	var city_offset: Vector2i = HexAxial.axial_to_offset_odd_r(10, 10)
	var cities: Array = [{
		"id": "luoyi",
		"faction_id": "neutral",
		"current_faction_id": "neutral",
		"hex_q": city_offset.x,
		"hex_r": city_offset.y,
		"jurisdiction_radius": 1,
		"is_capital": false,
		"city_level": 5,
	}]
	var near_owner: Variant = PoliticalControl.resolve_owner_for_axial(12, 10, cities, {}, _TEST_RADIUS_RULES)
	var far_owner: Variant = PoliticalControl.resolve_owner_for_axial(13, 10, cities, {}, _TEST_RADIUS_RULES)
	assert_eq(near_owner, "neutral")
	assert_eq(far_owner, null)


func test_nearest_city_wins_before_other_rules() -> void:
	var a_offset: Vector2i = HexAxial.axial_to_offset_odd_r(10, 10)
	var b_offset: Vector2i = HexAxial.axial_to_offset_odd_r(14, 10)
	var cities: Array = [
		{"id": "a", "faction_id": "qin", "hex_q": a_offset.x, "hex_r": a_offset.y, "jurisdiction_radius": 3, "is_capital": false, "city_level": 1},
		{"id": "b", "faction_id": "chu", "hex_q": b_offset.x, "hex_r": b_offset.y, "jurisdiction_radius": 5, "is_capital": true, "city_level": 9},
	]
	var owner: Variant = PoliticalControl.resolve_owner_for_axial(11, 10, cities, {})
	assert_eq(owner, "qin")


func test_capital_breaks_distance_ties() -> void:
	var a_offset: Vector2i = HexAxial.axial_to_offset_odd_r(10, 10)
	var b_offset: Vector2i = HexAxial.axial_to_offset_odd_r(12, 10)
	var cities: Array = [
		{"id": "a", "faction_id": "qin", "hex_q": a_offset.x, "hex_r": a_offset.y, "jurisdiction_radius": 3, "is_capital": false, "city_level": 3},
		{"id": "b", "faction_id": "chu", "hex_q": b_offset.x, "hex_r": b_offset.y, "jurisdiction_radius": 3, "is_capital": true, "city_level": 1},
	]
	var owner: Variant = PoliticalControl.resolve_owner_for_axial(11, 10, cities, {})
	assert_eq(owner, "chu")


func test_city_level_breaks_remaining_ties() -> void:
	var a_offset: Vector2i = HexAxial.axial_to_offset_odd_r(10, 10)
	var b_offset: Vector2i = HexAxial.axial_to_offset_odd_r(12, 10)
	var cities: Array = [
		{"id": "a", "faction_id": "qin", "hex_q": a_offset.x, "hex_r": a_offset.y, "jurisdiction_radius": 3, "is_capital": false, "city_level": 2},
		{"id": "b", "faction_id": "chu", "hex_q": b_offset.x, "hex_r": b_offset.y, "jurisdiction_radius": 3, "is_capital": false, "city_level": 4},
	]
	var owner: Variant = PoliticalControl.resolve_owner_for_axial(11, 10, cities, {})
	assert_eq(owner, "chu")


func test_city_id_breaks_final_ties() -> void:
	var a_offset: Vector2i = HexAxial.axial_to_offset_odd_r(10, 10)
	var b_offset: Vector2i = HexAxial.axial_to_offset_odd_r(12, 10)
	var cities: Array = [
		{"id": "zeta", "faction_id": "qin", "hex_q": a_offset.x, "hex_r": a_offset.y, "jurisdiction_radius": 3, "is_capital": false, "city_level": 2},
		{"id": "alpha", "faction_id": "chu", "hex_q": b_offset.x, "hex_r": b_offset.y, "jurisdiction_radius": 3, "is_capital": false, "city_level": 2},
	]
	var owner: Variant = PoliticalControl.resolve_owner_for_axial(11, 10, cities, {})
	assert_eq(owner, "chu")


func test_override_can_force_faction_or_unowned() -> void:
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
	var map_size: Vector2i = Vector2i(30, 20)
	var forced: Dictionary = PoliticalControl.build_resolved_control_grid(cities, [{
		"q": 10,
		"r": 10,
		"owner_faction_id": "chu",
	}], map_size)
	assert_eq(str(forced.get(Vector2i(10, 10), "")), "chu")
	var cleared: Dictionary = PoliticalControl.build_resolved_control_grid(cities, [{
		"q": 10,
		"r": 10,
		"owner_faction_id": null,
	}], map_size)
	assert_eq(str(cleared.get(Vector2i(10, 10), "")), "")


# ============= 影响力模式 P0：城格锁定 / 中立城源 / 关隘源 =============

const _INFLUENCE_RULES: Dictionary = {
	"mode": "influence",
	"city_power": {
		"base": 10,
		"per_level": 4,
		"capital_bonus": 15,
		"development_divisor": 10,
		"neutral_multiplier": 0.45,
	},
	"radius": {
		"base": 3,
		"per_level": 1,
		"capital_bonus": 1,
		"neutral": 3,
	},
	"ownership_threshold": 8.0,
	"dominance_ratio": 1.25,
	"frontier_min_score": 4.0,
	"hole_fill_neighbor_count": 4,
	"hole_fill_rounds": 2,
	"city_cell_lock": true,
	"core_boost": 1.35,
	"neutral_city_protected": true,
	"pass": {
		"as_source": true,
		"power": 7,
		"radius": 2,
		"owner_multiplier": 1.6,
		"enemy_multiplier": 0.5,
		"lock_self": true,
		"adjacent_owner_bonus": 0.2,
	},
	"terrain_influence": {"plains": 1.0, "pass": 1.0, "mountain": 0.35},
}


func test_influence_city_cell_locked_to_owner() -> void:
	# 魏国弱城被赵国强城包围：城格仍必须属于魏
	var wei_off: Vector2i = HexAxial.axial_to_offset_odd_r(20, 10)
	var zhao_off: Vector2i = HexAxial.axial_to_offset_odd_r(22, 10)
	var cities: Array = [
		{"id": "wei_city", "current_faction_id": "wei", "faction_id": "wei", "hex_q": wei_off.x, "hex_r": wei_off.y, "city_level": 1, "development": 0, "is_capital": false},
		{"id": "zhao_city", "current_faction_id": "zhao", "faction_id": "zhao", "hex_q": zhao_off.x, "hex_r": zhao_off.y, "city_level": 5, "development": 80, "is_capital": true},
	]
	var map_size: Vector2i = Vector2i(40, 30)
	var grid: Dictionary = PoliticalControl.build_resolved_control_grid(cities, [], map_size, _INFLUENCE_RULES)
	var wei_axial: Vector2i = HexAxial.offset_odd_r_to_axial(wei_off.x, wei_off.y)
	assert_eq(str(grid.get(wei_axial, "?")), "wei", "城市格必须锁定为城主势力")
	# 城周 1 环辖区也归城主（与建筑辖区同一套视觉邻格）
	for nb: Vector2i in HexAxial.offset_visual_neighbors(wei_off.x, wei_off.y):
		var nb_axial: Vector2i = HexAxial.offset_odd_r_to_axial(nb.x, nb.y)
		if not PoliticalControl.is_axial_in_big_map_bounds(nb_axial.x, nb_axial.y, map_size):
			continue
		assert_eq(str(grid.get(nb_axial, "?")), "wei", "城周 1 环辖区必须归城主（视觉邻格 %s）" % str(nb))


func test_influence_neutral_city_not_absorbed() -> void:
	var neu_off: Vector2i = HexAxial.axial_to_offset_odd_r(20, 10)
	var zhao_off: Vector2i = HexAxial.axial_to_offset_odd_r(23, 10)
	var cities: Array = [
		{"id": "neutral_city", "current_faction_id": "neutral", "faction_id": "neutral", "hex_q": neu_off.x, "hex_r": neu_off.y, "city_level": 2, "development": 10, "is_capital": false},
		{"id": "zhao_city", "current_faction_id": "zhao", "faction_id": "zhao", "hex_q": zhao_off.x, "hex_r": zhao_off.y, "city_level": 5, "development": 80, "is_capital": true},
	]
	var map_size: Vector2i = Vector2i(40, 30)
	var grid: Dictionary = PoliticalControl.build_resolved_control_grid(cities, [], map_size, _INFLUENCE_RULES)
	var neu_axial: Vector2i = HexAxial.offset_odd_r_to_axial(neu_off.x, neu_off.y)
	assert_eq(str(grid.get(neu_axial, "?")), "", "中立城格不得被邻国吸收")
	for nb: Vector2i in HexAxial.offset_visual_neighbors(neu_off.x, neu_off.y):
		var nb_axial: Vector2i = HexAxial.offset_odd_r_to_axial(nb.x, nb.y)
		if not PoliticalControl.is_axial_in_big_map_bounds(nb_axial.x, nb_axial.y, map_size):
			continue
		assert_eq(str(grid.get(nb_axial, "?")), "", "中立城周 1 环不得被邻国吸收")


func test_influence_pass_is_weaker_source() -> void:
	var cities: Array = [{
		"id": "qin_city", "current_faction_id": "qin", "faction_id": "qin",
		"hex_q": 10, "hex_r": 10, "city_level": 1, "development": 0, "is_capital": false,
	}]
	var pass_axial: Vector2i = Vector2i(16, 10)
	var far_axial: Vector2i = Vector2i(18, 10)
	var passes: Array = [{
		"axial_q": pass_axial.x,
		"axial_r": pass_axial.y,
		"owner": "zhao",
	}]
	var map_size: Vector2i = Vector2i(40, 30)
	var grid: Dictionary = PoliticalControl.build_resolved_control_grid(cities, [], map_size, _INFLUENCE_RULES, [], passes)
	assert_eq(str(grid.get(pass_axial, "?")), "zhao", "关隘格应锁定归属势力")
	# 关隘源弱于城市：远离关隘、也不在城市强辐射内的格不应被关隘单独染成大片赵土
	var pass_far_owner: String = str(grid.get(far_axial, ""))
	# 距离关隘 2，在 radius=2 内可能仍为赵；距离 3 以外应更易中立
	var beyond: Vector2i = Vector2i(20, 10)
	assert_eq(str(grid.get(beyond, "")), "", "关隘辐射半径有限，不应吞并远方格")
