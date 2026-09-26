extends RefCounted
class_name SkirmishTileTextures

## 战术演武：地形 / 兵种贴图路径（ai_art 统一），运行时缓存 Texture2D。
## 所有地形图统一指向 assets/ai_art/terrain（风格一致的新图）；
## ai_art 缺 02/03 变体时回退该地形 01，绝不混用旧 assets/terrain。

const _AI_TERRAIN_DIR := "res://assets/ai_art/terrain/"

const _TERRAIN_PATHS: Dictionary = {
	"plains": "res://assets/ai_art/terrain/tile_plain_01.png",
	"forest": "res://assets/ai_art/terrain/tile_forest_01.png",
	"mountain": "res://assets/ai_art/terrain/tile_mountain_01.png",
	"river": "res://assets/ai_art/terrain/tile_river_01.png",
	"marsh": "res://assets/ai_art/terrain/tile_marsh_01.png",
	"pass": "res://assets/ai_art/terrain/tile_pass_01.png",
	"ford": "res://assets/ai_art/terrain/tile_ford_01.png",
	"desert": "res://assets/ai_art/terrain/tile_desert_01.png",
	"tundra": "res://assets/ai_art/terrain/tile_tundra_01.png",
	"deep_ocean": "res://assets/ai_art/terrain/tile_deepsea_01.png",
	"shallow_ocean": "res://assets/ai_art/terrain/tile_shallowsea_01.png",
}

## 地形 ID 保持不变，仅由格子坐标选择视觉样式（全部 ai_art）。
const _TERRAIN_VARIANT_PATHS: Dictionary = {
	"plains": ["res://assets/ai_art/terrain/tile_plain_01.png", "res://assets/ai_art/terrain/tile_plain_02.png", "res://assets/ai_art/terrain/tile_plain_03.png"],
	"forest": ["res://assets/ai_art/terrain/tile_forest_01.png", "res://assets/ai_art/terrain/tile_forest_02.png", "res://assets/ai_art/terrain/tile_forest_03.png"],
	"mountain": ["res://assets/ai_art/terrain/tile_mountain_01.png", "res://assets/ai_art/terrain/tile_mountain_02.png", "res://assets/ai_art/terrain/tile_mountain_03.png"],
	"marsh": ["res://assets/ai_art/terrain/tile_marsh_01.png", "res://assets/ai_art/terrain/tile_marsh_02.png", "res://assets/ai_art/terrain/tile_marsh_03.png"],
	"desert": ["res://assets/ai_art/terrain/tile_desert_01.png", "res://assets/ai_art/terrain/tile_desert_02.png", "res://assets/ai_art/terrain/tile_desert_03.png"],
	"tundra": ["res://assets/ai_art/terrain/tile_tundra_01.png", "res://assets/ai_art/terrain/tile_tundra_02.png", "res://assets/ai_art/terrain/tile_tundra_03.png"],
	"pass": ["res://assets/ai_art/terrain/tile_pass_01.png", "res://assets/ai_art/terrain/tile_pass_02.png"],
	"shallow_ocean": ["res://assets/ai_art/terrain/tile_shallowsea_01.png", "res://assets/ai_art/terrain/tile_shallowsea_02.png"],
	"deep_ocean": ["res://assets/ai_art/terrain/tile_deepsea_01.png", "res://assets/ai_art/terrain/tile_deepsea_02.png"],
}

const _LAND_TERRAINS: Array[String] = ["plains", "forest", "mountain", "marsh", "desert", "tundra", "pass"]

const _TERRAIN_FALLBACK_COLORS: Dictionary = {
	"plains": Color(0.60, 0.69, 0.46, 1.0),
	"forest": Color(0.36, 0.51, 0.29, 1.0),
	"mountain": Color(0.45, 0.44, 0.46, 1.0),
	"river": Color(0.28, 0.51, 0.72, 1.0),
	"marsh": Color(0.42, 0.50, 0.36, 1.0),
	"pass": Color(0.61, 0.49, 0.31, 1.0),
	"ford": Color(0.43, 0.62, 0.72, 1.0),
	"desert": Color(0.76, 0.67, 0.42, 1.0),
	"tundra": Color(0.74, 0.79, 0.82, 1.0),
	"deep_ocean": Color(0.13, 0.28, 0.52, 1.0),
	"shallow_ocean": Color(0.24, 0.48, 0.72, 1.0),
}

