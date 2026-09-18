class_name StrategicAI

## 大地图战略 AI：操作本势力战略单位移动/攻城/交战。
## 由 MilitaryAI.evaluate_military() 在征兵后调用。


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
		var target: Vector2i = _nearest_axial(Vector2i(int(unit.get("q", 0)), int(unit.get("r", 0))), targets)
		StrategicMapManager.move_toward(unit_id, target)
		_try_attack_adjacent_enemy(unit_id, faction_id)
		_try_attack_adjacent_enemy_city(unit_id, faction_id)


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
	var best_id: String = ""
	var best_hp: int = 999999
	for enemy: Dictionary in StrategicMapManager.get_units():
		var enemy_fid: String = str(enemy.get("faction_id", ""))
		if not _can_engage(faction_id, enemy_fid):
			continue
		var e_pos: Vector2i = Vector2i(int(enemy.get("q", 0)), int(enemy.get("r", 0)))
		if HexAxial.hex_distance_hex(my_pos, e_pos) > atk_range:
			continue
		var hp: int = int(enemy.get("hp", 0))
		if hp < best_hp:
			best_hp = hp
			best_id = str(enemy.get("id", ""))
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
	for city in CityManager.get_all_city_states():
		var owner: String = str(city.get("current_faction_id", ""))
		if not _can_engage(faction_id, owner):
			continue
		if owner == "neutral" and int(city.get("city_level", 1)) < int(DataManager.get_balance_param("ai_strategic").get("neutral_city_min_level_to_attack", 3)):
			continue
		var c_pos: Vector2i = HexAxial.offset_odd_r_to_axial(int(city.get("hex_q", 0)), int(city.get("hex_r", 0)))
		if HexAxial.hex_distance_hex(my_pos, c_pos) > atk_range:
			continue
		return bool(StrategicMapManager.try_attack_city(unit_id, str(city.get("id", ""))).get("ok", false))
	return false


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
