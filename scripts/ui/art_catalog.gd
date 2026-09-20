extends RefCounted
class_name ArtCatalog

## 美术资源目录：ai_art 交付物 → Godot 路径解析。
## 城市图标按 city_id 后缀扫描（容忍国别前缀笔误），UI/单位优先 ai_art，失败再回退旧路径。

const AI_CITIES_DIR := "res://assets/ai_art/cities/"
const AI_TERRAIN_DIR := "res://assets/ai_art/terrain/"
const AI_UI_PANELS := "res://assets/ai_art/ui/panels/"
const AI_UI_BUTTONS := "res://assets/ai_art/ui/buttons/"
const AI_UI_ICONS := "res://assets/ai_art/ui/icons/"
const AI_UI_HIGHLIGHTS := "res://assets/ai_art/ui/highlights/"
const AI_UNITS_DIR := "res://assets/ai_art/units/"
const AI_OVERLAY_DIR := "res://assets/ai_art/overlay/"
const AI_AUDIO_BGM := "res://assets/audio/bgm/main_theme.wav"
const AI_AUDIO_BATTLE_BGM := "res://assets/audio/bgm/battle_theme.wav"
const AI_AUDIO_SFX_DIR := "res://assets/audio/sfx/"

## city_id → 精确文件名（与 cities.json 中文名一一对应，禁止再靠目录猜）
## 命名说明：美术文件偶有拼音笔误/异写，以本表为准
const _CITY_FILE_ALIAS: Dictionary = {
	# —— 首都 ——
	"xianyang": "tile_city_qin_capital.png",      # 咸阳·秦
	"linzi": "tile_city_qi_capital.png",          # 临淄·齐
	"handan": "tile_city_zhao_capital.png",       # 邯郸·赵
	"ying": "tile_city_chu_capital.png",          # 郢·楚
	"daliang": "tile_city_wei_capital.png",       # 大梁·魏
	"xinzheng": "tile_city_han_capital.png",      # 新郑·韩
	"ji": "tile_city_yan_capital.png",            # 蓟·燕
	# —— 秦 ——
	"yongcheng": "tile_city_qi_yongcheng.png",    # 雍城（美术前缀误作 qi）
	"yueyang": "tile_city_qi_yueyang.png",        # 栎阳（美术前缀误作 qi）
	"chencang": "tile_city_qin_chencang.png",     # 陈仓
	"longxi": "tile_city_qin_longxi.png",         # 陇西
	"shujun": "tile_city_qin_shujun.png",         # 蜀郡
	"nanzheng": "tile_city_qin_nanzheng.png",     # 南郑
	"hanzhong": "tile_city_qin_hanzhong.png",     # 汉中
	# —— 楚 ——
	"shouchun": "tile_city_chu_shouchun.png",     # 寿春
	"yuancheng": "tile_city_chu_yuancheng.png",   # 宛城
	"chencheng": "tile_city_chu_chencheng.png",   # 陈城
	"jiangling": "tile_city_chu_jiangling.png",   # 江陵
	"pengcheng": "tile_city_chu_pengcheng.png",   # 彭城
	"wu": "tile_city_chu_wu.png",                 # 吴
	"kuaiji": "tile_city_chu_kuaiji.png",         # 会稽
	"changsha": "tile_city_chu_changsha.png",     # 长沙
	# —— 齐 ——
	"jimo": "tile_city_qi_jimo.png",              # 即墨
	"yingqiu": "tile_city_qi_yingqiu.png",        # 营丘
	"donga": "tile_city_qi_donga.png",            # 东阿
	"pinglu": "tile_city_qi_pinglu.png",          # 平陆
	"xue": "tile_city_qi_xue.png",                # 薛
	"langye": "tile_city_qi_langye.png",          # 琅琊（与 city_id 同名优先）
	# —— 赵 ——
	"daijun": "tile_city_zhao_daijun.png",        # 代郡
	"jinyang": "tile_city_zhao_jinyang.png",      # 晋阳
	"zhongshan": "tile_city_zhao_zhongshan.png",  # 中山
	"yunzhong": "tile_city_zhao_yunzhong.png",    # 云中
	"yanmen": "tile_city_zhao_yanmen.png",        # 雁门
	"taoyu": "tile_city_zhao_taoyu.png",          # 陶邑
	# —— 魏 ——
	"anyi": "tile_city_wei_anyi.png",             # 安邑
	"hedong": "tile_city_wei_hedong.png",         # 河东
	"puyang": "tile_city_wei_puyang.png",         # 濮阳
	"ye": "tile_city_wei_ye.png",                 # 邺
	"huaxia": "tile_city_wei_huaxia.png",         # 华夏
	# —— 韩 ——
	"nanyang": "tile_city_han_nanyang.png",       # 南阳
	"shangdang": "tile_city_han_shangdang.png",   # 上党
	"yiyang": "tile_city_han_yiyang.png",         # 宜阳
	"yangzhai": "tile_city_han_yangzhai.png",     # 阢翟（另有 yangdi 异写，优先 yangzhai）
	# —— 燕 ——
	"liaoyang": "tile_city_yan_liaoyang.png",     # 辽阳
	"liaoxi": "tile_city_yan_liaoxi.png",         # 辽西
	"shanggu": "tile_city_yan_shanggu.png",       # 上谷
	"yuyang": "tile_city_yan_yuyang.png",         # 渔阳
	# —— 中立 ——
	"luoyi": "tile_city_neutral_luoyi.png",       # 洛邑
	"xingtai": "tile_city_neutral_xingtai.png",   # 邢台
	"dingtao": "tile_city_neutral_dingtao.png",   # 定陶
}

