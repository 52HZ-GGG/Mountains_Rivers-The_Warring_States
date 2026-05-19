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
	assert_eq(int(xianyang.get("current_population")), 10, "current_population 初始 = initial_population")


func test_static_fields_preserved() -> void:
	# cities.json 的静态字段必须完整保留
	var xianyang := CityManager.get_city_state("xianyang")
	assert_eq(xianyang.get("name"), "咸阳")
	assert_eq(xianyang.get("faction_id"), "qin")
	assert_true(xianyang.get("is_capital"), "咸阳应为首都")
	assert_eq(int(xianyang.get("max_building_slots")), 5)


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
const PLAYER_INITIAL_WOOD := 2000


func before_each() -> void:
	CityManager.reset()
	GameManager.reset()
	GameManager.apply_gold_delta(PLAYER_INITIAL_GOLD)
	GameManager.apply_wood_delta(PLAYER_INITIAL_WOOD)


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
	# 咸阳 max_building_slots = 5，强制塞 5 个进 buildings
	var xianyang := CityManager.get_city_state("xianyang")
	var buildings: Array = xianyang["buildings"]
	for bid in ["farm", "market", "lumbermill", "barracks", "wall"]:
		buildings.append({"building_id": bid, "level": 1})
	# 再尝试建第 6 个应被拒（不与上述 5 种重名）
	var result := CityManager.can_build("xianyang", "shrine")
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
	GameManager.apply_wood_delta(100)
	var result := CityManager.can_build("xianyang", "farm")
	assert_false(result["allowed"])
	assert_eq(result["reason"], CityManager.REASON_INSUFFICIENT_RESOURCES)


func test_can_build_rejects_insufficient_wood() -> void:
	GameManager.reset()
	GameManager.apply_gold_delta(1000)
	GameManager.apply_wood_delta(10)         # 伐木场要 20 木材
	var result := CityManager.can_build("xianyang", "lumbermill")
	assert_false(result["allowed"])
	assert_eq(result["reason"], CityManager.REASON_INSUFFICIENT_RESOURCES)


# ============= start_build =============

func test_start_build_success_returns_true() -> void:
	var ok := CityManager.start_build("xianyang", "farm")
	assert_true(ok)


func test_start_build_success_deducts_resources() -> void:
	# 伐木场：80 金 + 20 木材
	CityManager.start_build("xianyang", "lumbermill")
	assert_eq(GameManager.get_player_gold(), PLAYER_INITIAL_GOLD - 80)
	assert_eq(GameManager.get_player_wood(), PLAYER_INITIAL_WOOD - 20)


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
	assert_eq(GameManager.get_player_wood(), PLAYER_INITIAL_WOOD, "失败不应扣木材")


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
	# buildings=4 + 1 个已建项的升级正在队列中（占 4 槽，不是 5）
	# 应能再建第 5 个（max=5），证明 _count_new_build_in_queue 排除了升级项
	var xianyang := CityManager.get_city_state("xianyang")
	var buildings: Array = xianyang["buildings"]
	for bid in ["farm", "market", "lumbermill", "barracks"]:
		buildings.append({"building_id": bid, "level": 1})
	CityManager.start_upgrade("xianyang", "farm")  # farm 入升级队列
	var result := CityManager.can_build("xianyang", "shrine")
	assert_true(result["allowed"], "升级中的不应占新槽位，应允许建第 5 个")


# ============= 子任务 4：归属变更 change_ownership =============

func _find_non_capital_qin_city_id() -> String:
	# 任取一座非首都的秦国城市，避免硬编码
	for state in CityManager.get_faction_city_states("qin"):
		if not state.get("is_capital", false):
			return state["id"]
	return ""


func test_change_ownership_updates_current_faction_id() -> void:
	var ok = CityManager.change_ownership("xianyang", "zhao")
	assert_true(ok, "合法 city + 合法 faction 应返回 true")
	var xianyang := CityManager.get_city_state("xianyang")
	assert_eq(xianyang.get("current_faction_id"), "zhao", "current_faction_id 应变为 zhao")


func test_change_ownership_preserves_buildings() -> void:
	# 已建的建筑应随城易主，等级不变
	var xianyang := CityManager.get_city_state("xianyang")
	(xianyang["buildings"] as Array).append({"building_id": "farm", "level": 2})
	(xianyang["buildings"] as Array).append({"building_id": "market", "level": 1})
	CityManager.change_ownership("xianyang", "zhao")
	var buildings: Array = xianyang["buildings"]
	assert_eq(buildings.size(), 2, "占领后已建建筑应保留")
	assert_eq(buildings[0]["level"], 2, "等级应保留")


