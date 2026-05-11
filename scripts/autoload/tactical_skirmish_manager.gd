extends Node

## 阶段1战术演武 — 六角移动 + 战斗结算 + 占领城格（策划案 §5 最小可玩）
## 数据：data/tactical_skirmish_mvp.json

const HexLib := preload("res://scripts/systems/hex_axial.gd")
const CombatLib := preload("res://scripts/systems/combat_resolver.gd")

signal log_appended(line: String)
signal state_changed()
signal skirmish_ended(winner_faction_id: String)

const BIG_MOVE: int = 999999

var _cfg: Dictionary = {}
var _tiles: Dictionary = {} # Vector2i -> terrain_id
var _all_cells: Array[Vector2i] = []
var _units: Array[Dictionary] = []
var _player_faction: String = ""
var _enemy_faction: String = ""
var _player_city: Vector2i = Vector2i.ZERO
var _enemy_city: Vector2i = Vector2i.ZERO
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _skirmish_active: bool = false


func _ready() -> void:
	_rng.randomize()


func is_active() -> bool:
	return _skirmish_active


func get_player_faction() -> String:
	return _player_faction


func get_enemy_faction() -> String:
	return _enemy_faction


func get_player_city() -> Vector2i:
	return _player_city


func get_enemy_city() -> Vector2i:
	return _enemy_city


func get_units() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for u: Dictionary in _units:
		out.append(u.duplicate())
	return out


func terrain_at(cell: Vector2i) -> String:
	return str(_tiles.get(cell, "plains"))


## 开始演武：从 DataManager 读取 JSON 配置（duplicate 避免污染缓存）
func start_skirmish() -> void:
	_cfg = DataManager.get_tactical_skirmish_mvp().duplicate(true)
	if _cfg.is_empty():
		push_error("TacticalSkirmishManager: tactical_skirmish_mvp 数据为空")
		return
	_player_faction = str(_cfg.get("player_faction_id", "qin"))
	_enemy_faction = str(_cfg.get("enemy_faction_id", "zhao"))
	var pc: Dictionary = _cfg.get("player_city", {})
	var ec: Dictionary = _cfg.get("enemy_city", {})
	## JSON 中据点与 rows[row][col] 一致：q=列 col、r=行 row（odd-R 偏移），运行时一律转轴向
	_player_city = HexLib.offset_odd_r_to_axial(int(pc.get("q", 0)), int(pc.get("r", 0)))
	_enemy_city = HexLib.offset_odd_r_to_axial(int(ec.get("q", 0)), int(ec.get("r", 0)))
	_build_tiles()
	_spawn_units()
	_skirmish_active = true
	_append_log("演武开始：%s 对 %s，攻占对方城格获胜。" % [_player_faction, _enemy_faction])
	begin_player_phase()


func reset_skirmish() -> void:
	_skirmish_active = false
	_units.clear()
	_tiles.clear()
	_all_cells.clear()
	_cfg.clear()
	state_changed.emit()


func begin_player_phase() -> void:
	for u: Dictionary in _units:
		if str(u["faction_id"]) == _player_faction:
			u["acted"] = false
			u["mp_remaining"] = int(u.get("speed", 3))
	state_changed.emit()


func get_attack_move_cost() -> int:
	var v: Variant = DataManager.get_balance_param("tactical.attack_move_cost")
	return int(v) if v != null else 2


## 玩家主动结束本单位行动（移动后可不攻击：再次点选己方单位）
func finalize_player_unit_action(unit_id: String) -> void:
	var u: Dictionary = get_unit_by_id(unit_id)
	if u.is_empty():
		return
	if str(u["faction_id"]) != _player_faction:
		return
	if bool(u.get("acted", false)):
		return
	u["acted"] = true
	state_changed.emit()


## 玩家结束战术回合：执行 AI，再开启下一玩家阶段
func end_player_turn() -> void:
	if not _skirmish_active:
		return
	_run_ai_turn()
	var w: String = check_victory()
	if w != "":
		_finish(w)
		return
	begin_player_phase()


func get_unit_by_id(unit_id: String) -> Dictionary:
	for u: Dictionary in _units:
		if str(u["id"]) == unit_id:
			return u
	return {}


## 可移动到达的格子（累计移耗 ≤ 本回合剩余 mp_remaining），不含友军占据格
func get_reachable_cells(unit_id: String) -> Dictionary:
	var u: Dictionary = get_unit_by_id(unit_id)
	if u.is_empty():
		return {}
	if bool(u.get("acted", false)):
		return {}
	var origin: Vector2i = Vector2i(int(u["q"]), int(u["r"]))
	var mp: int = int(u.get("mp_remaining", int(u.get("speed", 3))))
	return _dijkstra_reachable(origin, mp, str(u["unit_type_id"]), str(u["id"]))


