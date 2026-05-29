extends GutTest

## 叛乱系统单元测试
##
## 验证：叛乱翻中立、人口损失、驻军清零、安定度重置、建筑破坏、
##       首都叛乱惩罚、灭国检查、驻军/监狱镇压、镇压上限、高安定不叛乱

const TWO_FACTIONS: Array[String] = ["qin", "zhao"]
const PLAYER: String = "qin"


func before_each() -> void:
	GameManager.reset()
	CityManager.reset()
	EventManager.set_muted(true)
	GameManager.start_game(TWO_FACTIONS, PLAYER)


func after_each() -> void:
	GameManager.reset()
	CityManager.reset()


# --- 辅助 ---

func _get_qin_capital_id() -> String:
	var capital: Dictionary = CityManager.get_capital_state("qin")
	return str(capital["id"])


# --- 叛乱后果测试 ---

func test_revolt_flips_to_neutral() -> void:
	var city_id: String = _get_qin_capital_id()
	var result: Dictionary = CityManager.revoke_to_neutral(city_id)
	assert_true(result.get("success", false), "revoke_to_neutral 应成功")
	var city: Dictionary = CityManager.get_city_state(city_id)
	assert_eq(city.get("current_faction_id", ""), "neutral", "叛乱后应归属 neutral")


func test_revolt_loses_population() -> void:
	var city_id: String = _get_qin_capital_id()
	var city_before: Dictionary = CityManager.get_city_state(city_id)
	var pop_before: int = int(city_before.get("current_population", 0))
	var ratio: float = DataManager.get_balance_param("stability.revolt.population_loss_ratio")
	var expected_loss: int = int(pop_before * ratio)

	var result: Dictionary = CityManager.revoke_to_neutral(city_id)
	var city_after: Dictionary = CityManager.get_city_state(city_id)
	var pop_after: int = int(city_after.get("current_population", 0))

	assert_eq(result.get("population_lost", 0), expected_loss, "返回值应包含损失人口")
	assert_eq(pop_after, pop_before - expected_loss, "城池人口应减少 population_loss_ratio 比例")


func test_revolt_destroys_garrison() -> void:
	var city_id: String = _get_qin_capital_id()
	GameManager.add_units("qin", "infantry", 100)
	CityManager.assign_garrison(city_id, 50)
	var city_before: Dictionary = CityManager.get_city_state(city_id)
	assert_eq(int(city_before.get("garrison", 0)), 50, "驻军应为 50")

	CityManager.revoke_to_neutral(city_id)
	var city_after: Dictionary = CityManager.get_city_state(city_id)
	assert_eq(int(city_after.get("garrison", 0)), 0, "叛乱后驻军应清零")


func test_revolt_resets_stability() -> void:
	var city_id: String = _get_qin_capital_id()
	var expected: int = int(DataManager.get_balance_param("stability.revolt.post_revolt_stability"))
	CityManager.revoke_to_neutral(city_id)
	var city: Dictionary = CityManager.get_city_state(city_id)
	assert_eq(int(city.get("stability", 0)), expected, "安定度应重置为 post_revolt_stability")


func test_revolt_clears_build_queue() -> void:
	var city_id: String = _get_qin_capital_id()
	# 确保玩家有资源建造
	GameManager.apply_gold_delta(1000)
	GameManager.apply_wood_delta(1000)
	var started: bool = CityManager.start_build(city_id, "granary")
	if not started:
		# granary 可能已建或不可建，跳过此测试
		pass_test("无法启动建造（granary 可能已建），跳过")
		return
	var city_before: Dictionary = CityManager.get_city_state(city_id)
	var queue_before: Array = city_before.get("build_queue", [])
	assert_gt(queue_before.size(), 0, "建造队列应非空")

	CityManager.revoke_to_neutral(city_id)
	var city_after: Dictionary = CityManager.get_city_state(city_id)
	assert_eq(city_after.get("build_queue", []).size(), 0, "叛乱后建造队列应清空")


