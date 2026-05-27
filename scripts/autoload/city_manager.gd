extends Node

## 城市管理器（CityManager）
##
## 维护 50 城的运行时状态，提供查询、建造、升级、拆除、归属变更、回合结算等接口。
## 子任务 1：autoload 骨架 + 状态初始化 + 4 个查询接口。
## 子任务 2：建造校验 + start_build（含每国限建逻辑）。
## 子任务 3：升级（can_upgrade / start_upgrade）+ 拆除（demolish）+ 修复 can_build 槽位计算。
## 子任务 4：城市占领系统 — change_ownership / relocate_player_capital /
##           relocate_ai_capital / is_faction_eliminated。
##
## 状态字段约定（见 docs/decisions/阶段1-策划任务决策记录.md 决策 43/44）：
## - 静态字段（来自 cities.json）：id / name / faction_id / hex_q / hex_r /
##   jurisdiction_radius / city_level / special_resource /
##   is_capital / initial_population
## - 运行时字段（本管理器维护）：
##   - current_faction_id: String — 当前占领者，初始 = faction_id
##   - buildings: Array — 已建建筑 [{building_id, level}]，初始 []
##   - build_queue: Array — 建造队列 [{building_id, turns_remaining}]，初始 []
##     注：升级与新建共用此队列（决策 - 升级队列共用 build_queue）。
##         回合结算时按「该城市 buildings 是否已包含 building_id」判断是新建还是升级。
##   - current_population: int — 当前人口，初始 = base_population
##   - is_capital: bool — 运行时可变（子任务 4 起），不变量「每国最多 1 个 is_capital=true」
##
## 限建语义说明（决策 33/35 + 子任务 2 解读 B）：
## - buildings.json 的 max_national_count 字段名易误解为「全图」语义，
##   实际策划意图是「每国限建数」：每个 faction 持有该 building_id 的
##   总数（已建 + 在建）≤ max_national_count。无此字段表示不限建。
##
## 拆除返还语义（子任务 3 决策）：
## - 按当前难度查 data/diplomacy.json difficulty.<diff>.demolish_refund_ratio
## - easy 0.75 / normal 0.50 / hard 0.25 / hell 0.00
## - 返还基数：仅基础建造成本（cost_gold + cost_wood），不返还升级花费
##
## 占领规则（子任务 4 决策）：
## - 占领后建筑随城易主（含等级），在建队列清空且不退资源
## - 中立城（洛邑/邢台/定陶）可被任意 7 国占领，与普通城同
## - 首都失守：原主 is_capital=false，发 capital_lost 信号；玩家最多迁都
##   data/balance_params.json:capital.player_max_relocations 次（默认 2），
##   AI 不限次数，AI 选址按 factions.json:ai_capital_relocation_weight
##   （null 时兜底人口最高）
## - 灭国：faction 持城数=0；GameManager.check_victory 由此决定征服胜利

# ============= 公开常量（拒绝原因） =============

const REASON_OK := "OK"
const REASON_INVALID_CITY := "INVALID_CITY"
const REASON_INVALID_BUILDING := "INVALID_BUILDING"
const REASON_ALREADY_BUILT := "ALREADY_BUILT"
const REASON_ALREADY_QUEUED := "ALREADY_QUEUED"
const REASON_SLOTS_FULL := "SLOTS_FULL"
const REASON_NATIONAL_CAP_REACHED := "NATIONAL_CAP_REACHED"
const REASON_INSUFFICIENT_RESOURCES := "INSUFFICIENT_RESOURCES"
const REASON_BUILDING_NOT_BUILT := "BUILDING_NOT_BUILT"
const REASON_MAX_LEVEL_REACHED := "MAX_LEVEL_REACHED"
const REASON_NOT_OWN_CITY := "NOT_OWN_CITY"
const REASON_RELOCATION_LIMIT := "RELOCATION_LIMIT"

# ============= 私有状态 =============

var _city_states: Dictionary = {}              # city_id (String) → city_state (Dictionary)
var _states_by_faction: Dictionary = {}        # faction_id (String) → Array of city_state
var _player_relocation_counts: Dictionary = {} # faction_id (String) → 已迁都次数 (int)

# ============= 生命周期 =============

func _ready() -> void:
	_initialize_states()
	_build_faction_index()
	print("[CityManager] 已初始化 %d 城" % _city_states.size())


# ============= 查询接口 =============

## 按 city_id 获取运行时状态。未知 ID 返回空字典并发 warning。
func get_city_state(city_id: String) -> Dictionary:
	if _city_states.has(city_id):
		return _city_states[city_id]
	push_warning("CityManager: 未找到城市 %s" % city_id)
	return {}


