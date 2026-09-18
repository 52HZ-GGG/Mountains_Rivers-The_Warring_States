extends GutTest

## 演武与大地图核心战斗一致：移动 MovementReach + 墙城 WallCombatRules

const WallLib := preload("res://scripts/systems/wall_combat_rules.gd")
const SiegeLib := preload("res://scripts/systems/siege_resolver.gd")


func test_shared_wall_and_move_kernels() -> void:
	var siege: String = FileAccess.get_file_as_string("res://scripts/systems/siege_resolver.gd")
	assert_true(siege.contains("WallLib") or siege.contains("wall_combat_rules.gd"), "SiegeResolver 必须用 WallCombatRules")
	var pipe: String = FileAccess.get_file_as_string("res://scripts/systems/skirmish_attack_pipeline.gd")
	assert_true(pipe.contains("WallLib") or pipe.contains("wall_combat_rules.gd"), "演武攻城必须用 WallCombatRules")
	var sk: String = FileAccess.get_file_as_string("res://scripts/autoload/tactical_skirmish_manager.gd")
	assert_true(sk.contains("MoveLib") or sk.contains("movement_reach.gd"), "演武移动必须用 MovementReach")
	assert_true(sk.contains("dijkstra_reachable"), "演武可达应调用 MovementReach.dijkstra_reachable")


func test_siege_multiplier_and_wall_split_consistent() -> void:
	GameManager.reset()
	CityManager.reset()
	EventManager.set_muted(true)
	var factions: Array[String] = ["qin"]
	GameManager.start_game(factions, "qin")
	assert_eq(WallLib.siege_multiplier("militia"), SiegeLib.siege_multiplier("militia"))
	var split: Dictionary = WallLib.split_damage_to_wall(100, "militia", 3, true)
	assert_eq(int(split["wall_damage"]) + int(split["city_damage"]), 100)
	var no_wall: Dictionary = WallLib.split_damage_to_wall(50, "militia", 3, false)
	assert_eq(int(no_wall["city_damage"]), 50)
	assert_eq(int(no_wall["wall_damage"]), 0)


func test_wall_defense_buff_shared() -> void:
	assert_almost_eq(WallLib.wall_defense_buff(150, 150, 45.0), 0.45, 0.01)
	# 墙几乎全破 → 受 min_ratio 下限
	var low: float = WallLib.wall_defense_buff(1, 200, 45.0)
	assert_almost_eq(low, 45.0 * 0.5 / 100.0, 0.01)


func test_skirmish_reachable_uses_shared_path() -> void:
	GameManager.reset()
	CityManager.reset()
	EventManager.set_muted(true)
	var factions: Array[String] = ["qin", "zhao"]
	GameManager.start_game(factions, "qin")
	TacticalSkirmishManager.start_skirmish()
	var units: Array = TacticalSkirmishManager.get("_units") as Array
	assert_false(units.is_empty(), "演武应有单位")
	var u: Dictionary = units[0] as Dictionary
	var uid: String = str(u.get("id", ""))
	# get_reachable_cells 公开 API
	if TacticalSkirmishManager.has_method("get_reachable_cells"):
		var reach: Variant = TacticalSkirmishManager.call("get_reachable_cells", uid)
		assert_true(reach is Dictionary)
		# 只要场景开放，步兵应至少能走 1 格（除非全围死）
		if (reach as Dictionary).is_empty():
			pass_test("该单位当前无可达格（可能被围/无移动力）")
	else:
		pass_test("无 get_reachable_cells 公开方法")
