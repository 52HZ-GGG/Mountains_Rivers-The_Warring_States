class_name DiplomacyAI

## AI 外交决策系统
##
## 根据 AI 性格参数（好战/贪婪/诚信/外交）驱动外交决策。
## 概率触发：每回合评估概率 = 好战度 × 15%。
## 包含宣战评估、停战评估、均势反应、附庸脱离评估。

# ============= 主入口 =============

## AI 外交决策入口，由 GameManager.process_ai_turn() 调用
static func evaluate_diplomacy(faction_id: String, turn_number: int) -> void:
	if DiplomacySystem.is_vassal(faction_id):
		_evaluate_vassal_escape(faction_id)
		return

	if not _should_evaluate(faction_id):
		return

	_evaluate_war(faction_id)
	_evaluate_ceasefire(faction_id)
	_evaluate_alliance(faction_id)
	_check_coalition_trigger()


# ============= 评估频率 =============

static func _should_evaluate(faction_id: String) -> bool:
	var personality: Dictionary = DataManager.get_ai_personality(faction_id)
	var aggression: int = personality.get("aggression", 2)
	var base_chance: float = DataManager.get_diplomacy_param("ai_decision.war_eval_base_chance")
	var chance: float = aggression * base_chance
	return randf() < chance


# ============= 宣战评估 =============

static func _evaluate_war(faction_id: String) -> void:
	# 已在战争中则不评估新宣战
	for other_id in GameManager.FACTION_IDS:
		if other_id != faction_id and DiplomacySystem.are_at_war(faction_id, other_id):
			return

	var target := _select_war_target(faction_id)
	if target.is_empty():
		return

	# 好感度保护：好感度>50 不主动宣战
	var opinion: int = DiplomacySystem.get_opinion(faction_id, target)
	if opinion > 50:
		return

	# 检查盟约
	if DiplomacySystem.are_allied(faction_id, target):
		return

	# 检查互不侵犯
	if DiplomacySystem.have_non_aggression(faction_id, target):
		return

	DiplomacySystem.declare_war(faction_id, target)


static func _select_war_target(faction_id: String) -> String:
	var weights: Dictionary = DataManager.get_diplomacy_param("ai_decision.war_target_weights")
	var best_target := ""
	var best_score := -1.0

	for other_id in GameManager.FACTION_IDS:
		if other_id == faction_id:
			continue
		if DiplomacySystem.are_at_war(faction_id, other_id):
			continue
		if DiplomacySystem.are_allied(faction_id, other_id):
			continue
		if DiplomacySystem.have_non_aggression(faction_id, other_id):
			continue

		var score: float = _calculate_target_score(faction_id, other_id, weights)
		if score > best_score:
			best_score = score
			best_target = other_id

	return best_target


static func _calculate_target_score(attacker: String, target: String, weights: Dictionary) -> float:
	# 距离分（越近越高）
	var distance_score: float = _distance_score(attacker, target)
	# 国力分（越弱越高）
	var power_score: float = _power_score(attacker, target)
	# 好感度分（越低越高）
	var opinion_score: float = _opinion_score(attacker, target)

	return distance_score * weights.get("distance", 0.3) \
		+ power_score * weights.get("power", 0.3) \
		+ opinion_score * weights.get("opinion", 0.4)


static func _distance_score(attacker: String, target: String) -> float:
	var cities_a: Array = DataManager.get_faction_cities(attacker)
	var cities_b: Array = DataManager.get_faction_cities(target)
	if cities_a.is_empty() or cities_b.is_empty():
		return 0.0

	var min_dist := 999
	for ca in cities_a:
		for cb in cities_b:
			var dist := _hex_distance(ca["hex_q"], ca["hex_r"], cb["hex_q"], cb["hex_r"])
			if dist < min_dist:
				min_dist = dist

	# 归一化：距离越近分数越高，最大距离30格
	return clampf(1.0 - float(min_dist) / 30.0, 0.0, 1.0)


