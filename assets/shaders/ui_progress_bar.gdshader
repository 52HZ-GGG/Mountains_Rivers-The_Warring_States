shader_type canvas_item;
render_mode blend_mix;

// ══════════════════════════════════════════════════════════
// 《山河策》进度条 Shader
// 用途：资源条/科技进度/经验值等进度条
// 使用：设为 TextureProgressBar 或自定义 Control 的 material
// ══════════════════════════════════════════════════════════

// 进度 0.0 ~ 1.0
uniform float progress : hint_range(0.0, 1.0) = 0.5;

// 颜色
uniform vec4 color_fill : source_color = vec4(0.70, 0.55, 0.30, 1.0);
uniform vec4 color_empty : source_color = vec4(0.08, 0.07, 0.06, 0.8);
uniform vec4 color_bg : source_color = vec4(0.05, 0.04, 0.03, 0.9);

// 条纹动画
uniform bool striped = true;
uniform float stripe_speed : hint_range(0.0, 2.0) = 0.3;

// 闪光效果（进度变化时）
uniform float shine : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec2 uv = UV;
    vec4 base = texture(TEXTURE, uv);

    // 背景
    vec3 col = color_bg.rgb;
    float alpha = color_bg.a;

    // 空区域
    if (uv.x > progress) {
        col = color_empty.rgb;
        alpha = color_empty.a;
    } else {
        // 填充区域
        col = color_fill.rgb;
        alpha = color_fill.a;

        // 条纹
        if (striped) {
            float stripe = fract((uv.x + uv.y * 0.3 + TIME * stripe_speed) * 8.0);
            stripe = smoothstep(0.4, 0.5, stripe) - smoothstep(0.5, 0.6, stripe);
            col += vec3(stripe * 0.08);
        }

        // 渐变（左暗右亮）
        float grad = uv.x / max(progress, 0.01);
        col *= 0.85 + 0.15 * grad;

        // 闪光
        if (shine > 0.01) {
            float shine_pos = fract(TIME * 0.5);
            float shine_width = 0.15;
            float s = smoothstep(shine_pos - shine_width, shine_pos, uv.x)
                    * smoothstep(shine_pos + shine_width, shine_pos, uv.x);
            col += vec3(s * shine * 0.5);
        }
    }

    // 边框
    float bx = min(uv.x, 1.0 - uv.x);
    float by = min(uv.y, 1.0 - uv.y);
    float edge = min(bx, by);
    float border = smoothstep(0.02, 0.04, edge);
    col = mix(vec3(0.3, 0.25, 0.18), col, border);

    // 混合纹理
    if (base.a > 0.01) {
        col = mix(col, base.rgb, base.a * 0.3);
        alpha = max(alpha, base.a);
    }

    COLOR = vec4(col, alpha);
}
