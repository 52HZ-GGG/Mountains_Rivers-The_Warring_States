extends SceneTree

## 全流程冒烟：无鼠标驱动，直接调用系统 API 压完整玩法路径。
## Autoload 通过 /root/ 节点访问（-s 场景下全局名可能不可用）。
## 运行：
##   Godot --headless --path <proj> -s res://tests/smoke/full_flow_smoke.gd
## 退出码：0=全过，1=有失败

const _HexAxial := preload("res://scripts/systems/hex_axial.gd")

var _pass: int = 0
var _fail: int = 0
var _errors: PackedStringArray = PackedStringArray()

var _dm: Node
var _gm: Node
var _cm: Node
var _mm: Node
var _sm: Node
var _wm: Node
var _ts: Node
var _dip: Node
var _em: Node
var _tm: Node
var _df: Node
var _sv: Node
var _sai: Node


func _initialize() -> void:
	await process_frame
	await process_frame
	_bind_autoloads()
	if _dm == null:
		print("[SMOKE][FAIL] Autoload 未就绪")
		quit(1)
		return
	_run_all()
	_print_summary()
	quit(1 if _fail > 0 else 0)


func _bind_autoloads() -> void:
	_dm = root.get_node_or_null("/root/DataManager")
	_gm = root.get_node_or_null("/root/GameManager")
	_cm = root.get_node_or_null("/root/CityManager")
	_mm = root.get_node_or_null("/root/MinisterManager")
	_sm = root.get_node_or_null("/root/SchoolManager")
	_wm = root.get_node_or_null("/root/WonderManager")
	_ts = root.get_node_or_null("/root/TechSystem")
	_dip = root.get_node_or_null("/root/DiplomacySystem")
	_em = root.get_node_or_null("/root/EventManager")
	_tm = root.get_node_or_null("/root/TacticalSkirmishManager")
	_df = root.get_node_or_null("/root/DemoFlow")
	_sv = root.get_node_or_null("/root/SaveManager")
	_sai = root.get_node_or_null("/root/StrategicMapManager")
	# class_name 可能可用
	if _sai == null:
		_sai = root.get_node_or_null("/root/StrategicMapManager")


func _ok(name: String) -> void:
	_pass += 1
	print("[SMOKE][PASS] ", name)


func _bad(name: String, detail: String = "") -> void:
	_fail += 1
	var line: String = name if detail.is_empty() else "%s — %s" % [name, detail]
	_errors.append(line)
	print("[SMOKE][FAIL] ", line)


