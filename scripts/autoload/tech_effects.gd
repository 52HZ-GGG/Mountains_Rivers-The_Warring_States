extends Node

## 科技效果门面（TechEffects）
##
## 战斗/经营/城防/外交等消费端的唯一效果查询入口。
## 只维护「势力 → 效果累加器」，不依赖 CityManager / GameManager / 战斗公式。
## 由 TechSystem（研究状态机）在研究完成/重置/读档时写入；其余系统只读。

signal effects_changed(faction_id: String)

var _buckets: Dictionary = {}  # {faction_id: Dictionary}
var _runtime: Dictionary = {}  # {faction_id: {key: float}}  外部系统写入的运行时加成（学派等）


func _ready() -> void:
	pass


# ============= 运行时加成层（外部系统写入，不改科技桶） =============

## 学派/政策等外部来源写入。key 与门面查询字段对齐，如 research_speed_modifier。
func set_runtime_bonus(faction_id: String, key: String, value: float) -> void:
	if faction_id == "" or key == "":
		return
	if not _runtime.has(faction_id):
		_runtime[faction_id] = {}
	var dict: Dictionary = _runtime[faction_id]
	dict[key] = value
	effects_changed.emit(faction_id)


func clear_runtime_bonus(faction_id: String, key: String = "") -> void:
	if not _runtime.has(faction_id):
		return
	if key == "":
		_runtime.erase(faction_id)
	else:
		(_runtime[faction_id] as Dictionary).erase(key)
	effects_changed.emit(faction_id)


func runtime_bonus(faction_id: String, key: String) -> float:
	var dict: Variant = _runtime.get(faction_id, {})
	if dict is Dictionary:
		return float((dict as Dictionary).get(key, 0.0))
	return 0.0


# ============= 生命周期（供 TechSystem 写入） =============

func clear_all() -> void:
	_buckets.clear()
	_runtime.clear()
	effects_changed.emit("*")


func clear_faction(faction_id: String) -> void:
	var changed: bool = false
	if _buckets.erase(faction_id):
		changed = true
	if _runtime.erase(faction_id):
		changed = true
	if changed:
		effects_changed.emit(faction_id)


func ensure_bucket(faction_id: String) -> Dictionary:
	if not _buckets.has(faction_id):
		_buckets[faction_id] = _make_bucket()
	return _buckets[faction_id]


func apply_tech(faction_id: String, tech: Dictionary) -> void:
	if faction_id == "" or tech.is_empty():
		return
	var bucket: Dictionary = ensure_bucket(faction_id)
	var effects = tech.get("effects", {})
	var effect_list: Array = []
	if effects is Array:
		effect_list = effects
	elif effects is Dictionary:
		effect_list = [effects]
	for effect in effect_list:
		accumulate_effect(faction_id, effect)
	for malus in tech.get("malus_effects", []):
		accumulate_malus(faction_id, malus)
	effects_changed.emit(faction_id)


