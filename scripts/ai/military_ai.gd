class_name MilitaryAI

## AI 军事决策系统
##
## 根据 AI 性格参数（好战/贪婪/诚信/外交）驱动征兵、攻城、驻军决策。
## 数据驱动：所有参数从 balance_params.json → ai_military 读取。
## 由 GameManager.process_ai_turn() 调用。

# ============= 主入口 =============

## AI 军事决策入口。跳过被动势力（Zhou）。
static func evaluate_military(faction_id: String) -> void:
	var personality: Dictionary = DataManager.get_ai_personality(faction_id)
	if personality.get("is_passive", false):
		return
	_evaluate_recruitment(faction_id)
	_evaluate_siege(faction_id)
	_evaluate_garrison(faction_id)


# ============= 征兵子系统 =============

static func _evaluate_recruitment(faction_id: String) -> void:
	var params: Dictionary = DataManager.get_balance_param("ai_military.recruitment")
	var personality: Dictionary = DataManager.get_ai_personality(faction_id)
	var aggression: int = personality.get("aggression", 2)
	var diplomacy: int = personality.get("diplomacy", 2)
	var cities: Array = CityManager.get_faction_city_states(faction_id)

	for city in cities:
		var city_id: String = city["id"]
		var pool: int = CityManager.get_conscription_pool(city_id)
		if pool <= 0:
			continue
		# 计算征兵量
		var base_ratio: float = float(params.get("base_recruit_ratio", 0.5))
		var aggr_bonus: float = aggression * float(params.get("aggression_recruit_bonus_per_point", 0.1))
		var diplo_penalty: float = diplomacy * float(params.get("diplomacy_recruit_penalty_per_point", 0.05))
		var ratio: float = base_ratio * (1.0 + aggr_bonus - diplo_penalty)
		ratio = clampf(ratio, 0.1, 1.0)
		var recruit_count: int = int(pool * ratio)
		if recruit_count <= 0:
			continue
		# 选兵种
		var unit_id: String = _select_recruit_unit(faction_id, city_id)
		if unit_id == "":
			continue
		var result: Dictionary = GameManager.recruit_unit_from_city(city_id, unit_id, recruit_count)
		var actual: int = int(result.get("recruited", 0))
		if actual <= 0:
			continue


## 按性格加权随机选兵种类别，再从 units.json 找最便宜的对应兵种。
static func _select_recruit_unit(faction_id: String, _city_id: String) -> String:
	var personality: Dictionary = DataManager.get_ai_personality(faction_id)
	var aggression: int = personality.get("aggression", 2)
	var greed: int = personality.get("greed", 2)
	var params: Dictionary = DataManager.get_balance_param("ai_military.recruitment")
	var base_weights: Dictionary = params.get("prefer_unit_weights", {})
	var weights: Dictionary = {
		"infantry": float(base_weights.get("infantry", 3)) + float(greed),
		"cavalry": float(base_weights.get("cavalry", 2)) + float(aggression),
		"archer": float(base_weights.get("archer", 2)),
		"siege": float(base_weights.get("siege", 1)),
	}
	var categories: Array = weights.keys()
	var w: Array = []
	for c in categories:
		w.append(weights[c])
	var picked: String = _weighted_random_pick(categories, w)
	return _cheapest_unit_in_category(picked, _city_id)


## 从 units.json 中找指定类别下最便宜的兵种 ID。
static func _cheapest_unit_in_category(category: String, city_id: String = "") -> String:
	var recruitable_units: Array[String] = CityManager.get_recruitable_units(city_id) if city_id != "" else []
	var best_id: String = ""
	var best_cost: int = 999999
	for unit in DataManager.get_all_unit_types():
		var unit_id: String = str(unit.get("id", ""))
		if not recruitable_units.is_empty() and not recruitable_units.has(unit_id):
			continue
		if unit.get("category", "") != category:
			continue
		var cost: int = int(unit.get("cost_gold", 0)) + int(unit.get("cost_food", 0))
		if cost < best_cost:
			best_cost = cost
			best_id = unit_id
	if best_id == "" and not recruitable_units.is_empty():
		for unit_id in recruitable_units:
			var unit_data: Dictionary = DataManager.get_unit_type(unit_id)
			var cost: int = int(unit_data.get("cost_gold", 0)) + int(unit_data.get("cost_food", 0))
			if cost < best_cost:
				best_cost = cost
				best_id = unit_id
	if best_id == "":
		var all_units: Array = DataManager.get_all_unit_types()
		if not all_units.is_empty():
			best_id = all_units[0]["id"]
	return best_id


# ============= 攻城子系统（自动结算） =============

