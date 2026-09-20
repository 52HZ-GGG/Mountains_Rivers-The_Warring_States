extends Node

## 大地图战略单位系统。
## 单位从城市生产后出现在大地图六角格上；移动/战斗/攻城均在大地图完成（无独立演武场景）。
## 坐标与城市一致：odd-R 偏移 (col=q, row=r)，邻接/距离用轴向转换。

signal units_changed
signal unit_moved(unit_id: String, from: Vector2i, to: Vector2i)
signal unit_attacked(attacker_id: String, defender_id: String, damage: int)
signal city_sieged(city_id: String, attacker_id: String, damage: int)

const HexLib := preload("res://scripts/systems/hex_axial.gd")
const CombatLib := preload("res://scripts/systems/combat_resolver.gd")
const UnitStateLib := preload("res://scripts/systems/unit_state.gd")
const CtxLib := preload("res://scripts/systems/combat_ctx_builder.gd")
const SiegeLib := preload("res://scripts/systems/siege_resolver.gd")
const MoveLib := preload("res://scripts/systems/movement_reach.gd")
const UnitMoraleRules := preload("res://scripts/systems/unit_morale_rules.gd")

var _units: Array[Dictionary] = []
var _next_unit_seq: int = 1
var _selected_unit_id: String = ""
var _combat: RefCounted = CombatLib.new()


func _ready() -> void:
	SignalBus.turn_started.connect(_on_turn_started)


func reset() -> void:
	_units.clear()
	_next_unit_seq = 1
	_selected_unit_id = ""
	units_changed.emit()


func _on_turn_started(_turn_number: int, faction_id: String) -> void:
	begin_faction_turn(faction_id)


func begin_faction_turn(faction_id: String) -> void:
	for u: Dictionary in _units:
		if str(u["faction_id"]) != faction_id:
			continue
		UnitMoraleRules.process_turn_morale(u, _is_unit_in_own_city(u))
		u["acted"] = false
		u["mp"] = UnitMoraleRules.effective_mp(u)
	units_changed.emit()


func _is_unit_in_own_city(unit: Dictionary) -> bool:
	var city_id: String = _city_id_at_offset(int(unit.get("col", unit.get("q", -1))), int(unit.get("row", unit.get("r", -1))))
	if city_id == "":
		return false
	var city: Dictionary = CityManager.get_city_state(city_id)
	return str(city.get("current_faction_id", "")) == str(unit.get("faction_id", ""))


# ============= 查询 =============

func get_units() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for u: Dictionary in _units:
		out.append(u.duplicate(true))
	return out


func get_unit(unit_id: String) -> Dictionary:
	for u: Dictionary in _units:
		if str(u["id"]) == unit_id:
			return u.duplicate(true)
	return {}


func get_unit_at_offset(col: int, row: int) -> Dictionary:
	var axial: Vector2i = HexLib.offset_odd_r_to_axial(col, row)
	return get_unit_at_axial(axial)


func get_unit_at_axial(axial: Vector2i) -> Dictionary:
	for u: Dictionary in _units:
		if int(u["q"]) == axial.x and int(u["r"]) == axial.y:
			return u.duplicate(true)
	return {}