## 战术演武城格据点：七国首都（ai_art/cities）
const _CAPITAL_PATHS: Dictionary = {
	"qin": "res://assets/ai_art/cities/tile_city_qin_capital.png",
	"zhao": "res://assets/ai_art/cities/tile_city_zhao_capital.png",
	"chu": "res://assets/ai_art/cities/tile_city_chu_capital.png",
	"qi": "res://assets/ai_art/cities/tile_city_qi_capital.png",
	"wei": "res://assets/ai_art/cities/tile_city_wei_capital.png",
	"yan": "res://assets/ai_art/cities/tile_city_yan_capital.png",
	"han": "res://assets/ai_art/cities/tile_city_han_capital.png",
}

## 事件插画：按事件 ID 映射（ai_art/events），category 做后备
const _EVENT_ID_PATHS: Dictionary = {
	"drought": "res://assets/ai_art/events/event_drought.png",
	"harvest": "res://assets/ai_art/events/event_harvest.png",
	"flood": "res://assets/ai_art/events/event_flood.png",
	"ambush": "res://assets/ai_art/events/event_ambush.png",
	"siege": "res://assets/ai_art/events/event_siege.png",
	"alliance": "res://assets/ai_art/events/event_alliance.png",
	"coalition": "res://assets/ai_art/events/event_coalition.png",
	"reform": "res://assets/ai_art/events/event_reform.png",
	"philosophy": "res://assets/ai_art/events/event_philosophy.png",
	"trade": "res://assets/ai_art/events/event_trade.png",
	"fortify": "res://assets/ai_art/events/event_fortify.png",
	"changping": "res://assets/ai_art/events/event_changping.png",
	"dynasty_fall": "res://assets/ai_art/events/event_dynasty_fall.png",
	"king_rise": "res://assets/ai_art/events/event_king_rise.png",
	"general_death": "res://assets/ai_art/events/event_general_death.png",
}

## 事件分类后备图（ID 无匹配时使用，ai_art）
const _EVENT_CATEGORY_PATHS: Dictionary = {
	"economy": "res://assets/ai_art/events/event_trade.png",
	"military": "res://assets/ai_art/events/event_siege.png",
	"morale": "res://assets/ai_art/events/event_harvest.png",
	"season": "res://assets/ai_art/events/event_flood.png",
	"politics": "res://assets/ai_art/events/event_reform.png",
	"diplomacy": "res://assets/ai_art/events/event_alliance.png",
	"special": "res://assets/ai_art/events/event_dynasty_fall.png",
	"school": "res://assets/ai_art/events/event_philosophy.png",
}

