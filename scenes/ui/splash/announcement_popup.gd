extends Control
## 公告弹窗（卷轴展开/收起动画）
##
## 使用方式：
##   var popup = preload("res://scenes/ui/splash/announcement_popup.tscn").instantiate()
##   popup.show_announcement("标题", "正文内容")
##   popup.announced.connect(func(): print("公告关闭"))

signal announced

@onready var bg: TextureRect = $Background
@onready var title_label: Label = $Background/Content/Title
@onready var body_label: Label = $Background/Content/Body
@onready var seal: TextureRect = $Background/Seal
@onready var confirm_btn: Button = $Background/Content/ConfirmButton
@onready var overlay: ColorRect = $Overlay

const OPEN_DURATION := 0.4
const CLOSE_DURATION := 0.3
const SEAL_DROP_DURATION := 0.2

func _ready() -> void:
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.visible = false
	bg.visible = false
	confirm_btn.pressed.connect(_close)

func show_announcement(title: String, body: String) -> void:
	title_label.text = title
	body_label.text = body
	_open()

func _open() -> void:
	overlay.visible = true
	bg.visible = true

	# 初始状态
	bg.scale.x = 0.0
	bg.modulate.a = 0.0
	title_label.modulate.a = 0.0
	body_label.modulate.a = 0.0
	seal.position.y = -40.0
	seal.modulate.a = 0.0
	confirm_btn.modulate.a = 0.0

	var tw := create_tween().set_parallel(true)

	# 卷轴展开（scale.x: 0→1）
	tw.tween_property(bg, "scale:x", 1.0, OPEN_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(bg, "modulate:a", 1.0, OPEN_DURATION * 0.5)

	# 内容淡入（延迟 0.2s，与展开重叠）
	tw.chain().tween_property(title_label, "modulate:a", 1.0, 0.2).set_delay(0.2)
	tw.chain().tween_property(body_label, "modulate:a", 1.0, 0.2).set_delay(0.25)
	tw.chain().tween_property(confirm_btn, "modulate:a", 1.0, 0.15).set_delay(0.3)

	# 印章盖下（延迟 0.5s）
	tw.chain().tween_property(seal, "position:y", 0.0, SEAL_DROP_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE).set_delay(0.5)
	tw.chain().tween_property(seal, "modulate:a", 1.0, 0.1).set_delay(0.5)

func _close() -> void:
	var tw := create_tween().set_parallel(true)

	# 内容先淡出
	tw.tween_property(title_label, "modulate:a", 0.0, CLOSE_DURATION * 0.5)
	tw.tween_property(body_label, "modulate:a", 0.0, CLOSE_DURATION * 0.5)
	tw.tween_property(confirm_btn, "modulate:a", 0.0, CLOSE_DURATION * 0.4)
	tw.tween_property(seal, "modulate:a", 0.0, CLOSE_DURATION * 0.4)

	# 卷轴收起
	tw.chain().tween_property(bg, "scale:x", 0.0, CLOSE_DURATION).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tw.chain().tween_property(bg, "modulate:a", 0.0, CLOSE_DURATION * 0.5)

	# 完成后隐藏并发出信号
	tw.chain().tween_callback(func():
		bg.visible = false
		overlay.visible = false
		announced.emit()
	)
