extends Node

## 战役关隘管理：开局归属来自 data/passes.json（策划显式），被占后长久持有并写入存档。

const _HexAxial := preload("res://scripts/systems/hex_axial.gd")
const PASSES_PATH := "res://data/passes.json"

## key=axial "q,r" → {owner, hp, max_hp, attacked, name, offset_col, offset_row}
var _passes: Dictionary = {}
var _config_loaded: bool = false


func _ready() -> void:
	SignalBus.game_started.connect(_on_game_started)
	# 若 GameManager 已在跑，也尝试初始化
	if GameManager != null and GameManager.has_method("get_current_turn"):
		call_deferred("_ensure_initialized")


func _on_game_started(_factions: Array = [], _player: String = "") -> void:
	_ensure_initialized()


func _ensure_initialized() -> void:
	if not _passes.is_empty():
		return
	initialize_from_config()


func _key(axial: Vector2i) -> String:
	return "%d,%d" % [axial.x, axial.y]


func _load_passes_json() -> Dictionary:
	if _config_loaded:
		return _passes
	_config_loaded = true
	_passes.clear()
	var file: FileAccess = FileAccess.open(PASSES_PATH, FileAccess.READ)
	if file == null:
		push_warning("PassManager: 无法读取 %s" % PASSES_PATH)
		return _passes
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		return _passes
	var list: Array = (parsed as Dictionary).get("passes", []) as Array
	var max_hp: int = pass_max_hp()
	for item: Variant in list:
		if not (item is Dictionary):
			continue
		var d: Dictionary = item as Dictionary
		var axial: Vector2i = Vector2i(int(d.get("axial_q", 0)), int(d.get("axial_r", 0)))
		var owner: String = str(d.get("owner", "neutral"))
		if owner == "":
			owner = "neutral"
		_passes[_key(axial)] = {
			"owner": owner,
			"hp": max_hp,
			"max_hp": max_hp,
			"attacked": false,
			"name": str(d.get("name", "关隘")),
			"offset_col": int(d.get("offset_col", 0)),
			"offset_row": int(d.get("offset_row", 0)),
		}
	return _passes


func pass_max_hp() -> int:
	var v: Variant = DataManager.get_balance_param("fortification.pass_hp")
	return int(v) if v != null else 300


func initialize_from_config() -> void:
	_load_passes_json()
	# 保证地图上所有 pass 地形格都有条目
	var rows: Array = DataManager.get_big_map_rows() if DataManager.has_method("get_big_map_rows") else []
	var map_size: Vector2i = DataManager.get_big_map_size() if DataManager.has_method("get_big_map_size") else Vector2i.ZERO
	if rows.is_empty() or map_size.x <= 0:
		return
	for row: int in range(map_size.y):
		if row >= rows.size():
			break
		var row_data: Variant = rows[row]
		if not (row_data is Array):
			continue
		var arr: Array = row_data as Array
		for col: int in range(map_size.x):
			if col >= arr.size():
				break
			if str(arr[col]) != "pass":
				continue
			var axial: Vector2i = _HexAxial.offset_odd_r_to_axial(col, row)
			var k: String = _key(axial)
			if _passes.has(k):
				continue
			# JSON 未列出：中立 + 警告（策划应补全）
			push_warning("PassManager: 关隘 (%d,%d) 未在 passes.json 声明，初始化为中立" % [axial.x, axial.y])
			_passes[k] = {
				"owner": "neutral",
				"hp": pass_max_hp(),
				"max_hp": pass_max_hp(),
				"attacked": false,
				"name": "关隘",
				"offset_col": col,
				"offset_row": row,
			}


func reset() -> void:
	_passes.clear()
	_config_loaded = false
	initialize_from_config()


func get_all_passes() -> Dictionary:
	_ensure_initialized()
	return _passes.duplicate(true)


func has_pass(axial: Vector2i) -> bool:
	_ensure_initialized()
	return _passes.has(_key(axial))


