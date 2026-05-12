extends RefCounted
class_name SkirmishTileTextures

## 战术演武：地形 / 兵种贴图路径（占位美术），运行时缓存 Texture2D。

const _TERRAIN_PATHS: Dictionary = {
	"plains": "res://photos/terrain(c)/tile_plain.png",
	"forest": "res://photos/terrain(c)/tile_forest.png",
	"mountain": "res://photos/terrain(c)/tile_mountain.png",
	"river": "res://photos/terrain(c)/tile_river.png",
	"marsh": "res://photos/terrain(c)/tile_swamp.png",
	"pass": "res://photos/terrain(c)/tile_pass.png",
	"ford": "res://photos/terrain(c)/tile_bridge.png",
	"desert": "res://photos/terrain(c)/tile_desert.png",
	"tundra": "res://photos/terrain(c)/tile_tundra.png",
}

## 战术演武城格据点：秦 / 赵首都（美工资源）
const _CAPITAL_PATHS: Dictionary = {
	"qin": "res://photos/city(c)/city_capital_qin_hex.png",
	"zhao": "res://photos/city(c)/city_capital_zhao.png",
	"chu": "res://photos/city(c)/city_capital_chu.png",
	"qi": "res://photos/city(c)/city_capital_qi.png",
	"wei": "res://photos/city(c)/city_capital_wei.png",
	"yan": "res://photos/city(c)/city_capital_yan.png",
	"han": "res://photos/city(c)/city_capital_han.png",
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
