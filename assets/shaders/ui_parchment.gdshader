shader_type canvas_item;
render_mode blend_mix;

// ══════════════════════════════════════════════════════════
// 《山河策》羊皮纸/竹简面板 Shader
// 用途：UI 面板背景，模拟竹简/羊皮纸质感
// 使用：设为 Panel/PanelContainer 的 material shader
// ══════════════════════════════════════════════════════════

// 基础颜色
uniform vec4 base_color : source_color = vec4(0.10, 0.08, 0.06, 0.92);
uniform vec4 border_color : source_color = vec4(0.45, 0.38, 0.24, 1.0);
uniform vec4 highlight_color : source_color = vec4(0.55, 0.47, 0.32, 1.0);

// 边框参数
uniform float border_width : hint_range(0.0, 0.15) = 0.04;
uniform float corner_radius : hint_range(0.0, 0.2) = 0.02;

// 竹简纹理参数
uniform float grain_scale : hint_range(1.0, 30.0) = 12.0;
uniform float grain_strength : hint_range(0.0, 0.3) = 0.08;

// 顶光
uniform float top_light : hint_range(0.0, 0.3) = 0.06;

// 哈希噪声
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
    vec2 uv = UV;
    vec3 col = base_color.rgb;
    float alpha = base_color.a;

    // 竹简横纹（水平条纹模拟竹片拼接）
    float grain = noise2d(vec2(uv.x * grain_scale, uv.y * grain_scale * 0.3));
    col += vec3(grain * grain_strength);

    // 竹片接缝（每 0.08 水平一条细线）
    float seam = smoothstep(0.0, 0.005, abs(fract(uv.x * 12.5) - 0.5) - 0.48);
    col = mix(col, col * 0.85, (1.0 - seam) * 0.4);

    // 顶光效果（模拟光照从上方来）
    col += vec3(top_light * (1.0 - uv.y));

    // 边框
    float bx = min(uv.x, 1.0 - uv.x);
    float by = min(uv.y, 1.0 - uv.y);
    float edge = min(bx, by);

    // 圆角
    vec2 corner_uv = min(uv, 1.0 - uv);
    float corner_dist = length(max(vec2(corner_radius) - corner_uv, 0.0));
    float corner_mask = smoothstep(0.0, corner_radius, corner_dist + corner_radius);

    // 外边框
    float border = smoothstep(border_width, border_width + 0.008, edge);
    col = mix(border_color.rgb, col, border);

    // 内高光线（距边框 2px 处微亮）
    float inner_line = smoothstep(0.0, 0.01, abs(edge - border_width - 0.01));
    col = mix(highlight_color.rgb, col, inner_line * 0.7);

    // 边缘暗角
    float vignette = smoothstep(0.0, 0.4, edge);
    col *= 0.85 + 0.15 * vignette;

    alpha *= corner_mask;
    COLOR = vec4(col, alpha);
}
