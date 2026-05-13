extends RefCounted
class_name SkirmishTileTextures

## 战术演武：地形 / 兵种贴图路径（占位美术），运行时缓存 Texture2D。

const _TERRAIN_PATHS: Dictionary = {
	"plains": "res://photos/terrain/tile_plain_01.png",
	"forest": "res://photos/terrain/tile_forest_01.png",
	"mountain": "res://photos/terrain/tile_mountain_01.png",
	"river": "res://photos/terrain/tile_river_01.png",
	"marsh": "res://photos/terrain/tile_marsh_01.png",
	"pass": "res://photos/terrain/tile_pass_01.png",
	"ford": "res://photos/terrain/tile_ford_01.png",
	"desert": "res://photos/terrain/tile_desert_01.png",
	"tundra": "res://photos/terrain/tile_plain_01.png",  # 暂用平原，待美术补充冻土贴图
}

## 战术演武城格据点：七国首都（美工资源）
const _CAPITAL_PATHS: Dictionary = {
	"qin": "res://photos/city/qin.png",
	"zhao": "res://photos/city/zhao.png",
	"chu": "res://photos/city/chu.png",
	"qi": "res://photos/city/qi.png",
	"wei": "res://photos/city/wei.png",
	"yan": "res://photos/city/yan.png",
	"han": "res://photos/city/han.png",
}

## 事件插画：按事件 ID 映射，category 做后备
const _EVENT_ID_PATHS: Dictionary = {
	"drought": "res://photos/event/event_drought.png",
	"harvest": "res://photos/event/event_harvest.png",
	"flood": "res://photos/event/event_flood.png",
	"ambush": "res://photos/event/event_ambush.png",
	"siege": "res://photos/event/event_siege.png",
	"alliance": "res://photos/event/event_alliance.png",
	"coalition": "res://photos/event/event_coalition.png",
	"reform": "res://photos/event/event_reform.png",
	"philosophy": "res://photos/event/event_philosophy.png",
	"trade": "res://photos/event/event_trade.png",
	"fortify": "res://photos/event/event_fortify.png",
	"changping": "res://photos/event/event_changping.png",
	"dynasty_fall": "res://photos/event/event_dynasty_fall.png",
	"king_rise": "res://photos/event/event_king_rise.png",
	"general_death": "res://photos/event/event_general_death.png",
}

## 事件分类后备图（ID 无匹配时使用）
const _EVENT_CATEGORY_PATHS: Dictionary = {
	"economy": "res://photos/event/event_trade.png",
	"military": "res://photos/event/event_siege.png",
	"morale": "res://photos/event/event_harvest.png",
	"season": "res://photos/event/event_flood.png",
	"politics": "res://photos/event/event_reform.png",
	"diplomacy": "res://photos/event/event_alliance.png",
	"special": "res://photos/event/event_dynasty_fall.png",
	"school": "res://photos/event/event_philosophy.png",
}

const _UNIT_PATHS: Dictionary = {
	"infantry": "res://photos/unit/unit_infantry.png",
	"archer": "res://photos/unit/unit_archer.png",
	"crossbow": "res://photos/unit/unit_archer.png",
	"cavalry": "res://photos/unit/unit_cavalry.png",
	"chariot": "res://photos/unit/unit_chariot.png",
	"siege": "res://photos/unit/unit_siege.png",
	"navy": "res://photos/unit/unit_infantry.png",
	"spear": "res://photos/unit/unit_wei_wuzu.png",
}

static var _cache: Dictionary = {}


static func terrain_texture(terrain_id: String) -> Texture2D:
	var path: String = str(_TERRAIN_PATHS.get(terrain_id, _TERRAIN_PATHS.get("plains", "")))
	if path.is_empty():
		return null
	return _load_cached(path)


static func capital_texture(faction_id: String) -> Texture2D:
	var path: String = str(_CAPITAL_PATHS.get(faction_id, ""))
	if path.is_empty():
		return null
	return _load_cached(path)


static func event_texture(event_id: String, category: String) -> Texture2D:
	# 先按 event_id 匹配关键词
	for key: String in _EVENT_ID_PATHS:
		if event_id.containsn(key):
			return _load_cached(str(_EVENT_ID_PATHS[key]))
	# 退回 category 后备
	var path: String = str(_EVENT_CATEGORY_PATHS.get(category, ""))
	if path.is_empty():
		return null
	return _load_cached(path)


static func unit_texture(unit_type_id: String) -> Texture2D:
	var path: String = str(_UNIT_PATHS.get(unit_type_id, _UNIT_PATHS.get("infantry", "")))
	if path.is_empty():
		return null
	return _load_cached(path)


static func _load_cached(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path] as Texture2D
	var res: Resource = load(path)
	var tex: Texture2D = res as Texture2D
	if tex != null:
		_cache[path] = tex
	return tex


## 单元测试或热重载时可清空缓存（一般无需调用）
static func clear_cache() -> void:
	_cache.clear()