## 获取所有城市的运行时状态数组。
func get_all_city_states() -> Array:
	return _city_states.values()


## 获取指定 faction 当前持有的城市状态数组。包含 "neutral" 中立城市。
## 未知 faction_id 返回空数组（无 warning，便于循环调用）。
func get_faction_city_states(faction_id: String) -> Array:
	return _states_by_faction.get(faction_id, [])


## 获取指定 faction 的首都状态。未找到返回空字典并发 warning。
func get_capital_state(faction_id: String) -> Dictionary:
	for state in get_faction_city_states(faction_id):
		if state.get("is_capital", false):
			return state
	push_warning("CityManager: 未找到 %s 的首都" % faction_id)
	return {}


# ============= 建造接口 =============

## 校验是否能在 city_id 建造 building_id。
## 返回 {"allowed": bool, "reason": String}。reason 为 REASON_* 常量之一。
## 校验项（按顺序）：
##   1. city_id 合法（INVALID_CITY）
##   2. building_id 合法（INVALID_BUILDING）
##   3. 该城市未建过该建筑（ALREADY_BUILT）
##   4. 该城市建造队列中无该建筑（ALREADY_QUEUED）
##   5. 该城市槽位未满（SLOTS_FULL，仅算「新建」队列项，升级中的不占新槽）
##   6. 该 faction 该建筑总数 < max_national_count（NATIONAL_CAP_REACHED）
##   7. 玩家资源够（INSUFFICIENT_RESOURCES）
func can_build(city_id: String, building_id: String) -> Dictionary:
	if not _city_states.has(city_id):
		return {"allowed": false, "reason": REASON_INVALID_CITY}
	var building: Dictionary = DataManager.get_building(building_id)
	if building.is_empty():
		return {"allowed": false, "reason": REASON_INVALID_BUILDING}

	var city: Dictionary = _city_states[city_id]
	if _city_has_building(city, building_id):
		return {"allowed": false, "reason": REASON_ALREADY_BUILT}
	if _city_has_in_queue(city, building_id):
		return {"allowed": false, "reason": REASON_ALREADY_QUEUED}

	# 槽位计算：buildings + 仅「新建」队列项（升级中的项已经在 buildings 里，不重复占槽）
	var city_level: int = int(city.get("city_level", 1))
	var levels_cfg: Dictionary = DataManager.get_balance_param("city_levels")
	var level_cfg: Dictionary = levels_cfg.get(str(city_level), {})
	var slots: int = int(level_cfg.get("building_slots", 0))
	var occupied: int = (city["buildings"] as Array).size() + _count_new_build_in_queue(city)
	if occupied >= slots:
		return {"allowed": false, "reason": REASON_SLOTS_FULL}

	# max_national_count = 每国限建数（决策 33/35 解读 B）
	var max_per_faction: Variant = building.get("max_national_count")
	if max_per_faction != null:
		var faction_id: String = city["current_faction_id"]
		var existing: int = _count_faction_building(faction_id, building_id)
		if existing >= int(max_per_faction):
			return {"allowed": false, "reason": REASON_NATIONAL_CAP_REACHED}

	var cost_gold: int = int(building.get("cost_gold", 0))
	var cost_wood: int = int(building.get("cost_wood", 0))
	if GameManager.get_player_gold() < cost_gold or GameManager.get_player_wood() < cost_wood:
		return {"allowed": false, "reason": REASON_INSUFFICIENT_RESOURCES}

	return {"allowed": true, "reason": REASON_OK}


## 开始在 city_id 建造 building_id。
## 校验通过 → 扣资源、加入建造队列、返回 true。
## 校验失败 → 不动任何状态、返回 false（建议先调 can_build 看 reason）。
func start_build(city_id: String, building_id: String) -> bool:
	var check: Dictionary = can_build(city_id, building_id)
	if not check["allowed"]:
		return false

	var building: Dictionary = DataManager.get_building(building_id)
	var cost_gold: int = int(building.get("cost_gold", 0))
	var cost_wood: int = int(building.get("cost_wood", 0))
	var build_turns: int = int(building.get("build_turns", 1))

	GameManager.apply_gold_delta(-cost_gold)
	GameManager.apply_wood_delta(-cost_wood)

	var city: Dictionary = _city_states[city_id]
	(city["build_queue"] as Array).append({
		"building_id": building_id,
		"turns_remaining": build_turns,
	})
	return true


# ============= 升级接口 =============

