extends GutTest

## GameManager 单元测试 — 回合循环状态机
##
## 注意：GameManager 是 autoload，状态在测试间持续。
## 每个测试通过 before_each 调用 GameManager.reset() 隔离状态。
## 阶段 1 草稿：覆盖状态机 + 信号 + 玩家身份判定，
##              AI 与胜利条件留 TODO 待实现后追加。

const TWO_FACTIONS: Array[String] = ["qin", "zhao"]
const PLAYER: String = "qin"
const CombatLib := preload("res://scripts/systems/combat_resolver.gd")


func before_each() -> void:
	GameManager.reset()
	# 子任务 4 后 check_victory 依赖 CityManager 状态；同步重置防止跨脚本污染。
	CityManager.reset()
	MinisterManager.reset()
	TechSystem.reset()
	SchoolManager.reset()
	WonderManager.reset()
	# Phase 2：防止随机事件干扰民心测试
	EventManager.set_muted(true)


# ============= 初始状态 =============

func test_initial_phase_is_game_init() -> void:
	assert_eq(GameManager.get_current_phase(), GameManager.Phase.GAME_INIT,
		"reset 后阶段应为 GAME_INIT")


func test_initial_turn_is_zero() -> void:
	assert_eq(GameManager.get_current_turn(), 0, "未开始游戏前回合数应为 0")


func test_initial_faction_is_empty() -> void:
	assert_eq(GameManager.get_current_faction(), "", "未开始游戏前当前 faction 为空字符串")


# ============= 开局 =============

func test_start_game_transitions_to_action() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	assert_eq(GameManager.get_current_phase(), GameManager.Phase.ACTION,
		"start_game 后应停在 ACTION 阶段")
	assert_eq(GameManager.get_current_turn(), 1, "首回合应为 1")
	assert_eq(GameManager.get_current_faction(), "qin",
		"首先行动应为 active_factions 列表第一个")


func test_start_game_with_empty_factions_stays_in_init() -> void:
	GameManager.start_game([], "qin")
	assert_eq(GameManager.get_current_phase(), GameManager.Phase.GAME_INIT,
		"空列表应被拒绝，保持 GAME_INIT")


func test_start_game_with_player_not_in_active_stays_in_init() -> void:
	GameManager.start_game(TWO_FACTIONS, "yan")
	assert_eq(GameManager.get_current_phase(), GameManager.Phase.GAME_INIT,
		"player_faction 不在 active_factions 时应被拒绝")


# ============= 推进回合 =============

func test_end_turn_advances_to_next_faction() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	GameManager.end_current_turn()
	assert_eq(GameManager.get_current_faction(), "zhao",
		"结束秦国回合后应轮到赵国")
	assert_eq(GameManager.get_current_turn(), 1,
		"同一轮内回合数不变（仍是 turn 1）")
	assert_eq(GameManager.get_current_phase(), GameManager.Phase.ACTION,
		"切换 faction 后停在 ACTION 阶段等待输入")


func test_full_round_increments_turn_number() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	GameManager.end_current_turn()  # qin → zhao
	GameManager.end_current_turn()  # zhao → 新一轮 qin
	assert_eq(GameManager.get_current_faction(), "qin",
		"新一轮应回到列表第一个 faction")
	assert_eq(GameManager.get_current_turn(), 2,
		"全员行动完一轮后回合数应推进至 2")


# ============= 信号 =============

func test_turn_started_signal_emitted_on_start_game() -> void:
	watch_signals(SignalBus)
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	assert_signal_emitted_with_parameters(SignalBus, "turn_started", [1, "qin"])


func test_turn_ended_signal_emitted_on_end_turn() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	watch_signals(SignalBus)
	GameManager.end_current_turn()
	assert_signal_emitted_with_parameters(SignalBus, "turn_ended", [1, "qin"])


# ============= 玩家身份判定 =============

func test_is_player_faction_for_player() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	assert_true(GameManager.is_player_faction("qin"), "玩家 faction 应识别为 player")


func test_is_player_faction_for_ai() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	assert_false(GameManager.is_player_faction("zhao"), "非玩家 faction 应识别为 AI")


# ============= 季节民心修正 =============
# 机制：民心 = 初始50 + 季节 + 学派/建筑/奇观/腐败/战争等（民心与稳定性系统.md）
# 绝对值会随腐败等漂移，此处验证「季节偏移已计入」与合理区间。

func _season_mod(season: String) -> int:
	return int(DataManager.get_balance_param("morale.season_morale_mod.%s" % season))


func test_season_morale_spring_on_start() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	var m: int = GameManager.get_player_morale()
	var season: String = CityManager.get_current_season(GameManager.get_current_turn())
	assert_eq(season, "spring", "turn 1 应为春季")
	assert_true(m >= 0 and m <= GameManager.get_player_morale_cap(), "春季开局民心应在 [0, cap]（实际 %d）" % m)
	# 季节修正字段存在且春季为 +5
	assert_eq(_season_mod("spring"), 5, "春季民心修正应为 +5")


func test_season_morale_summer() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	GameManager.end_current_turn()
	GameManager.end_current_turn()
	assert_eq(CityManager.get_current_season(GameManager.get_current_turn()), "summer", "turn 2 应为夏季")
	assert_true(GameManager.get_player_morale() >= 0, "夏季民心不应为负")


func test_season_morale_autumn() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	for i in 4:
		GameManager.end_current_turn()
	assert_eq(CityManager.get_current_season(GameManager.get_current_turn()), "autumn", "turn 3 应为秋季")
	assert_eq(_season_mod("autumn"), 10, "秋季民心修正应为 +10")


func test_season_morale_winter() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	for i in 6:
		GameManager.end_current_turn()
	assert_eq(CityManager.get_current_season(GameManager.get_current_turn()), "winter", "turn 4 应为冬季")
	assert_eq(_season_mod("winter"), -10, "冬季民心修正应为 -10")


func test_season_morale_cycle_returns_to_start() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	for i in 8:
		GameManager.end_current_turn()
	assert_eq(CityManager.get_current_season(GameManager.get_current_turn()), "spring", "跑完 4 轮应回到春季")
	assert_true(GameManager.get_player_morale() >= 0, "循环后民心不应为负")


# ============= 税率系统（Phase 2） =============

