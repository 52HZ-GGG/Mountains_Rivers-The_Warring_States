extends Control

## 科技树面板
##
## 显示54个科技的树状结构，支持点击研究。
## 横向三列：早期/中期/晚期，纵向四行：军事/经济/民生文化/建筑。

# 颜色常量
const COLOR_RESEARCHED := Color(0.2, 0.6, 0.2)    # 绿色：已研究
const COLOR_AVAILABLE := Color(0.2, 0.4, 0.8)     # 蓝色：可研究
const COLOR_RESEARCHING := Color(0.8, 0.6, 0.2)   # 橙色：研究中
const COLOR_LOCKED := Color(0.4, 0.4, 0.4)        # 灰色：未解锁
const COLOR_BG := Color(0.1, 0.1, 0.15, 0.95)

var _tech_buttons: Dictionary = {}  # {tech_id: Button}
var _detail_panel: VBoxContainer
var _selected_tech: String = ""

func _ready() -> void:
	_build_ui()
	SignalBus.tech_research_completed.connect(_on_tech_completed)
	SignalBus.tech_research_started.connect(_on_tech_started)
	SignalBus.tech_available.connect(_on_tech_available)


func _build_ui() -> void:
	# 主背景
	var bg := ColorRect.new()
	bg.color = COLOR_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 主容器
	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 10)
	add_child(main_vbox)

	# 标题栏
	var title_bar := HBoxContainer.new()
	title_bar.add_theme_constant_override("separation", 20)
	main_vbox.add_child(title_bar)

	var title := Label.new()
	title.text = "科 技 树"
	title.add_theme_font_size_override("font_size", 24)
	title_bar.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "关闭"
	close_btn.pressed.connect(_on_close_pressed)
	title_bar.add_child(close_btn)

	# 内容区：左侧科技树 + 右侧详情
	var content := HSplitContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(content)

	# 左侧：科技树网格
	var tree_scroll := ScrollContainer.new()
	tree_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(tree_scroll)

	var tree_grid := GridContainer.new()
	tree_grid.columns = 4  # 类别标签 + 3个时代
	tree_grid.add_theme_constant_override("h_separation", 15)
	tree_grid.add_theme_constant_override("v_separation", 10)
	tree_scroll.add_child(tree_grid)

	# 右侧：详情面板
	_detail_panel = VBoxContainer.new()
	_detail_panel.custom_minimum_size.x = 250
	_detail_panel.add_theme_constant_override("separation", 8)
	content.add_child(_detail_panel)

	_build_tree_grid(tree_grid)


func _build_tree_grid(grid: GridContainer) -> void:
	var categories := [
		{"id": "military", "name": "军事"},
		{"id": "economy", "name": "经济"},
		{"id": "livelihood", "name": "民生"},
		{"id": "architecture", "name": "建筑"},
	]
	var eras := ["early", "mid", "late"]
	var era_names := {"early": "早期", "mid": "中期", "late": "晚期"}

	# 表头
	var header_empty := Label.new()
	header_empty.text = ""
	grid.add_child(header_empty)
	for era in eras:
		var header := Label.new()
		header.text = era_names[era]
		header.add_theme_font_size_override("font_size", 18)
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(header)

	# 每个类别一行
	for cat in categories:
		var cat_label := Label.new()
		cat_label.text = cat.name
		cat_label.add_theme_font_size_override("font_size", 16)
		grid.add_child(cat_label)

		for era in eras:
			var cell := VBoxContainer.new()
			cell.add_theme_constant_override("separation", 4)
			grid.add_child(cell)

			var techs := DataManager.get_techs_by_category(cat.id)
			for tech in techs:
				if tech.get("era", "") != era:
					continue
				var btn := Button.new()
				btn.text = tech.name
				btn.custom_minimum_size = Vector2(120, 30)
				btn.add_theme_font_size_override("font_size", 12)
				var tech_id: String = tech.id
				btn.pressed.connect(_on_tech_clicked.bind(tech_id))
				_tech_buttons[tech_id] = btn
				cell.add_child(btn)

	_update_all_button_colors()


func _update_all_button_colors() -> void:
	for tech_id in _tech_buttons:
		var btn: Button = _tech_buttons[tech_id]
		if TechSystem.is_researched(tech_id):
			btn.modulate = COLOR_RESEARCHED
		elif TechSystem.get_researching_tech() == tech_id:
			btn.modulate = COLOR_RESEARCHING
		elif TechSystem.is_available(tech_id):
			btn.modulate = COLOR_AVAILABLE
		else:
			btn.modulate = COLOR_LOCKED


