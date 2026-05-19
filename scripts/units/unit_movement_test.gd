extends Node2D

## 单位移动动画测试脚本

@onready var unit: Unit = $Unit
@onready var movement_manager: UnitMovementManager = $UnitMovementManager

## 测试用的六角格坐标
var test_hexes: Array[Vector2i] = [
	Vector2i(0, 0),
	Vector2i(1, 0),
	Vector2i(2, 0),
	Vector2i(3, 0),
	Vector2i(4, 0),
]

var current_test_index: int = 0


func _ready() -> void:
	# 设置单位
	unit.setup("unit_infantry", "base", Vector2i(0, 0))

	# 设置移动管理器
	movement_manager.set_map_bounds(-20, 20, -20, 20)

	# 确保单位在屏幕中心
	unit.position = Vector2(512, 300)

	# 调整单位大小（图片太大，需要缩小）
	unit.scale = Vector2(0.25, 0.25)  # 缩小到 25%

	# 检查动画是否加载成功
	if unit.sprite_frames:
		print("✅ 动画加载成功！")
		print("可用动画：", unit.sprite_frames.get_animation_names())
		for anim_name in unit.sprite_frames.get_animation_names():
			var frame_count = unit.sprite_frames.get_frame_count(anim_name)
			print("  动画 '%s': %d 帧" % [anim_name, frame_count])
	else:
		print("❌ 动画加载失败！")

	# 开始测试
	print("=== 单位移动动画测试 ===")
	print("单位位置：", unit.position)
	print("单位大小：", unit.scale)
	print("")
	print("按键操作：")
	print("  空格键：移动单位")
	print("  ESC 键：重置位置")
	print("  T 键：测试可达范围")
	print("  1 键：idle（空闲）")
	print("  2 键：move（移动）")
	print("  3 键：attack（攻击）")
	print("  4 键：hurt（受伤）")
	print("  5 键：death（死亡）")
	print("========================")


## 测试加载图片
func _test_load_image() -> void:
	var test_path := "res://assets/sprites/units/base/unit_infantry/idle_01.png"
	if ResourceLoader.exists(test_path):
		var tex := load(test_path) as Texture2D
		if tex:
			print("✅ 测试图片加载成功：", test_path)
			# 创建一个临时精灵显示
			var sprite := Sprite2D.new()
			sprite.texture = tex
			sprite.position = Vector2(512, 300)
			sprite.scale = Vector2(0.1, 0.1)
			add_child(sprite)
		else:
			print("❌ 测试图片加载失败")
	else:
		print("❌ 测试图片不存在：", test_path)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):  # Space
		_test_move_to_next_hex()
	elif event.is_action_pressed("ui_cancel"):  # Escape
		_reset_unit()
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_T:
				_test_reachable_hexes()
			KEY_1:
				_play_anim("idle")
			KEY_2:
				_play_anim("move")
			KEY_3:
				_play_anim("attack")
			KEY_4:
				_play_anim("hurt")
			KEY_5:
				_play_anim("death")


## 测试移动到下一个六角格
func _test_move_to_next_hex() -> void:
	if unit.is_moving:
		print("Unit is still moving, please wait...")
		return

	current_test_index = (current_test_index + 1) % test_hexes.size()
	var target_hex := test_hexes[current_test_index]

	print("Moving unit to hex: %s" % str(target_hex))
	unit.move_to(target_hex)


## 重置单位位置
func _reset_unit() -> void:
	unit.setup("unit_infantry", "base", Vector2i(0, 0))
	current_test_index = 0
	print("Unit reset to origin")


## 测试可达范围计算
func _test_reachable_hexes() -> void:
	var move_range := 3
	var reachable := movement_manager.get_reachable_hexes(unit, move_range)

	print("Reachable hexes from %s with range %d:" % [str(unit.hex_position), move_range])
	for hex: Vector2i in reachable:
		print("  %s" % str(hex))


## 播放指定动画
func _play_anim(anim_name: String) -> void:
	if unit.animated_sprite.sprite_frames and unit.animated_sprite.sprite_frames.has_animation(anim_name):
		unit.animated_sprite.play(anim_name)
		print("播放动画: ", anim_name)
	else:
		print("动画不存在: ", anim_name)


## 绘制六角格网格（调试用）
func _draw() -> void:
	# 绘制简单的网格线
	var grid_size := 50.0
	var grid_color := Color(0.5, 0.5, 0.5, 0.3)

	for i in range(-10, 11):
		# 垂直线
		var x := i * grid_size
		draw_line(Vector2(x, -500), Vector2(x, 500), grid_color)
		# 水平线
		var y := i * grid_size
		draw_line(Vector2(-500, y), Vector2(500, y), grid_color)


## 更新绘制
func _process(delta: float) -> void:
	queue_redraw()
