shader_type canvas_item;
render_mode blend_mix;

// ══════════════════════════════════════════════════════════
// 《山河策》文化覆盖层 Shader
// 用途：在六角格上显示势力文化影响范围
// 使用：设 uniform faction_color 为势力颜色，alpha 控制强度
// ══════════════════════════════════════════════════════════

// 势力颜色（运行时从 factions.json 注入）
uniform vec4 faction_color : source_color = vec4(0.5, 0.2, 0.1, 0.3);

// 脉冲动画参数
uniform float pulse_speed : hint_range(0.0, 3.0) = 1.0;
uniform float pulse_strength : hint_range(0.0, 0.5) = 0.15;

// 边缘淡化
uniform float edge_fade : hint_range(0.0, 1.0) = 0.3;

// 噪声强度（增加有机感）
uniform float noise_strength : hint_range(0.0, 0.3) = 0.08;

// 简单哈希噪声
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise2d(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
    vec4 base = texture(TEXTURE, UV);
    // 如果有纹理，用纹理 alpha；否则用 UV 距离中心的衰减
    float tex_alpha = base.a;

    // 六角形边缘淡化（基于 UV 到中心的距离）
    vec2 center = UV - vec2(0.5);
    float dist = length(center * 2.0);
    float edge = smoothstep(1.0, 1.0 - edge_fade, dist);

    // 脉冲动画
    float pulse = 1.0 + pulse_strength * sin(TIME * pulse_speed);

    // 噪声扰动
    float n = noise2d(UV * 8.0 + TIME * 0.3) * noise_strength;

    // 最终 alpha
    float alpha = faction_color.a * tex_alpha * edge * pulse + n;
    alpha = clamp(alpha, 0.0, 0.6);

    // 颜色：势力颜色 + 微弱边缘光
    vec3 col = faction_color.rgb;
    col += vec3(0.1) * (1.0 - dist) * 0.5;  // 中心微亮

    COLOR = vec4(col, alpha);
}
