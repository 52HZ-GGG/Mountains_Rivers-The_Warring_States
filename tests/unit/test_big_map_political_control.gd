extends GutTest

const PoliticalControl := preload("res://scripts/systems/big_map_political_control.gd")
const HexAxial := preload("res://scripts/systems/hex_axial.gd")


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
