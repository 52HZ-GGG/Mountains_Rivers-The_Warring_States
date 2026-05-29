extends GutTest

## MilitaryAI 单元测试 — 征兵 / 攻城 / 驻军决策
##
## GameManager + CityManager 是 autoload，状态在测试间持续。
## 每个测试通过 before_each 调用 reset() 隔离状态。

const TWO_FACTIONS: Array[String] = ["qin", "zhao"]
const PLAYER: String = "zhao"
const MilitaryLib := preload("res://scripts/ai/military_ai.gd")


func before_each() -> void:
	GameManager.reset()
	CityManager.reset()
	DiplomacySystem.reset()
	EventManager.set_muted(true)


# ============= 征兵 =============

func test_evaluate_military_skips_passive() -> void:
	# Zhou 是被动势力，不应执行任何军事决策
	MilitaryLib.evaluate_military("zhou")
	# 无异常即通过；验证不调用 conscribe（无兵力变化）
	assert_eq(GameManager.get_total_troops("zhou"), 0,
		"被动势力不应征兵")


func test_recruit_respects_pool() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	# 切到 qin（AI）回合
	GameManager.end_current_turn()
	var qin_cities: Array = CityManager.get_faction_city_states("qin")
	assert_false(qin_cities.is_empty(), "qin 应有城市")
	var city_id: String = qin_cities[0]["id"]
	# 手动设置征兵池
	var city: Dictionary = CityManager.get_city_state(city_id)
	city["conscription_pool"] = 10
	# 执行征兵
	MilitaryLib._evaluate_recruitment("qin")
	# 验证：征兵量 ≤ 池大小
	var troops: int = GameManager.get_total_troops("qin")
	assert_true(troops <= 10, "征兵量不应超过征兵池（实际: %d）" % troops)


func test_recruit_deducts_resources() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	GameManager.end_current_turn()  # qin
	var gold_before: int = GameManager.get_faction_resource("qin", "gold")
	var food_before: int = GameManager.get_faction_resource("qin", "food")
	var troops_before: int = GameManager.get_total_troops("qin")
	# 设置较大征兵池确保征兵发生
	var city_id: String = CityManager.get_faction_city_states("qin")[0]["id"]
	CityManager.get_city_state(city_id)["conscription_pool"] = 50
	MilitaryLib._evaluate_recruitment("qin")
	var troops_after: int = GameManager.get_total_troops("qin")
	if troops_after > troops_before:
		var gold_after: int = GameManager.get_faction_resource("qin", "gold")
		var food_after: int = GameManager.get_faction_resource("qin", "food")
		assert_true(gold_after <= gold_before, "征兵应扣金币")
		assert_true(food_after <= food_before, "征兵应扣粮食")
	else:
		# 未能征兵（资源不足），验证兵力未变
		assert_eq(troops_after, troops_before, "资源不足时兵力应不变")


func test_recruit_personality_scaling() -> void:
	# 秦（aggression=4）应比齐（aggression=1）征更多兵
	var qin_personality: Dictionary = DataManager.get_ai_personality("qin")
	var qi_personality: Dictionary = DataManager.get_ai_personality("qi")
	var qin_aggr: int = qin_personality.get("aggression", 2)
	var qi_aggr: int = qi_personality.get("aggression", 2)
	assert_true(qin_aggr > qi_aggr,
		"秦 aggression(%d) 应 > 齐(%d)" % [qin_aggr, qi_aggr])


func test_recruit_skips_low_resources() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	GameManager.end_current_turn()  # qin
	# 设置征兵池为 0 来验证征兵被跳过（征兵池 <= 0 时直接 continue）
	var city_id: String = CityManager.get_faction_city_states("qin")[0]["id"]
	CityManager.get_city_state(city_id)["conscription_pool"] = 0
	MilitaryLib._evaluate_recruitment("qin")
	assert_eq(GameManager.get_total_troops("qin"), 0,
		"征兵池为 0 时不应征兵")


func test_recruit_keeps_minimum_resource_reserve() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	GameManager.end_current_turn()  # qin
	var params: Dictionary = DataManager.get_balance_param("ai_military.recruitment")
	var min_gold: int = int(params.get("min_gold_reserve", 0))
	var min_food: int = int(params.get("min_food_reserve", 0))
	var gold_delta: int = min_gold - GameManager.get_faction_resource("qin", "gold")
	var food_delta: int = min_food - GameManager.get_faction_resource("qin", "food")
	GameManager.apply_faction_resource_delta("qin", "gold", gold_delta)
	GameManager.apply_faction_resource_delta("qin", "food", food_delta)
	var city_id: String = CityManager.get_faction_city_states("qin")[0]["id"]
	CityManager.get_city_state(city_id)["conscription_pool"] = 50
	MilitaryLib._evaluate_recruitment("qin")
	assert_eq(GameManager.get_total_troops("qin"), 0,
		"AI 不应动用最低资源储备征兵")