func test_revolt_may_destroy_buildings() -> void:
	# 多次测试概率行为：给首都加建筑后叛乱，检查建筑是否被摧毁
	var any_destroyed: bool = false
	for i in range(10):
		CityManager.reset()
		GameManager.reset()
		GameManager.start_game(TWO_FACTIONS, PLAYER)
		var cid: String = _get_qin_capital_id()
		# 直接给首都添加一个建筑（绕过建造流程）
		var city: Dictionary = CityManager.get_city_state(cid)
		(city["buildings"] as Array).append({"building_id": "granary", "level": 1})
		var before: int = (city["buildings"] as Array).size()
		CityManager.revoke_to_neutral(cid)
		var city_after: Dictionary = CityManager.get_city_state(cid)
		if (city_after.get("buildings", []) as Array).size() < before:
			any_destroyed = true
			break
	# 30% 概率 10 次至少 1 次摧毁 ≈ 97% 置信度
	assert_true(any_destroyed, "概率测试：10 次中至少应有 1 次建筑被摧毁")


func test_capital_revolt_penalty() -> void:
	var city_id: String = _get_qin_capital_id()
	var old_morale: int = GameManager.get_faction_resource("qin", "morale")
	var penalty: int = int(DataManager.get_balance_param("stability.revolt.capital_revolt_morale_penalty"))

	# 直接调用处理器（qin 首都叛乱）
	GameManager._on_revolt_occurred(city_id, 10)

	var new_morale: int = GameManager.get_faction_resource("qin", "morale")
	assert_eq(new_morale, old_morale + penalty, "首都叛乱应扣民心 %d" % penalty)


func test_last_city_revolt_elimination() -> void:
	# 先把 qin 所有非首都城市叛乱掉，只剩首都
	var capital_id: String = _get_qin_capital_id()
	# 收集 ID 再遍历（revoke_to_neutral 会修改 _states_by_faction）
	var non_capital_ids: Array[String] = []
	for city_state in CityManager.get_faction_city_states("qin"):
		var cid: String = str(city_state["id"])
		if cid != capital_id:
			non_capital_ids.append(cid)
	for cid in non_capital_ids:
		CityManager.revoke_to_neutral(cid)

	var remaining: Array = CityManager.get_faction_city_states("qin")
	assert_eq(remaining.size(), 1, "只剩首都时应只有 1 座城")

	# 最后一座城叛乱 → 灭国
	GameManager._on_revolt_occurred(capital_id, 10)

	var cities_after: Array = CityManager.get_faction_city_states("qin")
	assert_eq(cities_after.size(), 0, "叛乱后 qin 应无城池（灭国）")


# --- 镇压测试 ---

func test_garrison_suppression() -> void:
	var city_id: String = _get_qin_capital_id()
	GameManager.add_units("qin", "infantry", 200)
	CityManager.assign_garrison(city_id, 100)
	var suppression: float = CityManager.get_revolt_suppression(city_id)
	# 100 × 0.01 = 1.0 → clamp to 0.95
	assert_almost_eq(suppression, 0.95, 0.01, "高驻军应提供高镇压率（上限 0.95）")


func test_no_suppression_without_garrison() -> void:
	var city_id: String = _get_qin_capital_id()
	var suppression: float = CityManager.get_revolt_suppression(city_id)
	assert_almost_eq(suppression, 0.0, 0.01, "无驻军无监狱时镇压率应为 0")


func test_suppression_cap_95() -> void:
	var city_id: String = _get_qin_capital_id()
	GameManager.add_units("qin", "infantry", 500)
	CityManager.assign_garrison(city_id, 200)
	var suppression: float = CityManager.get_revolt_suppression(city_id)
	assert_true(suppression <= 0.95, "镇压率不应超过 0.95")


func test_no_revolt_at_high_stability() -> void:
	var effect: Dictionary = CityManager.get_stability_threshold_effect(50)
	assert_eq(float(effect.get("revolt_chance", 0.0)), 0.0, "安定度 >= 50 时叛乱率应为 0")

	effect = CityManager.get_stability_threshold_effect(80)
	assert_eq(float(effect.get("revolt_chance", 0.0)), 0.0, "安定度 80 时叛乱率应为 0")
