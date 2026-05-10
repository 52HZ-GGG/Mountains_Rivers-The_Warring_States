extends Node

## 科技研究系统
##
## 管理科技研究状态、前置判定、特殊条件判定、效果应用。
## 阶段2增补：54个科技的完整研究流程。

# ============= 状态存储 =============

var _researched_techs: Dictionary = {}   # {tech_id: true}
var _available_techs: Dictionary = {}    # {tech_id: true}
var _researching_tech: String = ""
var _research_progress: int = 0          # 已研究回合数
var _research_cost_turns: int = 1        # 当前科技需要的回合数

# 效果修正器（其他系统查询用）
var _attack_modifiers: Dictionary = {}       # {target: float}
var _defense_modifiers: Dictionary = {}      # {target: float}
var _resource_modifiers: Dictionary = {}     # {resource: float}
var _unlocked_units: Array = []
var _terrain_traversal: Dictionary = {}      # {terrain: bool}
var _city_defense_bonus: float = 0.0
var _siege_bonus: float = 0.0
var _movement_bonus: int = 0
var _vision_bonus: int = 0
var _morale_bonus: int = 0
var _security_bonus: float = 0.0
var _culture_bonus: float = 0.0
var _healing_bonus: float = 0.0
var _event_chance_bonus: float = 0.0
var _research_speed_modifier: float = 0.0
var _trade_bonus: float = 0.0
var _garrison_bonus: float = 0.0
var _wall_durability_bonus: float = 0.0
var _border_defense_bonus: Dictionary = {}   # {region: float}
var _diplomacy_bonus: float = 0.0
var _recruit_cost_reduction: Dictionary = {} # {target: float}
var _disaster_resist_bonus: float = 0.0

# ============= 生命周期 =============

func _ready() -> void:
	print("[TechSystem] 启动")
	SignalBus.turn_started.connect(_on_turn_started)


func _on_turn_started(_turn_number: int, faction_id: String) -> void:
	if GameManager.is_player_faction(faction_id):
		_update_available_techs()
		_progress_research()


# ============= 公共查询 =============

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


func can_research(tech_id: String) -> Dictionary:
	var result := {"can_research": true, "missing_prereqs": [], "missing_conditions": []}
	var tech: Dictionary = DataManager.get_tech(tech_id)
	if tech.is_empty():
		result.can_research = false
		return result
	if is_researched(tech_id):
		result.can_research = false
		return result
	# 检查前置
	for prereq in tech.get("prerequisites", []):
		if not is_researched(prereq):
			result.missing_prereqs.append(prereq)
			result.can_research = false
	# 检查特殊条件
	if not _check_special_conditions(tech_id):
		result.missing_conditions = tech.get("special_conditions", [])
		result.can_research = false
	return result


# ============= 研究操作 =============

func start_research(tech_id: String) -> Dictionary:
	if _researching_tech != "":
		return {"success": false, "reason": "已有科技正在研究: %s" % _researching_tech}
	var check := can_research(tech_id)
	if not check.can_research:
		return {"success": false, "reason": "前置条件不满足"}
	var tech: Dictionary = DataManager.get_tech(tech_id)
	var cost_turns: int = DataManager.get_balance_param("tech.research_speed_per_turn")
	if cost_turns == null:
		cost_turns = 1
	# 研究回合数 = 金币成本 / 100（向上取整，最少1回合）
	var base_turns: int = maxi(1, ceili(float(tech.get("cost_gold", 100)) / 100.0))
	# 应用研究速度修正
	var speed_mod: float = 1.0 + _research_speed_modifier
	_research_cost_turns = maxi(1, ceili(float(base_turns) / speed_mod))
	_researching_tech = tech_id
	_research_progress = 0
	SignalBus.tech_research_started.emit(tech_id)
	return {"success": true}


func cancel_research() -> void:
	var old_tech := _researching_tech
	_researching_tech = ""
	_research_progress = 0
	if old_tech != "":
		SignalBus.tech_research_cancelled.emit(old_tech)


func _progress_research() -> void:
	if _researching_tech == "":
		return
	_research_progress += 1
	if _research_progress >= _research_cost_turns:
		_complete_research()


func _complete_research() -> void:
	var tech_id := _researching_tech
	_researched_techs[tech_id] = true
	_apply_tech_effects(tech_id)
	_researching_tech = ""
	_research_progress = 0
	_update_available_techs()
	SignalBus.tech_research_completed.emit(tech_id)
	print("[TechSystem] 科技研究完成: %s" % tech_id)


# ============= AI研究 =============

func start_ai_research(faction_id: String, tech_id: String) -> void:
	# AI直接完成研究（简化处理）
	# 后续可改为异步研究
	if not _can_ai_research(faction_id, tech_id):
		return
	_ai_researched_techs[faction_id] = _ai_researched_techs.get(faction_id, {})
	_ai_researched_techs[faction_id][tech_id] = true
	print("[TechSystem] AI %s 研究完成: %s" % [faction_id, tech_id])


