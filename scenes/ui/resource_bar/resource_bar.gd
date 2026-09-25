extends HBoxContainer

## 资源栏：显示玩家当前资源数值。
## 每回合自动刷新，也可手动调用 refresh() 强制更新。

class ResourceTooltipCell extends HBoxContainer:
	const TOOLTIP_WIDTH: float = 440.0

	func _make_custom_tooltip(for_text: String) -> Object:
		var panel: PanelContainer = PanelContainer.new()
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(0.08, 0.07, 0.05, 0.96)
		style.border_color = Color(0.72, 0.60, 0.34, 0.95)
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		panel.add_theme_stylebox_override("panel", style)

		var margin: MarginContainer = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 10)
		margin.add_theme_constant_override("margin_top", 8)
		margin.add_theme_constant_override("margin_right", 10)
		margin.add_theme_constant_override("margin_bottom", 8)
		panel.add_child(margin)

		var label: Label = Label.new()
		label.custom_minimum_size = Vector2(TOOLTIP_WIDTH, 0)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = for_text
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.84, 1))
		margin.add_child(label)
		return panel


var _labels: Dictionary = {}
var _delta_labels: Dictionary = {}
var _cells: Dictionary = {}
var _cell_children: Dictionary = {}
var _content_vbox: VBoxContainer = null
var _turn_info_label: Label = null
var _resource_flow: FlowContainer = null
var _hover_hint_label: Label = null


func _ready() -> void:
	add_to_group("resource_bar")
	_build_layout()
	_add_resource_cell("food", "粮食")
	_add_resource_cell("gold", "金币")
	_add_resource_cell("wood", "木材")
	_add_resource_cell("horse", "马匹")
	_add_resource_cell("refined_iron", "精铁")
	_add_resource_cell("craftsmen", "工匠")
	_add_resource_cell("building_materials", "建材")
	_add_resource_cell("troops", "兵力")
	_add_resource_cell("conscription", "兵源")
	_add_resource_cell("population", "人口")
	_add_resource_cell("morale", "民心")
	add_theme_constant_override("separation", 0)
	SignalBus.turn_started.connect(_on_turn_started)
	call_deferred("refresh")


func _build_layout() -> void:
	_content_vbox = VBoxContainer.new()
	_content_vbox.name = "ResourceBarContent"
	_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_vbox.add_theme_constant_override("separation", 4)
	add_child(_content_vbox)

	_turn_info_label = Label.new()
	_turn_info_label.name = "TurnSeasonLabel"
	_turn_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_turn_info_label.add_theme_font_size_override("font_size", 14)
	_turn_info_label.add_theme_color_override("font_color", Color(0.95, 0.90, 0.74, 1))
	_content_vbox.add_child(_turn_info_label)

	_resource_flow = FlowContainer.new()
	_resource_flow.name = "ResourceFlow"
	_resource_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_resource_flow.add_theme_constant_override("h_separation", 16)
	_resource_flow.add_theme_constant_override("v_separation", 4)
	_content_vbox.add_child(_resource_flow)

	_hover_hint_label = Label.new()
	_hover_hint_label.name = "ResourceHoverHintLabel"
	_hover_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hover_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hover_hint_label.add_theme_font_size_override("font_size", 11)
	_hover_hint_label.add_theme_color_override("font_color", Color(0.72, 0.74, 0.68, 1))
	_hover_hint_label.text = "小提示：鼠标悬停在资源上，可查看具体作用、影响因素与结算说明。"
	_content_vbox.add_child(_hover_hint_label)


func _add_resource_cell(key: String, display_name: String) -> void:
	var cell: ResourceTooltipCell = ResourceTooltipCell.new()
	cell.name = "ResourceCell_%s" % key
	cell.add_theme_constant_override("separation", 4)
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	var icon: Control = null
	var art_tex: Texture2D = _try_art_icon(key)
	if art_tex != null:
		var icon_rect := TextureRect.new()
		icon_rect.texture = art_tex
		icon_rect.custom_minimum_size = Vector2(22, 22)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(icon_rect)
		icon = icon_rect
	else:
		var icon_label := Label.new()
		icon_label.text = _resource_icon(key)
		icon_label.add_theme_font_size_override("font_size", 16)
		icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(icon_label)
		icon = icon_label
	var name_lbl := Label.new()
	name_lbl.text = display_name
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8, 1))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(name_lbl)
	var val_lbl := Label.new()
	val_lbl.text = "0"
	val_lbl.add_theme_font_size_override("font_size", 15)
	val_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	val_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(val_lbl)
	var delta_lbl := Label.new()
	delta_lbl.name = "ResourceDelta_%s" % key
	delta_lbl.text = ""
	delta_lbl.add_theme_font_size_override("font_size", 12)
	delta_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(delta_lbl)
	_resource_flow.add_child(cell)
	_labels[key] = val_lbl
	_delta_labels[key] = delta_lbl
	_cells[key] = cell
	_cell_children[key] = [cell, icon, name_lbl, val_lbl, delta_lbl]


