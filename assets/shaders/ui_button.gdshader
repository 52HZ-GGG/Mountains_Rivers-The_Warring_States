shader_type canvas_item;
render_mode blend_mix;

// ══════════════════════════════════════════════════════════
// 《山河策》按钮 Shader
// 用途：按钮悬停/按下效果，竹简风格
// 使用：设为 Button 的 material shader
//       通过 GDScript 修改 state uniform
// ══════════════════════════════════════════════════════════

// 状态：0=普通, 1=悬停, 2=按下, 3=禁用
uniform int state : hint_range(0, 3) = 0;

// 颜色配置
uniform vec4 color_normal : source_color = vec4(0.10, 0.08, 0.06, 0.95);
uniform vec4 color_hover : source_color = vec4(0.16, 0.12, 0.08, 0.95);
uniform vec4 color_pressed : source_color = vec4(0.06, 0.05, 0.03, 0.95);
uniform vec4 color_disabled : source_color = vec4(0.08, 0.07, 0.06, 0.7);
uniform vec4 border_color : source_color = vec4(0.45, 0.38, 0.24, 1.0);

// 悬停发光
uniform float glow_strength : hint_range(0.0, 0.5) = 0.15;
uniform float glow_speed : hint_range(0.0, 3.0) = 1.5;

// 边框
uniform float border_width : hint_range(0.0, 0.15) = 0.06;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
    vec2 uv = UV;
    vec4 base = texture(TEXTURE, uv);

    // 根据状态选颜色
    vec4 col;
    if (state == 0) {
        col = color_normal;
    } else if (state == 1) {
        col = color_hover;
        // 悬停脉冲发光
        float glow = glow_strength * (0.5 + 0.5 * sin(TIME * glow_speed));
        col.rgb += vec3(glow);
        // 边框微亮
        border_color.rgb += vec3(0.08);
    } else if (state == 2) {
        col = color_pressed;
        // 按下时内容下移 1px 效果（通过 UV 偏移模拟）
        uv.y = clamp(uv.y - 0.03, 0.0, 1.0);
    } else {
        col = color_disabled;
    }

    // 如果有纹理，混合纹理
    if (base.a > 0.01) {
        col.rgb = mix(col.rgb, base.rgb, base.a * 0.3);
    }

    // 边框
    float bx = min(uv.x, 1.0 - uv.x);
    float by = min(uv.y, 1.0 - uv.y);
    float edge = min(bx, by);
    float border = smoothstep(border_width, border_width + 0.01, edge);
    col.rgb = mix(border_color.rgb, col.rgb, border);

    // 底部阴影线
    float bottom_shadow = smoothstep(0.0, 0.08, uv.y);
    col.rgb *= 0.9 + 0.1 * bottom_shadow;

    // 顶部高光线
    float top_light = smoothstep(0.0, 0.05, 1.0 - uv.y);
    col.rgb += vec3(0.03) * top_light;

    // 禁用态去饱和
    if (state == 3) {
        float gray = dot(col.rgb, vec3(0.299, 0.587, 0.114));
        col.rgb = mix(col.rgb, vec3(gray), 0.5);
    }

    float alpha = col.a;
    if (base.a > 0.01) {
        alpha = max(alpha, base.a);
    }
    COLOR = vec4(col.rgb, alpha);
}