var _ai_researched_techs: Dictionary = {}  # {faction_id: {tech_id: true}}


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


func get_ai_researched_techs(faction_id: String) -> Dictionary:
	return _ai_researched_techs.get(faction_id, {})


# ============= 内部逻辑 =============

func _update_available_techs() -> void:
	_available_techs.clear()
	for tech in DataManager.get_all_techs():
		var tech_id: String = tech["id"]
		if is_researched(tech_id):
			continue
		if tech_id == _researching_tech:
			continue
		var check := can_research(tech_id)
		if check.can_research:
			_available_techs[tech_id] = true
			SignalBus.tech_available.emit(tech_id)


func _check_special_conditions(tech_id: String) -> bool:
	var tech: Dictionary = DataManager.get_tech(tech_id)
	for condition in tech.get("special_conditions", []):
		var cond_type: String = condition.get("type", "")
		match cond_type:
			"city_control":
				var city_id: String = condition.get("city_id", "")
				# 检查玩家是否控制该城市（需要CityManager）
				if not _is_city_controlled(city_id):
					return false
			"reputation":
				var req_val: int = condition.get("value", 0)
				if DiplomacySystem.get_reputation(GameManager._player_faction) < req_val:
					return false
			"building":
				var building_id: String = condition.get("building_id", "")
				if not _has_building(building_id):
					return false
			"region_control":
				var region: String = condition.get("region", "")
				var min_cities: int = condition.get("min_cities", 1)
				if not _control_region(region, min_cities):
					return false
			"fame":
				# 预留：历史名人系统
				pass
	return true


func _is_city_controlled(city_id: String) -> bool:
	# 暂时简化：检查城市是否在玩家城市列表中
	# 后续对接CityManager
	var player_cities: Array = DataManager.get_faction_cities(GameManager._player_faction)
	for c in player_cities:
		if c["id"] == city_id:
			return true
	return false


func _has_building(building_id: String) -> bool:
	# 暂时简化：预留接口，后续对接BuildingManager
	push_warning("TechSystem: _has_building 尚未对接BuildingManager (%s)" % building_id)
	return false


func _control_region(_region: String, _min_cities: int) -> bool:
	# 暂时简化：预留接口，后续对接CityManager
	push_warning("TechSystem: _control_region 尚未对接CityManager")
	return false


func _apply_tech_effects(tech_id: String) -> void:
	var tech: Dictionary = DataManager.get_tech(tech_id)
	var effect: Dictionary = tech["effects"]
	var effect_type: String = effect.get("type", "")

	match effect_type:
		"attack_bonus":
			var target: String = effect.get("target", "all")
			_attack_modifiers[target] = _attack_modifiers.get(target, 0.0) + effect.get("value", 0.0)
		"defense_bonus":
			var target: String = effect.get("target", "all")
			_defense_modifiers[target] = _defense_modifiers.get(target, 0.0) + effect.get("value", 0.0)
		"unlock_unit":
			var unit_id: String = effect.get("unit_id", "")
			if unit_id != "" and not _unlocked_units.has(unit_id):
				_unlocked_units.append(unit_id)
		"resource_bonus":
			var resource: String = effect.get("resource", "")
			_resource_modifiers[resource] = _resource_modifiers.get(resource, 0.0) + effect.get("value", 0.0)
		"resource_bonus_malus":
			var bonus_res: String = effect.get("bonus_resource", "")
			var malus_res: String = effect.get("malus_resource", "")
			_resource_modifiers[bonus_res] = _resource_modifiers.get(bonus_res, 0.0) + effect.get("bonus_value", 0.0)
			_resource_modifiers[malus_res] = _resource_modifiers.get(malus_res, 0.0) + effect.get("malus_value", 0.0)
		"resource_bonus_multi":
			var resources: Dictionary = effect.get("resources", {})
			for res in resources:
				_resource_modifiers[res] = _resource_modifiers.get(res, 0.0) + resources[res]
		"city_defense_bonus":
			_city_defense_bonus += effect.get("value", 0.0)
		"siege_bonus":
			_siege_bonus += effect.get("value", 0.0)
		"terrain_traversal":
			var terrain: String = effect.get("terrain", "")
			_terrain_traversal[terrain] = effect.get("value", false)
		"movement_bonus":
			_movement_bonus += effect.get("value", 0)
		"vision_bonus":
			_vision_bonus += effect.get("value", 0)
		"morale_bonus":
			_morale_bonus += effect.get("value", 0)
		"morale_opinion_bonus":
			_morale_bonus += effect.get("morale_value", 0)
		"security_bonus":
			_security_bonus += effect.get("value", 0.0)
		"security_morale_bonus":
			_security_bonus += effect.get("security_value", 0.0)
			_morale_bonus += effect.get("morale_value", 0)
		"culture_bonus":
			_culture_bonus += effect.get("value", 0.0)
		"healing_bonus":
			_healing_bonus += effect.get("value", 0.0)
		"event_chance_bonus":
			_event_chance_bonus += effect.get("value", 0.0)
		"research_speed_bonus":
			_research_speed_modifier += effect.get("value", 0.0)
		"trade_bonus":
			_trade_bonus += effect.get("value", 0.0)
		"garrison_bonus":
			_garrison_bonus += effect.get("value", 0.0)
		"wall_durability_bonus":
			_wall_durability_bonus += effect.get("value", 0.0)
		"border_defense_bonus":
			var region: String = effect.get("region", "")
			_border_defense_bonus[region] = _border_defense_bonus.get(region, 0.0) + effect.get("value", 0.0)
		"morale_reputation_bonus":
			_morale_bonus += effect.get("morale_value", 0)
		"morale_culture_bonus":
			_morale_bonus += effect.get("morale_value", 0)
			_culture_bonus += effect.get("culture_value", 0.0)
		"diplomacy_bonus":
			_diplomacy_bonus += effect.get("value", 0.0)
		"recruit_cost_reduction":
			var target: String = effect.get("target", "")
			_recruit_cost_reduction[target] = _recruit_cost_reduction.get(target, 0.0) + effect.get("value", 0.0)
		"disaster_resist":
			_disaster_resist_bonus += effect.get("value", 0.0)

	# 处理附加效果字段（如水利工程的 disaster_resist 作为次要效果）
	if effect.has("disaster_resist") and effect_type != "disaster_resist":
		_disaster_resist_bonus += effect.get("disaster_resist", 0.0)


