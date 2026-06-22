extends Node

## 游戏主循环管理器
##
## 负责回合循环、游戏阶段切换、胜利条件判定。
## 状态机：GAME_INIT → TURN_START → ACTION → TURN_END → (循环) → GAME_OVER
## 阶段 1 草稿：状态机骨架就绪，AI 与胜利条件留 TODO 待 TDD 填充。

# ============= 枚举 =============

## 游戏阶段。每次切换都通过 SignalBus.phase_changed 广播。
enum Phase {
	GAME_INIT,    ## autoload 已就绪、数据加载完，等 start_game
	TURN_START,   ## 回合开始：产出/季节/事件触发（瞬态）
	ACTION,       ## 当前 faction 行动中（玩家等输入 / AI 跑逻辑）
	TURN_END,     ## 回合结束：清理、检查胜利、推进（瞬态）
	GAME_OVER,    ## 胜负已分
}

const FACTION_IDS: Array[String] = ["qin", "zhao", "qi", "chu", "wei", "yan", "han"]

## 回合内子状态：标记当前势力行动阶段
enum TurnState {
	WAITING,
	EXECUTING,
	COMPLETED,
}

# ============= 私有状态 =============

var _phase: Phase = Phase.GAME_INIT
var _turn_state: TurnState = TurnState.WAITING
var _turn_number: int = 0
var _active_factions: Array[String] = []
var _faction_index: int = 0
var _player_faction: String = ""
var _faction_order: Array[String] = []

# 玩家资源状态（阶段1简化：单一资源池）
var _player_food: int = 0
var _player_gold: int = 0
var _player_wood: int = 0
var _player_morale: int = 50
var _player_population: int = 0
var _player_troops: int = 0
var _player_horse: int = 0
var _player_refined_iron: int = 0
var _player_craftsmen: int = 0
var _player_building_materials: int = 0
var _player_silk_books: int = 0

# 兵种构成追踪（Phase 3）: {faction_id: {unit_id: count}}
var _unit_composition: Dictionary = {}

# AI 国家资源追踪（阶段2）
var _faction_resources: Dictionary = {}  # {faction_id: {food, gold, wood, morale, population, troops, horse, refined_iron, craftsmen, building_materials, silk_books}}

# 难度系统（阶段2）
var _difficulty: String = "normal"

# 税率系统（Phase 2）
var _tax_rate: float = 0.3  # 默认标准税率 30%
var _tax_change_cooldown_remaining: int = 0

# 国家粮仓（Phase 2）
var _national_grain_pool: int = 0
var _grain_shortage_factions: Dictionary = {}
var _war_weariness_turns: Dictionary = {}
var _war_weariness_recovery_turns: Dictionary = {}
var _capital_morale_recovery: Dictionary = {}
var _capital_captured_targets: Dictionary = {}
var _captured_capitals_by_faction: Dictionary = {}
var _victory_bonus_turns_remaining: Dictionary = {}
var _cultural_victory_turns: Dictionary = {}

# ============= 生命周期 =============

func _ready() -> void:
	print("[GameManager] 启动 — 阶段 1（回合循环就绪，等 start_game）")
	_log_data_loaded()
	SignalBus.revolt_occurred.connect(_on_revolt_occurred)
	SignalBus.war_declared.connect(_on_war_declared)
	SignalBus.ceasefire_signed.connect(_on_ceasefire_signed)
	SignalBus.capital_lost.connect(_on_capital_lost)
	SignalBus.city_occupied.connect(_on_city_occupied)


func _log_data_loaded() -> void:
	var variant_count := 0
	for fid in FACTION_IDS:
		variant_count += DataManager.get_faction_variants(fid).size()

	print("[GameManager] 数据加载验证: %d 地形 / %d 基础兵种 / %d 国家变体 / %d 城市" % [
		DataManager.get_all_terrains().size(),
		DataManager.get_all_unit_types().size(),
		variant_count,
		DataManager.get_all_cities().size(),
	])

	var map_size: Vector2i = DataManager.get_map_size()
	print("[GameManager] 地图尺寸: %d × %d" % [map_size.x, map_size.y])


# ============= 状态查询 =============

func get_current_phase() -> Phase:
	return _phase


func get_current_turn() -> int:
	return _turn_number


func get_current_faction() -> String:
	var source: Array[String] = _faction_order if not _faction_order.is_empty() else _active_factions
	if source.is_empty():
		return ""
	return source[_faction_index]


func is_player_faction(faction_id: String) -> bool:
	return faction_id == _player_faction


func get_player_faction() -> String:
	return _player_faction


# ============= 税率系统（Phase 2） =============

## 获取当前税率（0.1 ~ 0.5）。
func get_tax_rate() -> float:
	return _tax_rate


## 设置税率。rate 必须在 [tax.min_rate, tax.max_rate] 范围内。
## 返回 true 表示设置成功。
func set_tax_rate(rate: float) -> bool:
	var min_rate: float = float(DataManager.get_balance_param("tax.min_rate"))
	var max_rate: float = float(DataManager.get_balance_param("tax.max_rate"))
	if rate < min_rate or rate > max_rate:
		push_warning("GameManager: 税率 %.2f 超出范围 [%.2f, %.2f]" % [rate, min_rate, max_rate])
		return false
	if is_equal_approx(rate, _tax_rate):
		return true
	if _tax_change_cooldown_remaining > 0:
		push_warning("GameManager: 税率调整冷却中，剩余 %d 回合" % _tax_change_cooldown_remaining)
		return false
	_tax_rate = rate
	var tax_morale: Variant = DataManager.get_balance_param("morale.tax_morale_values")
	if tax_morale is Dictionary:
		var tax_delta: int = int((tax_morale as Dictionary).get(str(rate), 0))
		if tax_delta != 0:
			apply_morale_delta(tax_delta)
	_tax_change_cooldown_remaining = int(DataManager.get_balance_param("morale.tax_change_cooldown"))
	return true


## 获取国家粮仓当前存量。
func get_national_grain_pool() -> int:
	return _national_grain_pool


func get_national_grain_cap(faction_id: String = "") -> int:
	var target_faction: String = faction_id if faction_id != "" else _player_faction
	var cap: int = int(DataManager.get_balance_param("population.national_grain_cap_base"))
	for city in CityManager.get_faction_city_states(target_faction):
		cap += int((city as Dictionary).get("national_grain_cap", 0))
		for building in (city as Dictionary).get("buildings", []):
			var b: Dictionary = building as Dictionary
			var bdata: Dictionary = DataManager.get_building(str(b.get("building_id", "")))
			if bdata.is_empty():
				continue
			var levels: Array = bdata.get("levels", [])
			var level: int = int(b.get("level", 1))
			if level < 1 or level > levels.size():
				continue
			var effects: Dictionary = (levels[level - 1] as Dictionary).get("effects", {})
			cap += int(effects.get("national_grain_cap", 0))
	return cap


func get_resource_cap(resource: String, faction_id: String = "") -> int:
	var target_faction: String = faction_id if faction_id != "" else _player_faction
	match resource:
		"food":
			return get_national_grain_cap(target_faction)
		"gold":
			var gold_cap: int = int(DataManager.get_balance_param("resources.gold_cap_base"))
			gold_cap += _get_total_building_levels(target_faction, "market") * int(DataManager.get_balance_param("resources.gold_cap_per_market_level"))
			return gold_cap
		"wood":
			var wood_cap: int = int(DataManager.get_balance_param("resources.wood_cap_base"))
			wood_cap += _get_total_building_levels(target_faction, "lumbermill") * int(DataManager.get_balance_param("resources.wood_cap_per_lumbermill_level"))
			return wood_cap
		"silk_books":
			var silk_cfg: Dictionary = DataManager.get_balance_param("resources.special_resources.silk_books")
			var silk_cap: int = int(silk_cfg.get("cap_base", 0))
			silk_cap += _get_total_building_levels(target_faction, "scriptorium") * int(silk_cfg.get("cap_per_building_level", 0))
			return silk_cap
	return -1


