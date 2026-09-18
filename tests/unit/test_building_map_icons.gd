extends GutTest

## 防回归：实体建筑必须能在大地图显示图标（决策 #123）


func test_building_texture_registry_and_assets() -> void:
	var tex_script: Script = load("res://scripts/ui/skirmish_tile_textures.gd")
	assert_not_null(tex_script)
	var farm: Texture2D = SkirmishTileTextures.building_texture("farm", "economy")
	assert_not_null(farm, "farm 建筑贴图必须可加载")
	var fallback: Texture2D = SkirmishTileTextures.building_texture("unknown_id", "military")
	assert_not_null(fallback, "未知建筑应回退到分类贴图")
	assert_true(ResourceLoader.exists("res://assets/buildings/tile_building_farm.png"))
	assert_true(ResourceLoader.exists("res://assets/buildings/tile_building_wall.png"))
	assert_true(ResourceLoader.exists("res://assets/buildings/tile_building_economy.png"))


func test_big_map_payload_draws_building_icon() -> void:
	var panel: String = FileAccess.get_file_as_string("res://scenes/ui/big_map/big_map_panel.gd")
	assert_true(panel.contains("building_texture"), "大地图 payload 必须写入 building_texture")
	assert_true(panel.contains("_building_rect"), "必须计算建筑图标矩形")
	assert_true(panel.contains("build_queue") or panel.contains("under_construction") or panel.contains("building_marks"), "建筑标记必须接入 overlay")
	var canvas: String = FileAccess.get_file_as_string("res://scripts/ui/skirmish_hex_map_canvas.gd")
	assert_true(canvas.contains("building_texture"), "HexMapCanvas 必须绘制 building_texture")
	assert_true(canvas.contains("draw_texture_rect"))


func test_building_icon_code_not_stripped_by_editor() -> void:
	var panel: String = FileAccess.get_file_as_string("res://scenes/ui/big_map/big_map_panel.gd")
	assert_true(panel.contains("SkirmishTileTextures.building_texture"), "必须调用 building_texture")
	assert_true(panel.contains("building_texture"), "payload 必须包含 building_texture 字段")


func test_completed_building_mark_has_id_for_icon() -> void:
	GameManager.reset()
	CityManager.reset()
	EventManager.set_muted(true)
	GameManager.start_game(["qin"], "qin")
	GameManager.apply_gold_delta(5000)
	GameManager.apply_wood_delta(5000)
	var city_id: String = "xianyang"
	var hexes: Array[Vector2i] = CityManager.get_jurisdiction_hexes(city_id)
	assert_false(hexes.is_empty())
	assert_true(CityManager.start_build(city_id, "farm", hexes[0]))
	# 推进到完工
	for i in range(4):
		CityManager._process_build_queue(city_id, {})
	var placed: Dictionary = CityManager.get_building_at_hex(hexes[0])
	assert_false(placed.is_empty(), "完工后应有实体建筑记录")
	assert_eq(str(placed.get("building_id", "")), "farm")
	assert_true(placed.has("hex_q") and placed.has("hex_r"))
	var tex: Texture2D = SkirmishTileTextures.building_texture(str(placed.get("building_id", "")), "economy")
	assert_not_null(tex, "已建成建筑应能解析到贴图")


func test_queue_hex_visible_before_complete() -> void:
	GameManager.reset()
	CityManager.reset()
	EventManager.set_muted(true)
	GameManager.start_game(["qin"], "qin")
	GameManager.apply_gold_delta(5000)
	GameManager.apply_wood_delta(5000)
	var hexes: Array[Vector2i] = CityManager.get_jurisdiction_hexes("xianyang")
	assert_true(CityManager.start_build("xianyang", "market", hexes[0]))
	var city: Dictionary = CityManager.get_city_state("xianyang")
	var queue: Array = city.get("build_queue", []) as Array
	assert_false(queue.is_empty())
	var q: Dictionary = queue[0] as Dictionary
	assert_true(q.has("hex_q") and q.has("hex_r"), "队列必须带坐标，地图才能显示工地")
	var tex: Texture2D = SkirmishTileTextures.building_texture(str(q.get("building_id", "")), "economy")
	assert_not_null(tex)