func test_select_unit_prefers_infantry() -> void:
	# 平衡性格（aggression=2, greed=2）多次选兵种，步兵概率应最高
	var counts: Dictionary = {"infantry": 0, "cavalry": 0, "archer": 0, "siege": 0}
	for i in 100:
		var unit_id: String = MilitaryLib._select_recruit_unit("qi", "")
		if unit_id == "":
			continue
		var unit_data: Dictionary = DataManager.get_unit_type(unit_id)
		var cat: String = unit_data.get("category", "")
		if counts.has(cat):
			counts[cat] += 1
	assert_true(counts["infantry"] > counts["cavalry"],
		"平衡性格应偏好步兵（步兵: %d, 骑兵: %d）" % [counts["infantry"], counts["cavalry"]])


# ============= 攻城 =============

func test_siege_finds_adjacent_targets() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	DiplomacySystem.declare_war("qin", "zhao")
	# 将赵国一座城移到秦都旁边（原地图不相邻）
	var zhao_cities: Array = CityManager.get_faction_city_states("zhao")
	assert_false(zhao_cities.is_empty())
	var zhao_city: Dictionary = CityManager.get_city_state(zhao_cities[0]["id"])
	zhao_city["hex_q"] = 4
	zhao_city["hex_r"] = 10
	var params: Dictionary = DataManager.get_balance_param("ai_military.siege")
	var targets: Array = MilitaryLib._find_siege_targets("qin", params)
	assert_false(targets.is_empty(), "秦应找到邻近敌方城池")


func test_siege_ignores_non_war_targets() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	var zhao_cities: Array = CityManager.get_faction_city_states("zhao")
	assert_false(zhao_cities.is_empty())
	var zhao_city: Dictionary = CityManager.get_city_state(zhao_cities[0]["id"])
	zhao_city["hex_q"] = 4
	zhao_city["hex_r"] = 10
	var params: Dictionary = DataManager.get_balance_param("ai_military.siege")
	var targets: Array = MilitaryLib._find_siege_targets("qin", params)
	assert_true(targets.is_empty(), "未宣战时 AI 不应把邻近城市列为攻城目标")


func test_siege_applies_damage() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	GameManager.end_current_turn()  # qin
	# 将赵国城移到秦都旁边
	var zhao_cities: Array = CityManager.get_faction_city_states("zhao")
	assert_false(zhao_cities.is_empty())
	var zhao_city: Dictionary = CityManager.get_city_state(zhao_cities[0]["id"])
	zhao_city["hex_q"] = 4
	zhao_city["hex_r"] = 10
	# 给 qin 大量兵力
	GameManager.add_units("qin", "infantry", 500)
	var target_id: String = zhao_cities[0]["id"]
	var hp_before: int = CityManager.get_city_hp(target_id)
	# 执行攻城
	var params: Dictionary = DataManager.get_balance_param("ai_military.siege")
	MilitaryLib._execute_auto_siege("qin", target_id,
		CityManager.get_faction_city_states("qin")[0]["id"], params)
	var hp_after: int = CityManager.get_city_hp(target_id)
	assert_true(hp_after <= hp_before,
		"攻城后城池 HP 应减少或被占领（前: %d, 后: %d）" % [hp_before, hp_after])


func test_siege_occupies_on_destruction() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	GameManager.end_current_turn()  # qin
	# 将赵国城移到秦都旁边
	var zhao_cities: Array = CityManager.get_faction_city_states("zhao")
	assert_false(zhao_cities.is_empty())
	var zhao_city: Dictionary = CityManager.get_city_state(zhao_cities[0]["id"])
	zhao_city["hex_q"] = 4
	zhao_city["hex_r"] = 10
	# 给 qin 大量兵力
	GameManager.add_units("qin", "infantry", 1000)
	# 先把赵国城池 HP 削到 1
	var target_id: String = zhao_cities[0]["id"]
	var hp: int = CityManager.get_city_hp(target_id)
	CityManager.damage_city(target_id, hp - 1)
	assert_eq(CityManager.get_city_hp(target_id), 1, "城池 HP 应为 1")
	# 攻城应占领
	var params: Dictionary = DataManager.get_balance_param("ai_military.siege")
	MilitaryLib._execute_auto_siege("qin", target_id,
		CityManager.get_faction_city_states("qin")[0]["id"], params)
	assert_eq(CityManager.get_city_state(target_id)["current_faction_id"], "qin",
		"城池 HP 归零后应被占领")


