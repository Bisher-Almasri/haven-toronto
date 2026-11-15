shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec4 outline_color : source_color = vec4(0.30, 0.13, 0.07, 0.95);
uniform float outline_px = 2.0;

void fragment() {
	vec4 c = texture(tex, UV);
	vec2 step_uv = outline_px / vec2(textureSize(tex, 0));
	float edge = 0.0;
	for (int i = 0; i < 8; i++) {
		float angle = float(i) * 0.785398;
		float a = texture(tex, UV + vec2(cos(angle), sin(angle)) * step_uv).a;
		edge = max(edge, smoothstep(0.4, 0.7, a));
	}
	float outline_a = edge * outline_color.a;
	float out_a = c.a + outline_a * (1.0 - c.a);
	ALBEDO = (c.rgb * c.a + outline_color.rgb * outline_a * (1.0 - c.a)) / max(out_a, 0.0001);
	ALPHA = out_a;
}
