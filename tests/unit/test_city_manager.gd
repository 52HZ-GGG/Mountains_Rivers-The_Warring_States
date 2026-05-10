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


# ============= 子任务 2：建造接口 =============
#
# 测试约定：
# - 每个测试前 before_each 重置 CityManager 和 GameManager
# - 默认给玩家充足资源（足以建任意单座建筑）
# - 限建语义按解读 B（每国限建数）

const PLAYER_INITIAL_GOLD := 10000
const PLAYER_INITIAL_IRON := 2000


func before_each() -> void:
	CityManager.reset()
	GameManager.reset()
	GameManager.apply_gold_delta(PLAYER_INITIAL_GOLD)
	GameManager.apply_iron_delta(PLAYER_INITIAL_IRON)


# ============= can_build：成功路径 =============

func test_can_build_allowed_basic() -> void:
	var result := CityManager.can_build("xianyang", "farm")
	assert_true(result["allowed"], "新城建新建筑应允许")
	assert_eq(result["reason"], CityManager.REASON_OK)


# ============= can_build：失败路径（按校验顺序排列） =============

func test_can_build_rejects_invalid_city() -> void:
	var result := CityManager.can_build("nonexistent", "farm")
	assert_false(result["allowed"])
	assert_eq(result["reason"], CityManager.REASON_INVALID_CITY)


func test_can_build_rejects_invalid_building() -> void:
	var result := CityManager.can_build("xianyang", "nonexistent_building")
	assert_false(result["allowed"])
	assert_eq(result["reason"], CityManager.REASON_INVALID_BUILDING)


func test_can_build_rejects_already_built() -> void:
	var xianyang := CityManager.get_city_state("xianyang")
	(xianyang["buildings"] as Array).append({"building_id": "farm", "level": 1})
	var result := CityManager.can_build("xianyang", "farm")
	assert_false(result["allowed"])
	assert_eq(result["reason"], CityManager.REASON_ALREADY_BUILT)


func test_can_build_rejects_already_queued() -> void:
	# start_build 一次进入队列，再 can_build 同建筑应被拒
	CityManager.start_build("xianyang", "farm")
	var result := CityManager.can_build("xianyang", "farm")
	assert_false(result["allowed"])
	assert_eq(result["reason"], CityManager.REASON_ALREADY_QUEUED)


func test_can_build_rejects_slots_full() -> void:
	# 咸阳 max_building_slots = 6，强制塞 6 个进 buildings
	var xianyang := CityManager.get_city_state("xianyang")
	var buildings: Array = xianyang["buildings"]
	for bid in ["farm", "market", "mine", "barracks", "wall", "shrine"]:
		buildings.append({"building_id": bid, "level": 1})
	# 再尝试建第 7 个应被拒（不与上述 6 种重名）
	var result := CityManager.can_build("xianyang", "academy")
	assert_false(result["allowed"])
	assert_eq(result["reason"], CityManager.REASON_SLOTS_FULL)


func test_can_build_rejects_national_cap_political() -> void:
	# 政治建筑 max_national_count=2，给秦国其它两座城各塞一座祠堂
	var qin_cities := CityManager.get_faction_city_states("qin")
	# 跳过咸阳本身（要测试它），给后两座
	(qin_cities[1]["buildings"] as Array).append({"building_id": "shrine", "level": 1})
	(qin_cities[2]["buildings"] as Array).append({"building_id": "shrine", "level": 1})
	var result := CityManager.can_build("xianyang", "shrine")
	assert_false(result["allowed"])
	assert_eq(result["reason"], CityManager.REASON_NATIONAL_CAP_REACHED)


func test_can_build_rejects_national_cap_palace() -> void:
	# 王宫 max_national_count=1，给秦国其它一座城建一座王宫
	var qin_cities := CityManager.get_faction_city_states("qin")
	(qin_cities[1]["buildings"] as Array).append({"building_id": "palace", "level": 1})
	var result := CityManager.can_build("xianyang", "palace")
	assert_false(result["allowed"])
	assert_eq(result["reason"], CityManager.REASON_NATIONAL_CAP_REACHED)


func test_can_build_rejects_insufficient_gold() -> void:
	GameManager.reset()
	GameManager.apply_gold_delta(50)         # 农田要 100 金
	GameManager.apply_iron_delta(100)
	var result := CityManager.can_build("xianyang", "farm")
	assert_false(result["allowed"])
	assert_eq(result["reason"], CityManager.REASON_INSUFFICIENT_RESOURCES)


