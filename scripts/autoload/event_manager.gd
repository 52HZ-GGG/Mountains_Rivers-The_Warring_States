extends Node

## 事件管理器 — 阶段1基础实现
##
## 职责：
##   1. 加载 events.json 中的事件定义
##   2. 在回合开始时检查事件触发条件（季节、民心、回合数）
##   3. 概率判定后触发事件（无选项直接生效，有选项发射信号等待UI）
##   4. 防止同一事件连续触发（冷却机制）
## 阶段4将扩展为完整的事件解析引擎。

var _events: Array = []
var _cooldowns: Dictionary = {}  # event_id -> remaining_cooldown_turns


func _ready() -> void:
	_events = DataManager.get_all_events()
	SignalBus.turn_started.connect(_on_turn_started)
	SignalBus.turn_ended.connect(_on_turn_ended)


func _on_turn_started(turn_number: int, faction_id: String) -> void:
	if not GameManager.is_player_faction(faction_id):
		return
	_check_and_trigger_events("turn_start", turn_number, faction_id)


func _on_turn_ended(_turn_number: int, _faction_id: String) -> void:
	_update_cooldowns()


func _check_and_trigger_events(timing: String, turn_number: int, faction_id: String) -> void:
	for evt in _events:
		if evt["trigger"]["type"] != timing:
			continue
		if _is_on_cooldown(evt["id"]):
			continue
		if not _check_conditions(evt["trigger"].get("conditions", {}), turn_number):
			continue
		if randf() <= evt["trigger"]["probability"]:
			_trigger_event(evt, faction_id)


func _check_conditions(conditions: Dictionary, turn_number: int) -> bool:
	if conditions.has("season"):
		var current_season: String = DataManager.get_current_season(turn_number)
		if not conditions["season"].has(current_season):
			return false

	if conditions.has("morale_min"):
		var morale: int = GameManager.get_player_morale()
		if morale < conditions["morale_min"]:
			return false

	if conditions.has("morale_max"):
		var morale: int = GameManager.get_player_morale()
		if morale > conditions["morale_max"]:
			return false

	if conditions.has("turn_min"):
		if turn_number < conditions["turn_min"]:
			return false

	if conditions.has("turn_max"):
		if turn_number > conditions["turn_max"]:
			return false

	return true


func _trigger_event(evt: Dictionary, _faction_id: String) -> void:
	var cooldown_turns: int = DataManager.get_balance_param("event_cooldown_turns")
	if cooldown_turns == null:
		cooldown_turns = 3
	_cooldowns[evt["id"]] = cooldown_turns

	if evt.get("options") != null:
		SignalBus.event_triggered.emit(evt)
	else:
		_apply_effects(evt["effects"])
		SignalBus.event_resolved.emit(evt["id"], "")


func resolve_event_choice(event_id: String, choice_id: String) -> void:
	var evt: Dictionary = DataManager.get_event(event_id)
	if evt.is_empty():
		push_warning("EventManager: 未找到事件 %s" % event_id)
		return
	if evt.get("options") == null:
		push_warning("EventManager: 事件 %s 无选项" % event_id)
		return
	for opt in evt["options"]:
		if opt["id"] == choice_id:
			_apply_effects(opt["outcomes"])
			SignalBus.event_resolved.emit(event_id, choice_id)
			return
	push_warning("EventManager: 事件 %s 中未找到选项 %s" % [event_id, choice_id])


func _apply_effects(effects: Dictionary) -> void:
	if effects == null:
		return
	# 通过 GameManager 应用资源和民心变化
	# 具体实现依赖 GameManager 的资源管理接口
	if effects.has("food_delta"):
		GameManager.apply_food_delta(effects["food_delta"])
	if effects.has("gold_delta"):
		GameManager.apply_gold_delta(effects["gold_delta"])
	if effects.has("iron_delta"):
		GameManager.apply_iron_delta(effects["iron_delta"])
	if effects.has("morale_delta"):
		GameManager.apply_morale_delta(effects["morale_delta"])
	if effects.has("population_delta"):
		GameManager.apply_population_delta(effects["population_delta"])
	if effects.has("troops_delta"):
		GameManager.apply_troops_delta(effects["troops_delta"])


func _update_cooldowns() -> void:
	var to_erase: Array = []
	for eid in _cooldowns:
		_cooldowns[eid] -= 1
		if _cooldowns[eid] <= 0:
			to_erase.append(eid)
	for eid in to_erase:
		_cooldowns.erase(eid)


func _is_on_cooldown(event_id: String) -> bool:
	return _cooldowns.has(event_id) and _cooldowns[event_id] > 0


## 重置所有状态（供测试和重新开局使用）
func reset() -> void:
	_cooldowns.clear()


## 获取当前冷却状态（供测试使用）
func get_cooldowns() -> Dictionary:
	return _cooldowns.duplicate()