## 首选文件缺失时的后备（同城异写文件）
const _CITY_FILE_FALLBACK: Dictionary = {
	"langye": ["tile_city_qi_langya.png"],
	"yangzhai": ["tile_city_han_yangdi.png"],
	"yongcheng": ["tile_city_qi_yongcheng.png", "tile_city_qin_yongcheng.png"],
	"yueyang": ["tile_city_qi_yueyang.png", "tile_city_qin_yueyang.png"],
}

static var _city_file_index: Dictionary = {}  # city_id -> filename
static var _index_ready: bool = false
static var _tex_cache: Dictionary = {}


static func _ensure_city_index() -> void:
	if _index_ready:
		return
	_city_file_index.clear()
	for city_id in _CITY_FILE_ALIAS:
		_city_file_index[city_id] = str(_CITY_FILE_ALIAS[city_id])
	_index_ready = true


static func city_texture(city_id: String, faction_id: String = "", is_capital: bool = false) -> Texture2D:
	_ensure_city_index()
	var candidates: Array[String] = []
	if _city_file_index.has(city_id):
		candidates.append(str(_city_file_index[city_id]))
	if _CITY_FILE_FALLBACK.has(city_id):
		for fb in _CITY_FILE_FALLBACK[city_id]:
			var fb_name := str(fb)
			if not candidates.has(fb_name):
				candidates.append(fb_name)
	if is_capital and faction_id != "":
		var cap_name := "tile_city_%s_capital.png" % faction_id
		if not candidates.has(cap_name):
			candidates.append(cap_name)
	for fname in candidates:
		var tex := _load_tex(AI_CITIES_DIR + fname)
		if tex != null:
			return tex
		# 引擎 tiles 目录（首都占位图）
		var engine_tex := _load_tex("res://assets/tiles/" + fname)
		if engine_tex != null:
			return engine_tex
	return null


static func city_art_filename(city_id: String) -> String:
	_ensure_city_index()
	return str(_city_file_index.get(city_id, ""))


static func terrain_texture(terrain_id: String, season: String = "") -> Texture2D:
	var map := {
		"plains": "tile_plain_01.png",
		"forest": "tile_forest_01.png",
		"mountain": "tile_mountain_01.png",
		# 临时：河流用浅海瓦片代替（正式 river overlay 后再改回）
		"river": "tile_shallowsea_01.png",
		"marsh": "tile_marsh_01.png",
		"pass": "tile_pass_01.png",
		"ford": "tile_ford_01.png",
		"desert": "tile_desert_01.png",
		"tundra": "tile_tundra_01.png",
		"deep_ocean": "tile_deepsea_01.png",
		"shallow_ocean": "tile_shallowsea_01.png",
		"deepsea": "tile_deepsea_01.png",
		"shallowsea": "tile_shallowsea_01.png",
	}
	# 季节差分（当前仅平原有 spring/autumn/winter）
	if season != "" and terrain_id == "plains":
		var season_name := season.to_lower()
		var season_file := "tile_plain_%s.png" % season_name
		var season_tex := _load_tex(AI_TERRAIN_DIR + season_file)
		if season_tex != null:
			return season_tex
	var fname: String = str(map.get(terrain_id, "tile_plain_01.png"))
	var tex := _load_tex(AI_TERRAIN_DIR + fname)
	if tex != null:
		return tex
	return _load_tex("res://assets/terrain/" + fname)


