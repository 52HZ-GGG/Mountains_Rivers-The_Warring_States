extends RefCounted
class_name SkirmishTileTextures

## 战术演武：地形 / 兵种贴图路径（占位美术），运行时缓存 Texture2D。

const _TERRAIN_PATHS: Dictionary = {
	"plains": "res://photos/terrain/plain.png",
	"forest": "res://photos/terrain/forest.png",
	"mountain": "res://photos/terrain/title_mountain1.jpg",
	"river": "res://photos/terrain/river.png",
	"marsh": "res://photos/terrain/swamp.png",
	"pass": "res://photos/terrain/ferry.png",
	"ford": "res://photos/terrain/ferry.png",
	"desert": "res://photos/terrain/desert.png",
	"lake": "res://photos/terrain/lake.png",
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

# ── 事件插画 ──
const _EVENT_PATHS: Dictionary = {
	"harvest": "res://photos/event/event_harvest.png",
	"drought": "res://photos/event/event_drought.png",
	"flood": "res://photos/event/event_flood.png",
	"trade": "res://photos/event/event_trade.png",
	"ambush": "res://photos/event/event_ambush.png",
	"siege": "res://photos/event/event_siege.png",
	"alliance": "res://photos/event/event_alliance.png",
	"coalition": "res://photos/event/event_coalition.png",
	"reform": "res://photos/event/event_reform.png",
	"philosophy": "res://photos/event/event_philosophy.png",
	"changping": "res://photos/event/event_changping.png",
	"fortify": "res://photos/event/event_fortify.png",
	"general_death": "res://photos/event/event_general_death.png",
	"king_rise": "res://photos/event/event_king_rise.png",
	"dynasty_fall": "res://photos/event/event_dynasty_fall.png",
}

# 事件 category → 默认插画（当 event_id 无直接匹配时使用）
const _EVENT_CATEGORY_DEFAULTS: Dictionary = {
	"economy": "res://photos/event/event_trade.png",
	"military": "res://photos/event/event_siege.png",
	"morale": "res://photos/event/event_philosophy.png",
	"season": "res://photos/event/event_harvest.png",
	"politics": "res://photos/event/event_reform.png",
	"diplomacy": "res://photos/event/event_alliance.png",
	"school": "res://photos/event/event_philosophy.png",
	"special": "res://photos/event/event_dynasty_fall.png",
}

# ── 外交插画 ──
const _DIPLOMACY_PATHS: Dictionary = {
	"declare_war": "res://photos/diplomacy/dip_declare_war.png",
	"ceasefire": "res://photos/diplomacy/dip_ceasefire.png",
	"alliance": "res://photos/diplomacy/dip_alliance.png",
	"peace": "res://photos/diplomacy/dip_peace.png",
	"trade": "res://photos/diplomacy/dip_trade.png",
	"tribute": "res://photos/diplomacy/dip_tribute.png",
	"spy": "res://photos/diplomacy/dip_spy.png",
	"betrayal": "res://photos/diplomacy/dip_betrayal.png",
	"cession": "res://photos/diplomacy/dip_cession.png",
	"marriage": "res://photos/diplomacy/dip_marriage.png",
}

# ── 君主头像 ──
const _PORTRAIT_MONARCH_PATHS: Dictionary = {
	"qin": "res://photos/portrait/portrait_monarch_qin_hires.png",
	"zhao": "res://photos/portrait/portrait_monarch_zhao_hires.png",
	"chu": "res://photos/portrait/portrait_monarch_chu_hires.png",
	"qi": "res://photos/portrait/portrait_monarch_qi_hires.png",
	"wei": "res://photos/portrait/portrait_monarch_wei_hires.png",
	"yan": "res://photos/portrait/portrait_monarch_yan_hires.png",
	"han": "res://photos/portrait/portrait_monarch_han_hires.png",
}

# ── 势力旗帜 ──
const _FLAG_PATHS: Dictionary = {
	"qin": "res://photos/flag/flag_qin.png",
	"zhao": "res://photos/flag/flag_zhao.png",
	"chu": "res://photos/flag/flag_chu.png",
	"qi": "res://photos/flag/flag_qi.png",
	"wei": "res://photos/flag/flag_wei.png",
	"yan": "res://photos/flag/flag_yan.png",
	"han": "res://photos/flag/flag_han.png",
}

# ── Logo ──
const _LOGO_PATH: String = "res://photos/logo/logo_shanhece.png"

# ── 关系状态 → 外交插画映射 ──
const _STATUS_DIPLOMACY_MAP: Dictionary = {
	"war": "declare_war",
	"alliance": "alliance",
	"non_aggression": "peace",
	"trade": "trade",
	"peace": "peace",
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
	if res == null:
		push_warning("[SkirmishTileTextures] load() 返回 null: %s" % path)
		return null
	var tex: Texture2D = res as Texture2D
	if tex != null:
		_cache[path] = tex
	else:
		push_warning("[SkirmishTileTextures] 资源不是 Texture2D: %s (类型: %s)" % [path, res.get_class()])
	return tex


## 单元测试或热重载时可清空缓存（一般无需调用）
static func clear_cache() -> void:
	_cache.clear()


## 根据事件 ID 和 category 获取事件插画
static func event_texture(event_id: String, category: String = "") -> Texture2D:
	var path: String = _resolve_event_path(event_id, category)
	if path.is_empty():
		return null
	return _load_cached(path)


## 根据外交动作获取外交插画
static func diplomacy_texture(action: String) -> Texture2D:
	var path: String = str(_DIPLOMACY_PATHS.get(action, ""))
	if path.is_empty():
		return null
	return _load_cached(path)


## 根据关系状态获取外交插画（状态 → 动作 → 插画）
static func diplomacy_texture_for_status(status: String) -> Texture2D:
	var action: String = str(_STATUS_DIPLOMACY_MAP.get(status, "peace"))
	return diplomacy_texture(action)


## 获取君主头像
static func portrait_texture(faction_id: String) -> Texture2D:
	var path: String = str(_PORTRAIT_MONARCH_PATHS.get(faction_id, ""))
	if path.is_empty():
		return null
	return _load_cached(path)


## 获取势力旗帜
static func flag_texture(faction_id: String) -> Texture2D:
	var path: String = str(_FLAG_PATHS.get(faction_id, ""))
	if path.is_empty():
		return null
	return _load_cached(path)


## 获取游戏 Logo
static func logo_texture() -> Texture2D:
	if _LOGO_PATH.is_empty():
		return null
	return _load_cached(_LOGO_PATH)


## 解析事件插画路径：优先按 event_id 关键词匹配，其次按 category 兜底
static func _resolve_event_path(event_id: String, category: String) -> String:
	# 从 event_id 中提取关键词匹配（如 evt_drought → drought, hist_changping → changping）
	for key in _EVENT_PATHS:
		if event_id.contains(key):
			return str(_EVENT_PATHS[key])
	# 按 category 兜底
	if not category.is_empty():
		var fallback: String = str(_EVENT_CATEGORY_DEFAULTS.get(category, ""))
		if not fallback.is_empty():
			return fallback
	# 最终兜底
	return str(_EVENT_CATEGORY_DEFAULTS.get("economy", ""))
