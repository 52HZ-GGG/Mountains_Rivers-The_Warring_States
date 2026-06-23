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
var _action_speed_bonus: float = 0.0

# 新增效果类型（阶段7补全）
var _corruption_reduction: float = 0.0     # 腐败减少百分比
var _zoc_range_bonus: int = 0              # ZOC范围加成
var _zoc_cost_immunity: bool = false       # 免疫ZOC移动力消耗
var _trade_route_capacity_bonus: int = 0   # 商路上限加成
var _trade_route_exchange_bonus: float = 0.0  # 商路资源交换比例加成
var _opinion_bonus: int = 0                # 外交好感加成
var _reputation_bonus: int = 0             # 外交声望加成

# 负面效果状态（阶段7补全 malus_effects）
var _stability_penalty: float = 0.0        # 安定度惩罚（绝对值）
var _corruption_increase: float = 0.0      # 腐败增加（绝对值）
var _population_growth_modifier: float = 0.0  # 人口增长修正
var _upkeep_increase: float = 0.0          # 维护费增加

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
	var result := {"can_research": true, "missing_prereqs": [], "missing_conditions": [], "missing_resources": {}}
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
	if bool(DataManager.get_balance_param("tech.cost_resources_enabled")):
		var missing_resources: Dictionary = _get_missing_cost_resources(tech)
		if not missing_resources.is_empty():
			result.missing_resources = missing_resources
			result.can_research = false
	return result


# ============= 研究操作 =============

func start_research(tech_id: String) -> Dictionary:
	if _researching_tech != "":
		return {"success": false, "reason": "已有科技正在研究: %s" % _researching_tech}
	var check := can_research(tech_id)
	if not check.can_research:
		if not (check.missing_resources as Dictionary).is_empty():
			return {"success": false, "reason": "研究资源不足", "missing_resources": check.missing_resources}
		return {"success": false, "reason": "前置条件不满足"}
	var tech: Dictionary = DataManager.get_tech(tech_id)
	if bool(DataManager.get_balance_param("tech.cost_resources_enabled")):
		_consume_cost_resources(tech)
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
	if tech.has("requires_wonder"):
		var wonder_id: String = str(tech.get("requires_wonder", ""))
		if wonder_id != "" and not WonderManager.has_wonder(GameManager.get_player_faction(), wonder_id):
			return false
	return true


func _get_missing_cost_resources(tech: Dictionary) -> Dictionary:
	var missing: Dictionary = {}
	var cost_resources: Dictionary = tech.get("cost_resources", {})
	for resource in cost_resources:
		var required: int = int(cost_resources.get(resource, 0))
		if required <= 0:
			continue
		var available: int = GameManager.get_faction_resource(GameManager.get_player_faction(), str(resource))
		if available < required:
			missing[resource] = required - available
	return missing


func _consume_cost_resources(tech: Dictionary) -> void:
	var cost_resources: Dictionary = tech.get("cost_resources", {})
	var faction_id: String = GameManager.get_player_faction()
	for resource in cost_resources:
		var required: int = int(cost_resources.get(resource, 0))
		if required <= 0:
			continue
		GameManager.apply_faction_resource_delta(faction_id, str(resource), -required)


func _is_city_controlled(city_id: String) -> bool:
	var city: Dictionary = CityManager.get_city_state(city_id)
	if city.is_empty():
		return false
	return str(city.get("current_faction_id", "")) == GameManager.get_player_faction()


func _has_building(building_id: String) -> bool:
	for city in CityManager.get_faction_city_states(GameManager.get_player_faction()):
		for building in city.get("buildings", []):
			if str((building as Dictionary).get("building_id", "")) == building_id:
				return true
	return false


func _control_region(region: String, min_cities: int) -> bool:
	if min_cities <= 0:
		return true
	var count: int = 0
	for city in CityManager.get_faction_city_states(GameManager.get_player_faction()):
		if region == "northern_border":
			var q: int = int(city.get("hex_q", 0))
			var r: int = int(city.get("hex_r", 0))
			if q >= 55 or r <= 15:
				count += 1
		elif str(city.get("region", "")) == region:
			count += 1
	return count >= min_cities