func _on_tech_clicked(tech_id: String) -> void:
	_selected_tech = tech_id
	_show_tech_detail(tech_id)


func _show_tech_detail(tech_id: String) -> void:
	# 清空详情面板
	for child in _detail_panel.get_children():
		child.queue_free()

	var tech: Dictionary = DataManager.get_tech(tech_id)
	if tech.is_empty():
		return

	# 科技名称
	var name_label := Label.new()
	name_label.text = tech.name
	name_label.add_theme_font_size_override("font_size", 20)
	_detail_panel.add_child(name_label)

	# 类别和时代
	var cat_era := Label.new()
	var cat_names := {"military": "军事", "economy": "经济", "livelihood": "民生", "architecture": "建筑"}
	var era_names := {"early": "早期", "mid": "中期", "late": "晚期"}
	cat_era.text = "%s · %s" % [cat_names.get(tech.get("category", ""), ""), era_names.get(tech.get("era", ""), "")]
	cat_era.add_theme_font_size_override("font_size", 14)
	cat_era.modulate = Color(0.7, 0.7, 0.7)
	_detail_panel.add_child(cat_era)

	# 描述
	var desc := RichTextLabel.new()
	desc.text = tech.get("description", "")
	desc.custom_minimum_size.y = 60
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc.bbcode_enabled = false
	_detail_panel.add_child(desc)

	# 金币成本
	var cost_label := Label.new()
	cost_label.text = "研究费用: %d 金币" % tech.get("cost_gold", 0)
	cost_label.add_theme_font_size_override("font_size", 14)
	_detail_panel.add_child(cost_label)

	# 回合数
	var turns := maxi(1, ceili(float(tech.get("cost_gold", 100)) / 100.0))
	var turns_label := Label.new()
	turns_label.text = "研究回合: %d" % turns
	turns_label.add_theme_font_size_override("font_size", 14)
	_detail_panel.add_child(turns_label)

	# 效果
	var effect_label := Label.new()
	effect_label.text = "效果: %s" % _format_effect(tech.get("effects", {}))
	effect_label.add_theme_font_size_override("font_size", 14)
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_panel.add_child(effect_label)

	# 前置科技
	var prereqs: Array = tech.get("prerequisites", [])
	if not prereqs.is_empty():
		var prereq_label := Label.new()
		var prereq_names: Array = []
		for pid in prereqs:
			var pt: Dictionary = DataManager.get_tech(pid)
			prereq_names.append(pt.get("name", pid))
		prereq_label.text = "前置: %s" % ", ".join(prereq_names)
		prereq_label.add_theme_font_size_override("font_size", 14)
		prereq_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail_panel.add_child(prereq_label)

	# 特殊条件
	var conditions: Array = tech.get("special_conditions", [])
	if not conditions.is_empty():
		var cond_label := Label.new()
		cond_label.text = "特殊条件: %s" % _format_conditions(conditions)
		cond_label.add_theme_font_size_override("font_size", 14)
		cond_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cond_label.modulate = Color(1.0, 0.8, 0.3)
		_detail_panel.add_child(cond_label)

	# 状态
	var status_label := Label.new()
	if TechSystem.is_researched(tech_id):
		status_label.text = "状态: 已研究"
		status_label.modulate = COLOR_RESEARCHED
	elif TechSystem.get_researching_tech() == tech_id:
		var prog: int = TechSystem.get_research_progress()
		var total: int = TechSystem.get_research_cost_turns()
		status_label.text = "状态: 研究中 (%d/%d)" % [prog, total]
		status_label.modulate = COLOR_RESEARCHING
	elif TechSystem.is_available(tech_id):
		status_label.text = "状态: 可研究"
		status_label.modulate = COLOR_AVAILABLE
	else:
		status_label.text = "状态: 未解锁"
		status_label.modulate = COLOR_LOCKED
	status_label.add_theme_font_size_override("font_size", 14)
	_detail_panel.add_child(status_label)

	# 研究按钮
	var btn_container := HBoxContainer.new()
	_detail_panel.add_child(btn_container)

	if TechSystem.is_available(tech_id) and TechSystem.get_researching_tech() == "":
		var research_btn := Button.new()
		research_btn.text = "开始研究"
		research_btn.pressed.connect(_on_start_research.bind(tech_id))
		btn_container.add_child(research_btn)
	elif TechSystem.get_researching_tech() == tech_id:
		var cancel_btn := Button.new()
		cancel_btn.text = "取消研究"
		cancel_btn.pressed.connect(_on_cancel_research)
		btn_container.add_child(cancel_btn)


