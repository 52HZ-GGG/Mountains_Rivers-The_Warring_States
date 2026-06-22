extends Node

## 学派运行时管理器（最小闭环）
##
## 当前实现：
## - 每势力运行时学派状态：当前学派、等级、经验、激活政策、持续回合
## - 经验增减 / 自动升级
## - 政策激活 / 过期
## - 按等级 + 政策 + 季节汇总效果

var _school_state_by_faction: Dictionary = {}
const _POLICY_SLOT_EFFECT_KEYS: Array[String] = [
	"all_output_bonus",
	"research_speed_bonus",
	"recruit_efficiency",
	"build_cost_reduction",
	"trade_bonus",
	"food_consumption_reduction",
	"alliance_cost_multiplier",
	"diplomacy_opinion_multiplier",
	"fire_attack_bonus",
	"wall_hp_bonus",
	"special_unit_recruit",
]


func _ready() -> void:
	SignalBus.turn_started.connect(_on_turn_started)
	SignalBus.school_exp_gained.connect(_on_school_exp_gained)


func reset() -> void:
	_school_state_by_faction.clear()


func initialize_factions(active_factions: Array[String]) -> void:
	reset()
	for faction_id in active_factions:
		var faction: Dictionary = DataManager.get_faction(faction_id)
		var school_id: String = str(faction.get("default_school", ""))
		_school_state_by_faction[faction_id] = {
			"current_school": school_id,
			"level": 1 if school_id != "" else 0,
			"exp": 0,
			"active_policies": [],
			"transition_turns": 0,
		}


func get_save_data() -> Dictionary:
	return {
		"faction_states": _school_state_by_faction.duplicate(true),
	}


func load_save_data(data: Dictionary) -> void:
	var faction_states: Variant = data.get("faction_states", {})
	if faction_states is Dictionary:
		_school_state_by_faction = (faction_states as Dictionary).duplicate(true)
	else:
		_school_state_by_faction.clear()


func has_faction_school(faction_id: String) -> bool:
	return _school_state_by_faction.has(faction_id)


func get_school_state(faction_id: String) -> Dictionary:
	if not _school_state_by_faction.has(faction_id):
		return {}
	return (_school_state_by_faction[faction_id] as Dictionary).duplicate(true)


func get_current_school(faction_id: String) -> String:
	if not _school_state_by_faction.has(faction_id):
		return ""
	return str((_school_state_by_faction[faction_id] as Dictionary).get("current_school", ""))


func get_school_level(faction_id: String) -> int:
	if not _school_state_by_faction.has(faction_id):
		return 0
	return int((_school_state_by_faction[faction_id] as Dictionary).get("level", 0))


func get_school_exp(faction_id: String) -> int:
	if not _school_state_by_faction.has(faction_id):
		return 0
	return int((_school_state_by_faction[faction_id] as Dictionary).get("exp", 0))


func get_active_policies(faction_id: String) -> Array:
	if not _school_state_by_faction.has(faction_id):
		return []
	var policies: Array = (_school_state_by_faction[faction_id] as Dictionary).get("active_policies", [])
	return policies.duplicate(true)


func get_transition_turns(faction_id: String) -> int:
	if not _school_state_by_faction.has(faction_id):
		return 0
	return int((_school_state_by_faction[faction_id] as Dictionary).get("transition_turns", 0))


func is_in_transition(faction_id: String) -> bool:
	return get_transition_turns(faction_id) > 0


func get_policy_slot_limit(faction_id: String) -> int:
	if not _school_state_by_faction.has(faction_id):
		return 0
	var state: Dictionary = _school_state_by_faction[faction_id]
	var school_level: int = int(state.get("level", 0))
	var max_slots: int = int(DataManager.get_balance_param("school.max_policy_slots"))
	return mini(school_level, max_slots)


func add_school_exp(faction_id: String, amount: int) -> void:
	if amount == 0 or not _school_state_by_faction.has(faction_id):
		return
	var state: Dictionary = _school_state_by_faction[faction_id]
	state["exp"] = maxi(0, int(state.get("exp", 0)) + amount)
	_try_level_up(faction_id)


func set_current_school(faction_id: String, school_id: String) -> bool:
	if not _school_state_by_faction.has(faction_id):
		return false
	if school_id != "" and DataManager.get_school(school_id).is_empty():
		return false
	var state: Dictionary = _school_state_by_faction[faction_id]
	var old_school: String = str(state.get("current_school", ""))
	if old_school == school_id:
		return true
	for policy_state_v in state.get("active_policies", []):
		var policy_state: Dictionary = policy_state_v as Dictionary
		SignalBus.school_policy_expired.emit(old_school, str(policy_state.get("policy_id", "")))
	state["current_school"] = school_id
	state["level"] = 1 if school_id != "" else 0
	state["active_policies"] = []
	state["transition_turns"] = int(DataManager.get_balance_param("school.switch_transition_turns"))
	SignalBus.school_switched.emit(faction_id, old_school, school_id)
	return true