func _resource_icon(key: String) -> String:
	match key:
		"food": return "🌾"
		"gold": return "💰"
		"wood": return "🪵"
		"horse": return "🐎"
		"refined_iron": return "⚔"
		"craftsmen": return "🔨"
		"building_materials": return "🧱"
		"troops": return "🛡"
		"population": return "👥"
		"morale": return "🔥"
		_: return "?"


func _on_turn_started(_turn: int, _faction: String) -> void:
	refresh()


## 刷新所有资源数值。
func refresh() -> void:
	_refresh_turn_info()
	_set_val("food", GameManager.get_player_food())
	_set_val("gold", GameManager.get_player_gold())
	_set_val("wood", GameManager.get_player_wood())
	_set_val("horse", GameManager.get_player_horse())
	_set_val("refined_iron", GameManager.get_player_refined_iron())
	_set_val("craftsmen", GameManager.get_player_craftsmen())
	_set_val("building_materials", GameManager.get_player_building_materials())
	_set_val("troops", GameManager.get_player_troops())
	_set_val("conscription", GameManager.get_player_conscription_pool())
	_set_val("population", GameManager.get_player_population())
	_set_val("morale", GameManager.get_player_morale())
	_refresh_tooltips()


func _refresh_turn_info() -> void:
	if _turn_info_label == null:
		return
	var turn_number: int = GameManager.get_current_turn()
	var season: String = CityManager.get_current_season(turn_number)
	_turn_info_label.text = "第 %d 回合 · %s" % [turn_number, _season_name(season)]


func _set_val(key: String, value: int) -> void:
	if _labels.has(key):
		var cap: int = _resource_cap(key)
		if cap >= 0:
			# 左=当前存量；右=仓库上限（不是预计产出，不可与左边相加）
			_labels[key].text = "%s / 上限%s" % [_format_number(value), _format_number(cap)]
		else:
			_labels[key].text = _format_number(value)


func _resource_cap(key: String) -> int:
	match key:
		"food", "gold", "wood", "silk_books":
			return GameManager.get_resource_cap(key, GameManager.get_player_faction())
		"morale":
			return GameManager.get_player_morale_cap()
		_:
			return -1


func _refresh_tooltips() -> void:
	var faction_id: String = GameManager.get_player_faction()
	if faction_id == "":
		return
	var preview: Dictionary = GameManager.preview_faction_turn_income(faction_id)
	var production: Dictionary = preview.get("production", {})
	var upkeep: Dictionary = preview.get("upkeep", {})
	var deltas: Dictionary = preview.get("deltas", {})
	for key in _cells:
		var tooltip: String = _resource_tooltip(str(key), production, upkeep, deltas, preview)
		var cell: Control = _cells.get(key, null) as Control
		if cell != null:
			cell.tooltip_text = tooltip
		_set_delta(str(key), int(deltas.get(key, 0)))


func _set_delta(key: String, delta: int) -> void:
	if not _delta_labels.has(key):
		return
	var lbl: Label = _delta_labels[key] as Label
	if key == "population" or key == "troops" or key == "conscription" or key == "morale":
		lbl.text = ""
		return
	# 绿色 = 本回合净变化（入库−维护）；下一回合 ≈ 当前 + 本值（受仓库上限）
	lbl.text = "(净%+d)" % delta
	if delta > 0:
		lbl.add_theme_color_override("font_color", Color(0.45, 0.95, 0.58, 1))
	elif delta < 0:
		lbl.add_theme_color_override("font_color", Color(1.0, 0.48, 0.42, 1))
	else:
		lbl.add_theme_color_override("font_color", Color(0.65, 0.68, 0.72, 1))