func accumulate_effect(faction_id: String, effect: Dictionary) -> void:
	var bucket: Dictionary = ensure_bucket(faction_id)
	var effect_type: String = str(effect.get("type", ""))
	match effect_type:
		"attack_bonus":
			_add_float(bucket["attack_modifiers"], str(effect.get("target", "all")), float(effect.get("value", 0.0)))
		"defense_bonus":
			_add_float(bucket["defense_modifiers"], str(effect.get("target", "all")), float(effect.get("value", 0.0)))
		"unlock_unit":
			var unit_id: String = str(effect.get("unit_id", ""))
			if unit_id != "" and not (bucket["unlocked_units"] as Array).has(unit_id):
				(bucket["unlocked_units"] as Array).append(unit_id)
		"resource_bonus":
			_add_float(bucket["resource_modifiers"], str(effect.get("resource", "")), float(effect.get("value", 0.0)))
		"resource_bonus_malus":
			_add_float(bucket["resource_modifiers"], str(effect.get("bonus_resource", "")), float(effect.get("bonus_value", 0.0)))
			_add_float(bucket["resource_modifiers"], str(effect.get("malus_resource", "")), float(effect.get("malus_value", 0.0)))
		"resource_bonus_multi":
			var resources: Dictionary = effect.get("resources", {})
			for res in resources:
				_add_float(bucket["resource_modifiers"], str(res), float(resources[res]))
		"city_defense_bonus":
			bucket["city_defense_bonus"] = float(bucket["city_defense_bonus"]) + float(effect.get("value", 0.0))
		"siege_bonus":
			bucket["siege_bonus"] = float(bucket["siege_bonus"]) + float(effect.get("value", 0.0))
		"terrain_traversal":
			(bucket["terrain_traversal"] as Dictionary)[str(effect.get("terrain", ""))] = bool(effect.get("value", false))
		"movement_bonus":
			bucket["movement_bonus"] = int(bucket["movement_bonus"]) + int(effect.get("value", 0))
		"vision_bonus":
			bucket["vision_bonus"] = int(bucket["vision_bonus"]) + int(effect.get("value", 0))
		"morale_bonus":
			bucket["morale_bonus"] = int(bucket["morale_bonus"]) + int(effect.get("value", 0))
		"morale_opinion_bonus":
			bucket["morale_bonus"] = int(bucket["morale_bonus"]) + int(effect.get("morale_value", 0))
			bucket["opinion_bonus"] = int(bucket["opinion_bonus"]) + int(effect.get("opinion_value", 0))
		"security_bonus":
			bucket["security_bonus"] = float(bucket["security_bonus"]) + float(effect.get("value", 0.0))
		"security_morale_bonus":
			bucket["security_bonus"] = float(bucket["security_bonus"]) + float(effect.get("security_value", 0.0))
			bucket["morale_bonus"] = int(bucket["morale_bonus"]) + int(effect.get("morale_value", 0))
		"culture_bonus":
			bucket["culture_bonus"] = float(bucket["culture_bonus"]) + float(effect.get("value", 0.0))
		"healing_bonus":
			bucket["healing_bonus"] = float(bucket["healing_bonus"]) + float(effect.get("value", 0.0))
		"event_chance_bonus":
			bucket["event_chance_bonus"] = float(bucket["event_chance_bonus"]) + float(effect.get("value", 0.0))
		"research_speed_bonus":
			bucket["research_speed_modifier"] = float(bucket["research_speed_modifier"]) + float(effect.get("value", 0.0))
		"trade_bonus":
			bucket["trade_bonus"] = float(bucket["trade_bonus"]) + float(effect.get("value", 0.0))
		"garrison_bonus":
			bucket["garrison_bonus"] = float(bucket["garrison_bonus"]) + float(effect.get("value", 0.0))
		"wall_durability_bonus":
			bucket["wall_durability_bonus"] = float(bucket["wall_durability_bonus"]) + float(effect.get("value", 0.0))
		"border_defense_bonus":
			_add_float(bucket["border_defense_bonus"], str(effect.get("region", "")), float(effect.get("value", 0.0)))
		"morale_reputation_bonus":
			bucket["morale_bonus"] = int(bucket["morale_bonus"]) + int(effect.get("morale_value", 0))
			bucket["reputation_bonus"] = int(bucket["reputation_bonus"]) + int(effect.get("reputation_value", 0))
		"morale_culture_bonus":
			bucket["morale_bonus"] = int(bucket["morale_bonus"]) + int(effect.get("morale_value", 0))
			bucket["culture_bonus"] = float(bucket["culture_bonus"]) + float(effect.get("culture_value", 0.0))
		"diplomacy_bonus":
			bucket["diplomacy_bonus"] = float(bucket["diplomacy_bonus"]) + float(effect.get("value", 0.0))
		"recruit_cost_reduction":
			_add_float(bucket["recruit_cost_reduction"], str(effect.get("target", "all")), float(effect.get("value", 0.0)))
		"disaster_resist":
			bucket["disaster_resist_bonus"] = float(bucket["disaster_resist_bonus"]) + float(effect.get("value", 0.0))
		"corruption_reduction":
			bucket["corruption_reduction"] = float(bucket["corruption_reduction"]) + float(effect.get("value", 0.0))
		"zoc_range_bonus":
			bucket["zoc_range_bonus"] = int(bucket["zoc_range_bonus"]) + int(effect.get("value", 0))
		"zoc_cost_immunity":
			bucket["zoc_cost_immunity"] = bool(effect.get("value", true))
		"trade_route_capacity":
			bucket["trade_route_capacity_bonus"] = int(bucket["trade_route_capacity_bonus"]) + int(effect.get("value", 0))
		"trade_route_exchange_bonus":
			bucket["trade_route_exchange_bonus"] = float(bucket["trade_route_exchange_bonus"]) + float(effect.get("value", 0.0))
	if effect.has("disaster_resist") and effect_type != "disaster_resist":
		bucket["disaster_resist_bonus"] = float(bucket["disaster_resist_bonus"]) + float(effect.get("disaster_resist", 0.0))


