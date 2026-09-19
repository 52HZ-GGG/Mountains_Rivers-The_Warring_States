extends GutTest

func test_open_big_map_scene() -> void:
	GameManager.reset()
	CityManager.reset()
	EventManager.set_muted(true)
	GameManager.start_game(["qin", "zhao"], "qin")
	var scene: PackedScene = load("res://scenes/ui/big_map/big_map_scene.tscn")
	assert_not_null(scene)
	var inst: Node = scene.instantiate()
	add_child_autofree(inst)
	await wait_physics_frames(3)
	# open_big_map may be deferred
	if inst.has_method("open_big_map"):
		inst.call("open_big_map")
	await wait_physics_frames(5)
	assert_true(inst.has_method("open_big_map"))
	if inst.has_method("is_big_map_open"):
		assert_true(bool(inst.call("is_big_map_open")), "大地图应已打开")
