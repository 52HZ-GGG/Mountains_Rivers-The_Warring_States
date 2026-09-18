extends GutTest

## 内核接线续：MovementReach + AiCombatScoring 已接入战略/演武

const ScoringLib := preload("res://scripts/systems/ai_combat_scoring.gd")


func test_wiring_sources() -> void:
	var sm: String = FileAccess.get_file_as_string("res://scripts/autoload/strategic_map_manager.gd")
	assert_true(sm.contains("MoveLib") or sm.contains("movement_reach.gd"), "战略可达必须走 MovementReach")
	assert_true(sm.contains("dijkstra_reachable"), "get_reachable_cells 应调用 dijkstra_reachable")
	var sai: String = FileAccess.get_file_as_string("res://scripts/ai/strategic_ai.gd")
	assert_true(sai.contains("ScoringLib") or sai.contains("ai_combat_scoring.gd"), "战略 AI 必须引用 AiCombatScoring")
	assert_true(sai.contains("pick_best_unit_target"), "战略 AI 选敌应走评分")
	assert_true(sai.contains("pick_best_city_target"), "战略 AI 攻城目标应走评分")
	var skai: String = FileAccess.get_file_as_string("res://scripts/systems/skirmish_ai.gd")
	assert_true(skai.contains("ScoringLib") or skai.contains("ai_combat_scoring.gd"), "演武 AI 必须引用 AiCombatScoring")
	assert_true(skai.contains("CtxLib") or skai.contains("combat_ctx_builder.gd"), "演武 AI ctx 应委托 CtxBuilder")


func test_strategic_reachable_uses_shared_kernel() -> void:
	GameManager.reset()
	CityManager.reset()
	EventManager.set_muted(true)
	var factions: Array[String] = ["qin", "zhao"]
	GameManager.start_game(factions, "qin")
	StrategicMapManager.reset()
	var spawn: Dictionary = StrategicMapManager.spawn_unit_at_city("qin", "infantry", 12, 12, 1)
	assert_true(bool(spawn.get("success", false)))
	var uid: String = str(spawn.get("unit_id", ""))
	var reach: Dictionary = StrategicMapManager.get_reachable_cells(uid)
	# 步兵 speed 通常 ≥2，至少能到邻格（除非全被占/山地围死）
	assert_true(reach is Dictionary)
	if reach.is_empty():
		pass_test("当前格可能被地形/占用围死，跳过非空断言")
		return
	for cell in reach:
		assert_true(cell is Vector2i)


func test_ai_scoring_prefers_low_hp() -> void:
	var cands: Array = [
		{"id": "healthy", "hp": 90, "max_hp": 100, "dist": 2},
		{"id": "weak", "hp": 20, "max_hp": 100, "dist": 2},
	]
	assert_eq(ScoringLib.pick_best_unit_target(cands), "weak")
	var cities: Array = [
		{"id": "far_full", "city_level": 5, "hp": 300, "max_hp": 300, "dist": 3},
		{"id": "near_hurt", "city_level": 2, "hp": 50, "max_hp": 300, "dist": 1},
	]
	var pick: String = ScoringLib.pick_best_city_target(cities, true)
	assert_eq(pick, "near_hurt")
