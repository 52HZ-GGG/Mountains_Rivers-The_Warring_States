extends Node

## 外交系统 — 阶段2实现
##
## 管理所有外交状态：好感度、国际声望、条约、战争、附庸、商路、通行权。
## 所有外交动作通过本系统执行，状态变更通过 SignalBus 广播。

# ============= 状态存储 =============

## 双向独立好感度: _opinions[A][B] 表示 A 对 B 的好感度
var _opinions: Dictionary = {}

## 每国独立声望
var _reputation: Dictionary = {}

## 条约集合: key = "a_b", value = {type, turns_left, ...}
var _treaties: Dictionary = {}

## 战争状态: key = "a_b", value = {start_turn, cooldown_until}
var _at_war: Dictionary = {}

## 附庸关系: vassal_id -> {master_id, since_turn}
var _vassals: Dictionary = {}

## 商路: key = "a_b", value = {active: bool}
var _trade_routes: Dictionary = {}

## 通行权: key = "a_b", value = {max_units, turns_left, used_units}
var _military_access: Dictionary = {}

## 朝贡度: faction_id -> int
var _tribute: Dictionary = {}

## 质子状态: sender -> {receiver, minister_id, turns_left, quality}
var _hostages: Dictionary = {}

## 被俘大夫: owner_faction -> [minister_id]
var _prisoners: Dictionary = {}

## 情报力: observer -> {target -> {points, suppress_turns}}
var _intelligence: Dictionary = {}

## 纵横家能力/联盟预留状态
var _strategist_abilities: Dictionary = {}
var _hezong_alliance: Dictionary = {}
var _lianheng_alliance: Dictionary = {}

## 好感度衰减计数器
var _decay_counter: int = 0


# ============= 生命周期 =============

func _ready() -> void:
	SignalBus.turn_started.connect(_on_turn_started)
	SignalBus.turn_ended.connect(_on_turn_ended)


func _on_turn_started(turn_number: int, _faction_id: String) -> void:
	_update_opinion_decay()
	_update_treaty_expiry()
	_update_war_cooldowns()


func _on_turn_ended(turn_number: int, _faction_id: String) -> void:
	_settle_vassal_tribute()
	_settle_trade_routes()
	_tick_hostages()
	_tick_intelligence()


# ============= 初始化 =============

## 初始化外交状态，应在 start_game 后调用
func initialize(active_factions: Array[String]) -> void:
	_opinions.clear()
	_reputation.clear()
	_treaties.clear()
	_at_war.clear()
	_vassals.clear()
	_trade_routes.clear()
	_military_access.clear()
	_tribute.clear()
	_hostages.clear()
	_prisoners.clear()
	_intelligence.clear()
	_strategist_abilities.clear()
	_hezong_alliance.clear()
	_lianheng_alliance.clear()
	_decay_counter = 0

	# 初始化好感度（基于 initial_relations + 接壤修正）
	for a in active_factions:
		_opinions[a] = {}
		_reputation[a] = DataManager.get_balance_param("diplomacy.initial_reputation") as int
		_tribute[a] = DataManager.get_initial_tribute(a)
		_intelligence[a] = {}
		if not _prisoners.has(a):
			_prisoners[a] = []
		for b in active_factions:
			if a == b:
				continue
			var base_opinion: int = DataManager.get_initial_relations(a, b)
			# 接壤修正：接壤国家好感度-10
			if are_bordering(a, b):
				base_opinion -= 10
			_opinions[a][b] = base_opinion
			(_intelligence[a] as Dictionary)[b] = {"points": maxf(float(base_opinion), 0.0), "suppress_turns": 0}

	# 应用建筑外交效果
	_apply_building_diplomacy_effects()


# ============= 查询接口 =============

func get_opinion(faction_a: String, faction_b: String) -> int:
	if _opinions.has(faction_a) and _opinions[faction_a].has(faction_b):
		return _opinions[faction_a][faction_b]
	return 0


func get_reputation(faction_id: String) -> int:
	return _reputation.get(faction_id, 50)


func get_reputation_level(faction_id: String) -> String:
	var rep: int = get_reputation(faction_id)
	var thresholds: Dictionary = DataManager.get_diplomacy_param("reputation_thresholds")
	if rep < thresholds.get("very_low", 20):
		return "very_low"
	elif rep < thresholds.get("low", 30):
		return "low"
	elif rep >= thresholds.get("very_high", 80):
		return "very_high"
	elif rep >= thresholds.get("high", 70):
		return "high"
	return "mid"


func are_at_war(faction_a: String, faction_b: String) -> bool:
	return _at_war.has(_relation_key(faction_a, faction_b))


func are_allied(faction_a: String, faction_b: String) -> bool:
	var key := _relation_key(faction_a, faction_b)
	return _treaties.has(key) and _treaties[key]["type"] == "alliance"


func have_non_aggression(faction_a: String, faction_b: String) -> bool:
	var key := _relation_key(faction_a, faction_b)
	return _treaties.has(key) and _treaties[key]["type"] == "non_aggression"


func have_trade_route(faction_a: String, faction_b: String) -> bool:
	return _trade_routes.has(_relation_key(faction_a, faction_b))


func have_military_access(faction_a: String, faction_b: String) -> bool:
	var key := _relation_key(faction_a, faction_b)
	return _military_access.has(key) and _military_access[key]["turns_left"] > 0


func is_vassal(faction_id: String) -> bool:
	return _vassals.has(faction_id)


func get_vassal_master(faction_id: String) -> String:
	if _vassals.has(faction_id):
		return _vassals[faction_id]["master_id"]
	return ""


func get_vassals(master_id: String) -> Array[String]:
	var result: Array[String] = []
	for vid in _vassals:
		if _vassals[vid]["master_id"] == master_id:
			result.append(vid)
	return result


func are_bordering(faction_a: String, faction_b: String) -> bool:
	var cities_a: Array = DataManager.get_faction_cities(faction_a)
	var cities_b: Array = DataManager.get_faction_cities(faction_b)
	var threshold: int = DataManager.get_balance_param("diplomacy.border_distance_threshold")
	for ca in cities_a:
		for cb in cities_b:
			var dist := _hex_distance(ca["hex_q"], ca["hex_r"], cb["hex_q"], cb["hex_r"])
			if dist <= threshold:
				return true
	return false


