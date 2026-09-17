extends GutTest

const AiScoreLib := preload("res://scripts/systems/ai_combat_scoring.gd")


func test_score_low_hp_higher_than_full() -> void:
	var low: float = AiScoreLib.score_unit_target(10, 100, 2)
	var full: float = AiScoreLib.score_unit_target(100, 100, 2)
	assert_gt(low, full, "low hp should score higher")


func test_score_adjacent_bonus() -> void:
	var near: float = AiScoreLib.score_unit_target(50, 100, 1)
	var far: float = AiScoreLib.score_unit_target(50, 100, 3)
	assert_gt(near, far, "adjacent should score higher")


func test_pick_best_unit_prefers_low_hp() -> void:
	var candidates: Array = [
		{"id": "full", "hp": 100, "max_hp": 100, "dist": 1},
		{"id": "low", "hp": 20, "max_hp": 100, "dist": 2},
	]
	var pick: String = AiScoreLib.pick_best_unit_target(candidates, false)
	assert_eq(pick, "low")


func test_pick_city_siege_bonus() -> void:
	var candidates: Array = [
		{"id": "c1", "city_level": 2, "hp": 50, "max_hp": 100, "dist": 1},
	]
	var siege_pick: String = AiScoreLib.pick_best_city_target(candidates, true)
	assert_eq(siege_pick, "c1")


func test_tutorial_move_not_null_when_candidates() -> void:
	var cells: Array = [Vector2i(1, 1), Vector2i(2, 2), Vector2i(3, 3)]
	var pick: Variant = AiScoreLib.pick_tutorial_move(cells)
	assert_not_null(pick)
