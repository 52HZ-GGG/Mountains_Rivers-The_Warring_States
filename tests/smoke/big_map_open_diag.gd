extends SceneTree

## 大地图打开诊断：无头实例化 panel.open()，检查格子/画布/尺寸是否真的建出来。
## 运行：Godot --headless --path <proj> -s res://tests/smoke/big_map_open_diag.gd

var _pass: int = 0
var _fail: int = 0


func _initialize() -> void:
	await process_frame
	await process_frame
	var gm: Node = root.get_node_or_null("/root/GameManager")
	var cm: Node = root.get_node_or_null("/root/CityManager")
	var em: Node = root.get_node_or_null("/root/EventManager")
	var sai: Node = root.get_node_or_null("/root/StrategicMapManager")
	if gm == null or cm == null:
		print("[BIGMAP][FAIL] autoload missing gm=", gm, " cm=", cm)
		quit(1)
		return
	gm.call("reset")
	cm.call("reset")
	if em != null:
		em.call("set_muted", true)
	if sai != null and sai.has_method("reset"):
		sai.call("reset")
	var factions: Array[String] = ["qin", "zhao", "qi", "chu", "wei"]
	gm.call("start_game", factions, "qin")
	await process_frame

	var packed: PackedScene = load("res://scenes/ui/big_map/big_map_panel.tscn")
	if packed == null:
		print("[BIGMAP][FAIL] cannot load big_map_panel.tscn")
		quit(1)
		return
	var panel: CanvasLayer = packed.instantiate() as CanvasLayer
	if panel == null:
		print("[BIGMAP][FAIL] instantiate returned null")
		quit(1)
		return
	root.add_child(panel)
	await process_frame
	if not panel.has_method("open"):
		print("[BIGMAP][FAIL] panel has no open(); script missing?")
		print("[BIGMAP] script=", panel.get_script())
		quit(1)
		return

	panel.call("open")
	await process_frame
	await process_frame
	await process_frame

	var hex_board: Control = panel.get_node_or_null("MarginContainer/MainVBox/Scroll/HexBoard") as Control
	_check("hex_board_exists", hex_board != null)
	if hex_board == null:
		_print_summary()
		quit(1)
		return

	var terrain_cv: Control = hex_board.get_node_or_null("HexMapTerrainCanvas") as Control
	var overlay_cv: Control = hex_board.get_node_or_null("HexMapOverlayCanvas") as Control
	var backdrop: Control = hex_board.get_node_or_null("BoardBackdrop") as Control
	var input_overlay: Control = hex_board.get_node_or_null("HexInputOverlay") as Control
	_check("terrain_canvas", terrain_cv != null)
	_check("overlay_canvas", overlay_cv != null)
	_check("board_backdrop", backdrop != null)
	_check("input_overlay", input_overlay != null)

	var board_size: Vector2 = hex_board.custom_minimum_size
	print("[BIGMAP] board custom_minimum_size=", board_size)
	print("[BIGMAP] board size=", hex_board.size)
	print("[BIGMAP] hex_board children=", hex_board.get_child_count())
	for ch in hex_board.get_children():
		print("[BIGMAP]  child: ", ch.name, " ", ch.get_class(), " size=", (ch as Control).size if ch is Control else "?")
	_check("board_min_size_nonzero", board_size.x > 1.0 and board_size.y > 1.0)

	if terrain_cv != null:
		print("[BIGMAP] terrain_cv size=", terrain_cv.size, " scale=", terrain_cv.scale, " z=", terrain_cv.z_index)
		print("[BIGMAP] terrain_cv visible=", terrain_cv.visible, " modulate=", terrain_cv.modulate)
		_check("terrain_cv_nonzero_size", terrain_cv.size.x > 1.0 or board_size.x > 1.0)

	var payload_count: int = -1
	var cells: Variant = panel.get("_terrain_payload_cells")
	if cells is Array:
		payload_count = (cells as Array).size()
	print("[BIGMAP] terrain_payload_cells=", payload_count)
	_check("payload_cells_built", payload_count > 100)

	var radius: float = float(panel.get("_cell_radius_px"))
	print("[BIGMAP] cell_radius_px=", radius)
	_check("cell_radius_positive", radius > 1.0)

	var terrain_cfg: Variant = panel.get("_terrain_cfg")
	if terrain_cfg is Dictionary:
		var cfg: Dictionary = terrain_cfg as Dictionary
		print("[BIGMAP] terrain_cfg map=", cfg.get("map_width"), "x", cfg.get("map_height"), " rows=", (cfg.get("rows", []) as Array).size())
		_check("terrain_cfg_loaded", int(cfg.get("map_width", 0)) > 0 and int(cfg.get("map_height", 0)) > 0)
	else:
		print("[BIGMAP] terrain_cfg missing=", terrain_cfg)
		_check("terrain_cfg_loaded", false)

	var cities: Array = cm.call("get_all_city_states") as Array
	print("[BIGMAP] cities=", cities.size())
	_check("cities_loaded", cities.size() > 0)

	var political: Variant = panel.get("_political_control_grid")
	var owned: int = 0
	if political is Dictionary:
		for k in (political as Dictionary):
			if str((political as Dictionary)[k]) != "":
				owned += 1
		print("[BIGMAP] political_grid cells=", (political as Dictionary).size(), " owned=", owned)
		_check("political_grid_built", (political as Dictionary).size() > 100)
	else:
		_check("political_grid_built", false)

	print("[BIGMAP] panel script=", panel.get_script())
	_check("panel_script_loaded", panel.get_script() != null)

	# 磁盘防覆盖检查
	var src: FileAccess = FileAccess.open("res://scenes/ui/big_map/big_map_panel.gd", FileAccess.READ)
	if src != null:
		var text: String = src.get_as_text()
		src.close()
		_check("disk_uses_bigmapinput_preload", text.contains("preload(\"res://scripts/ui/big_map_input.gd\")"))
		_check("disk_no_accept_event", not text.contains("accept_event()"))
	else:
		_check("disk_readable", false)

	_print_summary()
	quit(1 if _fail > 0 else 0)


func _check(name: String, cond: bool) -> void:
	if cond:
		_pass += 1
		print("[BIGMAP][PASS] ", name)
	else:
		_fail += 1
		print("[BIGMAP][FAIL] ", name)


func _print_summary() -> void:
	print("[BIGMAP] SUMMARY pass=", _pass, " fail=", _fail)