func has_grain_shortage(faction_id: String) -> bool:
	return bool(_grain_shortage_factions.get(faction_id, false))


func get_grain_shortage_attack_mod(faction_id: String) -> float:
	if not has_grain_shortage(faction_id):
		return 1.0
	return float(DataManager.get_balance_param("population.grain_shortage_atk_mod"))


func get_grain_shortage_defense_mod(faction_id: String) -> float:
	if not has_grain_shortage(faction_id):
		return 1.0
	return float(DataManager.get_balance_param("population.grain_shortage_def_mod"))


func get_service_penalty_effect(faction_id: String) -> Dictionary:
	var total_pop: int = _get_faction_runtime_population(faction_id)
	if total_pop <= 0:
		return {"food_mod": 1.0, "gold_mod": 1.0, "growth_mod": 1.0, "service_ratio": 0.0}
	var active: int = get_faction_active_service_count(faction_id)
	var service_ratio: float = float(active) / float(total_pop)
	var threshold: float = float(DataManager.get_balance_param("population.service_penalty_threshold"))
	if service_ratio <= threshold:
		return {"food_mod": 1.0, "gold_mod": 1.0, "growth_mod": 1.0, "service_ratio": service_ratio}
	var over: float = service_ratio - threshold
	var food_mod: float = 1.0 - over * float(DataManager.get_balance_param("population.service_penalty_food_mod"))
	var gold_mod: float = 1.0 - over * float(DataManager.get_balance_param("population.service_penalty_gold_mod"))
	var growth_mod: float = 1.0 - over * float(DataManager.get_balance_param("population.service_penalty_growth_mod"))
	return {
		"food_mod": maxf(food_mod, 0.0),
		"gold_mod": maxf(gold_mod, 0.0),
		"growth_mod": maxf(growth_mod, 0.0),
		"service_ratio": service_ratio,
	}


func get_faction_active_service_count(faction_id: String) -> int:
	var total: int = get_total_troops(faction_id)
	for city in CityManager.get_faction_city_states(faction_id):
		total += int((city as Dictionary).get("garrison", 0))
	return total


func get_food_consumption_reduction(faction_id: String) -> float:
	var total: float = _get_school_effect_float(faction_id, "food_consumption_reduction")
	total += float(_sum_building_effect(faction_id, "food_consumption_reduction"))
	return maxf(total, 0.0)


func get_recruit_efficiency(faction_id: String, city_id: String = "") -> float:
	var total: float = _get_school_effect_float(faction_id, "recruit_efficiency")
	total += TechSystem.get_recruit_cost_reduction("all")
	var city: Dictionary = CityManager.get_city_state(city_id) if city_id != "" else {}
	if not city.is_empty():
		total += _sum_city_building_effect(city, "recruit_efficiency")
	return clampf(total, 0.0, 0.95)


func get_current_school() -> String:
	return SchoolManager.get_current_school(_player_faction)


func get_player_faction_id() -> String:
	return _player_faction


func get_player_morale_cap() -> int:
	return _get_morale_cap(_player_faction)


func get_corruption_value(faction_id: String) -> float:
	var cities: Array = CityManager.get_faction_city_states(faction_id)
	var city_count: int = cities.size()
	var total_pop: int = _get_faction_runtime_population(faction_id)
	var border_count: int = _get_border_city_count(faction_id, cities)
	var c_cities: float = float(DataManager.get_balance_param("corruption.growth.C_cities"))
	var c_pop: float = float(DataManager.get_balance_param("corruption.growth.C_pop"))
	var c_border: float = float(DataManager.get_balance_param("corruption.growth.C_border"))
	var corruption_base: float = c_cities * log(float(city_count + 1)) / log(2.0)
	corruption_base += c_pop * log(float(total_pop + 1)) / log(2.0)
	corruption_base += c_border * float(border_count)
	var tech_reduction: float = clampf(_get_corruption_tech_reduction(), 0.0, float(DataManager.get_balance_param("corruption.tech_reduction_max")))
	var building_reduction: float = float(_sum_building_effect(faction_id, "corruption_reduction"))
	var minister_reduction: float = MinisterManager.get_faction_corruption_reduction(faction_id)
	var wonder_reduction: float = float(WonderManager.get_effect_float(faction_id, "corruption_reduction_national"))
	return clampf(corruption_base * (1.0 - tech_reduction) - building_reduction - minister_reduction - wonder_reduction, 0.0, 100.0)


func get_corruption_effect(faction_id: String) -> Dictionary:
	var corruption: float = get_corruption_value(faction_id)
	var clean: float = float(DataManager.get_balance_param("corruption.threshold_clean"))
	var normal: float = float(DataManager.get_balance_param("corruption.threshold_normal"))
	var corrupt: float = float(DataManager.get_balance_param("corruption.threshold_corrupt"))
	var tax_mod: float = 0.0
	var morale_delta: int = 0
	if corruption <= clean:
		var ratio: float = (clean - corruption) / maxf(clean, 1.0)
		tax_mod = float(DataManager.get_balance_param("corruption.clean_tax_bonus_max")) * ratio
		morale_delta = int(round(float(DataManager.get_balance_param("corruption.clean_morale_bonus_max")) * ratio))
	elif corruption <= normal:
		pass
	elif corruption <= corrupt:
		tax_mod = -float(DataManager.get_balance_param("corruption.corrupt_tax_penalty_rate")) * (corruption - normal)
		morale_delta = -int(round(float(DataManager.get_balance_param("corruption.corrupt_morale_penalty_rate")) * (corruption - normal)))
	else:
		tax_mod = -float(DataManager.get_balance_param("corruption.corrupt_tax_penalty_rate")) * (corrupt - normal)
		tax_mod -= float(DataManager.get_balance_param("corruption.severe_tax_penalty_rate")) * (corruption - corrupt)
		morale_delta = -int(round(float(DataManager.get_balance_param("corruption.corrupt_morale_penalty_rate")) * (corrupt - normal)))
		morale_delta -= int(round(float(DataManager.get_balance_param("corruption.severe_morale_penalty_rate")) * (corruption - corrupt)))
	return {"corruption": corruption, "tax_mod": tax_mod, "morale_delta": morale_delta}


## 获取当前民心阈值效果。返回 {tax_mod, recruit_mod, morale_atk_mod, description}。
func get_morale_threshold_effect() -> Dictionary:
	var morale: int = _player_morale
	var high: int = int(DataManager.get_balance_param("morale.threshold_high"))
	var mid: int = int(DataManager.get_balance_param("morale.threshold_mid"))
	var low: int = int(DataManager.get_balance_param("morale.threshold_low"))
	var morale_atk_mod: float = 0.7 + 0.3 * (float(morale) / 100.0)
	if morale >= high:
		return {
			"tax_mod": 1.0 + float(DataManager.get_balance_param("morale.high_tax_bonus")),
			"production_mod": 1.0 + float(DataManager.get_balance_param("morale.high_tax_bonus")),
			"recruit_mod": 1.0 + float(DataManager.get_balance_param("morale.high_recruit_bonus")),
			"morale_atk_mod": morale_atk_mod,
			"description": "民心高昂",
		}
	elif morale >= mid:
		return {"tax_mod": 1.0, "production_mod": 1.0, "recruit_mod": 1.0, "morale_atk_mod": morale_atk_mod, "description": "民心正常"}
	elif morale >= low:
		return {
			"tax_mod": 1.0 + float(DataManager.get_balance_param("morale.low_tax_penalty")),
			"production_mod": 1.0 + float(DataManager.get_balance_param("morale.low_tax_penalty")),
			"recruit_mod": 1.0 + float(DataManager.get_balance_param("morale.low_recruit_penalty")),
			"morale_atk_mod": morale_atk_mod,
			"description": "民心低落",
		}
	else:
		return {
			"tax_mod": 1.0 + float(DataManager.get_balance_param("morale.critical_tax_penalty")),
			"production_mod": 1.0 + float(DataManager.get_balance_param("morale.critical_tax_penalty")),
			"recruit_mod": 1.0 + float(DataManager.get_balance_param("morale.low_recruit_penalty")),
			"morale_atk_mod": morale_atk_mod,
			"description": "民心危机",
		}


