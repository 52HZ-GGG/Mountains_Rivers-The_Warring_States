@tool
class_name GenerateEffectSpriteFrames
extends EditorScript
## 一键生成所有战斗特效的 SpriteFrames 资源
##
## 使用方法：
##   1. 确保 assets/sprites/units/effects/ 下已有单帧 PNG 文件
##      （由 generate_effect_animations.py + 复制到项目生成）
##   2. 在 Godot 编辑器中：Project > Tools > EditorScript > 选择本文件
##   3. 等待控制台输出完成信息
##
## 输出：
##   每个特效目录下生成 effect_frames.tres（SpriteFrames 资源）
##   包含 1 个动画（以特效名命名），8 帧，不循环

## 帧率（FPS）
const FPS: float = 8.0

## 特效根目录
const EFFECTS_ROOT: String = "res://assets/sprites/units/effects/"


func _run() -> void:
	print("=== 战斗特效 SpriteFrames 生成器 ===")
	print("扫描目录: ", EFFECTS_ROOT)
	print("")

	var total_effects: int = 0
	var total_frames: int = 0

	var dir := DirAccess.open(EFFECTS_ROOT)
	if not dir:
		print("无法打开目录: ", EFFECTS_ROOT)
		return

	dir.list_dir_begin()
	var entry := dir.get_next()

	while entry != "":
		if dir.current_is_dir() and entry.begins_with("fx_"):
			var effect_dir: String = EFFECTS_ROOT.path_join(entry)
			var frames: Array[String] = _collect_frames(effect_dir, entry)

			if not frames.is_empty():
				var sf := SpriteFrames.new()

				if sf.has_animation("default"):
					sf.remove_animation("default")

				# 用特效名作为动画名
				sf.add_animation(entry)
				sf.set_animation_speed(entry, FPS)
				sf.set_animation_loop(entry, false)

				for frame_path: String in frames:
					var tex: Texture2D = load(frame_path) as Texture2D
					if tex:
						sf.add_frame(entry, tex)

				var tres_path: String = effect_dir.path_join("effect_frames.tres")
				var err: Error = ResourceSaver.save(sf, tres_path)
				if err == OK:
					print("  [OK] ", tres_path, " (", frames.size(), " frames)")
					total_effects += 1
					total_frames += frames.size()
				else:
					print("  [ERR] ", tres_path, " error: ", error_string(err))

		entry = dir.get_next()

	dir.list_dir_end()

	print("")
	print("=== 完成: ", total_effects, " 特效, ", total_frames, " 帧 ===")


## 收集目录中所有动画帧并排序
func _collect_frames(effect_dir: String, effect_name: String) -> Array[String]:
	var frames: Array[String] = []
	var dir := DirAccess.open(effect_dir)
	if not dir:
		return frames

	dir.list_dir_begin()
	var entry := dir.get_next()

	while entry != "":
		if entry.ends_with(".png") and entry.begins_with(effect_name + "_"):
			frames.append(effect_dir.path_join(entry))
		entry = dir.get_next()

	dir.list_dir_end()
	frames.sort()
	return frames