static func panel_texture(panel_key: String) -> Texture2D:
	var map := {
		"main": "panel_main.png",
		"city": "panel_city.png",
		"battle": "panel_battle.png",
		"event": "panel_event.png",
		"settings": "panel_settings.png",
		"event_popup": "panel_event.png",
		"diplomacy": "panel_diplomacy.png",
		"tech": "panel_tech.png",
		"school": "panel_school.png",
		"save": "panel_save.png",
		"victory": "panel_victory.png",
		"defeat": "panel_defeat.png",
		"new_game": "panel_new_game.png",
		"unit_info": "panel_unit_info.png",
		"save_load": "panel_save.png",
	}
	var fname: String = str(map.get(panel_key, ""))
	if fname.is_empty():
		return null
	return _load_tex(AI_UI_PANELS + fname)


static func button_stylebox(state: String) -> StyleBoxTexture:
	var map := {
		"normal": "button_default.png",
		"hover": "button_hover.png",
		"pressed": "button_pressed.png",
		"disabled": "button_disabled.png",
	}
	var tex := _load_tex(AI_UI_BUTTONS + str(map.get(state, "button_default.png")))
	if tex == null:
		return null
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = 24.0
	sb.texture_margin_right = 24.0
	sb.texture_margin_top = 12.0
	sb.texture_margin_bottom = 12.0
	return sb


static func icon_texture(icon_key: String) -> Texture2D:
	var map := {
		"food": "icon_food.png",
		"gold": "icon_gold.png",
		"wood": "icon_wood.png",
		"iron": "icon_iron.png",
		"stone": "icon_stone.png",
		"population": "icon_population.png",
		"morale": "icon_morale.png",
		"culture": "icon_culture.png",
		"horse": "icon_horse.png",
		# 磁盘文件为 icon_craftsman.png（单数）
		"craftsmen": "icon_craftsman.png",
		"craftsman": "icon_craftsman.png",
		"building_materials": "icon_building_materials.png",
		"troops": "icon_troops.png",
		"military": "icon_troops.png",
		"confucian": "icon_confucian.png",
		"taoist": "icon_taoist.png",
		"legalist": "icon_legalist.png",
		"militarist": "icon_militarist.png",
	}
	var fname: String = str(map.get(icon_key, ""))
	if fname.is_empty():
		return null
	var tex := _load_tex(AI_UI_ICONS + fname)
	if tex != null:
		return tex
	var old_map := {
		"food": "icon_food.png",
		"gold": "icon_gold.png",
		"wood": "icon_wood.png",
		"iron": "icon_iron.png",
		"morale": "icon_morale.png",
		"horse": "icon_horse.png",
		"troops": "icon_troops.png",
	}
	if old_map.has(icon_key):
		return _load_tex("res://assets/ui/icons/" + str(old_map[icon_key]))
	return null


static func highlight_texture(kind: String) -> Texture2D:
	var map := {
		"selected": "highlight_selected.png",
		"move": "highlight_move.png",
		"attack": "highlight_attack.png",
	}
	var fname: String = str(map.get(kind, "highlight_selected.png"))
	var tex := _load_tex(AI_UI_HIGHLIGHTS + fname)
	if tex != null:
		return tex
	var old := {
		"selected": "ui_highlight_select.png",
		"move": "ui_highlight_move.png",
		"attack": "ui_highlight_attack.png",
	}
	return _load_tex("res://assets/ui/highlights/" + str(old.get(kind, "ui_highlight_select.png")))


## 势力旗帜 flag_{qin,qi,zhao,chu,wei,han,yan}.png
static func faction_flag(faction_id: String) -> Texture2D:
	if faction_id.is_empty():
		return null
	return _load_tex(AI_UI_ICONS + "flag_%s.png" % faction_id)


## 建筑图标：building_{id}.png（与 buildings.json id 对齐）
static func building_icon(building_id: String) -> Texture2D:
	if building_id.is_empty():
		return null
	return _load_tex(AI_UI_ICONS + "building_%s.png" % building_id)


