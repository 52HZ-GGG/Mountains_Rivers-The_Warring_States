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
		if not _check_conditions(evt["trigger"].get("conditions", {}), turn_number, faction_id):
			continue
		if randf() <= evt["trigger"]["probability"]:
			_trigger_event(evt, faction_id)


func _check_conditions(conditions: Dictionary, turn_number: int, faction_id: String = "") -> bool:
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

	if conditions.has("faction"):
		if faction_id != "" and conditions["faction"] != faction_id:
			return false

	if conditions.has("at_war_with"):
		if faction_id != "" and not DiplomacySystem.are_at_war(faction_id, conditions["at_war_with"]):
			return false

	if conditions.has("tech_researched"):
		if not TechSystem.is_researched(conditions["tech_researched"]):
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


func resolve_event_choice(event_id: String, choice_id: String) -> bool:
	var evt: Dictionary = DataManager.get_event(event_id)
	if evt.is_empty():
		push_warning("EventManager: 未找到事件 %s" % event_id)
		return false
	if evt.get("options") == null:
		push_warning("EventManager: 事件 %s 无选项" % event_id)
		return false
	for opt in evt["options"]:
		if opt["id"] == choice_id:
			var cost: Dictionary = opt.get("cost", {})
			if not cost.is_empty() and not _can_afford(cost):
				push_warning("EventManager: 资源不足，无法选择选项 %s" % choice_id)
				return false
			if not cost.is_empty():
				_deduct_cost(cost)
			_apply_effects(opt["outcomes"])
			SignalBus.event_resolved.emit(event_id, choice_id)
			return true
	push_warning("EventManager: 事件 %s 中未找到选项 %s" % [event_id, choice_id])
	return false


## 检查选项是否可承担（供 UI 调用）
func can_afford_option(event_id: String, choice_id: String) -> bool:
	var evt: Dictionary = DataManager.get_event(event_id)
	if evt.is_empty() or evt.get("options") == null:
		return false
	for opt in evt["options"]:
		if opt["id"] == choice_id:
			return _can_afford(opt.get("cost", {}))
	return false


func _can_afford(cost: Dictionary) -> bool:
	if cost.has("food") and GameManager.get_player_food() < cost["food"]:
		return false
	if cost.has("gold") and GameManager.get_player_gold() < cost["gold"]:
		return false
	if cost.has("wood") and GameManager.get_player_wood() < cost["wood"]:
		return false
	if cost.has("craftsmen") and GameManager.get_player_craftsmen() < cost["craftsmen"]:
		return false
	if cost.has("building_materials") and GameManager.get_player_building_materials() < cost["building_materials"]:
		return false
	if cost.has("horse") and GameManager.get_player_horse() < cost["horse"]:
		return false
	if cost.has("refined_iron") and GameManager.get_player_refined_iron() < cost["refined_iron"]:
		return false
	return true


func _deduct_cost(cost: Dictionary) -> void:
	if cost.has("food"):
		GameManager.apply_food_delta(-cost["food"])
	if cost.has("gold"):
		GameManager.apply_gold_delta(-cost["gold"])
	if cost.has("wood"):
		GameManager.apply_wood_delta(-cost["wood"])
	if cost.has("craftsmen"):
		GameManager.apply_craftsmen_delta(-cost["craftsmen"])
	if cost.has("building_materials"):
		GameManager.apply_building_materials_delta(-cost["building_materials"])
	if cost.has("horse"):
		GameManager.apply_horse_delta(-cost["horse"])
	if cost.has("refined_iron"):
		GameManager.apply_refined_iron_delta(-cost["refined_iron"])