func activate_policy(faction_id: String, policy_id: String, target_faction_id: String = "", target_relation_delta: int = 0) -> Dictionary:
	if not _school_state_by_faction.has(faction_id):
		return {"success": false, "reason": "INVALID_FACTION"}
	if is_in_transition(faction_id):
		return {"success": false, "reason": "TRANSITION_LOCKED"}
	var policy: Dictionary = get_policy_definition(faction_id, policy_id)
	if policy.is_empty():
		return {"success": false, "reason": "INVALID_POLICY"}
	var state: Dictionary = _school_state_by_faction[faction_id]
	var school_level: int = int(state.get("level", 0))
	var unlock_level: int = int(policy.get("unlock_level", 1))
	if school_level < unlock_level:
		return {"success": false, "reason": "LEVEL_LOCKED"}
	var effect_data: Dictionary = policy.get("effects", {})
	var duration_turns: int = int(policy.get("duration_turns", 0))
	if _policy_uses_slot(policy):
		var policy_slots: int = get_policy_slot_limit(faction_id)
		if policy_slots <= 0:
			return {"success": false, "reason": "NO_POLICY_SLOT"}
		if not _has_active_policy(state, policy_id) and _count_slot_occupying_policies(faction_id, state) >= policy_slots:
			return {"success": false, "reason": "NO_POLICY_SLOT"}
	var exp_cost: int = int(policy.get("exp_cost", 0))
	if int(state.get("exp", 0)) < exp_cost:
		return {"success": false, "reason": "INSUFFICIENT_EXP"}
	state["exp"] = int(state.get("exp", 0)) - exp_cost
	if effect_data.has("morale_delta"):
		GameManager.apply_faction_resource_delta(faction_id, "morale", int(effect_data.get("morale_delta", 0)))
	if effect_data.has("target_relation_delta") and target_faction_id != "":
		var relation_delta: int = target_relation_delta if target_relation_delta != 0 else int(effect_data.get("target_relation_delta", 0))
		DiplomacySystem.change_opinion(faction_id, target_faction_id, relation_delta)
		DiplomacySystem.change_opinion(target_faction_id, faction_id, relation_delta)
	if duration_turns > 0 or effect_data.has("all_output_bonus") or effect_data.has("research_speed_bonus") or effect_data.has("recruit_efficiency") or effect_data.has("build_cost_reduction") or effect_data.has("trade_bonus") or effect_data.has("food_consumption_reduction") or effect_data.has("alliance_cost_multiplier") or effect_data.has("diplomacy_opinion_multiplier") or effect_data.has("fire_attack_bonus") or effect_data.has("wall_hp_bonus") or effect_data.has("special_unit_recruit"):
		_add_or_replace_policy(state, policy_id, duration_turns)
		SignalBus.school_policy_activated.emit(get_current_school(faction_id), policy_id)
	return {"success": true}


func get_effect_float(faction_id: String, effect_key: String) -> float:
	var effects: Dictionary = get_effects(faction_id)
	return float(effects.get(effect_key, 0.0))


func get_effect_value(faction_id: String, effect_key: String) -> Variant:
	var effects: Dictionary = get_effects(faction_id)
	return effects.get(effect_key, null)


func get_effects(faction_id: String, season: String = "") -> Dictionary:
	if not _school_state_by_faction.has(faction_id):
		return {}
	var state: Dictionary = _school_state_by_faction[faction_id]
	var school_id: String = str(state.get("current_school", ""))
	if school_id == "":
		return {}
	var multiplier: float = 1.0
	if int(state.get("transition_turns", 0)) > 0:
		multiplier = float(DataManager.get_balance_param("school.switch_transition_effect_multiplier"))
		if is_zero_approx(multiplier):
			return {}
	var school: Dictionary = DataManager.get_school(school_id)
	if school.is_empty():
		return {}
	var result: Dictionary = {}
	var active_season: String = season if season != "" else CityManager.get_current_season(GameManager.get_current_turn())
	var level: int = int(state.get("level", 0))
	var level_effects: Dictionary = school.get("level_effects", {})
	for current_level in range(1, level + 1):
		var level_data: Dictionary = level_effects.get(str(current_level), {})
		var effects: Dictionary = level_data.get("effects", {})
		_merge_effects(result, effects, multiplier)
		var season_bonus: Dictionary = effects.get("season_bonus", {})
		if season_bonus.has(active_season):
			_merge_effects(result, season_bonus.get(active_season, {}), multiplier)
	for policy_state_v in state.get("active_policies", []):
		var policy_state: Dictionary = policy_state_v as Dictionary
		var policy: Dictionary = get_policy_definition(faction_id, str(policy_state.get("policy_id", "")))
		if policy.is_empty():
			continue
		_merge_effects(result, policy.get("effects", {}), 1.0)
	return result