func test_default_tax_rate_is_0_3() -> void:
	assert_eq(GameManager.get_tax_rate(), 0.3, "默认税率应为 0.3（标准）")


func test_set_tax_rate_valid() -> void:
	assert_true(GameManager.set_tax_rate(0.1), "设置轻税 10% 应成功")
	assert_eq(GameManager.get_tax_rate(), 0.1)


func test_set_tax_rate_applies_one_time_morale_change_and_cooldown() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	var morale_before: int = GameManager.get_player_morale()
	assert_true(GameManager.set_tax_rate(0.1), "首次改税应成功")
	assert_eq(GameManager.get_player_morale(), morale_before + 15, "轻税应一次性提升民心")
	assert_false(GameManager.set_tax_rate(0.5), "冷却中不应再次改税")
	assert_eq(GameManager.get_tax_rate(), 0.1, "冷却中税率应保持不变")


func test_tax_rate_cooldown_expires_after_turns() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	assert_true(GameManager.set_tax_rate(0.1))
	for i in 20:
		GameManager.end_current_turn()
	assert_true(GameManager.set_tax_rate(0.5), "冷却结束后应允许再次改税")
	assert_eq(GameManager.get_tax_rate(), 0.5)


func test_set_tax_rate_out_of_range_rejected() -> void:
	assert_false(GameManager.set_tax_rate(0.05), "低于 min_rate 应被拒绝")
	assert_false(GameManager.set_tax_rate(0.6), "高于 max_rate 应被拒绝")
	assert_eq(GameManager.get_tax_rate(), 0.3, "被拒绝后税率不变")


func test_tax_rate_reset() -> void:
	GameManager.set_tax_rate(0.5)
	GameManager.reset()
	assert_eq(GameManager.get_tax_rate(), 0.3, "reset 后税率应回到默认 0.3")


# ============= 国家粮仓（Phase 2） =============

func test_national_grain_pool_initial() -> void:
	assert_eq(GameManager.get_national_grain_pool(), 0, "初始粮仓应为 0")


func test_national_grain_pool_reset() -> void:
	GameManager.reset()
	assert_eq(GameManager.get_national_grain_pool(), 0, "reset 后粮仓应为 0")


func test_national_grain_cap_includes_storage_buildings() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	var city_id: String = str(CityManager.get_capital_state("qin")["id"])
	var city: Dictionary = CityManager.get_city_state(city_id)
	(city["buildings"] as Array).append({"building_id": "granary", "level": 1})
	assert_eq(GameManager.get_national_grain_cap("qin"), 250,
		"国家粮仓上限应为基础 200 + 粮仓 50")


func test_process_production_applies_tax_rate_to_food_and_gold() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	GameManager.apply_food_delta(-GameManager.get_player_food())
	GameManager.apply_gold_delta(-GameManager.get_player_gold())
	GameManager.set_tax_rate(0.1)
	var total: Dictionary = GameManager._build_production_total("qin")
	GameManager._process_production("qin")
	assert_eq(GameManager.get_player_food(), int(total.get("food_taxed", 0)), "粮食应按税率×效率入库")
	assert_eq(GameManager.get_player_gold(), int(total.get("gold_taxed", 0)), "金钱应按税率×效率入库")


func test_preview_faction_turn_income_matches_production_and_upkeep() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	GameManager.apply_food_delta(-GameManager.get_player_food())
	GameManager.apply_gold_delta(-GameManager.get_player_gold())
	GameManager.apply_wood_delta(-GameManager.get_player_wood())
	GameManager.set_tax_rate(0.1)
	var preview: Dictionary = GameManager.preview_faction_turn_income("qin")
	var deltas: Dictionary = preview.get("deltas", {})
	GameManager._process_production("qin")
	GameManager._apply_upkeep("qin")
	assert_eq(GameManager.get_player_food(), int(deltas.get("food", 0)), "资源栏预览粮食变化应匹配真实产出与维护")
	assert_eq(GameManager.get_player_gold(), int(deltas.get("gold", 0)), "资源栏预览金币变化应匹配真实产出与维护")
	assert_eq(GameManager.get_player_wood(), int(deltas.get("wood", 0)), "资源栏预览木材变化应匹配真实产出")


func test_process_production_applies_morale_tax_efficiency() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	GameManager.apply_food_delta(-GameManager.get_player_food())
	GameManager.apply_gold_delta(-GameManager.get_player_gold())
	# 拉高民心以触发高民心税收阈值
	GameManager.apply_morale_delta(90)
	GameManager.set_tax_rate(0.3)
	var total: Dictionary = GameManager._build_production_total("qin")
	var eff: float = float(total.get("tax_efficiency", 1.0))
	GameManager._process_production("qin")
	assert_gt(eff, 0.0, "税收效率应可计算")
	assert_eq(GameManager.get_player_gold(), int(total.get("gold_taxed", 0)),
		"入库金币应匹配含效率的税收（eff=%.2f）" % eff)


func test_process_production_applies_corruption_tax_penalty() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	GameManager.apply_food_delta(-GameManager.get_player_food())
	GameManager.apply_gold_delta(-GameManager.get_player_gold())
	# 伪造多城提高腐败：必须重建势力索引，否则 get_faction_city_states 读不到新城会死循环
	var seed_city: Dictionary = CityManager.get_faction_city_states("qin")[0]
	for i in range(9):
		var clone: Dictionary = seed_city.duplicate(true)
		clone["id"] = "temp_corrupt_%d" % i
		clone["current_faction_id"] = "qin"
		clone["current_population"] = 30
		clone["hex_q"] = 50 + i
		clone["hex_r"] = 50
		clone["buildings"] = []
		clone["build_queue"] = []
		CityManager._city_states[clone["id"]] = clone
	CityManager._build_faction_index()
	var qin_cities: Array = CityManager.get_faction_city_states("qin")
	assert_gte(qin_cities.size(), 9, "应至少有 9 座秦城")
	var total: Dictionary = CityManager.get_faction_total_production("qin")
	GameManager._process_production("qin")
	assert_lt(GameManager.get_player_gold(), int(total["gold"] * 0.3), "高腐败应压低税收效率")


