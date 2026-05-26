extends Node2D
class_name Unit

## 单位动画状态
enum AnimState { IDLE, MOVE, ATTACK, HURT, DEATH }

## 单位类型
@export var unit_type: String = "unit_infantry"
@export var faction: String = "base"  # base, qin, zhao, qi, chu, wei, yan, han

## 当前位置（六角网格坐标）
var hex_position: Vector2i = Vector2i.ZERO

## 目标位置（移动时）
var target_hex_position: Vector2i = Vector2i.ZERO

## 移动相关
var is_moving: bool = false
var move_speed: float = 200.0  # 像素/秒
var move_progress: float = 0.0
var move_start_position: Vector2 = Vector2.ZERO
var move_target_position: Vector2 = Vector2.ZERO

## 动画相关
var current_anim_state: AnimState = AnimState.IDLE
var sprite_frames: SpriteFrames = null

## 节点引用
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	_load_sprite_frames()
	_play_animation(AnimState.IDLE)


func _process(delta: float) -> void:
	if is_moving:
		_update_movement(delta)


## 加载 SpriteFrames 资源
func _load_sprite_frames() -> void:
	var path := "res://assets/sprites/units/%s/%s/unit_frames.tres" % [faction, unit_type]
	if ResourceLoader.exists(path):
		sprite_frames = load(path)
		if sprite_frames:
			animated_sprite.sprite_frames = sprite_frames
	else:
		# 如果没有预生成的 SpriteFrames，尝试动态创建
		_create_sprite_frames_from_files()


## 从文件动态创建 SpriteFrames
func _create_sprite_frames_from_files() -> void:
	var base_path := "res://assets/sprites/units/%s/%s/" % [faction, unit_type]
	var dir := DirAccess.open(base_path)

	if not dir:
		push_warning("Unit: Cannot open directory %s" % base_path)
		return

	sprite_frames = SpriteFrames.new()
	sprite_frames.remove_animation("default")

	var anim_names := ["idle", "move", "attack", "hurt", "death"]
	var loop_anims := ["idle", "move"]
	var fps := 8.0

	for anim_name in anim_names:
		var frame_files: Array[String] = []

		# 查找该动画的所有帧文件
		dir.list_dir_begin()
		var entry := dir.get_next()
		while entry != "":
			if entry.ends_with(".png") and not entry.ends_with(".import") and ("_" + anim_name + "_") in entry:
				frame_files.append(base_path + entry)
			entry = dir.get_next()
		dir.list_dir_end()

		if frame_files.is_empty():
			continue

		# 排序帧文件
		frame_files.sort()

		# 添加动画
		sprite_frames.add_animation(anim_name)
		sprite_frames.set_animation_speed(anim_name, fps)
		sprite_frames.set_animation_loop(anim_name, anim_name in loop_anims)

		# 添加帧
		for frame_path in frame_files:
			var tex := load(frame_path) as Texture2D
			if tex:
				sprite_frames.add_frame(anim_name, tex)

	if sprite_frames:
		animated_sprite.sprite_frames = sprite_frames
		print("Unit: Created SpriteFrames for %s/%s (%d animations)" % [faction, unit_type, sprite_frames.get_animation_names().size()])


## 播放动画
func _play_animation(state: AnimState) -> void:
	if not sprite_frames:
		return

	current_anim_state = state
	var anim_name := _get_animation_name(state)
	if sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)


## 获取动画名称
func _get_animation_name(state: AnimState) -> String:
	match state:
		AnimState.IDLE:
			return "idle"
		AnimState.MOVE:
			return "move"
		AnimState.ATTACK:
			return "attack"
		AnimState.HURT:
			return "hurt"
		AnimState.DEATH:
			return "death"
		_:
			return "idle"


## 开始移动到目标六角格
func move_to(target_hex: Vector2i) -> void:
	if is_moving:
		return

	target_hex_position = target_hex
	is_moving = true
	move_progress = 0.0
	move_start_position = global_position
	move_target_position = _hex_to_pixel(target_hex)
	_play_animation(AnimState.MOVE)


## 更新移动
func _update_movement(delta: float) -> void:
	var distance := move_start_position.distance_to(move_target_position)
	if distance < 1.0:
		_finish_movement()
		return

	move_progress += (move_speed * delta) / distance
	move_progress = clampf(move_progress, 0.0, 1.0)

	global_position = move_start_position.lerp(move_target_position, move_progress)

	if move_progress >= 1.0:
		_finish_movement()


## 完成移动
func _finish_movement() -> void:
	global_position = move_target_position
	hex_position = target_hex_position
	is_moving = false
	move_progress = 0.0
	_play_animation(AnimState.IDLE)


## 六角格坐标转像素位置（需要根据实际地图调整）
func _hex_to_pixel(hex: Vector2i) -> Vector2:
	# 使用 hex_axial.gd 的转换函数
	var circumradius := 32.0  # 六角格外接圆半径，根据实际大小调整
	var top_left := HexAxial.axial_flat_top_cell_top_left(hex.x, hex.y, circumradius)
	return top_left + Vector2(circumradius, circumradius * sqrt(3.0) * 0.5)


## 设置单位类型和阵营
func setup(p_unit_type: String, p_faction: String, p_hex_position: Vector2i) -> void:
	unit_type = p_unit_type
	faction = p_faction
	hex_position = p_hex_position
	target_hex_position = p_hex_position
	global_position = _hex_to_pixel(p_hex_position)
	_load_sprite_frames()
	_play_animation(AnimState.IDLE)


## 播放攻击动画
func play_attack() -> void:
	_play_animation(AnimState.ATTACK)


## 播放受伤动画
func play_hurt() -> void:
	_play_animation(AnimState.HURT)


## 播放死亡动画
func play_death() -> void:
	_play_animation(AnimState.DEATH)