func get_power_score(faction_id: String) -> float:
	var params: Dictionary = DataManager.get_diplomacy_param("power_score")
	var cities: Array = DataManager.get_faction_cities(faction_id)
	var city_count: int = cities.size()
	var resources: Dictionary = GameManager.get_faction_resources(faction_id)
	var troops: int = resources.get("troops", 0)
	var morale: int = resources.get("morale", 50)
	# 科技和文化暂用占位值
	var tech_count: int = 0
	var culture: int = 0
	return city_count * params.get("city_weight", 50) \
		+ troops * params.get("troop_weight", 3) \
		+ tech_count * params.get("tech_weight", 15) \
		+ morale * params.get("morale_weight", 1) \
		+ culture * params.get("culture_weight", 1)


func get_tribute(faction_id: String) -> int:
	return int(_tribute.get(faction_id, DataManager.get_initial_tribute(faction_id)))


func set_tribute(faction_id: String, value: int) -> void:
	if faction_id == "":
		return
	_tribute[faction_id] = clampi(value, 0, 100)


func get_hostage(faction_id: String) -> Dictionary:
	return _hostages.get(faction_id, {}).duplicate(true) if _hostages.has(faction_id) else {}


func has_hostage(faction_id: String) -> bool:
	return _hostages.has(faction_id)


func is_hostage_of(faction_id: String) -> bool:
	for sender in _hostages:
		var hostage: Dictionary = _hostages[sender]
		if str(hostage.get("receiver", "")) == faction_id:
			return true
	return false


func get_prisoners(faction_id: String) -> Array[String]:
	var result: Array[String] = []
	for minister_id in _prisoners.get(faction_id, []):
		result.append(str(minister_id))
	return result


func get_intelligence_points(observer: String, target: String) -> int:
	if observer == "" or target == "":
		return 0
	if DataManager.get_faction(observer).get("is_passive", false) or DataManager.get_faction(target).get("is_passive", false):
		return 100
	if are_at_war(observer, target):
		var war_state: Dictionary = _get_intelligence_state(observer, target)
		if not war_state.is_empty() and int(war_state.get("suppress_turns", 0)) > 0:
			return int(war_state.get("points", 0))
		return 0
	var value: int = 0
	var obs_intel: Dictionary = _intelligence.get(observer, {})
	var state: Dictionary = obs_intel.get(target, {})
	value += get_opinion(observer, target)
	value += int(state.get("points", 0))
	if have_trade_route(observer, target):
		value += int(DataManager.get_diplomacy_param("intelligence.modifiers.trade_route"))
	if has_hostage(observer):
		var hostage: Dictionary = _hostages.get(observer, {})
		if str(hostage.get("receiver", "")) == target:
			value += int(DataManager.get_diplomacy_param("intelligence.modifiers.hostage_held"))
	if DataManager.get_faction(observer).get("is_passive", false) or DataManager.get_faction(target).get("is_passive", false):
		return 100
	return maxi(0, value)


func get_intelligence_level(observer: String, target: String) -> int:
	var points: int = get_intelligence_points(observer, target)
	var thresholds: Dictionary = DataManager.get_diplomacy_param("intelligence.level_thresholds")
	if points >= int(thresholds.get("complete_min", 80)):
		return 4
	if points >= int(thresholds.get("detailed_min", 60)):
		return 3
	if points >= int(thresholds.get("basic_min", 40)):
		return 2
	if points >= int(thresholds.get("blackout_max", 20)):
		return 1
	return 0


func get_visible_enemy_cities(observer: String, target: String) -> Array[String]:
	var level: int = get_intelligence_level(observer, target)
	var visible: Array[String] = []
	if level <= 0:
		return visible
	for city in DataManager.get_faction_cities(target):
		visible.append(str(city.get("id", "")))
	return visible


func get_intel_detail(observer: String, target: String, info_type: String) -> Variant:
	var level: int = get_intelligence_level(observer, target)
	match info_type:
		"city_count":
			return DataManager.get_faction_cities(target).size() if level >= 1 else null
		"reputation":
			return get_reputation(target) if level >= 1 else null
		"troops":
			return GameManager.get_faction_resource(target, "troops") if level >= 2 else null
		"resources":
			return GameManager.get_faction_resources(target) if level >= 3 else null
		"cities":
			return get_visible_enemy_cities(observer, target) if level >= 1 else []
	return null


func is_zhou_faction(faction_id: String) -> bool:
	return faction_id == "zhou"


func is_zhou_destroyed() -> bool:
	return CityManager.is_faction_eliminated("zhou")


func get_declare_war_type(attacker: String, defender: String) -> String:
	if get_intelligence_points(defender, attacker) >= 60:
		return "declare"
	return "surprise"


func get_all_opinions_for(faction_id: String) -> Dictionary:
	return _opinions.get(faction_id, {})


func get_save_data() -> Dictionary:
	return {
		"opinions": _opinions.duplicate(true),
		"reputation": _reputation.duplicate(true),
		"treaties": _treaties.duplicate(true),
		"at_war": _at_war.duplicate(true),
		"vassals": _vassals.duplicate(true),
		"trade_routes": _trade_routes.duplicate(true),
		"military_access": _military_access.duplicate(true),
		"tribute": _tribute.duplicate(true),
		"hostages": _hostages.duplicate(true),
		"prisoners": _prisoners.duplicate(true),
		"intelligence": _intelligence.duplicate(true),
		"strategist_abilities": _strategist_abilities.duplicate(true),
		"hezong_alliance": _hezong_alliance.duplicate(true),
		"lianheng_alliance": _lianheng_alliance.duplicate(true),
		"event_chain_flags": _event_chain_flags.duplicate(true),
		"decay_counter": _decay_counter,
	}