const _UNIT_PATHS: Dictionary = {
	# 基础步兵
	"militia": "res://assets/ai_art/units/militia_idle.png",
	"infantry": "res://assets/ai_art/units/infantry_idle.png",
	"spear": "res://assets/ai_art/units/spear_idle.png",
	"iron_armored": "res://assets/ai_art/units/iron_armored_idle.png",
	# 基础骑兵
	"scout_team": "res://assets/ai_art/units/scout_team_idle.png",
	"scout_cavalry": "res://assets/ai_art/units/scout_cavalry_idle.png",
	"cavalry": "res://assets/ai_art/units/cavalry_idle.png",
	"shock_cavalry": "res://assets/ai_art/units/shock_cavalry_idle.png",
	"heavy_cavalry": "res://assets/ai_art/units/heavy_cavalry_idle.png",
	"chariot": "res://assets/ai_art/units/chariot_idle.png",
	"horse_archer": "res://assets/ai_art/units/horse_archer_idle.png",
	# 基础远程
	"archer": "res://assets/ai_art/units/archer_idle.png",
	"crossbow": "res://assets/ai_art/units/crossbow_idle.png",
	# 攻城器械
	"battering_ram": "res://assets/ai_art/units/battering_ram_idle.png",
	"catapult": "res://assets/ai_art/units/catapult_idle.png",
	"siege": "res://assets/ai_art/units/catapult_idle.png",
	"ballista": "res://assets/ai_art/units/ballista_idle.png",
	# 水军
	"mengchong": "res://assets/ai_art/units/mengchong_idle.png",
	"dayi": "res://assets/ai_art/units/great_wing_idle.png",
	"great_wing": "res://assets/ai_art/units/great_wing_idle.png",
	"louchuan": "res://assets/ai_art/units/tower_ship_idle.png",
	"tower_ship": "res://assets/ai_art/units/tower_ship_idle.png",
	"navy": "res://assets/ai_art/units/mengchong_idle.png",
	# 国家变体
	"rushi": "res://assets/ai_art/units/qin_ruishix_idle.png",
	"hufu_qibing": "res://assets/ai_art/units/zhao_bianqi_idle.png",
	"jijishou": "res://assets/ai_art/units/qi_jiji_idle.png",
	"shenxi_zhishi": "res://assets/ai_art/units/chu_manjia_idle.png",
	"wuzu": "res://assets/ai_art/units/wei_wuzu_idle.png",
	"liaodong_gongqi": "res://assets/ai_art/units/yan_sishi_idle.png",
	"jinnu": "res://assets/ai_art/units/han_nushou_idle.png",
}

static var _cache: Dictionary = {}
static var _season_hint: String = ""


static func set_season_hint(season: String) -> void:
	_season_hint = season


## 实体建筑占位贴图（优先 ai_art/map_buildings 六边形瓦片，回退统一 ai_art）
const _BUILDING_PATHS: Dictionary = {
	"farm": "res://assets/ai_art/map_buildings/map_farm.png",
	"market": "res://assets/ai_art/map_buildings/map_market.png",
	"wall": "res://assets/ai_art/map_buildings/map_wall.png",
	"arrow_tower": "res://assets/ai_art/map_buildings/map_arrow_tower.png",
	"barracks": "res://assets/ai_art/map_buildings/map_barracks.png",
	"academy": "res://assets/ai_art/map_buildings/map_academy.png",
	"granary": "res://assets/ai_art/map_buildings/map_grain.png",
	"grain": "res://assets/ai_art/map_buildings/map_grain.png",
	"ironworks": "res://assets/ai_art/map_buildings/map_iron_mine.png",
	"iron_mine": "res://assets/ai_art/map_buildings/map_iron_mine.png",
	"quarry": "res://assets/ai_art/map_buildings/map_quarry.png",
	"stable": "res://assets/ai_art/map_buildings/map_stable.png",
	"temple": "res://assets/ai_art/map_buildings/map_temple.png",
	"shrine": "res://assets/ai_art/map_buildings/map_temple.png",
	"dock": "res://assets/ai_art/map_buildings/map_dock.png",
	"workshop": "res://assets/ai_art/map_buildings/map_workshop.png",
	"beacon_tower": "res://assets/ai_art/map_buildings/map_beacon_tower.png",
	"lumbermill": "res://assets/ai_art/map_buildings/map_lumbermill.png",
	"post_station": "res://assets/ai_art/map_buildings/map_post_station.png",
	"inner_gate": "res://assets/ai_art/map_buildings/map_wall.png",
}


static func building_texture(building_id: String, category: String = "") -> Texture2D:
	# 优先 ai_art/map_buildings 六边形俯视瓦片
	if ClassDB.class_exists("ArtCatalog"):
		var art_tex: Texture2D = ArtCatalog.map_building_texture(building_id, category)
		if art_tex != null:
			return art_tex
	var path: String = str(_BUILDING_PATHS.get(building_id, ""))
	if path.is_empty():
		match category:
			"economy":
				path = "res://assets/ai_art/map_buildings/map_market.png"
			"military":
				path = "res://assets/ai_art/map_buildings/map_barracks.png"
			"defense":
				path = "res://assets/ai_art/map_buildings/map_wall.png"
			"politics":
				path = "res://assets/ai_art/map_buildings/map_academy.png"
			_:
				path = "res://assets/ai_art/map_buildings/map_market.png"
	return _load_cached(path)


