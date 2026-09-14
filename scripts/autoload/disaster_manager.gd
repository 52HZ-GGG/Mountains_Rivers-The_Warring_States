extends Node

## 大灾异象与复国主义
## - 彗星/异象：全局民心、安定度、声望惩罚/加成
## - 五连星：正面天命 buff
## - 复国：灭国后按文化覆盖/声望/盟友掷骰复国

var _active_omens: Dictionary = {}  # type -> {turns_left, faction_id?}
var _last_disaster_turn: int = 0
var _restored_factions: Dictionary = {}  # faction_id -> {city_id, turn}
var _eliminated_memory: Dictionary = {}  # faction_id -> {reputation, culture_ratio, allies}


func _ready() -> void:
	SignalBus.turn_started.connect(_on_turn_started)
	SignalBus.faction_eliminated.connect(_on_faction_eliminated)


func reset() -> void:
	_active_omens.clear()
	_last_disaster_turn = 0
	_restored_factions.clear()
	_eliminated_memory.clear()


func get_save_data() -> Dictionary:
	return {
		"active_omens": _active_omens.duplicate(true),
		"last_disaster_turn": _last_disaster_turn,
		"restored_factions": _restored_factions.duplicate(true),
		"eliminated_memory": _eliminated_memory.duplicate(true),
	}


func load_save_data(data: Dictionary) -> void:
	_active_omens = (data.get("active_omens", {}) as Dictionary).duplicate(true)
	_last_disaster_turn = int(data.get("last_disaster_turn", 0))
	_restored_factions = (data.get("restored_factions", {}) as Dictionary).duplicate(true)
	_eliminated_memory = (data.get("eliminated_memory", {}) as Dictionary).duplicate(true)


func _on_turn_started(turn_number: int, faction_id: String) -> void:
	_tick_omens()
	if faction_id != GameManager.get_player_faction():
		return
	_try_roll_disaster(turn_number)
	_try_restoration(turn_number)


func _on_faction_eliminated(faction_id: String) -> void:
	_eliminated_memory[faction_id] = {
		"reputation": DiplomacySystem.get_reputation(faction_id),
		"culture_ratio": CityManager.get_culture_coverage_ratio(faction_id),
		"allies": DiplomacySystem.get_allies_count(faction_id),
		"eliminated_turn": GameManager.get_current_turn(),
	}


# ============= 异象 =============

func is_omen_active(omen_type: String) -> bool:
	return _active_omens.has(omen_type)


func get_active_omens() -> Dictionary:
	return _active_omens.duplicate(true)


func _try_roll_disaster(turn_number: int) -> void:
	var cfg: Dictionary = DataManager.get_balance_param("disasters")
	if cfg.is_empty():
		return
	if turn_number - _last_disaster_turn < int(cfg.get("cooldown_turns", 12)):
		return

	# 五连星（正面）
	if turn_number >= int(cfg.get("five_star_min_turn", 40)):
		if randf() < float(cfg.get("five_star_chance", 0.02)):
			_trigger_omen("five_star", int(cfg.get("five_star_duration", 8)))
			for fid in GameManager.FACTION_IDS:
				GameManager.apply_faction_resource_delta(fid, "morale", int(cfg.get("five_star_morale_bonus", 10)))
				DiplomacySystem._change_reputation(fid, int(cfg.get("five_star_reputation_bonus", 10)))
			_last_disaster_turn = turn_number
			return

	# 彗星（负面）
	if turn_number >= int(cfg.get("comet_min_turn", 25)):
		if randf() < float(cfg.get("comet_chance", 0.03)):
			_trigger_omen("comet", int(cfg.get("omen_duration", 5)))
			for fid in GameManager.FACTION_IDS:
				GameManager.apply_faction_resource_delta(fid, "morale", int(cfg.get("comet_morale_penalty", -15)))
				DiplomacySystem._change_reputation(fid, int(cfg.get("comet_reputation_penalty", -5)))
				_apply_stability_to_faction(fid, int(cfg.get("omen_stability_penalty", -5)))
			_last_disaster_turn = turn_number
			return

	# 普通异象
	if turn_number >= int(cfg.get("omen_min_turn", 15)):
		if randf() < float(cfg.get("omen_chance", 0.04)):
			_trigger_omen("omen", int(cfg.get("omen_duration", 5)))
			for fid in GameManager.FACTION_IDS:
				GameManager.apply_faction_resource_delta(fid, "morale", int(cfg.get("omen_morale_penalty", -8)))
				_apply_stability_to_faction(fid, int(cfg.get("omen_stability_penalty", -5)))
			_last_disaster_turn = turn_number


func _trigger_omen(omen_type: String, duration: int) -> void:
	_active_omens[omen_type] = {"turns_left": duration, "start_turn": GameManager.get_current_turn()}
	SignalBus.diplomacy_action_performed.emit("omen_" + omen_type, "heaven", "all")