func load_save_data(data: Dictionary) -> void:
	_opinions = (data.get("opinions", {}) as Dictionary).duplicate(true)
	_reputation = (data.get("reputation", {}) as Dictionary).duplicate(true)
	_treaties = (data.get("treaties", {}) as Dictionary).duplicate(true)
	_at_war = (data.get("at_war", {}) as Dictionary).duplicate(true)
	_vassals = (data.get("vassals", {}) as Dictionary).duplicate(true)
	_trade_routes = (data.get("trade_routes", {}) as Dictionary).duplicate(true)
	_military_access = (data.get("military_access", {}) as Dictionary).duplicate(true)
	_tribute = (data.get("tribute", {}) as Dictionary).duplicate(true)
	_hostages = (data.get("hostages", {}) as Dictionary).duplicate(true)
	_prisoners = (data.get("prisoners", {}) as Dictionary).duplicate(true)
	_intelligence = (data.get("intelligence", {}) as Dictionary).duplicate(true)
	_strategist_abilities = (data.get("strategist_abilities", {}) as Dictionary).duplicate(true)
	_hezong_alliance = (data.get("hezong_alliance", {}) as Dictionary).duplicate(true)
	_lianheng_alliance = (data.get("lianheng_alliance", {}) as Dictionary).duplicate(true)
	_event_chain_flags = (data.get("event_chain_flags", {}) as Dictionary).duplicate(true)
	_decay_counter = int(data.get("decay_counter", 0))


func add_prisoner(owner_faction: String, minister_id: String) -> void:
	if owner_faction == "" or minister_id == "":
		return
	if not _prisoners.has(owner_faction):
		_prisoners[owner_faction] = []
	var prisoners: Array = _prisoners[owner_faction]
	if not prisoners.has(minister_id):
		prisoners.append(minister_id)


func set_intelligence_points(observer: String, target: String, points: int, suppress_turns: int = 0) -> void:
	if observer == "" or target == "":
		return
	if not _intelligence.has(observer):
		_intelligence[observer] = {}
	(_intelligence[observer] as Dictionary)[target] = {
		"points": maxi(0, points),
		"suppress_turns": maxi(0, suppress_turns),
	}


func add_intelligence_points(observer: String, target: String, points: int, suppress_turns: int = 0) -> void:
	if observer == "" or target == "" or points == 0:
		return
	var state: Dictionary = _get_intelligence_state(observer, target)
	var base_points: int = int(state.get("points", 0))
	var next_points: int = maxi(0, base_points + points)
	var next_suppress: int = maxi(int(state.get("suppress_turns", 0)), suppress_turns)
	set_intelligence_points(observer, target, next_points, next_suppress)


# ============= 公共操作接口（供事件系统调用） =============

var _event_chain_flags: Dictionary = {}


func get_all_faction_ids() -> Array:
	return _opinions.keys()


func _get_intelligence_state(observer: String, target: String) -> Dictionary:
	if not _intelligence.has(observer):
		return {}
	var obs_intel: Dictionary = _intelligence.get(observer, {}) as Dictionary
	return obs_intel.get(target, {}) as Dictionary


## 公共好感度修改（供事件系统调用）
func change_opinion(faction_a: String, faction_b: String, delta: int) -> void:
	_change_opinion(faction_a, faction_b, delta)


## 公共声望修改（供事件系统调用）
func change_reputation(faction_id: String, delta: int) -> void:
	_change_reputation(faction_id, delta)


## 所有势力对 target 的好感变化
func change_opinion_all_toward(target: String, delta: int) -> void:
	for fid in _opinions:
		if fid != target:
			_change_opinion(fid, target, delta)


## 存储事件链标记
func set_event_chain_flag(flag_name: String, value: Variant = true) -> void:
	_event_chain_flags[flag_name] = value


## 读取事件链标记
func get_event_chain_flag(flag_name: String) -> Variant:
	return _event_chain_flags.get(flag_name, null)


## 获取所有事件链标记
func get_event_chain_flags() -> Dictionary:
	return _event_chain_flags.duplicate()


# ============= 外交动作 =============

func declare_war(attacker: String, defender: String) -> Dictionary:
	# 检查是否已在战争
	if are_at_war(attacker, defender):
		return {"success": false, "reason": "already_at_war"}

	# 检查战争冷却
	var key := _relation_key(attacker, defender)
	if _at_war.has(key) and _at_war[key]["cooldown_until"] > GameManager.get_current_turn():
		return {"success": false, "reason": "war_cooldown"}

	# 检查是否为附庸
	if is_vassal(attacker):
		return {"success": false, "reason": "is_vassal"}

	# 检查盟约
	if are_allied(attacker, defender):
		_break_alliance(attacker, defender)

	# 检查互不侵犯
	if have_non_aggression(attacker, defender):
		_break_treaty(attacker, defender, "non_aggression")

	# 执行宣战
	_at_war[key] = {"start_turn": GameManager.get_current_turn(), "cooldown_until": 0}
	_set_intelligence_war_state(attacker, defender)

	# 好感度变化
	var effects: Dictionary = DataManager.get_action_effects("declare_war")
	_change_opinion(attacker, defender, effects.get("opinion_change_target", -30))

	# 所有国家好感度变化（不宣而战惩罚）
	for fid in _opinions:
		if fid != attacker and fid != defender:
			_change_opinion(fid, attacker, effects.get("opinion_change_all", -10))

	# 声望变化
	_change_reputation(attacker, effects.get("reputation_change", -20))

	SignalBus.war_declared.emit(attacker, defender)
	SignalBus.diplomacy_action_performed.emit("declare_war", attacker, defender)
	return {"success": true}


func propose_ceasefire(proposer: String, target: String, terms: Dictionary) -> Dictionary:
	if not are_at_war(proposer, target):
		return {"success": false, "reason": "not_at_war"}

	# 检查战争持续时间
	var war_key := _relation_key(proposer, target)
	if _at_war.has(war_key):
		var war_turns: int = GameManager.get_current_turn() - _at_war[war_key]["start_turn"]
		var min_turns: int = DataManager.get_diplomacy_param("ceasefire_conditions.min_war_turns")
		if war_turns < min_turns:
			return {"success": false, "reason": "war_too_short"}

	SignalBus.negotiation_offer.emit(proposer, target, terms)
	return {"success": true, "reason": "negotiation_started"}


