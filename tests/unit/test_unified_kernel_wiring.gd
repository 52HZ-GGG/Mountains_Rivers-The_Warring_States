extends GutTest

## U0-U8 收尾：战略层必须接入共享内核（UnitState / CtxBuilder / SiegeResolver）

const HexAxial := preload("res://scripts/systems/hex_axial.gd")


func before_each() -> void:
	GameManager.reset()
	CityManager.reset()
	EventManager.set_muted(true)
	var factions: Array[String] = ["qin", "zhao"]
	GameManager.start_game(factions, "qin")
	StrategicMapManager.reset()


func test_strategic_kernel_files_wired() -> void:
	var sm: String = FileAccess.get_file_as_string("res://scripts/autoload/strategic_map_manager.gd")
	assert_true(sm.contains("UnitStateLib") or sm.contains("unit_state.gd"), "战略层必须引用 UnitState")
	assert_true(sm.contains("CtxLib") or sm.contains("combat_ctx_builder.gd"), "战略层必须引用 CombatCtxBuilder")
	assert_true(sm.contains("SiegeLib") or sm.contains("siege_resolver.gd"), "战略层必须引用 SiegeResolver")
	assert_true(sm.contains("MoveLib") or sm.contains("movement_reach.gd"), "战略层必须引用 MovementReach")
	assert_false(sm.contains("func _build_combat_ctx") and sm.contains("SchoolManager.get_effect_float(faction_id, \"attack_bonus\")"),
		"_build_combat_ctx 不得再手写一套学派/科技加成（应委托 CtxBuilder）")


func test_city_wall_apis_exist() -> void:
	assert_true(CityManager.has_method("get_wall_hp"))
	assert_true(CityManager.has_method("get_wall_max_hp"))
	assert_true(CityManager.has_method("damage_wall"))
	var cities: Array = CityManager.get_faction_cities("qin")
	assert_false(cities.is_empty())
	var city_id: String = str((cities[0] as Dictionary).get("id", ""))
	# 无墙时返回 -1
	var wall: int = CityManager.get_wall_hp(city_id)
	assert_true(wall == -1 or wall >= 0)


func test_spawn_unit_uses_unit_state_v3() -> void:
	var result: Dictionary = StrategicMapManager.spawn_unit_at_city("qin", "infantry", 10, 10, 2)
	assert_true(bool(result.get("success", false)))
	var uid: String = str(result.get("unit_id", ""))
	var unit: Dictionary = StrategicMapManager.get_unit(uid)
	assert_false(unit.is_empty())
	assert_eq(int(unit.get("count", -1)), 2)
	assert_true(unit.has("max_mp"))
	assert_true(unit.has("skills"), "UnitState v3 必须带 skills")
	assert_true(unit.has("is_supplied"))
	assert_true(unit.has("attacks_this_turn"))


func test_try_attack_city_returns_siege_fields() -> void:
	GameManager.apply_gold_delta(3000)
	GameManager.apply_food_delta(3000)
	GameManager.apply_wood_delta(3000)
	if not DiplomacySystem.are_at_war("qin", "zhao"):
		DiplomacySystem.declare_war("qin", "zhao")
	var cities: Array = CityManager.get_faction_cities("zhao")
	assert_false(cities.is_empty())
	var city_id: String = str((cities[0] as Dictionary).get("id", ""))
	var city: Dictionary = CityManager.get_city_state(city_id)
	var cpos: Vector2i = HexAxial.offset_odd_r_to_axial(int(city.get("hex_q", 0)), int(city.get("hex_r", 0)))
	# 直接在城旁 offset 格生产，保证距离
	var spawn_col: int = int(city.get("hex_q", 0))
	var spawn_row: int = int(city.get("hex_r", 0)) + 1
	if spawn_row >= 70:
		spawn_row = int(city.get("hex_r", 0)) - 1
	var spawn: Dictionary = StrategicMapManager.spawn_unit_at_city("qin", "militia", spawn_col, spawn_row, 1)
	assert_true(bool(spawn.get("success", false)))
	var uid: String = str(spawn.get("unit_id", ""))
	var unit: Dictionary = StrategicMapManager.get_unit(uid)
	assert_false(unit.is_empty())
	unit["acted"] = false
	unit["mp"] = 3
	# 若仍超距，改写 axial 到邻格（get_unit 可能返回拷贝，用内部引用）
	if StrategicMapManager.has_method("_get_unit_ref"):
		var uref: Dictionary = StrategicMapManager._get_unit_ref(uid)
		if not uref.is_empty():
			for nb: Vector2i in HexAxial.neighbors_hex(cpos):
				uref["q"] = nb.x
				uref["r"] = nb.y
				uref["acted"] = false
				uref["mp"] = 3
				break
	var attack: Dictionary = StrategicMapManager.try_attack_city(uid, city_id)
	assert_true(bool(attack.get("ok", false)), "reason=%s" % str(attack.get("reason", "")))
	assert_true(attack.has("damage"))
	assert_true(attack.has("wall_damage"), "Siege 字段 wall_damage")
	assert_true(attack.has("counter_damage"), "Siege 字段 counter_damage")
	assert_true(int(attack.get("damage", 0)) >= 0)


func test_skirmish_pipeline_uses_ctx_builder() -> void:
	var pipe: String = FileAccess.get_file_as_string("res://scripts/systems/skirmish_attack_pipeline.gd")
	assert_true(pipe.contains("CtxLib") or pipe.contains("combat_ctx_builder.gd"), "演武管线必须引用 CtxBuilder")
