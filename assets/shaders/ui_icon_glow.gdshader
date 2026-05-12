shader_type canvas_item;
render_mode blend_mix;

// ══════════════════════════════════════════════════════════
// 《山河策》图标发光 Shader
// 用途：学派/科技/资源图标选中时的发光效果
// 使用：设为 TextureRect/TextureButton 的 material
// ══════════════════════════════════════════════════════════

// 发光颜色（可由外部设置，如学派主题色）
uniform vec4 glow_color : source_color = vec4(0.85, 0.75, 0.45, 1.0);

// 发光参数
uniform float glow_strength : hint_range(0.0, 1.0) = 0.4;
uniform float glow_radius : hint_range(0.0, 0.3) = 0.08;
uniform float pulse_speed : hint_range(0.0, 3.0) = 1.2;

// 是否激活发光
uniform bool active = false;

void fragment() {
    vec4 base = texture(TEXTURE, UV);
    if (base.a < 0.01) {
        COLOR = base;
        return;
    }

    vec3 col = base.rgb;
    float alpha = base.a;

    if (active) {
        // 脉冲
        float pulse = 0.7 + 0.3 * sin(TIME * pulse_speed);

        // 边缘发光（采样周围像素判断是否在边缘）
        float edge = 0.0;
        float r = glow_radius;
        for (float dx = -1.0; dx <= 1.0; dx += 1.0) {
            for (float dy = -1.0; dy <= 1.0; dy += 1.0) {
                vec2 offset = vec2(dx, dy) * r;
                float s = texture(TEXTURE, UV + offset).a;
                edge += s;
            }
        }
        edge = edge / 9.0;
        float outline = smoothstep(0.3, 0.7, edge) * (1.0 - smoothstep(0.7, 1.0, base.a));

        // 发光叠加
        vec3 glow = glow_color.rgb * glow_strength * pulse;
        col += glow * (outline + 0.15);

        // 中心微亮
        vec2 center = UV - vec2(0.5);
        float dist = length(center * 2.0);
        col += glow * 0.1 * (1.0 - dist);
    }

    COLOR = vec4(col, alpha);
}
