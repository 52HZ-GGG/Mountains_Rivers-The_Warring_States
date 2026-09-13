extends GutTest

## DataManager 单元测试
##
## 依赖：在 Godot AssetLib 安装 GUT 插件（addons/gut/）后启用。
## 运行方式：Godot 编辑器 → GUT 面板 → Run All
##         或 godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests

# ============= 加载与计数 =============

func test_terrains_loaded() -> void:
	var terrains := DataManager.get_all_terrains()
	assert_eq(terrains.size(), 11, "应有 11 种地形")


func test_unit_types_loaded() -> void:
	var units := DataManager.get_all_unit_types()
	# 决策 39：新增枪刺兵（spear）作为反骑兵专业兵种
	assert_eq(units.size(), 19, "应有 19 种基础兵种")


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
	# 数值以 units.json 为准（阶段 7 兵种重算后 attack=27）
	assert_eq(int(infantry.get("attack", 0)), 27)
	assert_eq(int(infantry.get("defense", 0)), 10)
	assert_eq(int(infantry.get("hp", 0)), 100)


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
	var base := DataManager.get_unit_type("infantry")
	assert_eq(rushi.get("variant_id"), "rushi")
	assert_eq(rushi.get("variant_name"), "锐士")
	# 以 units.json faction_variants 为准（造价与基础步兵同为 75）
	assert_eq(int(rushi.get("attack", 0)), 32, "锐士 attack 应为 32")
	assert_true(int(rushi.get("defense", 0)) > int(base.get("defense", 0)), "锐士防御应高于基础步兵")
	assert_eq(int(rushi.get("cost_gold", 0)), 75, "锐士 cost_gold 覆盖为 75")
	# 未覆盖字段保留基础值
	assert_eq(int(rushi.get("hp", 0)), int(base.get("hp", 0)), "锐士 hp 未覆盖时应与基础一致")
	assert_eq(int(rushi.get("speed", 0)), int(base.get("speed", 0)), "锐士 speed 未覆盖时应与基础一致")


func test_faction_variant_no_match_returns_base() -> void:
	# 楚国的 infantry 变体存在，但请求楚国的 cavalry 变体不存在 → 应返回基础 cavalry
	var fallback := DataManager.get_faction_variant("chu", "cavalry")
	assert_false(fallback.has("variant_id"), "无变体时不应包含 variant_id 字段")
	assert_eq(fallback.get("name"), "护卫骑兵")


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
	# 大地图从 30×20 扩大到 100×70（战国七雄全境）
	assert_eq(size, Vector2i(100, 70), "地图应为 100×70")