func _resource_tooltip(key: String, production: Dictionary, upkeep: Dictionary, deltas: Dictionary, preview: Dictionary) -> String:
	var actual_income: Dictionary = preview.get("actual_income", {})
	var before: Dictionary = preview.get("before", {})
	var after: Dictionary = preview.get("after", {})
	var after_income: Dictionary = preview.get("after_income", {})
	var caps: Dictionary = preview.get("caps", {})
	match key:
		"food":
			var f_before: int = int(before.get("food", 0))
			var f_income: int = int(actual_income.get("food", 0))
			var f_keep: int = int(upkeep.get("food", 0))
			var f_after: int = int(after.get("food", 0))
			var f_delta: int = int(deltas.get("food", 0))
			return "粮食\n· 左侧 %d = 当前存量；右侧「上限 %d」= 粮仓，**不可相加**\n· 绿色(净%+d) = 本回合入库−维护\n· 结束回合后：当前 + 净 = %d\n· 算式：%d + %d - %d = %d（触顶则截断到上限）\n· 税后入库 %d = 税基 %d × 税率 %.0f%% × 税效 %.0f%%" % [
				f_before,
				int(caps.get("food", -1)),
				f_delta,
				f_after,
				f_before,
				f_income,
				f_keep,
				f_after,
				int(production.get("food_taxed", 0)),
				int(production.get("food", 0)),
				float(preview.get("tax_rate", 0.0)) * 100.0,
				float(preview.get("tax_efficiency", 0.0)) * 100.0,
			]
		"gold":
			var g_before: int = int(before.get("gold", 0))
			var g_income: int = int(actual_income.get("gold", 0))
			var g_keep: int = int(upkeep.get("gold", 0)) + int(upkeep.get("building_gold", 0))
			var g_after: int = int(after.get("gold", 0))
			var g_delta: int = int(deltas.get("gold", 0))
			return "金币\n· 左侧 %d = 当前存量；右侧「上限 %d」= 金库，**不可相加**\n· 绿色(净%+d) = 本回合入库−维护\n· 结束回合后：当前 + 净 = %d\n· 算式：%d + %d - %d = %d（触顶则截断到上限）\n· 税后入库 %d = 税基 %d × 税率 %.0f%% × 税效 %.0f%%\n· 维护：军饷 %d + 建筑 %d" % [
				g_before,
				int(caps.get("gold", -1)),
				g_delta,
				g_after,
				g_before,
				g_income,
				g_keep,
				g_after,
				int(production.get("gold_taxed", 0)),
				int(production.get("gold", 0)),
				float(preview.get("tax_rate", 0.0)) * 100.0,
				float(preview.get("tax_efficiency", 0.0)) * 100.0,
				int(upkeep.get("gold", 0)),
				int(upkeep.get("building_gold", 0)),
			]
		"wood":
			var w_before: int = int(before.get("wood", 0))
			var w_income: int = int(production.get("wood", 0))
			var w_after: int = int(after.get("wood", 0))
			return "木材\n预计下一回合 = 当前 + 入库\n%d + %d = %d\n全国木材产出 %d ｜ 上限 %d" % [
				w_before,
				w_income,
				w_after,
				w_income,
				int(caps.get("wood", -1)),
			]
		"horse":
			return "马匹预计变化：%+d\n作用：招募骑兵、斥候骑兵等骑乘单位；马匹也会造成额外粮食维护。\n如何获得：马场/畜养类建筑、马匹特产、科技/奇观/学派等全国产出修正。\n如何影响：马匹产出直接入库；征骑兵会即时扣马，持有马匹按 horse_upkeep_food_per_unit 增加粮食维护。\n本回合：全国马匹产出 %d。" % [int(deltas.get("horse", 0)), int(production.get("horse", 0))]
		"refined_iron":
			return "精铁预计变化：%+d\n作用：招募重甲、精锐、攻城等高阶部队，也会用于部分军事生产。\n如何获得：精铁坊等建筑、相关特产、科技/奇观/学派产出修正。\n如何影响：精铁不走税率，按全国精铁产出直接入库；招募需要精铁的兵种会即时扣除。\n本回合：全国精铁产出 %d。" % [int(deltas.get("refined_iron", 0)), int(production.get("refined_iron", 0))]
		"craftsmen":
			return "工匠预计变化：%+d\n作用：招募工程/器械类部队，支撑部分高级建筑或军事生产。\n如何获得：工匠坊、工匠特产、季节工匠修正、科技/奇观/学派产出修正。\n如何影响：工匠不走税率，按全国工匠产出直接入库；征募需要工匠的兵种会即时扣除。\n本回合：全国工匠产出 %d。" % [int(deltas.get("craftsmen", 0)), int(production.get("craftsmen", 0))]
		"building_materials":
			return "建材预计变化：%+d\n作用：高级建筑、城防、奇观或后续大型工程会消耗建材。\n如何获得：建材坊、建材特产、季节建材修正、科技/奇观/学派产出修正。\n如何影响：建材不走税率，按全国建材产出直接入库；建造需要建材的项目会即时扣除。\n本回合：全国建材产出 %d。" % [int(deltas.get("building_materials", 0)), int(production.get("building_materials", 0))]
		"troops":
			return "兵力\n作用：全国已服役编制之和（兵种构成）。\n如何获得：城池面板征兵；消耗全国可服役池 + 兵种资源（不扣城人口）。\n如何影响：军队维护扣粮金；服役比例过高触发服役惩罚。"
		"conscription":
			var fid: String = GameManager.get_player_faction()
			var avail: int = GameManager.get_available_conscription(fid)
			var mx: int = GameManager.get_max_conscription(fid)
			var active: int = GameManager.get_total_troops(fid)
			var pop: int = GameManager.get_player_population()
			var rate: float = float(DataManager.get_balance_param("population.conscription_rate"))
			var fill: float = float(DataManager.get_balance_param("population.conscription_fill_rate"))
			var bar_w: int = 20
			var filled: int = int(round(clampf(float(avail) / float(maxi(mx, 1)), 0.0, 1.0) * bar_w))
			var bar: String = "["
			for i: int in range(bar_w):
				bar += "█" if i < filled else "░"
			bar += "]"
			var fill_per_turn: int = int(float(mx) * fill)
			var death_pen: int = GameManager.get_conscription_death_penalty(fid)
			var pen_str: String = "− %d（阵亡衰减 #95，每 %d 回合 +1）" % [death_pen, int(DataManager.get_balance_param("population.death_recovery_period"))] if death_pen > 0 else ""
			return "兵源（全国可服役池 · 全局悬浮总览）\n%s  %d / %d\n已服役：%d ｜ 硬约束：可服役+已服役≤最大征召\n最大征召 = 全国人口 %d × %.0f%% %s\n每回合填充 = 最大征召 × %.0f%% ≈ +%d\n征兵消耗：可服役池 + 兵种金/粮/马/铁/工匠（不扣城人口）\n入口：城池面板「征兵」" % [
				bar,
				avail,
				mx,
				active,
				pop,
				rate * 100.0,
				pen_str,
				fill * 100.0,
				fill_per_turn,
			]
		"population":
			return "人口\n作用：全国各城人口之和；税基；决定最大征召 = 人口×20%。\n如何获得：城市回合按粮食/季节/安定度进度条增长。\n如何影响：人口越高税基与兵源上限越高；**征兵不扣城人口**（决策 #94）；服役比例过高有产出惩罚。"
		"morale":
			return "民心\n作用：影响税收效率、征兵效率、战斗士气相关效果，并可能影响安定度。\n如何变化：季节民心修正、税率调整、腐败、建筑民心、学派政策、奇观、战争疲劳、胜利奖励、首都陷落/收复都会改变民心。\n如何影响：高民心提高税收/产出和征兵，低民心降低税收/征兵并可能带来骚乱或安定下降。当前税收效率 %.0f%%，当前/上限 %d/%d。" % [
				float(preview.get("tax_efficiency", 0.0)) * 100.0,
				GameManager.get_player_morale(),
				GameManager.get_player_morale_cap(),
			]
		_:
			return ""


