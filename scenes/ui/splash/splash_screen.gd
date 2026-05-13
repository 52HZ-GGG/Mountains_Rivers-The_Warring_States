extends Control
## 进入动画（Splash Screen）
## 流程：黑屏 0.5s → Logo 淡入 1s → 毛笔写字 1.5s → 光晕 0.5s → 淡出 1s → 切换主场景
##
## 由 StartupFlow 管理流程，动画结束后调用 StartupFlow.on_splash_finished()

# 配置
@export var next_scene: String = ""  # 留空则由 StartupFlow 接管
@export var skip_on_click: bool = true  # 点击可跳过

# 节点引用
@onready var bg: ColorRect = $Background
@onready var logo: TextureRect = $LogoContainer/Logo
@onready var title: TextureRect = $TitleContainer/Title
@onready var anim: AnimationPlayer = $AnimationPlayer

# Shader 参数
const MASK_FRAMES := 36  # 3 字 × 12 帧
const BRUSH_DURATION := 1.5  # 毛笔写字总时长（秒）
const GLOW_DURATION := 0.5

var _finished := false

func _ready() -> void:
	# 初始状态：全黑，Logo 和标题隐藏
	bg.color = Color.BLACK
	logo.modulate.a = 0.0
	title.visible = false

	# 创建并播放动画
	_create_animation()
	anim.play("splash")

func _unhandled_input(event: InputEvent) -> void:
	if skip_on_click and event is InputEventMouseButton and event.pressed:
		_skip_to_main()

func _skip_to_main() -> void:
	if _finished:
		return
	_finished = true
	anim.stop()
	_go_next()

func _go_next() -> void:
	if next_scene != "":
		get_tree().change_scene_to_file(next_scene)
	else:
		StartupFlow.on_splash_finished()

func _create_animation() -> void:
	var lib := Animation.new()
	var track_bg: int
	var track_logo: int
	var track_title_visible: int
	var track_title_frame: int
	var track_title_glow: int
	var track_finish: int

	# 总时长：0.5 + 1.0 + 1.5 + 0.5 + 1.0 = 4.5s
	lib.length = 4.5

	# ── Background：始终黑色，最后淡出到透明 ──
	track_bg = lib.add_track(Animation.TYPE_VALUE)
	lib.track_set_path(track_bg, "Background:color")
	lib.track_insert_key(track_bg, 0.0, Color.BLACK)
	lib.track_insert_key(track_bg, 3.5, Color.BLACK)
	lib.track_insert_key(track_bg, 4.5, Color(0, 0, 0, 0))

	# ── Logo：0.5s 开始淡入，1.5s 完成 ──
	track_logo = lib.add_track(Animation.TYPE_VALUE)
	lib.track_set_path(track_logo, "LogoContainer/Logo:modulate:a")
	lib.track_insert_key(track_logo, 0.0, 0.0)
	lib.track_insert_key(track_logo, 0.5, 0.0)
	lib.track_insert_key(track_logo, 1.5, 1.0)
	# Logo 在写字阶段保持，淡出阶段消失
	lib.track_insert_key(track_logo, 3.5, 1.0)
	lib.track_insert_key(track_logo, 4.0, 0.0)

	# ── Title 可见性：1.5s 时显示 ──
	track_title_visible = lib.add_track(Animation.TYPE_VALUE)
	lib.track_set_path(track_title_visible, "TitleContainer/Title:visible")
	lib.track_insert_key(track_title_visible, 0.0, false)
	lib.track_insert_key(track_title_visible, 1.49, false)
	lib.track_insert_key(track_title_visible, 1.5, true)

	# ── Title shader frame：1.5s~3.0s 从 0→35 ──
	track_title_frame = lib.add_track(Animation.TYPE_VALUE)
	lib.track_set_path(track_title_frame, "TitleContainer/Title:material:shader_parameter/frame")
	lib.track_insert_key(track_title_frame, 1.5, 0)
	lib.track_insert_key(track_title_frame, 3.0, MASK_FRAMES - 1)

	# ── Title 光晕：3.0s~3.5s 脉冲 ──
	track_title_glow = lib.add_track(Animation.TYPE_VALUE)
	lib.track_set_path(track_title_glow, "TitleContainer/Title:material:shader_parameter/glow_intensity")
	lib.track_insert_key(track_title_glow, 0.0, 0.0)
	lib.track_insert_key(track_title_glow, 3.0, 0.0)
	lib.track_insert_key(track_title_glow, 3.15, 1.0)
	lib.track_insert_key(track_title_glow, 3.5, 0.3)

	# ── Title 淡出：3.5s~4.0s ──
	var track_title_alpha = lib.add_track(Animation.TYPE_VALUE)
	lib.track_set_path(track_title_alpha, "TitleContainer/Title:modulate:a")
	lib.track_insert_key(track_title_alpha, 0.0, 0.0)
	lib.track_insert_key(track_title_alpha, 1.5, 1.0)
	lib.track_insert_key(track_title_alpha, 3.5, 1.0)
	lib.track_insert_key(track_title_alpha, 4.0, 0.0)

	# ── 动画结束回调 ──
	track_finish = lib.add_track(Animation.TYPE_METHOD)
	lib.track_set_path(track_finish, ".")
	lib.track_insert_key(track_finish, 4.5, {"method": "_on_splash_finished", "args": []})

	# 添加到 AnimationPlayer
	var lib_name := "splash"
	var anim_lib := AnimationLibrary.new()
	anim_lib.add_animation(lib_name, lib)
	anim.add_animation_library("", anim_lib)

func _on_splash_finished() -> void:
	if _finished:
		return
	_finished = true
	_go_next()