# ============= 状态转换 =============

## 开始游戏。active_factions 是激活的国家 ID 列表，player_faction 是人类玩家。
## 仅在 GAME_INIT 阶段可调用。
func start_game(active_factions: Array[String], player_faction: String) -> void:
	if _phase != Phase.GAME_INIT:
		push_warning("GameManager: start_game 只能在 GAME_INIT 阶段调用，当前 %s" % Phase.keys()[_phase])
		return
	if active_factions.is_empty():
		push_error("GameManager: active_factions 不能为空")
		return
	if not active_factions.has(player_faction):
		push_error("GameManager: player_faction %s 不在 active_factions 中" % player_faction)
		return

	_active_factions = active_factions.duplicate()
	_player_faction = player_faction
	_faction_index = 0
	_turn_number = 1
	_init_player_resources()
	_init_ai_factions()
	_sort_factions_by_speed()
	DiplomacySystem.initialize(active_factions)
	TechSystem.reset()
	SchoolManager.initialize_factions(active_factions)
	MinisterManager.initialize_factions(active_factions)
	_change_phase(Phase.TURN_START)
	# 首回合：季节民心修正 + 城市结算 + 资源产出 + 军队维护
	_apply_season_morale()
	var first_faction := get_current_faction()
	CityManager.process_turn(first_faction)
	_process_production(first_faction)
	_apply_upkeep(first_faction)
	_process_national_culture_turn()
	SignalBus.turn_started.emit(_turn_number, first_faction)
	_change_phase(Phase.ACTION)


## 结束当前 faction 回合。玩家点「结束回合」或 AI 行动完毕调用。
## 仅在 ACTION 阶段可调用。
func end_current_turn() -> void:
	if _phase != Phase.ACTION:
		push_warning("GameManager: end_current_turn 必须在 ACTION 阶段调用")
		return

	var ending_faction := get_current_faction()
	_change_phase(Phase.TURN_END)
	SignalBus.turn_ended.emit(_turn_number, ending_faction)

	var winner := check_victory()
	if winner != "":
		_change_phase(Phase.GAME_OVER)
		SignalBus.game_over.emit(winner)
		return

	# 切到下一个 faction；轮到队首则推进回合数
	_faction_index += 1
	if _faction_index >= _active_factions.size():
		_faction_index = 0
		_turn_number += 1
		_sort_factions_by_speed()
		_process_national_culture_turn()

	_change_phase(Phase.TURN_START)
	# 新一轮（季节切换）：应用季节民心修正
	if _faction_index == 0:
		_apply_season_morale()
	var new_faction := get_current_faction()
	# 回合开始：城市结算（建造队列+人口）→ 资源产出 → 军队维护
	CityManager.process_turn(new_faction)
	_process_production(new_faction)
	_apply_upkeep(new_faction)
	SignalBus.turn_started.emit(_turn_number, new_faction)
	_change_phase(Phase.ACTION)


## AI 行动入口：外交决策 → 科技研究 → 军事决策（征兵/攻城/驻军）。
func process_ai_turn() -> void:
	var faction_id := get_current_faction()
	# 1. AI外交决策
	DiplomacyAI.evaluate_diplomacy(faction_id, _turn_number)
	# 2. AI科技研究
	_ai_research_tick(faction_id)
	# 3. AI军事决策（征兵/攻城/驻军）
	MilitaryAI.evaluate_military(faction_id)
	end_current_turn()


func _ai_research_tick(faction_id: String) -> void:
	var ai_techs: Dictionary = TechSystem.get_ai_researched_techs(faction_id)
	# 按时代优先，其次按成本从高到低
	var available: Array = []
	for tech in DataManager.get_all_techs():
		var tech_id: String = tech["id"]
		if ai_techs.has(tech_id):
			continue
		var can_research := true
		for prereq in tech.get("prerequisites", []):
			if not ai_techs.has(prereq):
				can_research = false
				break
		if can_research:
			available.append(tech)
	if available.is_empty():
		return
	# 排序：晚期 > 中期 > 早期，同时代按成本降序
	var era_priority := {"late": 3, "mid": 2, "early": 1}
	available.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ea: int = era_priority.get(a.get("era", ""), 0)
		var eb: int = era_priority.get(b.get("era", ""), 0)
		if ea != eb:
			return ea > eb
		return a.get("cost_gold", 0) > b.get("cost_gold", 0)
	)
	TechSystem.start_ai_research(faction_id, available[0]["id"])


# ============= 每回合资源产出 =============

## 预览势力下一次资源结算。用于 UI 展示，公式与 _process_production / _apply_upkeep 保持一致，但不修改状态。
func preview_faction_turn_income(faction_id: String) -> Dictionary:
	var total: Dictionary = _build_production_total(faction_id)
	var upkeep: Dictionary = _preview_upkeep(faction_id)
	var before: Dictionary = get_faction_resources(faction_id).duplicate()
	var after_income: Dictionary = before.duplicate()
	_preview_apply_resource_delta(after_income, faction_id, "food", int(total.get("food_taxed", 0)))
	_preview_apply_resource_delta(after_income, faction_id, "gold", int(total.get("gold_taxed", 0)))
	_preview_apply_resource_delta(after_income, faction_id, "wood", int(total.get("wood", 0)))
	_preview_apply_resource_delta(after_income, faction_id, "horse", int(total.get("horse", 0)))
	_preview_apply_resource_delta(after_income, faction_id, "refined_iron", int(total.get("refined_iron", 0)))
	_preview_apply_resource_delta(after_income, faction_id, "craftsmen", int(total.get("craftsmen", 0)))
	_preview_apply_resource_delta(after_income, faction_id, "building_materials", int(total.get("building_materials", 0)))
	_preview_apply_resource_delta(after_income, faction_id, "silk_books", int(total.get("silk_books", 0)))
	var actual_income: Dictionary = {}
	for income_resource: String in ["food", "gold", "wood", "horse", "refined_iron", "craftsmen", "building_materials", "silk_books"]:
		actual_income[income_resource] = int(after_income.get(income_resource, 0)) - int(before.get(income_resource, 0))
	var caps: Dictionary = {}
	for capped_resource: String in ["food", "gold", "wood", "silk_books"]:
		caps[capped_resource] = get_resource_cap(capped_resource, faction_id)
	var after: Dictionary = after_income.duplicate()
	_preview_apply_resource_delta(after, faction_id, "food", -int(upkeep.get("food", 0)))
	_preview_apply_resource_delta(after, faction_id, "gold", -int(upkeep.get("gold", 0)))
	_preview_apply_resource_delta(after, faction_id, "gold", -int(upkeep.get("building_gold", 0)))
	var deltas: Dictionary = {}
	for resource: String in ["food", "gold", "wood", "horse", "refined_iron", "craftsmen", "building_materials", "silk_books", "population", "troops", "morale"]:
		deltas[resource] = int(after.get(resource, 0)) - int(before.get(resource, 0))
	return {
		"production": total,
		"upkeep": upkeep,
		"deltas": deltas,
		"before": before,
		"after_income": after_income,
		"actual_income": actual_income,
		"caps": caps,
		"after": after,
		"tax_rate": _tax_rate if faction_id == _player_faction else float(DataManager.get_balance_param("tax.default_rate")),
		"tax_efficiency": float(total.get("tax_efficiency", 0.0)),
		"season": CityManager.get_current_season(_turn_number),
	}


