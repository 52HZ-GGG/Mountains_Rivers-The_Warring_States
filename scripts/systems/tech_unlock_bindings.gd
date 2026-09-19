extends Node

## 科技解锁条件绑定（组合根）
##
## 将业务系统的具体判定注册到 TechUnlockContext。
## 本文件是唯一允许「科技条件 → City/Diplomacy/Wonder」引用的位置；
## TechSystem 与消费端均不直接互相调用这些系统来做条件判断。
## 由 StartupFlow / GameManager 开局时调用 bind_all()。

static var _bound: bool = false


static func bind_all() -> void:
	if _bound:
		return
	if not is_instance_valid(TechUnlockContext):
		return
	TechUnlockContext.clear_checkers()
	TechUnlockContext.register_checker("city_control", _check_city_control)
	TechUnlockContext.register_checker("building", _check_building)
	TechUnlockContext.register_checker("region_control", _check_region_control)
	TechUnlockContext.register_checker("reputation", _check_reputation)
	TechUnlockContext.register_checker("wonder", _check_wonder)
	_bound = true


static func unbind_all() -> void:
	if is_instance_valid(TechUnlockContext):
		TechUnlockContext.clear_checkers()
	_bound = false


static func _check_city_control(faction_id: String, condition: Dictionary) -> bool:
	var city_id: String = str(condition.get("city_id", ""))
	if city_id == "" or not is_instance_valid(CityManager):
		return false
	var city: Dictionary = CityManager.get_city_state(city_id)
	if city.is_empty():
		return false
	return str(city.get("current_faction_id", "")) == faction_id


static func _check_building(faction_id: String, condition: Dictionary) -> bool:
	var building_id: String = str(condition.get("building_id", ""))
	if building_id == "" or not is_instance_valid(CityManager):
		return false
	for city in CityManager.get_faction_city_states(faction_id):
		for building in city.get("buildings", []):
			if str((building as Dictionary).get("building_id", "")) == building_id:
				return true
	return false


static func _check_region_control(faction_id: String, condition: Dictionary) -> bool:
	var min_cities: int = int(condition.get("min_cities", 1))
	if min_cities <= 0:
		return true
	if not is_instance_valid(CityManager) or not is_instance_valid(DataManager):
		return false
	var region: String = str(condition.get("region", ""))
	var northern_ids: Array = []
	var north_cfg: Variant = DataManager.get_balance_param("tech.northern_border_cities")
	if north_cfg is Array:
		northern_ids = north_cfg
	var count: int = 0
	for city in CityManager.get_faction_city_states(faction_id):
		var city_id: String = str(city.get("id", ""))
		var city_region: String = str(city.get("region", ""))
		if region == "northern_border" or region == "north":
			if northern_ids.has(city_id) or city_region == "northern_border" or city_region == "north":
				count += 1
		elif city_region == region or city_id == region:
			count += 1
	return count >= min_cities


static func _check_reputation(faction_id: String, condition: Dictionary) -> bool:
	if not is_instance_valid(DiplomacySystem):
		return false
	var effective: int = DiplomacySystem.get_reputation(faction_id)
	if is_instance_valid(TechEffects):
		effective += TechEffects.reputation_bonus(faction_id)
	return effective >= int(condition.get("value", 0))


static func _check_wonder(faction_id: String, condition: Dictionary) -> bool:
	var wonder_id: String = str(condition.get("wonder_id", ""))
	if wonder_id == "" or not is_instance_valid(WonderManager):
		return false
	return WonderManager.has_wonder(faction_id, wonder_id)
