extends GutTest

const DocumentScript := preload("res://addons/big_map_editor/big_map_document.gd")

var _temp_terrain_path: String = "user://test_big_map_terrain.json"
var _temp_cities_path: String = "user://test_cities.json"
var _temp_control_path: String = "user://test_big_map_political_control.json"


func before_each() -> void:
	_delete_temp(_temp_terrain_path)
	_delete_temp(_temp_cities_path)
	_delete_temp(_temp_control_path)


func after_each() -> void:
	_delete_temp(_temp_terrain_path)
	_delete_temp(_temp_cities_path)
	_delete_temp(_temp_control_path)


func _load_doc() -> BigMapDocument:
	var doc: BigMapDocument = DocumentScript.new()
	assert_true(doc.load_all(), "应能加载大地图编辑文档")
	return doc


func test_existing_big_map_documents_validate_successfully() -> void:
	var doc: BigMapDocument = _load_doc()
	assert_eq(doc.validate_document().size(), 0, "现有大地图数据应通过编辑器校验")


func test_create_city_has_defaults() -> void:
	var doc: BigMapDocument = _load_doc()
	var city_index: int = doc.create_city()
	var city: Dictionary = doc.get_city(city_index)
	assert_eq(str(city.get("name", "")), "新城市")
	assert_eq(str(city.get("faction_id", "")), "qin")
	assert_eq(int(city.get("jurisdiction_radius", 0)), 1)


func test_duplicate_city_generates_unique_id() -> void:
	var doc: BigMapDocument = _load_doc()
	var copy_index: int = doc.duplicate_city(0)
	var original_id: String = str(doc.get_city(0).get("id", ""))
	var copy_id: String = str(doc.get_city(copy_index).get("id", ""))
	assert_ne(copy_id, original_id)
	assert_true(copy_id.begins_with(original_id + "_copy"))


func test_resize_expansion_fills_new_cells_with_plains() -> void:
	var doc: BigMapDocument = _load_doc()
	var result: Dictionary = doc.resize_map(doc.get_map_width() + 2, doc.get_map_height() + 1)
	assert_true(bool(result.get("ok", false)), "扩大地图应成功")
	assert_eq(doc.get_terrain_at_offset(doc.get_map_width() - 1, doc.get_map_height() - 1), "plains")


func test_resize_rejects_when_city_would_be_clipped() -> void:
	var doc: BigMapDocument = _load_doc()
	var result: Dictionary = doc.resize_map(10, 10)
	assert_false(bool(result.get("ok", true)), "裁掉已有城市时应拒绝缩图")


func test_undo_redo_restores_terrain_edit() -> void:
	var doc: BigMapDocument = _load_doc()
	var before: String = doc.get_terrain_at_offset(0, 0)
	doc.set_terrain_at_offset(0, 0, "forest")
	assert_eq(doc.get_terrain_at_offset(0, 0), "forest")
	assert_true(doc.undo(), "应能撤回地形编辑")
	assert_eq(doc.get_terrain_at_offset(0, 0), before)
	assert_true(doc.redo(), "应能还原地形编辑")
	assert_eq(doc.get_terrain_at_offset(0, 0), "forest")


func test_undo_redo_restores_city_creation() -> void:
	var doc: BigMapDocument = _load_doc()
	var before_count: int = doc.get_city_count()
	doc.create_city()
	assert_eq(doc.get_city_count(), before_count + 1)
	assert_true(doc.undo(), "应能撤回新建城市")
	assert_eq(doc.get_city_count(), before_count)
	assert_true(doc.redo(), "应能还原新建城市")
	assert_eq(doc.get_city_count(), before_count + 1)


func test_override_force_and_clear_restore_derived_owner() -> void:
	var doc: BigMapDocument = _load_doc()
	var city: Dictionary = doc.get_city(0)
	var q: int = int(city.get("hex_q", 0))
	var r: int = int(city.get("hex_r", 0))
	assert_eq(doc.get_resolved_owner_at_axial(q, r), str(city.get("faction_id", "")))
	doc.set_override_owner(q, r, "chu")
	assert_eq(doc.get_resolved_owner_at_axial(q, r), "chu")
	doc.set_override_owner(q, r, null)
	assert_eq(doc.get_resolved_owner_at_axial(q, r), "")
	doc.clear_override(q, r)
	assert_eq(doc.get_resolved_owner_at_axial(q, r), str(city.get("faction_id", "")))


func test_unknown_terrain_fails_validation() -> void:
	var doc: BigMapDocument = _load_doc()
	doc.set_terrain_at_offset(0, 0, "lava")
	assert_true(_contains_text(doc.validate_document(), "地形未知"))


func test_unknown_city_faction_fails_validation() -> void:
	var doc: BigMapDocument = _load_doc()
	doc.set_city_field(0, "faction_id", "ghost")
	assert_true(_contains_text(doc.validate_document(), "未知势力"))


func test_duplicate_city_id_fails_validation() -> void:
	var doc: BigMapDocument = _load_doc()
	doc.set_city_field(1, "id", str(doc.get_city(0).get("id", "")))
	assert_true(_contains_text(doc.validate_document(), "城市 id 重复"))


func test_multiple_capitals_for_same_faction_fail_validation() -> void:
	var doc: BigMapDocument = _load_doc()
	doc.set_city_field(1, "is_capital", true)
	assert_true(_contains_text(doc.validate_document(), "不能拥有多个首都"))


func test_out_of_bounds_override_fails_validation() -> void:
	var doc: BigMapDocument = _load_doc()
	doc.set_override_owner(999, 999, "qin")
	assert_true(_contains_text(doc.validate_document(), "覆盖层坐标越界"))


func test_save_and_reload_round_trip() -> void:
	var doc: BigMapDocument = _load_doc()
	doc.set_terrain_at_offset(0, 0, "forest")
	doc.set_override_owner(0, 0, "qin")
	var save_result: Dictionary = doc.save_to_paths(_temp_terrain_path, _temp_cities_path, _temp_control_path)
	assert_true(bool(save_result.get("ok", false)), "临时保存应成功")
	var reloaded: BigMapDocument = DocumentScript.new()
	assert_true(reloaded.load_from_paths(_temp_terrain_path, _temp_cities_path, _temp_control_path), "应能重新载入保存结果")
	assert_eq(reloaded.get_terrain_at_offset(0, 0), "forest")
	assert_eq(reloaded.get_resolved_owner_at_axial(0, 0), "qin")


func _contains_text(lines: Array[String], needle: String) -> bool:
	for line: String in lines:
		if line.contains(needle):
			return true
	return false


func _delete_temp(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