## 校验是否能在 city_id 升级 building_id（升 1 级）。
## 返回 {"allowed": bool, "reason": String}。
## 校验项（按顺序）：
##   1. city_id 合法（INVALID_CITY）
##   2. building_id 合法（INVALID_BUILDING）
##   3. 该建筑已建在该城市（BUILDING_NOT_BUILT）
##   4. 该建筑未在 build_queue（ALREADY_QUEUED；含升级队列中状态）
##   5. 当前等级 < max_level（MAX_LEVEL_REACHED）
##   6. 玩家资源够升级费用（INSUFFICIENT_RESOURCES）
## 注：升级不占新槽位、不增数量，故不校验 SLOTS_FULL 与 NATIONAL_CAP。
func can_upgrade(city_id: String, building_id: String) -> Dictionary:
	if not _city_states.has(city_id):
		return {"allowed": false, "reason": REASON_INVALID_CITY}
	var building: Dictionary = DataManager.get_building(building_id)
	if building.is_empty():
		return {"allowed": false, "reason": REASON_INVALID_BUILDING}

	var city: Dictionary = _city_states[city_id]
	var current_level: int = _city_building_level(city, building_id)
	if current_level == 0:
		return {"allowed": false, "reason": REASON_BUILDING_NOT_BUILT}
	if _city_has_in_queue(city, building_id):
		return {"allowed": false, "reason": REASON_ALREADY_QUEUED}

	var max_level: int = int(building.get("max_level", 1))
	if current_level >= max_level:
		return {"allowed": false, "reason": REASON_MAX_LEVEL_REACHED}

	var costs: Array = _calculate_upgrade_cost(building, current_level)
	if GameManager.get_player_gold() < int(costs[0]) or GameManager.get_player_wood() < int(costs[1]):
		return {"allowed": false, "reason": REASON_INSUFFICIENT_RESOURCES}

	return {"allowed": true, "reason": REASON_OK}


## 开始升级 city_id 的 building_id（升 1 级）。
## 升级费用 = base_cost × upgrade_cost_multiplier^current_level（决策 25）。
## 校验通过 → 扣升级费用、加入 build_queue、返回 true。
## 校验失败 → 不动任何状态、返回 false。
func start_upgrade(city_id: String, building_id: String) -> bool:
	var check: Dictionary = can_upgrade(city_id, building_id)
	if not check["allowed"]:
		return false

	var building: Dictionary = DataManager.get_building(building_id)
	var city: Dictionary = _city_states[city_id]
	var current_level: int = _city_building_level(city, building_id)
	var costs: Array = _calculate_upgrade_cost(building, current_level)
	var build_turns: int = int(building.get("build_turns", 1))

	GameManager.apply_gold_delta(-int(costs[0]))
	GameManager.apply_wood_delta(-int(costs[1]))

	(city["build_queue"] as Array).append({
		"building_id": building_id,
		"turns_remaining": build_turns,
	})
	return true


# ============= 拆除接口 =============

## 拆除 city_id 已建的 building_id。
## 按当前难度查 difficulty.<diff>.demolish_refund_ratio 返还基础建造成本：
##   easy 0.75 / normal 0.50 / hard 0.25 / hell 0.00（兜底 0.50）
## 返还基数：仅基础建造成本（cost_gold + cost_wood），不返还升级花费。
## 若该建筑同时在 build_queue（升级中），一并清除（不补偿升级费）。
## 仅拆已建建筑：未建（仅在队列中）的建筑请用 cancel_build（暂未实现）。
##
## 返回 true 表示拆除成功，false 表示参数非法或建筑未建。
func demolish(city_id: String, building_id: String) -> bool:
	if not _city_states.has(city_id):
		return false
	var city: Dictionary = _city_states[city_id]
	if not _city_has_building(city, building_id):
		return false

	# 计算并返还资源（防御性兜底，避免 difficulty 配置缺失时崩）
	var building: Dictionary = DataManager.get_building(building_id)
	if not building.is_empty():
		var diff: String = GameManager.get_difficulty()
		var settings: Dictionary = DataManager.get_difficulty_settings(diff)
		var ratio: float = float(settings.get("demolish_refund_ratio", 0.5))
		var refund_gold: int = int(round(float(building.get("cost_gold", 0)) * ratio))
		var refund_wood: int = int(round(float(building.get("cost_wood", 0)) * ratio))
		if refund_gold > 0:
			GameManager.apply_gold_delta(refund_gold)
		if refund_wood > 0:
			GameManager.apply_wood_delta(refund_wood)

	# 移除 buildings 中匹配项（倒序遍历安全删除）
	var buildings: Array = city["buildings"]
	for i in range(buildings.size() - 1, -1, -1):
		if buildings[i].get("building_id") == building_id:
			buildings.remove_at(i)

	# 清理 build_queue 中匹配项（含正在升级的）
	var queue: Array = city["build_queue"]
	for i in range(queue.size() - 1, -1, -1):
		if queue[i].get("building_id") == building_id:
			queue.remove_at(i)

	return true