# ============= 效果查询接口（供其他系统调用） =============

func get_attack_modifier(target: String) -> float:
	return _attack_modifiers.get(target, 0.0) + _attack_modifiers.get("all", 0.0)


func get_defense_modifier(target: String) -> float:
	return _defense_modifiers.get(target, 0.0) + _defense_modifiers.get("all", 0.0)


func get_resource_modifier(resource: String) -> float:
	return _resource_modifiers.get(resource, 0.0)


func is_unit_unlocked(unit_id: String) -> bool:
	return _unlocked_units.has(unit_id)


func can_traverse_terrain(terrain: String) -> bool:
	return _terrain_traversal.get(terrain, false)


func get_city_defense_bonus() -> float:
	return _city_defense_bonus


func get_siege_bonus() -> float:
	return _siege_bonus


func get_movement_bonus() -> int:
	return _movement_bonus


func get_vision_bonus() -> int:
	return _vision_bonus


func get_morale_bonus() -> int:
	return _morale_bonus


func get_security_bonus() -> float:
	return _security_bonus


func get_culture_bonus() -> float:
	return _culture_bonus


func get_healing_bonus() -> float:
	return _healing_bonus


func get_event_chance_bonus() -> float:
	return _event_chance_bonus


func get_trade_bonus() -> float:
	return _trade_bonus


func get_garrison_bonus() -> float:
	return _garrison_bonus


func get_wall_durability_bonus() -> float:
	return _wall_durability_bonus


func get_border_defense_bonus(region: String) -> float:
	return _border_defense_bonus.get(region, 0.0)


func get_diplomacy_bonus() -> float:
	return _diplomacy_bonus


func get_recruit_cost_reduction(target: String) -> float:
	return _recruit_cost_reduction.get(target, 0.0)


func get_disaster_resist_bonus() -> float:
	return _disaster_resist_bonus


# ============= 重置 =============

func reset() -> void:
	_researched_techs.clear()
	_available_techs.clear()
	_researching_tech = ""
	_research_progress = 0
	_research_cost_turns = 1
	_attack_modifiers.clear()
	_defense_modifiers.clear()
	_resource_modifiers.clear()
	_unlocked_units.clear()
	_terrain_traversal.clear()
	_city_defense_bonus = 0.0
	_siege_bonus = 0.0
	_movement_bonus = 0
	_vision_bonus = 0
	_morale_bonus = 0
	_security_bonus = 0.0
	_culture_bonus = 0.0
	_healing_bonus = 0.0
	_event_chance_bonus = 0.0
	_research_speed_modifier = 0.0
	_trade_bonus = 0.0
	_garrison_bonus = 0.0
	_wall_durability_bonus = 0.0
	_border_defense_bonus.clear()
	_diplomacy_bonus = 0.0
	_recruit_cost_reduction.clear()
	_disaster_resist_bonus = 0.0
	_ai_researched_techs.clear()