func get_pass_owner(axial: Vector2i) -> String:
	_ensure_initialized()
	return str((_passes.get(_key(axial), {}) as Dictionary).get("owner", ""))


func get_pass_hp(axial: Vector2i) -> int:
	_ensure_initialized()
	var p: Dictionary = _passes.get(_key(axial), {}) as Dictionary
	if p.is_empty():
		return -1
	return int(p.get("hp", 0))


func get_pass_max_hp_at(axial: Vector2i) -> int:
	_ensure_initialized()
	var p: Dictionary = _passes.get(_key(axial), {}) as Dictionary
	if p.is_empty():
		return pass_max_hp()
	return int(p.get("max_hp", pass_max_hp()))


func is_enemy_pass(axial: Vector2i, faction_id: String) -> bool:
	var owner: String = get_pass_owner(axial)
	if owner == "" or owner == "neutral":
		return false
	return owner != faction_id


func damage_pass(axial: Vector2i, damage: int) -> Dictionary:
	_ensure_initialized()
	var k: String = _key(axial)
	if not _passes.has(k):
		return {"ok": false, "reason": "NO_PASS"}
	var p: Dictionary = _passes[k]
	var old_hp: int = int(p.get("hp", 0))
	var new_hp: int = maxi(0, old_hp - maxi(0, damage))
	p["hp"] = new_hp
	p["attacked"] = true
	_passes[k] = p
	return {"ok": true, "old_hp": old_hp, "hp": new_hp, "destroyed": new_hp <= 0}


## 统一占领：结构 HP≤0 且无驻军（由调用方保证）→ 易主 + 恢复 30%
func try_capture_pass(axial: Vector2i, new_owner: String, force: bool = false) -> Dictionary:
	_ensure_initialized()
	var k: String = _key(axial)
	if not _passes.has(k):
		return {"ok": false, "reason": "NO_PASS"}
	var p: Dictionary = _passes[k]
	if not force and int(p.get("hp", 1)) > 0:
		return {"ok": false, "reason": "STRUCTURE_STANDING"}
	var old_owner: String = str(p.get("owner", ""))
	if old_owner == new_owner:
		return {"ok": true, "unchanged": true}
	var max_hp: int = int(p.get("max_hp", pass_max_hp()))
	var ratio_v: Variant = DataManager.get_balance_param("city_combat.capture_restore_ratio")
	var ratio: float = float(ratio_v) if ratio_v != null else 0.3
	p["owner"] = new_owner
	p["hp"] = maxi(1, int(float(max_hp) * ratio))
	p["attacked"] = false
	_passes[k] = p
	if SignalBus.has_signal("pass_occupied"):
		SignalBus.pass_occupied.emit(_key(axial), old_owner, new_owner)
	return {"ok": true, "old_owner": old_owner, "owner": new_owner, "hp": int(p["hp"])}


func process_turn_recovery() -> void:
	_ensure_initialized()
	var ratio_v: Variant = DataManager.get_balance_param("city_combat.natural_recovery_ratio")
	var ratio: float = float(ratio_v) if ratio_v != null else 0.05
	for k: String in _passes.keys():
		var p: Dictionary = _passes[k]
		if bool(p.get("attacked", false)):
			p["attacked"] = false
			_passes[k] = p
			continue
		var hp: int = int(p.get("hp", 0))
		var max_hp: int = int(p.get("max_hp", pass_max_hp()))
		if hp <= 0 or hp >= max_hp:
			continue
		p["hp"] = mini(max_hp, hp + maxi(1, int(float(max_hp) * ratio)))
		_passes[k] = p


func get_save_data() -> Dictionary:
	_ensure_initialized()
	return {"passes": _passes.duplicate(true)}


func load_save_data(data: Dictionary) -> void:
	if data.is_empty():
		initialize_from_config()
		return
	var saved: Dictionary = data.get("passes", {}) as Dictionary
	if saved.is_empty():
		initialize_from_config()
		return
	_passes = saved.duplicate(true)
	_config_loaded = true
