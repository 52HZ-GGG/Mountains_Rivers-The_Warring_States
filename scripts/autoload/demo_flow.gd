extends Node

## Demo 纵向切片状态管理。
## 固定秦国开局，七国与中立城市同场运行；玩家从经营准备进入洛邑战役，
## 胜利后回到城市经营结果，供任务 UI 与主场景查询。

signal step_completed(step_id: String)
signal target_city_captured(city_id: String, faction_id: String)
signal demo_completed(target_city_id: String)

const PLAYER_FACTION_ID: String = "qin"
const TARGET_CITY_ID: String = "luoyi"
const TARGET_CITY_NAME: String = "洛邑"
const RECOMMENDED_SCENARIO_ID: String = "luoyi_siege_demo"
const RECOMMENDED_SEASON: String = "summer"

const STEP_OPEN_BIG_MAP: String = "open_big_map"
const STEP_INSPECT_LUOYI: String = "inspect_luoyi"
const STEP_MANAGE_CAPITAL: String = "manage_capital"
const STEP_PREPARE_QIN: String = "prepare_qin"
const STEP_START_CAMPAIGN: String = "start_campaign"
const STEP_WIN_SKIRMISH: String = "win_skirmish"
const STEP_CAPTURE_LUOYI: String = "capture_luoyi"
const STEP_REVIEW_RESULT: String = "review_result"
const STEP_DEMO_COMPLETE: String = "demo_complete"

const STEP_ORDER: Array[String] = [
	STEP_OPEN_BIG_MAP,
	STEP_MANAGE_CAPITAL,
	STEP_PREPARE_QIN,
	STEP_START_CAMPAIGN,
	STEP_WIN_SKIRMISH,
	STEP_CAPTURE_LUOYI,
	STEP_REVIEW_RESULT,
	STEP_DEMO_COMPLETE,
]

var _completed_steps: Dictionary = {}
var _demo_complete: bool = false
var _enabled: bool = false
var _full_demo_enabled: bool = false
var _tutorial_enabled: bool = false


func reset() -> void:
	_completed_steps.clear()
	_demo_complete = false
	_enabled = false
	_full_demo_enabled = false
	_tutorial_enabled = false


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not _enabled:
		_completed_steps.clear()
		_demo_complete = false
		_full_demo_enabled = false
		_tutorial_enabled = false


func is_enabled() -> bool:
	return _enabled


func set_full_demo_enabled(enabled: bool) -> void:
	_full_demo_enabled = enabled
	if enabled:
		_tutorial_enabled = false


func is_full_demo_enabled() -> bool:
	return _enabled and _full_demo_enabled


func set_tutorial_enabled(enabled: bool) -> void:
	_tutorial_enabled = enabled
	if enabled:
		_full_demo_enabled = false


func is_tutorial_enabled() -> bool:
	return _enabled and _tutorial_enabled


func requires_strategy_preparation() -> bool:
	return is_full_demo_enabled()


func get_player_faction_id() -> String:
	return PLAYER_FACTION_ID


func get_target_city_id() -> String:
	return TARGET_CITY_ID


func get_target_city_name() -> String:
	return TARGET_CITY_NAME


func get_recommended_scenario_id() -> String:
	return RECOMMENDED_SCENARIO_ID


func get_recommended_season() -> String:
	return RECOMMENDED_SEASON


func get_current_step() -> String:
	if not requires_strategy_preparation():
		for step_id: String in [STEP_START_CAMPAIGN, STEP_WIN_SKIRMISH, STEP_CAPTURE_LUOYI, STEP_REVIEW_RESULT, STEP_DEMO_COMPLETE]:
			if not _completed_steps.has(step_id):
				return step_id
		return STEP_DEMO_COMPLETE
	for step_id: String in STEP_ORDER:
		if not _completed_steps.has(step_id):
			return step_id
	return STEP_DEMO_COMPLETE


func get_completed_steps() -> Dictionary:
	return _completed_steps.duplicate()


func get_strategy_snapshot() -> Dictionary:
	var city_counts: Dictionary = {}
	var neutral_count: int = 0
	var independent_count: int = 0
	var total_cities: int = 0
	for raw_city: Variant in CityManager.get_all_city_states():
		var city: Dictionary = raw_city as Dictionary
		var owner: String = str(city.get("current_faction_id", city.get("faction_id", "")))
		total_cities += 1
		if GameManager.FACTION_IDS.has(owner):
			city_counts[owner] = int(city_counts.get(owner, 0)) + 1
		elif owner == "neutral":
			neutral_count += 1
		else:
			independent_count += 1

	var target_city: Dictionary = CityManager.get_city_state(TARGET_CITY_ID)
	return {
		"player_faction_id": PLAYER_FACTION_ID,
		"target_city_id": TARGET_CITY_ID,
		"target_owner": str(target_city.get("current_faction_id", "")),
		"total_cities": total_cities,
		"faction_city_counts": city_counts,
		"neutral_city_count": neutral_count,
		"independent_city_count": independent_count,
		"active_faction_count": GameManager.FACTION_IDS.size(),
	}


func is_step_completed(step_id: String) -> bool:
	return _completed_steps.has(step_id)


func is_strategy_prepared() -> bool:
	if not requires_strategy_preparation():
		return true
	return is_step_completed(STEP_PREPARE_QIN)


func mark_step_completed(step_id: String) -> void:
	if not _enabled:
		return
	if step_id == "":
		return
	if _completed_steps.has(step_id):
		return
	_completed_steps[step_id] = true
	step_completed.emit(step_id)


func mark_strategy_prepared_if_ready() -> void:
	if not _enabled:
		return
	if is_step_completed(STEP_OPEN_BIG_MAP) and is_step_completed(STEP_MANAGE_CAPITAL):
		mark_step_completed(STEP_PREPARE_QIN)


func is_demo_complete() -> bool:
	return _demo_complete


func complete_demo() -> void:
	if not _enabled:
		return
	if _demo_complete:
		return
	mark_step_completed(STEP_DEMO_COMPLETE)
	_demo_complete = true
	demo_completed.emit(TARGET_CITY_ID)


func mark_result_reviewed() -> void:
	if not _enabled:
		return
	if not is_step_completed(STEP_CAPTURE_LUOYI):
		return
	mark_step_completed(STEP_REVIEW_RESULT)
	complete_demo()


func apply_skirmish_victory(winner_faction_id: String) -> bool:
	if not _enabled:
		return false
	if _demo_complete:
		return false
	if winner_faction_id != PLAYER_FACTION_ID:
		return false

	mark_step_completed(STEP_WIN_SKIRMISH)
	var changed: bool = CityManager.change_ownership(TARGET_CITY_ID, PLAYER_FACTION_ID)
	if not changed:
		push_warning("DemoFlow: 洛邑归属变更失败")
		return false

	mark_step_completed(STEP_CAPTURE_LUOYI)
	target_city_captured.emit(TARGET_CITY_ID, PLAYER_FACTION_ID)
	if not requires_strategy_preparation():
		complete_demo()
	return true
