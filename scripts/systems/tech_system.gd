extends Node

## 科技研究状态机（TechSystem）
##
## 只负责：研究进度、前置/互斥/资源门、AI 研究登记、协同激活标记、存档。
## 效果数值一律写入 TechEffects（门面）；解锁条件一律走 TechUnlockContext。
## 本节点不查询 CityManager 的城防/人口，也不被城防/经营公式直接调用。

const TechUnlockBindings := preload("res://scripts/systems/tech_unlock_bindings.gd")

# ============= 研究状态 =============

var _researched_techs: Dictionary = {}   # {tech_id: true}
var _available_techs: Dictionary = {}    # {tech_id: true}
var _researching_tech: String = ""
var _research_progress: int = 0
var _research_cost_turns: int = 1
var _ai_researched_techs: Dictionary = {}  # {faction_id: {tech_id: true}}
var _active_synergies: Dictionary = {}
var _unlocked_knowledge_cards: Dictionary = {}
var _pending_research_event: Dictionary = {}
var _research_event_cooldown: int = 0
var _mastery_levels: Dictionary = {}  # {tech_id: int} 研究后的精通等级（0=仅基础效果）


func _ready() -> void:
	print("[TechSystem] 启动")
	SignalBus.turn_started.connect(_on_turn_started)
	# 组合根：注册解锁条件校验器（唯一允许绑定业务系统的位置）
	TechUnlockBindings.bind_all()


func _on_turn_started(_turn_number: int, faction_id: String) -> void:
	if GameManager.is_player_faction(faction_id):
		_update_available_techs()
		_progress_research()


# ============= 研究状态查询 =============

func is_researched(tech_id: String) -> bool:
	return _researched_techs.has(tech_id)


func is_available(tech_id: String) -> bool:
	return _available_techs.has(tech_id)


func get_researching_tech() -> String:
	return _researching_tech


func get_research_progress() -> int:
	return _research_progress


func get_research_cost_turns() -> int:
	return _research_cost_turns


func get_available_techs() -> Array:
	var result: Array = []
	for tech_id in _available_techs:
		result.append(DataManager.get_tech(tech_id))
	return result


func get_researched_techs() -> Array:
	var result: Array = []
	for tech_id in _researched_techs:
		result.append(DataManager.get_tech(tech_id))
	return result


func get_ai_researched_techs(faction_id: String) -> Dictionary:
	return _ai_researched_techs.get(faction_id, {})


func get_active_synergies() -> Array:
	var result: Array = []
	for synergy in DataManager.get_tech_synergies():
		if _active_synergies.has(str(synergy.get("id", ""))):
			result.append(synergy)
	return result


func is_knowledge_card_unlocked(tech_id: String) -> bool:
	return _unlocked_knowledge_cards.has(tech_id) or is_researched(tech_id)


func get_pending_research_event() -> Dictionary:
	return _pending_research_event


func get_mastery_level(tech_id: String) -> int:
	return int(_mastery_levels.get(tech_id, 0))


func get_mastery_config(tech_id: String) -> Dictionary:
	return DataManager.get_tech(tech_id).get("mastery", {})


func can_upgrade_mastery(tech_id: String) -> Dictionary:
	var result := {"can_upgrade": false, "reason": "", "cost": {}, "next_increment": 0.0}
	if not bool(DataManager.get_balance_param("tech.mastery_enabled")):
		result.reason = "精通系统未启用"
		return result
	if not is_researched(tech_id):
		result.reason = "科技未研究"
		return result
	var mastery: Dictionary = get_mastery_config(tech_id)
	if mastery.is_empty():
		result.reason = "该科技无精通"
		return result
	var level: int = get_mastery_level(tech_id)
	var max_level: int = int(mastery.get("max_level", 0))
	if level >= max_level:
		result.reason = "已达精通上限"
		return result
	# 全局精通等级上限
	var global_max: int = int(DataManager.get_balance_param("tech.mastery_max_global_level_sum"))
	var total: int = 0
	for tid in _mastery_levels:
		total += int(_mastery_levels[tid])
	if global_max > 0 and total >= global_max:
		result.reason = "全局精通等级已达上限"
		return result
	var costs: Array = mastery.get("upgrade_cost", [])
	if level >= costs.size():
		result.reason = "精通成本配置缺失"
		return result
	var cost: Dictionary = costs[level]
	result.cost = cost
	var increments: Array = mastery.get("increment_per_level", [])
	result.next_increment = float(increments[level]) if level < increments.size() else 0.0
	var fid: String = _player_faction()
	for res in cost:
		if GameManager.get_faction_resource(fid, str(res)) < int(cost[res]):
			result.reason = "资源不足"
			return result
	result.can_upgrade = true
	return result