func _preview_apply_resource_delta(resources: Dictionary, faction_id: String, resource: String, delta: int) -> void:
	if delta == 0 or not resources.has(resource):
		return
	if resource == "morale":
		resources[resource] = clampi(int(resources[resource]) + delta, 0, _get_morale_cap(faction_id))
	else:
		resources[resource] = max(0, int(resources[resource]) + delta)
	var cap: int = get_resource_cap(resource, faction_id)
	if cap >= 0:
		resources[resource] = mini(int(resources[resource]), cap)


## 计算并应用势力的每回合资源产出（建筑效果 + 季节修正 + 税率修正）。
func _process_production(faction_id: String) -> void:
	var total: Dictionary = _build_production_total(faction_id)
	apply_faction_resource_delta(faction_id, "food", int(total.get("food_taxed", 0)))
	apply_faction_resource_delta(faction_id, "gold", int(total.get("gold_taxed", 0)))
	apply_faction_resource_delta(faction_id, "wood", int(total.get("wood", 0)))
	apply_faction_resource_delta(faction_id, "horse", int(total.get("horse", 0)))
	apply_faction_resource_delta(faction_id, "refined_iron", int(total.get("refined_iron", 0)))
	apply_faction_resource_delta(faction_id, "craftsmen", int(total.get("craftsmen", 0)))
	apply_faction_resource_delta(faction_id, "building_materials", int(total.get("building_materials", 0)))
	apply_faction_resource_delta(faction_id, "silk_books", int(total.get("silk_books", 0)))
	_clamp_faction_resource_caps(faction_id)
	if faction_id == _player_faction:
		_national_grain_pool = _player_food
	SignalBus.resources_produced.emit(faction_id, total)


func _build_production_total(faction_id: String) -> Dictionary:
	var total: Dictionary = CityManager.get_faction_total_production(faction_id)
	_apply_resource_modifier(total, "food")
	_apply_resource_modifier(total, "gold")
	_apply_resource_modifier(total, "wood")
	_apply_resource_modifier(total, "horse")
	_apply_resource_modifier(total, "refined_iron")
	_apply_resource_modifier(total, "craftsmen")
	_apply_resource_modifier(total, "building_materials")
	_apply_resource_modifier(total, "silk_books")
	_apply_wonder_resource_modifier(total, faction_id, "food", "food_production_national")
	_apply_wonder_resource_modifier(total, faction_id, "gold", "gold_production_national")
	_apply_wonder_resource_modifier(total, faction_id, "wood", "wood_production_national")
	total["silk_books"] = int(total.get("silk_books", 0)) + WonderManager.get_effect_int(faction_id, "silk_books_production_national")
	var tax_rate: float = _tax_rate if faction_id == _player_faction else float(DataManager.get_balance_param("tax.default_rate"))
	var tax_efficiency: float = float(DataManager.get_balance_param("tax.current_efficiency"))
	if faction_id == _player_faction:
		var effect: Dictionary = get_morale_threshold_effect()
		tax_efficiency *= float(effect.get("tax_mod", 1.0))
	var corruption_effect: Dictionary = get_corruption_effect(faction_id)
	tax_efficiency *= 1.0 + float(corruption_effect.get("tax_mod", 0.0))
	tax_efficiency *= 1.0 + float(total.get("tax_bonus", 0.0))
	tax_efficiency *= 1.0 + float(WonderManager.get_effect_float(faction_id, "tax_bonus_national"))
	tax_efficiency = maxf(tax_efficiency, 0.0)
	var taxed_food: int = int(total["food"] * tax_rate * tax_efficiency)
	var taxed_gold: int = int(total["gold"] * tax_rate * tax_efficiency)
	total["food_taxed"] = taxed_food
	total["gold_taxed"] = taxed_gold
	total["tax_efficiency"] = tax_efficiency
	total["corruption"] = float(corruption_effect.get("corruption", 0.0))
	return total


func _preview_upkeep(faction_id: String) -> Dictionary:
	var comp: Dictionary = _unit_composition.get(faction_id, {})
	var total_food_upkeep: int = 0
	var total_gold_upkeep: int = 0
	if not comp.is_empty():
		for unit_id in comp:
			var count: int = int(comp[unit_id])
			if count <= 0:
				continue
			var unit_data: Dictionary = DataManager.get_unit_type(unit_id)
			if unit_data.is_empty():
				continue
			total_food_upkeep += count * int(unit_data.get("upkeep_food", 0))
			total_gold_upkeep += count * int(unit_data.get("upkeep_gold", 0))
	else:
		var troops: int = get_faction_resource(faction_id, "troops")
		total_food_upkeep = troops * int(DataManager.get_balance_param("resources.army_upkeep_food_per_unit"))
		total_gold_upkeep = troops * int(DataManager.get_balance_param("resources.army_upkeep_gold_per_unit"))
	var horse: int = get_faction_resource(faction_id, "horse")
	total_food_upkeep += horse * int(DataManager.get_balance_param("resources.horse_upkeep_food_per_unit"))
	return {
		"food": total_food_upkeep,
		"gold": total_gold_upkeep,
		"building_gold": _get_total_building_upkeep(faction_id),
	}


## 扣除军队维护费（粮食 + 金币）。按兵种构成计算，无构成时回退 flat rate。
func _apply_upkeep(faction_id: String) -> void:
	var comp: Dictionary = _unit_composition.get(faction_id, {})
	var total_food_upkeep: int = 0
	var total_gold_upkeep: int = 0
	if not comp.is_empty():
		# 按兵种维护费
		for unit_id in comp:
			var count: int = int(comp[unit_id])
			if count <= 0:
				continue
			var unit_data: Dictionary = DataManager.get_unit_type(unit_id)
			if unit_data.is_empty():
				continue
			total_food_upkeep += count * int(unit_data.get("upkeep_food", 0))
			total_gold_upkeep += count * int(unit_data.get("upkeep_gold", 0))
	else:
		# 回退：flat rate（AI 未建立兵种构成时）
		var troops: int = get_faction_resource(faction_id, "troops")
		var food_per_troop: int = int(DataManager.get_balance_param("resources.army_upkeep_food_per_unit"))
		var gold_per_troop: int = int(DataManager.get_balance_param("resources.army_upkeep_gold_per_unit"))
		total_food_upkeep = troops * food_per_troop
		total_gold_upkeep = troops * gold_per_troop
	# 马匹维护（独立于兵种构成）
	var horse: int = get_faction_resource(faction_id, "horse")
	var food_per_horse: int = int(DataManager.get_balance_param("resources.horse_upkeep_food_per_unit"))
	total_food_upkeep += horse * food_per_horse
	var food_before: int = get_faction_resource(faction_id, "food")
	var has_shortage: bool = total_food_upkeep > 0 and food_before < total_food_upkeep
	_grain_shortage_factions[faction_id] = has_shortage
	if total_food_upkeep > 0:
		apply_faction_resource_delta(faction_id, "food", -total_food_upkeep)
	if total_gold_upkeep > 0:
		apply_faction_resource_delta(faction_id, "gold", -total_gold_upkeep)
	var building_upkeep: int = _get_total_building_upkeep(faction_id)
	if building_upkeep > 0:
		apply_faction_resource_delta(faction_id, "gold", -building_upkeep)
	if has_shortage:
		apply_faction_resource_delta(faction_id, "morale", -int(DataManager.get_balance_param("population.grain_shortage_morale_loss")))
	_clamp_faction_resource_caps(faction_id)