func test_can_build_rejects_insufficient_iron() -> void:
	GameManager.reset()
	GameManager.apply_gold_delta(1000)
	GameManager.apply_iron_delta(10)         # 矿场要 20 铁
	var result := CityManager.can_build("xianyang", "mine")
	assert_false(result["allowed"])
	assert_eq(result["reason"], CityManager.REASON_INSUFFICIENT_RESOURCES)


# ============= start_build =============

func test_start_build_success_returns_true() -> void:
	var ok := CityManager.start_build("xianyang", "farm")
	assert_true(ok)


func test_start_build_success_deducts_resources() -> void:
	# 矿场：80 金 + 20 铁
	CityManager.start_build("xianyang", "mine")
	assert_eq(GameManager.get_player_gold(), PLAYER_INITIAL_GOLD - 80)
	assert_eq(GameManager.get_player_iron(), PLAYER_INITIAL_IRON - 20)


func test_start_build_success_adds_to_queue() -> void:
	CityManager.start_build("xianyang", "farm")
	var xianyang := CityManager.get_city_state("xianyang")
	var queue: Array = xianyang["build_queue"]
	assert_eq(queue.size(), 1, "队列应有 1 项")
	assert_eq(queue[0]["building_id"], "farm")
	assert_eq(int(queue[0]["turns_remaining"]), 1, "farm build_turns=1")


func test_start_build_failure_returns_false() -> void:
	var ok := CityManager.start_build("nonexistent_city", "farm")
	assert_false(ok)


func test_start_build_failure_does_not_deduct() -> void:
	CityManager.start_build("xianyang", "nonexistent_building")
	assert_eq(GameManager.get_player_gold(), PLAYER_INITIAL_GOLD, "失败不应扣金")
	assert_eq(GameManager.get_player_iron(), PLAYER_INITIAL_IRON, "失败不应扣铁")


# ============= 子任务 3：升级接口 =============

func test_can_upgrade_allowed_basic() -> void:
	# 给咸阳手动建一座 level 1 农田
	var xianyang := CityManager.get_city_state("xianyang")
	(xianyang["buildings"] as Array).append({"building_id": "farm", "level": 1})
	var result := CityManager.can_upgrade("xianyang", "farm")
	assert_true(result["allowed"], "已建 level 1 应允许升级")
	assert_eq(result["reason"], CityManager.REASON_OK)


func test_can_upgrade_rejects_invalid_city() -> void:
	var result := CityManager.can_upgrade("nonexistent", "farm")
	assert_false(result["allowed"])
	assert_eq(result["reason"], CityManager.REASON_INVALID_CITY)


func test_can_upgrade_rejects_invalid_building() -> void:
	var result := CityManager.can_upgrade("xianyang", "nonexistent_building")
	assert_false(result["allowed"])
	assert_eq(result["reason"], CityManager.REASON_INVALID_BUILDING)


func test_can_upgrade_rejects_not_built() -> void:
	# 咸阳没建过 farm，不能升级
	var result := CityManager.can_upgrade("xianyang", "farm")
	assert_false(result["allowed"])
	assert_eq(result["reason"], CityManager.REASON_BUILDING_NOT_BUILT)


func test_can_upgrade_rejects_already_queued() -> void:
	# 已建 level 1 + 已在升级队列，不能再发起升级
	var xianyang := CityManager.get_city_state("xianyang")
	(xianyang["buildings"] as Array).append({"building_id": "farm", "level": 1})
	CityManager.start_upgrade("xianyang", "farm")
	var result := CityManager.can_upgrade("xianyang", "farm")
	assert_false(result["allowed"])
	assert_eq(result["reason"], CityManager.REASON_ALREADY_QUEUED)


func test_can_upgrade_rejects_max_level() -> void:
	# farm max_level = 3，已是 level 3 不能升
	var xianyang := CityManager.get_city_state("xianyang")
	(xianyang["buildings"] as Array).append({"building_id": "farm", "level": 3})
	var result := CityManager.can_upgrade("xianyang", "farm")
	assert_false(result["allowed"])
	assert_eq(result["reason"], CityManager.REASON_MAX_LEVEL_REACHED)


func test_can_upgrade_rejects_insufficient_resources() -> void:
	# farm 升级 1→2 = 100 × 1.5 = 150 金；给玩家只 100 金
	var xianyang := CityManager.get_city_state("xianyang")
	(xianyang["buildings"] as Array).append({"building_id": "farm", "level": 1})
	GameManager.reset()
	GameManager.apply_gold_delta(100)
	var result := CityManager.can_upgrade("xianyang", "farm")
	assert_false(result["allowed"])
	assert_eq(result["reason"], CityManager.REASON_INSUFFICIENT_RESOURCES)