func test_change_ownership_clears_build_queue_no_refund() -> void:
	# 在建队列应清空，且不退资源给原主
	CityManager.start_build("xianyang", "farm")  # farm: 100 金 1 铁
	var gold_before_occupation := GameManager.get_player_gold()
	CityManager.change_ownership("xianyang", "zhao")
	var xianyang := CityManager.get_city_state("xianyang")
	assert_eq((xianyang["build_queue"] as Array).size(), 0, "占领后 build_queue 应清空")
	assert_eq(GameManager.get_player_gold(), gold_before_occupation, "占领不应退还在建资源给原主")


func test_change_ownership_rebuilds_faction_index() -> void:
	# 占领后，原主索引少 1、新主索引多 1
	var qin_before: int = CityManager.get_faction_city_states("qin").size()
	var zhao_before: int = CityManager.get_faction_city_states("zhao").size()
	CityManager.change_ownership("xianyang", "zhao")
	assert_eq(CityManager.get_faction_city_states("qin").size(), qin_before - 1, "qin 应少 1 城")
	assert_eq(CityManager.get_faction_city_states("zhao").size(), zhao_before + 1, "zhao 应多 1 城")


func test_change_ownership_non_capital_no_capital_lost_signal() -> void:
	# 占领非首都不应触发 capital_lost
	var non_cap_id := _find_non_capital_qin_city_id()
	assert_ne(non_cap_id, "", "应能找到非首都秦城")
	watch_signals(SignalBus)
	CityManager.change_ownership(non_cap_id, "zhao")
	assert_signal_emitted(SignalBus, "city_occupied", "城市占领信号应触发")
	assert_signal_not_emitted(SignalBus, "capital_lost", "占非首都不应触发 capital_lost")


func test_change_ownership_capital_emits_capital_lost() -> void:
	# 占领首都应触发 capital_lost
	watch_signals(SignalBus)
	CityManager.change_ownership("xianyang", "zhao")
	assert_signal_emitted_with_parameters(SignalBus, "capital_lost", ["qin", "xianyang"])


func test_change_ownership_invalid_args_return_false() -> void:
	# 非法 city_id 与非法 faction_id 都应返回 false
	assert_false(CityManager.change_ownership("nonexistent_city", "qin"), "非法 city_id 应返 false")
	assert_false(CityManager.change_ownership("xianyang", "nonexistent_faction"), "非法 faction_id 应返 false")


# ============= 子任务 4：玩家迁都 relocate_player_capital =============

func test_relocate_player_capital_first_time_succeeds() -> void:
	# qin 迁都到 yongcheng：成功 + 计数=1 + 新城 is_capital=true + 旧城 is_capital=false
	var result: Dictionary = CityManager.relocate_player_capital("qin", "yongcheng")
	assert_true(result["success"], "首次迁都应成功")
	assert_eq(result["reason"], CityManager.REASON_OK)
	assert_eq(int(result["remaining_relocations"]), 1, "首次后剩余 1 次")
	assert_eq(CityManager.get_player_relocation_count("qin"), 1, "计数应为 1")
	var yongcheng := CityManager.get_city_state("yongcheng")
	assert_true(yongcheng.get("is_capital"), "新首都 yongcheng 应 is_capital=true")
	var xianyang := CityManager.get_city_state("xianyang")
	assert_false(xianyang.get("is_capital"), "旧首都 xianyang 应 is_capital=false")


func test_relocate_player_capital_second_time_succeeds() -> void:
	# 第二次迁都仍允许：yongcheng → yueyang
	CityManager.relocate_player_capital("qin", "yongcheng")
	var result: Dictionary = CityManager.relocate_player_capital("qin", "yueyang")
	assert_true(result["success"], "第二次迁都应成功")
	assert_eq(int(result["remaining_relocations"]), 0, "第二次后剩余 0 次")
	assert_eq(CityManager.get_player_relocation_count("qin"), 2)


func test_relocate_player_capital_third_time_fails() -> void:
	# 第三次迁都应被拒
	CityManager.relocate_player_capital("qin", "yongcheng")
	CityManager.relocate_player_capital("qin", "yueyang")
	var result: Dictionary = CityManager.relocate_player_capital("qin", "chencang")
	assert_false(result["success"], "第三次迁都应失败")
	assert_eq(result["reason"], CityManager.REASON_RELOCATION_LIMIT)
	# 失败不应增加计数
	assert_eq(CityManager.get_player_relocation_count("qin"), 2, "失败不应增计数")
	# 也不应改 is_capital
	var chencang := CityManager.get_city_state("chencang")
	assert_false(chencang.get("is_capital"), "失败的迁都不应设置新首都")