## 存档槽 / 势力卡片
static func ui_card_texture(kind: String) -> Texture2D:
	var map := {
		"faction_normal": "faction_card_normal.png",
		"faction_selected": "faction_card_selected.png",
		"save_slot": "save_slot.png",
	}
	var fname: String = str(map.get(kind, ""))
	if fname.is_empty():
		return null
	return _load_tex(AI_UI_PANELS + fname)


## 战略单位 idle：优先 ai_art/units/{unit_id}_idle.png（与 units.json 对齐）
static func unit_idle_texture(unit_type_id: String, faction_id: String = "") -> Texture2D:
	# 七国特色（units.json 变体 id 或美术命名）
	var faction_units := {
		"rushi": "qin_ruishix_idle.png",
		"qin_ruishi": "qin_ruishix_idle.png",
		"jijishou": "qi_jiji_idle.png",
		"hufu_qibing": "zhao_bianqi_idle.png",
		"wuzu": "wei_wuzu_idle.png",
		"shenxi_zhishi": "chu_manjia_idle.png",
		"jinnu": "han_nushou_idle.png",
		"liaodong_gongqi": "yan_sishi_idle.png",
		# 基础兵种 id → 文件名（units.json）
		"militia": "militia_idle.png",
		"infantry": "infantry_idle.png",
		"spear": "spear_idle.png",
		"scout_team": "scout_team_idle.png",
		"iron_armored": "iron_armored_idle.png",
		"scout_cavalry": "scout_cavalry_idle.png",
		"cavalry": "cavalry_idle.png",
		"shock_cavalry": "shock_cavalry_idle.png",
		"heavy_cavalry": "heavy_cavalry_idle.png",
		"chariot": "chariot_idle.png",
		"archer": "archer_idle.png",
		"crossbow": "crossbow_idle.png",
		"horse_archer": "horse_archer_idle.png",
		"battering_ram": "battering_ram_idle.png",
		"catapult": "catapult_idle.png",
		"siege": "catapult_idle.png",
		"ballista": "ballista_idle.png",
		"mengchong": "mengchong_idle.png",
		"great_wing": "great_wing_idle.png",
		"dayi": "great_wing_idle.png",
		"tower_ship": "tower_ship_idle.png",
		"louchuan": "tower_ship_idle.png",
		"navy": "mengchong_idle.png",
	}
	var fname: String = str(faction_units.get(unit_type_id, ""))
	# 后备：{id}_idle.png
	if fname.is_empty():
		fname = "%s_idle.png" % unit_type_id
	var tex := _load_tex(AI_UNITS_DIR + fname)
	if tex != null:
		return tex
	# 再后备：旧 portraits
	return null


## 事件插画：ai_art/events/{filename}
static func event_texture(filename: String) -> Texture2D:
	if filename.is_empty():
		return null
	var fname: String = filename if filename.ends_with(".png") else filename + ".png"
	var tex := _load_tex("res://assets/ai_art/events/" + fname)
	if tex != null:
		return tex
	# 旧路径 assets/events
	return _load_tex("res://assets/events/" + fname)


## 君主 / 大臣头像
static func lord_portrait(faction_id: String) -> Texture2D:
	if faction_id.is_empty():
		return null
	return _load_tex(AI_UNITS_DIR + "portraits/lord_%s.png" % faction_id)


static func minister_portrait(minister_key: String) -> Texture2D:
	if minister_key.is_empty():
		return null
	var fname := minister_key if minister_key.begins_with("minister_") else "minister_%s.png" % minister_key
	if not fname.ends_with(".png"):
		fname += ".png"
	return _load_tex(AI_UNITS_DIR + "ministers/" + fname)


## UI 杂项 / 横幅 / 背景
static func ui_misc_texture(kind: String) -> Texture2D:
	var map := {
		"game_logo": "game_logo.png",
		"loading_bar": "loading_bar.png",
		"loading_bar_bg": "loading_bar_bg.png",
		"resource_bar": "resource_bar.png",
		"end_turn_button": "end_turn_button.png",
		"health_bar": "health_bar.png",
	}
	var fname: String = str(map.get(kind, ""))
	if fname.is_empty():
		return null
	return _load_tex("res://assets/ai_art/ui/misc/" + fname)