func upgrade_mastery(tech_id: String) -> Dictionary:
	var check := can_upgrade_mastery(tech_id)
	if not check.can_upgrade:
		return {"success": false, "reason": str(check.get("reason", "不可升级精通"))}
	var mastery: Dictionary = get_mastery_config(tech_id)
	var level: int = get_mastery_level(tech_id)
	var costs: Array = mastery.get("upgrade_cost", [])
	var cost: Dictionary = costs[level]
	var fid: String = _player_faction()
	for res in cost:
		GameManager.apply_faction_resource_delta(fid, str(res), -int(cost[res]))
	var increments: Array = mastery.get("increment_per_level", [])
	var inc: float = float(increments[level]) if level < increments.size() else 0.0
	var effect_type: String = str(mastery.get("effect_type", "attack_bonus"))
	var effect_target: String = str(mastery.get("effect_target", "all"))
	TechEffects.accumulate_effect(fid, {
		"type": effect_type,
		"target": effect_target,
		"resource": effect_target if effect_type == "resource_bonus" else "",
		"value": inc,
	})
	_mastery_levels[tech_id] = level + 1
	TechEffects.effects_changed.emit(fid)
	return {"success": true, "level": level + 1, "increment": inc}


func _replay_mastery_increments(faction_id: String, tech_id: String, levels: int) -> void:
	if levels <= 0:
		return
	var mastery: Dictionary = get_mastery_config(tech_id)
	if mastery.is_empty():
		return
	var increments: Array = mastery.get("increment_per_level", [])
	var effect_type: String = str(mastery.get("effect_type", "attack_bonus"))
	var effect_target: String = str(mastery.get("effect_target", "all"))
	for i in mini(levels, increments.size()):
		TechEffects.accumulate_effect(faction_id, {
			"type": effect_type,
			"target": effect_target,
			"resource": effect_target if effect_type == "resource_bonus" else "",
			"value": float(increments[i]),
		})


func _player_faction() -> String:
	return GameManager.get_player_faction()


func can_research(tech_id: String) -> Dictionary:
	var result := {
		"can_research": true,
		"missing_prereqs": [],
		"missing_conditions": [],
		"missing_resources": {},
		"locked_by_mutual_exclusion": "",
		"locked_by_mutual_group": "",
	}
	var tech: Dictionary = DataManager.get_tech(tech_id)
	if tech.is_empty() or is_researched(tech_id):
		result.can_research = false
		return result
	for prereq in tech.get("prerequisites", []):
		if not is_researched(prereq):
			result.missing_prereqs.append(prereq)
			result.can_research = false
	if _is_mutually_excluded(tech_id):
		result.can_research = false
		result.locked_by_mutual_group = DataManager.get_tech_mutual_exclusion_group(tech_id)
		for peer in DataManager.get_tech_mutual_exclusion_members(str(result.locked_by_mutual_group)):
			if peer != tech_id and is_researched(peer):
				result.locked_by_mutual_exclusion = peer
				break
	var fid: String = _player_faction()
	if not TechUnlockContext.check_tech(fid, tech):
		result.missing_conditions = TechUnlockContext.missing_conditions(fid, tech)
		result.can_research = false
	if bool(DataManager.get_balance_param("tech.cost_resources_enabled")):
		var missing_resources: Dictionary = _get_missing_cost_resources(tech)
		if not missing_resources.is_empty():
			result.missing_resources = missing_resources
			result.can_research = false
	return result