func accept_ceasefire(faction_a: String, faction_b: String, terms: Dictionary) -> Dictionary:
	var war_key := _relation_key(faction_a, faction_b)
	if not _at_war.has(war_key):
		return {"success": false, "reason": "not_at_war"}

	# 应用停战条件
	if terms.has("gold") and terms["gold"] > 0:
		var payer: String = terms.get("payer", faction_a)
		var receiver: String = terms.get("receiver", faction_b)
		GameManager.apply_faction_resource_delta(payer, "gold", -terms["gold"])
		GameManager.apply_faction_resource_delta(receiver, "gold", terms["gold"])

	if terms.has("city_id") and terms["city_id"] != "":
		# 割地：城市归属变更由 CityManager 处理，这里只发信号
		SignalBus.diplomacy_action_performed.emit("cede_city", faction_a, faction_b)

	if terms.get("vassal", false):
		_establish_vassal(faction_a, faction_b)

	# 结束战争
	_at_war.erase(war_key)
	var cooldown: int = DataManager.get_diplomacy_param("treaty_params.war_cooldown")
	# 设置冷却（不能立即再开战）
	var reverse_key := _relation_key(faction_b, faction_a)
	if _at_war.has(reverse_key):
		_at_war.erase(reverse_key)
	_set_intelligence_war_recovery(faction_a, faction_b)

	# 好感度恢复
	var effects: Dictionary = DataManager.get_action_effects("ceasefire")
	_change_opinion(faction_a, faction_b, effects.get("opinion_change_target", 5))
	_change_opinion(faction_b, faction_a, effects.get("opinion_change_target", 5))

	SignalBus.ceasefire_signed.emit(faction_a, faction_b)
	SignalBus.diplomacy_action_performed.emit("ceasefire", faction_a, faction_b)
	return {"success": true}


func sign_non_aggression(faction_a: String, faction_b: String, duration: int) -> Dictionary:
	if are_at_war(faction_a, faction_b):
		return {"success": false, "reason": "at_war"}

	var key := _relation_key(faction_a, faction_b)
	if _treaties.has(key) and _treaties[key]["type"] == "non_aggression":
		return {"success": false, "reason": "already_has_treaty"}

	_treaties[key] = {"type": "non_aggression", "turns_left": duration, "start_turn": GameManager.get_current_turn()}
	var effects: Dictionary = DataManager.get_action_effects("non_aggression")
	_change_opinion(faction_a, faction_b, effects.get("opinion_change_target", 5))
	_change_opinion(faction_b, faction_a, effects.get("opinion_change_target", 5))
	_change_reputation(faction_a, effects.get("reputation_change", 5))

	SignalBus.treaty_signed.emit(faction_a, "non_aggression")
	SignalBus.diplomacy_action_performed.emit("non_aggression", faction_a, faction_b)
	return {"success": true}


func grant_military_access(grantor: String, grantee: String, max_units: int) -> Dictionary:
	if are_at_war(grantor, grantee):
		return {"success": false, "reason": "at_war"}

	var params: Dictionary = DataManager.get_diplomacy_param("treaty_params")
	var cost_per_unit: int = params.get("military_access_cost_per_unit", 10)
	var total_cost: int = cost_per_unit * max_units
	var grantee_gold: int = GameManager.get_faction_resource(grantee, "gold")
	if grantee_gold < total_cost:
		return {"success": false, "reason": "not_enough_gold"}

	GameManager.apply_faction_resource_delta(grantee, "gold", -total_cost)
	GameManager.apply_faction_resource_delta(grantor, "gold", total_cost)

	var key := _relation_key(grantor, grantee)
	_military_access[key] = {"max_units": max_units, "turns_left": 5, "used_units": 0}

	var effects: Dictionary = DataManager.get_action_effects("military_access")
	_change_opinion(grantor, grantee, effects.get("opinion_change_target", 3))

	SignalBus.diplomacy_action_performed.emit("military_access", grantor, grantee)
	return {"success": true}


func open_trade_route(faction_a: String, faction_b: String) -> Dictionary:
	if are_at_war(faction_a, faction_b):
		return {"success": false, "reason": "at_war"}

	var key := _relation_key(faction_a, faction_b)
	if _trade_routes.has(key):
		return {"success": false, "reason": "already_has_trade"}

	_trade_routes[key] = {"active": true}

	var effects: Dictionary = DataManager.get_action_effects("trade_route")
	_change_opinion(faction_a, faction_b, effects.get("opinion_change_target", 5))
	_change_opinion(faction_b, faction_a, effects.get("opinion_change_target", 5))

	SignalBus.trade_route_opened.emit(faction_a, faction_b)
	SignalBus.diplomacy_action_performed.emit("trade_route", faction_a, faction_b)
	return {"success": true}


func send_gift(sender: String, receiver: String, tier: int) -> Dictionary:
	var tiers: Array = DataManager.get_gift_tiers()
	if tier < 0 or tier >= tiers.size():
		return {"success": false, "reason": "invalid_tier"}

	var tier_data: Dictionary = tiers[tier]
	var cost: int = tier_data["cost_gold"]
	var sender_gold: int = GameManager.get_faction_resource(sender, "gold")
	if sender_gold < cost:
		return {"success": false, "reason": "not_enough_gold"}

	GameManager.apply_faction_resource_delta(sender, "gold", -cost)
	GameManager.apply_faction_resource_delta(receiver, "gold", cost)

	var opinion_change: int = tier_data["opinion_change"]
	_change_opinion(receiver, sender, opinion_change)

	SignalBus.diplomacy_action_performed.emit("gift", sender, receiver)
	return {"success": true}