func try_move_unit(unit_id: String, dest: Vector2i) -> Dictionary:
	var u: Dictionary = get_unit_by_id(unit_id)
	if u.is_empty():
		return {"ok": false, "reason": "no_unit"}
	if not _skirmish_active:
		return {"ok": false, "reason": "inactive"}
	if str(u["faction_id"]) != _player_faction:
		return {"ok": false, "reason": "not_player"}
	if bool(u.get("acted", false)):
		return {"ok": false, "reason": "already_acted"}
	var reach: Dictionary = get_reachable_cells(unit_id)
	if not reach.has(dest):
		return {"ok": false, "reason": "unreachable"}
	if _occupant_id_at(dest) != "":
		return {"ok": false, "reason": "occupied"}
	var path_cost: int = int(reach[dest])
	var mp_after: int = int(u.get("mp_remaining", int(u.get("speed", 3)))) - path_cost
	u["q"] = dest.x
	u["r"] = dest.y
	u["mp_remaining"] = mp_after
	var atk_cost: int = get_attack_move_cost()
	var can_still_attack: bool = mp_after >= atk_cost and not list_attack_targets(unit_id).is_empty()
	if can_still_attack:
		u["acted"] = false
	else:
		u["acted"] = true
	_append_log("%s 移动至 (%d,%d)，剩余移动力 %d%s" % [
		unit_id, dest.x, dest.y, mp_after,
		"（可攻击敌军）" if can_still_attack else "（本回合行动结束）",
	])
	_check_enter_city(u)
	state_changed.emit()
	var w: String = check_victory()
	if w != "":
		_finish(w)
	return {"ok": true, "reason": "OK"}


func try_player_attack(attacker_id: String, defender_id: String) -> Dictionary:
	var a: Dictionary = get_unit_by_id(attacker_id)
	var d: Dictionary = get_unit_by_id(defender_id)
	if a.is_empty() or d.is_empty():
		return {"ok": false, "reason": "no_unit"}
	if str(a["faction_id"]) != _player_faction:
		return {"ok": false, "reason": "not_player"}
	if str(a["faction_id"]) == str(d["faction_id"]):
		return {"ok": false, "reason": "friendly"}
	if bool(a.get("acted", false)):
		return {"ok": false, "reason": "already_acted"}
	var atk_cost: int = get_attack_move_cost()
	if int(a.get("mp_remaining", 0)) < atk_cost:
		return {"ok": false, "reason": "insufficient_mp_for_attack"}
	if not _can_attack(a, d):
		return {"ok": false, "reason": "out_of_range"}
	var def_terrain: String = terrain_at(Vector2i(int(d["q"]), int(d["r"])))
	var morale_p: int = GameManager.get_player_morale() if GameManager.is_player_faction(_player_faction) else 50
	var dmg_info: Dictionary = CombatLib.compute_damage(
		str(a["unit_type_id"]),
		str(d["unit_type_id"]),
		def_terrain,
		morale_p,
		50,
		_rng,
	)
	var dmg: int = int(dmg_info.get("damage", 0))
	d["hp"] = int(d["hp"]) - dmg
	var amb: String = "（伏击！）" if bool(dmg_info.get("was_ambush", false)) else ""
	_append_log("%s 攻击 %s，造成 %d 伤害%s" % [attacker_id, defender_id, dmg, amb])
	a["mp_remaining"] = int(a.get("mp_remaining", 0)) - atk_cost
	a["acted"] = true
	if int(d["hp"]) <= 0:
		_remove_unit(defender_id)
		_append_log("%s 被歼灭" % defender_id)
	state_changed.emit()
	var w: String = check_victory()
	if w != "":
		_finish(w)
	return {"ok": true, "damage": dmg, "was_ambush": dmg_info.get("was_ambush", false)}


## 可被玩家选中的攻击目标列表（敌对且射程内，且剩余移动力≥攻击额外消耗）
func list_attack_targets(attacker_id: String) -> Array[String]:
	var a: Dictionary = get_unit_by_id(attacker_id)
	var out: Array[String] = []
	if a.is_empty():
		return out
	if int(a.get("mp_remaining", 0)) < get_attack_move_cost():
		return out
	var acell: Vector2i = Vector2i(int(a["q"]), int(a["r"]))
	for d: Dictionary in _units:
		if str(d["faction_id"]) == str(a["faction_id"]):
			continue
		var dcell: Vector2i = Vector2i(int(d["q"]), int(d["r"]))
		var dist: int = HexLib.hex_distance_hex(acell, dcell)
		var ug: Dictionary = DataManager.get_unit_type(str(a["unit_type_id"]))
		var rng: int = int(ug.get("range", 1))
		if dist >= 1 and dist <= rng:
			out.append(str(d["id"]))
	return out