static func _evaluate_siege(faction_id: String) -> void:
	var params: Dictionary = DataManager.get_balance_param("ai_military.siege")
	var personality: Dictionary = DataManager.get_ai_personality(faction_id)
	var aggression: int = personality.get("aggression", 2)
	# 概率门控
	var base_chance: float = float(params.get("evaluation_chance_base", 0.10))
	var per_point: float = float(params.get("aggression_chance_per_point", 0.08))
	if randf() >= base_chance + aggression * per_point:
		return
	# 找目标
	var targets: Array = _find_siege_targets(faction_id, params)
	if targets.is_empty():
		return
	# 按城级升序 + 距离升序排序
	targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["level"] != b["level"]:
			return a["level"] < b["level"]
		return a["dist"] < b["dist"]
	)
	# 尝试攻击第一个可行目标
	for target in targets:
		if _should_attack_city(faction_id, target, params):
			_execute_auto_siege(faction_id, target["city_id"], target["from_city_id"], params)
			return


## 找己方城池附近（hex_distance ≤ adjacent_hex_distance）的敌方城池。
static func _find_siege_targets(faction_id: String, params: Dictionary) -> Array:
	var max_dist: int = int(params.get("adjacent_hex_distance", 2))
	var my_cities: Array = CityManager.get_faction_city_states(faction_id)
	var all_cities: Array = CityManager.get_all_city_states()
	var targets: Array = []
	for mc in my_cities:
		var mq: int = int(mc.get("hex_q", 0))
		var mr: int = int(mc.get("hex_r", 0))
		for ac in all_cities:
			if ac["current_faction_id"] == faction_id:
				continue
			if ac.get("is_ruins", false):
				continue
			var target_faction: String = str(ac.get("current_faction_id", ""))
			if not DiplomacySystem.are_at_war(faction_id, target_faction):
				continue
			var aq: int = int(ac.get("hex_q", 0))
			var ar: int = int(ac.get("hex_r", 0))
			var dist: int = _hex_distance(mq, mr, aq, ar)
			if dist <= max_dist:
				targets.append({
					"city_id": ac["id"],
					"from_city_id": mc["id"],
					"level": int(ac.get("city_level", 1)),
					"dist": dist,
				})
	return targets


## 判断是否应该攻击：己方兵力 ≥ 城防 × min_ratio。
static func _should_attack_city(faction_id: String, target: Dictionary, params: Dictionary) -> bool:
	var min_ratio: float = float(params.get("min_troop_ratio_to_siege", 1.5))
	var my_troops: int = GameManager.get_total_troops(faction_id)
	var city_def: int = CityManager.get_city_defense(target["city_id"])
	return my_troops >= int(city_def * min_ratio)


## 执行自动攻城：投兵 → 攻城伤害 → 城池反击 → 占领/撤退。
static func _execute_auto_siege(faction_id: String, target_city_id: String, from_city_id: String, params: Dictionary) -> void:
	var allocate_ratio: float = float(params.get("siege_troop_allocate_ratio", 0.3))
	var total_troops: int = GameManager.get_total_troops(faction_id)
	var send_troops: int = int(total_troops * allocate_ratio)
	if send_troops <= 0:
		return
	# 选最佳攻城单位
	var siege_unit: String = _select_best_siege_unit(faction_id)
	if siege_unit == "":
		return
	# 投入兵力
	var comp: Dictionary = GameManager.get_unit_composition(faction_id)
	var available: int = int(comp.get(siege_unit, 0))
	if available < send_troops:
		# 尝试用其他单位补足
		for uid in comp:
			if uid != siege_unit:
				available += int(comp[uid])
		if available < send_troops:
			send_troops = available
	if send_troops <= 0:
		return
	# 攻城伤害
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var city_def: int = CityManager.get_city_defense(target_city_id)
	var city_hp: int = CityManager.get_city_hp(target_city_id)
	var atk_result: Dictionary = CombatResolver.compute_siege_damage(siege_unit, send_troops, city_def, city_hp, rng)
	var damage: int = int(atk_result.get("damage", 0))
	var destroyed: bool = atk_result.get("city_destroyed", false)
	if destroyed or damage >= city_hp:
		# 城池被摧毁 → 占领
		CityManager.occupy_city(target_city_id, faction_id)
		# 从投入兵力中留驻，避免与 assign_garrison 重复扣兵。
		var garrison_ratio: float = float(params.get("post_siege_garrison_ratio", 0.3))
		var cap: int = CityManager.get_garrison_capacity(target_city_id)
		var garrison_count: int = mini(int(cap * garrison_ratio), send_troops)
		if garrison_count > 0:
			_remove_troops_from_composition(faction_id, siege_unit, garrison_count)
			CityManager.add_garrison_direct(target_city_id, garrison_count)
	else:
		CityManager.damage_city(target_city_id, damage)
		# 城池反击
		var city_atk: int = CityManager.get_city_attack(target_city_id)
		var city_lv: int = int(CityManager.get_city_state(target_city_id).get("city_level", 1))
		var counter: Dictionary = CombatResolver.compute_city_counter_damage(city_atk, city_lv, siege_unit, send_troops, rng)
		var counter_damage: int = int(counter.get("damage", 0))
		if counter_damage > 0:
			_remove_troops_from_composition(faction_id, siege_unit, mini(counter_damage, send_troops))


