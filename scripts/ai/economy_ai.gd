class_name EconomyAI

## AI 经济决策：每回合在财力允许时建造/升级基础建筑。
## 数据优先从 buildings.json 读取造价；无 balance 专用节时使用保守阈值。
## 由 GameManager.process_ai_turn() 调用。


static func evaluate_economy(faction_id: String) -> void:
	var personality: Dictionary = DataManager.get_ai_personality(faction_id)
	if personality.get("is_passive", false):
		return
	var cities: Array = CityManager.get_faction_city_states(faction_id)
	if cities.is_empty():
		return
	# 每回合最多处理 2 城，避免 AI 一次铺满
	var budget_turns: int = 2
	for city_v in cities:
		if budget_turns <= 0:
			break
		var city: Dictionary = city_v as Dictionary
		if _try_build_or_upgrade(faction_id, str(city.get("id", ""))):
			budget_turns -= 1


static func _try_build_or_upgrade(faction_id: String, city_id: String) -> bool:
	if city_id == "":
		return false
	# 优先升级已有经济建筑，再补基础经济建筑
	var upgrade_id: String = _pick_upgrade_target(city_id)
	if upgrade_id != "" and CityManager.can_upgrade(city_id, upgrade_id).get("allowed", false):
		return CityManager.start_upgrade(city_id, upgrade_id)
	var build_id: String = _pick_build_target(city_id)
	if build_id != "" and CityManager.can_build(city_id, build_id).get("allowed", false):
		return CityManager.start_build(city_id, build_id)
	return false


static func _pick_build_target(city_id: String) -> String:
	# 经济优先级：农田 → 市集 → 伐木场；军事城补兵营
	var preference: Array[String] = ["farm", "market", "lumbermill", "barracks"]
	var city: Dictionary = CityManager.get_city_state(city_id)
	if city.is_empty():
		return ""
	var pop: int = int(city.get("current_population", 0))
	if pop <= 5:
		preference = ["farm"]
	for building_id in preference:
		if CityManager.can_build(city_id, building_id).get("allowed", false):
			return building_id
	return ""


static func _pick_upgrade_target(city_id: String) -> String:
	var city: Dictionary = CityManager.get_city_state(city_id)
	if city.is_empty():
		return ""
	var candidates: Array[String] = ["farm", "market", "lumbermill", "barracks"]
	for building_id in candidates:
		for entry_v in city.get("buildings", []):
			var entry: Dictionary = entry_v as Dictionary
			if str(entry.get("building_id", "")) != building_id:
				continue
			if int(entry.get("level", 1)) >= 3:
				continue
			if CityManager.can_upgrade(city_id, building_id).get("allowed", false):
				return building_id
	return ""