func _formula_factor_text() -> String:
	return "影响项：\n- 税基：城市人口基础产出、建筑百分比/固定产出、官员城市产出、特产、安定度、服役人口占比、学派全产出、儒家民心繁荣、人口口粮消耗、食物消耗减免、季节修正、科技资源修正、奇观资源修正、建筑完工/升级/拆除/取消。\n- 税收效率：税率、基础税效、民心档位、腐败、建筑税收、奇观税收。\n- 腐败：城市数、总人口、边境城市数、科技/建筑/官员/奇观减腐。\n- 上限：粮仓/市场/伐木场/帛书建筑等资源上限。\n- 扣除：兵种维护、马匹耗粮、建筑维护、征兵与建造即时花费。"


func _season_name(season: String) -> String:
	match season:
		"spring":
			return "春"
		"summer":
			return "夏"
		"autumn":
			return "秋"
		"winter":
			return "冬"
		_:
			return season


func _format_number(n: int) -> String:
	if n >= 10000:
		return "%.1f万" % (n / 10000.0)
	return str(n)


## ai_art 资源图标（粮金木铁人口士气马匹工匠建材兵力）
func _art_icon_key(resource_key: String) -> String:
	match resource_key:
		"food":
			return "food"
		"gold":
			return "gold"
		"wood":
			return "wood"
		"refined_iron", "iron":
			return "iron"
		"population":
			return "population"
		"morale":
			return "morale"
		"horse":
			return "horse"
		"craftsmen":
			return "craftsmen"
		"building_materials":
			return "building_materials"
		"troops":
			return "troops"
		_:
			return ""

func _try_art_icon(key: String) -> Texture2D:
	if not ClassDB.class_exists("ArtCatalog"):
		return null
	var art_key := _art_icon_key(key)
	if art_key == "":
		return null
	return ArtCatalog.icon_texture(art_key)