func check_victory() -> String:
	if not _skirmish_active:
		return ""
	for u: Dictionary in _units:
		var c: Vector2i = Vector2i(int(u["q"]), int(u["r"]))
		if str(u["faction_id"]) == _player_faction and c == _enemy_city:
			return _player_faction
	for u: Dictionary in _units:
		var c2: Vector2i = Vector2i(int(u["q"]), int(u["r"]))
		if str(u["faction_id"]) == _enemy_faction and c2 == _player_city:
			return _enemy_faction
	return ""


# ============= 内部 =============

func _finish(winner: String) -> void:
	_skirmish_active = false
	_append_log("演武结束，获胜方：%s" % winner)
	skirmish_ended.emit(winner)
	state_changed.emit()


func _append_log(line: String) -> void:
	log_appended.emit(line)


func _build_tiles() -> void:
	_tiles.clear()
	_all_cells.clear()
	var w: int = int(_cfg.get("map_width", 7))
	var h: int = int(_cfg.get("map_height", 7))
	var rows: Array = _cfg.get("rows", [])
	for row_o: int in range(h):
		var row: Array = rows[row_o] as Array
		for col_o: int in range(w):
			var cell_axial: Vector2i = HexLib.offset_odd_r_to_axial(col_o, row_o)
			_tiles[cell_axial] = str(row[col_o])
			_all_cells.append(cell_axial)


func _spawn_units() -> void:
	_units.clear()
	for raw: Variant in _cfg.get("initial_units", []):
		var e: Dictionary = raw as Dictionary
		var ut: String = str(e.get("unit_type_id", "infantry"))
		var def: Dictionary = DataManager.get_unit_type(ut)
		var max_hp: int = int(def.get("hp", 100))
		var spd: int = int(def.get("speed", 3))
		var col_u: int = int(e.get("q", 0))
		var row_u: int = int(e.get("r", 0))
		var axial_u: Vector2i = HexLib.offset_odd_r_to_axial(col_u, row_u)
		_units.append({
			"id": str(e.get("id", "")),
			"faction_id": str(e.get("faction_id", "")),
			"unit_type_id": ut,
			"q": axial_u.x,
			"r": axial_u.y,
			"hp": max_hp,
			"max_hp": max_hp,
			"speed": spd,
			"mp_remaining": spd,
			"acted": false,
		})


func _occupant_id_at(cell: Vector2i) -> String:
	for u: Dictionary in _units:
		if Vector2i(int(u["q"]), int(u["r"])) == cell:
			return str(u["id"])
	return ""


func _tile_move_cost_cell(cell: Vector2i, unit_type_id: String) -> int:
	var tid: String = terrain_at(cell)
	var tdata: Dictionary = DataManager.get_terrain(tid)
	var mc: int = int(tdata.get("move_cost", 1))
	if mc < 0:
		return BIG_MOVE
	var udata: Dictionary = DataManager.get_unit_type(unit_type_id)
	var special: Variant = udata.get("special", null)
	if special != null and str(special) == "naval":
		if not bool(tdata.get("is_navigable", false)):
			return BIG_MOVE
		return mc
	if unit_type_id == "cavalry" and not bool(tdata.get("cavalry_allowed", true)):
		return BIG_MOVE
	return mc


func _dijkstra_reachable(origin: Vector2i, mp_budget: int, unit_type_id: String, moving_unit_id: String) -> Dictionary:
	var dist: Dictionary = {}
	for c: Vector2i in _all_cells:
		dist[c] = BIG_MOVE
	dist[origin] = 0
	var visited: Dictionary = {}
	while true:
		var u: Vector2i = Vector2i(-9999, -9999)
		var best: int = BIG_MOVE
		for c: Vector2i in _all_cells:
			if visited.has(c):
				continue
			var d: int = int(dist[c])
			if d < best:
				best = d
				u = c
		if best >= BIG_MOVE or best > mp_budget:
			break
		visited[u] = true
		for v: Vector2i in HexLib.neighbors_hex(u):
			if not dist.has(v):
				continue
			var occ: String = _occupant_id_at(v)
			if occ != "" and occ != moving_unit_id:
				continue
			var w: int = _tile_move_cost_cell(v, unit_type_id)
			if w >= BIG_MOVE:
				continue
			var alt: int = int(dist[u]) + w
			if alt < int(dist[v]):
				dist[v] = alt
	var reach: Dictionary = {}
	for k: Vector2i in dist.keys():
		var cost: int = int(dist[k])
		if cost <= mp_budget and cost < BIG_MOVE and k != origin:
			# 不能停在友军格（起点除外已在上面迭代）
			var occf: String = _occupant_id_at(k)
			if occf != "" and occf != moving_unit_id:
				continue
			reach[k] = cost
	return reach