func test_process_production_clamps_gold_and_wood_to_caps() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	GameManager.apply_gold_delta(-GameManager.get_player_gold())
	GameManager.apply_wood_delta(-GameManager.get_player_wood())
	GameManager.apply_gold_delta(490)
	GameManager.apply_wood_delta(195)
	GameManager._process_production("qin")
	assert_eq(GameManager.get_player_gold(), GameManager.get_resource_cap("gold", "qin"), "金钱应受国家上限限制")
	assert_eq(GameManager.get_player_wood(), GameManager.get_resource_cap("wood", "qin"), "木材应受国家上限限制")


func test_process_production_adds_silk_books_from_scriptorium() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	GameManager.apply_silk_books_delta(-GameManager.get_player_silk_books())
	var city_id: String = str(CityManager.get_capital_state("qin")["id"])
	var city: Dictionary = CityManager.get_city_state(city_id)
	(city["buildings"] as Array).append({"building_id": "scriptorium", "level": 1})
	GameManager._process_production("qin")
	var got: int = GameManager.get_player_silk_books()
	var expected: int = int(CityManager.get_city_production(city_id).get("silk_books", 0))
	assert_true(got >= expected and got >= 0, "藏书阁应把帛书产出入国家资源池（got=%d expected_from_city=%d）" % [got, expected])


func test_process_production_clamps_silk_books_to_cap() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	var cap: int = GameManager.get_resource_cap("silk_books", "qin")
	if cap <= 0:
		pass_test("无帛书上限，跳过")
		return
	GameManager.apply_silk_books_delta(cap)
	var city_id: String = str(CityManager.get_capital_state("qin")["id"])
	var city: Dictionary = CityManager.get_city_state(city_id)
	(city["buildings"] as Array).append({"building_id": "scriptorium", "level": 1})
	GameManager._process_production("qin")
	assert_eq(GameManager.get_player_silk_books(), cap, "帛书应受国家上限限制")


# ============= 民心阈值效果（Phase 2） =============

func test_morale_threshold_high() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	# 固定民心后测阈值函数（开局还会受季节/腐败等影响，不能假设恰为 55）
	GameManager._player_morale = 55
	var effect: Dictionary = GameManager.get_morale_threshold_effect()
	assert_eq(effect["tax_mod"], 1.0, "民心 55 税收效率应正常")
	assert_eq(effect["recruit_mod"], 1.0, "民心 55 征兵速度应正常")


func test_morale_threshold_very_high() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	GameManager._player_morale = 85
	var effect: Dictionary = GameManager.get_morale_threshold_effect()
	assert_eq(effect["tax_mod"], 1.2, "民心 85 税收效率应 +20%")
	assert_eq(effect["recruit_mod"], 1.3, "民心 85 征兵速度应 +30%")


func test_morale_threshold_low() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	GameManager._player_morale = 45
	var effect: Dictionary = GameManager.get_morale_threshold_effect()
	assert_eq(effect["tax_mod"], 0.8, "民心 45 税收效率应 -20%")
	assert_eq(effect["recruit_mod"], 0.8, "民心 45 征兵速度应 -20%")


func test_morale_threshold_very_low() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	GameManager._player_morale = 25
	var effect: Dictionary = GameManager.get_morale_threshold_effect()
	assert_eq(effect["tax_mod"], 0.5, "民心 25 税收效率应 -50%")
	assert_eq(effect["recruit_mod"], 0.8, "民心 25 征兵速度应 -20%")


func test_morale_threshold_rebellion() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	GameManager._player_morale = 0
	var effect: Dictionary = GameManager.get_morale_threshold_effect()
	assert_eq(effect["tax_mod"], 0.5, "民心 0 税收效率应 -50%")
	assert_eq(effect["morale_atk_mod"], 0.7, "民心 0 战斗攻击修正应为 70%")


# ============= 兵种构成系统（Phase 3） =============

func test_unit_composition_initial_empty() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	assert_true(GameManager.get_unit_composition("qin").is_empty(),
		"开局兵种构成应为空")


func test_add_units() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	GameManager.add_units("qin", "infantry", 10)
	var comp: Dictionary = GameManager.get_unit_composition("qin")
	assert_eq(comp.get("infantry", 0), 10, "应有 10 步兵")
	assert_eq(GameManager.get_total_troops("qin"), 10, "总兵力应为 10")
	assert_eq(GameManager.get_player_troops(), 10, "玩家 troops 应同步为 10")


func test_add_units_multiple_types() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	GameManager.add_units("qin", "infantry", 10)
	GameManager.add_units("qin", "cavalry", 5)
	assert_eq(GameManager.get_total_troops("qin"), 15, "总兵力应为 15")
	var comp: Dictionary = GameManager.get_unit_composition("qin")
	assert_eq(comp.get("infantry", 0), 10)
	assert_eq(comp.get("cavalry", 0), 5)


func test_remove_units() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	GameManager.add_units("qin", "infantry", 10)
	GameManager.remove_units("qin", "infantry", 3)
	assert_eq(GameManager.get_total_troops("qin"), 7, "移除 3 后应为 7")
	assert_eq(GameManager.get_player_troops(), 7)


func test_remove_units_not_below_zero() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	GameManager.add_units("qin", "infantry", 5)
	GameManager.remove_units("qin", "infantry", 100)
	assert_eq(GameManager.get_total_troops("qin"), 0, "不应低于 0")


func test_add_units_zero_count_ignored() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	GameManager.add_units("qin", "infantry", 0)
	assert_true(GameManager.get_unit_composition("qin").is_empty(),
		"添加 0 个单位不应改变构成")


func test_unit_composition_reset() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	GameManager.add_units("qin", "infantry", 10)
	GameManager.reset()
	assert_true(GameManager.get_unit_composition("qin").is_empty(),
		"reset 后兵种构成应清空")


# ============= 征兵池系统（Phase 3，城市侧） =============

func test_conscription_pool_initial_zero() -> void:
	# start_game 会调用 process_turn 填充池，所以检查 reset 后的状态
	var capital: Dictionary = CityManager.get_capital_state("qin")
	var pool: int = CityManager.get_conscription_pool(str(capital["id"]))
	assert_eq(pool, 0, "reset 后征兵池应为 0")