func get_faction_units(faction_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for u: Dictionary in _units:
		if str(u["faction_id"]) == faction_id:
			out.append(u.duplicate(true))
	return out


func get_selected_unit_id() -> String:
	return _selected_unit_id


func select_unit(unit_id: String) -> void:
	_selected_unit_id = unit_id
	units_changed.emit()


func clear_selection() -> void:
	_selected_unit_id = ""
	units_changed.emit()


# ============= 生产 =============

## 在城市格生产战略单位。
## 规则与演武一致：**一格最多一支军队**（不叠放实体）。
## 若城格已有己方同兵种 → 合并 count；否则落到邻接空格。
func spawn_unit_at_city(faction_id: String, unit_type_id: String, col: int, row: int, count: int = 1) -> Dictionary:
	var type_data: Dictionary = DataManager.get_unit_type(unit_type_id)
	if type_data.is_empty():
		return {"success": false, "reason": "INVALID_UNIT", "unit_id": ""}
	var hp: int = int(type_data.get("hp", 100)) * maxi(1, count)
	var speed: int = int(type_data.get("speed", 3))
	var axial: Vector2i = HexLib.offset_odd_r_to_axial(col, row)
	# 1) 同格己方同兵种：合并编制，不新开实体
	var here: Dictionary = get_unit_at_axial(axial)
	if not here.is_empty() and str(here.get("faction_id", "")) == faction_id and str(here.get("unit_type_id", "")) == unit_type_id:
		here["count"] = int(here.get("count", 1)) + maxi(1, count)
		here["hp"] = int(here.get("hp", 0)) + hp
		units_changed.emit()
		return {"success": true, "unit_id": str(here.get("id", "")), "merged": true}
	# 2) 城格被占：找邻接空格（一格一军）
	var place: Vector2i = axial
	if not here.is_empty():
		var free_cell: Vector2i = _find_free_adjacent(axial)
		if free_cell == Vector2i(-9999, -9999):
			return {"success": false, "reason": "HEX_OCCUPIED", "unit_id": ""}
		place = free_cell
	# UnitState v3 权威字段（统一规范 §3）
	var unit_id: String = "su_%d_%s_%s" % [_next_unit_seq, faction_id, unit_type_id]
	_next_unit_seq += 1
	var off: Vector2i = HexLib.axial_to_offset_odd_r(place.x, place.y)
	var unit: Dictionary = UnitStateLib.make(
		faction_id, unit_type_id, place.x, place.y, hp, speed, maxi(1, count), unit_id, off.x, off.y
	)
	_units.append(unit)
	units_changed.emit()
	return {"success": true, "unit_id": unit_id, "merged": false, "axial": place}


func _find_free_adjacent(origin: Vector2i) -> Vector2i:
	var map_size: Vector2i = DataManager.get_big_map_size()
	if map_size.x <= 0:
		map_size = Vector2i(100, 70)
	for n: Vector2i in HexLib.neighbors_hex(origin):
		if n.x < 0 or n.y < 0:
			continue
		var off: Vector2i = HexLib.axial_to_offset_odd_r(n.x, n.y)
		if off.x < 0 or off.y < 0 or off.x >= map_size.x or off.y >= map_size.y:
			continue
		if get_unit_at_axial(n).is_empty():
			return n
	return Vector2i(-9999, -9999)


# ============= 移动 =============

func get_reachable_cells(unit_id: String) -> Dictionary:
	var result: Dictionary = {}
	var unit: Dictionary = _get_unit_ref(unit_id)
	if unit.is_empty():
		return result
	var start: Vector2i = Vector2i(int(unit["q"]), int(unit["r"]))
	var mp: int = int(unit.get("mp", 0))
	if mp <= 0:
		return result
	var unit_type_id: String = str(unit["unit_type_id"])
	var faction_id: String = str(unit["faction_id"])
	var map_size: Vector2i = DataManager.get_big_map_size()
	if map_size.x <= 0 or map_size.y <= 0:
		map_size = Vector2i(100, 70)
	# 统一规范 §6：Dijkstra + ZOC + 地形限制走 MovementReach
	var occupied := func(axial: Vector2i) -> bool:
		return not get_unit_at_axial(axial).is_empty()
	return MoveLib.dijkstra_reachable(
		start,
		mp,
		unit_type_id,
		faction_id,
		_units,
		Vector2i.ZERO,
		Vector2i(map_size.x - 1, map_size.y - 1),
		occupied
	)


func try_move_unit(unit_id: String, dest_axial: Vector2i, allow_ai: bool = false) -> Dictionary:
	var unit: Dictionary = _get_unit_ref(unit_id)
	if unit.is_empty():
		return {"ok": false, "reason": "NO_UNIT"}
	if not allow_ai and str(unit["faction_id"]) != GameManager.get_player_faction():
		return {"ok": false, "reason": "NOT_PLAYER"}
	if bool(unit.get("acted", false)):
		return {"ok": false, "reason": "ALREADY_ACTED"}
	var reach: Dictionary = get_reachable_cells(unit_id)
	if not reach.has(dest_axial):
		return {"ok": false, "reason": "UNREACHABLE"}
	return _apply_move(unit, dest_axial, int(reach[dest_axial]))


func _apply_move(unit: Dictionary, dest_axial: Vector2i, cost: int) -> Dictionary:
	var unit_id: String = str(unit["id"])
	var from: Vector2i = Vector2i(int(unit["q"]), int(unit["r"]))
	unit["q"] = dest_axial.x
	unit["r"] = dest_axial.y
	var offset: Vector2i = HexLib.axial_to_offset_odd_r(dest_axial.x, dest_axial.y)
	unit["col"] = offset.x
	unit["row"] = offset.y
	unit["mp"] = int(unit.get("mp", 0)) - cost
	if int(unit["mp"]) < 0:
		unit["mp"] = 0
	# 仍有移动力可继续行动
	unit["acted"] = false
	# 无血量建筑敌占：停留即失效（决策 #124）
	_apply_building_occupation(unit, dest_axial)
	# 移动到敌城且城防为 0 → 占领
	var city_id: String = _city_id_at_offset(offset.x, offset.y)
	if city_id != "":
		_try_capture_city_if_clear(str(unit["faction_id"]), city_id)
	# 关隘：结构破且无驻军时进驻易主（统一占领规则）
	if PassManager != null and PassManager.has_pass(dest_axial):
		_try_capture_pass_if_clear(str(unit["faction_id"]), dest_axial)
	unit_moved.emit(unit_id, from, dest_axial)
	units_changed.emit()
	return {"ok": true}


func _try_capture_pass_if_clear(faction_id: String, axial: Vector2i) -> void:
	if PassManager == null:
		return
	if not PassManager.has_pass(axial):
		return
	if PassManager.get_pass_hp(axial) > 0:
		return
	PassManager.try_capture_pass(axial, faction_id)


## 敌军踏上无血量建筑格 → 独立占领（防御建筑）或标记失效
func _apply_building_occupation(unit: Dictionary, axial: Vector2i) -> void:
	var b: Dictionary = CityManager.get_building_at_hex(axial)
	if b.is_empty():
		return
	var fid: String = str(unit["faction_id"])
	if CityManager.is_defense_building_hex(axial):
		CityManager.try_capture_building_at_hex(axial, fid, false)
		return
	var city_id: String = str(b.get("city_id", ""))
	if city_id == "":
		return
	var city: Dictionary = CityManager.get_city_state(city_id)
	if city.is_empty():
		return
	if str(city.get("current_faction_id", "")) == fid:
		return
	CityManager.disable_building_at_hex(axial)


## 一步移动到目标方向最近可达格（供 AI 用）。
func move_toward(unit_id: String, target_axial: Vector2i) -> Dictionary:
	var unit: Dictionary = _get_unit_ref(unit_id)
	if unit.is_empty() or bool(unit.get("acted", false)):
		return {"ok": false, "reason": "NO_ACTION"}
	var reach: Dictionary = get_reachable_cells(unit_id)
	if reach.is_empty():
		return {"ok": false, "reason": "NO_REACH"}
	var best_cell: Vector2i = Vector2i(int(unit["q"]), int(unit["r"]))
	var best_dist: int = HexLib.hex_distance_hex(best_cell, target_axial)
	var best_cost: int = 0
	for cell: Vector2i in reach:
		var dist: int = HexLib.hex_distance_hex(cell, target_axial)
		if dist < best_dist:
			best_dist = dist
			best_cell = cell
			best_cost = int(reach[cell])
	if best_cell == Vector2i(int(unit["q"]), int(unit["r"])):
		return {"ok": false, "reason": "NO_CLOSER"}
	return _apply_move(unit, best_cell, best_cost)


# ============= 战斗 =============

func try_attack_unit(attacker_id: String, defender_id: String) -> Dictionary:
	var attacker: Dictionary = _get_unit_ref(attacker_id)
	var defender: Dictionary = _get_unit_ref(defender_id)
	if attacker.is_empty() or defender.is_empty():
		return {"ok": false, "reason": "NO_UNIT"}
	if str(attacker["faction_id"]) == str(defender["faction_id"]):
		return {"ok": false, "reason": "SAME_FACTION"}
	# 决策 #89：未宣战禁止交互
	if not DiplomacySystem.are_at_war(str(attacker["faction_id"]), str(defender["faction_id"])):
		return {"ok": false, "reason": "NOT_AT_WAR"}
	if bool(attacker.get("acted", false)):
		return {"ok": false, "reason": "ALREADY_ACTED"}
	var a_pos: Vector2i = Vector2i(int(attacker["q"]), int(attacker["r"]))
	var d_pos: Vector2i = Vector2i(int(defender["q"]), int(defender["r"]))
	var a_type: Dictionary = DataManager.get_unit_type(str(attacker["unit_type_id"]))
	var range: int = int(a_type.get("range", 1))
	if HexLib.hex_distance_hex(a_pos, d_pos) > range:
		return {"ok": false, "reason": "OUT_OF_RANGE"}
	var dmg: int = _compute_unit_damage(attacker, defender)
	defender["hp"] = int(defender["hp"]) - dmg
	attacker["acted"] = true
	attacker["mp"] = 0
	var counter_dmg: int = 0
	if int(defender["hp"]) > 0:
		counter_dmg = _try_counter_attack(attacker, defender)
	if int(defender["hp"]) <= 0:
		_apply_kill_morale(attacker, defender)
		_remove_unit(str(defender["id"]))
	unit_attacked.emit(attacker_id, defender_id, dmg)
	units_changed.emit()
	return {"ok": true, "damage": dmg, "counter_damage": counter_dmg}


## 攻击辖区格上的防御建筑（墙/塔/瓮城）— 共享 SiegeResolver
func try_attack_building(attacker_id: String, target_axial: Vector2i) -> Dictionary:
	var attacker: Dictionary = _get_unit_ref(attacker_id)
	if attacker.is_empty():
		return {"ok": false, "reason": "NO_UNIT"}
	if bool(attacker.get("acted", false)):
		return {"ok": false, "reason": "ALREADY_ACTED"}
	var b: Dictionary = CityManager.get_building_at_hex(target_axial)
	if b.is_empty() or not CityManager.is_defense_building_hex(target_axial):
		return {"ok": false, "reason": "NOT_DEFENSE_BUILDING"}
	if CityManager.is_hex_passable_for_units(target_axial):
		return {"ok": false, "reason": "ALREADY_BREACHED"}
	var a_pos: Vector2i = Vector2i(int(attacker["q"]), int(attacker["r"]))
	var a_type: Dictionary = DataManager.get_unit_type(str(attacker["unit_type_id"]))
	var range: int = int(a_type.get("range", 1))
	if HexLib.hex_distance_hex(a_pos, target_axial) > range:
		return {"ok": false, "reason": "OUT_OF_RANGE"}
	var siege_result: Dictionary = SiegeLib.compute_fortification_attack(attacker, target_axial)
	if not bool(siege_result.get("ok", false)):
		return siege_result
	attacker["acted"] = true
	attacker["mp"] = 0
	units_changed.emit()
	return {
		"ok": true,
		"damage": int(siege_result.get("damage", 0)),
		"destroyed": bool(siege_result.get("destroyed", false)),
		"remaining_hp": int(siege_result.get("remaining_hp", 0)),
		"building_id": str(siege_result.get("building_id", b.get("building_id", ""))),
	}


## 攻击关隘结构（共享 SiegeResolver，含地形修正）
func try_attack_pass(unit_id: String, pass_axial: Vector2i) -> Dictionary:
	var unit: Dictionary = _get_unit_ref(unit_id)
	if unit.is_empty():
		return {"ok": false, "reason": "NO_UNIT"}
	if PassManager == null or not PassManager.has_pass(pass_axial):
		return {"ok": false, "reason": "NO_PASS"}
	if bool(unit.get("acted", false)):
		return {"ok": false, "reason": "ALREADY_ACTED"}
	var owner: String = PassManager.get_pass_owner(pass_axial)
	var fid: String = str(unit["faction_id"])
	if owner == fid:
		return {"ok": false, "reason": "OWN_PASS"}
	# 有归属且非中立/己方时需宣战
	if owner != "" and owner != "neutral":
		if not DiplomacySystem.are_at_war(fid, owner):
			return {"ok": false, "reason": "NOT_AT_WAR"}
	var u_pos: Vector2i = Vector2i(int(unit["q"]), int(unit["r"]))
	var a_type: Dictionary = DataManager.get_unit_type(str(unit["unit_type_id"]))
	var range: int = int(a_type.get("range", 1))
	if HexLib.hex_distance_hex(u_pos, pass_axial) > range:
		return {"ok": false, "reason": "OUT_OF_RANGE"}
	var siege_result: Dictionary = SiegeLib.compute_pass_attack(unit, pass_axial)
	unit["acted"] = true
	unit["mp"] = 0
	units_changed.emit()
	return siege_result


## 近战反击：远程主动攻击不触发；远程被近战攻击时用 melee_attack（§2.4/§5.5）
func _try_counter_attack(attacker: Dictionary, defender: Dictionary) -> int:
	var a_type_id: String = str(attacker["unit_type_id"])
	var d_type_id: String = str(defender["unit_type_id"])
	var is_ranged_atk: bool = _combat.is_ranged_unit(a_type_id)
	if not _combat.should_trigger_counter(d_type_id, is_ranged_atk):
		return 0
	var c_atk_ctx: Dictionary = _build_combat_ctx(
		d_type_id, str(defender["faction_id"]), true,
		defender.get("skills", []) if defender.get("skills") is Array else []
	)
	var c_def_ctx: Dictionary = _build_combat_ctx(a_type_id, str(attacker["faction_id"]), false)
	if _combat.is_ranged_unit(d_type_id):
		var d_data: Dictionary = DataManager.get_unit_type(d_type_id)
		if d_data.has("melee_attack"):
			c_atk_ctx["override_attack"] = int(d_data.get("melee_attack"))
	var a_offset: Vector2i = HexLib.axial_to_offset_odd_r(int(attacker["q"]), int(attacker["r"]))
	var a_terrain: String = CityManager.get_big_map_terrain_id(a_offset.x, a_offset.y)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var result: Dictionary = _combat.compute_counter_attack(
		d_type_id, a_type_id, a_terrain,
		int(defender.get("morale", 100)), int(attacker.get("morale", 100)),
		rng, c_atk_ctx, c_def_ctx,
	)
	var counter_dmg: int = maxi(1, int(result.get("damage", 0)))
	counter_dmg = mini(counter_dmg, int(attacker["hp"]))
	attacker["hp"] = int(attacker["hp"]) - counter_dmg
	if int(attacker["hp"]) <= 0:
		_apply_kill_morale(defender, attacker)
		_remove_unit(str(attacker["id"]))
	return counter_dmg


## 构建攻/防 context：统一走 CombatCtxBuilder（禁止大地图/演武各拼一套，U2）
func _build_combat_ctx(
	unit_type_id: String,
	faction_id: String,
	is_attacker: bool,
	skills: Array = [],
	city_id: String = ""
) -> Dictionary:
	if is_attacker:
		return CtxLib.build_attack_ctx(faction_id, unit_type_id, skills)
	return CtxLib.build_defense_ctx(faction_id, unit_type_id, city_id)


## 击杀/阵亡士气（战斗系统.md §6.2，与演武共用 UnitMoraleRules）
func _apply_kill_morale(killer: Dictionary, victim: Dictionary) -> void:
	var killer_faction: String = str(killer.get("faction_id", ""))
	var dead_faction: String = str(victim.get("faction_id", ""))
	var killer_allies: Array = []
	var dead_allies: Array = []
	for u: Dictionary in _units:
		if str(u.get("faction_id", "")) == killer_faction:
			killer_allies.append(u)
		elif str(u.get("faction_id", "")) == dead_faction:
			dead_allies.append(u)
	UnitMoraleRules.apply_kill_morale(killer, killer_allies, dead_allies)


func _compute_unit_damage(attacker: Dictionary, defender: Dictionary) -> int:
	var a_type_id: String = str(attacker["unit_type_id"])
	var d_type_id: String = str(defender["unit_type_id"])
	var d_offset: Vector2i = HexLib.axial_to_offset_odd_r(int(defender["q"]), int(defender["r"]))
	var d_terrain_id: String = CityManager.get_big_map_terrain_id(d_offset.x, d_offset.y)
	var atk_ctx: Dictionary = _build_combat_ctx(
		a_type_id, str(attacker["faction_id"]), true,
		attacker.get("skills", []) if attacker.get("skills") is Array else []
	)
	var def_ctx: Dictionary = _build_combat_ctx(
		d_type_id, str(defender["faction_id"]), false,
		defender.get("skills", []) if defender.get("skills") is Array else []
	)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var result: Dictionary = _combat.compute_damage(
		a_type_id,
		d_type_id,
		d_terrain_id,
		int(attacker.get("morale", 100)),
		int(defender.get("morale", 100)),
		rng,
		atk_ctx,
		def_ctx,
	)
	return maxi(1, int(result.get("damage", 1)))


func try_attack_city(unit_id: String, city_id: String) -> Dictionary:
	var unit: Dictionary = _get_unit_ref(unit_id)
	if unit.is_empty():
		return {"ok": false, "reason": "NO_UNIT"}
	var city: Dictionary = CityManager.get_city_state(city_id)
	if city.is_empty():
		return {"ok": false, "reason": "NO_CITY"}
	if str(city.get("current_faction_id", "")) == str(unit["faction_id"]):
		return {"ok": false, "reason": "OWN_CITY"}
	# 决策 #89：未宣战禁止攻城（中立城除外）
	var city_owner: String = str(city.get("current_faction_id", ""))
	if city_owner != "neutral" and city_owner != "":
		if not DiplomacySystem.are_at_war(str(unit["faction_id"]), city_owner):
			return {"ok": false, "reason": "NOT_AT_WAR"}
	if bool(unit.get("acted", false)):
		return {"ok": false, "reason": "ALREADY_ACTED"}
	var u_pos: Vector2i = Vector2i(int(unit["q"]), int(unit["r"]))
	var c_pos: Vector2i = HexLib.offset_odd_r_to_axial(int(city.get("hex_q", 0)), int(city.get("hex_r", 0)))
	var a_type: Dictionary = DataManager.get_unit_type(str(unit["unit_type_id"]))
	var range: int = int(a_type.get("range", 1))
	if HexLib.hex_distance_hex(u_pos, c_pos) > range:
		return {"ok": false, "reason": "OUT_OF_RANGE"}
	# 统一规范 §7：攻城走 SiegeResolver（墙 HP 分流 + ctx + 器械倍率）
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var skills: Array = unit.get("skills", []) if unit.get("skills") is Array else []
	# SiegeResolver 内部用 CtxBuilder；此处保证 skills 进入 unit dict 供其读取
	unit["skills"] = skills
	var siege_result: Dictionary = SiegeLib.compute_city_attack(unit, city_id, rng)
	var dmg: int = int(siege_result.get("damage", 0))
	if dmg <= 0 and not bool(siege_result.get("city_destroyed", false)):
		# 兜底：无 ctx 时至少 1 点，避免零伤害死锁
		var atk: int = int(a_type.get("attack", 10))
		var siege_mult: float = SiegeLib.siege_multiplier(str(unit["unit_type_id"]))
		var city_def: float = float(CityManager.get_city_defense(city_id))
		dmg = maxi(1, int(float(atk) * siege_mult * 20.0 / (20.0 + maxf(city_def, 0.0))))
		var fallback: Dictionary = CityManager.damage_city(city_id, dmg)
		siege_result["city_destroyed"] = bool(fallback.get("destroyed", false))
		siege_result["city_damage"] = dmg
	# 城防反击（统一规范 §7）
	var counter: int = 0
	if not bool(siege_result.get("city_destroyed", false)):
		counter = SiegeLib.city_counter_damage(city_id, unit, rng)
		if counter > 0:
			unit["hp"] = maxi(0, int(unit.get("hp", 1)) - counter)
			if int(unit["hp"]) <= 0:
				_remove_unit(str(unit["id"]))
	unit["acted"] = true
	unit["mp"] = 0
	if bool(siege_result.get("city_destroyed", false)):
		var captor: String = str(unit["faction_id"])
		CityManager.change_ownership(city_id, captor)
		MinisterManager.try_acquire_military_minister(captor)
	city_sieged.emit(city_id, unit_id, dmg)
	units_changed.emit()
	return {
		"ok": true,
		"damage": dmg,
		"wall_damage": int(siege_result.get("wall_damage", 0)),
		"city_damage": int(siege_result.get("city_damage", dmg)),
		"counter_damage": counter,
		"destroyed": bool(siege_result.get("city_destroyed", false)),
	}


func _city_id_at_offset(col: int, row: int) -> String:
	for city in CityManager.get_all_city_states():
		if int(city.get("hex_q", -1)) == col and int(city.get("hex_r", -1)) == row:
			return str(city.get("id", ""))
	return ""


func _try_capture_city_if_clear(faction_id: String, city_id: String) -> void:
	var city: Dictionary = CityManager.get_city_state(city_id)
	if city.is_empty():
		return
	if str(city.get("current_faction_id", "")) == faction_id:
		return
	if int(city.get("current_hp", 0)) > 0:
		return
	CityManager.change_ownership(city_id, faction_id)
	MinisterManager.try_acquire_military_minister(faction_id)


## 公开：城防归零时尝试占城（供测试与 AI 调用）
func try_capture_city_if_clear(faction_id: String, city_id: String) -> void:
	_try_capture_city_if_clear(faction_id, city_id)


func _get_unit_ref(unit_id: String) -> Dictionary:
	for u: Dictionary in _units:
		if str(u["id"]) == unit_id:
			return u
	return {}


func _remove_unit(unit_id: String) -> void:
	for i in range(_units.size() - 1, -1, -1):
		if str((_units[i] as Dictionary).get("id", "")) == unit_id:
			_units.remove_at(i)
	if _selected_unit_id == unit_id:
		_selected_unit_id = ""


# ============= 存档 =============

func get_save_data() -> Dictionary:
	return {
		"units": _units.duplicate(true),
		"next_unit_seq": _next_unit_seq,
	}


func load_save_data(data: Dictionary) -> void:
	_units.clear()
	var raw: Variant = data.get("units", [])
	if raw is Array:
		for item: Variant in raw:
			if item is Dictionary:
				_units.append(UnitStateLib.normalize((item as Dictionary).duplicate(true)))
	_next_unit_seq = int(data.get("next_unit_seq", _units.size() + 1))
	_selected_unit_id = ""
	units_changed.emit()
