extends GutTest

## 资源预览：当前 + 净变化 = 结束回合后的资源（仓库上限截断）
## 结算顺序：产出/维护 → 城市经营（与 end_current_turn 一致）


func before_each() -> void:
	GameManager.reset()
	CityManager.reset()
	EventManager.set_muted(true)
	GameManager.start_game(["qin", "zhao"], "qin")


func test_preview_equals_current_plus_delta() -> void:
	var fid: String = "qin"
	var preview: Dictionary = GameManager.preview_faction_turn_income(fid)
	var before: Dictionary = preview.get("before", {}) as Dictionary
	var after: Dictionary = preview.get("after", {}) as Dictionary
	var production: Dictionary = preview.get("production", {}) as Dictionary
	var upkeep: Dictionary = preview.get("upkeep", {}) as Dictionary
	var gold_before: int = int(before.get("gold", 0))
	var gold_income: int = int(production.get("gold_taxed", 0))
	var gold_keep: int = int(upkeep.get("gold", 0)) + int(upkeep.get("building_gold", 0))
	var gold_after: int = int(after.get("gold", 0))
	var expect: int = maxi(0, gold_before + gold_income - gold_keep)
	var gold_cap: int = int(preview.get("caps", {}).get("gold", -1))
	if gold_cap >= 0:
		expect = mini(expect, gold_cap)
	assert_eq(gold_after, expect, "金：当前%d +入库%d -维护%d 应=%d，实际%d" % [gold_before, gold_income, gold_keep, expect, gold_after])


func test_preview_after_matches_process_production_upkeep() -> void:
	var fid: String = GameManager.get_player_faction()
	var preview: Dictionary = GameManager.preview_faction_turn_income(fid)
	var food_after_preview: int = int((preview.get("after", {}) as Dictionary).get("food", 0))
	var gold_after_preview: int = int((preview.get("after", {}) as Dictionary).get("gold", 0))
	GameManager._process_production(fid)
	GameManager._apply_upkeep(fid)
	assert_eq(GameManager.get_player_food(), food_after_preview, "粮预览应=实算 after")
	assert_eq(GameManager.get_player_gold(), gold_after_preview, "金预览应=实算 after")


func test_current_plus_green_equals_after_end_turn() -> void:
	var fid: String = GameManager.get_player_faction()
	var preview: Dictionary = GameManager.preview_faction_turn_income(fid)
	var gold_now: int = GameManager.get_player_gold()
	var gold_delta: int = int((preview.get("deltas", {}) as Dictionary).get("gold", 0))
	var gold_expect: int = int((preview.get("after", {}) as Dictionary).get("gold", 0))
	GameManager.run_ai_continuation()
	assert_eq(
		GameManager.get_player_gold(),
		gold_expect,
		"结束回合后金应=预览 after（原先 %d + 净%d → 期望 %d，实际 %d）" % [
			gold_now,
			gold_delta,
			gold_expect,
			GameManager.get_player_gold(),
		]
	)


func test_ai_build_does_not_spend_player_gold() -> void:
	var player_gold: int = GameManager.get_player_gold()
	var zhao_city: Dictionary = (CityManager.get_faction_cities("zhao")[0] as Dictionary)
	var zid: String = str(zhao_city.get("id", ""))
	# 给 AI 足够资源并强制建造
	CityManager.get_city_state(zid)["current_faction_id"] = "zhao"
	if GameManager._faction_resources.has("zhao"):
		(GameManager._faction_resources["zhao"] as Dictionary)["gold"] = 2000
		(GameManager._faction_resources["zhao"] as Dictionary)["wood"] = 2000
	var ok: bool = CityManager.start_build(zid, "farm")
	assert_true(ok, "AI 城应可建造")
	assert_eq(GameManager.get_player_gold(), player_gold, "AI 建造不得扣玩家金")