func start_research(tech_id: String) -> Dictionary:
	if _researching_tech != "":
		return {"success": false, "reason": "已有科技正在研究: %s" % _researching_tech}
	var check := can_research(tech_id)
	if not check.can_research:
		var excluded_peer: String = str(check.get("locked_by_mutual_exclusion", ""))
		if excluded_peer != "":
			var peer_name: String = str(DataManager.get_tech(excluded_peer).get("name", excluded_peer))
			return {"success": false, "reason": "与已研究的「%s」互斥" % peer_name, "locked_by_mutual_exclusion": excluded_peer}
		if not (check.missing_resources as Dictionary).is_empty():
			return {"success": false, "reason": "研究资源不足", "missing_resources": check.missing_resources}
		return {"success": false, "reason": "前置条件不满足"}
	var tech: Dictionary = DataManager.get_tech(tech_id)
	if bool(DataManager.get_balance_param("tech.cost_resources_enabled")):
		_consume_cost_resources(tech)
	var base_turns: int = maxi(1, ceili(float(tech.get("cost_gold", 100)) / 100.0))
	var speed_mod: float = 1.0 + TechEffects.research_speed_modifier(_player_faction())
	if speed_mod < 0.1:
		speed_mod = 0.1
	_research_cost_turns = maxi(1, ceili(float(base_turns) / speed_mod))
	_researching_tech = tech_id
	_research_progress = 0
	_try_trigger_research_event(tech)
	SignalBus.tech_research_started.emit(tech_id)
	return {"success": true}


func cancel_research() -> void:
	var old_tech := _researching_tech
	if old_tech == "":
		return
	# 退还已扣资源（互斥/条件在开始时已校验，取消不产生科技效果）
	_refund_cost_resources(DataManager.get_tech(old_tech))
	_researching_tech = ""
	_research_progress = 0
	_pending_research_event = {}
	_update_available_techs()
	SignalBus.tech_research_cancelled.emit(old_tech)


func _refund_cost_resources(tech: Dictionary) -> void:
	if tech.is_empty():
		return
	var fid: String = _player_faction()
	var cost_resources: Dictionary = tech.get("cost_resources", {})
	if not cost_resources.is_empty():
		for resource in cost_resources:
			var required: int = int(cost_resources.get(resource, 0))
			if required > 0:
				GameManager.apply_faction_resource_delta(fid, str(resource), required)
		return
	if bool(DataManager.get_balance_param("tech.cost_gold_fallback")):
		var required_gold: int = int(tech.get("cost_gold", 0))
		if required_gold > 0:
			GameManager.apply_faction_resource_delta(fid, "gold", required_gold)


func resolve_research_event(option_id: String) -> Dictionary:
	if _pending_research_event.is_empty() or _researching_tech == "":
		return {"success": false, "reason": "无待处理研究事件"}
	for opt in _pending_research_event.get("options", []):
		if str(opt.get("id", "")) != option_id:
			continue
		var cost: Dictionary = opt.get("cost", {})
		var fid: String = _player_faction()
		for res in cost:
			if GameManager.get_faction_resource(fid, str(res)) < int(cost[res]):
				return {"success": false, "reason": "资源不足，无法选择该选项"}
		for res in cost:
			GameManager.apply_faction_resource_delta(fid, str(res), -int(cost[res]))
		var outcomes: Dictionary = opt.get("outcomes", {})
		var gold_delta: int = int(outcomes.get("gold_delta", 0))
		if gold_delta != 0:
			GameManager.apply_faction_resource_delta(fid, "gold", gold_delta)
		var progress_bonus: float = float(outcomes.get("tech_progress_bonus", 0.0))
		var progress_penalty: float = float(outcomes.get("tech_progress_penalty", 0.0))
		if progress_bonus != 0.0:
			_research_progress = maxi(0, _research_progress + int(round(progress_bonus * float(_research_cost_turns))))
		if progress_penalty != 0.0:
			_research_progress = maxi(0, _research_progress + int(round(progress_penalty * float(_research_cost_turns))))
		var morale_delta: int = int(outcomes.get("morale_delta", 0))
		if morale_delta != 0:
			GameManager.apply_morale_delta(morale_delta)
		_pending_research_event = {}
		if _research_progress >= _research_cost_turns:
			_complete_research()
		return {"success": true}
	return {"success": false, "reason": "无效选项"}


# ============= AI 研究（只登记 + 写入 TechEffects） =============

func start_ai_research(faction_id: String, tech_id: String) -> void:
	if not _can_ai_research(faction_id, tech_id):
		return
	if not _ai_researched_techs.has(faction_id):
		_ai_researched_techs[faction_id] = {}
	var tech: Dictionary = DataManager.get_tech(tech_id)
	var group_id: String = DataManager.get_tech_mutual_exclusion_group(tech_id)
	if group_id != "":
		for peer in DataManager.get_tech_mutual_exclusion_members(group_id):
			if peer != tech_id and (_ai_researched_techs[faction_id] as Dictionary).has(peer):
				return
	# AI 也走解锁门面（城控/声望等），避免纸面科技绕过条件
	if not TechUnlockContext.check_tech(faction_id, tech):
		return
	_ai_researched_techs[faction_id][tech_id] = true
	TechEffects.apply_tech(faction_id, tech)
	print("[TechSystem] AI %s 研究完成: %s" % [faction_id, tech_id])


