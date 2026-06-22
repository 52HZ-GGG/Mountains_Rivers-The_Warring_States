extends Node

## 奇观运行时管理器（最小闭环）
##
## 当前实现：
## - 记录奇观归属势力
## - 汇总国家级奇观效果供经营/民心系统查询

var _wonder_owners: Dictionary = {}


func reset() -> void:
	_wonder_owners.clear()


func set_wonder_owner(wonder_id: String, faction_id: String) -> bool:
	if DataManager.get_wonder(wonder_id).is_empty():
		return false
	if faction_id != "" and faction_id != "neutral" and DataManager.get_faction(faction_id).is_empty():
		return false
	if faction_id == "" or faction_id == "neutral":
		_wonder_owners.erase(wonder_id)
	else:
		_wonder_owners[wonder_id] = faction_id
	return true


func get_wonder_owner(wonder_id: String) -> String:
	return str(_wonder_owners.get(wonder_id, ""))


func get_faction_wonders(faction_id: String) -> Array[String]:
	var result: Array[String] = []
	for wonder_id in _wonder_owners:
		if str(_wonder_owners[wonder_id]) == faction_id:
			result.append(str(wonder_id))
	return result


func has_wonder(faction_id: String, wonder_id: String) -> bool:
	return get_wonder_owner(wonder_id) == faction_id


func get_effect_float(faction_id: String, effect_key: String) -> float:
	var total: float = 0.0
	for wonder_id in get_faction_wonders(faction_id):
		var wonder: Dictionary = DataManager.get_wonder(wonder_id)
		if wonder.is_empty():
			continue
		var effects: Dictionary = wonder.get("effects", {})
		total += float(effects.get(effect_key, 0.0))
	return total


func get_effect_int(faction_id: String, effect_key: String) -> int:
	return int(round(get_effect_float(faction_id, effect_key)))


func get_owned_wonders() -> Dictionary:
	return _wonder_owners.duplicate(true)


func get_save_data() -> Dictionary:
	return {
		"wonder_owners": _wonder_owners.duplicate(true),
	}


func load_save_data(data: Dictionary) -> void:
	var owners: Variant = data.get("wonder_owners", {})
	if owners is Dictionary:
		_wonder_owners = (owners as Dictionary).duplicate(true)
	else:
		_wonder_owners.clear()