# ============= 取消建造 =============

## 取消建造队列中指定位置的条目。退还全部建造费用。
## queue_index 为 build_queue 中的索引（0-based）。
## 返回 true 表示取消成功。
func cancel_build(city_id: String, queue_index: int) -> bool:
	if not _city_states.has(city_id):
		return false
	var city: Dictionary = _city_states[city_id]
	var queue: Array = city["build_queue"] as Array
	if queue_index < 0 or queue_index >= queue.size():
		return false
	var entry: Dictionary = queue[queue_index]
	var bid: String = str(entry["building_id"])
	var building: Dictionary = DataManager.get_building(bid)
	if not building.is_empty():
		# 退还全部建造费用
		var cost_gold: int = int(building.get("cost_gold", 0))
		var cost_wood: int = int(building.get("cost_wood", 0))
		if cost_gold > 0:
			GameManager.apply_gold_delta(cost_gold)
		if cost_wood > 0:
			GameManager.apply_wood_delta(cost_wood)
	queue.remove_at(queue_index)
	return true


# ============= 测试与重开 =============

## 重置到初始状态。供单元测试与「重新开局」使用。
func reset() -> void:
	_initialize_states()
	_build_faction_index()
	_player_relocation_counts.clear()


# ============= 占领系统（子任务 4） =============

## 把 city_id 的所有权变更到 new_faction_id。
## - 校验：city_id 必须合法，new_faction_id 必须是 7 国之一（neutral 不能作为新主）
## - 保留 buildings 不变；清空 build_queue 不退资源给原主（以战养战）
## - 重建 _states_by_faction 索引
## - 占的是首都时，先广播 capital_lost；总是广播 city_occupied
## 返回 true 表示变更成功，false 表示参数非法。
func change_ownership(city_id: String, new_faction_id: String) -> bool:
	if not _city_states.has(city_id):
		return false
	# new_faction_id 必须是 7 国之一（neutral / 未知 → DataManager.get_faction 返空）
	if DataManager.get_faction(new_faction_id).is_empty():
		return false

	var city: Dictionary = _city_states[city_id]
	var old_faction_id: String = city["current_faction_id"]
	# 同主无操作（避免误清队列与误翻 is_capital）
	if old_faction_id == new_faction_id:
		return true
	var was_capital: bool = city.get("is_capital", false)

	city["current_faction_id"] = new_faction_id
	(city["build_queue"] as Array).clear()
	_move_city_in_faction_index(city, old_faction_id, new_faction_id)

	if was_capital:
		# 首都被占 → 城市失去首都身份（不变量：每国最多 1 个 is_capital=true）。
		# 原主需要后续 relocate_*_capital 才能重新拥有首都。
		city["is_capital"] = false
		SignalBus.capital_lost.emit(old_faction_id, city_id)
	SignalBus.city_occupied.emit(city_id, old_faction_id, new_faction_id)
	return true


## 玩家迁都：把 faction_id 的首都迁到 new_capital_city_id。
## - 校验：city 合法、属于该 faction、本 faction 迁都次数 < max（默认 2）
## - 应用：旧首都 is_capital=false → 新首都 is_capital=true → 计数 +1
## - 广播 capital_relocated
## 返回 {success, reason, remaining_relocations}。
## remaining 含义：max - count（成功后已扣减；失败时反映当前剩余次数）。
func relocate_player_capital(faction_id: String, new_capital_city_id: String) -> Dictionary:
	var max_relocations: int = int(DataManager.get_balance_param("capital.player_max_relocations"))
	var current_count: int = int(_player_relocation_counts.get(faction_id, 0))

	if not _city_states.has(new_capital_city_id):
		return _make_relocation_result(false, REASON_INVALID_CITY, max_relocations - current_count)

	var city: Dictionary = _city_states[new_capital_city_id]
	if city["current_faction_id"] != faction_id:
		return _make_relocation_result(false, REASON_NOT_OWN_CITY, max_relocations - current_count)

	if current_count >= max_relocations:
		return _make_relocation_result(false, REASON_RELOCATION_LIMIT, 0)

	_apply_capital_relocation(faction_id, new_capital_city_id)
	var new_count: int = current_count + 1
	_player_relocation_counts[faction_id] = new_count
	SignalBus.capital_relocated.emit(faction_id, new_capital_city_id)
	return _make_relocation_result(true, REASON_OK, max_relocations - new_count)