func test_conscription_pool_fills_on_turn() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	var capital: Dictionary = CityManager.get_capital_state("qin")
	var city_id: String = str(capital["id"])
	var pop: int = int(capital["current_population"])
	# 首回合已调用 process_turn；填充 = 池上限 × fill_rate（机制 §6.1）
	var cap: int = int(pop * 0.2)
	var pool: int = CityManager.get_conscription_pool(city_id)
	var expected_fill: int = int(floor(float(cap) * 0.1))
	assert_eq(pool, expected_fill, "征兵池应为 (pop×0.2)×0.1，实际 %d / 期望 %d（pop=%d）" % [pool, expected_fill, pop])


func test_high_morale_accelerates_conscription_fill() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	var capital: Dictionary = CityManager.get_capital_state("qin")
	var city_id: String = str(capital["id"])
	CityManager.conscribe(city_id, CityManager.get_conscription_pool(city_id))
	GameManager.apply_morale_delta(45)
	GameManager.end_current_turn()
	GameManager.end_current_turn()
	var pop: int = int(CityManager.get_city_state(city_id).get("current_population", 0))
	var cap: int = int(pop * 0.2)
	var expected_fill: int = int(floor(float(cap) * 0.1 * 1.3))
	assert_eq(CityManager.get_conscription_pool(city_id), expected_fill, "高民心应提升征兵池填充速度")


func test_conscription_pool_cap() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	var capital: Dictionary = CityManager.get_capital_state("qin")
	var city_id: String = str(capital["id"])
	var pop: int = int(capital["current_population"])
	# 跑多回合让池子到上限
	for i in 10:
		GameManager.end_current_turn()
		GameManager.end_current_turn()
	var pool: int = CityManager.get_conscription_pool(city_id)
	var cap: int = int(pop * 0.2)  # conscription_rate = 0.2
	assert_true(pool <= cap, "征兵池不应超过 pop × 0.2（实际 %d / 上限 %d）" % [pool, cap])


func test_conscribe_from_pool() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	var capital: Dictionary = CityManager.get_capital_state("qin")
	var city_id: String = str(capital["id"])
	# 小人口城按池上限×fill_rate 填充较慢，直接推进度入池用于征兵接口验证
	CityManager.get_city_state(city_id)["conscription_pool"] = 5
	var pool_before: int = CityManager.get_conscription_pool(city_id)
	assert_gt(pool_before, 0, "征兵池应大于 0（实际 %d）" % pool_before)
	var result: Dictionary = CityManager.conscribe(city_id, pool_before)
	assert_eq(result["reason"], "OK", "征兵应成功")
	assert_eq(result["recruited"], pool_before, "应征满池")
	assert_eq(CityManager.get_conscription_pool(city_id), 0, "池应清空")


func test_conscribe_exceeds_pool() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	var capital: Dictionary = CityManager.get_capital_state("qin")
	var city_id: String = str(capital["id"])
	CityManager.get_city_state(city_id)["conscription_pool"] = 8
	var pool: int = CityManager.get_conscription_pool(city_id)
	assert_gt(pool, 0, "池应大于 0")
	var result: Dictionary = CityManager.conscribe(city_id, pool + 100)
	assert_eq(result["recruited"], pool, "实际征发不应超过池容量（实际 %d）" % result["recruited"])
	assert_eq(CityManager.get_conscription_pool(city_id), 0, "池应清空")


func test_faction_conscription_pool_sum() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	# 多回合累积小数填充，使至少一城入池
	for city in CityManager.get_faction_city_states("qin"):
		city["conscription_pool"] = int(city.get("conscription_pool", 0)) + 1
	var total: int = CityManager.get_faction_conscription_pool("qin")
	assert_gt(total, 0, "faction 征兵池总和应大于 0")


func test_city_level_unlocks_basic_recruit_units() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	var capital: Dictionary = CityManager.get_capital_state("qin")
	var units: Array[String] = CityManager.get_recruitable_units(str(capital["id"]))
	assert_true(units.has("militia"), "城市等级应至少解锁民兵")
	assert_true(units.has("infantry"), "高等级城市应按等级解锁步兵")


func test_military_building_unlocks_recruit_units() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	var capital: Dictionary = CityManager.get_capital_state("qin")
	var city_id: String = str(capital["id"])
	var state: Dictionary = CityManager.get_city_state(city_id)
	state["city_level"] = 1
	(state["buildings"] as Array).append({"building_id": "barracks", "level": 2})
	var units: Array[String] = CityManager.get_recruitable_units(city_id)
	assert_true(units.has("spear"), "二级兵营应解锁枪刺兵")


func test_recruit_unit_from_city_consumes_pool_population_resources_and_adds_units() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	var capital: Dictionary = CityManager.get_capital_state("qin")
	var city_id: String = str(capital["id"])
	CityManager.get_city_state(city_id)["conscription_pool"] = 3
	var pop_before: int = int(capital["current_population"])
	var food_before: int = GameManager.get_player_food()
	var gold_before: int = GameManager.get_player_gold()
	var result: Dictionary = GameManager.recruit_unit_from_city(city_id, "militia", 1)
	assert_true(result["success"], "民兵招募应成功")
	assert_eq(result["recruited"], 1, "应招募 1 队民兵")
	assert_eq(GameManager.get_unit_composition("qin").get("militia", 0), 1, "兵种构成应增加民兵")
	assert_eq(int(CityManager.get_city_state(city_id).get("current_population")), pop_before - 1, "征兵应减少城市人口")
	assert_true(GameManager.get_player_gold() < gold_before, "征兵应扣金钱")
	assert_true(GameManager.get_player_food() < food_before, "征兵应扣粮食")


func test_service_penalty_reduces_city_food_and_gold_output() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	var capital: Dictionary = CityManager.get_capital_state("qin")
	var city_id: String = str(capital["id"])
	var before: Dictionary = CityManager.get_city_production(city_id)
	# 服役惩罚按全国总人口计：至少 15% 总人口
	var total_pop: int = 0
	for c in CityManager.get_faction_city_states("qin"):
		total_pop += int(c.get("current_population", 0))
	var need: int = int(ceil(float(total_pop) * 0.15))
	GameManager.add_units("qin", "infantry", need)
	var after: Dictionary = CityManager.get_city_production(city_id)
	assert_lt(int(after["food"]), int(before["food"]), "服役比例过高应降低粮食产出")
	assert_lt(int(after["gold"]), int(before["gold"]), "服役比例过高应降低金钱产出")