func form_alliance(faction_a: String, faction_b: String) -> Dictionary:
	if are_at_war(faction_a, faction_b):
		return {"success": false, "reason": "at_war"}

	# 好感度检查
	var opinion_ab: int = get_opinion(faction_a, faction_b)
	var opinion_ba: int = get_opinion(faction_b, faction_a)
	if opinion_ab < 30 or opinion_ba < 30:
		return {"success": false, "reason": "opinion_too_low"}

	var key := _relation_key(faction_a, faction_b)
	if _treaties.has(key) and _treaties[key]["type"] == "alliance":
		return {"success": false, "reason": "already_allied"}

	_treaties[key] = {"type": "alliance", "turns_left": -1, "start_turn": GameManager.get_current_turn()}

	var effects: Dictionary = DataManager.get_action_effects("alliance")
	_change_opinion(faction_a, faction_b, effects.get("opinion_change_target", 15))
	_change_opinion(faction_b, faction_a, effects.get("opinion_change_target", 15))
	_change_reputation(faction_a, effects.get("reputation_change", 5))
	_change_reputation(faction_b, effects.get("reputation_change", 5))

	SignalBus.alliance_formed.emit(faction_a, faction_b)
	SignalBus.diplomacy_action_performed.emit("alliance", faction_a, faction_b)
	return {"success": true}


func request_annex_neutral(requester: String, city_id: String) -> Dictionary:
	var city: Dictionary = DataManager.get_city(city_id)
	if city.is_empty():
		return {"success": false, "reason": "city_not_found"}
	if city.get("faction_id", "") != "neutral":
		return {"success": false, "reason": "not_neutral"}

	var params: Dictionary = DataManager.get_diplomacy_param("neutral_city")
	var threshold: int = params.get("lobby_opinion_threshold", 80)
	var cost: int = params.get("cost_gold", 200)

	# 中立城没有独立好感度系统，直接检查金钱
	var requester_gold: int = GameManager.get_faction_resource(requester, "gold")
	if requester_gold < cost:
		return {"success": false, "reason": "not_enough_gold"}

	GameManager.apply_faction_resource_delta(requester, "gold", -cost)

	# 建立附庸关系
	_vassals[city_id] = {"master_id": requester, "since_turn": GameManager.get_current_turn()}

	# 其他国家好感度下降
	var decline: int = params.get("opinion_decline_on_annex", -20)
	for fid in _opinions:
		if fid != requester:
			_change_opinion(fid, requester, decline)

	SignalBus.vassal_established.emit(city_id, requester)
	SignalBus.diplomacy_action_performed.emit("annex_neutral", requester, city_id)
	return {"success": true}


func request_vassalage(requester: String, target: String) -> Dictionary:
	if requester == "" or target == "" or requester == target:
		return {"success": false, "reason": "invalid_target"}
	if is_vassal(requester):
		return {"success": false, "reason": "already_vassal"}
	if are_at_war(requester, target):
		return {"success": false, "reason": "at_war"}
	var opinion: int = get_opinion(requester, target)
	var reputation_gap: int = get_reputation(target) - get_reputation(requester)
	var power_ratio: float = get_power_score(target) / maxf(get_power_score(requester), 1.0)
	var req: Dictionary = DataManager.get_diplomacy_param("vassal")
	if opinion < int(req.get("request_min_opinion", 50)):
		return {"success": false, "reason": "opinion_too_low"}
	if reputation_gap < int(req.get("request_reputation_gap", 20)):
		return {"success": false, "reason": "reputation_gap_too_low"}
	if power_ratio < float(req.get("request_power_ratio", 2.5)):
		return {"success": false, "reason": "power_ratio_too_low"}
	_establish_vassal(requester, target)
	_change_opinion(requester, target, 10)
	_change_reputation(target, 5)
	return {"success": true}


func send_tribute(sender: String, tier: String) -> Dictionary:
	if sender == "" or is_zhou_destroyed():
		return {"success": false, "reason": "tribute_locked"}
	var tribute_cfg: Dictionary = DataManager.get_tribute_params()
	if not tribute_cfg.has(tier):
		return {"success": false, "reason": "invalid_tier"}
	var tier_cfg: Dictionary = tribute_cfg.get(tier, {})
	var gold_cost: int = int(tier_cfg.get("cost_gold", 0))
	var food_cost: int = int(tier_cfg.get("cost_food", 0))
	if GameManager.get_faction_resource(sender, "gold") < gold_cost or GameManager.get_faction_resource(sender, "food") < food_cost:
		return {"success": false, "reason": "not_enough_resources"}
	GameManager.apply_faction_resource_delta(sender, "gold", -gold_cost)
	GameManager.apply_faction_resource_delta(sender, "food", -food_cost)
	var old_tribute: int = get_tribute(sender)
	var tribute_delta: int = int(tier_cfg.get("tribute_change", 0))
	_tribute[sender] = clampi(old_tribute + tribute_delta, 0, 100)
	var effects: Dictionary = DataManager.get_action_effects("tribute")
	_change_reputation(sender, int(tier_cfg.get("reputation_change", int(effects.get("reputation_change", 0)))))
	_change_opinion(sender, "zhou", int(effects.get("opinion_change_target", 10)))
	SignalBus.diplomacy_action_performed.emit("tribute", sender, "zhou")
	return {"success": true, "tribute": get_tribute(sender)}


func request_enfeoffment(faction_id: String, type: String) -> Dictionary:
	if faction_id == "" or is_zhou_destroyed():
		return {"success": false, "reason": "tribute_locked"}
	var params: Dictionary = DataManager.get_enfeoffment_params()
	if not params.has(type):
		return {"success": false, "reason": "invalid_type"}
	var type_cfg: Dictionary = params.get(type, {})
	if get_tribute(faction_id) < int(type_cfg.get("tribute_threshold", 0)):
		return {"success": false, "reason": "tribute_too_low"}
	var rep_boost: int = int(type_cfg.get("reputation_boost", 0))
	_change_reputation(faction_id, rep_boost)
	_change_opinion(faction_id, "zhou", int(type_cfg.get("opinion_boost_zhou", 0)))
	SignalBus.diplomacy_action_performed.emit("enfeoffment", faction_id, type)
	return {"success": true}