## 取某 faction 已用迁都次数。
func get_player_relocation_count(faction_id: String) -> int:
	return int(_player_relocation_counts.get(faction_id, 0))


## 判定 faction 是否已被灭国（运行时持有的城市数为 0）。
## 注：仅作结构性判定。玩家「迁都用完后首都再失守」的隐性失败由 UI/GameManager 处理。
func is_faction_eliminated(faction_id: String) -> bool:
	return get_faction_city_states(faction_id).is_empty()


## AI 迁都：根据 faction.ai_capital_relocation_weight 自动选新首都。
## - weight=null（默认）：按 current_population 最高选
## - weight=Dictionary（策划后期可填 {city_id: priority_value}）：按权重最高选
## - 该 faction 无任何城市：返回空字符串（调用方应已先 is_faction_eliminated）
## 选中后设置该城 is_capital=true、广播 capital_relocated。返回选中的 city_id。
func relocate_ai_capital(faction_id: String) -> String:
	var available: Array = get_faction_city_states(faction_id)
	if available.is_empty():
		return ""

	var weight: Variant = DataManager.get_faction(faction_id).get("ai_capital_relocation_weight")
	var chosen_id: String = _pick_ai_capital_city(available, weight)
	_apply_capital_relocation(faction_id, chosen_id)
	SignalBus.capital_relocated.emit(faction_id, chosen_id)
	return chosen_id


# ----- 占领系统内部辅助 -----

## 把 faction 当前的首都（若有）翻为 is_capital=false，并把 new_city 标为 is_capital=true。
## 维持不变量「每国最多 1 个 is_capital=true」。
func _apply_capital_relocation(faction_id: String, new_capital_city_id: String) -> void:
	for state in get_faction_city_states(faction_id):
		if state.get("is_capital", false):
			state["is_capital"] = false
	_city_states[new_capital_city_id]["is_capital"] = true


func _make_relocation_result(success: bool, reason: String, remaining: int) -> Dictionary:
	return {
		"success": success,
		"reason": reason,
		"remaining_relocations": max(remaining, 0),
	}


## 在 available 城市数组里挑选 AI 新首都。
## weight 为 Dictionary 时按权重最高选；否则（含 null）按 current_population 最高选。
func _pick_ai_capital_city(available: Array, weight: Variant) -> String:
	if weight is Dictionary:
		var best: Dictionary = available[0]
		var best_w: float = float((weight as Dictionary).get(best["id"], 0))
		for state in available:
			var w: float = float((weight as Dictionary).get(state["id"], 0))
			if w > best_w:
				best = state
				best_w = w
		return best["id"]
	# 兜底（含 weight=null）：按 current_population 最高
	var best_pop: Dictionary = available[0]
	for state in available:
		if int(state.get("current_population", 0)) > int(best_pop.get("current_population", 0)):
			best_pop = state
	return best_pop["id"]


# ============= 回合结算 =============

## 每回合调用。递减建造队列、自动完成建造、推进人口增长，返回本回合事件摘要。
func process_turn(faction_id: String) -> Dictionary:
	var events: Dictionary = {"buildings_completed": [], "upgrades_completed": []}
	var cities: Array = get_faction_city_states(faction_id)
	for city in cities:
		var city_id: String = str(city["id"])
		_process_build_queue(city_id, events)
		_process_population_growth(city_id)
	return events


## 递减建造队列，turns_remaining <= 0 时自动完成建造/升级。
func _process_build_queue(city_id: String, events: Dictionary) -> void:
	var city: Dictionary = _city_states.get(city_id, {})
	if city.is_empty():
		return
	var queue: Array = city["build_queue"] as Array
	var completed_indices: Array = []
	for i in range(queue.size()):
		var entry: Dictionary = queue[i] as Dictionary
		entry["turns_remaining"] = int(entry["turns_remaining"]) - 1
		if int(entry["turns_remaining"]) <= 0:
			completed_indices.append(i)
	# 倒序移除已完成项（避免索引偏移）
	for i in range(completed_indices.size() - 1, -1, -1):
		var idx: int = completed_indices[i]
		var entry: Dictionary = queue[idx] as Dictionary
		var bid: String = str(entry["building_id"])
		var city_state: Dictionary = _city_states[city_id]
		if _city_has_building(city_state, bid):
			# 已有该建筑 → 升级完成，提升等级
			for b in (city_state["buildings"] as Array):
				if b.get("building_id") == bid:
					b["level"] = int(b.get("level", 1)) + 1
					events["upgrades_completed"].append({"city_id": city_id, "building_id": bid, "level": b["level"]})
					SignalBus.building_completed.emit(city_id, bid, b["level"])
					break
		else:
			# 新建完成
			(city_state["buildings"] as Array).append({"building_id": bid, "level": 1})
			events["buildings_completed"].append({"city_id": city_id, "building_id": bid})
			SignalBus.building_completed.emit(city_id, bid, 1)
		queue.remove_at(idx)