## 季节 + 税率民心修正（每轮一次，国家级）。
## 季节：spring +5 / summer -5 / autumn +10 / winter -10
## 税率：查 morale.tax_morale_values（0.1→+15, 0.2→+5, 0.3→0, 0.4→-10, 0.5→-20）
func _apply_season_morale() -> void:
	if _tax_change_cooldown_remaining > 0:
		_tax_change_cooldown_remaining -= 1
	var morale_delta: int = _get_base_drift_delta(_player_faction)

	# 季节修正
	var season: String = CityManager.get_current_season(_turn_number)
	var mods: Variant = DataManager.get_balance_param("morale.season_morale_mod")
	if mods is Dictionary:
		morale_delta += int((mods as Dictionary).get(season, 0))

	# 科技 / 学派 / 建筑 / 腐败 / 奇观 / 战争带来的全国民心变化
	morale_delta += TechSystem.get_morale_bonus()
	morale_delta += int(round(_get_school_effect_float(_player_faction, "morale_bonus")))
	morale_delta += WonderManager.get_effect_int(_player_faction, "morale_national")
	morale_delta += _get_total_national_building_morale(_player_faction)
	morale_delta += int(get_corruption_effect(_player_faction).get("morale_delta", 0))
	morale_delta += _get_war_weariness_delta(_player_faction)
	morale_delta += _get_victory_bonus_delta(_player_faction)
	morale_delta += _get_capital_recovery_delta(_player_faction)
	if morale_delta != 0:
		apply_morale_delta(morale_delta)


# ============= 胜利条件 =============

## 检查胜利。返回获胜方 faction_id 或空串。
## 规则（子任务 4）：
## - 唯一存活的 faction → 该 faction 获胜（征服胜利）
## - 玩家已被灭（0 城）但仍有多个 AI 存活 → 游戏对玩家结束，返第一个存活 AI 作为获胜方
## - 其它情况 → 返空串（游戏继续）
func check_victory() -> String:
	if _active_factions.is_empty():
		return ""

	var alive: Array[String] = []
	for fid in _active_factions:
		if not CityManager.is_faction_eliminated(fid):
			alive.append(fid)

	if alive.size() == 1:
		return alive[0]

	var cultural_winner: String = _check_cultural_victory()
	if cultural_winner != "":
		return cultural_winner

	if _player_faction != "" and CityManager.is_faction_eliminated(_player_faction):
		return alive[0] if not alive.is_empty() else ""

	return ""


# ============= 叛乱处理 =============

## 叛乱信号处理器：城池翻中立 → 首都叛乱扣民心/AI迁都。
## 灭国检查由 end_current_turn → check_victory 自动处理。
func _on_revolt_occurred(city_id: String, _stability: int) -> void:
	var city: Dictionary = CityManager.get_city_state(city_id)
	var old_faction: String = city.get("current_faction_id", "")
	if old_faction == "" or old_faction == "neutral":
		return

	var result: Dictionary = CityManager.revoke_to_neutral(city_id)
	if not result.get("success", false):
		return

	# 首都叛乱：民心惩罚 + 首都丢失信号 + AI 迁都
	if city.get("is_capital", false):
		var penalty: int = int(DataManager.get_balance_param("stability.revolt.capital_revolt_morale_penalty"))
		apply_faction_resource_delta(old_faction, "morale", penalty)
		SignalBus.capital_lost.emit(old_faction, city_id)
		if old_faction != _player_faction:
			CityManager.relocate_ai_capital(old_faction)


# ============= 资源管理（EventManager 调用） =============

func get_player_morale() -> int:
	return _player_morale


func get_player_food() -> int:
	return _player_food


func get_player_gold() -> int:
	return _player_gold


func get_player_wood() -> int:
	return _player_wood


func get_player_population() -> int:
	return _player_population


func get_player_troops() -> int:
	return _player_troops


func apply_food_delta(delta: int) -> void:
	_player_food = max(0, _player_food + delta)


func apply_gold_delta(delta: int) -> void:
	_player_gold = max(0, _player_gold + delta)


func apply_wood_delta(delta: int) -> void:
	_player_wood = max(0, _player_wood + delta)


func apply_morale_delta(delta: int) -> void:
	_player_morale = clampi(_player_morale + delta, 0, _get_morale_cap(_player_faction))


func apply_population_delta(delta: int) -> void:
	_player_population = max(0, _player_population + delta)


func apply_troops_delta(delta: int) -> void:
	_player_troops = max(0, _player_troops + delta)


# ============= 兵种构成管理（Phase 3） =============

## 获取 faction 的兵种构成。返回 {unit_id: count}。
func get_unit_composition(faction_id: String) -> Dictionary:
	return _unit_composition.get(faction_id, {})


## 给 faction 添加指定兵种。自动同步 _player_troops（玩家侧）。
func add_units(faction_id: String, unit_id: String, count: int) -> void:
	if count <= 0:
		return
	if not _unit_composition.has(faction_id):
		_unit_composition[faction_id] = {}
	var comp: Dictionary = _unit_composition[faction_id]
	comp[unit_id] = int(comp.get(unit_id, 0)) + count
	if faction_id == _player_faction:
		_player_troops = _sum_composition(faction_id)


## 从城市招募指定兵种，统一扣除征兵池、人口与国家资源，并同步兵种构成。
func recruit_unit_from_city(city_id: String, unit_id: String, count: int) -> Dictionary:
	if count <= 0:
		return {"success": false, "reason": "INVALID_AMOUNT", "recruited": 0}
	var city: Dictionary = CityManager.get_city_state(city_id)
	if city.is_empty():
		return {"success": false, "reason": "INVALID_CITY", "recruited": 0}
	if not CityManager.get_recruitable_units(city_id).has(unit_id):
		return {"success": false, "reason": "UNIT_LOCKED", "recruited": 0}
	var faction_id: String = str(city.get("current_faction_id", ""))
	var unit_data: Dictionary = DataManager.get_unit_type(unit_id)
	if unit_data.is_empty():
		return {"success": false, "reason": "INVALID_UNIT", "recruited": 0}
	var pool: int = CityManager.get_conscription_pool(city_id)
	var max_by_pool: int = pool
	var actual: int = mini(count, max_by_pool)
	if actual <= 0:
		return {"success": false, "reason": "POOL_EMPTY", "recruited": 0}
	var reserve: Dictionary = _get_recruit_resource_reserve(faction_id)
	var max_by_resources: int = _get_affordable_unit_count(faction_id, unit_data, actual, reserve)
	actual = mini(actual, max_by_resources)
	if actual <= 0:
		return {"success": false, "reason": "INSUFFICIENT_RESOURCES", "recruited": 0}

	var conscription: Dictionary = CityManager.conscribe(city_id, actual)
	actual = int(conscription.get("recruited", 0))
	if actual <= 0:
		return {"success": false, "reason": str(conscription.get("reason", "POOL_EMPTY")), "recruited": 0}
	_pay_unit_cost(faction_id, city_id, unit_data, actual)
	apply_faction_resource_delta(faction_id, "population", -actual)
	add_units(faction_id, unit_id, actual)
	return {"success": true, "reason": "OK", "recruited": actual}


func _get_affordable_unit_count(faction_id: String, unit_data: Dictionary, desired: int, reserve: Dictionary = {}) -> int:
	var resource_costs: Dictionary = {
		"gold": int(unit_data.get("cost_gold", 0)),
		"food": int(unit_data.get("cost_food", 0)),
		"wood": int(unit_data.get("cost_wood", 0)),
		"horse": int(unit_data.get("cost_horse", 0)),
		"refined_iron": int(unit_data.get("cost_refined_iron", 0)),
		"craftsmen": int(unit_data.get("cost_craftsmen", 0)),
	}
	var affordable: int = desired
	for resource in resource_costs:
		var cost: int = int(resource_costs[resource])
		if cost <= 0:
			continue
		var available: int = get_faction_resource(faction_id, str(resource)) - int(reserve.get(resource, 0))
		affordable = mini(affordable, int(maxi(available, 0) / cost))
	return affordable


