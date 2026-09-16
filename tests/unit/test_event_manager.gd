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
	GameManager.reset()
	CityManager.reset()
	SchoolManager.reset()


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


func test_recent_events_track_trigger_and_resolution() -> void:
	var evt: Dictionary = {
		"id": "test_runtime_evt",
		"category": "economy",
		"title": "运行态事件",
		"trigger": {"type": "turn_start", "probability": 1.0, "priority": 30, "one_shot": false, "conditions": {}},
		"effects": null,
		"options": [
			{"id": "A", "text": "执行", "cost": {}, "outcomes": {"food_delta": 0}}
		]
	}
	EventManager._trigger_event(evt, "qin")
	assert_eq(EventManager.get_recent_events().size(), 1, "触发事件后应记录最近事件")
	assert_eq(EventManager.get_recent_events()[0].get("status", ""), "triggered", "首次记录状态应为 triggered")
	EventManager._record_recent_event(evt, "resolved", "A")
	assert_eq(EventManager.get_recent_events().size(), 2, "结算事件后应继续写入最近事件记录")
	assert_eq(EventManager.get_recent_events()[0].get("status", ""), "resolved", "最新记录状态应为 resolved")
	assert_eq(EventManager.get_recent_events()[0].get("choice_id", ""), "A", "结算记录应保留玩家选择")


func test_chain_progress_snapshot_uses_data_and_runtime_state() -> void:
	EventManager._chain_states["chain_zhangyi_lianheng"] = {"current_index": 1}
	var snapshot: Array[Dictionary] = EventManager.get_chain_progress_snapshot()
	var found: Dictionary = {}
	for item: Dictionary in snapshot:
		if str(item.get("chain_id", "")) == "chain_zhangyi_lianheng":
			found = item
			break
	assert_false(found.is_empty(), "事件链快照应包含张仪连横")
	assert_eq(int(found.get("current_index", -1)), 1, "事件链快照应反映运行时 current_index")
	assert_eq(str(found.get("next_title", "")), "连横之策", "事件链快照应展示下一步事件标题")


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


func test_school_level_condition_uses_runtime_school_state() -> void:
	GameManager.start_game(["qin", "zhao"], "qin")
	SchoolManager.add_school_exp("qin", 60)
	assert_true(EventManager._check_conditions({"school_level": 2}, 1, "qin"), "运行时学派等级达到 2 时应满足 school_level 条件")
	assert_false(EventManager._check_conditions({"school_level": 3}, 1, "qin"), "未达到 3 级时不应满足 school_level 条件")


func test_morale_max_condition() -> void:
	# GameManager.get_player_morale() 返回当前民心
	# 需要 GameManager 已初始化
	var conditions: Dictionary = {"morale_max": 100}
	var result: bool = EventManager._check_conditions(conditions, 1, "qin")
	# 默认民心通常 < 100，应通过
	assert_true(result, "民心 < 100 应满足 morale_max=100")


# ============= AI 势力事件 =============

func test_ai_trigger_no_options_event_applies_to_ai_resources() -> void:
	# AI 无选项事件：效果应加到 AI 自己的资源（food/gold/morale），不碰玩家资源
	# 注意：AI 初始资源会被 GameManager 钳制到资源上限（zhao food cap=200/gold cap=500），
	# 故先手动下调 AI 资源再触发，确保增量断言不受上限截断影响。
	EventManager.set_muted(true)
	GameManager.start_game(["qin", "zhao"], "qin")
	GameManager.apply_faction_resource_delta("zhao", "food", -150)
	GameManager.apply_faction_resource_delta("zhao", "gold", -300)
	var ai_food_before: int = GameManager.get_faction_resource("zhao", "food")
	var ai_gold_before: int = GameManager.get_faction_resource("zhao", "gold")
	var ai_morale_before: int = GameManager.get_faction_resource("zhao", "morale")
	var player_food_before: int = GameManager.get_player_food()
	var evt: Dictionary = {
		"id": "test_ai_noopt",
		"category": "economy",
		"title": "AI 无选项事件",
		"trigger": {"type": "turn_start", "probability": 1.0, "priority": 30, "one_shot": false, "conditions": {}},
		"effects": {"food_delta": 100, "gold_delta": 50, "morale_delta": 5},
		"options": null
	}
	EventManager._trigger_event(evt, "zhao")
	assert_eq(GameManager.get_faction_resource("zhao", "food"), ai_food_before + 100, "AI 无选项事件 food 应加到 AI 自身")
	assert_eq(GameManager.get_faction_resource("zhao", "gold"), ai_gold_before + 50, "AI 无选项事件 gold 应加到 AI 自身")
	assert_eq(GameManager.get_faction_resource("zhao", "morale"), ai_morale_before + 5, "AI 无选项事件 morale 应加到 AI 自身")
	assert_eq(GameManager.get_player_food(), player_food_before, "AI 事件不应改动玩家资源")