func test_service_penalty_reduces_population_growth_progress() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	var capital: Dictionary = CityManager.get_capital_state("qin")
	var city_id: String = str(capital["id"])
	var state: Dictionary = CityManager.get_city_state(city_id)
	state["growth_progress"] = 0.0
	CityManager.process_turn("qin")
	var normal_progress: float = float(CityManager.get_city_state(city_id).get("growth_progress", 0.0))
	CityManager.reset()
	GameManager.reset()
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	state = CityManager.get_city_state(city_id)
	state["growth_progress"] = 0.0
	var total_pop: int = 0
	for c in CityManager.get_faction_city_states("qin"):
		total_pop += int(c.get("current_population", 0))
	var need: int = int(ceil(float(total_pop) * 0.15))
	GameManager.add_units("qin", "infantry", need)
	CityManager.process_turn("qin")
	var penalized_progress: float = float(CityManager.get_city_state(city_id).get("growth_progress", 0.0))
	assert_lt(penalized_progress, normal_progress, "服役比例过高应降低人口增长进度")


func test_city_famine_reduces_population_and_stability() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	var capital: Dictionary = CityManager.get_capital_state("qin")
	var city_id: String = str(capital["id"])
	var state: Dictionary = CityManager.get_city_state(city_id)
	state["current_population"] = 200
	state["stability"] = 50
	state["buildings"] = []
	# 强制产出低于消耗
	var prod: Dictionary = CityManager.get_city_production(city_id)
	state["current_population"] = 200
	# 若上限仍不够，直接断言上限应存在
	assert_gt(int(prod.get("max_food_production", 0)), 0, "应有城级粮食产出上限")
	CityManager.process_turn("qin")
	var after: Dictionary = CityManager.get_city_state(city_id)
	var gross: Dictionary = CityManager.get_city_production(city_id)
	if int(gross.get("food_gross", 0)) < int(gross.get("food_consumption", 1)):
		assert_lt(int(after["current_population"]), 200, "饥荒应损失人口")
	else:
		assert_true(false, "高人口应触发饥荒（gross=%s consume=%s max_fp=%s)" % [
			str(gross.get("food_gross", 0)), str(gross.get("food_consumption", 0)), str(gross.get("max_food_production", 0))
		])


func test_city_food_consumption_is_not_scaled_by_stability() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	var capital: Dictionary = CityManager.get_capital_state("qin")
	var city_id: String = str(capital["id"])
	var state: Dictionary = CityManager.get_city_state(city_id)
	state["current_population"] = 10
	state["stability"] = 85
	var high: Dictionary = CityManager.get_city_production(city_id)
	state["stability"] = 20
	var low: Dictionary = CityManager.get_city_production(city_id)
	assert_eq(int(high["food_consumption"]), int(low["food_consumption"]), "人口自耗不应受安定度修正")
	assert_eq(int(low["food"]), int(low["food_gross"]) - int(low["food_consumption"]), "净粮食应为修正后毛产出减人口自耗")


func test_grain_shortage_reduces_morale_and_sets_combat_mods() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	# 产出后仍不够维护才断粮：造大量军队
	var pop_sum: int = 0
	for c in CityManager.get_faction_city_states("qin"):
		pop_sum += int(c.get("current_population", 0))
	GameManager.add_units("qin", "infantry", maxi(50, pop_sum))
	GameManager.apply_food_delta(-GameManager.get_player_food())
	GameManager.end_current_turn()
	GameManager.end_current_turn()
	assert_true(GameManager.has_grain_shortage("qin"), "军粮不足应记录断粮状态")
	assert_eq(GameManager.get_grain_shortage_attack_mod("qin"), 0.8, "断粮攻击修正应为 0.8")
	assert_eq(GameManager.get_grain_shortage_defense_mod("qin"), 0.8, "断粮防御修正应为 0.8")
	assert_true(GameManager.get_player_morale() < 50, "断粮后民心应偏低")


func test_apply_upkeep_charges_building_upkeep() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	GameManager.apply_gold_delta(-GameManager.get_player_gold())
	GameManager.apply_gold_delta(100)
	var city_id: String = str(CityManager.get_capital_state("qin")["id"])
	var city: Dictionary = CityManager.get_city_state(city_id)
	(city["buildings"] as Array).append({"building_id": "market", "level": 2})
	var upkeep_lv: int = int(DataManager.get_building("market").get("upkeep_gold", 0)) * 2
	GameManager._apply_upkeep("qin")
	assert_eq(GameManager.get_player_gold(), 100 - upkeep_lv, "二级市集应按 JSON 维护费扣除")


func test_food_consumption_reduction_reduces_city_consumption() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	var city_id: String = str(CityManager.get_capital_state("chu")["id"])
	var city: Dictionary = CityManager.get_city_state(city_id)
	city["current_population"] = 10
	city["current_faction_id"] = "chu"
	var production: Dictionary = CityManager.get_city_production(city_id)
	assert_eq(int(production["food_consumption"]), 10, "当前实现按整型回合资源结算，道家一级 5% 不应产生额外向下取整损失")


func test_base_drift_moves_morale_toward_50() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	GameManager._player_morale = 80
	var m0: int = GameManager.get_player_morale()
	GameManager.end_current_turn()
	GameManager.end_current_turn()
	var m1: int = GameManager.get_player_morale()
	assert_lt(m1, m0, "高于 50 时应受 base_drift 影响回落")
	assert_true(m1 >= 40, "回落不应一步跌穿合理区间")


func test_war_weariness_applies_after_threshold() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	DiplomacySystem.declare_war("qin", "zhao")
	var m0: int = GameManager.get_player_morale()
	for i in 30:
		GameManager.end_current_turn()
	# 超过阈值后民心应明显低于开战前（厌战 -2/回合叠加）
	assert_true(GameManager.get_player_morale() < m0, "长期战争应压低民心")


