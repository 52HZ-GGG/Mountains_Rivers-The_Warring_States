extends GutTest

const UnitStateLib := preload("res://scripts/systems/unit_state.gd")


func before_each() -> void:
	GameManager.reset()
	CityManager.reset()
	MinisterManager.reset()
	TechSystem.reset()
	SchoolManager.reset()
	DiplomacySystem.reset()
	DisasterManager.reset()
	EventManager.set_muted(true)
	GameManager.start_game(["qin", "zhao", "qi", "chu", "wei"], "qin")


func test_make_has_v3_fields() -> void:
	var u: Dictionary = UnitStateLib.make("qin", "infantry", 5, 6, 100, 3, 2, "u1", 10, 12, [])
	assert_eq(str(u.get("id", "")), "u1")
	assert_eq(int(u.get("mp", -1)), 3)
	assert_eq(int(u.get("max_mp", -1)), 3)
	assert_eq(int(u.get("count", -1)), 2)
	assert_true(u.get("skills") is Array)
	assert_true(bool(u.get("is_supplied", false)))
	assert_eq(int(u.get("attacks_this_turn", -1)), 0)
	assert_eq(int(u.get("burn_turns", -1)), 0)
	assert_eq(int(u.get("stranded_turns", -1)), 0)


func test_normalize_legacy_mp_remaining() -> void:
	var legacy: Dictionary = {
		"id": "x",
		"faction_id": "qin",
		"unit_type_id": "infantry",
		"q": 1, "r": 1,
		"hp": 50, "max_hp": 50,
		"speed": 4,
		"mp_remaining": 2,
		"morale": 80,
		"acted": false,
	}
	var u: Dictionary = UnitStateLib.normalize(legacy)
	assert_eq(int(u.get("max_mp", -1)), 4, "max_mp from speed")
	assert_eq(int(u.get("mp", -1)), 2, "mp from mp_remaining")
	assert_true(bool(u.get("is_supplied", true)))
	assert_eq(int(u.get("schema_v", 0)), UnitStateLib.SCHEMA_VERSION)


func test_normalize_fills_defaults() -> void:
	var minimal: Dictionary = {
		"id": "y", "faction_id": "chu", "unit_type_id": "cavalry",
		"q": 2, "r": 3, "hp": 80, "max_hp": 80, "max_mp": 5, "mp": 5,
	}
	var u: Dictionary = UnitStateLib.normalize(minimal)
	assert_eq(int(u.get("count", -1)), 1)
	assert_eq(int(u.get("morale", -1)), 100)
	assert_true(u.get("skills") is Array)
	assert_eq(int(u.get("burn_damage", -1)), 0)


func test_spawn_unit_uses_unit_state() -> void:
	StrategicMapManager.reset()
	var result: Dictionary = StrategicMapManager.spawn_unit_at_city("qin", "infantry", 10, 10, 2)
	assert_true(bool(result.get("success", false)))
	var uid: String = str(result.get("unit_id", ""))
	var unit: Dictionary = StrategicMapManager.get_unit(uid)
	assert_false(unit.is_empty())
	assert_eq(int(unit.get("count", -1)), 2)
	assert_true(unit.has("max_mp"))
	assert_true(unit.has("skills"))
	assert_true(unit.has("is_supplied"))
	assert_true(unit.has("attacks_this_turn"))


func test_save_load_round_trip_v3() -> void:
	StrategicMapManager.reset()
	StrategicMapManager.spawn_unit_at_city("qin", "archer", 8, 8, 3)
	var save: Dictionary = StrategicMapManager.get_save_data()
	StrategicMapManager.reset()
	assert_eq((StrategicMapManager.get_save_data().get("units", []) as Array).size(), 0)
	StrategicMapManager.load_save_data(save)
	var units: Array = StrategicMapManager.get_save_data().get("units", []) as Array
	assert_eq(units.size(), 1)
	var u: Dictionary = units[0] as Dictionary
	assert_true(u.has("max_mp"))
	assert_eq(int(u.get("count", -1)), 3)
	assert_eq(int(u.get("schema_v", 0)), UnitStateLib.SCHEMA_VERSION)


func test_save_schema_version_is_3() -> void:
	assert_eq(SaveManager.SCHEMA_VERSION, 3)


func test_wall_hp_on_city_state() -> void:
	var cities: Array = CityManager.get_faction_cities("qin")
	assert_false(cities.is_empty())
	var city_id: String = str((cities[0] as Dictionary).get("id", ""))
	var wall: int = CityManager.get_wall_hp(city_id)
	assert_true(wall >= -1, "wall_hp readable")
	var state: Dictionary = CityManager.get_city_state(city_id)
	assert_true(state.has("wall_hp"), "wall_hp on city state")
