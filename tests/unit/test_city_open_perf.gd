extends GutTest

## 诊断：城池面板打开路径是否会卡死


func test_city_panel_open_path_fast() -> void:
	GameManager.reset()
	CityManager.reset()
	GameManager.start_game(["qin"], "qin")
	var t0: int = Time.get_ticks_msec()
	var all: Array = DataManager.get_all_buildings()
	for bdata in all:
		var bid: String = str(bdata.get("id", ""))
		var check: Dictionary = CityManager.can_build("xianyang", bid)
		assert_true(check.has("allowed"), "can_build 应返回 allowed，bid=%s" % bid)
	var prod: Dictionary = CityManager.get_city_production("xianyang")
	assert_true(prod.size() > 0)
	var units: Array = CityManager.get_recruitable_units("xianyang")
	var elapsed: int = Time.get_ticks_msec() - t0
	print("DIAG open-path elapsed_ms=", elapsed)
	assert_lt(elapsed, 2000, "城池刷新路径应 <2s，实际 %dms" % elapsed)
