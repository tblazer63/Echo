shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

#include "res://shaders/noise.gdshaderinc"

uniform float speed = 1.6;
uniform vec3 deep : source_color = vec3(0.55, 0.85, 0.95);
uniform vec3 foam : source_color = vec3(0.97, 1.0, 1.0);

void fragment() {
	vec2 uv = UV;
	float streak = fbm3(vec3(uv.x * 14.0, uv.y * 2.0 - TIME * speed, 0.0));
	float streak2 = fbm3(vec3(uv.x * 30.0, uv.y * 4.0 - TIME * speed * 1.4, 4.0));
	float s = smoothstep(0.35, 0.75, streak * 0.6 + streak2 * 0.5);
	float side = smoothstep(0.0, 0.18, uv.x) * smoothstep(1.0, 0.82, uv.x);
	float bottom = smoothstep(1.0, 0.6, uv.y);
	float top = smoothstep(0.0, 0.05, uv.y);
	ALBEDO = mix(deep, foam, s);
	ALPHA = side * bottom * top * (0.45 + s * 0.5);
}
