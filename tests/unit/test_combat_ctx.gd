extends GutTest

const CtxBuilder := preload("res://scripts/systems/combat_ctx_builder.gd")


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


func test_build_attack_ctx_is_dictionary() -> void:
	var ctx: Dictionary = CtxBuilder.build_attack_ctx("qin", "infantry", [], "summer", false)
	assert_true(ctx is Dictionary)


func test_build_attack_ctx_fire_sets_flag() -> void:
	var ctx: Dictionary = CtxBuilder.build_attack_ctx("qin", "archer", [], "summer", true)
	assert_true(bool(ctx.get("is_fire_attack", false)))
	assert_gt(float(ctx.get("fire_bonus", 0.0)), 0.0)


func test_build_defense_ctx_empty_ok() -> void:
	var ctx: Dictionary = CtxBuilder.build_defense_ctx("zhao", "infantry")
	assert_true(ctx is Dictionary)


func test_passive_skill_bonus() -> void:
	var skills: Array = [
		{"type": "passive", "value": 0.15},
		{"type": "recon", "value": 1},
	]
	assert_almost_eq(CtxBuilder.passive_skill_bonus(skills), 0.15, 0.001)


func test_strategic_damage_uses_ctx_builder() -> void:
	StrategicMapManager.reset()
	var a: Dictionary = StrategicMapManager.spawn_unit_at_city("qin", "infantry", 10, 10, 1)
	var d: Dictionary = StrategicMapManager.spawn_unit_at_city("zhao", "militia", 11, 10, 1)
	var au: Dictionary = StrategicMapManager.get_unit(str(a.get("unit_id", "")))
	var du: Dictionary = StrategicMapManager.get_unit(str(d.get("unit_id", "")))
	assert_false(au.is_empty())
	assert_false(du.is_empty())
	var dmg: int = StrategicMapManager._compute_unit_damage(au, du)
	assert_true(dmg >= 1, "damage should be at least 1, got %d" % dmg)
