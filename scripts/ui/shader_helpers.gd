class_name ShaderHelpers
extends RefCounted

## Shader 辅助工具
## 提供快速创建 shader material 的工厂方法

# ── 势力颜色常量（来自 factions.json） ──
const FACTION_COLORS := {
	"qin":  Color(0.545, 0.0, 0.0),      # #8B0000
	"zhao": Color(0.255, 0.412, 0.882),   # #4169E1
	"qi":   Color(1.0, 0.843, 0.0),       # #FFD700
	"chu":  Color(0.133, 0.545, 0.133),   # #228B22
	"wei":  Color(0.294, 0.0, 0.510),     # #4B0082
	"yan":  Color(0.184, 0.310, 0.310),   # #2F4F4F
	"han":  Color(1.0, 0.388, 0.278),     # #FF6347
}

# ── 学派颜色（UI 用） ──
const SCHOOL_COLORS := {
	"confucianism": Color(0.627, 0.471, 0.275),
	"legalism":     Color(0.392, 0.235, 0.157),
	"mohism":       Color(0.314, 0.392, 0.275),
	"daoism":       Color(0.471, 0.549, 0.510),
	"military":     Color(0.353, 0.275, 0.235),
	"diplomacy":    Color(0.549, 0.510, 0.314),
}


## 创建文化覆盖层 material
static func create_culture_material(faction_id: String, alpha: float = 0.3) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/culture_overlay.gdshader")
	var col: Color = FACTION_COLORS.get(faction_id, Color(0.5, 0.5, 0.5, alpha))
	col.a = alpha
	mat.set_shader_parameter("faction_color", col)
	return mat


## 创建羊皮纸面板 material
static func create_parchment_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/ui_parchment.gdshader")
	return mat


## 创建按钮 material
static func create_button_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/ui_button.gdshader")
	return mat


## 设置按钮状态（0=普通, 1=悬停, 2=按下, 3=禁用）
static func set_button_state(mat: ShaderMaterial, state: int) -> void:
	mat.set_shader_parameter("state", state)


## 创建高亮 material
static func create_highlight_material(highlight_type: int = 0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/ui_highlight_pulse.gdshader")
	mat.set_shader_parameter("highlight_type", highlight_type)
	return mat


## 创建图标发光 material
static func create_icon_glow_material(school_id: String = "") -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/ui_icon_glow.gdshader")
	if school_id != "":
		var col: Color = SCHOOL_COLORS.get(school_id, Color(0.85, 0.75, 0.45))
		mat.set_shader_parameter("glow_color", col)
	return mat


## 创建进度条 material
static func create_progress_material(fill_color: Color = Color(0.7, 0.55, 0.3)) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/ui_progress_bar.gdshader")
	mat.set_shader_parameter("color_fill", fill_color)
	return mat


## 设置进度条值
static func set_progress(mat: ShaderMaterial, value: float) -> void:
	mat.set_shader_parameter("progress", clampf(value, 0.0, 1.0))