func _can_ai_research(faction_id: String, tech_id: String) -> bool:
	var tech: Dictionary = DataManager.get_tech(tech_id)
	if tech.is_empty():
		return false
	var ai_techs: Dictionary = _ai_researched_techs.get(faction_id, {})
	if ai_techs.has(tech_id):
		return false
	for prereq in tech.get("prerequisites", []):
		if not ai_techs.has(prereq):
			return false
	return true


# ============= 内部研究流程 =============

func _progress_research() -> void:
	if _researching_tech == "":
		return
	_research_progress += 1
	if _research_event_cooldown > 0:
		_research_event_cooldown -= 1
	if _research_progress >= _research_cost_turns:
		_complete_research()


func _complete_research() -> void:
	var tech_id := _researching_tech
	var tech: Dictionary = DataManager.get_tech(tech_id)
	_researched_techs[tech_id] = true
	TechEffects.apply_tech(_player_faction(), tech)
	if bool(DataManager.get_balance_param("tech.knowledge_card_unlock_on_research")):
		if not DataManager.get_tech_knowledge_card(tech_id).is_empty():
			_unlocked_knowledge_cards[tech_id] = true
	_researching_tech = ""
	_research_progress = 0
	_pending_research_event = {}
	_apply_all_synergies()
	_update_available_techs()
	SignalBus.tech_research_completed.emit(tech_id)
	print("[TechSystem] 科技研究完成: %s" % tech_id)


func _update_available_techs() -> void:
	var was_available: Dictionary = _available_techs.duplicate()
	_available_techs.clear()
	for tech in DataManager.get_all_techs():
		var tech_id: String = tech["id"]
		if is_researched(tech_id) or tech_id == _researching_tech:
			continue
		if can_research(tech_id).can_research:
			_available_techs[tech_id] = true
			if not was_available.has(tech_id):
				SignalBus.tech_available.emit(tech_id)


func _get_missing_cost_resources(tech: Dictionary) -> Dictionary:
	var missing: Dictionary = {}
	var cost_resources: Dictionary = tech.get("cost_resources", {})
	var fid: String = _player_faction()
	for resource in cost_resources:
		var required: int = int(cost_resources.get(resource, 0))
		if required <= 0:
			continue
		if GameManager.get_faction_resource(fid, str(resource)) < required:
			missing[resource] = required - GameManager.get_faction_resource(fid, str(resource))
	if cost_resources.is_empty() and bool(DataManager.get_balance_param("tech.cost_gold_fallback")):
		var required_gold: int = int(tech.get("cost_gold", 0))
		if required_gold > 0 and GameManager.get_faction_resource(fid, "gold") < required_gold:
			missing["gold"] = required_gold - GameManager.get_faction_resource(fid, "gold")
	return missing


func _consume_cost_resources(tech: Dictionary) -> void:
	var fid: String = _player_faction()
	var cost_resources: Dictionary = tech.get("cost_resources", {})
	if not cost_resources.is_empty():
		for resource in cost_resources:
			var required: int = int(cost_resources.get(resource, 0))
			if required > 0:
				GameManager.apply_faction_resource_delta(fid, str(resource), -required)
		return
	if bool(DataManager.get_balance_param("tech.cost_gold_fallback")):
		var required_gold: int = int(tech.get("cost_gold", 0))
		if required_gold > 0:
			GameManager.apply_faction_resource_delta(fid, "gold", -required_gold)


func _is_mutually_excluded(tech_id: String) -> bool:
	if not bool(DataManager.get_balance_param("tech.mutual_exclusion_hard_lock")):
		return false
	var group_id: String = DataManager.get_tech_mutual_exclusion_group(tech_id)
	if group_id == "":
		return false
	for peer in DataManager.get_tech_mutual_exclusion_members(group_id):
		if peer != tech_id and is_researched(peer):
			return true
	return false


