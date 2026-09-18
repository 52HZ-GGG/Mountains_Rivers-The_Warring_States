class_name StrategicAI

## 大地图战略 AI：操作本势力战略单位移动/攻城/交战。
## 由 MilitaryAI.evaluate_military() 在征兵后调用。
## 目标评分走 AiCombatScoring（统一规范 §8）。

const ScoringLib := preload("res://scripts/systems/ai_combat_scoring.gd")
const SiegeLib := preload("res://scripts/systems/siege_resolver.gd")


static func evaluate_strategic_units(faction_id: String) -> void:
	var personality: Dictionary = DataManager.get_ai_personality(faction_id)
	if personality.get("is_passive", false):
		return
	var units: Array[Dictionary] = StrategicMapManager.get_faction_units(faction_id)
	if units.is_empty():
		return
	# 未与任何人开战则不出兵
	var at_war: bool = false
	for other in GameManager.FACTION_IDS:
		if other != faction_id and DiplomacySystem.are_at_war(faction_id, other):
			at_war = true
			break
	if not at_war:
		return
	var targets: Array = _enemy_target_axials(faction_id)
	if targets.is_empty():
		return
	# 每回合最多操作 N 支（ai_strategic.action_budget_per_turn），避免大地图单位多了拖慢 AI 回合
	var action_budget: int = int(DataManager.get_balance_param("ai_strategic").get("action_budget_per_turn", 5))
	for unit_v in units:
		if action_budget <= 0:
			break
		var unit: Dictionary = unit_v as Dictionary
		var unit_id: String = str(unit.get("id", ""))
		if bool(unit.get("acted", false)):
			continue
		action_budget -= 1
		if _try_attack_adjacent_enemy(unit_id, faction_id):
			continue
		if _try_attack_adjacent_enemy_city(unit_id, faction_id):
			continue
		var target: Vector2i = _best_move_target(unit, faction_id, targets)
		StrategicMapManager.move_toward(unit_id, target)
		_try_attack_adjacent_enemy(unit_id, faction_id)
		_try_attack_adjacent_enemy_city(unit_id, faction_id)


static func _best_move_target(unit: Dictionary, faction_id: String, targets: Array) -> Vector2i:
	var from: Vector2i = Vector2i(int(unit.get("q", 0)), int(unit.get("r", 0)))
	if targets.is_empty():
		return from
	# 优先评分最高的敌城/敌军（残血/近距），而非仅最近
	var candidates: Array = []
	for t: Variant in targets:
		var ax: Vector2i = t as Vector2i
		var dist: int = HexAxial.hex_distance_hex(from, ax)
		candidates.append({"id": "%d_%d" % [ax.x, ax.y], "hp": 0, "max_hp": 1, "dist": dist, "axial": ax})
	# 用 unit 评分仅作距离权重：取 dist 最小的前 3 个里第一个
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["dist"]) < int(b["dist"]))
	return (candidates[0] as Dictionary).get("axial", from) as Vector2i


static func _enemy_target_axials(faction_id: String) -> Array:
	var out: Array = []
	for city in CityManager.get_all_city_states():
		var owner: String = str(city.get("current_faction_id", ""))
		if owner == faction_id or owner == "":
			continue
		# 仅进攻战争中的敌国；中立城默认不打（避免和平期乱跑）
		if owner == "neutral":
			continue
		if not DiplomacySystem.are_at_war(faction_id, owner):
			continue
		out.append(HexAxial.offset_odd_r_to_axial(int(city.get("hex_q", 0)), int(city.get("hex_r", 0))))
	for enemy_unit: Dictionary in StrategicMapManager.get_units():
		var enemy_fid: String = str(enemy_unit.get("faction_id", ""))
		if enemy_fid == faction_id or enemy_fid == "neutral":
			continue
		if not DiplomacySystem.are_at_war(faction_id, enemy_fid):
			continue
		out.append(Vector2i(int(enemy_unit.get("q", 0)), int(enemy_unit.get("r", 0))))
	return out