func _apply_effects(effects: Dictionary) -> void:
	if effects == null:
		return
	# 通过 GameManager 应用资源和民心变化
	# 具体实现依赖 GameManager 的资源管理接口
	if effects.has("food_delta"):
		GameManager.apply_food_delta(effects["food_delta"])
	if effects.has("gold_delta"):
		GameManager.apply_gold_delta(effects["gold_delta"])
	if effects.has("wood_delta"):
		GameManager.apply_wood_delta(effects["wood_delta"])
	if effects.has("craftsmen_delta"):
		GameManager.apply_craftsmen_delta(effects["craftsmen_delta"])
	if effects.has("building_materials_delta"):
		GameManager.apply_building_materials_delta(effects["building_materials_delta"])
	if effects.has("morale_delta"):
		GameManager.apply_morale_delta(effects["morale_delta"])
	if effects.has("population_delta"):
		GameManager.apply_population_delta(effects["population_delta"])
	if effects.has("troops_delta"):
		GameManager.apply_troops_delta(effects["troops_delta"])
	if effects.has("horse_delta"):
		GameManager.apply_horse_delta(effects["horse_delta"])
	if effects.has("refined_iron_delta"):
		GameManager.apply_refined_iron_delta(effects["refined_iron_delta"])
	if effects.has("school_exp"):
		SignalBus.school_exp_gained.emit(effects["school_exp"])

	# 外交数值效果
	if effects.has("reputation_change"):
		DiplomacySystem.change_reputation(GameManager.get_player_faction_id(), effects["reputation_change"])
	if effects.has("opinion_change_aid_factions"):
		DiplomacySystem.change_opinion_all_toward(GameManager.get_player_faction_id(), effects["opinion_change_aid_factions"])
	if effects.has("opinion_change_all_hezong_members"):
		DiplomacySystem.change_opinion_all_toward(GameManager.get_player_faction_id(), effects["opinion_change_all_hezong_members"])
	if effects.has("opinion_change_defector_all"):
		DiplomacySystem.change_opinion_all_toward(GameManager.get_player_faction_id(), effects["opinion_change_defector_all"])
	if effects.has("opinion_change_all_lianheng_members"):
		DiplomacySystem.change_opinion_all_toward(GameManager.get_player_faction_id(), effects["opinion_change_all_lianheng_members"])
	if effects.has("opinion_change_lianheng_allies"):
		DiplomacySystem.change_opinion_all_toward(GameManager.get_player_faction_id(), effects["opinion_change_lianheng_allies"])
	if effects.has("diplomacy_random_opinion_shift"):
		var shift_range: Dictionary = effects["diplomacy_random_opinion_shift"]
		var min_val: int = shift_range.get("min", -10)
		var max_val: int = shift_range.get("max", 10)
		var shift: int = randi_range(min_val, max_val)
		DiplomacySystem.change_opinion_all_toward(GameManager.get_player_faction_id(), shift)
	if effects.has("tribute_change"):
		DiplomacySystem.set_event_chain_flag("tribute_change", effects["tribute_change"])
	if effects.has("diplomacy_independence_bonus"):
		DiplomacySystem.set_event_chain_flag("independence_bonus", effects["diplomacy_independence_bonus"])

	# 事件链状态标记（存入 DiplomacySystem，不触发链式逻辑）
	if effects.has("diplomacy_hezong_trigger"):
		DiplomacySystem.set_event_chain_flag("hezong_active", true)
	if effects.has("diplomacy_hezong_dissolve"):
		DiplomacySystem.set_event_chain_flag("hezong_active", false)
	if effects.has("diplomacy_hezong_defection"):
		DiplomacySystem.set_event_chain_flag("hezong_defection", true)
	if effects.has("diplomacy_lianheng_trigger"):
		DiplomacySystem.set_event_chain_flag("lianheng_active", true)
	if effects.has("diplomacy_lianheng_dissolve"):
		DiplomacySystem.set_event_chain_flag("lianheng_active", false)
	if effects.has("diplomacy_lianheng_backlash"):
		DiplomacySystem.set_event_chain_flag("lianheng_backlash", true)
	if effects.has("diplomacy_zhou_aid"):
		DiplomacySystem.set_event_chain_flag("zhou_aid", true)

	# TODO: 待实现效果（需要深度系统集成）
	# grant_ability: 授予发起合纵/连横能力（需 DiplomacySystem 扩展）
	# special_victory: 九鼎/禅让特殊胜利（需胜利系统扩展）


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