func accumulate_malus(faction_id: String, malus: Dictionary) -> void:
	var bucket: Dictionary = ensure_bucket(faction_id)
	var malus_type: String = str(malus.get("type", ""))
	match malus_type:
		"morale_penalty":
			bucket["morale_bonus"] = int(bucket["morale_bonus"]) + int(malus.get("value", 0))
		"stability_penalty":
			bucket["stability_penalty"] = float(bucket["stability_penalty"]) + float(malus.get("value", 0))
		"recruit_cost_increase":
			_add_float(bucket["recruit_cost_reduction"], "all", -float(malus.get("value", 0.0)))
		"diplomacy_penalty":
			bucket["diplomacy_bonus"] = float(bucket["diplomacy_bonus"]) + float(malus.get("value", 0))
		"corruption_increase":
			bucket["corruption_increase"] = float(bucket["corruption_increase"]) + float(malus.get("value", 0))
		"resource_penalty":
			_add_float(bucket["resource_modifiers"], str(malus.get("resource", "")), float(malus.get("value", 0.0)))
		"attack_bonus":
			_add_float(bucket["attack_modifiers"], "all", float(malus.get("value", 0.0)))
		"security_bonus":
			bucket["security_bonus"] = float(bucket["security_bonus"]) + float(malus.get("value", 0.0))
		"trade_bonus":
			bucket["trade_bonus"] = float(bucket["trade_bonus"]) + float(malus.get("value", 0.0))
		"population_growth_penalty":
			bucket["population_growth_modifier"] = float(bucket["population_growth_modifier"]) + float(malus.get("value", 0))
		"upkeep_increase":
			bucket["upkeep_increase"] = float(bucket["upkeep_increase"]) + float(malus.get("value", 0))


# ============= 只读查询（消费端） =============

func attack_modifier(faction_id: String, target: String) -> float:
	# target=="all" 时只返回全局项，避免调用方再加一次 all 造成双计
	var am: Dictionary = {}
	if _buckets.has(faction_id):
		am = (_buckets[faction_id] as Dictionary)["attack_modifiers"]
	var all_v: float = float(am.get("all", 0.0))
	if target == "all" or target == "":
		return all_v
	return float(am.get(target, 0.0)) + all_v


func defense_modifier(faction_id: String, target: String) -> float:
	var dm: Dictionary = {}
	if _buckets.has(faction_id):
		dm = (_buckets[faction_id] as Dictionary)["defense_modifiers"]
	var all_v: float = float(dm.get("all", 0.0))
	if target == "all" or target == "":
		return all_v
	return float(dm.get(target, 0.0)) + all_v


func recruit_cost_reduction(faction_id: String, target: String) -> float:
	var rc: Dictionary = {}
	if _buckets.has(faction_id):
		rc = (_buckets[faction_id] as Dictionary)["recruit_cost_reduction"]
	var all_v: float = float(rc.get("all", 0.0))
	if target == "all" or target == "":
		return all_v
	return float(rc.get(target, 0.0)) + all_v


func resource_modifier(faction_id: String, resource: String) -> float:
	var rm: Dictionary = {}
	if _buckets.has(faction_id):
		rm = (_buckets[faction_id] as Dictionary)["resource_modifiers"]
	return float(rm.get(resource, 0.0))


func unit_unlocked(faction_id: String, unit_id: String) -> bool:
	if not _buckets.has(faction_id):
		return false
	return ((_buckets[faction_id] as Dictionary)["unlocked_units"] as Array).has(unit_id)


func can_traverse_terrain(faction_id: String, terrain: String) -> bool:
	if not _buckets.has(faction_id):
		return false
	return bool(((_buckets[faction_id] as Dictionary)["terrain_traversal"] as Dictionary).get(terrain, false))


func _fval(faction_id: String, key: String) -> float:
	if not _buckets.has(faction_id):
		return 0.0
	return float((_buckets[faction_id] as Dictionary).get(key, 0.0))


func _ival(faction_id: String, key: String) -> int:
	if not _buckets.has(faction_id):
		return 0
	return int((_buckets[faction_id] as Dictionary).get(key, 0))


func city_defense_bonus(faction_id: String) -> float:
	return _fval(faction_id, "city_defense_bonus")


func siege_bonus(faction_id: String) -> float:
	return _fval(faction_id, "siege_bonus")


func movement_bonus(faction_id: String) -> int:
	return _ival(faction_id, "movement_bonus")


func vision_bonus(faction_id: String) -> int:
	return _ival(faction_id, "vision_bonus")


func morale_bonus(faction_id: String) -> int:
	return _ival(faction_id, "morale_bonus")