func _get_recruit_resource_reserve(faction_id: String) -> Dictionary:
	if faction_id == _player_faction:
		return {}
	var params: Dictionary = DataManager.get_balance_param("ai_military.recruitment")
	return {
		"gold": int(params.get("min_gold_reserve", 0)),
		"food": int(params.get("min_food_reserve", 0)),
	}


func _pay_unit_cost(faction_id: String, city_id: String, unit_data: Dictionary, count: int) -> void:
	var cost_mod: float = 1.0 - get_recruit_efficiency(faction_id, city_id)
	apply_faction_resource_delta(faction_id, "gold", -int(round(int(unit_data.get("cost_gold", 0)) * count * cost_mod)))
	apply_faction_resource_delta(faction_id, "food", -int(round(int(unit_data.get("cost_food", 0)) * count * cost_mod)))
	apply_faction_resource_delta(faction_id, "wood", -int(round(int(unit_data.get("cost_wood", 0)) * count * cost_mod)))
	apply_faction_resource_delta(faction_id, "horse", -int(round(int(unit_data.get("cost_horse", 0)) * count * cost_mod)))
	apply_faction_resource_delta(faction_id, "refined_iron", -int(round(int(unit_data.get("cost_refined_iron", 0)) * count * cost_mod)))
	apply_faction_resource_delta(faction_id, "craftsmen", -int(round(int(unit_data.get("cost_craftsmen", 0)) * count * cost_mod)))


## 移除 faction 指定兵种。不会低于 0。
func remove_units(faction_id: String, unit_id: String, count: int) -> void:
	if not _unit_composition.has(faction_id):
		return
	var comp: Dictionary = _unit_composition[faction_id]
	if not comp.has(unit_id):
		return
	comp[unit_id] = max(0, int(comp[unit_id]) - count)
	if comp[unit_id] == 0:
		comp.erase(unit_id)
	if faction_id == _player_faction:
		_player_troops = _sum_composition(faction_id)


## 获取 faction 总兵力（从兵种构成求和）。
func get_total_troops(faction_id: String) -> int:
	return _sum_composition(faction_id)


func _sum_composition(faction_id: String) -> int:
	var total: int = 0
	for count in _unit_composition.get(faction_id, {}).values():
		total += int(count)
	return total


func get_player_horse() -> int:
	return _player_horse


func get_player_refined_iron() -> int:
	return _player_refined_iron


func apply_horse_delta(delta: int) -> void:
	_player_horse = max(0, _player_horse + delta)


func apply_refined_iron_delta(delta: int) -> void:
	_player_refined_iron = max(0, _player_refined_iron + delta)


func get_player_craftsmen() -> int:
	return _player_craftsmen


func apply_craftsmen_delta(delta: int) -> void:
	_player_craftsmen = max(0, _player_craftsmen + delta)


func get_player_building_materials() -> int:
	return _player_building_materials


func apply_building_materials_delta(delta: int) -> void:
	_player_building_materials = max(0, _player_building_materials + delta)


func get_player_silk_books() -> int:
	return _player_silk_books


func apply_silk_books_delta(delta: int) -> void:
	_player_silk_books = max(0, _player_silk_books + delta)


# ============= 测试与重开 =============

## 重置到初始状态。供单元测试与「重新开局」使用。
func reset() -> void:
	_phase = Phase.GAME_INIT
	_turn_state = TurnState.WAITING
	_turn_number = 0
	_active_factions = []
	_faction_order = []
	_faction_index = 0
	_player_faction = ""
	_player_food = 0
	_player_gold = 0
	_player_wood = 0
	_player_morale = 50
	_player_population = 0
	_player_troops = 0
	_player_horse = 0
	_player_refined_iron = 0
	_player_craftsmen = 0
	_player_building_materials = 0
	_player_silk_books = 0
	_faction_resources.clear()
	_unit_composition.clear()
	_grain_shortage_factions.clear()
	_difficulty = "normal"
	_tax_rate = 0.3
	_tax_change_cooldown_remaining = 0
	_national_grain_pool = 0
	_war_weariness_turns.clear()
	_war_weariness_recovery_turns.clear()
	_capital_morale_recovery.clear()
	_capital_captured_targets.clear()
	_captured_capitals_by_faction.clear()
	_victory_bonus_turns_remaining.clear()
	_cultural_victory_turns.clear()


# ============= AI 国家资源管理 =============

func get_faction_resources(faction_id: String) -> Dictionary:
	if faction_id == _player_faction:
		return {"food": _player_food, "gold": _player_gold, "wood": _player_wood,
				"morale": _player_morale, "population": _player_population, "troops": _player_troops,
				"horse": _player_horse, "refined_iron": _player_refined_iron,
				"craftsmen": _player_craftsmen, "building_materials": _player_building_materials,
				"silk_books": _player_silk_books}
	return _faction_resources.get(faction_id, {})


func get_faction_resource(faction_id: String, resource: String) -> int:
	var res: Dictionary = get_faction_resources(faction_id)
	return res.get(resource, 0)


func apply_faction_resource_delta(faction_id: String, resource: String, delta: int) -> void:
	if faction_id == _player_faction:
		match resource:
			"food": apply_food_delta(delta)
			"gold": apply_gold_delta(delta)
			"wood": apply_wood_delta(delta)
			"morale": apply_morale_delta(delta)
			"population": apply_population_delta(delta)
			"troops": apply_troops_delta(delta)
			"horse": apply_horse_delta(delta)
			"refined_iron": apply_refined_iron_delta(delta)
			"craftsmen": apply_craftsmen_delta(delta)
			"building_materials": apply_building_materials_delta(delta)
			"silk_books": apply_silk_books_delta(delta)
		return
	if not _faction_resources.has(faction_id):
		return
	var res: Dictionary = _faction_resources[faction_id]
	if not res.has(resource):
		return
	if resource == "morale":
		res[resource] = clampi(res[resource] + delta, 0, _get_morale_cap(faction_id))
	else:
		res[resource] = max(0, res[resource] + delta)
	var cap: int = get_resource_cap(resource, faction_id)
	if cap >= 0:
		res[resource] = mini(int(res[resource]), cap)


func get_difficulty() -> String:
	return _difficulty


func set_difficulty(difficulty: String) -> void:
	_difficulty = difficulty


# ============= 内部 =============

func _init_player_resources() -> void:
	var capital: Dictionary = DataManager.get_capital(_player_faction)
	if capital.is_empty():
		push_warning("GameManager: 未找到玩家首都，使用默认资源")
		_player_food = 500
		_player_gold = 300
		_player_wood = 100
		_player_population = 10000
		_player_troops = 0
		_player_horse = 0
		_player_refined_iron = 0
		_player_craftsmen = 0
		_player_building_materials = 0
		_player_silk_books = 0
		return
	_player_population = int(capital.get("initial_population", capital.get("base_population", 10000)))
	# 初始资源基于城市人口和基础产出（路径：population.food_per_pop / gold_per_pop）
	var food_pp: float = float(DataManager.get_balance_param("population.food_per_pop"))
	var gold_pp: float = float(DataManager.get_balance_param("population.gold_per_pop"))
	_player_food = int(_player_population * food_pp * 10)
	_player_gold = int(_player_population * gold_pp * 5)
	_player_wood = int(DataManager.get_balance_param("resources.city_base_wood") * 3)
	_player_troops = 0
	_player_horse = 0
	_player_refined_iron = 0
	_player_craftsmen = 0
	_player_building_materials = 0
	_player_silk_books = 0
	_player_morale = 50
	_clamp_faction_resource_caps(_player_faction)


