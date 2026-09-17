class_name AiCombatScoring

## 共享 AI 战斗评分（统一规范 §8）
## 大地图 StrategicAI 与演武 skirmish_ai 共用。
## 场景壳负责：预算、宣战过滤、ai_mode 档位。

const HexLib := preload("res://scripts/systems/hex_axial.gd")


## 目标评分：残血优先 + 器械对城优先 + 近距加分
static func score_unit_target(target_hp: int, target_max_hp: int, dist: int, attacker_is_siege: bool = false) -> float:
	var hp_ratio: float = 1.0
	if target_max_hp > 0:
		hp_ratio = float(target_hp) / float(target_max_hp)
	# 残血分更高
	var score: float = 1.0 - hp_ratio
	# 近距加分
	if dist <= 1:
		score += 0.3
	elif dist <= 2:
		score += 0.15
	return score


static func score_city_target(city_level: int, city_hp: int, city_max_hp: int, dist: int, attacker_is_siege: bool) -> float:
	var hp_ratio: float = 1.0
	if city_max_hp > 0:
		hp_ratio = float(city_hp) / float(city_max_hp)
	var score: float = (1.0 - hp_ratio) * 0.8 + float(city_level) * 0.05
	if attacker_is_siege:
		score += 0.5
	if dist <= 1:
		score += 0.25
	return score


## 在可攻击候选中选最优单位目标
## candidates: Array of {id, hp, max_hp, dist, axial}
static func pick_best_unit_target(candidates: Array, attacker_is_siege: bool = false) -> String:
	var best_id: String = ""
	var best_score: float = -1.0
	for c: Variant in candidates:
		var d: Dictionary = c as Dictionary
		var s: float = score_unit_target(
			int(d.get("hp", 0)),
			int(d.get("max_hp", 1)),
			int(d.get("dist", 99)),
			attacker_is_siege
		)
		if s > best_score:
			best_score = s
			best_id = str(d.get("id", ""))
	return best_id


static func pick_best_city_target(candidates: Array, attacker_is_siege: bool = false) -> String:
	var best_id: String = ""
	var best_score: float = -1.0
	for c: Variant in candidates:
		var d: Dictionary = c as Dictionary
		var s: float = score_city_target(
			int(d.get("city_level", 1)),
			int(d.get("hp", 0)),
			int(d.get("max_hp", 1)),
			int(d.get("dist", 99)),
			attacker_is_siege
		)
		if s > best_score:
			best_score = s
			best_id = str(d.get("id", ""))
	return best_id


## 演武 AI 难度档（统一规范 §8）
## tutorial：弱化（不连续追杀）
## random：现网随机
## scored：完整评分
static func pick_tutorial_move(candidates: Array) -> Variant:
	if candidates.is_empty():
		return null
	# 教学：优先靠近但不强求最优
	var idx: int = 0
	if candidates.size() > 1:
		idx = candidates.size() / 3
	return candidates[idx]
