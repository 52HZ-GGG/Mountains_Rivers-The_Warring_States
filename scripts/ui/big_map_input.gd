class_name BigMapInput

## 大地图输入消费工具（统一规范：适配层输入）
## 从 big_map_panel 抽出，避免编辑器缓冲覆盖面板脚本时丢失修复。
## 注意：InputEvent 没有 accept_event()，必须用 viewport 消费。


static func consume() -> void:
	var vp: Viewport = Engine.get_main_loop().root.get_viewport() if Engine.get_main_loop() is SceneTree else null
	if vp != null:
		vp.set_input_as_handled()


## 是否鼠标左键
static func is_left_button(mb: InputEventMouseButton) -> bool:
	return mb.button_index == MOUSE_BUTTON_LEFT


## 是否鼠标右键
static func is_right_button(mb: InputEventMouseButton) -> bool:
	return mb.button_index == MOUSE_BUTTON_RIGHT


## 城池 caption：HP + 墙 + 建筑数
static func city_caption(city_id: String, base_name: String) -> String:
	if city_id == "":
		return base_name
	var state: Dictionary = CityManager.get_city_state(city_id)
	if state.is_empty():
		return base_name
	var hp: int = int(state.get("current_hp", 0))
	var max_hp: int = CityManager.get_city_max_hp(city_id) if CityManager.has_method("get_city_max_hp") else hp
	if max_hp <= 0:
		max_hp = maxi(hp, 1)
	var caption: String = "%s\nHP%d/%d" % [base_name, hp, max_hp]
	var wall: int = CityManager.get_wall_hp(city_id)
	if wall >= 0:
		caption += " 墙%d" % wall
	var built: int = (state.get("buildings", []) as Array).size()
	var queue: int = (state.get("build_queue", []) as Array).size()
	if built > 0 or queue > 0:
		var b_tag: String = I18n.t("big_map.build_tag") % built
		if queue > 0:
			b_tag += "+%d" % queue
		caption += "\n" + b_tag
	return caption