## 大地图资源点（特产）瓦片
static func map_resource_texture(special_resource: String) -> Texture2D:
	if ClassDB.class_exists("ArtCatalog"):
		var art_tex: Texture2D = ArtCatalog.map_resource_texture(special_resource)
		if art_tex != null:
			return art_tex
	return null


static func terrain_texture(terrain_id: String, season: String = "") -> Texture2D:
	var season_use: String = season if season != "" else _season_hint
	var art_tex: Texture2D = null
	if ClassDB.class_exists("ArtCatalog"):
		art_tex = ArtCatalog.terrain_texture(terrain_id, season_use)
	if art_tex != null:
		return art_tex
	var path: String = str(_TERRAIN_PATHS.get(terrain_id, ""))
	if path.is_empty() and not _TERRAIN_PATHS.has(terrain_id):
		path = str(_TERRAIN_PATHS.get("plains", ""))
	if path.is_empty():
		return null
	return _load_cached(path)


static func terrain_variant_count(terrain_id: String) -> int:
	if _TERRAIN_VARIANT_PATHS.has(terrain_id):
		return (_TERRAIN_VARIANT_PATHS[terrain_id] as Array).size()
	return 1


## 边缘混合按地貌关系分级；海岸只做轻微渗色，避免海水或植被覆盖整格。
static func terrain_edge_blend_alpha(terrain_id: String, neighbor_id: String) -> float:
	if terrain_id == neighbor_id:
		return 0.0
	if terrain_id in _LAND_TERRAINS and neighbor_id in _LAND_TERRAINS:
		return 0.5
	if terrain_id in ["shallow_ocean", "deep_ocean"] and neighbor_id in ["shallow_ocean", "deep_ocean"]:
		return 0.5
	if (terrain_id in _LAND_TERRAINS and neighbor_id == "shallow_ocean") or (terrain_id == "shallow_ocean" and neighbor_id in _LAND_TERRAINS):
		return 0.25
	return 0.0


static func terrain_variant_index(terrain_id: String, col: int, row: int) -> int:
	var count: int = terrain_variant_count(terrain_id)
	if count <= 1:
		return 0
	var mixed: int = (col * 73856093) ^ (row * 19349663) ^ ((col * row + 17) * 83492791)
	mixed = mixed ^ (mixed >> 13)
	return (mixed & 0x7FFFFFFF) % count


static func terrain_variant_path(terrain_id: String, index: int) -> String:
	if _TERRAIN_VARIANT_PATHS.has(terrain_id):
		var paths: Array = _TERRAIN_VARIANT_PATHS[terrain_id] as Array
		var wanted: String = str(paths[clampi(index, 0, paths.size() - 1)])
		# ai_art 缺变体文件时回退该地形 01，保持风格统一
		if ResourceLoader.exists(wanted):
			return wanted
		return str(paths[0])
	return str(_TERRAIN_PATHS.get(terrain_id, _TERRAIN_PATHS["plains"]))


static func terrain_variant_texture(terrain_id: String, col: int, row: int) -> Texture2D:
	return terrain_texture_by_variant(terrain_id, terrain_variant_index(terrain_id, col, row))


static func terrain_texture_by_variant(terrain_id: String, index: int) -> Texture2D:
	if index == 0 and ClassDB.class_exists("ArtCatalog"):
		var art_tex: Texture2D = ArtCatalog.terrain_texture(terrain_id, _season_hint)
		if art_tex != null:
			return art_tex
	return _load_cached(terrain_variant_path(terrain_id, index))


static func terrain_fallback_color(terrain_id: String) -> Color:
	if _TERRAIN_FALLBACK_COLORS.has(terrain_id):
		return _TERRAIN_FALLBACK_COLORS[terrain_id] as Color
	return _TERRAIN_FALLBACK_COLORS["plains"] as Color


