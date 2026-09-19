extends RefCounted
class_name BuildingPlacementHighlight

## 建筑放置高亮：大地图与演武共用同一配色与辖区判定（决策 #123）

const CLR_OK: Color = Color(0.25, 0.95, 0.35, 0.55)
const CLR_OCCUPIED: Color = Color(0.9, 0.55, 0.15, 0.5)
const CLR_BAD: Color = Color(0.9, 0.2, 0.2, 0.4)

const REASON_HEX_OCCUPIED: String = "HEX_OCCUPIED"
const REASON_HEX_RESERVED: String = "HEX_RESERVED"


## key=axial(Vector2i)，value=Color。仅覆盖 city 的视觉辖区环。
static func highlight_for_jurisdiction(city_id: String, building_id: String) -> Dictionary:
	var out: Dictionary = {}
	if city_id.is_empty() or building_id.is_empty():
		return out
	var cm: Object = Engine.get_singleton("CityManager") if Engine.has_singleton("CityManager") else null
	# Autoload 在运行时为节点单例；脚本被 preload 时用主循环查找
	if cm == null:
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		if tree != null and tree.root != null:
			cm = tree.root.get_node_or_null("CityManager")
	if cm == null or not cm.has_method("get_jurisdiction_hexes"):
		return out
	for cell: Vector2i in cm.get_jurisdiction_hexes(city_id):
		out[cell] = color_for_can_build(cm.can_build(city_id, building_id, cell))
	return out


static func color_for_can_build(check: Dictionary) -> Color:
	if bool(check.get("allowed", false)):
		return CLR_OK
	var reason: String = str(check.get("reason", ""))
	if reason == REASON_HEX_OCCUPIED or reason == REASON_HEX_RESERVED:
		return CLR_OCCUPIED
	return CLR_BAD