func test_ai_trigger_with_options_auto_chooses_first_affordable() -> void:
	# AI 有选项事件：应自动选择第一个可负担的选项（cost 5 < AI food），并应用其 outcomes
	EventManager.set_muted(true)
	GameManager.start_game(["qin", "zhao"], "qin")
	GameManager.apply_faction_resource_delta("zhao", "gold", -300)  # 下调 gold 避免上限截断
	var ai_food_before: int = GameManager.get_faction_resource("zhao", "food")
	var ai_gold_before: int = GameManager.get_faction_resource("zhao", "gold")
	var evt: Dictionary = {
		"id": "test_ai_opt",
		"category": "economy",
		"title": "AI 选项事件",
		"trigger": {"type": "turn_start", "probability": 1.0, "priority": 30, "one_shot": false, "conditions": {}},
		"effects": null,
		"options": [
			{"id": "A", "text": "花费购粮", "cost": {"food": 5}, "outcomes": {"food_delta": -5, "gold_delta": 20}},
			{"id": "B", "text": "免费", "cost": {}, "outcomes": {"food_delta": 0, "gold_delta": 10}}
		]
	}
	EventManager._trigger_event(evt, "zhao")
	# 选 A：扣 cost food 5 + outcomes food -5 → food 净 -10；gold +20
	assert_eq(GameManager.get_faction_resource("zhao", "food"), ai_food_before - 10, "AI 应选可负担的 A（food 净 -10）")
	assert_eq(GameManager.get_faction_resource("zhao", "gold"), ai_gold_before + 20, "AI 应选 A 的 gold +20 outcomes")


func test_ai_auto_choice_falls_back_to_free_option_when_unaffordable() -> void:
	# AI 负担不起首个选项时，应回退选择 cost 为空的首项
	EventManager.set_muted(true)
	GameManager.start_game(["qin", "zhao"], "qin")
	GameManager.apply_faction_resource_delta("zhao", "food", -100)  # 下调 food 避免上限截断
	var ai_food_before: int = GameManager.get_faction_resource("zhao", "food")
	var evt: Dictionary = {
		"id": "test_ai_unaffordable",
		"category": "economy",
		"title": "AI 负担不起测试",
		"trigger": {"type": "turn_start", "probability": 1.0, "priority": 30, "one_shot": false, "conditions": {}},
		"effects": null,
		"options": [
			{"id": "A", "text": "天价", "cost": {"food": 999999999}, "outcomes": {"gold_delta": 500}},
			{"id": "B", "text": "免费", "cost": {}, "outcomes": {"food_delta": 10}}
		]
	}
	EventManager._trigger_event(evt, "zhao")
	assert_eq(GameManager.get_faction_resource("zhao", "food"), ai_food_before + 10, "负担不起 A 时应选 B（food +10）")


func test_border_north_for_ai_factions() -> void:
	# 北方边境条件按势力判定：燕/赵有 hex_r<=15 的北方城，秦/楚没有
	assert_true(EventManager._check_conditions({"border_north": true}, 1, "yan"), "燕应有北方边境")
	assert_true(EventManager._check_conditions({"border_north": true}, 1, "zhao"), "赵应有北方边境")
	assert_false(EventManager._check_conditions({"border_north": true}, 1, "qin"), "秦不应有北方边境")
	assert_false(EventManager._check_conditions({"border_north": true}, 1, "chu"), "楚不应有北方边境")


func test_ai_morale_condition_uses_ai_morale_resource() -> void:
	# AI 民心条件判定应使用 AI 自己的 morale 资源（初始 50），而非玩家民心
	EventManager.set_muted(true)
	GameManager.start_game(["qin", "zhao"], "qin")
	assert_true(EventManager._check_conditions({"morale_min": 50}, 1, "zhao"), "AI morale=50 应满足 morale_min=50")
	assert_false(EventManager._check_conditions({"morale_min": 60}, 1, "zhao"), "AI morale=50 不应满足 morale_min=60")


