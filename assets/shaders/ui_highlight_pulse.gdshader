shader_type canvas_item;
render_mode blend_mix;

// ══════════════════════════════════════════════════════════
// 《山河策》选中高亮 Shader
// 用途：六角格选中/移动/攻击范围的动画高亮
// 使用：设为高亮 Sprite2D 的 material
// ══════════════════════════════════════════════════════════

// 高亮类型：0=选中(黄), 1=移动(蓝), 2=攻击(红)
uniform int highlight_type : hint_range(0, 2) = 0;

// 动画
uniform float pulse_speed : hint_range(0.5, 4.0) = 2.0;
uniform float breathe_strength : hint_range(0.0, 0.5) = 0.2;

// 边框流动
uniform float border_flow_speed : hint_range(0.0, 3.0) = 1.5;
uniform float border_width : hint_range(0.01, 0.15) = 0.06;

// 预设颜色
const vec3 COLOR_SELECT = vec3(0.86, 0.78, 0.31);   // 选中黄
const vec3 COLOR_MOVE = vec3(0.31, 0.55, 0.86);     // 移动蓝
const vec3 COLOR_ATTACK = vec3(0.86, 0.31, 0.31);   // 攻击红

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
    vec4 base = texture(TEXTURE, UV);
    float tex_alpha = base.a;

    // 选颜色
    vec3 hl_color;
    if (highlight_type == 0) {
        hl_color = COLOR_SELECT;
    } else if (highlight_type == 1) {
        hl_color = COLOR_MOVE;
    } else {
        hl_color = COLOR_ATTACK;
    }

    // 中心到边缘距离
    vec2 center = UV - vec2(0.5);
    float dist = length(center * 2.0);

    // 脉冲呼吸
    float pulse = 1.0 + breathe_strength * sin(TIME * pulse_speed);

    // 流动边框
    float angle = atan(center.y, center.x);
    float flow = sin(angle * 6.0 + TIME * border_flow_speed) * 0.5 + 0.5;

    // 边框高亮
    float border = smoothstep(border_width + 0.02, border_width, abs(dist - 0.85));
    border *= 0.7 + 0.3 * flow;

    // 内部填充
    float fill = smoothstep(1.0, 0.3, dist) * 0.3;

    // 组合
    float alpha = (border + fill) * pulse * tex_alpha;
    vec3 col = hl_color * (0.8 + 0.2 * flow);

    // 中心微光
    col += vec3(0.15) * (1.0 - dist) * pulse * 0.3;

    COLOR = vec4(col, alpha);
}