## 人口增长（进度条制）+ 饥荒检测。
## 增长周期 = growth_base_period × (1/food_ratio) × (1/season_mod) × (1/stability_mod)
##   food_ratio = 城市粮食净产出 / (人口 × food_consume_per_pop)，兜底 0.5
##   season_mod: spring 1.0 / summer 1.0 / autumn 1.2 / winter 0.7
##   stability_mod = growth_stability_base + stability × growth_stability_per_point
## 每回合 progress += 1/period，满 1.0 则 pop += 1。
## 饥荒：粮食净产出 < 0 时每回合减 famine_pop_loss 人口（最低 1）。
func _process_population_growth(city_id: String) -> void:
	var city: Dictionary = _city_states.get(city_id, {})
	if city.is_empty():
		return
	var pop: int = int(city.get("current_population", 0))
	if pop <= 0:
		return

	# 计算城市粮食净产出
	var prod: Dictionary = get_city_production(city_id)
	var season: String = get_current_season(GameManager.get_current_turn())
	var season_prod: Dictionary = _apply_season_modifier(prod, season)
	var net_food: int = int(season_prod.get("food", 0))

	# 饥荒检测：净产出 < 0
	if net_food < 0:
		var famine_loss: int = int(DataManager.get_balance_param("population.famine_pop_loss"))
		city["current_population"] = max(1, pop - famine_loss)
		city["growth_progress"] = 0.0
		return

	# 人口已到上限则不增长
	var city_level: int = int(city.get("city_level", 1))
	var levels_cfg: Dictionary = DataManager.get_balance_param("city_levels")
	var level_cfg: Dictionary = levels_cfg.get(str(city_level), {})
	var pop_cap: int = int(level_cfg.get("population_capacity", 0))
	if pop_cap > 0 and pop >= pop_cap:
		return

	# 粮食比 = 净产出 / (人口消耗)
	var food_consume_per_pop: int = int(DataManager.get_balance_param("population.food_consume_per_pop"))
	var total_consumption: int = pop * food_consume_per_pop
	var food_ratio: float = float(net_food) / float(max(total_consumption, 1))
	food_ratio = clampf(food_ratio, 0.5, 3.0)

	# 季节修正
	var growth_season_mod: Dictionary = DataManager.get_balance_param("population.growth_season_mod")
	var season_mod: float = float(growth_season_mod.get(season, 1.0))
	season_mod = maxf(season_mod, 0.1)

	# 安定度修正（暂用基础值，Phase 2 接入实际安定度）
	var stability_base: float = float(DataManager.get_balance_param("population.growth_stability_base"))
	var stability_per_point: float = float(DataManager.get_balance_param("population.growth_stability_per_point"))
	var stability_mod: float = stability_base + 50.0 * stability_per_point  # 默认安定度 50
	stability_mod = maxf(stability_mod, 0.1)

	# 增长周期
	var base_period: float = float(DataManager.get_balance_param("population.growth_base_period"))
	var period: float = base_period * (1.0 / food_ratio) * (1.0 / season_mod) * (1.0 / stability_mod)
	period = clampf(period, 2.0, 20.0)

	# 进度累加
	var progress: float = float(city.get("growth_progress", 0.0))
	progress += 1.0 / period
	if progress >= 1.0:
		city["current_population"] = pop + 1
		city["growth_progress"] = progress - 1.0
	else:
		city["growth_progress"] = progress


# ============= 建筑效果与产出 =============

## 获取指定 faction 的城市列表。
func get_faction_cities(faction_id: String) -> Array:
	return get_faction_city_states(faction_id)