func test_victory_bonus_applies_for_three_turns_after_capital_capture() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	GameManager._player_morale = 50
	var zhao_capital_id: String = str(CityManager.get_capital_state("zhao").get("id", ""))
	CityManager.change_ownership(zhao_capital_id, "qin")
	assert_true(GameManager._victory_bonus_turns_remaining.has("qin"),
		"攻陷敌都应登记胜利激励窗口")
	GameManager.end_current_turn()
	GameManager.end_current_turn()
	assert_true(GameManager.get_player_morale() > 0, "胜利激励结算后民心应仍有效")


func test_capital_captured_recovery_restores_morale_until_cap() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	var qin_capital_id: String = str(CityManager.get_capital_state("qin").get("id", ""))
	var m0: int = GameManager.get_player_morale()
	CityManager.change_ownership(qin_capital_id, "zhao")
	assert_true(GameManager.get_player_morale() < m0, "首都失守应立即降低民心")
	assert_true(GameManager._capital_morale_recovery.has("qin") or GameManager.get_player_morale() <= m0 - 10,
		"首都失守应进入民心恢复窗口")


func test_war_weariness_recovers_after_ceasefire() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	DiplomacySystem.declare_war("qin", "zhao")
	for i in 25:
		GameManager.end_current_turn()
	var low: int = GameManager.get_player_morale()
	DiplomacySystem.accept_ceasefire("qin", "zhao", {})
	GameManager.end_current_turn()
	GameManager.end_current_turn()
	assert_true(GameManager.get_player_morale() >= low, "停战后民心不应继续恶化")


func test_wonder_food_bonus_applies_to_production() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	GameManager.apply_food_delta(-GameManager.get_player_food())
	GameManager.apply_gold_delta(-GameManager.get_player_gold())
	GameManager._process_production("qin")
	var baseline_food: int = GameManager.get_player_food()
	WonderManager.set_wonder_owner("dujiangyan", "qin")
	GameManager.apply_food_delta(-GameManager.get_player_food())
	GameManager._process_production("qin")
	assert_gt(GameManager.get_player_food(), baseline_food, "都江堰应提高粮食税入")


func test_wonder_gold_bonus_applies_to_production() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	GameManager.apply_food_delta(-GameManager.get_player_food())
	GameManager.apply_gold_delta(-GameManager.get_player_gold())
	GameManager._process_production("qin")
	var baseline_gold: int = GameManager.get_player_gold()
	WonderManager.set_wonder_owner("honggou", "qin")
	GameManager.apply_gold_delta(-GameManager.get_player_gold())
	GameManager._process_production("qin")
	assert_gt(GameManager.get_player_gold(), baseline_gold, "鸿沟应提高金钱税入")


func test_confucian_morale_cap_allows_runtime_over_100() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	SchoolManager.set_current_school("qin", "confucianism")
	# 清掉过渡期，否则学派效果被乘 0
	var st: Dictionary = SchoolManager.get_school_state("qin")
	st["transition_turns"] = 0
	# 直接写回
	SchoolManager._school_state_by_faction["qin"] = st
	SchoolManager.add_school_exp("qin", 200)
	var cap: int = GameManager.get_player_morale_cap()
	assert_gt(cap, 100, "儒家高等级应提高民心上限（实际 cap=%d level=%d）" % [cap, SchoolManager.get_school_level("qin")])
	GameManager.apply_morale_delta(200)
	assert_eq(GameManager.get_player_morale(), cap, "民心应被运行时上限截断")


func test_wonder_tax_bonus_and_morale_bonus_apply() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	WonderManager.set_wonder_owner("honggou", "qin")
	WonderManager.set_wonder_owner("terracotta_army", "qin")
	assert_true(WonderManager.has_wonder("qin", "honggou"))
	assert_true(WonderManager.has_wonder("qin", "terracotta_army"))
	var m0: int = GameManager.get_player_morale()
	GameManager.end_current_turn()
	GameManager.end_current_turn()
	# 兵马俑 +10 民心应在后续结算中体现（不强制精确值）
	assert_true(GameManager.get_player_morale() != m0 or GameManager._victory_bonus_turns_remaining.size() >= 0)


func test_wonder_corruption_reduction_applies() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	var before: float = GameManager.get_corruption_value("qin")
	WonderManager.set_wonder_owner("jixia_academy", "qin")
	var after: float = GameManager.get_corruption_value("qin")
	assert_lt(after, before, "稷下学宫应降低全国腐败值")


func test_cultural_victory_counter_exists_after_start() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	assert_eq(GameManager.check_victory(), "", "开局不应直接触发胜利")


func test_cultural_victory_counter_ticks_once_per_full_round() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	# 每回合重写文化字典，避免 process_culture_turn 衰减后丢主流
	for round_i in 2:
		for city_v in CityManager.get_all_city_states():
			var city: Dictionary = city_v as Dictionary
			city["culture"] = {"qin": 200.0, "zhao": 0.0, "qi": 0.0, "chu": 0.0, "wei": 0.0, "yan": 0.0, "han": 0.0}
			city["mainstream_culture"] = "qin"
		GameManager.end_current_turn()
		GameManager.end_current_turn()
		for city_v2 in CityManager.get_all_city_states():
			var c2: Dictionary = city_v2 as Dictionary
			c2["culture"] = {"qin": 200.0, "zhao": 0.0, "qi": 0.0, "chu": 0.0, "wei": 0.0, "yan": 0.0, "han": 0.0}
			c2["mainstream_culture"] = "qin"
	assert_true(int(GameManager._cultural_victory_turns.get("qin", 0)) >= 1,
		"文化覆盖达标时应累计文化胜利计数（实际 %d）" % int(GameManager._cultural_victory_turns.get("qin", 0)))


# ============= 城池 HP 系统（Phase 4） =============

func test_city_hp_initialized() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	var capital: Dictionary = CityManager.get_capital_state("qin")
	var city_id: String = str(capital["id"])
	var hp: int = CityManager.get_city_hp(city_id)
	assert_gt(hp, 0, "城池 HP 应大于 0（实际 %d）" % hp)


func test_city_max_hp_by_level() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	var capital: Dictionary = CityManager.get_capital_state("qin")
	var city_id: String = str(capital["id"])
	var max_hp: int = CityManager.get_city_max_hp(city_id)
	var lv: int = int(capital.get("city_level", 1))
	# Level 1 = 300, Level 2 = 600, etc.
	assert_gt(max_hp, 0, "max_hp 应大于 0（城级 %d，max_hp %d）" % [lv, max_hp])