func _apply_tech_effects(tech_id: String) -> void:
	var tech: Dictionary = DataManager.get_tech(tech_id)
	var effects = tech.get("effects", {})

	# 支持数组和字典两种格式
	var effect_list: Array = []
	if effects is Array:
		effect_list = effects
	elif effects is Dictionary:
		effect_list = [effects]

	# 应用所有正面效果
	for effect in effect_list:
		_apply_single_effect(effect)

	# 应用负面效果（malus_effects）
	for malus in tech.get("malus_effects", []):
		_apply_single_malus(malus)


func _apply_single_effect(effect: Dictionary) -> void:
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
			_opinion_bonus += int(effect.get("opinion_value", 0))
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
			_reputation_bonus += int(effect.get("reputation_value", 0))
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
		"corruption_reduction":
			_corruption_reduction += effect.get("value", 0.0)
		"zoc_range_bonus":
			_zoc_range_bonus += int(effect.get("value", 0))
		"zoc_cost_immunity":
			_zoc_cost_immunity = bool(effect.get("value", true))
		"trade_route_capacity":
			_trade_route_capacity_bonus += int(effect.get("value", 0))
		"trade_route_exchange_bonus":
			_trade_route_exchange_bonus += effect.get("value", 0.0)

	# 处理附加效果字段（如水利工程的 disaster_resist 作为次要效果）
	if effect.has("disaster_resist") and effect_type != "disaster_resist":
		_disaster_resist_bonus += effect.get("disaster_resist", 0.0)


func _apply_single_malus(malus: Dictionary) -> void:
	var malus_type: String = malus.get("type", "")

	match malus_type:
		"morale_penalty":
			_morale_bonus += int(malus.get("value", 0))
		"stability_penalty":
			_stability_penalty += float(malus.get("value", 0))
		"recruit_cost_increase":
			var increase: float = malus.get("value", 0.0)
			_recruit_cost_reduction["all"] = _recruit_cost_reduction.get("all", 0.0) - increase
		"diplomacy_penalty":
			_diplomacy_bonus += float(malus.get("value", 0))
		"corruption_increase":
			_corruption_increase += float(malus.get("value", 0))
		"resource_penalty":
			var resource: String = malus.get("resource", "")
			_resource_modifiers[resource] = _resource_modifiers.get(resource, 0.0) + malus.get("value", 0.0)
		"attack_bonus":
			_attack_modifiers["all"] = _attack_modifiers.get("all", 0.0) + malus.get("value", 0.0)
		"security_bonus":
			_security_bonus += malus.get("value", 0.0)
		"trade_bonus":
			_trade_bonus += malus.get("value", 0.0)
		"population_growth_penalty":
			_population_growth_modifier += float(malus.get("value", 0))
		"upkeep_increase":
			_upkeep_increase += float(malus.get("value", 0))


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


func get_faction_action_speed_bonus(_faction_id: String) -> float:
	return _action_speed_bonus


# ============= 阶段7新增查询接口 =============

func get_corruption_reduction() -> float:
	return _corruption_reduction


func get_corruption_increase() -> float:
	return _corruption_increase


func get_zoc_range_bonus() -> int:
	return _zoc_range_bonus


func has_zoc_cost_immunity() -> bool:
	return _zoc_cost_immunity


func get_trade_route_capacity_bonus() -> int:
	return _trade_route_capacity_bonus


func get_trade_route_exchange_bonus() -> float:
	return _trade_route_exchange_bonus


func get_opinion_bonus() -> int:
	return _opinion_bonus


func get_reputation_bonus() -> int:
	return _reputation_bonus


func get_stability_penalty() -> float:
	return _stability_penalty


func get_population_growth_modifier() -> float:
	return _population_growth_modifier


func get_upkeep_increase() -> float:
	return _upkeep_increase


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
	_action_speed_bonus = 0.0
	# 阶段7新增
	_corruption_reduction = 0.0
	_zoc_range_bonus = 0
	_zoc_cost_immunity = false
	_trade_route_capacity_bonus = 0
	_trade_route_exchange_bonus = 0.0
	_opinion_bonus = 0
	_reputation_bonus = 0
	_stability_penalty = 0.0
	_corruption_increase = 0.0
	_population_growth_modifier = 0.0
	_upkeep_increase = 0.0
	_ai_researched_techs.clear()