## 返回城市本回合产出（已含建筑效果，未含季节/特产修正）。
## 百分比加成（*_bonus）与固定值加成（*_production）分别处理：
##   最终值 = 基础值 × (1 + Σ百分比) + Σ固定值
func get_city_production(city_id: String) -> Dictionary:
	var city: Dictionary = _city_states.get(city_id, {})
	if city.is_empty():
		return {}
	var prod: Dictionary = {
		"food": 0, "gold": 0, "wood": 0,
		"horse": 0, "refined_iron": 0,
		"craftsmen": 0, "building_materials": 0,
		"morale_bonus": 0, "defense_bonus": 0.0,
		"recruit_speed_bonus": 0.0, "tax_bonus": 0.0,
		"culture_production": 0,
		"max_food_production": 0, "national_grain_cap": 0,
	}
	# 基础产出（路径来自 balance_params.json 实际结构）
	var pop: int = int(city.get("current_population", 0))
	var food_per_pop: Variant = DataManager.get_balance_param("population.food_per_pop")
	var gold_per_pop: Variant = DataManager.get_balance_param("population.gold_per_pop")
	var base_food: int = int(pop * (float(food_per_pop) if food_per_pop != null else 3.0))
	var base_gold: int = int(pop * (float(gold_per_pop) if gold_per_pop != null else 10.0))
	prod["food"] = base_food
	prod["gold"] = base_gold
	prod["wood"] = int(DataManager.get_balance_param("resources.city_base_wood"))
	# 收集建筑效果：百分比加成单独累加，固定值直接加
	var food_bonus: float = 0.0
	var gold_bonus: float = 0.0
	for b in city.get("buildings", []):
		var bid: String = str(b.get("building_id", ""))
		var bdata: Dictionary = DataManager.get_building(bid)
		if bdata.is_empty():
			continue
		var effects: Dictionary = bdata.get("effects", {})
		var level: int = int(b.get("level", 1))
		for key in effects:
			var val: Variant = effects[key]
			if not (val is int or val is float):
				continue
			# 百分比加成：food_production_bonus / gold_production_bonus
			if key == "food_production_bonus":
				food_bonus += float(val) * level
			elif key == "gold_production_bonus":
				gold_bonus += float(val) * level
			elif prod.has(key):
				# 固定值加成：wood_production / craftsmen_production / morale_bonus 等
				prod[key] += val * level
	# 应用百分比加成（基础值 × 累加倍率）
	prod["food"] = int(base_food * (1.0 + food_bonus))
	prod["gold"] = int(base_gold * (1.0 + gold_bonus))
	# 粮仓 max_food_production 上限截断
	var max_fp: int = int(prod.get("max_food_production", 0))
	if max_fp > 0 and prod["food"] > max_fp:
		prod["food"] = max_fp
	# 特产加成
	var sr: Variant = city.get("special_resource", null)
	if sr != null:
		_apply_special_resource_modifier(prod, str(sr))
	# 粮食消耗（人口吃饭）
	var food_consume_per_pop: int = int(DataManager.get_balance_param("population.food_consume_per_pop"))
	prod["food"] -= pop * food_consume_per_pop
	return prod


## 获取指定 faction 所有城市的总产出（已含季节修正）。
func get_faction_total_production(faction_id: String) -> Dictionary:
	var total: Dictionary = {
		"food": 0, "gold": 0, "wood": 0,
		"horse": 0, "refined_iron": 0,
		"craftsmen": 0, "building_materials": 0,
	}
	var season: String = get_current_season(GameManager.get_current_turn())
	var cities: Array = get_faction_city_states(faction_id)
	for city in cities:
		var city_prod: Dictionary = get_city_production(str(city["id"]))
		if city_prod.is_empty():
			continue
		var season_prod: Dictionary = _apply_season_modifier(city_prod, season)
		total["food"] += int(season_prod.get("food", 0))
		total["gold"] += int(season_prod.get("gold", 0))
		total["wood"] += int(season_prod.get("wood", 0))
		total["horse"] += int(season_prod.get("horse", 0))
		total["refined_iron"] += int(season_prod.get("refined_iron", 0))
		total["craftsmen"] += int(season_prod.get("craftsmen", 0))
		total["building_materials"] += int(season_prod.get("building_materials", 0))
	return total


## 根据回合数返回当前季节。
func get_current_season(turn_number: int) -> String:
	var seasons_cfg: Dictionary = DataManager.get_balance_param("season_cycle")
	var seasons: Array = seasons_cfg.get("seasons", ["spring", "summer", "autumn", "winter"])
	var idx: int = (turn_number - 1) % seasons.size()
	return str(seasons[idx])


## 应用季节修正（返回新字典，不修改原字典）。
func _apply_season_modifier(prod: Dictionary, season: String) -> Dictionary:
	var result: Dictionary = prod.duplicate()
	var food_mod: Dictionary = DataManager.get_balance_param("resources.season_food_mod")
	var gold_mod: Dictionary = DataManager.get_balance_param("resources.season_gold_mod")
	var wood_mod: Dictionary = DataManager.get_balance_param("resources.season_wood_mod")
	var craftsmen_mod: Dictionary = DataManager.get_balance_param("resources.season_craftsmen_mod")
	var bm_mod: Dictionary = DataManager.get_balance_param("resources.season_building_materials_mod")
	result["food"] = int(result["food"] * float(food_mod.get(season, 1.0)))
	result["gold"] = int(result["gold"] * float(gold_mod.get(season, 1.0)))
	result["wood"] = int(result["wood"] * float(wood_mod.get(season, 1.0)))
	result["craftsmen"] = int(result["craftsmen"] * float(craftsmen_mod.get(season, 1.0)))
	result["building_materials"] = int(result["building_materials"] * float(bm_mod.get(season, 1.0)))
	return result