func _init_ai_factions() -> void:
	_faction_resources.clear()
	var diff_settings: Dictionary = DataManager.get_difficulty_settings(_difficulty)
	var gold_bonus: int = diff_settings.get("initial_gold_bonus", 0)
	var res_mod: float = diff_settings.get("resource_mod", 0.0)

	for fid in _active_factions:
		if fid == _player_faction:
			continue
		var capital: Dictionary = DataManager.get_capital(fid)
		var population: int = int(capital.get("initial_population", capital.get("base_population", 10000))) if not capital.is_empty() else 10000
		var ai_food_pp: float = float(DataManager.get_balance_param("population.food_per_pop"))
		var ai_gold_pp: float = float(DataManager.get_balance_param("population.gold_per_pop"))
		var base_food: int = int(population * ai_food_pp * 10)
		var base_gold: int = int(population * ai_gold_pp * 5)
		var base_wood: int = int(DataManager.get_balance_param("resources.city_base_wood") * 3)
		# 应用难度修正
		_faction_resources[fid] = {
			"food": int(base_food * (1.0 + res_mod)),
			"gold": int(base_gold * (1.0 + res_mod)) + gold_bonus,
			"wood": int(base_wood * (1.0 + res_mod)),
			"morale": 50,
			"population": population,
			"troops": 0,
			"horse": 0,
			"refined_iron": 0,
			"craftsmen": 0,
			"building_materials": 0,
			"silk_books": 0
		}
		_clamp_faction_resource_caps(fid)


func _get_faction_runtime_population(faction_id: String) -> int:
	var total: int = 0
	for city in CityManager.get_faction_city_states(faction_id):
		total += int((city as Dictionary).get("current_population", 0))
	if total > 0:
		return total
	return get_faction_resource(faction_id, "population")


func _get_border_city_count(faction_id: String, cities: Array = []) -> int:
	var target_cities: Array = cities if not cities.is_empty() else CityManager.get_faction_city_states(faction_id)
	var capital: Dictionary = CityManager.get_capital_state(faction_id)
	if capital.is_empty():
		return 0
	var cq: int = int(capital.get("hex_q", 0))
	var cr: int = int(capital.get("hex_r", 0))
	var threshold: int = int(DataManager.get_balance_param("corruption.growth.border_distance_threshold"))
	var count: int = 0
	for city in target_cities:
		var state: Dictionary = city as Dictionary
		var dist: int = (absi(int(state.get("hex_q", 0)) - cq) + absi(int(state.get("hex_q", 0)) + int(state.get("hex_r", 0)) - cq - cr) + absi(int(state.get("hex_r", 0)) - cr)) / 2
		if dist > threshold:
			count += 1
	return count


func _get_corruption_tech_reduction() -> float:
	var total: float = 0.0
	for tech in TechSystem.get_researched_techs():
		var effect_data: Variant = (tech as Dictionary).get("effects", {})
		var effects: Array = effect_data if effect_data is Array else [effect_data]
		for entry in effects:
			var effect: Dictionary = entry as Dictionary
			if str(effect.get("type", "")) == "corruption_reduction":
				total += float(effect.get("value", 0.0))
	return total


func _get_school_effect_float(faction_id: String, effect_key: String) -> float:
	return SchoolManager.get_effect_float(faction_id, effect_key)


func _get_confucian_prosperity_bonus(faction_id: String) -> float:
	var prosperity_enabled: Variant = SchoolManager.get_effect_value(faction_id, "morale_prosperity_enabled")
	if prosperity_enabled is not bool or not prosperity_enabled:
		return 0.0
	if not is_player_faction(faction_id):
		return 0.0
	var threshold: int = int(DataManager.get_balance_param("morale.confucian_prosperity_threshold"))
	var per_point: float = float(DataManager.get_balance_param("morale.confucian_prosperity_per_point"))
	if _player_morale <= threshold:
		return 0.0
	return float(_player_morale - threshold) * per_point


func _get_morale_cap(faction_id: String) -> int:
	if faction_id == "":
		return 100
	var base_cap: int = 100
	var morale_cap_bonus: int = int(round(_get_school_effect_float(faction_id, "morale_cap_bonus")))
	var hard_cap_bonus: int = int(round(_get_school_effect_float(faction_id, "morale_hard_cap_bonus")))
	var wonder_cap_bonus: int = int(round(WonderManager.get_effect_float(faction_id, "morale_cap_national")))
	var soft_cap: int = base_cap + morale_cap_bonus + wonder_cap_bonus
	var hard_cap: int = int(DataManager.get_balance_param("morale.hard_cap_base")) + hard_cap_bonus
	return mini(soft_cap, hard_cap)


func _sum_city_building_effect(city: Dictionary, effect_key: String) -> float:
	var total: float = 0.0
	for building in city.get("buildings", []):
		var b: Dictionary = building as Dictionary
		var bdata: Dictionary = DataManager.get_building(str(b.get("building_id", "")))
		if bdata.is_empty():
			continue
		var levels: Array = bdata.get("levels", [])
		var level: int = int(b.get("level", 1))
		if level < 1 or level > levels.size():
			continue
		var effects: Dictionary = (levels[level - 1] as Dictionary).get("effects", {})
		total += float(effects.get(effect_key, 0.0))
	return total


func _sum_building_effect(faction_id: String, effect_key: String) -> float:
	var total: float = 0.0
	for city in CityManager.get_faction_city_states(faction_id):
		total += _sum_city_building_effect(city as Dictionary, effect_key)
	return total


func _get_total_national_building_morale(faction_id: String) -> int:
	return int(round(_sum_building_effect(faction_id, "morale_bonus")))


func _get_total_building_upkeep(faction_id: String) -> int:
	var total: int = 0
	for city in CityManager.get_faction_city_states(faction_id):
		for building in (city as Dictionary).get("buildings", []):
			var b: Dictionary = building as Dictionary
			var bdata: Dictionary = DataManager.get_building(str(b.get("building_id", "")))
			if bdata.is_empty():
				continue
			total += int(bdata.get("upkeep_gold", 0)) * int(b.get("level", 1))
	var reduction: float = clampf(_get_school_effect_float(faction_id, "building_upkeep_reduction"), 0.0, 0.95)
	return int(round(total * (1.0 - reduction)))


func _apply_resource_modifier(total: Dictionary, resource: String) -> void:
	if not total.has(resource):
		return
	var modifier: float = TechSystem.get_resource_modifier(resource)
	if absf(modifier) <= 0.001:
		return
	total[resource] = int(round(int(total.get(resource, 0)) * (1.0 + modifier)))


func _apply_wonder_resource_modifier(total: Dictionary, faction_id: String, resource: String, effect_key: String) -> void:
	if not total.has(resource):
		return
	var modifier: float = float(WonderManager.get_effect_float(faction_id, effect_key))
	if absf(modifier) <= 0.001:
		return
	total[resource] = int(round(int(total.get(resource, 0)) * (1.0 + modifier)))


func _get_total_building_levels(faction_id: String, building_id: String) -> int:
	var total: int = 0
	for city in CityManager.get_faction_city_states(faction_id):
		for building in (city as Dictionary).get("buildings", []):
			var b: Dictionary = building as Dictionary
			if str(b.get("building_id", "")) == building_id:
				total += int(b.get("level", 1))
	return total


func _clamp_faction_resource_caps(faction_id: String) -> void:
	for resource in ["food", "gold", "wood", "silk_books"]:
		var cap: int = get_resource_cap(resource, faction_id)
		if cap < 0:
			continue
		if faction_id == _player_faction:
			match resource:
				"food":
					_player_food = mini(_player_food, cap)
				"gold":
					_player_gold = mini(_player_gold, cap)
				"wood":
					_player_wood = mini(_player_wood, cap)
				"silk_books":
					_player_silk_books = mini(_player_silk_books, cap)
		elif _faction_resources.has(faction_id):
			_faction_resources[faction_id][resource] = mini(int(_faction_resources[faction_id].get(resource, 0)), cap)


