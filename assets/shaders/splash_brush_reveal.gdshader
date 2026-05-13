shader_type canvas_item;
// 毛笔写字揭露效果
// 用于 Splash 屏的「山河策」逐字显现动画
//
// 使用方式：
//   title_texture  = 最终文字纹理 (splash_title.png)
//   mask_texture   = 遮罩精灵表 (splash_title_mask.png)
//   frame          = 当前帧索引 (0 ~ total_frames-1)
//   total_frames   = 精灵表总帧数
//   glow_intensity = 光晕强度 (0~1，写字完成后脉冲)

uniform sampler2D title_texture;
uniform sampler2D mask_texture;
uniform int frame : hint_range(0, 35) = 0;
uniform int total_frames = 36;
uniform float glow_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 glow_color : source_color = vec4(0.784, 0.659, 0.306, 1.0); // #C8A84E

void fragment() {
	// 计算 mask 精灵表中的 UV 偏移
	float frame_width = 1.0 / float(total_frames);
	float offset_x = float(frame) * frame_width;
	vec2 mask_uv = vec2(UV.x * frame_width + offset_x, UV.y);

	// 采样 mask（白色 = 显示，黑色 = 隐藏）
	float mask = texture(mask_texture, mask_uv).r;

	// 采样标题文字
	vec4 title_color = texture(title_texture, UV);

	// 用 mask 控制文字显示
	vec4 final_color = title_color;
	final_color.a *= mask;

	// 光晕效果：写字完成后文字轻微发光
	if (glow_intensity > 0.0) {
		// 在文字边缘添加光晕
		float glow_mask = smoothstep(0.0, 0.3, mask) * (1.0 - smoothstep(0.7, 1.0, mask));
		final_color.rgb += glow_color.rgb * glow_intensity * 0.4;
		final_color.rgb += glow_color.rgb * glow_mask * glow_intensity * 0.6;
		final_color.a = max(final_color.a, glow_mask * glow_intensity * 0.3);
	}

	COLOR = final_color;
}