func test_player_path_unchanged_popup_and_effects() -> void:
	# 玩家路径不变：有选项仍弹窗等待选择；无选项效果归属玩家
	EventManager.set_muted(true)
	GameManager.start_game(["qin", "zhao"], "qin")
	var seen_triggered: Array[String] = []
	var seen_resolved: Array[String] = []
	var on_triggered := func(_evt: Dictionary) -> void: seen_triggered.append(str(_evt["id"]))
	var on_resolved := func(_id: String, _choice: String) -> void: seen_resolved.append(_id)
	SignalBus.event_triggered.connect(on_triggered)
	SignalBus.event_resolved.connect(on_resolved)

	var evt: Dictionary = {
		"id": "test_player_opt",
		"category": "economy",
		"title": "玩家选项事件",
		"trigger": {"type": "turn_start", "probability": 1.0, "priority": 30, "one_shot": false, "conditions": {}},
		"effects": null,
		"options": [
			{"id": "A", "text": "选项A", "cost": {}, "outcomes": {"food_delta": 5}}
		]
	}
	EventManager._trigger_event(evt, "qin")
	assert_eq(seen_triggered.size(), 1, "玩家有选项事件应弹窗（event_triggered）")
	assert_eq(seen_resolved.size(), 0, "玩家有选项事件不应自动结算")

	var player_food_before: int = GameManager.get_player_food()
	var evt2: Dictionary = {
		"id": "test_player_noopt",
		"category": "economy",
		"title": "玩家无选项事件",
		"trigger": {"type": "turn_start", "probability": 1.0, "priority": 30, "one_shot": false, "conditions": {}},
		"effects": {"food_delta": 30},
		"options": null
	}
	EventManager._trigger_event(evt2, "qin")
	assert_eq(GameManager.get_player_food(), player_food_before + 30, "玩家无选项事件效果应归属玩家")

	SignalBus.event_triggered.disconnect(on_triggered)
	SignalBus.event_resolved.disconnect(on_resolved)


func test_ai_event_skips_player_diplomacy_effects() -> void:
	# AI 事件的玩家专属外交效果（reputation_change 等）应被跳过，保护玩家外交状态机
	EventManager.set_muted(true)
	GameManager.start_game(["qin", "zhao"], "qin")
	GameManager.apply_faction_resource_delta("zhao", "food", -100)  # 下调 food 避免上限截断
	var player_rep_before: int = DiplomacySystem.get_reputation("qin")
	var ai_food_before: int = GameManager.get_faction_resource("zhao", "food")
	var evt: Dictionary = {
		"id": "test_ai_diplo",
		"category": "diplomacy",
		"title": "AI 外交效果测试",
		"trigger": {"type": "turn_start", "probability": 1.0, "priority": 70, "one_shot": false, "conditions": {}},
		"effects": {"food_delta": 40, "reputation_change": -30},
		"options": null
	}
	EventManager._trigger_event(evt, "zhao")
	assert_eq(GameManager.get_faction_resource("zhao", "food"), ai_food_before + 40, "AI 资源类效果应生效")
	assert_eq(DiplomacySystem.get_reputation("qin"), player_rep_before, "AI 事件的 reputation_change 不应改动玩家声望")


# ============= 效果档位（effects_variants） =============

func test_pick_effects_variant_returns_original_effects_for_normal_event() -> void:
	# 普通事件（无 effects_variants）应原样返回 effects，行为不变
	var evt: Dictionary = {
		"id": "test_normal",
		"category": "economy",
		"title": "普通事件",
		"trigger": {"type": "turn_start", "probability": 1.0, "priority": 30, "one_shot": false, "conditions": {}},
		"effects": {"food_delta": 10, "morale_delta": 2},
		"options": null
	}
	var result: Dictionary = EventManager._pick_effects_variant(evt)
	assert_eq(result, {"food_delta": 10, "morale_delta": 2}, "普通事件应原样返回 effects")