func get_policy_definition(faction_id: String, policy_id: String) -> Dictionary:
	var school_id: String = get_current_school(faction_id)
	for policy in DataManager.get_all_school_general_policies():
		var policy_data: Dictionary = policy as Dictionary
		if str(policy_data.get("id", "")) == policy_id:
			return policy_data
	if school_id == "":
		return {}
	var school: Dictionary = DataManager.get_school(school_id)
	for policy in school.get("exclusive_policies", []):
		var policy_data: Dictionary = policy as Dictionary
		if str(policy_data.get("id", "")) == policy_id:
			return policy_data
	return {}


func _on_turn_started(_turn_number: int, faction_id: String) -> void:
	_tick_policy_durations(faction_id)


func _on_school_exp_gained(amount: int) -> void:
	var faction_id: String = GameManager.get_player_faction()
	if faction_id == "":
		return
	add_school_exp(faction_id, amount)


func _tick_policy_durations(faction_id: String) -> void:
	if not _school_state_by_faction.has(faction_id):
		return
	var state: Dictionary = _school_state_by_faction[faction_id]
	var remaining_policies: Array = []
	for policy_state_v in state.get("active_policies", []):
		var policy_state: Dictionary = (policy_state_v as Dictionary).duplicate(true)
		var turns_remaining: int = int(policy_state.get("turns_remaining", 0))
		if turns_remaining > 0:
			policy_state["turns_remaining"] = turns_remaining - 1
		if int(policy_state.get("turns_remaining", 0)) == 0 and turns_remaining > 0:
			SignalBus.school_policy_expired.emit(get_current_school(faction_id), str(policy_state.get("policy_id", "")))
			continue
		remaining_policies.append(policy_state)
	state["active_policies"] = remaining_policies
	var transition_turns: int = int(state.get("transition_turns", 0))
	if transition_turns > 0:
		state["transition_turns"] = transition_turns - 1


func _has_active_policy(state: Dictionary, policy_id: String) -> bool:
	for policy_state_v in state.get("active_policies", []):
		var policy_state: Dictionary = policy_state_v as Dictionary
		if str(policy_state.get("policy_id", "")) == policy_id:
			return true
	return false


func _count_slot_occupying_policies(faction_id: String, state: Dictionary) -> int:
	var count: int = 0
	for policy_state_v in state.get("active_policies", []):
		var policy_state: Dictionary = policy_state_v as Dictionary
		var policy: Dictionary = get_policy_definition(faction_id, str(policy_state.get("policy_id", "")))
		if not policy.is_empty() and _policy_uses_slot(policy):
			count += 1
	return count


func _policy_uses_slot(policy: Dictionary) -> bool:
	var duration_turns: int = int(policy.get("duration_turns", 0))
	if duration_turns > 0:
		return true
	var effects: Dictionary = policy.get("effects", {})
	for key in _POLICY_SLOT_EFFECT_KEYS:
		if effects.has(key):
			return true
	return false


func _try_level_up(faction_id: String) -> void:
	if not _school_state_by_faction.has(faction_id):
		return
	var state: Dictionary = _school_state_by_faction[faction_id]
	var old_level: int = int(state.get("level", 0))
	var target_level: int = old_level
	var exp: int = int(state.get("exp", 0))
	if old_level < 2 and exp >= int(DataManager.get_balance_param("school.exp_to_level_2")):
		target_level = 2
	if target_level < 3 and exp >= int(DataManager.get_balance_param("school.exp_to_level_3")):
		target_level = 3
	if target_level != old_level:
		state["level"] = target_level
		SignalBus.school_level_changed.emit(get_current_school(faction_id), old_level, target_level)


func _merge_effects(target: Dictionary, source: Dictionary, multiplier: float) -> void:
	for key in source:
		var value: Variant = source.get(key)
		if value is Dictionary:
			continue
		if value is bool:
			target[key] = bool(target.get(key, false)) or bool(value)
		elif value is int or value is float:
			target[key] = float(target.get(key, 0.0)) + float(value) * multiplier
		else:
			target[key] = value


func _add_or_replace_policy(state: Dictionary, policy_id: String, duration_turns: int) -> void:
	var policies: Array = state.get("active_policies", [])
	for i in range(policies.size()):
		var policy_state: Dictionary = policies[i] as Dictionary
		if str(policy_state.get("policy_id", "")) == policy_id:
			policies[i] = {"policy_id": policy_id, "turns_remaining": duration_turns}
			return
	policies.append({"policy_id": policy_id, "turns_remaining": duration_turns})