func send_hostage(sender: String, receiver: String, minister_id: String) -> Dictionary:
	if sender == "" or receiver == "" or minister_id == "":
		return {"success": false, "reason": "invalid_args"}
	var hostage_cfg: Dictionary = DataManager.get_hostage_params()
	if has_hostage(sender):
		return {"success": false, "reason": "already_has_hostage"}
	if is_hostage_of(receiver):
		return {"success": false, "reason": "receiver_already_has_hostage"}
	if get_opinion(sender, receiver) < int(hostage_cfg.get("min_opinion_to_send", 20)):
		return {"success": false, "reason": "opinion_too_low"}
	var minister: Dictionary = MinisterManager.get_minister(minister_id)
	if minister.is_empty():
		return {"success": false, "reason": "invalid_minister"}
	if str(minister.get("faction_id", "")) != sender:
		return {"success": false, "reason": "wrong_owner"}
	if str(minister.get("status", "")) != "idle":
		return {"success": false, "reason": "minister_busy"}
	_hostages[sender] = {
		"receiver": receiver,
		"minister_id": minister_id,
		"turns_left": int(DataManager.get_balance_param("minister.fate.diplomat_lifespan_turns")),
		"quality": str(minister.get("quality", "common")),
	}
	_change_opinion(sender, receiver, int(DataManager.get_action_effects("send_hostage").get("opinion_change_target", int(hostage_cfg.get("opinion_boost_on_send", 20)))))
	MinisterManager.send_minister_hostage(minister_id, receiver)
	SignalBus.diplomacy_action_performed.emit("send_hostage", sender, receiver)
	return {"success": true}


func recall_hostage(faction_id: String) -> Dictionary:
	if not has_hostage(faction_id):
		return {"success": false, "reason": "no_hostage"}
	var hostage: Dictionary = _hostages.get(faction_id, {})
	var receiver: String = str(hostage.get("receiver", ""))
	var hostage_cfg: Dictionary = DataManager.get_hostage_params()
	_hostages.erase(faction_id)
	_change_opinion(faction_id, receiver, int(DataManager.get_action_effects("recall_hostage").get("opinion_change_target", int(hostage_cfg.get("opinion_penalty_on_recall", -15)))))
	_change_reputation(faction_id, int(DataManager.get_action_effects("recall_hostage").get("reputation_change", int(hostage_cfg.get("reputation_penalty_on_recall", -5)))))
	SignalBus.diplomacy_action_performed.emit("recall_hostage", faction_id, receiver)
	return {"success": true}


func return_hostage(returner: String, owner: String) -> Dictionary:
	if returner == "" or owner == "":
		return {"success": false, "reason": "invalid_args"}
	var hostage_id: String = ""
	for sender in _hostages:
		var hostage: Dictionary = _hostages[sender]
		if str(hostage.get("receiver", "")) == returner and sender == owner:
			hostage_id = sender
			break
	if hostage_id == "":
		return {"success": false, "reason": "no_hostage"}
	var hostage_data: Dictionary = _hostages[hostage_id]
	_hostages.erase(hostage_id)
	_change_opinion(returner, owner, int(DataManager.get_action_effects("release_hostage").get("opinion_change_target", 10)))
	_change_reputation(returner, int(DataManager.get_action_effects("release_hostage").get("reputation_change", 5)))
	SignalBus.diplomacy_action_performed.emit("return_hostage", returner, owner)
	return {"success": true, "hostage": hostage_data}


func release_prisoners(releaser: String, target: String) -> Dictionary:
	if releaser == "" or target == "":
		return {"success": false, "reason": "invalid_args"}
	var prisoners: Array = _prisoners.get(target, [])
	if prisoners.is_empty():
		return {"success": false, "reason": "no_prisoners"}
	_prisoners[target] = []
	var host_cfg: Dictionary = DataManager.get_hostage_params()
	_change_opinion(releaser, target, int(DataManager.get_action_effects("release_hostage").get("opinion_change_target", int(host_cfg.get("opinion_boost_on_return", 10)))))
	_change_reputation(releaser, int(DataManager.get_action_effects("release_hostage").get("reputation_change", 5)))
	SignalBus.diplomacy_action_performed.emit("release_prisoners", releaser, target)
	return {"success": true, "prisoners": prisoners}


func _tick_hostages() -> void:
	var expired: Array[String] = []
	for sender in _hostages:
		var hostage: Dictionary = _hostages[sender]
		var turns_left: int = int(hostage.get("turns_left", 0))
		if turns_left > 0:
			hostage["turns_left"] = turns_left - 1
			if turns_left - 1 <= 0:
				expired.append(sender)
	for sender in expired:
		var hostage: Dictionary = _hostages[sender]
		var receiver: String = str(hostage.get("receiver", ""))
		var minister_id: String = str(hostage.get("minister_id", ""))
		_hostages.erase(sender)
		if minister_id != "":
			MinisterManager.release_minister_hostage(minister_id)
		if receiver != "":
			_change_opinion(sender, receiver, int(DataManager.get_action_effects("return_hostage").get("opinion_change_target", 10)))
			_change_reputation(sender, int(DataManager.get_action_effects("return_hostage").get("reputation_change", 5)))


func request_gate_open(requester: String, target: String) -> Dictionary:
	if are_at_war(requester, target):
		return {"success": false, "reason": "at_war"}

	var formula: Dictionary = DataManager.get_diplomacy_param("gate_open_score_formula")
	var opinion: int = get_opinion(target, requester)
	var requester_gold: int = GameManager.get_faction_resource(requester, "gold")
	var reputation: int = get_reputation(requester)

	var score: float = opinion * formula.get("opinion_weight", 0.4) \
		+ (requester_gold / formula.get("gold_divisor", 100)) * formula.get("gold_weight", 0.3) \
		+ reputation * formula.get("reputation_weight", 0.3)

	var threshold: float = formula.get("threshold", 60)
	if score < threshold:
		return {"success": false, "reason": "score_too_low", "score": score, "threshold": threshold}

	# 开放关隘 = 开放商路
	return open_trade_route(requester, target)