func test_siege_success_does_not_double_charge_garrison() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	GameManager.end_current_turn()  # qin
	var zhao_cities: Array = CityManager.get_faction_city_states("zhao")
	assert_false(zhao_cities.is_empty())
	var target_id: String = zhao_cities[0]["id"]
	var hp: int = CityManager.get_city_hp(target_id)
	CityManager.damage_city(target_id, hp - 1)
	GameManager.add_units("qin", "infantry", 1000)
	var troops_before: int = GameManager.get_total_troops("qin")
	var params: Dictionary = DataManager.get_balance_param("ai_military.siege")
	MilitaryLib._execute_auto_siege("qin", target_id,
		CityManager.get_faction_city_states("qin")[0]["id"], params)
	var mobile_after: int = GameManager.get_total_troops("qin")
	var garrison_after: int = CityManager.get_garrison(target_id)
	assert_eq(mobile_after + garrison_after, troops_before,
		"攻城成功后机动兵力 + 新驻军应守恒，不能重复扣兵")


func test_failed_siege_only_loses_counter_damage() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	GameManager.end_current_turn()  # qin
	var zhao_cities: Array = CityManager.get_faction_city_states("zhao")
	assert_false(zhao_cities.is_empty())
	var target_id: String = zhao_cities[0]["id"]
	var target_city: Dictionary = CityManager.get_city_state(target_id)
	target_city["current_hp"] = 999999
	target_city["city_level"] = 1
	target_city["garrison"] = 0
	GameManager.add_units("qin", "infantry", 500)
	var troops_before: int = GameManager.get_total_troops("qin")
	var params: Dictionary = DataManager.get_balance_param("ai_military.siege")
	var send_troops: int = int(troops_before * float(params.get("siege_troop_allocate_ratio", 0.3)))
	MilitaryLib._execute_auto_siege("qin", target_id,
		CityManager.get_faction_city_states("qin")[0]["id"], params)
	var troops_after: int = GameManager.get_total_troops("qin")
	assert_true(troops_after >= troops_before - 2,
		"攻城失败时不应吞掉全部投入兵力，只应扣除反击损失")


func test_siege_requires_minimum_troops() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	GameManager.end_current_turn()  # qin
	DiplomacySystem.declare_war("qin", "zhao")
	# 将赵国城移到秦都旁边
	var zhao_cities: Array = CityManager.get_faction_city_states("zhao")
	assert_false(zhao_cities.is_empty())
	var zhao_city: Dictionary = CityManager.get_city_state(zhao_cities[0]["id"])
	zhao_city["hex_q"] = 4
	zhao_city["hex_r"] = 10
	# 不给 qin 兵力
	var params: Dictionary = DataManager.get_balance_param("ai_military.siege")
	var targets: Array = MilitaryLib._find_siege_targets("qin", params)
	assert_false(targets.is_empty(), "应找到目标城池")
	var should: bool = MilitaryLib._should_attack_city("qin", targets[0], params)
	assert_false(should, "兵力不足时不应攻城")


# ============= 驻军 =============

func test_garrison_assigns_to_threatened() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	GameManager.end_current_turn()  # qin
	# 给 qin 兵力
	GameManager.add_units("qin", "infantry", 200)
	var params: Dictionary = DataManager.get_balance_param("ai_military.garrison")
	MilitaryLib._evaluate_garrison("qin")
	# 验证：至少一个城池有驻军
	var qin_cities: Array = CityManager.get_faction_city_states("qin")
	var has_garrison: bool = false
	for city in qin_cities:
		if CityManager.get_garrison(city["id"]) > 0:
			has_garrison = true
			break
	assert_true(has_garrison, "有兵力时 AI 应分配驻军")


func test_garrison_respects_capacity() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	GameManager.end_current_turn()  # qin
	# 给大量兵力
	GameManager.add_units("qin", "infantry", 9999)
	MilitaryLib._evaluate_garrison("qin")
	# 验证：驻军 ≤ 容量
	for city in CityManager.get_faction_city_states("qin"):
		var garrison: int = CityManager.get_garrison(city["id"])
		var cap: int = CityManager.get_garrison_capacity(city["id"])
		assert_true(garrison <= cap,
			"驻军(%d)不应超过容量(%d) - %s" % [garrison, cap, city["id"]])


# ============= 工具函数 =============

func test_hex_distance() -> void:
	assert_eq(MilitaryLib._hex_distance(0, 0, 0, 0), 0, "同点距离为 0")
	assert_eq(MilitaryLib._hex_distance(0, 0, 1, 0), 1, "相邻距离为 1")
	assert_eq(MilitaryLib._hex_distance(0, 0, 2, 0), 2, "距离 2")


func test_weighted_random_pick() -> void:
	# 权重全 0 时应返回第一个
	var result: String = MilitaryLib._weighted_random_pick(["a", "b"], [0, 0])
	assert_eq(result, "a", "权重全 0 应返回第一项")
	# 单项权重
	result = MilitaryLib._weighted_random_pick(["a", "b"], [0, 100])
	assert_eq(result, "b", "单项权重应返回该项")
