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

func test_season_morale_spring_on_start() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	# turn 1 = spring，初始民心 50 + 5 = 55
	assert_eq(GameManager.get_player_morale(), 55,
		"春季开局民心应为 55（50 + spring +5）")


func test_season_morale_summer() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	# 跑完一轮到 turn 2 = summer
	GameManager.end_current_turn()  # qin → zhao
	GameManager.end_current_turn()  # zhao → turn 2, summer
	# 55 + summer(-5) = 50
	assert_eq(GameManager.get_player_morale(), 50,
		"夏季民心应为 50（55 + summer -5）")


func test_season_morale_autumn() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	# 跑到 turn 3 = autumn
	for i in 4:
		GameManager.end_current_turn()
	# 50 + autumn(+10) = 60
	assert_eq(GameManager.get_player_morale(), 60,
		"秋季民心应为 60（50 + autumn +10）")


func test_season_morale_winter() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	# 跑到 turn 4 = winter
	for i in 6:
		GameManager.end_current_turn()
	# 60 + winter(-10) = 50
	assert_eq(GameManager.get_player_morale(), 50,
		"冬季民心应为 50（60 + winter -10）")


func test_season_morale_cycle_returns_to_start() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	# 跑完一整年（4 轮 × 2 faction = 8 次 end_turn）
	for i in 8:
		GameManager.end_current_turn()
	# 50 → spring(+5) = 55（新一年春天已应用春季修正）
	assert_eq(GameManager.get_player_morale(), 55,
		"四季循环后回到春天，春季修正 +5 生效，民心应为 55")
	assert_eq(GameManager.get_current_turn(), 5,
		"跑完 4 轮后应回到 turn 5（新一年春天）")


# ============= 税率系统（Phase 2） =============

func test_default_tax_rate_is_0_3() -> void:
	assert_eq(GameManager.get_tax_rate(), 0.3, "默认税率应为 0.3（标准）")


func test_set_tax_rate_valid() -> void:
	assert_true(GameManager.set_tax_rate(0.1), "设置轻税 10% 应成功")
	assert_eq(GameManager.get_tax_rate(), 0.1)
	assert_true(GameManager.set_tax_rate(0.5), "设置苛税 50% 应成功")
	assert_eq(GameManager.get_tax_rate(), 0.5)
	assert_true(GameManager.set_tax_rate(0.2), "设置低税 20% 应成功")
	assert_eq(GameManager.get_tax_rate(), 0.2)
	assert_true(GameManager.set_tax_rate(0.4), "设置重税 40% 应成功")
	assert_eq(GameManager.get_tax_rate(), 0.4)


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


# ============= 民心阈值效果（Phase 2） =============

func test_morale_threshold_high() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	# 初始民心 50 + spring +5 = 55 → 40-59 区间（民心低落）
	var effect: Dictionary = GameManager.get_morale_threshold_effect()
	assert_eq(effect["production_mod"], 0.9, "民心 55 应为产出 -10%（40-59 区间）")


func test_morale_threshold_very_high() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	# 强制设高民心
	for i in 6:
		GameManager.apply_morale_delta(5)  # 55 + 30 = 85
	var effect: Dictionary = GameManager.get_morale_threshold_effect()
	assert_eq(effect["production_mod"], 1.1, "民心 85 应为产出 +10%")


func test_morale_threshold_low() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	# 降到 40-59 区间
	GameManager.apply_morale_delta(-10)  # 55 - 10 = 45
	var effect: Dictionary = GameManager.get_morale_threshold_effect()
	assert_eq(effect["production_mod"], 0.9, "民心 45 应为产出 -10%")


func test_morale_threshold_very_low() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	GameManager.apply_morale_delta(-30)  # 55 - 30 = 25
	var effect: Dictionary = GameManager.get_morale_threshold_effect()
	assert_eq(effect["production_mod"], 0.75, "民心 25 应为产出 -25%")


func test_morale_threshold_rebellion() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	GameManager.apply_morale_delta(-55)  # 55 - 55 = 0
	var effect: Dictionary = GameManager.get_morale_threshold_effect()
	assert_eq(effect["production_mod"], 0.5, "民心 0 应为产出 -50%（叛乱风险）")


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
	# 首回合已调用 process_turn，池应已填充
	var pool: int = CityManager.get_conscription_pool(city_id)
	var expected_fill: int = int(pop * 0.1)  # fill_rate = 0.1
	assert_eq(pool, expected_fill, "征兵池应为 pop × 0.1")


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
	# start_game 已调用 process_turn，池已填充
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
	var pool: int = CityManager.get_conscription_pool(city_id)
	assert_gt(pool, 0, "池应大于 0")
	var result: Dictionary = CityManager.conscribe(city_id, pool + 100)
	assert_eq(result["recruited"], pool, "实际征发不应超过池容量（实际 %d）" % result["recruited"])
	assert_eq(CityManager.get_conscription_pool(city_id), 0, "池应清空")


func test_faction_conscription_pool_sum() -> void:
	GameManager.start_game(TWO_FACTIONS, PLAYER)
	# 首回合后各城已填充
	var total: int = CityManager.get_faction_conscription_pool("qin")
	assert_gt(total, 0, "faction 征兵池总和应大于 0")


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
	assert_eq(CityManager.get_city_stability(city_id), 50, "开局安定度应为 50")


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
	assert_eq(stab_after_occupy, 20, "占领后安定度应为 20（50 + (-30)）")
	# 驻军镇压叛乱，确保测试战争恢复而非叛乱
	GameManager.add_units("qin", "infantry", 100)
	CityManager.assign_garrison(city_id, 80)
	# 跑一回合，应恢复 +3
	GameManager.end_current_turn()
	GameManager.end_current_turn()
	var stab_after_recovery: int = CityManager.get_city_stability(city_id)
	assert_gt(stab_after_recovery, stab_after_occupy, "战争恢复应提升安定度（%d → %d）" % [stab_after_occupy, stab_after_recovery])


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
