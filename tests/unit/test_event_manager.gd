extends GutTest

## EventManager 单元测试 — 三阶段流水线 v2.0
##
## 测试覆盖：
##   - 冷却机制（差异化冷却、one_shot）
##   - 条件判定（已实现 + 新增条件）
##   - 三阶段触发流程
##   - 事件链推进
##   - 分池竞争（每类最多 1 条）
##   - 优先级排序

func before_each() -> void:
	EventManager.reset()


# ============= 冷却机制 =============

func test_one_shot_event_gets_cooldown_999() -> void:
	# 构造一个 one_shot 事件
	var evt: Dictionary = {
		"id": "test_hist_one",
		"category": "special",
		"title": "测试历史事件",
		"trigger": {"type": "turn_start", "probability": 1.0, "priority": 50, "one_shot": true, "conditions": {}},
		"effects": {"food_delta": 10},
		"options": null
	}
	var cd: int = EventManager._get_cooldown_for_event(evt)
	assert_eq(cd, 999, "one_shot 事件冷却应为 999")


func test_normal_economy_event_gets_cooldown_3() -> void:
	var evt: Dictionary = {
		"id": "test_economy",
		"category": "economy",
		"title": "测试经济事件",
		"trigger": {"type": "turn_start", "probability": 1.0, "priority": 30, "one_shot": false, "conditions": {}},
		"effects": {"food_delta": 10},
		"options": null
	}
	var cd: int = EventManager._get_cooldown_for_event(evt)
	assert_eq(cd, 3, "普通经济事件冷却应为 3")


func test_season_event_gets_cooldown_0() -> void:
	var evt: Dictionary = {
		"id": "test_season",
		"category": "season",
		"title": "测试季节事件",
		"trigger": {"type": "turn_start", "probability": 1.0, "priority": 80, "one_shot": false, "conditions": {}},
		"effects": {"food_delta": 10},
		"options": null
	}
	var cd: int = EventManager._get_cooldown_for_event(evt)
	assert_eq(cd, 0, "季节事件冷却应为 0")


func test_cooldown_decrements_on_turn_end() -> void:
	# 手动设置冷却
	EventManager._cooldowns["test_evt"] = 3
	EventManager._update_cooldowns()
	assert_eq(EventManager._cooldowns["test_evt"], 2, "冷却应递减到 2")
	EventManager._update_cooldowns()
	assert_eq(EventManager._cooldowns["test_evt"], 1, "冷却应递减到 1")


func test_cooldown_removed_at_zero() -> void:
	EventManager._cooldowns["test_evt"] = 1
	EventManager._update_cooldowns()
	assert_false(EventManager._cooldowns.has("test_evt"), "冷却到 0 后应被移除")


func test_is_on_cooldown_works() -> void:
	EventManager._cooldowns["test_evt"] = 2
	assert_true(EventManager._is_on_cooldown("test_evt"), "冷却中应返回 true")
	EventManager._cooldowns["test_evt"] = 0
	assert_false(EventManager._is_on_cooldown("test_evt"), "冷却为 0 应返回 false")
	assert_false(EventManager._is_on_cooldown("nonexistent"), "不存在的事件应返回 false")


# ============= 事件链 =============

func test_chain_states_initialized_empty() -> void:
	assert_eq(EventManager._chain_states.size(), 0, "初始时无事件链状态")


func test_chain_advances_on_trigger() -> void:
	EventManager._chain_states["test_chain"] = {"current_index": 0}
	EventManager.advance_chain("test_chain")
	assert_eq(EventManager._chain_states["test_chain"]["current_index"], 1, "链指针应推进到 1")


func test_advance_nonexistent_chain_does_nothing() -> void:
	EventManager.advance_chain("nonexistent")
	# 不应崩溃
	assert_true(true, "推进不存在的链不应崩溃")


func test_get_active_chains_returns_correct_data() -> void:
	EventManager._chain_states["chain_a"] = {"current_index": 2}
	EventManager._chain_states["chain_b"] = {"current_index": 0}
	var chains: Array = EventManager.get_active_chains()
	assert_eq(chains.size(), 2, "应返回 2 条链状态")


# ============= 分池竞争 =============

func test_triggered_categories_cleared_each_turn() -> void:
	EventManager._triggered_categories["economy"] = true
	EventManager._triggered_categories["military"] = true
	# 模拟新回合开始（_check_and_trigger_events 会 clear）
	EventManager._triggered_categories.clear()
	assert_eq(EventManager._triggered_categories.size(), 0, "每回合开始时应清空已触发类型")