func request_vassal_escape(vassal_id: String, method: String) -> Dictionary:
	if not is_vassal(vassal_id):
		return {"success": false, "reason": "not_vassal"}

	var master_id: String = get_vassal_master(vassal_id)

	match method:
		"third_party_lobby":
			# 需要另一个国家好感度高于宗主国
			var best_ally := ""
			var best_opinion := -999
			for fid in _opinions:
				if fid != vassal_id and fid != master_id:
					var op: int = get_opinion(vassal_id, fid)
					if op > best_opinion:
						best_opinion = op
						best_ally = fid
			var master_opinion: int = get_opinion(vassal_id, master_id)
			if best_opinion <= master_opinion:
				return {"success": false, "reason": "no_stronger_ally"}
			_execute_escape(vassal_id, master_id)
			return {"success": true}

		"reputation_escape":
			var params: Dictionary = DataManager.get_diplomacy_param("vassal")
			var threshold: int = params.get("reputation_escape_threshold", 30)
			if get_reputation(master_id) >= threshold:
				return {"success": false, "reason": "master_reputation_too_high"}
			_execute_escape(vassal_id, master_id)
			return {"success": true}

		"wartime_escape":
			if not _is_master_at_war(master_id):
				return {"success": false, "reason": "master_not_at_war"}
			_execute_escape(vassal_id, master_id)
			return {"success": true}

	return {"success": false, "reason": "invalid_method"}


# ============= 内部方法 =============

func _relation_key(a: String, b: String) -> String:
	return a + "_" + b


func _hex_distance(q1: int, r1: int, q2: int, r2: int) -> int:
	return (absi(q1 - q2) + absi(q1 + r1 - q2 - r2) + absi(r1 - r2)) / 2


func _change_opinion(faction_a: String, faction_b: String, delta: int) -> void:
	if not _opinions.has(faction_a) or not _opinions[faction_a].has(faction_b):
		return
	var old_val: int = _opinions[faction_a][faction_b]
	var min_val: int = DataManager.get_balance_param("diplomacy.opinion_min")
	var max_val: int = DataManager.get_balance_param("diplomacy.opinion_max")
	_opinions[faction_a][faction_b] = clampi(old_val + delta, min_val, max_val)
	SignalBus.opinion_changed.emit(faction_a, faction_b, old_val, _opinions[faction_a][faction_b])


func _change_reputation(faction_id: String, delta: int) -> void:
	var old_val: int = _reputation.get(faction_id, 50)
	var min_val: int = DataManager.get_balance_param("diplomacy.reputation_min")
	var max_val: int = DataManager.get_balance_param("diplomacy.reputation_max")
	_reputation[faction_id] = clampi(old_val + delta, min_val, max_val)
	SignalBus.reputation_changed.emit(faction_id, old_val, _reputation[faction_id])


func _break_alliance(faction_a: String, faction_b: String) -> void:
	var key := _relation_key(faction_a, faction_b)
	_treaties.erase(key)
	var betrayal: Dictionary = DataManager.get_diplomacy_param("betrayal_effects")
	_change_opinion(faction_b, faction_a, betrayal.get("opinion_change_target", -50))
	_change_reputation(faction_a, betrayal.get("reputation_change", -30))
	for fid in _opinions:
		if fid != faction_a:
			_change_opinion(fid, faction_a, betrayal.get("opinion_change_all", -15))
	SignalBus.alliance_broken.emit(faction_a, faction_b)
	SignalBus.treaty_broken.emit(faction_a, faction_b, "alliance")


func _break_treaty(faction_a: String, faction_b: String, treaty_type: String) -> void:
	var key := _relation_key(faction_a, faction_b)
	_treaties.erase(key)
	var betrayal: Dictionary = DataManager.get_diplomacy_param("betrayal_effects")
	_change_opinion(faction_b, faction_a, betrayal.get("opinion_change_target", -50))
	_change_reputation(faction_a, betrayal.get("reputation_change", -30))
	SignalBus.treaty_broken.emit(faction_a, faction_b, treaty_type)


func _establish_vassal(vassal_id: String, master_id: String) -> void:
	_vassals[vassal_id] = {"master_id": master_id, "since_turn": GameManager.get_current_turn()}
	SignalBus.vassal_established.emit(vassal_id, master_id)


func _execute_escape(vassal_id: String, master_id: String) -> void:
	_vassals.erase(vassal_id)
	var params: Dictionary = DataManager.get_diplomacy_param("vassal")
	_change_reputation(master_id, params.get("escape_penalty_reputation", -10))
	_change_opinion(master_id, vassal_id, params.get("escape_penalty_opinion", -20))
	SignalBus.vassal_escaped.emit(vassal_id, master_id)


func _is_master_at_war(master_id: String) -> bool:
	for key in _at_war:
		if key.begins_with(master_id + "_") or key.ends_with("_" + master_id):
			return true
	return false


func _update_opinion_decay() -> void:
	_decay_counter += 1
	var interval: int = DataManager.get_diplomacy_param("opinion_decay.decay_interval_turns")
	var amount: int = DataManager.get_diplomacy_param("opinion_decay.decay_amount")
	if _decay_counter < interval:
		return
	_decay_counter = 0

	for a in _opinions:
		for b in _opinions[a]:
			var current: int = _opinions[a][b]
			if current > 0:
				_opinions[a][b] = max(0, current - amount)
			elif current < 0:
				_opinions[a][b] = min(0, current + amount)


func _update_treaty_expiry() -> void:
	var to_erase: Array = []
	for key in _treaties:
		var treaty: Dictionary = _treaties[key]
		if treaty["turns_left"] > 0:
			treaty["turns_left"] -= 1
			if treaty["turns_left"] <= 0:
				to_erase.append(key)
	for key in to_erase:
		var parts: PackedStringArray = key.split("_")
		var a: String = parts[0]
		var b: String = parts[1]
		SignalBus.treaty_expired.emit(a, _treaties[key]["type"])
		_treaties.erase(key)


func _update_war_cooldowns() -> void:
	var to_erase: Array = []
	for key in _at_war:
		var war: Dictionary = _at_war[key]
		if war["cooldown_until"] > 0 and war["cooldown_until"] <= GameManager.get_current_turn():
			to_erase.append(key)
	for key in to_erase:
		_at_war.erase(key)


