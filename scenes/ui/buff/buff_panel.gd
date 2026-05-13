extends PanelContainer
## Buff/Debuff 介绍面板
## 点击单位/城市状态栏的 Buff 图标后弹出，展示效果详情
##
## 使用方式：
##   buff_panel.show_buffs([
##       {"name": "攻击强化", "type": "buff", "icon": "attack_up", "effect": "攻击力 +20%", "duration": 3, "source": "兵家学派加成", "desc": "兵贵神速，攻势如潮"},
##       {"name": "灼烧", "type": "debuff", "icon": "fire", "effect": "每回合 -5% 生命", "duration": 2, "source": "火攻", "desc": "烈焰焚身"},
##   ])

signal buff_selected(buff_data: Dictionary)
signal panel_closed

@onready var title_label: Label = $VBox/Title
@onready var close_btn: Button = $VBox/Title/CloseButton
@onready var buff_container: HBoxContainer = $VBox/BuffArea/BuffContainer
@onready var debuff_container: HBoxContainer = $VBox/DebuffArea/DebuffContainer
@onready var detail_panel: VBoxContainer = $VBox/DetailPanel
@onready var detail_name: Label = $VBox/DetailPanel/Name
@onready var detail_effect: Label = $VBox/DetailPanel/Effect
@onready var detail_duration: Label = $VBox/DetailPanel/Duration
@onready var detail_source: Label = $VBox/DetailPanel/Source
@onready var detail_desc: Label = $VBox/DetailPanel/Desc

const ICON_SIZE := 64
const POP_DURATION := 0.25
const CLOSE_DURATION := 0.2

var _buff_data: Array[Dictionary] = []

func _ready() -> void:
	close_btn.pressed.connect(_close)
	detail_panel.visible = false
	visible = false

func show_buffs(buffs: Array[Dictionary]) -> void:
	_buff_data = buffs
	_clear_icons()
	_populate_icons()
	_popup_animate()

func _clear_icons() -> void:
	for c in buff_container.get_children():
		c.queue_free()
	for c in debuff_container.get_children():
		c.queue_free()

func _populate_icons() -> void:
	for i in _buff_data.size():
		var b := _buff_data[i]
		var icon_btn := _create_icon_button(b, i)
		if b.get("type", "buff") == "debuff":
			debuff_container.add_child(icon_btn)
			_start_debuff_blink(icon_btn)
		else:
			buff_container.add_child(icon_btn)

func _create_icon_button(data: Dictionary, index: int) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	btn.text = data.get("name", "?").substr(0, 2)
	btn.add_theme_font_size_override("font_size", 14)

	# 加载图标纹理
	var icon_name: String = data.get("icon", "")
	if icon_name != "":
		var icon_path := "res://assets/ui/icons/icon_buff_%s.png" % icon_name
		if data.get("type", "buff") == "debuff":
			icon_path = "res://assets/ui/icons/icon_debuff_%s.png" % icon_name
		if ResourceLoader.exists(icon_path):
			btn.icon = load(icon_path)
			btn.expand_icon = true

	# 浮动动画
	var tw := create_tween().set_loops()
	var delay := index * 0.15
	tw.tween_interval(delay)
	tw.tween_property(btn, "position:y", btn.position.y - 4.0, 0.6).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(btn, "position:y", btn.position.y, 0.6).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	btn.pressed.connect(func(): _show_detail(index))
	return btn

func _start_debuff_blink(btn: Button) -> void:
	var tw := create_tween().set_loops()
	tw.tween_property(btn, "modulate", Color(1, 0.6, 0.6, 1), 0.5)
	tw.tween_property(btn, "modulate", Color(1, 1, 1, 1), 0.5)

func _show_detail(index: int) -> void:
	if index >= _buff_data.size():
		return
	var b := _buff_data[index]
	detail_name.text = b.get("name", "")
	detail_effect.text = "效果：%s" % b.get("effect", "")
	detail_duration.text = "持续：%d 回合" % b.get("duration", 0)
	detail_source.text = "来源：%s" % b.get("source", "")
	detail_desc.text = "「%s」" % b.get("desc", "")
	detail_panel.visible = true

	# 详情区滑入
	detail_panel.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(detail_panel, "modulate:a", 1.0, 0.2)

	buff_selected.emit(b)

func _popup_animate() -> void:
	visible = true
	scale = Vector2(0.8, 0.8)
	modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ONE, POP_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(self, "modulate:a", 1.0, POP_DURATION * 0.6)

func _close() -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2(0.8, 0.8), CLOSE_DURATION).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "modulate:a", 0.0, CLOSE_DURATION)
	tw.chain().tween_callback(func():
		visible = false
		detail_panel.visible = false
		panel_closed.emit()
	)
