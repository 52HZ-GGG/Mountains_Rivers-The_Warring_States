extends GutTest

## DataManager 单元测试
##
## 依赖：在 Godot AssetLib 安装 GUT 插件（addons/gut/）后启用。
## 运行方式：Godot 编辑器 → GUT 面板 → Run All
##         或 godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests

# ============= 加载与计数 =============

func test_terrains_loaded() -> void:
	var terrains := DataManager.get_all_terrains()
	assert_eq(terrains.size(), 7, "应有 7 种地形（plains/forest/mountain/river/marsh/pass/ford）")


func test_unit_types_loaded() -> void:
	var units := DataManager.get_all_unit_types()
	# 决策 39：新增枪刺兵（spear）作为反骑兵专业兵种
	assert_eq(units.size(), 8, "应有 8 种基础兵种（步/弓/弩/骑/战车/水军/攻城器械/枪刺兵）")


func test_cities_loaded() -> void:
	var cities := DataManager.get_all_cities()
	# 决策 43：城市从 14 扩展到 50（七国 47 + 中立 3）
	assert_eq(cities.size(), 50, "应有 50 座城市（七国 47 + 中立 3）")


# ============= ID 查询 =============

func test_get_terrain_by_id() -> void:
	var plains := DataManager.get_terrain("plains")
	assert_eq(plains.get("name"), "平原")
	assert_eq(plains.get("move_cost"), 1)


func test_get_unit_type_by_id() -> void:
	var infantry := DataManager.get_unit_type("infantry")
	assert_eq(infantry.get("name"), "步兵")
	assert_eq(infantry.get("attack"), 10)


func test_get_city_by_id() -> void:
	var xianyang := DataManager.get_city("xianyang")
	assert_eq(xianyang.get("name"), "咸阳")
	assert_eq(xianyang.get("faction_id"), "qin")


func test_invalid_terrain_returns_empty() -> void:
	var invalid := DataManager.get_terrain("nonexistent")
	assert_true(invalid.is_empty(), "未知地形应返回空字典")


# ============= 国家变体合并 =============

func test_faction_variant_merge_qin_rushi() -> void:
	var rushi := DataManager.get_faction_variant("qin", "infantry")
	assert_eq(rushi.get("variant_id"), "rushi")
	assert_eq(rushi.get("variant_name"), "锐士")
	# stat_overrides 应覆盖基础值
	assert_eq(rushi.get("attack"), 12, "锐士 attack 应被覆盖为 12")
	assert_eq(rushi.get("defense"), 10, "锐士 defense 应被覆盖为 10")
	assert_eq(rushi.get("cost_gold"), 75, "锐士 cost_gold 应被覆盖为 75")
	# 未覆盖字段应保留基础值
	assert_eq(rushi.get("hp"), 100, "锐士 hp 未在 overrides 中应保留 100")
	assert_eq(rushi.get("speed"), 3, "锐士 speed 未在 overrides 中应保留 3")


func test_faction_variant_no_match_returns_base() -> void:
	# 楚国的 infantry 变体存在，但请求楚国的 cavalry 变体不存在 → 应返回基础 cavalry
	var fallback := DataManager.get_faction_variant("chu", "cavalry")
	assert_false(fallback.has("variant_id"), "无变体时不应包含 variant_id 字段")
	assert_eq(fallback.get("name"), "骑兵")


# ============= 国家筛选 =============

func test_get_faction_cities_qin() -> void:
	var qin_cities := DataManager.get_faction_cities("qin")
	# 决策 43：按历史疆域面积分配，秦国 8 城
	assert_eq(qin_cities.size(), 8, "秦国应有 8 座城市")


func test_get_capital_qin() -> void:
	var capital := DataManager.get_capital("qin")
	assert_eq(capital.get("id"), "xianyang")
	assert_true(capital.get("is_capital"), "首都的 is_capital 应为 true")


# ============= 地图尺寸 =============

func test_map_size() -> void:
	var size := DataManager.get_map_size()
	# 决策 43：地图从 20×15（300 格）扩大到 30×20（600 格）
	assert_eq(size, Vector2i(30, 20), "地图应为 30×20")