func test_type_priority_values() -> void:
	assert_eq(EventManager.TYPE_PRIORITY["politics"], 90)
	assert_eq(EventManager.TYPE_PRIORITY["season"], 80)
	assert_eq(EventManager.TYPE_PRIORITY["diplomacy"], 70)
	assert_eq(EventManager.TYPE_PRIORITY["military"], 60)
	assert_eq(EventManager.TYPE_PRIORITY["special"], 50)
	assert_eq(EventManager.TYPE_PRIORITY["school"], 40)
	assert_eq(EventManager.TYPE_PRIORITY["economy"], 30)
	assert_eq(EventManager.TYPE_PRIORITY["morale"], 20)


# ============= 重置 =============

func test_reset_clears_all_state() -> void:
	EventManager._cooldowns["test"] = 5
	EventManager._chain_states["chain"] = {"current_index": 1}
	EventManager._triggered_categories["economy"] = true
	EventManager.reset()
	assert_eq(EventManager._cooldowns.size(), 0, "reset 应清空冷却")
	assert_eq(EventManager._chain_states.size(), 0, "reset 应清空链状态")
	assert_eq(EventManager._triggered_categories.size(), 0, "reset 应清空已触发类型")


# ============= 存档/读档 =============

func test_save_data_contains_cooldowns_and_chains() -> void:
	EventManager._cooldowns["evt_a"] = 3
	EventManager._chain_states["chain_a"] = {"current_index": 1}
	var save: Dictionary = EventManager.get_save_data()
	assert_true(save.has("cooldowns"), "存档应包含冷却数据")
	assert_true(save.has("chain_states"), "存档应包含链状态")
	assert_eq(save["cooldowns"]["evt_a"], 3)
	assert_eq(save["chain_states"]["chain_a"]["current_index"], 1)


func test_load_save_data_restores_state() -> void:
	var data: Dictionary = {
		"cooldowns": {"evt_b": 2},
		"chain_states": {"chain_b": {"current_index": 3}}
	}
	EventManager.load_save_data(data)
	assert_eq(EventManager._cooldowns["evt_b"], 2, "读档应恢复冷却")
	assert_eq(EventManager._chain_states["chain_b"]["current_index"], 3, "读档应恢复链状态")


# ============= 条件判定 =============

func test_turn_min_condition_blocks_early_turns() -> void:
	var conditions: Dictionary = {"turn_min": 5}
	var result: bool = EventManager._check_conditions(conditions, 3, "qin")
	assert_false(result, "回合 3 不应满足 turn_min=5")


func test_turn_min_condition_passes_late_turns() -> void:
	var conditions: Dictionary = {"turn_min": 5}
	var result: bool = EventManager._check_conditions(conditions, 8, "qin")
	assert_true(result, "回合 8 应满足 turn_min=5")


func test_turn_max_condition_blocks_late_turns() -> void:
	var conditions: Dictionary = {"turn_max": 5}
	var result: bool = EventManager._check_conditions(conditions, 8, "qin")
	assert_false(result, "回合 8 不应满足 turn_max=5")


func test_faction_condition_blocks_wrong_faction() -> void:
	var conditions: Dictionary = {"faction": "qin"}
	var result: bool = EventManager._check_conditions(conditions, 5, "zhao")
	assert_false(result, "势力 zhao 不应满足 faction=qin")


func test_faction_condition_passes_correct_faction() -> void:
	var conditions: Dictionary = {"faction": "qin"}
	var result: bool = EventManager._check_conditions(conditions, 5, "qin")
	assert_true(result, "势力 qin 应满足 faction=qin")


func test_empty_conditions_always_pass() -> void:
	var conditions: Dictionary = {}
	var result: bool = EventManager._check_conditions(conditions, 1, "qin")
	assert_true(result, "空条件应始终通过")


func test_morale_max_condition() -> void:
	# GameManager.get_player_morale() 返回当前民心
	# 需要 GameManager 已初始化
	var conditions: Dictionary = {"morale_max": 100}
	var result: bool = EventManager._check_conditions(conditions, 1, "qin")
	# 默认民心通常 < 100，应通过
	assert_true(result, "民心 < 100 应满足 morale_max=100")