## 应用特产加成（直接修改 prod）。
func _apply_special_resource_modifier(prod: Dictionary, special_resource: String) -> void:
	var sr_mods: Dictionary = DataManager.get_balance_param("resources.special_resource_mod")
	var mod: Dictionary = sr_mods.get(special_resource, {})
	for key in mod:
		if prod.has(key):
			var factor: float = float(mod[key])
			prod[key] = int(prod[key] * factor)
	# 马匹/精铁特产城市直接产出对应资源
	var sr_production: Dictionary = DataManager.get_balance_param("resources.special_resources")
	if sr_production.has(special_resource):
		var sr_data: Dictionary = sr_production[special_resource]
		if not prod.has(special_resource):
			prod[special_resource] = int(sr_data.get("city_base_production", 0))


# ============= 内部 =============

func _initialize_states() -> void:
	_city_states.clear()
	for city_data in DataManager.get_all_cities():
		var state: Dictionary = city_data.duplicate(true)
		state["current_faction_id"] = city_data["faction_id"]
		state["buildings"] = []
		state["build_queue"] = []
		state["current_population"] = int(city_data.get("initial_population", 0))
		state["growth_progress"] = 0.0
		_city_states[city_data["id"]] = state


func _build_faction_index() -> void:
	_states_by_faction.clear()
	for city_id in _city_states:
		var state: Dictionary = _city_states[city_id]
		var fid: String = state["current_faction_id"]
		if not _states_by_faction.has(fid):
			_states_by_faction[fid] = []
		_states_by_faction[fid].append(state)


## 增量更新 _states_by_faction：把 city 从旧 faction 移到新 faction。
## 供 change_ownership 调用，避免全量重建索引。
func _move_city_in_faction_index(city: Dictionary, old_faction_id: String, new_faction_id: String) -> void:
	if _states_by_faction.has(old_faction_id):
		(_states_by_faction[old_faction_id] as Array).erase(city)
	if not _states_by_faction.has(new_faction_id):
		_states_by_faction[new_faction_id] = []
	(_states_by_faction[new_faction_id] as Array).append(city)


## 该城市的 buildings 是否已包含 building_id
func _city_has_building(city: Dictionary, building_id: String) -> bool:
	for entry in (city["buildings"] as Array):
		if entry.get("building_id") == building_id:
			return true
	return false


## 该城市的 build_queue 是否已包含 building_id
func _city_has_in_queue(city: Dictionary, building_id: String) -> bool:
	for entry in (city["build_queue"] as Array):
		if entry.get("building_id") == building_id:
			return true
	return false


## 该 faction 持有该 building_id 的总数（已建 + 在建）。
## 用于每国限建校验（决策 33/35 解读 B）。
func _count_faction_building(faction_id: String, building_id: String) -> int:
	var count := 0
	for state in get_faction_city_states(faction_id):
		if _city_has_building(state, building_id):
			count += 1
		if _city_has_in_queue(state, building_id):
			count += 1
	return count


## 该城市的 buildings 中该 building_id 的当前等级。0 表示未建。
func _city_building_level(city: Dictionary, building_id: String) -> int:
	for entry in (city["buildings"] as Array):
		if entry.get("building_id") == building_id:
			return int(entry.get("level", 0))
	return 0


## 升级到下一级的成本（基础成本 × multiplier^current_level）。
## 返回 [cost_gold, cost_wood]，已 round + int 化。
func _calculate_upgrade_cost(building: Dictionary, current_level: int) -> Array:
	var multiplier: float = float(building.get("upgrade_cost_multiplier", 1.5))
	var factor: float = pow(multiplier, current_level)
	var cost_gold: int = int(round(float(building.get("cost_gold", 0)) * factor))
	var cost_wood: int = int(round(float(building.get("cost_wood", 0)) * factor))
	return [cost_gold, cost_wood]


## 该城市 build_queue 中「新建」类型的项数（即 building_id 未在 buildings 中）。
## 用于槽位校验：升级中的项已经在 buildings 里，不重复占槽。
func _count_new_build_in_queue(city: Dictionary) -> int:
	var count := 0
	for entry in (city["build_queue"] as Array):
		if not _city_has_building(city, entry.get("building_id", "")):
			count += 1
	return count