func _can_attack(a: Dictionary, d: Dictionary) -> bool:
	var ac: Vector2i = Vector2i(int(a["q"]), int(a["r"]))
	var dc: Vector2i = Vector2i(int(d["q"]), int(d["r"]))
	var dist: int = HexLib.hex_distance_hex(ac, dc)
	var ug: Dictionary = DataManager.get_unit_type(str(a["unit_type_id"]))
	var rng: int = int(ug.get("range", 1))
	return dist >= 1 and dist <= rng


func _remove_unit(uid: String) -> void:
	for i: int in range(_units.size() - 1, -1, -1):
		if str((_units[i] as Dictionary).get("id", "")) == uid:
			_units.remove_at(i)
			break


func _check_enter_city(u: Dictionary) -> void:
	var c: Vector2i = Vector2i(int(u["q"]), int(u["r"]))
	if str(u["faction_id"]) == _player_faction and c == _enemy_city:
		_append_log("%s 占据 %s 城格！" % [_player_faction, _enemy_faction])
	elif str(u["faction_id"]) == _enemy_faction and c == _player_city:
		_append_log("%s 占据 %s 城格！" % [_enemy_faction, _player_faction])


func _run_ai_turn() -> void:
	var enemies: Array[Dictionary] = []
	for u: Dictionary in _units:
		if str(u["faction_id"]) == _enemy_faction:
			enemies.append(u)
	for u: Dictionary in enemies:
		u["acted"] = false

	var atk_cost_ai: int = get_attack_move_cost()
	for u: Dictionary in enemies:
		var uid: String = str(u["id"])
		u["mp_remaining"] = int(u.get("speed", 3))
		# 随机移动：消耗 mp_remaining
		var reach: Dictionary = _dijkstra_reachable(Vector2i(int(u["q"]), int(u["r"])), int(u["mp_remaining"]), str(u["unit_type_id"]), uid)
		var candidates: Array[Vector2i] = []
		for pos: Variant in reach.keys():
			var p: Vector2i = pos as Vector2i
			if _occupant_id_at(p) == "":
				candidates.append(p)
		if candidates.size() > 0:
			var pick_i: int = _rng.randi_range(0, candidates.size() - 1)
			var dest: Vector2i = candidates[pick_i]
			var step_cost: int = int(reach[dest])
			u["mp_remaining"] = int(u["mp_remaining"]) - step_cost
			u["q"] = dest.x
			u["r"] = dest.y
			_append_log("AI %s 移动至 (%d,%d)，剩余移动力 %d" % [uid, dest.x, dest.y, int(u["mp_remaining"])])
			_check_enter_city(u)

		var wmid: String = check_victory()
		if wmid != "":
			_finish(wmid)
			return

		# 进攻：需剩余移动力≥攻击额外消耗
		var targets: Array[String] = []
		if int(u.get("mp_remaining", 0)) >= atk_cost_ai:
			for o: Dictionary in _units:
				if str(o["faction_id"]) == _enemy_faction:
					continue
				if _can_attack(u, o):
					targets.append(str(o["id"]))
		if targets.size() > 0:
			var t_id: String = targets[_rng.randi_range(0, targets.size() - 1)]
			var defender: Dictionary = get_unit_by_id(t_id)
			var def_ter: String = terrain_at(Vector2i(int(defender["q"]), int(defender["r"])))
			var dmg_i: Dictionary = CombatLib.compute_damage(
				str(u["unit_type_id"]),
				str(defender["unit_type_id"]),
				def_ter,
				50,
				50,
				_rng,
			)
			defender["hp"] = int(defender["hp"]) - int(dmg_i.get("damage", 0))
			var amb2: String = "（伏击！）" if bool(dmg_i.get("was_ambush", false)) else ""
			_append_log("AI %s 攻击 %s，%d 伤%s" % [uid, t_id, int(dmg_i.get("damage", 0)), amb2])
			if int(defender["hp"]) <= 0:
				_remove_unit(t_id)
				_append_log("%s 被歼灭" % t_id)
			u["mp_remaining"] = int(u.get("mp_remaining", 0)) - atk_cost_ai
		u["acted"] = true

		wmid = check_victory()
		if wmid != "":
			_finish(wmid)
			return

	state_changed.emit()