func test_relocate_player_capital_other_faction_city_fails() -> void:
	# qin 想迁到楚国的 ying，应被拒
	var result: Dictionary = CityManager.relocate_player_capital("qin", "ying")
	assert_false(result["success"])
	assert_eq(result["reason"], CityManager.REASON_NOT_OWN_CITY)


func test_relocate_player_capital_nonexistent_city_fails() -> void:
	var result: Dictionary = CityManager.relocate_player_capital("qin", "nonexistent_city")
	assert_false(result["success"])
	assert_eq(result["reason"], CityManager.REASON_INVALID_CITY)


# ============= 子任务 4：AI 迁都 relocate_ai_capital =============

func test_relocate_ai_capital_picks_highest_population_when_weight_null() -> void:
	# 默认数据中 weight=null。先让 xianyang 失守，再把 yongcheng 人口设为最高。
	CityManager.change_ownership("xianyang", "zhao")
	var yongcheng := CityManager.get_city_state("yongcheng")
	yongcheng["current_population"] = 99999
	var chosen: String = CityManager.relocate_ai_capital("qin")
	assert_eq(chosen, "yongcheng", "weight=null 时应选人口最高城")
	assert_true(yongcheng.get("is_capital"), "新首都 is_capital 应为 true")


func test_relocate_ai_capital_picks_only_remaining_city() -> void:
	# 让 qin 只剩 yongcheng（其余 7 城全送给 zhao）
	var to_capture: Array = []
	for state in CityManager.get_faction_city_states("qin"):
		if state["id"] != "yongcheng":
			to_capture.append(state["id"])
	for city_id in to_capture:
		CityManager.change_ownership(city_id, "zhao")
	assert_eq(CityManager.get_faction_city_states("qin").size(), 1, "qin 应只剩 1 城")
	var chosen: String = CityManager.relocate_ai_capital("qin")
	assert_eq(chosen, "yongcheng", "仅剩 1 城时新首都即为该城")


func test_relocate_ai_capital_uses_weight_when_set() -> void:
	# 接口预留：weight 是 {city_id: priority} 字典，按权重最高选
	CityManager.change_ownership("xianyang", "zhao")
	var qin_faction := DataManager.get_faction("qin")
	var original_weight: Variant = qin_faction.get("ai_capital_relocation_weight")
	qin_faction["ai_capital_relocation_weight"] = {"chencang": 100, "yongcheng": 1}
	var chosen: String = CityManager.relocate_ai_capital("qin")
	# 还原（避免污染其它测试）
	qin_faction["ai_capital_relocation_weight"] = original_weight
	assert_eq(chosen, "chencang", "权重最高的 chencang 应被选为新首都")


# ============= 子任务 4：灭国判定与征服胜利 =============

const ALL_FACTIONS: Array[String] = ["qin", "zhao", "qi", "chu", "wei", "yan", "han"]


func test_is_faction_eliminated_false_when_has_cities() -> void:
	assert_false(CityManager.is_faction_eliminated("qin"), "qin 初始有 8 城应未灭")


func test_is_faction_eliminated_true_when_no_cities() -> void:
	# 把 qin 所有城都送给 zhao
	var qin_ids: Array = []
	for state in CityManager.get_faction_city_states("qin"):
		qin_ids.append(state["id"])
	for cid in qin_ids:
		CityManager.change_ownership(cid, "zhao")
	assert_true(CityManager.is_faction_eliminated("qin"), "qin 0 城应判定为灭国")


func test_check_victory_returns_player_when_all_others_eliminated() -> void:
	# 玩家 qin 把所有非 qin 城（含中立）都吞下
	GameManager.start_game(ALL_FACTIONS, "qin")
	var to_seize: Array = []
	for state in CityManager.get_all_city_states():
		if state["current_faction_id"] != "qin":
			to_seize.append(state["id"])
	for cid in to_seize:
		CityManager.change_ownership(cid, "qin")
	assert_eq(GameManager.check_victory(), "qin", "玩家征服全图应判定玩家胜")


func test_check_victory_returns_ai_when_player_eliminated() -> void:
	# zhao 占领 qin 所有 8 城 → 玩家灭，应返一个仍活着的 AI（不为玩家）
	GameManager.start_game(ALL_FACTIONS, "qin")
	var qin_ids: Array = []
	for state in CityManager.get_faction_city_states("qin"):
		qin_ids.append(state["id"])
	for cid in qin_ids:
		CityManager.change_ownership(cid, "zhao")
	var winner := GameManager.check_victory()
	assert_ne(winner, "", "玩家灭国应触发 check_victory 返回获胜方")
	assert_ne(winner, "qin", "玩家灭国时获胜方不应是玩家自己")
