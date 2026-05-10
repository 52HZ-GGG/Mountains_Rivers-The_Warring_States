extends GutTest

## CityManager 单元测试
##
## 子任务 1（CityManager 骨架与状态初始化）的验证。
## 验证范围：autoload 注册、50 城状态初始化、4 个查询接口。
## 后续子任务（建造/升级/归属/结算）的测试将单独追加。

# ============= 状态初始化 =============

func test_city_states_initialized() -> void:
	# 决策 43：50 城（七国 47 + 中立 3）
	var states := CityManager.get_all_city_states()
	assert_eq(states.size(), 50, "CityManager 启动后应初始化 50 城状态")


func test_runtime_fields_present() -> void:
	# 城市状态字典必须包含 4 个运行时字段
	var xianyang := CityManager.get_city_state("xianyang")
	assert_true(xianyang.has("current_faction_id"), "应有 current_faction_id 字段")
	assert_true(xianyang.has("buildings"), "应有 buildings 字段")
	assert_true(xianyang.has("build_queue"), "应有 build_queue 字段")
	assert_true(xianyang.has("current_population"), "应有 current_population 字段")


func test_runtime_fields_initial_values() -> void:
	# 运行时字段初始值规约
	var xianyang := CityManager.get_city_state("xianyang")
	assert_eq(xianyang.get("current_faction_id"), "qin", "current_faction_id 初始 = faction_id")
	assert_eq(xianyang.get("buildings"), [], "buildings 初始为空数组")
	assert_eq(xianyang.get("build_queue"), [], "build_queue 初始为空数组")
	assert_eq(int(xianyang.get("current_population")), 12000, "current_population 初始 = base_population")


func test_static_fields_preserved() -> void:
	# cities.json 的静态字段必须完整保留
	var xianyang := CityManager.get_city_state("xianyang")
	assert_eq(xianyang.get("name"), "咸阳")
	assert_eq(xianyang.get("faction_id"), "qin")
	assert_true(xianyang.get("is_capital"), "咸阳应为首都")
	assert_eq(int(xianyang.get("max_building_slots")), 6)


# ============= get_city_state =============

func test_get_city_state_invalid_returns_empty() -> void:
	var result := CityManager.get_city_state("nonexistent_city")
	assert_true(result.is_empty(), "未知 city_id 应返回空字典")


# ============= get_faction_city_states =============

func test_get_faction_city_states_qin() -> void:
	# 决策 43：秦国按疆域分配 8 城
	var qin_states := CityManager.get_faction_city_states("qin")
	assert_eq(qin_states.size(), 8, "秦国应有 8 城")


func test_get_faction_city_states_neutral() -> void:
	# 中立城市（洛邑、邢台、定陶）应被识别为合法 faction
	var neutral_states := CityManager.get_faction_city_states("neutral")
	assert_eq(neutral_states.size(), 3, "中立应有 3 城")


func test_get_faction_city_states_invalid_returns_empty() -> void:
	var result := CityManager.get_faction_city_states("nonexistent_faction")
	assert_true(result.is_empty(), "未知 faction_id 应返回空数组")


# ============= get_capital_state =============

func test_get_capital_state_qin() -> void:
	var capital := CityManager.get_capital_state("qin")
	assert_eq(capital.get("id"), "xianyang", "秦国首都应为咸阳")
	assert_true(capital.get("is_capital"), "首都的 is_capital 应为 true")


# ============= get_all_city_states =============

func test_get_all_city_states_count() -> void:
	var all_states := CityManager.get_all_city_states()
	assert_eq(all_states.size(), 50, "全部城市状态应为 50")