func _try_trigger_research_event(tech: Dictionary) -> void:
	_pending_research_event = {}
	if _research_event_cooldown > 0:
		return
	var event_ids: Array = tech.get("research_events", [])
	if event_ids.is_empty():
		return
	var base_chance: float = float(DataManager.get_balance_param("tech.research_event_base_chance"))
	base_chance += TechEffects.event_chance_bonus(_player_faction())
	if randf() > clampf(base_chance, 0.0, 0.95):
		return
	var picked: String = str(event_ids[randi() % event_ids.size()])
	var event_data: Dictionary = DataManager.get_tech_research_event(picked)
	if event_data.is_empty():
		return
	_pending_research_event = event_data
	_research_event_cooldown = int(DataManager.get_balance_param("tech.research_event_cooldown_turns"))
	SignalBus.tech_research_event.emit(picked, str(tech.get("id", "")))


func _apply_all_synergies() -> void:
	var fid: String = _player_faction()
	for synergy in DataManager.get_tech_synergies():
		var sid: String = str(synergy.get("id", ""))
		if sid == "" or _active_synergies.has(sid):
			continue
		var all_ready: bool = true
		for req in synergy.get("required_techs", []):
			if not is_researched(str(req)):
				all_ready = false
				break
		if not all_ready:
			continue
		_active_synergies[sid] = true
		for effect in synergy.get("effects", []):
			TechEffects.accumulate_effect(fid, effect)
	if not _active_synergies.is_empty():
		TechEffects.effects_changed.emit(fid)
		_update_available_techs()


# ============= 存档 =============

func reset() -> void:
	_researched_techs.clear()
	_available_techs.clear()
	_researching_tech = ""
	_research_progress = 0
	_research_cost_turns = 1
	_ai_researched_techs.clear()
	_active_synergies.clear()
	_unlocked_knowledge_cards.clear()
	_pending_research_event = {}
	_research_event_cooldown = 0
	_mastery_levels.clear()
	TechEffects.clear_tech_buckets()


func get_save_data() -> Dictionary:
	return {
		"researched_techs": _researched_techs.duplicate(true),
		"researching_tech": _researching_tech,
		"research_progress": _research_progress,
		"research_cost_turns": _research_cost_turns,
		"ai_researched_techs": _ai_researched_techs.duplicate(true),
		"active_synergies": _active_synergies.duplicate(true),
		"unlocked_knowledge_cards": _unlocked_knowledge_cards.duplicate(true),
		"mastery_levels": _mastery_levels.duplicate(true),
	}


func load_save_data(data: Dictionary) -> void:
	reset()
	var researched: Variant = data.get("researched_techs", {})
	if researched is Dictionary:
		for tech_id in researched:
			_researched_techs[str(tech_id)] = true
	_researching_tech = str(data.get("researching_tech", ""))
	_research_progress = int(data.get("research_progress", 0))
	_research_cost_turns = int(data.get("research_cost_turns", 1))
	var ai: Variant = data.get("ai_researched_techs", {})
	if ai is Dictionary:
		_ai_researched_techs = (ai as Dictionary).duplicate(true)
	var syn: Variant = data.get("active_synergies", {})
	if syn is Dictionary:
		_active_synergies = (syn as Dictionary).duplicate(true)
	var cards: Variant = data.get("unlocked_knowledge_cards", {})
	if cards is Dictionary:
		_unlocked_knowledge_cards = (cards as Dictionary).duplicate(true)
	var mastery: Variant = data.get("mastery_levels", {})
	if mastery is Dictionary:
		_mastery_levels = (mastery as Dictionary).duplicate(true)
	var fid: String = _player_faction()
	for tech_id in _researched_techs:
		TechEffects.apply_tech(fid, DataManager.get_tech(str(tech_id)))
		if not DataManager.get_tech_knowledge_card(str(tech_id)).is_empty():
			_unlocked_knowledge_cards[str(tech_id)] = true
	# 重放精通增量
	for tech_id in _mastery_levels:
		_replay_mastery_increments(fid, str(tech_id), int(_mastery_levels[tech_id]))
	for faction_id in _ai_researched_techs:
		var faction_techs: Variant = _ai_researched_techs[faction_id]
		if not (faction_techs is Dictionary):
			continue
		for tech_id in faction_techs:
			TechEffects.apply_tech(str(faction_id), DataManager.get_tech(str(tech_id)))
	if _active_synergies.is_empty():
		_apply_all_synergies()
	else:
		for synergy in DataManager.get_tech_synergies():
			var sid: String = str(synergy.get("id", ""))
			if _active_synergies.has(sid):
				for effect in synergy.get("effects", []):
					TechEffects.accumulate_effect(fid, effect)
	_update_available_techs()