# ============= start_upgrade =============

func test_start_upgrade_success_returns_true() -> void:
	var xianyang := CityManager.get_city_state("xianyang")
	(xianyang["buildings"] as Array).append({"building_id": "farm", "level": 1})
	var ok := CityManager.start_upgrade("xianyang", "farm")
	assert_true(ok)


func test_start_upgrade_deducts_upgraded_cost() -> void:
	# farm level 1→2: cost_gold = 100 × 1.5 = 150
	var xianyang := CityManager.get_city_state("xianyang")
	(xianyang["buildings"] as Array).append({"building_id": "farm", "level": 1})
	CityManager.start_upgrade("xianyang", "farm")
	assert_eq(GameManager.get_player_gold(), PLAYER_INITIAL_GOLD - 150)


func test_start_upgrade_adds_to_queue() -> void:
	var xianyang := CityManager.get_city_state("xianyang")
	(xianyang["buildings"] as Array).append({"building_id": "farm", "level": 1})
	CityManager.start_upgrade("xianyang", "farm")
	var queue: Array = xianyang["build_queue"]
	assert_eq(queue.size(), 1, "升级应入队")
	assert_eq(queue[0]["building_id"], "farm")


# ============= 拆除 =============

func test_demolish_returns_true_and_removes() -> void:
	var xianyang := CityManager.get_city_state("xianyang")
	(xianyang["buildings"] as Array).append({"building_id": "farm", "level": 1})
	var ok := CityManager.demolish("xianyang", "farm")
	assert_true(ok)
	assert_eq((xianyang["buildings"] as Array).size(), 0, "拆除后 buildings 应为空")


func test_demolish_nonexistent_returns_false() -> void:
	var ok := CityManager.demolish("xianyang", "farm")
	assert_false(ok, "未建过的不能拆")


func test_demolish_clears_pending_upgrade() -> void:
	# 已建 level 1 + 升级中：拆除应同时清掉 buildings 和 build_queue
	var xianyang := CityManager.get_city_state("xianyang")
	(xianyang["buildings"] as Array).append({"building_id": "farm", "level": 1})
	CityManager.start_upgrade("xianyang", "farm")
	CityManager.demolish("xianyang", "farm")
	assert_eq((xianyang["buildings"] as Array).size(), 0, "拆除后 buildings 应为空")
	assert_eq((xianyang["build_queue"] as Array).size(), 0, "拆除后 build_queue 应为空")


# ============= 难度返还 =============

func test_demolish_normal_refunds_half() -> void:
	# normal 难度 ratio=0.5；farm cost_gold=100，应返 50
	GameManager.set_difficulty("normal")
	var xianyang := CityManager.get_city_state("xianyang")
	(xianyang["buildings"] as Array).append({"building_id": "farm", "level": 1})
	var gold_before := GameManager.get_player_gold()
	CityManager.demolish("xianyang", "farm")
	assert_eq(GameManager.get_player_gold(), gold_before + 50, "normal 应返还 50%")


func test_demolish_easy_refunds_three_quarters() -> void:
	# easy 难度 ratio=0.75；farm cost_gold=100，应返 75
	GameManager.set_difficulty("easy")
	var xianyang := CityManager.get_city_state("xianyang")
	(xianyang["buildings"] as Array).append({"building_id": "farm", "level": 1})
	var gold_before := GameManager.get_player_gold()
	CityManager.demolish("xianyang", "farm")
	assert_eq(GameManager.get_player_gold(), gold_before + 75, "easy 应返还 75%")


# ============= can_build 槽位回归（升级中的项不占新槽位） =============

func test_can_build_slots_excludes_upgrades_in_queue() -> void:
	# buildings=5 + 1 个已建项的升级正在队列中（占 5 槽，不是 6）
	# 应能再建第 6 个（max=6），证明 _count_new_build_in_queue 排除了升级项
	var xianyang := CityManager.get_city_state("xianyang")
	var buildings: Array = xianyang["buildings"]
	for bid in ["farm", "market", "mine", "barracks", "wall"]:
		buildings.append({"building_id": bid, "level": 1})
	CityManager.start_upgrade("xianyang", "farm")  # farm 入升级队列
	var result := CityManager.can_build("xianyang", "shrine")
	assert_true(result["allowed"], "升级中的不应占新槽位，应允许建第 6 个")
