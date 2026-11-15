shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.30, 0.13, 0.07, 0.95);
uniform float outline_px = 2.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 step_uv = TEXTURE_PIXEL_SIZE * outline_px;
	float edge = 0.0;
	for (int i = 0; i < 8; i++) {
		float angle = float(i) * 0.785398;
		float a = texture(TEXTURE, UV + vec2(cos(angle), sin(angle)) * step_uv).a;
		edge = max(edge, smoothstep(0.4, 0.7, a));
	}
	float outline_a = edge * outline_color.a;
	vec3 body = mix(c.rgb, vec3(1.0), flash);
	float out_a = c.a + outline_a * (1.0 - c.a);
	vec3 rgb = (body * c.a + outline_color.rgb * outline_a * (1.0 - c.a)) / max(out_a, 0.0001);
	COLOR = vec4(rgb, out_a);
}