static func _power_score(attacker: String, target: String) -> float:
	var attacker_power: float = DiplomacySystem.get_power_score(attacker)
	var target_power: float = DiplomacySystem.get_power_score(target)
	if attacker_power + target_power == 0:
		return 0.5
	# 目标越弱分数越高
	return clampf(1.0 - target_power / (attacker_power + target_power), 0.0, 1.0)


static func _opinion_score(attacker: String, target: String) -> float:
	var opinion: int = DiplomacySystem.get_opinion(attacker, target)
	# 好感度 -100~100 映射到 0~1（越低越高）
	return clampf(float(100 - opinion) / 200.0, 0.0, 1.0)


# ============= 停战评估 =============

static func _evaluate_ceasefire(faction_id: String) -> void:
	for other_id in GameManager.FACTION_IDS:
		if other_id == faction_id:
			continue
		if not DiplomacySystem.are_at_war(faction_id, other_id):
			continue

		# 检查是否应该主动求和
		if _should_offer_ceasefire(faction_id, other_id):
			var terms := _generate_ceasefire_terms(faction_id, other_id)
			DiplomacySystem.propose_ceasefire(faction_id, other_id, terms)


static func _should_offer_ceasefire(faction_id: String, enemy_id: String) -> bool:
	# 条件1：军队损耗>50%
	var resources: Dictionary = GameManager.get_faction_resources(faction_id)
	var initial_troops: int = resources.get("population", 10000) / 10  # 粗略估计初始军队
	var current_troops: int = resources.get("troops", 0)
	if initial_troops > 0 and current_troops < initial_troops * 0.5:
		return true

	# 条件2：占领敌方3座城
	var enemy_cities: int = DataManager.get_faction_cities(enemy_id).size()
	var my_cities: int = DataManager.get_faction_cities(faction_id).size()
	if enemy_cities <= DataManager.get_faction_cities(enemy_id).size() - 3:
		return true

	return false


static func _generate_ceasefire_terms(proposer: String, target: String) -> Dictionary:
	# AI 根据战局自动提出条件
	var terms: Dictionary = {"gold": 0, "city_id": "", "vassal": false}
	var personality: Dictionary = DataManager.get_ai_personality(proposer)
	var greed: int = personality.get("greed", 2)

	# 根据贪婪度决定条件苛刻程度
	if greed >= 3:
		terms["gold"] = 100 * greed
		terms["vassal"] = greed >= 4
	elif greed >= 2:
		terms["gold"] = 50 * greed

	return terms


# ============= 结盟评估 =============

static func _evaluate_alliance(faction_id: String) -> void:
	for other_id in GameManager.FACTION_IDS:
		if other_id == faction_id:
			continue
		if DiplomacySystem.are_allied(faction_id, other_id):
			continue
		if DiplomacySystem.are_at_war(faction_id, other_id):
			continue

		var opinion_ab: int = DiplomacySystem.get_opinion(faction_id, other_id)
		var opinion_ba: int = DiplomacySystem.get_opinion(other_id, faction_id)

		# 双方好感度都需要>40
		if opinion_ab > 40 and opinion_ba > 40:
			DiplomacySystem.form_alliance(faction_id, other_id)
			return


# ============= 均势反应 =============

static func _check_coalition_trigger() -> void:
	var params: Dictionary = DataManager.get_diplomacy_param("power_score")
	var trigger_ratio: float = params.get("coalition_trigger_ratio", 1.5)

	# 计算玩家国力
	var player_power: float = DiplomacySystem.get_power_score(GameManager.get_player_faction())

	# 计算AI平均国力
	var ai_total_power := 0.0
	var ai_count := 0
	for fid in GameManager.FACTION_IDS:
		if fid != GameManager.get_player_faction():
			ai_total_power += DiplomacySystem.get_power_score(fid)
			ai_count += 1

	if ai_count == 0:
		return

	var ai_avg_power: float = ai_total_power / ai_count

	# 玩家国力超过AI平均值的1.5倍时触发联盟
	if player_power > ai_avg_power * trigger_ratio:
		_form_coalition(GameManager.get_player_faction())