static func capital_texture(faction_id: String) -> Texture2D:
	if ClassDB.class_exists("ArtCatalog"):
		var art_tex: Texture2D = ArtCatalog.city_texture("", faction_id, true)
		if art_tex != null:
			return art_tex
	var path: String = str(_CAPITAL_PATHS.get(faction_id, ""))
	if path.is_empty():
		return null
	return _load_cached(path)


static func city_art_texture(city_id: String, faction_id: String = "", is_capital: bool = false) -> Texture2D:
	if ClassDB.class_exists("ArtCatalog"):
		var art_tex: Texture2D = ArtCatalog.city_texture(city_id, faction_id, is_capital)
		if art_tex != null:
			return art_tex
	if is_capital:
		return capital_texture(faction_id)
	return null


static func event_texture(event_id: String, category: String) -> Texture2D:
	if ClassDB.class_exists("ArtCatalog"):
		for key: String in _EVENT_ID_PATHS:
			if event_id.containsn(key):
				var ai_tex: Texture2D = ArtCatalog.event_texture("event_%s.png" % key)
				if ai_tex != null:
					return ai_tex
		var cat_path: String = str(_EVENT_CATEGORY_PATHS.get(category, ""))
		if cat_path != "":
			var ai_cat: Texture2D = ArtCatalog.event_texture(cat_path.get_file())
			if ai_cat != null:
				return ai_cat
	for key: String in _EVENT_ID_PATHS:
		if event_id.containsn(key):
			return _load_cached(str(_EVENT_ID_PATHS[key]))
	var path: String = str(_EVENT_CATEGORY_PATHS.get(category, ""))
	if path.is_empty():
		return null
	return _load_cached(path)


static func unit_texture(unit_type_id: String, faction_id: String = "") -> Texture2D:
	if ClassDB.class_exists("ArtCatalog"):
		var art_tex: Texture2D = ArtCatalog.unit_idle_texture(unit_type_id, faction_id)
		if art_tex != null:
			return art_tex
	var path: String = str(_UNIT_PATHS.get(unit_type_id, _UNIT_PATHS.get("infantry", "")))
	if path.is_empty():
		return null
	return _load_cached(path)


## UI 面板背景（优先 ai_art/ui/panels，回退统一 ai_art）
const _PANEL_PATHS: Dictionary = {
	"city": "res://assets/ai_art/ui/panels/panel_city.png",
	"diplomacy": "res://assets/ai_art/ui/panels/panel_diplomacy.png",
	"event_popup": "res://assets/ai_art/ui/panels/panel_event.png",
	"tech": "res://assets/ai_art/ui/panels/panel_tech.png",
	"school": "res://assets/ai_art/ui/panels/panel_school.png",
	"battle": "res://assets/ai_art/ui/panels/panel_battle.png",
	"settings": "res://assets/ai_art/ui/panels/panel_settings.png",
	"save_load": "res://assets/ai_art/ui/panels/panel_save.png",
	"victory": "res://assets/ai_art/ui/panels/panel_victory.png",
	"defeat": "res://assets/ai_art/ui/panels/panel_defeat.png",
	"new_game": "res://assets/ai_art/ui/panels/panel_new_game.png",
	"unit_info": "res://assets/ai_art/ui/panels/panel_unit_info.png",
}

static func panel_texture(panel_name: String) -> Texture2D:
	if ClassDB.class_exists("ArtCatalog"):
		var ai_key: String = panel_name
		match panel_name:
			"event_popup":
				ai_key = "event"
			"save_load":
				ai_key = "save"
		var art_tex: Texture2D = ArtCatalog.panel_texture(ai_key)
		if art_tex != null:
			return art_tex
		if panel_name in ["victory", "defeat", "new_game", "unit_info"]:
			# ai_art/ui/panels/panel_*.png
			art_tex = ArtCatalog.panel_texture(panel_name)
			if art_tex != null:
				return art_tex
			if panel_name in ["victory", "defeat"]:
				art_tex = ArtCatalog.event_texture(panel_name + ".png")
				if art_tex != null:
					return art_tex
	var path: String = str(_PANEL_PATHS.get(panel_name, ""))
	if path.is_empty():
		return null
	return _load_cached(path)


