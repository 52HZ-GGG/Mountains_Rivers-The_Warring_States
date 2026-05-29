extends Node

## 事件管理器 — 三阶段流水线 v2.0
##
## 职责：
##   1. 阶段 1：链式事件（纵横家事件链，必定触发，独立于分池）
##   2. 阶段 2：季节事件（概率 1.0，每季必定触发）
##   3. 阶段 3：分池竞争（按类型优先级，每类最多 1 条）
##   4. 差异化冷却（one_shot=999, 按类型读取冷却值）
##   5. 条件判定（含 school/at_war/has_alliance/allies_min）

## 类型优先级（数值越大越优先）
const TYPE_PRIORITY: Dictionary = {
	"politics": 90,
	"season": 80,
	"diplomacy": 70,
	"military": 60,
	"special": 50,
	"school": 40,
	"economy": 30,
	"morale": 20,
}

var _events: Array = []
var _cooldowns: Dictionary = {}  # event_id -> remaining_cooldown_turns
var _chain_states: Dictionary = {}  # chain_id -> { "current_index": int }
var _triggered_categories: Dictionary = {}  # category -> true（本回合已触发的类型）
var _muted: bool = false


func _ready() -> void:
	_events = DataManager.get_all_events()
	SignalBus.turn_started.connect(_on_turn_started)
	SignalBus.turn_ended.connect(_on_turn_ended)


func _on_turn_started(turn_number: int, faction_id: String) -> void:
	if _muted:
		return
	if not GameManager.is_player_faction(faction_id):
		return
	_check_and_trigger_events("turn_start", turn_number, faction_id)


func _on_turn_ended(_turn_number: int, _faction_id: String) -> void:
	_update_cooldowns()


# ============= 三阶段流水线 =============

func _check_and_trigger_events(timing: String, turn_number: int, faction_id: String) -> void:
	_triggered_categories.clear()

	# 阶段 1：链式事件
	_process_chain_events(turn_number, faction_id)

	# 阶段 2：季节事件
	_process_season_events(turn_number, faction_id)

	# 阶段 3：分池竞争
	_process_pool_events(turn_number, faction_id)


func _process_chain_events(turn_number: int, faction_id: String) -> void:
	var chains: Array = DataManager.get_event_chains()
	for chain in chains:
		if not _is_chain_applicable(chain, faction_id):
			continue
		var chain_id: String = chain["id"]
		if not _chain_states.has(chain_id):
			_chain_states[chain_id] = {"current_index": 0}
		var state: Dictionary = _chain_states[chain_id]
		var current_index: int = state["current_index"]
		if current_index >= chain["nodes"].size():
			continue  # 链已结束
		var node: Dictionary = chain["nodes"][current_index]
		if _check_conditions(node.get("conditions", {}), turn_number, faction_id):
			var evt: Dictionary = DataManager.get_event(node["event_id"])
			if evt.is_empty():
				continue
			# 链式事件必定触发，无视概率和冷却
			if evt.get("options") != null:
				SignalBus.event_triggered.emit(evt)
			else:
				_apply_effects(evt["effects"])
				SignalBus.event_resolved.emit(evt["id"], "")
			SignalBus.chain_advanced.emit(chain_id, node["event_id"])
			# 推进指针
			if node["next"] == null:
				SignalBus.chain_completed.emit(chain_id)
				state["current_index"] = chain["nodes"].size()  # 标记结束
			else:
				state["current_index"] = current_index + 1


func _is_chain_applicable(chain: Dictionary, faction_id: String) -> bool:
	var chain_faction: String = chain.get("faction", "")
	if chain_faction != "" and chain_faction != faction_id:
		return false
	return true


func _process_season_events(turn_number: int, faction_id: String) -> void:
	var current_season: String = DataManager.get_current_season(turn_number)
	for evt in _events:
		if evt["category"] != "season":
			continue
		if _is_on_cooldown(evt["id"]):
			continue
		var conditions: Dictionary = evt["trigger"].get("conditions", {})
		if conditions.has("season") and not conditions["season"].has(current_season):
			continue
		if not _check_conditions(conditions, turn_number, faction_id):
			continue
		# 季节事件概率 1.0
		_trigger_event(evt, faction_id)
		_triggered_categories["season"] = true
		break  # 每类最多 1 条