func _get_base_drift_delta(faction_id: String) -> int:
	var current_morale: int = get_faction_resource(faction_id, "morale")
	var drift: int = int(DataManager.get_balance_param("morale.base_drift"))
	if current_morale > 50:
		return -drift
	if current_morale < 50:
		return drift
	return 0


func _get_war_weariness_delta(faction_id: String) -> int:
	_update_war_weariness(faction_id)
	var threshold: int = int(DataManager.get_balance_param("morale.war_weariness_threshold"))
	var war_turns: int = int(_war_weariness_turns.get(faction_id, 0))
	if war_turns > threshold:
		return int(DataManager.get_balance_param("morale.war_weariness_per_turn"))
	var recovery_turns: int = int(_war_weariness_recovery_turns.get(faction_id, 0))
	if recovery_turns > 0:
		_war_weariness_recovery_turns[faction_id] = recovery_turns - 1
		if recovery_turns - 1 <= 0:
			_war_weariness_recovery_turns.erase(faction_id)
		return int(DataManager.get_balance_param("morale.war_recovery_per_turn"))
	return 0


func _get_victory_bonus_delta(faction_id: String) -> int:
	var turns_remaining: int = int(_victory_bonus_turns_remaining.get(faction_id, 0))
	if turns_remaining <= 0:
		return 0
	_victory_bonus_turns_remaining[faction_id] = turns_remaining - 1
	return int(DataManager.get_balance_param("morale.victory_bonus"))


func _get_capital_recovery_delta(faction_id: String) -> int:
	var recovery_state: Dictionary = _capital_morale_recovery.get(faction_id, {})
	if recovery_state.is_empty():
		return 0
	var remaining_penalty: int = int(recovery_state.get("remaining_penalty", 0))
	var recovery_per_turn: int = int(DataManager.get_balance_param("morale.capital_captured_recovery_per_turn"))
	var recovery_cap: int = int(DataManager.get_balance_param("morale.capital_captured_recovery_cap"))
	if remaining_penalty >= recovery_cap:
		_capital_morale_recovery.erase(faction_id)
		return 0
	var new_remaining_penalty: int = min(remaining_penalty + recovery_per_turn, recovery_cap)
	_capital_morale_recovery[faction_id] = {"remaining_penalty": new_remaining_penalty}
	if new_remaining_penalty >= recovery_cap:
		_capital_morale_recovery.erase(faction_id)
	return recovery_per_turn


func _on_war_declared(attacker: String, defender: String) -> void:
	if not _war_weariness_turns.has(attacker):
		_war_weariness_turns[attacker] = 0
	if not _war_weariness_turns.has(defender):
		_war_weariness_turns[defender] = 0


func _on_ceasefire_signed(faction_a: String, faction_b: String) -> void:
	_start_war_recovery(faction_a)
	_start_war_recovery(faction_b)


func _on_capital_lost(faction_id: String, _lost_city_id: String) -> void:
	var debuff: int = int(DataManager.get_balance_param("morale.capital_captured_debuff"))
	apply_faction_resource_delta(faction_id, "morale", debuff)
	_capital_morale_recovery[faction_id] = {"remaining_penalty": debuff}
	_capital_captured_targets[faction_id] = _lost_city_id


func _on_city_occupied(city_id: String, old_faction: String, new_faction: String) -> void:
	var city: Dictionary = CityManager.get_city_state(city_id)
	if city.is_empty():
		return
	var was_capital: bool = bool(city.get("is_capital", false))
	var capital_lost_target: String = str(_capital_captured_targets.get(old_faction, ""))
	if capital_lost_target != "":
		was_capital = capital_lost_target == city_id
	if not was_capital:
		return
	_handle_capital_capture(new_faction, old_faction, city_id)


func _handle_capital_capture(attacker: String, defender: String, city_id: String) -> void:
	if bool(DataManager.get_balance_param("morale.capital_recapture_clear_all")) and _capital_captured_targets.get(attacker, "") == city_id:
		_capital_morale_recovery.erase(attacker)
		_capital_captured_targets.erase(attacker)
		return
	var first_capture_only: bool = bool(DataManager.get_balance_param("morale.victory_bonus_first_capture_only"))
	if first_capture_only:
		if not _captured_capitals_by_faction.has(attacker):
			_captured_capitals_by_faction[attacker] = {}
		var captured: Dictionary = _captured_capitals_by_faction[attacker]
		if bool(captured.get(defender, false)):
			return
		captured[defender] = true
	var duration: int = int(DataManager.get_balance_param("morale.victory_bonus_duration"))
	_victory_bonus_turns_remaining[attacker] = duration


func _update_war_weariness(faction_id: String) -> void:
	var at_war: bool = DiplomacySystem.is_at_war(faction_id)
	if at_war:
		_war_weariness_turns[faction_id] = int(_war_weariness_turns.get(faction_id, 0)) + 1
		return
	if not _war_weariness_recovery_turns.has(faction_id):
		_war_weariness_turns.erase(faction_id)


func _start_war_recovery(faction_id: String) -> void:
	var threshold: int = int(DataManager.get_balance_param("morale.war_weariness_threshold"))
	var war_turns: int = int(_war_weariness_turns.get(faction_id, 0))
	if war_turns > threshold:
		_war_weariness_recovery_turns[faction_id] = war_turns - threshold
	_war_weariness_turns.erase(faction_id)


func _change_phase(new_phase: Phase) -> void:
	var old_phase := _phase
	_phase = new_phase
	SignalBus.phase_changed.emit(old_phase, new_phase)


func _process_national_culture_turn() -> void:
	CityManager.process_culture_turn()
	var victory_cfg: Dictionary = DataManager.get_balance_param("victory.cultural")
	var ratio_threshold: float = float(victory_cfg.get("city_ratio", DataManager.get_balance_param("culture.victory_ratio")))
	var maintain_turns: int = int(victory_cfg.get("maintain_turns", DataManager.get_balance_param("culture.victory_turns")))
	for fid in _active_factions:
		var coverage: float = CityManager.get_culture_coverage_ratio(fid)
		if coverage >= ratio_threshold:
			_cultural_victory_turns[fid] = int(_cultural_victory_turns.get(fid, 0)) + 1
		else:
			_cultural_victory_turns.erase(fid)


func _check_cultural_victory() -> String:
	var victory_cfg: Dictionary = DataManager.get_balance_param("victory.cultural")
	var ratio_threshold: float = float(victory_cfg.get("city_ratio", DataManager.get_balance_param("culture.victory_ratio")))
	var maintain_turns: int = int(victory_cfg.get("maintain_turns", DataManager.get_balance_param("culture.victory_turns")))
	for fid in _active_factions:
		if int(_cultural_victory_turns.get(fid, 0)) >= maintain_turns and CityManager.get_culture_coverage_ratio(fid) >= ratio_threshold:
			return fid
	return ""


func _sort_factions_by_speed() -> void:
	_faction_order = _active_factions.duplicate()
	_faction_order.sort_custom(func(a: String, b: String) -> bool:
		var speed_a: float = _get_faction_action_speed(a)
		var speed_b: float = _get_faction_action_speed(b)
		if speed_a != speed_b:
			return speed_a > speed_b
		return a < b
	)


func _get_faction_action_speed(faction_id: String) -> float:
	var speed: float = 1.0
	speed += TechSystem.get_faction_action_speed_bonus(faction_id)
	return speed


func get_turn_state() -> TurnState:
	return _turn_state


func get_faction_order() -> Array[String]:
	return _faction_order.duplicate()
