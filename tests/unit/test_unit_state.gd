extends GutTest

## UnitState v3 库本身（策略层接入待与 origin 端口化战斗对齐后补集成用例）

const UnitStateLib := preload("res://scripts/systems/unit_state.gd")


func test_make_has_v3_fields() -> void:
	var u: Dictionary = UnitStateLib.make("qin", "infantry", 5, 6, 100, 3, 2, "u1", 10, 12, [])
	assert_eq(str(u.get("id", "")), "u1")
	assert_eq(int(u.get("mp", -1)), 3)
	assert_eq(int(u.get("max_mp", -1)), 3)
	assert_eq(int(u.get("count", -1)), 2)
	assert_true(u.get("skills") is Array)
	assert_true(bool(u.get("is_supplied", false)))
	assert_eq(int(u.get("attacks_this_turn", -1)), 0)


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