static func _form_coalition(against: String) -> void:
	# 所有与玩家好感度<0的AI尝试组建联盟
	for fid in GameManager.FACTION_IDS:
		if fid == against:
			continue
		var opinion: int = DiplomacySystem.get_opinion(fid, against)
		if opinion < 0:
			# 尝试与其他AI结盟
			for other_id in GameManager.FACTION_IDS:
				if other_id == against or other_id == fid:
					continue
				var other_opinion: int = DiplomacySystem.get_opinion(fid, other_id)
				if other_opinion > 20:
					DiplomacySystem.form_alliance(fid, other_id)
					break


# ============= 附庸脱离评估 =============

static func _evaluate_vassal_escape(faction_id: String) -> void:
	var master_id: String = DiplomacySystem.get_vassal_master(faction_id)
	if master_id.is_empty():
		return

	# 方法1：声望脱离
	var params: Dictionary = DataManager.get_diplomacy_param("vassal")
	var rep_threshold: int = params.get("reputation_escape_threshold", 30)
	if DiplomacySystem.get_reputation(master_id) < rep_threshold:
		DiplomacySystem.request_vassal_escape(faction_id, "reputation_escape")
		return

	# 方法2：趁乱脱离（宗主国在战争中）
	if DiplomacySystem._is_master_at_war(master_id):
		DiplomacySystem.request_vassal_escape(faction_id, "wartime_escape")
		return

	# 方法3：第三方拉拢
	var best_ally := ""
	var best_opinion := -999
	for other_id in GameManager.FACTION_IDS:
		if other_id != faction_id and other_id != master_id:
			var op: int = DiplomacySystem.get_opinion(faction_id, other_id)
			if op > best_opinion:
				best_opinion = op
				best_ally = other_id
	var master_opinion: int = DiplomacySystem.get_opinion(faction_id, master_id)
	if best_opinion > master_opinion:
		DiplomacySystem.request_vassal_escape(faction_id, "third_party_lobby")


# ============= 谈判评估 =============

## AI 评估停战报价，返回是否接受
static func evaluate_ceasefire_offer(faction_id: String, terms: Dictionary) -> bool:
	var score: float = _calculate_negotiation_score(faction_id, terms)
	var threshold: float = _get_accept_threshold(faction_id)
	return score >= threshold


static func _calculate_negotiation_score(faction_id: String, terms: Dictionary) -> float:
	var params: Dictionary = DataManager.get_diplomacy_param("negotiation")
	var score := 0.0

	# 赔款分数
	if terms.has("gold") and terms["gold"] > 0:
		score += terms["gold"] * params.get("score_per_gold", 0.01)

	# 割地分数
	if terms.has("city_id") and terms["city_id"] != "":
		score += params.get("score_per_city_base", 2)

	# 称臣分数
	if terms.get("vassal", false):
		score += params.get("score_vassal", 3)

	return score


static func _get_accept_threshold(faction_id: String) -> float:
	var params: Dictionary = DataManager.get_diplomacy_param("negotiation")
	var base: float = params.get("base_accept_threshold", 3)
	var personality: Dictionary = DataManager.get_ai_personality(faction_id)

	# 性格修正
	base += personality.get("aggression", 2) * params.get("personality_mod_aggression", 0.3)
	base += personality.get("greed", 2) * params.get("personality_mod_greed", 0.2)

	return base


## AI 生成还价
static func generate_counter_offer(faction_id: String, original_terms: Dictionary) -> Dictionary:
	var params: Dictionary = DataManager.get_diplomacy_param("negotiation")
	var counter: Dictionary = original_terms.duplicate()

	# 在临界点上加价
	var current_score: float = _calculate_negotiation_score(faction_id, counter)
	var threshold: float = _get_accept_threshold(faction_id)

	if current_score < threshold:
		var deficit: float = threshold - current_score
		if deficit > 0:
			var gold_increase: int = int(deficit / params.get("score_per_gold", 0.01))
			counter["gold"] = counter.get("gold", 0) + gold_increase

	return counter


# ============= 工具函数 =============

static func _hex_distance(q1: int, r1: int, q2: int, r2: int) -> int:
	return (absi(q1 - q2) + absi(q1 + r1 - q2 - r2) + absi(r1 - r2)) / 2