func _tick_intelligence() -> void:
	var recover_turns: int = int(DataManager.get_diplomacy_param("intelligence.surprise_war_penalty_duration"))
	for observer in _intelligence:
		for target in (_intelligence[observer] as Dictionary):
			var state: Dictionary = (_intelligence[observer] as Dictionary)[target] as Dictionary
			var suppress_turns: int = int(state.get("suppress_turns", 0))
			if suppress_turns > 0:
				state["suppress_turns"] = suppress_turns - 1
				if int(state.get("suppress_turns", 0)) <= 0:
					if recover_turns > 0:
						state["points"] = int(state.get("war_restore_points", state.get("points", 0)))
					state.erase("war_restore_points")
				(_intelligence[observer] as Dictionary)[target] = state


func _settle_vassal_tribute() -> void:
	var rate: float = DataManager.get_diplomacy_param("vassal.tribute_rate")
	for vid in _vassals:
		var master_id: String = _vassals[vid]["master_id"]
		var vassal_resources: Dictionary = GameManager.get_faction_resources(vid)
		var gold_tribute: int = int(vassal_resources.get("gold", 0) * rate)
		var food_tribute: int = int(vassal_resources.get("food", 0) * rate)
		if gold_tribute > 0:
			GameManager.apply_faction_resource_delta(vid, "gold", -gold_tribute)
			GameManager.apply_faction_resource_delta(master_id, "gold", gold_tribute)
		if food_tribute > 0:
			GameManager.apply_faction_resource_delta(vid, "food", -food_tribute)
			GameManager.apply_faction_resource_delta(master_id, "food", food_tribute)


func _settle_trade_routes() -> void:
	var params: Dictionary = DataManager.get_diplomacy_param("trade_route")
	var base_income: int = params.get("base_income", 20)
	var rep_threshold: int = params.get("reputation_bonus_threshold", 70)
	var rep_bonus: float = params.get("reputation_bonus_rate", 0.10)

	for key in _trade_routes:
		if not _trade_routes[key]["active"]:
			continue
		var parts: PackedStringArray = key.split("_")
		var a: String = parts[0]
		var b: String = parts[1]
		var income_a: int = base_income
		var income_b: int = base_income
		if get_reputation(a) >= rep_threshold:
			income_a = int(base_income * (1.0 + rep_bonus))
		if get_reputation(b) >= rep_threshold:
			income_b = int(base_income * (1.0 + rep_bonus))
		GameManager.apply_faction_resource_delta(a, "gold", income_a)
		GameManager.apply_faction_resource_delta(b, "gold", income_b)


func _apply_building_diplomacy_effects() -> void:
	for faction_id in _opinions:
		var cities: Array = DataManager.get_faction_cities(faction_id)
		for city in cities:
			# 驿站: diplomacy_bonus
			# 王宫: diplomacy_reputation
			# 长城: diplomacy_opinion_neighbor
			# 这些效果在阶段2暂不逐城市追踪，留待阶段3完善
			pass


func _set_intelligence_war_state(attacker: String, defender: String) -> void:
	var attacker_state: Dictionary = _get_intelligence_state(attacker, defender)
	var defender_state: Dictionary = _get_intelligence_state(defender, attacker)
	_set_intelligence_state(attacker, defender, 0, 0, int(attacker_state.get("points", 0)))
	_set_intelligence_state(defender, attacker, 0, 0, int(defender_state.get("points", 0)))


func _set_intelligence_war_recovery(faction_a: String, faction_b: String) -> void:
	var penalty_points: int = int(DataManager.get_diplomacy_param("intelligence.surprise_war_penalty_points"))
	var penalty_turns: int = int(DataManager.get_diplomacy_param("intelligence.surprise_war_penalty_duration"))
	var a_restore: int = int(_get_intelligence_state(faction_a, faction_b).get("war_restore_points", 0))
	var b_restore: int = int(_get_intelligence_state(faction_b, faction_a).get("war_restore_points", 0))
	if a_restore <= 0:
		a_restore = int(_get_intelligence_state(faction_a, faction_b).get("points", 0))
	if b_restore <= 0:
		b_restore = int(_get_intelligence_state(faction_b, faction_a).get("points", 0))
	_set_intelligence_state(faction_a, faction_b, maxi(0, a_restore + penalty_points), penalty_turns, a_restore)
	_set_intelligence_state(faction_b, faction_a, maxi(0, b_restore + penalty_points), penalty_turns, b_restore)


func _set_intelligence_state(observer: String, target: String, points: float, suppress_turns: int, restore_points: int = 0) -> void:
	if observer == "" or target == "":
		return
	if not _intelligence.has(observer):
		_intelligence[observer] = {}
	(_intelligence[observer] as Dictionary)[target] = {
		"points": maxi(0, int(points)),
		"suppress_turns": maxi(0, suppress_turns),
		"war_restore_points": maxi(0, restore_points),
	}


# ============= 重置 =============

func reset() -> void:
	_opinions.clear()
	_reputation.clear()
	_treaties.clear()
	_at_war.clear()
	_vassals.clear()
	_trade_routes.clear()
	_military_access.clear()
	_decay_counter = 0


# ============= 测试辅助 =============

func get_treaties() -> Dictionary:
	return _treaties.duplicate(true)


func get_at_war() -> Dictionary:
	return _at_war.duplicate(true)


func get_vassals_dict() -> Dictionary:
	return _vassals.duplicate(true)


func get_trade_routes() -> Dictionary:
	return _trade_routes.duplicate(true)


func get_military_access() -> Dictionary:
	return _military_access.duplicate(true)


## 检查指定势力是否处于战争状态
func is_at_war(faction_id: String) -> bool:
	for key in _at_war:
		if _at_war[key].has(faction_id):
			return true
	return false


## 检查指定势力是否有同盟
func has_alliance(faction_id: String) -> bool:
	for key in _treaties:
		if key.begins_with("alliance_") and key.ends_with("_" + faction_id):
			return true
		if key.begins_with("alliance_" + faction_id + "_"):
			return true
	return false


## 获取指定势力的同盟数量
func get_allies_count(faction_id: String) -> int:
	var count: int = 0
	for key in _treaties:
		if key.begins_with("alliance_") and (key.ends_with("_" + faction_id) or key.begins_with("alliance_" + faction_id + "_")):
			count += 1
	return count
