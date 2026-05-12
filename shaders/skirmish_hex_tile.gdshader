shader_type canvas_item;
render_mode blend_mix;

/* 文明类六角：顶光、边角略暗、轻微冷色阴影（不改数值，仅美术表现） */

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	if (base.a < 0.001) {
		COLOR = base;
		return;
	}
	float bx = min(UV.x, 1.0 - UV.x);
	float by = min(UV.y, 1.0 - UV.y);
	float edge = min(bx, by);
	float rim = smoothstep(0.02, 0.18, edge * 3.5);
	float roof = mix(0.84, 1.12, 1.0 - UV.y * 0.55);
	roof *= mix(0.9, 1.06, 1.0 - UV.x * 0.35);
	vec3 lit = base.rgb * roof * (0.76 + 0.24 * rim);
	lit = mix(lit, lit * vec3(0.82, 0.88, 1.05), 0.14 * (1.0 - rim));
	COLOR = vec4(lit, base.a);
}