func _tick_omens() -> void:
	var expired: Array = []
	for omen_type in _active_omens:
		var state: Dictionary = _active_omens[omen_type]
		state["turns_left"] = int(state.get("turns_left", 0)) - 1
		if int(state.get("turns_left", 0)) <= 0:
			expired.append(omen_type)
	for omen_type in expired:
		_active_omens.erase(omen_type)


func _apply_stability_to_faction(faction_id: String, delta: int) -> void:
	for city in CityManager.get_faction_cities(faction_id):
		var city_id: String = str(city.get("id", ""))
		if city_id.is_empty():
			continue
		var state: Dictionary = CityManager.get_city_state(city_id)
		if state.is_empty():
			continue
		var old_stab: int = int(state.get("stability", 50))
		state["stability"] = clampi(old_stab + delta, 0, 100)


# ============= 复国主义 =============

func get_restored_factions() -> Dictionary:
	return _restored_factions.duplicate(true)


func can_attempt_restoration(faction_id: String) -> bool:
	var cfg: Dictionary = DataManager.get_balance_param("restoration")
	if not bool(cfg.get("enabled", true)):
		return false
	if not _eliminated_memory.has(faction_id):
		return false
	if _restored_factions.has(faction_id):
		return false
	if GameManager.get_current_turn() < int(cfg.get("min_turn", 20)):
		return false
	if not CityManager.is_faction_eliminated(faction_id):
		return false
	return true


## 直接尝试复国（force_rng >= 0 时跳过回合门槛，便于测试/强制复国）
func attempt_restoration(faction_id: String, force_rng: float = -1.0) -> Dictionary:
	if force_rng >= 0.0:
		if _restored_factions.has(faction_id):
			return {"success": false, "reason": "already_restored"}
		if CityManager.is_faction_eliminated(faction_id) and not _eliminated_memory.has(faction_id):
			_on_faction_eliminated(faction_id)
		if not _eliminated_memory.has(faction_id):
			return {"success": false, "reason": "not_eligible"}
		if not CityManager.is_faction_eliminated(faction_id):
			return {"success": false, "reason": "not_eliminated"}
	elif not can_attempt_restoration(faction_id):
		return {"success": false, "reason": "not_eligible"}
	var cfg: Dictionary = DataManager.get_balance_param("restoration")
	var mem: Dictionary = _eliminated_memory.get(faction_id, {})
	var chance: float = float(cfg.get("base_chance", 0.35))
	if float(mem.get("culture_ratio", 0.0)) >= 0.3:
		chance += float(cfg.get("culture_coverage_bonus", 0.25))
	if int(mem.get("reputation", 0)) >= int(cfg.get("reputation_threshold", 60)):
		chance += float(cfg.get("high_reputation_bonus", 0.15))
	if int(mem.get("allies", 0)) > 0:
		chance += float(cfg.get("ally_support_bonus", 0.1))
	chance = clampf(chance, 0.0, 0.95)

	var roll: float = force_rng if force_rng >= 0.0 else randf()
	if roll >= chance:
		return {"success": false, "reason": "roll_failed", "chance": chance}

	var city_id: String = _find_restoration_city(faction_id)
	if city_id.is_empty():
		return {"success": false, "reason": "no_city"}

	CityManager.occupy_city(city_id, faction_id)
	GameManager.apply_faction_resource_delta(faction_id, "morale", int(cfg.get("restore_morale", 40)))
	GameManager.apply_faction_resource_delta(faction_id, "gold", int(cfg.get("restore_gold", 200)))
	GameManager.apply_faction_resource_delta(faction_id, "food", int(cfg.get("restore_food", 200)))
	_restored_factions[faction_id] = {
		"city_id": city_id,
		"turn": GameManager.get_current_turn(),
	}
	SignalBus.diplomacy_action_performed.emit("restoration", faction_id, city_id)
	return {"success": true, "city_id": city_id, "chance": chance}


func _try_restoration(_turn_number: int) -> void:
	for faction_id in _eliminated_memory.keys():
		if not can_attempt_restoration(str(faction_id)):
			continue
		attempt_restoration(str(faction_id))


## 选一座文化主流仍是本国、或安定度最低的城作为复国据点
func _find_restoration_city(faction_id: String) -> String:
	var best := ""
	var best_score := -1.0
	for city in CityManager.get_all_city_states():
		var city_id: String = str(city.get("id", ""))
		if city_id.is_empty():
			continue
		var owner: String = str(city.get("current_faction_id", ""))
		if owner == faction_id:
			continue
		var culture: Dictionary = CityManager.get_city_culture(city_id)
		var own_culture: float = float(culture.get(faction_id, 0.0))
		var stab: int = CityManager.get_city_stability(city_id)
		var score: float = own_culture * 2.0 + float(100 - stab) / 100.0
		if score > best_score:
			best_score = score
			best = city_id
	return best