static func _can_engage(faction_id: String, target_faction_id: String) -> bool:
	if target_faction_id == faction_id:
		return false
	if target_faction_id == "neutral" or target_faction_id == "":
		return true
	return DiplomacySystem.are_at_war(faction_id, target_faction_id)


static func _try_attack_adjacent_enemy(unit_id: String, faction_id: String) -> bool:
	var me: Dictionary = StrategicMapManager.get_unit(unit_id)
	if me.is_empty():
		return false
	var my_pos: Vector2i = Vector2i(int(me.get("q", 0)), int(me.get("r", 0)))
	var my_type: Dictionary = DataManager.get_unit_type(str(me.get("unit_type_id", "")))
	var atk_range: int = int(my_type.get("range", 1))
	var candidates: Array = []
	for enemy: Dictionary in StrategicMapManager.get_units():
		var enemy_fid: String = str(enemy.get("faction_id", ""))
		if not _can_engage(faction_id, enemy_fid):
			continue
		var e_pos: Vector2i = Vector2i(int(enemy.get("q", 0)), int(enemy.get("r", 0)))
		var dist: int = HexAxial.hex_distance_hex(my_pos, e_pos)
		if dist > atk_range:
			continue
		candidates.append({
			"id": str(enemy.get("id", "")),
			"hp": int(enemy.get("hp", 0)),
			"max_hp": int(enemy.get("max_hp", 1)),
			"dist": dist,
		})
	if candidates.is_empty():
		return false
	# 统一规范 §8：残血优先 + 近距
	var best_id: String = ScoringLib.pick_best_unit_target(candidates)
	if best_id == "":
		return false
	return bool(StrategicMapManager.try_attack_unit(unit_id, best_id).get("ok", false))


static func _try_attack_adjacent_enemy_city(unit_id: String, faction_id: String) -> bool:
	var me: Dictionary = StrategicMapManager.get_unit(unit_id)
	if me.is_empty():
		return false
	var my_pos: Vector2i = Vector2i(int(me.get("q", 0)), int(me.get("r", 0)))
	var my_type: Dictionary = DataManager.get_unit_type(str(me.get("unit_type_id", "")))
	var atk_range: int = int(my_type.get("range", 1))
	var attacker_is_siege: bool = SiegeLib.is_siege_unit(str(me.get("unit_type_id", "")))
	var candidates: Array = []
	for city in CityManager.get_all_city_states():
		var owner: String = str(city.get("current_faction_id", ""))
		if not _can_engage(faction_id, owner):
			continue
		if owner == "neutral" and int(city.get("city_level", 1)) < int(DataManager.get_balance_param("ai_strategic").get("neutral_city_min_level_to_attack", 3)):
			continue
		var city_id: String = str(city.get("id", ""))
		var c_pos: Vector2i = HexAxial.offset_odd_r_to_axial(int(city.get("hex_q", 0)), int(city.get("hex_r", 0)))
		var dist: int = HexAxial.hex_distance_hex(my_pos, c_pos)
		if dist > atk_range:
			continue
		candidates.append({
			"id": city_id,
			"city_level": int(city.get("city_level", 1)),
			"hp": CityManager.get_city_hp(city_id),
			"max_hp": CityManager.get_city_max_hp(city_id),
			"dist": dist,
		})
	if candidates.is_empty():
		return false
	var best_city: String = ScoringLib.pick_best_city_target(candidates, attacker_is_siege)
	if best_city == "":
		return false
	return bool(StrategicMapManager.try_attack_city(unit_id, best_city).get("ok", false))


static func _nearest_axial(from: Vector2i, candidates: Array) -> Vector2i:
	var best: Vector2i = from
	var best_d: int = 999999
	for item: Variant in candidates:
		var cell: Vector2i = item as Vector2i
		var d: int = HexAxial.hex_distance_hex(from, cell)
		if d < best_d:
			best_d = d
			best = cell
	return best