static func season_banner(season: String) -> Texture2D:
	return _load_tex("res://assets/ai_art/ui/banners/season_%s.png" % season)


static func ui_background(kind: String) -> Texture2D:
	var map := {
		"main_menu": "main_menu.png",
		"faction_select": "faction_select.png",
	}
	var fname: String = str(map.get(kind, ""))
	if fname.is_empty():
		return null
	return _load_tex("res://assets/ai_art/ui/backgrounds/" + fname)


static func wonder_icon(wonder_id: String) -> Texture2D:
	if wonder_id.is_empty():
		return null
	return _load_tex(AI_UI_ICONS + "wonders/%s.png" % wonder_id)


static func overlay_texture(key: String) -> Texture2D:
	var map := {
		"river": "river_belt.png",
		"pass": "pass_gate.png",
		"ford": "ford_stepping_stones.png",
	}
	var fname: String = str(map.get(key, ""))
	if fname.is_empty():
		return null
	return _load_tex(AI_OVERLAY_DIR + fname)


static func bgm_path() -> String:
	return AI_AUDIO_BGM


static func battle_bgm_path() -> String:
	return AI_AUDIO_BATTLE_BGM


## 音效：ui_click / battle_hit / event_popup / turn_start / building_complete / recruit_complete
static func sfx_path(key: String) -> String:
	var map := {
		"ui_click": "ui_click.wav",
		"battle_hit": "battle_hit.wav",
		"event_popup": "event_popup.wav",
		"turn_start": "turn_start.wav",
		"building_complete": "building_complete.wav",
		"recruit_complete": "recruit_complete.wav",
	}
	var fname: String = str(map.get(key, ""))
	if fname.is_empty():
		return ""
	var full := AI_AUDIO_SFX_DIR + fname
	return full if ResourceLoader.exists(full) else ""


static func city_index_snapshot() -> Dictionary:
	_ensure_city_index()
	return _city_file_index.duplicate(true)


static func _load_tex(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _tex_cache.has(path):
		return _tex_cache[path] as Texture2D
	if not ResourceLoader.exists(path):
		return null
	var res: Resource = load(path)
	var tex: Texture2D = res as Texture2D
	if tex != null:
		_tex_cache[path] = tex
	return tex


## 大地图建筑瓦片：ai_art/map_buildings/map_*.png
const AI_MAP_BUILDINGS := "res://assets/ai_art/map_buildings/"

## building_id → map 瓦片文件名（与 buildings.json 常用 id 对齐）
static func map_building_texture(building_id: String, category: String = "") -> Texture2D:
	var map := {
		"barracks": "map_barracks.png",
		"farm": "map_farm.png",
		"market": "map_market.png",
		"workshop": "map_workshop.png",
		"stable": "map_stable.png",
		"iron_mine": "map_iron_mine.png",
		"ironworks": "map_iron_mine.png",
		"quarry": "map_quarry.png",
		"granary": "map_grain.png",
		"grain": "map_grain.png",
		"academy": "map_academy.png",
		"wall": "map_wall.png",
		"beacon_tower": "map_beacon_tower.png",
		"arrow_tower": "map_arrow_tower.png",
		"lumbermill": "map_lumbermill.png",
		"dock": "map_dock.png",
		"post_station": "map_post_station.png",
		"temple": "map_temple.png",
		"shrine": "map_temple.png",
	}
	var fname: String = str(map.get(building_id, ""))
	if fname.is_empty():
		fname = "map_%s.png" % building_id
	var tex := _load_tex(AI_MAP_BUILDINGS + fname)
	if tex != null:
		return tex
	# 无精确瓦片时不回退 UI 小图标，交给调用方旧 tile_building_*
	return null


## 大地图资源点：iron/wood/farm/fish
static func map_resource_texture(special_resource: String) -> Texture2D:
	if special_resource.is_empty():
		return null
	var map := {
		"iron": "resource_iron.png",
		"refined_iron": "resource_iron.png",
		"wood": "resource_wood.png",
		"food": "resource_farm.png",
		"farm": "resource_farm.png",
		"fish": "resource_fish.png",
		"fishery": "resource_fish.png",
	}
	var fname: String = str(map.get(special_resource, "resource_%s.png" % special_resource))
	return _load_tex(AI_MAP_BUILDINGS + fname)
