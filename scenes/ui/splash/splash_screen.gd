extends Control
## Splash Screen - minimal test version

@onready var bg: ColorRect = $Background
@onready var logo: TextureRect = $LogoContainer/Logo
@onready var anim: AnimationPlayer = $AnimationPlayer

var _finished := false

func _ready() -> void:
	print("[Splash] _ready 执行")
	bg.color = Color.BLACK
	logo.modulate.a = 0.0

	# 绑定 Logo 纹理
	var logo_path := "res://photos/logo/logo_shanhece.png"
	if ResourceLoader.exists(logo_path):
		var tex: Texture2D = load(logo_path) as Texture2D
		logo.texture = tex
		print("[Splash] Logo 已加载: %s" % str(tex.get_size()))
	else:
		print("[Splash] Logo 文件不存在")

	# 创建简单动画
	_create_animation()
	anim.play("splash")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and not _finished:
		_finished = true
		_go_next()

func _go_next() -> void:
	StartupFlow.on_splash_finished()

func _create_animation() -> void:
	var lib := Animation.new()
	lib.length = 4.5

	# Logo 淡入
	var track_logo := lib.add_track(Animation.TYPE_VALUE)
	lib.track_set_path(track_logo, "LogoContainer/Logo:modulate:a")
	lib.track_insert_key(track_logo, 0.0, 0.0)
	lib.track_insert_key(track_logo, 0.5, 0.0)
	lib.track_insert_key(track_logo, 1.5, 1.0)
	lib.track_insert_key(track_logo, 3.5, 1.0)
	lib.track_insert_key(track_logo, 4.0, 0.0)

	# 背景淡出
	var track_bg := lib.add_track(Animation.TYPE_VALUE)
	lib.track_set_path(track_bg, "Background:color")
	lib.track_insert_key(track_bg, 0.0, Color.BLACK)
	lib.track_insert_key(track_bg, 3.5, Color.BLACK)
	lib.track_insert_key(track_bg, 4.5, Color(0, 0, 0, 0))

	# 动画结束回调
	var track_finish := lib.add_track(Animation.TYPE_METHOD)
	lib.track_set_path(track_finish, ".")
	lib.track_insert_key(track_finish, 4.5, {"method": "_on_splash_finished", "args": []})

	var anim_lib := AnimationLibrary.new()
	anim_lib.add_animation("splash", lib)
	anim.add_animation_library("", anim_lib)

func _on_splash_finished() -> void:
	if not _finished:
		_finished = true
		_go_next()