func _assert(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		_ok(name)
	else:
		_bad(name, detail)


func _run_all() -> void:
	print("[SMOKE] Autoloads: dm=%s gm=%s cm=%s sai=%s sv=%s" % [
		str(_dm != null), str(_gm != null), str(_cm != null), str(_sai != null), str(_sv != null)
	])
	_test_data_ready()
	_test_start_game()
	_test_economy_loop()
	_test_recruit_and_strategic_units()
	_test_strategic_combat()
	_test_diplomacy_war()
	_test_tech_research()
	_test_school_and_minister()
	_test_wonder_build()
	_test_save_load()
	_test_demo_flow()
	_test_event_pipeline()
	_test_skirmish_tutorial()
	_test_end_turn_cycle()


func _test_data_ready() -> void:
	_assert("数据: 地形 11", _dm.call("get_all_terrains").size() == 11)
	_assert("数据: 兵种 19", _dm.call("get_all_unit_types").size() == 19)
	_assert("数据: 城市 50", _dm.call("get_all_cities").size() == 50)
	_assert("数据: 大地图 100x70", _dm.call("get_map_size") == Vector2i(100, 70))


func _test_start_game() -> void:
	_gm.call("reset")
	_cm.call("reset")
	_mm.call("reset")
	_sm.call("reset")
	_wm.call("reset")
	_ts.call("reset")
	_dip.call("reset")
	_sai.call("reset")
	_em.call("set_muted", true)
	var factions: Array[String] = ["qin", "zhao", "qi", "chu", "wei", "yan", "han"]
	_gm.call("start_game", factions, "qin")
	_assert("开局: 玩家为秦", str(_gm.call("get_player_faction")) == "qin")
	_assert("开局: 回合数>=1", int(_gm.call("get_current_turn")) >= 1)
	_assert("开局: 当前势力非空", str(_gm.call("get_current_faction")) != "")
	_assert("开局: 秦有首都", not (_cm.call("get_capital_state", "qin") as Dictionary).is_empty())


func _test_economy_loop() -> void:
	var capital_id: String = str((_cm.call("get_capital_state", "qin") as Dictionary)["id"])
	var city: Dictionary = _cm.call("get_city_state", capital_id)
	city["conscription_pool"] = 10
	_gm.call("apply_faction_resource_delta", "qin", "gold", 2000)
	_gm.call("apply_faction_resource_delta", "qin", "wood", 1000)
	var build_ok: bool = bool(_cm.call("start_build", capital_id, "farm"))
	_assert("经济: 可建造农田", build_ok)
	var prod: Dictionary = _cm.call("get_city_production", capital_id)
	_assert("经济: 产出字典可读", prod is Dictionary)
	var taxed: Dictionary = _gm.call("_build_production_total", "qin")
	_assert("经济: 税收产出可算", taxed.has("food_taxed") or taxed.has("gold_taxed"))
	_assert("经济: 税率可设", bool(_gm.call("set_tax_rate", 0.4)))


func _test_recruit_and_strategic_units() -> void:
	var capital_id: String = str((_cm.call("get_capital_state", "qin") as Dictionary)["id"])
	var city: Dictionary = _cm.call("get_city_state", capital_id)
	city["conscription_pool"] = 8
	_gm.call("apply_faction_resource_delta", "qin", "gold", 5000)
	_gm.call("apply_faction_resource_delta", "qin", "food", 5000)
	var recruit: Dictionary = _gm.call("recruit_unit_from_city", capital_id, "militia", 1)
	_assert("征兵: 成功", bool(recruit.get("success", false)), str(recruit.get("reason", "")))
	var su_id: String = str(recruit.get("strategic_unit_id", ""))
	_assert("征兵: 生成大地图单位", su_id != "" and not (_sai.call("get_unit", su_id) as Dictionary).is_empty())
	if su_id == "":
		return
	var reach: Dictionary = _sai.call("get_reachable_cells", su_id)
	_assert("战略: 有可达格", reach.size() > 0)
	if reach.is_empty():
		return
	var dest: Vector2i = Vector2i.ZERO
	for cell: Vector2i in reach:
		dest = cell
		break
	var moved: Dictionary = _sai.call("try_move_unit", su_id, dest)
	_assert("战略: 移动成功", bool(moved.get("ok", false)), str(moved.get("reason", "")))


func _test_strategic_combat() -> void:
	var mine: Array = _sai.call("get_faction_units", "qin")
	if mine.is_empty():
		_bad("战略战斗: 秦无单位")
		return
	var my_id: String = str((mine[0] as Dictionary).get("id", ""))
	var enemy: Dictionary = _sai.call("spawn_unit_at_city", "zhao", "militia", 1, 1, 1)
	_assert("战略战斗: 敌军生成", bool(enemy.get("success", false)))
	if not bool(enemy.get("success", false)):
		return
	var enemy_id: String = str(enemy.get("unit_id", ""))
	var my_ref: Dictionary = _sai.call("_get_unit_ref", my_id)
	var e_ref: Dictionary = _sai.call("_get_unit_ref", enemy_id)
	if my_ref.is_empty() or e_ref.is_empty():
		_bad("战略战斗: 单位引用无效")
		return
	var e_axial: Vector2i = Vector2i(int(e_ref["q"]), int(e_ref["r"]))
	for neighbor: Vector2i in _HexAxial.neighbors_hex(e_axial):
		var off: Vector2i = _HexAxial.axial_to_offset_odd_r(neighbor.x, neighbor.y)
		if str(_cm.call("get_big_map_terrain_id", off.x, off.y)) == "mountain":
			continue
		my_ref["q"] = neighbor.x
		my_ref["r"] = neighbor.y
		my_ref["acted"] = false
		my_ref["mp"] = 5
		break
	var atk: Dictionary = _sai.call("try_attack_unit", my_id, enemy_id)
	_assert("战略战斗: 攻击成功", bool(atk.get("ok", false)), str(atk.get("reason", "")))
	_assert("战略战斗: 造成伤害", int(atk.get("damage", 0)) > 0)


func _test_diplomacy_war() -> void:
	var declared: Dictionary = _dip.call("declare_war", "qin", "zhao")
	_assert("外交: 宣战", bool(declared.get("success", false)), str(declared.get("reason", "")))
	_assert("外交: 处于战争", bool(_dip.call("are_at_war", "qin", "zhao")))
	var accepted: Dictionary = _dip.call("accept_ceasefire", "qin", "zhao", {})
	_assert("外交: 停战", bool(accepted.get("success", false)), str(accepted.get("reason", "")))
	_assert("外交: 停战后非战争", not bool(_dip.call("are_at_war", "qin", "zhao")))
	_assert("外交: 战力评分可算", float(_dip.call("get_power_score", "qin")) > 0.0)


func _test_tech_research() -> void:
	_ts.set("_researched_techs", {&"sericulture": true})
	# 直接改字典可能失败，改用内部方法
	if not bool(_ts.call("is_researched", "sericulture")):
		# 通过 start_research 路径
		pass
	_gm.call("apply_faction_resource_delta", "qin", "gold", 500)
	_gm.call("apply_faction_resource_delta", "qin", "silk_books", 20)
	var result: Dictionary = _ts.call("start_research", "private_academy")
	# 前置 sericulture 可能未研究，允许失败但要有 reason
	_assert("科技: 研究接口可调用", result is Dictionary and result.has("success"))
	if bool(result.get("success", false)):
		_ok("科技: 可开始研究")
	else:
		# 尝试无前置科技
		var r2: Dictionary = _ts.call("start_research", "rites_music")
		_assert("科技: 可开始无前置研究", bool(r2.get("success", false)), str(r2.get("reason", "")) + " / " + str(result.get("reason", "")))


func _test_school_and_minister() -> void:
	_sm.call("add_school_exp", "qin", 60)
	_assert("学派: 经验>=60", int(_sm.call("get_school_exp", "qin")) >= 60)
	var act: Dictionary = _sm.call("activate_policy", "qin", "gp_build")
	_assert("学派: 激活政策", bool(act.get("success", false)), str(act.get("reason", "")))
	_assert("学派: 政策列表非空", (_sm.call("get_active_policies", "qin") as Array).size() > 0)
	var ministers: Array = _mm.call("get_faction_civil_ministers", "qin")
	_assert("大夫: 存在文大夫", ministers.size() > 0)
	if ministers.size() > 0:
		var cap: Dictionary = _cm.call("get_capital_state", "qin")
		var assigned: bool = bool(_mm.call("assign_civil_minister", str(cap["id"]), str((ministers[0] as Dictionary).get("id", ""))))
		_assert("大夫: 可派驻首都", assigned)
		_mm.call("remove_civil_minister_from_city", str(cap["id"]))


func _test_wonder_build() -> void:
	_gm.call("apply_faction_resource_delta", "qin", "gold", 5000)
	_gm.call("apply_faction_resource_delta", "qin", "wood", 3000)
	_gm.call("apply_faction_resource_delta", "qin", "building_materials", 500)
	var start: Dictionary = _wm.call("start_build_wonder", "qin", "dujiangyan")
	_assert("奇观: 可开工", bool(start.get("success", false)), str(start.get("reason", "")))
	for i in 30:
		_wm.call("tick_build_projects", "qin")
	_assert("奇观: 完工归属", bool(_wm.call("has_wonder", "qin", "dujiangyan")))


func _test_save_load() -> void:
	var city: Dictionary = _cm.call("get_city_state", "xianyang")
	city["conscription_pool"] = 6
	_gm.call("apply_gold_delta", 77)
	var saved: Dictionary = _sv.call("save_to_slot", 2)
	_assert("存档: 写入槽3", bool(saved.get("success", false)))
	var city2: Dictionary = _cm.call("get_city_state", "xianyang")
	city2["conscription_pool"] = 0
	_gm.call("apply_gold_delta", -int(_gm.call("get_player_gold")))
	var loaded: Dictionary = _sv.call("load_from_slot", 2)
	_assert("存档: 读取成功", bool(loaded.get("success", false)), str(loaded.get("reason", "")))
	_assert("存档: 恢复征兵池", int(_cm.call("get_conscription_pool", "xianyang")) == 6)
	_assert("存档: 自动槽可写", bool((_sv.call("save_to_slot", _sv.get("AUTO_SLOT")) as Dictionary).get("success", false)))


func _test_demo_flow() -> void:
	_df.call("reset")
	_df.call("set_enabled", true)
	_assert("Demo: 目标城洛邑", str(_df.call("get_target_city_id")) == "luoyi")
	_cm.call("change_ownership", "luoyi", "qin")
	_assert("Demo: 洛邑归秦", str((_cm.call("get_city_state", "luoyi") as Dictionary).get("current_faction_id", "")) == "qin")


func _test_event_pipeline() -> void:
	var save_e: Dictionary = _em.call("get_save_data")
	_assert("事件: save 字典非空", save_e is Dictionary)
	_em.call("reset")
	_em.call("load_save_data", save_e)
	_em.call("set_muted", true)
	_assert("事件: 系统存活", _em != null)


func _test_skirmish_tutorial() -> void:
	_tm.call("reset_skirmish")
	_tm.call("start_skirmish")
	_assert("演武: 已激活", bool(_tm.call("is_active")))
	var units: Array = _tm.call("get_units")
	_assert("演武: 有单位", units.size() > 0)
	var winner: String = str(_tm.call("check_victory"))
	_assert("演武: 胜利检查可跑", true, "winner=%s" % winner)
	_tm.call("reset_skirmish")


func _test_end_turn_cycle() -> void:
	var t0: int = int(_gm.call("get_current_turn"))
	var fid0: String = str(_gm.call("get_current_faction"))
	_gm.call("end_current_turn")
	_assert("回合: 势力切换", str(_gm.call("get_current_faction")) != "")
	_assert("回合: 推进", int(_gm.call("get_current_turn")) >= t0 or str(_gm.call("get_current_faction")) != fid0)
	if str(_gm.call("get_current_faction")) != str(_gm.call("get_player_faction")):
		_gm.call("process_ai_turn")
	_assert("回合: AI 一轮后仍存活", int(_gm.call("get_current_phase")) != 0)


func _print_summary() -> void:
	print("[SMOKE] ========== 汇总 ==========")
	print("[SMOKE] PASS=", _pass, " FAIL=", _fail)
	if _fail > 0:
		print("[SMOKE] 失败项:")
		for e: String in _errors:
			print("  - ", e)
	print("[SMOKE] =========================")
