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
	_decay_counter = 0

	# 初始化好感度（基于 initial_relations + 接壤修正）
	for a in active_factions:
		_opinions[a] = {}
		_reputation[a] = DataManager.get_balance_param("diplomacy.initial_reputation") as int
		for b in active_factions:
			if a == b:
				continue
			var base_opinion: int = DataManager.get_initial_relations(a, b)
			# 接壤修正：接壤国家好感度-10
			if are_bordering(a, b):
				base_opinion -= 10
			_opinions[a][b] = base_opinion

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


func get_all_opinions_for(faction_id: String) -> Dictionary:
	return _opinions.get(faction_id, {})


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