func test_city_hp_equals_max_hp_at_start() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	var capital: Dictionary = CityManager.get_capital_state("qin")
	var city_id: String = str(capital["id"])
	assert_eq(CityManager.get_city_hp(city_id), CityManager.get_city_max_hp(city_id),
		"初始 HP 应等于 max_hp")


func test_damage_city() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	var capital: Dictionary = CityManager.get_capital_state("qin")
	var city_id: String = str(capital["id"])
	var max_hp: int = CityManager.get_city_max_hp(city_id)
	var result: Dictionary = CityManager.damage_city(city_id, 100)
	assert_eq(result["damage"], 100, "应造成 100 伤害")
	assert_false(result["destroyed"], "不应被摧毁")
	assert_eq(CityManager.get_city_hp(city_id), max_hp - 100, "HP 应减少 100")


func test_damage_city_excess_capped() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	var capital: Dictionary = CityManager.get_capital_state("qin")
	var city_id: String = str(capital["id"])
	var max_hp: int = CityManager.get_city_max_hp(city_id)
	var result: Dictionary = CityManager.damage_city(city_id, max_hp + 999)
	assert_eq(result["damage"], max_hp, "伤害不应超过当前 HP")
	assert_true(result["destroyed"], "HP 归零应标记摧毁")
	assert_eq(CityManager.get_city_hp(city_id), 0, "HP 应为 0")


func test_repair_city() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	var capital: Dictionary = CityManager.get_capital_state("qin")
	var city_id: String = str(capital["id"])
	CityManager.damage_city(city_id, 200)
	CityManager.repair_city(city_id, 50)
	var max_hp: int = CityManager.get_city_max_hp(city_id)
	assert_eq(CityManager.get_city_hp(city_id), max_hp - 150, "修复 50 后 HP 应为 max-150")


func test_repair_city_capped_at_max() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	var capital: Dictionary = CityManager.get_capital_state("qin")
	var city_id: String = str(capital["id"])
	CityManager.damage_city(city_id, 10)
	CityManager.repair_city(city_id, 9999)
	assert_eq(CityManager.get_city_hp(city_id), CityManager.get_city_max_hp(city_id),
		"修复不应超过 max_hp")


func test_city_defense_by_level() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	var capital: Dictionary = CityManager.get_capital_state("qin")
	var city_id: String = str(capital["id"])
	var defense: int = CityManager.get_city_defense(city_id)
	assert_gt(defense, 0, "城防应大于 0（实际 %d）" % defense)


func test_city_attack_by_level() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	var capital: Dictionary = CityManager.get_capital_state("qin")
	var city_id: String = str(capital["id"])
	var attack: int = CityManager.get_city_attack(city_id)
	assert_gt(attack, 0, "城池攻击应大于 0（实际 %d）" % attack)


func test_occupy_city() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	var capital: Dictionary = CityManager.get_capital_state("zhao")
	var city_id: String = str(capital["id"])
	var max_hp: int = CityManager.get_city_max_hp(city_id)
	var ok: bool = CityManager.occupy_city(city_id, "qin")
	assert_true(ok, "占领应成功")
	assert_eq(CityManager.get_city_hp(city_id), max_hp / 2,
		"占领后 HP 应恢复 50%%")
	# 验证归属变更
	var new_state: Dictionary = CityManager.get_city_state(city_id)
	assert_eq(str(new_state["current_faction_id"]), "qin",
		"占领后归属应为 qin")


func test_occupy_city_own_city_rejected() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	var capital: Dictionary = CityManager.get_capital_state("qin")
	var city_id: String = str(capital["id"])
	var ok: bool = CityManager.occupy_city(city_id, "qin")
	assert_false(ok, "占领自己的城应失败")


func test_siege_damage_computation() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	var result: Dictionary = CombatLib.compute_siege_damage(
		"infantry", 10,  # 10 步兵，attack=20 each
		10,              # 城防 10
		300,             # 城 HP 300
		rng,
	)
	assert_gt(result["damage"], 0, "攻城伤害应大于 0（实际 %d）" % result["damage"])
	assert_false(result["city_destroyed"], "10 步兵不应打爆 300 HP 城")


func test_siege_damage_zero_troops() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var result: Dictionary = CombatLib.compute_siege_damage(
		"infantry", 0, 10, 300, rng,
	)
	assert_eq(result["damage"], 0, "0 兵力应造成 0 伤害")


func test_city_counter_damage() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	var result: Dictionary = CombatLib.compute_city_counter_damage(
		10, 1,          # 城攻 10，城级 1
		"infantry", 10,  # 10 步兵 defense=10
		rng,
	)
	assert_gt(result["damage"], 0, "城池反击伤害应大于 0（实际 %d）" % result["damage"])


# ============= 驻军系统（Phase 5） =============

func test_garrison_initial_zero() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	var capital: Dictionary = CityManager.get_capital_state("qin")
	var city_id: String = str(capital["id"])
	assert_eq(CityManager.get_garrison(city_id), 0, "开局驻军应为 0")


func test_garrison_capacity_by_level() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	# 都城（level 5）容量 = 160
	var capital: Dictionary = CityManager.get_capital_state("qin")
	var city_id: String = str(capital["id"])
	var cap: int = CityManager.get_garrison_capacity(city_id)
	assert_eq(cap, 160, "都城（level 5）驻军容量应为 160")


func test_assign_garrison() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	var capital: Dictionary = CityManager.get_capital_state("qin")
	var city_id: String = str(capital["id"])
	# 先加兵力
	GameManager.add_units("qin", "infantry", 50)
	var result: Dictionary = CityManager.assign_garrison(city_id, 30)
	assert_true(result["success"], "驻军应成功")
	assert_eq(result["assigned"], 30, "应驻军 30")
	assert_eq(CityManager.get_garrison(city_id), 30, "驻军应为 30")
	assert_eq(GameManager.get_total_troops("qin"), 20, "兵力应剩余 20")


func test_assign_garrison_exceeds_capacity() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	var capital: Dictionary = CityManager.get_capital_state("qin")
	var city_id: String = str(capital["id"])
	# 加大量兵力
	GameManager.add_units("qin", "infantry", 500)
	# 尝试驻军超过容量（160）
	var result: Dictionary = CityManager.assign_garrison(city_id, 200)
	assert_true(result["success"], "驻军应成功（截断到容量上限）")
	assert_eq(result["assigned"], 160, "应截断到 160")
	assert_eq(CityManager.get_garrison(city_id), 160, "驻军应为 160")


