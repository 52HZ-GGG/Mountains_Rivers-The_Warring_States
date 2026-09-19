extends Node

## 科技解锁条件门面（TechUnlockContext）
##
## 科技特殊条件的唯一校验入口。TechSystem 只调用本节点，
## 不直接依赖 CityManager / DiplomacySystem / WonderManager。
## 具体校验器由各业务系统在 _ready 中注册（组合根绑定）。

var _checkers: Dictionary = {}  # {cond_type: Callable(faction_id, condition) -> bool}


func register_checker(cond_type: String, checker: Callable) -> void:
	if cond_type == "":
		return
	_checkers[cond_type] = checker


func unregister_checker(cond_type: String) -> void:
	_checkers.erase(cond_type)


func has_checker(cond_type: String) -> bool:
	return _checkers.has(cond_type)


func clear_checkers() -> void:
	_checkers.clear()


## 单条条件。fame 等预留类型默认通过；未注册类型默认拒绝（fail-closed）。
func check_condition(faction_id: String, condition: Dictionary) -> bool:
	var cond_type: String = str(condition.get("type", ""))
	if cond_type == "" or cond_type == "fame":
		return true
	if not _checkers.has(cond_type):
		return false
	return bool(_checkers[cond_type].call(faction_id, condition))


## 整项科技的 special_conditions + requires_wonder。
func check_tech(faction_id: String, tech: Dictionary) -> bool:
	if tech.is_empty():
		return false
	for condition in tech.get("special_conditions", []):
		if not check_condition(faction_id, condition as Dictionary):
			return false
	var wonder_id: String = str(tech.get("requires_wonder", ""))
	if wonder_id != "":
		return check_condition(faction_id, {"type": "wonder", "wonder_id": wonder_id})
	return true


## 供 UI/调试：列出某科技当前未满足的条件类型。
func missing_conditions(faction_id: String, tech: Dictionary) -> Array:
	var missing: Array = []
	for condition in tech.get("special_conditions", []):
		var cond: Dictionary = condition as Dictionary
		if not check_condition(faction_id, cond):
			missing.append(cond)
	var wonder_id: String = str(tech.get("requires_wonder", ""))
	if wonder_id != "":
		var wcond := {"type": "wonder", "wonder_id": wonder_id}
		if not check_condition(faction_id, wcond):
			missing.append(wcond)
	return missing
