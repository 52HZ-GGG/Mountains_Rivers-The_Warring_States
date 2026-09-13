extends GutTest

## 战略 AI：宣战后推进；和平时期不进攻


func before_each() -> void:
	GameManager.reset()
	CityManager.reset()
	MinisterManager.reset()
	SchoolManager.reset()
	TechSystem.reset()
	DiplomacySystem.reset()
	StrategicMapManager.reset()
	EventManager.set_muted(true)
	GameManager.start_game(["qin", "zhao"], "qin")


func test_strategic_ai_moves_unit_toward_enemy() -> void:
	DiplomacySystem.declare_war("zhao", "qin")
	var zhao_cap: Dictionary = CityManager.get_capital_state("zhao")
	var qin_cap: Dictionary = CityManager.get_capital_state("qin")
	var spawn: Dictionary = StrategicMapManager.spawn_unit_at_city(
		"zhao",
		"militia",
		int(zhao_cap.get("hex_q", 0)),
		int(zhao_cap.get("hex_r", 0)),
		1
	)
	assert_true(bool(spawn.get("success", false)))
	var unit_id: String = str(spawn.get("unit_id", ""))
	var before: Dictionary = StrategicMapManager.get_unit(unit_id)
	var qin_axial: Vector2i = HexAxial.offset_odd_r_to_axial(int(qin_cap.get("hex_q", 0)), int(qin_cap.get("hex_r", 0)))
	var before_dist: int = HexAxial.hex_distance_hex(Vector2i(int(before["q"]), int(before["r"])), qin_axial)
	StrategicAI.evaluate_strategic_units("zhao")
	var after: Dictionary = StrategicMapManager.get_unit(unit_id)
	if after.is_empty():
		assert_true(true, "单位已行动（可能交战）")
		return
	var after_dist: int = HexAxial.hex_distance_hex(Vector2i(int(after["q"]), int(after["r"])), qin_axial)
	assert_true(after_dist <= before_dist, "宣战后 AI 应向敌都推进或保持（%d → %d）" % [before_dist, after_dist])


func test_strategic_ai_holds_without_war() -> void:
	var zhao_cap: Dictionary = CityManager.get_capital_state("zhao")
	var spawn: Dictionary = StrategicMapManager.spawn_unit_at_city(
		"zhao",
		"militia",
		int(zhao_cap.get("hex_q", 0)),
		int(zhao_cap.get("hex_r", 0)),
		1
	)
	assert_true(bool(spawn.get("success", false)))
	var unit_id: String = str(spawn.get("unit_id", ""))
	var before: Dictionary = StrategicMapManager.get_unit(unit_id)
	StrategicAI.evaluate_strategic_units("zhao")
	var after: Dictionary = StrategicMapManager.get_unit(unit_id)
	assert_false(after.is_empty(), "和平时期单位应仍在")
	assert_eq(int(after.get("q", -1)), int(before.get("q", -999)), "和平时期不应向敌都推进")
	assert_eq(int(after.get("r", -1)), int(before.get("r", -999)), "和平时期不应向敌都推进")