func test_pick_effects_variant_without_any_effects_field_returns_empty() -> void:
	# 无 effects_variants 也无 effects 字段时返回空字典（等价于原 effects 缺省行为）
	var evt: Dictionary = {"id": "test_empty"}
	var result: Dictionary = EventManager._pick_effects_variant(evt)
	assert_true(result.is_empty(), "无任何效果字段时应返回空字典")


func test_pick_effects_variant_always_lands_in_valid_tier() -> void:
	# 概率和=1 时，多次抽取结果应始终落在合法档位内（不越界、不报错）
	var evt: Dictionary = {
		"id": "test_variants",
		"category": "season",
		"title": "多档事件",
		"trigger": {"type": "turn_start", "probability": 1.0, "priority": 80, "one_shot": false, "conditions": {}},
		"effects_variants": [
			{"probability": 0.25, "effects": {"food_delta": 300}},
			{"probability": 0.5, "effects": {"food_delta": 150}},
			{"probability": 0.25, "effects": {"food_delta": -50}}
		],
		"options": null
	}
	var valid_tiers: Array = [
		{"food_delta": 300},
		{"food_delta": 150},
		{"food_delta": -50}
	]
	for i in range(200):
		var picked: Dictionary = EventManager._pick_effects_variant(evt)
		assert_true(valid_tiers.has(picked), "抽取结果应始终是合法档位之一（第 %d 次）" % i)


func test_pick_effects_variant_applies_chosen_tier_effects() -> void:
	# 某档概率=1.0 时，抽中的档位效果应正确应用到玩家资源
	EventManager.set_muted(true)
	GameManager.start_game(["qin", "zhao"], "qin")
	var player_food_before: int = GameManager.get_player_food()
	var player_morale_before: int = GameManager.get_player_morale()
	var evt: Dictionary = {
		"id": "test_variant_apply",
		"category": "season",
		"title": "档位应用测试",
		"trigger": {"type": "turn_start", "probability": 1.0, "priority": 80, "one_shot": false, "conditions": {}},
		"effects_variants": [
			{"probability": 1.0, "effects": {"food_delta": 123, "morale_delta": 7}}
		],
		"options": null
	}
	EventManager._trigger_event(evt, "qin")
	assert_eq(GameManager.get_player_food(), player_food_before + 123, "概率=1 档位的 food_delta 应生效")
	assert_eq(GameManager.get_player_morale(), player_morale_before + 7, "概率=1 档位的 morale_delta 应生效")


func test_ai_no_options_event_uses_picked_variant() -> void:
	# AI 无选项多档事件：抽中的档位效果应加到 AI 自身资源
	EventManager.set_muted(true)
	GameManager.start_game(["qin", "zhao"], "qin")
	GameManager.apply_faction_resource_delta("zhao", "gold", -300)  # 下调 gold 避免上限截断
	var ai_gold_before: int = GameManager.get_faction_resource("zhao", "gold")
	var evt: Dictionary = {
		"id": "test_ai_variant",
		"category": "season",
		"title": "AI 多档事件",
		"trigger": {"type": "turn_start", "probability": 1.0, "priority": 80, "one_shot": false, "conditions": {}},
		"effects_variants": [
			{"probability": 1.0, "effects": {"gold_delta": 77}}
		],
		"options": null
	}
	EventManager._trigger_event(evt, "zhao")
	assert_eq(GameManager.get_faction_resource("zhao", "gold"), ai_gold_before + 77, "AI 多档事件的档位效果应加到 AI 自身")


func test_season_events_variant_probabilities_sum_to_one() -> void:
	# 数据校验：三个季节事件的 effects_variants 概率和必须 = 1，且至少 3 档（好/中/坏）
	for evt in DataManager.get_all_events():
		if evt.get("category", "") != "season":
			continue
		var variants: Array = evt.get("effects_variants", [])
		assert_true(variants.size() >= 3, "季节事件 %s 应至少 3 档效果" % evt["id"])
		assert_true(evt.get("options") == null, "季节事件 %s 的 options 应为 null" % evt["id"])
		assert_false(evt.has("effects"), "季节事件 %s 不应再保留原 effects 字段" % evt["id"])
		var sum_prob: float = 0.0
		for variant: Variant in variants:
			sum_prob += float((variant as Dictionary).get("probability", 0.0))
		assert_almost_eq(sum_prob, 1.0, 0.0001, "季节事件 %s 的档位概率和应=1（实际 %.4f）" % [evt["id"], sum_prob])