func security_bonus(faction_id: String) -> float:
	return _fval(faction_id, "security_bonus")


func culture_bonus(faction_id: String) -> float:
	return _fval(faction_id, "culture_bonus")


func healing_bonus(faction_id: String) -> float:
	return _fval(faction_id, "healing_bonus")


func event_chance_bonus(faction_id: String) -> float:
	return _fval(faction_id, "event_chance_bonus")


func research_speed_modifier(faction_id: String) -> float:
	return _fval(faction_id, "research_speed_modifier") + runtime_bonus(faction_id, "research_speed_modifier")


func trade_bonus(faction_id: String) -> float:
	return _fval(faction_id, "trade_bonus") + runtime_bonus(faction_id, "trade_bonus")


func garrison_bonus(faction_id: String) -> float:
	return _fval(faction_id, "garrison_bonus")


func wall_durability_bonus(faction_id: String) -> float:
	return _fval(faction_id, "wall_durability_bonus")


func border_defense_bonus(faction_id: String, region: String) -> float:
	if not _buckets.has(faction_id):
		return 0.0
	var bd: Dictionary = (_buckets[faction_id] as Dictionary)["border_defense_bonus"]
	return float(bd.get(region, 0.0))


func diplomacy_bonus(faction_id: String) -> float:
	return _fval(faction_id, "diplomacy_bonus")


func disaster_resist_bonus(faction_id: String) -> float:
	return _fval(faction_id, "disaster_resist_bonus")


func corruption_reduction(faction_id: String) -> float:
	return _fval(faction_id, "corruption_reduction")


func corruption_increase(faction_id: String) -> float:
	return _fval(faction_id, "corruption_increase")


func zoc_range_bonus(faction_id: String) -> int:
	return _ival(faction_id, "zoc_range_bonus")


func has_zoc_cost_immunity(faction_id: String) -> bool:
	return bool(_fval(faction_id, "zoc_cost_immunity"))


func trade_route_capacity_bonus(faction_id: String) -> int:
	return _ival(faction_id, "trade_route_capacity_bonus")


func trade_route_exchange_bonus(faction_id: String) -> float:
	return _fval(faction_id, "trade_route_exchange_bonus")


func opinion_bonus(faction_id: String) -> int:
	return _ival(faction_id, "opinion_bonus")


func reputation_bonus(faction_id: String) -> int:
	return _ival(faction_id, "reputation_bonus")


func stability_penalty(faction_id: String) -> float:
	return _fval(faction_id, "stability_penalty")


func population_growth_modifier(faction_id: String) -> float:
	return _fval(faction_id, "population_growth_modifier")


func upkeep_increase(faction_id: String) -> float:
	return _fval(faction_id, "upkeep_increase")


func has_bucket(faction_id: String) -> bool:
	return _buckets.has(faction_id)


# ============= 内部 =============

func clear_tech_buckets() -> void:
	## 仅清空科技桶，保留学派等外部 runtime 加成
	_buckets.clear()
	effects_changed.emit("*")


func _add_float(dict: Dictionary, key: String, value: float) -> void:
	if key == "":
		return
	dict[key] = float(dict.get(key, 0.0)) + value


func _make_bucket() -> Dictionary:
	return {
		"attack_modifiers": {},
		"defense_modifiers": {},
		"resource_modifiers": {},
		"city_defense_bonus": 0.0,
		"siege_bonus": 0.0,
		"movement_bonus": 0,
		"vision_bonus": 0,
		"morale_bonus": 0,
		"security_bonus": 0.0,
		"culture_bonus": 0.0,
		"healing_bonus": 0.0,
		"event_chance_bonus": 0.0,
		"research_speed_modifier": 0.0,
		"trade_bonus": 0.0,
		"garrison_bonus": 0.0,
		"wall_durability_bonus": 0.0,
		"border_defense_bonus": {},
		"diplomacy_bonus": 0.0,
		"recruit_cost_reduction": {},
		"disaster_resist_bonus": 0.0,
		"corruption_reduction": 0.0,
		"corruption_increase": 0.0,
		"zoc_range_bonus": 0,
		"zoc_cost_immunity": false,
		"trade_route_capacity_bonus": 0,
		"trade_route_exchange_bonus": 0.0,
		"opinion_bonus": 0,
		"reputation_bonus": 0,
		"stability_penalty": 0.0,
		"population_growth_modifier": 0.0,
		"upkeep_increase": 0.0,
		"unlocked_units": [],
		"terrain_traversal": {},
	}