func _format_effect(effect: Dictionary) -> String:
	if effect.is_empty():
		return "无"
	var effect_type: String = effect.get("type", "")
	match effect_type:
		"attack_bonus":
			return "%s攻击+%d%%" % [_target_name(effect.get("target", "")), int(effect.get("value", 0) * 100)]
		"defense_bonus":
			return "%s防御+%d%%" % [_target_name(effect.get("target", "")), int(effect.get("value", 0) * 100)]
		"unlock_unit":
			return "解锁单位: %s" % effect.get("unit_id", "")
		"resource_bonus":
			return "%s产出+%d%%" % [_resource_name(effect.get("resource", "")), int(effect.get("value", 0) * 100)]
		"city_defense_bonus":
			return "城防+%d%%" % int(effect.get("value", 0) * 100)
		"siege_bonus":
			return "攻城伤害+%d%%" % int(effect.get("value", 0) * 100)
		"terrain_traversal":
			return "可穿越%s" % effect.get("terrain", "")
		"movement_bonus":
			return "移动力+%d" % effect.get("value", 0)
		"vision_bonus":
			return "视野+%d格" % effect.get("value", 0)
		"morale_bonus":
			return "民心+%d" % effect.get("value", 0)
		"security_bonus":
			return "治安+%d%%" % int(effect.get("value", 0) * 100)
		"culture_bonus":
			return "文化产出+%d%%" % int(effect.get("value", 0) * 100)
		"healing_bonus":
			return "伤兵恢复+%d%%" % int(effect.get("value", 0) * 100)
		"event_chance_bonus":
			return "事件触发+%d%%" % int(effect.get("value", 0) * 100)
		"research_speed_bonus":
			return "研究速度+%d%%" % int(effect.get("value", 0) * 100)
		"trade_bonus":
			return "贸易收入+%d%%" % int(effect.get("value", 0) * 100)
		"garrison_bonus":
			return "驻军上限+%d%%" % int(effect.get("value", 0) * 100)
		"wall_durability_bonus":
			return "城墙耐久+%d%%" % int(effect.get("value", 0) * 100)
		"diplomacy_bonus":
			return "宣战好感度惩罚减半"
		"recruit_cost_reduction":
			return "%s训练费用-%d%%" % [_target_name(effect.get("target", "")), int(effect.get("value", 0) * 100)]
		_:
			return str(effect)


func _target_name(target: String) -> String:
	match target:
		"all": return "全军"
		"infantry": return "步兵"
		"cavalry": return "骑兵"
		"crossbow": return "弩兵"
		"chariot": return "战车"
		_: return target


func _resource_name(resource: String) -> String:
	match resource:
		"food": return "粮食"
		"gold": return "金币"
		"wood": return "木材"
		"craftsmen": return "工匠"
		"building_materials": return "建材"
		_: return resource


func _format_conditions(conditions: Array) -> String:
	var parts: Array = []
	for cond in conditions:
		var cond_type: String = cond.get("type", "")
		match cond_type:
			"city_control":
				var city: Dictionary = DataManager.get_city(cond.get("city_id", ""))
				parts.append("占领%s" % city.get("name", cond.get("city_id", "")))
			"reputation":
				parts.append("声望>%d" % cond.get("value", 0))
			"building":
				parts.append("拥有%s" % cond.get("building_id", ""))
			"region_control":
				parts.append("控制%s地区%d城" % [cond.get("region", ""), cond.get("min_cities", 1)])
			_:
				parts.append(str(cond))
	return "、".join(parts)


func _on_start_research(tech_id: String) -> void:
	var result: Dictionary = TechSystem.start_research(tech_id)
	if result.success:
		_update_all_button_colors()
		_show_tech_detail(tech_id)
	else:
		push_warning("科技研究失败: %s" % result.reason)


func _on_cancel_research() -> void:
	TechSystem.cancel_research()
	_update_all_button_colors()
	if _selected_tech != "":
		_show_tech_detail(_selected_tech)


func _on_tech_completed(_tech_id: String) -> void:
	_update_all_button_colors()
	if _selected_tech != "":
		_show_tech_detail(_selected_tech)


func _on_tech_started(_tech_id: String) -> void:
	_update_all_button_colors()
	if _selected_tech != "":
		_show_tech_detail(_selected_tech)


func _on_tech_available(_tech_id: String) -> void:
	_update_all_button_colors()


func _on_close_pressed() -> void:
	visible = false
