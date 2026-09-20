class_name UnitMoraleRules

## 单位士气统一规则（演武 / 大地图共用）
## 机制权威：docs/机制概览/战斗系统.md §6
## 数值来源：data/balance_params.json → unit_morale


static func get_params() -> Dictionary:
	var bp: Variant = DataManager.get_balance_param("unit_morale")
	if bp is Dictionary:
		return bp
	return {}


static func param_int(key: String, fallback: int) -> int:
	var v: Variant = DataManager.get_balance_param("unit_morale." + key)
	if v == null:
		return fallback
	return int(v)


static func param_float(key: String, fallback: float) -> float:
	var v: Variant = DataManager.get_balance_param("unit_morale." + key)
	if v == null:
		return fallback
	return float(v)


static func base_morale() -> int:
	return param_int("base_morale", 100)


static func max_morale() -> int:
	return param_int("max_morale", 130)


static func break_threshold() -> int:
	return param_int("morale_break_threshold", 20)


static func low_threshold() -> int:
	return param_int("low_morale_threshold", 50)


static func high_threshold() -> int:
	return param_int("high_morale_threshold", 130)


static func natural_recovery_cap() -> int:
	return param_int("natural_recovery_cap", 100)


static func clamp_morale(value: int) -> int:
	return clampi(value, 0, max_morale())


## 四段式档位：broken / low / normal / high
static func morale_tier(morale: int) -> String:
	var m: int = int(morale)
	if m < break_threshold():
		return "broken"
	if m < low_threshold():
		return "low"
	if m < high_threshold():
		return "normal"
	return "high"


static func tier_display_name(tier: String) -> String:
	match tier:
		"broken":
			return "崩溃"
		"low":
			return "低士气"
		"high":
			return "高士气"
		_:
			return "正常"


static func tier_effect_text(morale: int) -> String:
	var tier: String = morale_tier(morale)
	match tier:
		"broken":
			var atk_mod: float = param_float("broken_atk_mod", 0.5)
			var hp_ratio: float = param_float("broken_hp_loss_per_turn", 0.15)
			return "攻防移×%.0f%%，回合损HP %.0f%%" % [atk_mod * 100.0, hp_ratio * 100.0]
		"low":
			var pen: float = param_float("low_morale_atk_penalty", -0.1)
			return "攻击%+.0f%%" % (pen * 100.0)
		"high":
			var bonus: float = param_float("high_morale_atk_bonus", 0.1)
			return "攻击%+.0f%%" % (bonus * 100.0)
		_:
			return ""


## 悬停基础信息：士气 15（崩溃）｜攻防移×50%…
static func format_morale_info(morale: int) -> String:
	var tier: String = morale_tier(morale)
	var label: String = tier_display_name(tier)
	var effect: String = tier_effect_text(morale)
	if effect.is_empty():
		return "士气 %d（%s）" % [int(morale), label]
	return "士气 %d（%s）｜%s" % [int(morale), label, effect]


## 就地增减士气并 clamp 到 [0, max_morale]
static func apply_morale_delta(unit: Dictionary, delta: int) -> void:
	if unit.is_empty() or delta == 0:
		return
	unit["morale"] = clamp_morale(int(unit.get("morale", base_morale())) + delta)


## 击杀事件（战斗系统.md §6.2）：
## 亲自击杀 +10，与友军击杀叠加共 +15；同阵营其他友军 +5；敌方阵营 -5
static func apply_kill_morale(killer: Dictionary, killer_faction_units: Array, dead_faction_units: Array) -> void:
	var self_gain: int = param_int("morale_gain_on_self_kill", 10)
	var ally_gain: int = param_int("morale_gain_on_ally_kill", 5)
	var ally_loss: int = param_int("morale_loss_on_ally_death", 5)
	var killer_id: String = str(killer.get("id", ""))
	# 击杀者：亲自击杀 + 友军击杀（文档：叠加共 +15）
	apply_morale_delta(killer, self_gain + ally_gain)
	for u: Dictionary in killer_faction_units:
		if str(u.get("id", "")) == killer_id:
			continue
		apply_morale_delta(u, ally_gain)
	for u2: Dictionary in dead_faction_units:
		apply_morale_delta(u2, -absi(ally_loss) if ally_loss > 0 else ally_loss)


## 夹击/包围持续状态：返回当前应有的扣减值（非叠加历史）
static func flanking_penalty(active: bool) -> int:
	if not active:
		return 0
	return param_int("flanking_morale_loss", -15)


static func encirclement_penalty(active: bool) -> int:
	if not active:
		return 0
	return param_int("encirclement_morale_loss", -30)


## 回合士气结算（演武与大地图统一，战斗系统.md §6.1/§6.5）
## is_in_own_city：城中恢复 +8，野外 +3；自然恢复上限 natural_recovery_cap；
## 超过 cap 每回合 -1；崩溃态按 max_hp 扣 HP。
## 回合士气结算（演武与大地图统一，战斗系统.md §6.1/§6.5）
## is_in_own_city：城中恢复 +8，野外 +3；自然恢复上限 natural_recovery_cap；
## 超过 cap 每回合 -1；崩溃态按 max_hp 扣 HP。
## 返回 true 表示 unit 被修改。
static func process_turn_morale(unit: Dictionary, is_in_own_city: bool) -> bool:
	if unit.is_empty():
		return false
	var changed: bool = false
	var current: int = int(unit.get("morale", base_morale()))
	var cap: int = natural_recovery_cap()
	var recovery: int = param_int("morale_recovery_in_city", 8) if is_in_own_city \
		else param_int("morale_recovery_per_turn", 3)
	if current < cap:
		unit["morale"] = mini(current + recovery, cap)
		changed = true
	elif current > cap:
		unit["morale"] = current - 1
		changed = true
	var after: int = int(unit.get("morale", current))
	if after < break_threshold():
		var max_hp: int = int(unit.get("max_hp", unit.get("hp", 100)))
		var ratio: float = param_float("broken_hp_loss_per_turn", 0.15)
		var hp_loss: int = int(round(float(max_hp) * ratio))
		if hp_loss > 0:
			var old_hp: int = int(unit.get("hp", max_hp))
			unit["hp"] = maxi(1, old_hp - hp_loss)
			changed = true
	return changed


## 崩溃态有效移动力（相对当前移动力上限）
static func effective_mp(unit: Dictionary) -> int:
	var base_mp: int = 0
	if unit.has("max_mp"):
		base_mp = int(unit["max_mp"])
	elif unit.has("mp_remaining"):
		base_mp = int(unit["mp_remaining"])
	elif unit.has("speed"):
		base_mp = int(unit["speed"])
	else:
		base_mp = int(unit.get("mp", 3))
	if int(unit.get("morale", base_morale())) < break_threshold():
		var speed_mod: float = param_float("broken_speed_mod", 0.5)
		return maxi(1, int(float(base_mp) * speed_mod))
	return maxi(1, base_mp)


## 攻击加法层偏移（与 CombatResolver._get_morale_atk_offset 同口径）
static func morale_atk_offset(morale: int) -> float:
	var tier: String = morale_tier(morale)
	match tier:
		"high":
			return param_float("high_morale_atk_bonus", 0.1)
		"low":
			return param_float("low_morale_atk_penalty", -0.1)
		_:
			return 0.0


static func is_broken(morale: int) -> bool:
	return int(morale) < break_threshold()