## 选最佳攻城单位：攻城类优先，否则最强单位。
static func _select_best_siege_unit(faction_id: String) -> String:
	var comp: Dictionary = GameManager.get_unit_composition(faction_id)
	if comp.is_empty():
		return ""
	# 优先攻城类
	for uid in comp:
		var unit_data: Dictionary = DataManager.get_unit_type(uid)
		if unit_data.get("category", "") == "siege":
			return uid
	# 否则选数量最多的
	var best_id: String = ""
	var best_count: int = 0
	for uid in comp:
		var count: int = int(comp[uid])
		if count > best_count:
			best_count = count
			best_id = uid
	return best_id


## 从兵种构成中移除指定数量。优先从指定 unit_id 扣，不足时从其他兵种补。
static func _remove_troops_from_composition(faction_id: String, unit_id: String, amount: int) -> void:
	var remaining: int = amount
	var comp: Dictionary = GameManager.get_unit_composition(faction_id)
	# 先扣指定兵种
	var available: int = int(comp.get(unit_id, 0))
	var deduct: int = mini(available, remaining)
	if deduct > 0:
		GameManager.remove_units(faction_id, unit_id, deduct)
		remaining -= deduct
	# 不足部分从其他兵种扣
	if remaining > 0:
		for uid in comp:
			if uid == unit_id:
				continue
			var cnt: int = int(comp[uid])
			var d: int = mini(cnt, remaining)
			if d > 0:
				GameManager.remove_units(faction_id, uid, d)
				remaining -= d
			if remaining <= 0:
				break


# ============= 驻军子系统 =============

static func _evaluate_garrison(faction_id: String) -> void:
	var params: Dictionary = DataManager.get_balance_param("ai_military.garrison")
	var cities: Array = CityManager.get_faction_city_states(faction_id)
	for city in cities:
		var city_id: String = city["id"]
		var current: int = CityManager.get_garrison(city_id)
		var capacity: int = CityManager.get_garrison_capacity(city_id)
		if current >= capacity:
			continue
		var threat: float = _calculate_threat_level(city_id, faction_id, params)
		var desired: int = _calculate_desired_garrison(city_id, faction_id, threat, params)
		var deficit: int = desired - current
		if deficit > 0:
			var assign: int = mini(deficit, capacity - current)
			CityManager.assign_garrison(city_id, assign)


## 计算城池威胁等级：扫描范围内敌方城数 / 友方城数。
static func _calculate_threat_level(city_id: String, faction_id: String, params: Dictionary) -> float:
	var scan_dist: int = int(params.get("threat_evaluation_distance", 3))
	var city: Dictionary = CityManager.get_city_state(city_id)
	if city.is_empty():
		return 0.0
	var cq: int = int(city.get("hex_q", 0))
	var cr: int = int(city.get("hex_r", 0))
	var enemy_count: int = 0
	var friendly_count: int = 0
	for other in CityManager.get_all_city_states():
		if other["id"] == city_id:
			continue
		var oq: int = int(other.get("hex_q", 0))
		var or_: int = int(other.get("hex_r", 0))
		if _hex_distance(cq, cr, oq, or_) > scan_dist:
			continue
		if other["current_faction_id"] == faction_id:
			friendly_count += 1
		else:
			enemy_count += 1
	if friendly_count == 0:
		return 2.0 if enemy_count > 0 else 0.0
	return float(enemy_count) / float(friendly_count)


## 根据威胁等级计算期望驻军数量。
static func _calculate_desired_garrison(city_id: String, faction_id: String, threat: float, params: Dictionary) -> int:
	var capacity: int = CityManager.get_garrison_capacity(city_id)
	var city: Dictionary = CityManager.get_city_state(city_id)
	var turns_since_capture: int = int(city.get("turns_since_capture", 0))
	# 刚占领的城池
	if turns_since_capture > 0 and turns_since_capture <= 10:
		return int(capacity * float(params.get("conquered_city_garrison_ratio", 0.4)))
	# 威胁城池
	if threat > 1.0:
		return int(capacity * (float(params.get("garrison_ratio_threatened", 0.5)) + float(params.get("frontline_garrison_bonus", 0.2))))
	# 安全城池
	return int(capacity * float(params.get("garrison_ratio_peaceful", 0.2)))


# ============= 工具函数 =============

static func _hex_distance(q1: int, r1: int, q2: int, r2: int) -> int:
	return (absi(q1 - q2) + absi(q1 + r1 - q2 - r2) + absi(r1 - r2)) / 2


static func _weighted_random_pick(items: Array, weights: Array) -> String:
	var total: float = 0.0
	for w in weights:
		total += float(w)
	if total <= 0.0:
		return items[0] if not items.is_empty() else ""
	var roll: float = randf() * total
	var acc: float = 0.0
	for i in items.size():
		acc += float(weights[i])
		if roll < acc:
			return items[i]
	return items[items.size() - 1]