## UI 图标（资源 / 建筑 / 学派 / 季节 / 科技）
const _ICON_BASE_PATH: String = "res://assets/ai_art/ui/icons/"

static func icon_texture(icon_name: String) -> Texture2D:
	if ClassDB.class_exists("ArtCatalog"):
		var key: String = icon_name
		if key.begins_with("icon_"):
			key = key.substr(5)
		var art_tex: Texture2D = ArtCatalog.icon_texture(key)
		if art_tex != null:
			return art_tex
		art_tex = ArtCatalog.icon_texture(icon_name)
		if art_tex != null:
			return art_tex
	var path: String = _ICON_BASE_PATH + icon_name + ".png"
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


## 创建统一竹简风格按钮
static func styled_button(text: String = "") -> Button:
	var btn := Button.new()
	btn.text = text
	_apply_button_style(btn)
	return btn


## 给场景中已有的 Button 应用统一竹简风格
static func style_scene_button(btn: Button) -> void:
	_apply_button_style(btn)


static func _apply_button_style(btn: Button) -> void:
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Color(0.91, 0.835, 0.69, 1))
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.10, 0.08, 0.06, 0.95)
	bg.border_color = Color(0.45, 0.38, 0.24, 1.0)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(2)
	btn.add_theme_stylebox_override("normal", bg)
	var bg_hover := bg.duplicate()
	bg_hover.bg_color = Color(0.16, 0.12, 0.08, 0.95)
	btn.add_theme_stylebox_override("hover", bg_hover)
	var bg_pressed := bg.duplicate()
	bg_pressed.bg_color = Color(0.06, 0.05, 0.03, 0.95)
	btn.add_theme_stylebox_override("pressed", bg_pressed)
	var bg_disabled := bg.duplicate()
	bg_disabled.bg_color = Color(0.08, 0.07, 0.06, 0.7)
	btn.add_theme_stylebox_override("disabled", bg_disabled)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


## 兼容旧调用：StyleBox 状态由 Godot Button 自动切换
static func update_button_disabled(btn: Button) -> void:
	btn.queue_redraw()


## 动态创建特效 SpriteFrames（15 个特效 × 8 帧）
static func effect_frames(effect_id: String) -> SpriteFrames:
	var base_path := "res://assets/units/effects/%s/" % effect_id
	var dir := DirAccess.open(base_path)
	if not dir:
		return null
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("play")
	sf.set_animation_speed("play", 8.0)
	sf.set_animation_loop("play", false)
	var files: Array[String] = []
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.ends_with(".png") and not entry.ends_with(".import"):
			files.append(base_path + entry)
		entry = dir.get_next()
	dir.list_dir_end()
	files.sort()
	for f in files:
		var tex := load(f) as Texture2D
		if tex:
			sf.add_frame("play", tex)
	return sf


## 将隶书字体设为全局默认字体（在 StartupFlow._ready() 中调用）
static func apply_global_font() -> void:
	var font_path := "res://assets/fonts/pixel_lishu_dynamic.tres"
	if not ResourceLoader.exists(font_path):
		push_warning("[SkirmishTileTextures] 字体文件不存在: %s" % font_path)
		return
	var font: Font = load(font_path)
	if font == null:
		push_warning("[SkirmishTileTextures] 字体加载失败: %s" % font_path)
		return
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		var existing: Theme = tree.root.theme
		if existing == null:
			existing = Theme.new()
			tree.root.theme = existing
		existing.default_font = font
		existing.default_font_size = 18
		existing.set_color("font_color", "Label", Color.WHITE)
		existing.set_color("font_color", "Button", Color.WHITE)
		existing.set_color("font_outline_color", "Label", Color(0, 0, 0, 0))
		existing.set_constant("outline_size", "Label", 0)