func _process_pool_events(turn_number: int, faction_id: String) -> void:
	# 按类型优先级从高到低处理
	var sorted_types: Array = TYPE_PRIORITY.keys()
	sorted_types.sort_custom(func(a: String, b: String) -> bool: return TYPE_PRIORITY[a] > TYPE_PRIORITY[b])

	for type_name in sorted_types:
		if type_name == "season":
			continue  # 季节事件已在阶段 2 处理
		if _triggered_categories.has(type_name):
			continue  # 已被占用

		# 收集该类型中满足条件且通过概率判定的事件
		var candidates: Array = []
		for evt in _events:
			if evt.get("category", "") != type_name:
				continue
			if _is_on_cooldown(evt["id"]):
				continue
			if not _check_conditions(evt["trigger"].get("conditions", {}), turn_number, faction_id):
				continue
			if randf() <= evt["trigger"]["probability"]:
				candidates.append(evt)

		if candidates.is_empty():
			continue

		# 按 priority 排序，取最高
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return a["trigger"].get("priority", 50) > b["trigger"].get("priority", 50))
		_trigger_event(candidates[0], faction_id)
		_triggered_categories[type_name] = true


# ============= 条件判定 =============

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

	# 新增条件：school
	if conditions.has("school"):
		var current_school: String = GameManager.get_current_school()
		if current_school != conditions["school"]:
			return false

	# 新增条件：at_war
	if conditions.has("at_war"):
		var is_war: bool = DiplomacySystem.is_at_war(faction_id)
		if conditions["at_war"] != is_war:
			return false

	# 新增条件：has_alliance
	if conditions.has("has_alliance"):
		var has_ally: bool = DiplomacySystem.has_alliance(faction_id)
		if conditions["has_alliance"] != has_ally:
			return false

	# 新增条件：allies_min
	if conditions.has("allies_min"):
		var ally_count: int = DiplomacySystem.get_allies_count(faction_id)
		if ally_count < conditions["allies_min"]:
			return false

	return true


# ============= 触发与冷却 =============

func _trigger_event(evt: Dictionary, _faction_id: String) -> void:
	var cooldown_turns: int = _get_cooldown_for_event(evt)
	_cooldowns[evt["id"]] = cooldown_turns

	if evt.get("options") != null:
		SignalBus.event_triggered.emit(evt)
	else:
		_apply_effects(evt["effects"])
		SignalBus.event_resolved.emit(evt["id"], "")


func _get_cooldown_for_event(evt: Dictionary) -> int:
	# one_shot 事件冷却 999
	if evt["trigger"].get("one_shot", false):
		return 999
	# 从 balance_params.json 读取按类型冷却
	var category: String = evt.get("category", "economy")
	var cooldown_by_type: Dictionary = DataManager.get_balance_param("event_cooldown_by_type")
	if cooldown_by_type != null and cooldown_by_type.has(category):
		return cooldown_by_type[category]
	# 回退到默认值
	var default_cd = DataManager.get_balance_param("event_cooldown_turns")
	if default_cd == null:
		return 3
	return default_cd


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


# ============= 选项处理 =============

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


# ============= 效果应用 =============

func _apply_effects(effects: Dictionary) -> void:
	if effects == null:
		return
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

	# 事件链状态标记
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


# ============= 公共接口 =============

## 获取当前激活的事件链状态
func get_active_chains() -> Array:
	var result: Array = []
	for chain_id in _chain_states:
		result.append({"chain_id": chain_id, "state": _chain_states[chain_id]})
	return result


## 手动推进指定事件链（调试用）
func advance_chain(chain_id: String) -> void:
	if _chain_states.has(chain_id):
		_chain_states[chain_id]["current_index"] += 1


## 获取事件链状态（供存档系统调用）
func get_save_data() -> Dictionary:
	return {
		"cooldowns": _cooldowns.duplicate(),
		"chain_states": _chain_states.duplicate(true),
	}


## 恢复事件链状态（供读档系统调用）
func load_save_data(data: Dictionary) -> void:
	_cooldowns = data.get("cooldowns", {})
	_chain_states = data.get("chain_states", {})
	_triggered_categories.clear()


## 重置所有状态（供测试和重新开局使用）
func reset() -> void:
	_cooldowns.clear()
	_chain_states.clear()
	_triggered_categories.clear()
	_muted = false


func set_muted(muted: bool) -> void:
	_muted = muted


## 获取当前冷却状态（供测试使用）
func get_cooldowns() -> Dictionary:
	return _cooldowns.duplicate()