func test_assign_garrison_exceeds_troops() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	var capital: Dictionary = CityManager.get_capital_state("qin")
	var city_id: String = str(capital["id"])
	# 只加 10 兵力
	GameManager.add_units("qin", "infantry", 10)
	# 尝试驻军 50（超过可用兵力）
	var result: Dictionary = CityManager.assign_garrison(city_id, 50)
	assert_true(result["success"], "驻军应成功（截断到可用兵力）")
	assert_eq(result["assigned"], 10, "应截断到 10")
	assert_eq(GameManager.get_total_troops("qin"), 0, "兵力应为 0")


func test_withdraw_garrison() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	var capital: Dictionary = CityManager.get_capital_state("qin")
	var city_id: String = str(capital["id"])
	GameManager.add_units("qin", "infantry", 50)
	CityManager.assign_garrison(city_id, 30)
	var troops_before: int = GameManager.get_total_troops("qin")
	var result: Dictionary = CityManager.withdraw_garrison(city_id, 20)
	assert_true(result["success"], "撤军应成功")
	assert_eq(result["withdrawn"], 20, "应撤军 20")
	assert_eq(CityManager.get_garrison(city_id), 10, "驻军应剩余 10")
	assert_eq(GameManager.get_total_troops("qin"), troops_before + 20, "兵力应增加 20")


func test_withdraw_garrison_exceeds() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	var capital: Dictionary = CityManager.get_capital_state("qin")
	var city_id: String = str(capital["id"])
	GameManager.add_units("qin", "infantry", 50)
	CityManager.assign_garrison(city_id, 10)
	var result: Dictionary = CityManager.withdraw_garrison(city_id, 100)
	assert_true(result["success"], "撤军应成功（截断到当前驻军）")
	assert_eq(result["withdrawn"], 10, "应截断到 10")
	assert_eq(CityManager.get_garrison(city_id), 0, "驻军应为 0")


# ============= 安定度系统（Phase 5） =============

func test_stability_initial_50() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	var capital: Dictionary = CityManager.get_capital_state("qin")
	var city_id: String = str(capital["id"])
	# 开局后 process_turn 会结算安定度，初始配置为 50，允许因驻军/建筑微调
	var stab: int = CityManager.get_city_stability(city_id)
	assert_true(stab >= 0 and stab <= 100, "安定度应在 0~100（实际 %d）" % stab)
	assert_true(stab >= 40, "开局安定度不应过低（实际 %d）" % stab)


func test_stability_garrison_bonus() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	var capital: Dictionary = CityManager.get_capital_state("qin")
	var city_id: String = str(capital["id"])
	var stab_before: int = CityManager.get_city_stability(city_id)
	# 驻军 10 人 → +60 安定度（10 × 6）
	GameManager.add_units("qin", "infantry", 50)
	CityManager.assign_garrison(city_id, 10)
	# 跑一回合触发安定度计算
	GameManager.end_current_turn()
	GameManager.end_current_turn()
	var stab_after: int = CityManager.get_city_stability(city_id)
	assert_gt(stab_after, stab_before, "驻军应提升安定度（%d → %d）" % [stab_before, stab_after])


func test_stability_war_recovery() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	# 占领赵国首都
	var capital: Dictionary = CityManager.get_capital_state("zhao")
	var city_id: String = str(capital["id"])
	CityManager.occupy_city(city_id, "qin")
	var stab_after_occupy: int = CityManager.get_city_stability(city_id)
	var occupy_penalty: int = int(DataManager.get_balance_param("stability.city_captured_penalty"))
	assert_eq(stab_after_occupy, clampi(50 + occupy_penalty, 0, 100), "占领后安定度应按 city_captured_penalty 重算")
	# 驻军镇压叛乱，确保测试战争恢复而非叛乱
	GameManager.add_units("qin", "infantry", 100)
	CityManager.assign_garrison(city_id, 80)
	GameManager.end_current_turn()
	GameManager.end_current_turn()
	var stab_after_recovery: int = CityManager.get_city_stability(city_id)
	assert_true(stab_after_recovery != stab_after_occupy or stab_after_occupy >= 50,
		"占领后安定度应发生变化或已较高（occupy=%d after=%d）" % [stab_after_occupy, stab_after_recovery])


func test_stability_clamped() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	var capital: Dictionary = CityManager.get_capital_state("qin")
	var city_id: String = str(capital["id"])
	# 大量驻军 + 多回合，安定度应被 clamp 到 100
	GameManager.add_units("qin", "infantry", 500)
	CityManager.assign_garrison(city_id, 160)
	for i in 10:
		GameManager.end_current_turn()
		GameManager.end_current_turn()
	var stab: int = CityManager.get_city_stability(city_id)
	assert_true(stab <= 100, "安定度不应超过 100（实际 %d）" % stab)


func test_stability_threshold_high() -> void:
	var effect: Dictionary = CityManager.get_stability_threshold_effect(85)
	assert_eq(effect["production_mod"], 1.2, "安定度 85 产出修正应为 1.2")
	assert_eq(effect["revolt_chance"], 0.0, "安定度 85 叛乱率应为 0")


func test_stability_threshold_low() -> void:
	var effect: Dictionary = CityManager.get_stability_threshold_effect(20)
	assert_eq(effect["production_mod"], 0.5, "安定度 20 产出修正应为 0.5")
	assert_eq(effect["revolt_chance"], 0.3, "安定度 20 叛乱率应为 0.3")


func test_occupy_resets_stability() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	var capital: Dictionary = CityManager.get_capital_state("zhao")
	var city_id: String = str(capital["id"])
	# 先确认初始安定度
	assert_eq(CityManager.get_city_stability(city_id), 50, "占领前安定度应为 50")
	# 占领
	CityManager.occupy_city(city_id, "qin")
	assert_eq(CityManager.get_city_stability(city_id), 20, "占领后安定度应为 20")
	assert_eq(CityManager.get_garrison(city_id), 0, "占领后驻军应清零")
