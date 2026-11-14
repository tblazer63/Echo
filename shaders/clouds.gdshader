shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, shadows_disabled, diffuse_lambert, specular_disabled;

#include "res://shaders/noise.gdshaderinc"

uniform vec3 light_col : source_color = vec3(0.97, 0.99, 1.0);
uniform vec3 shade_col : source_color = vec3(0.62, 0.78, 0.92);
uniform float scale = 0.012;
uniform float drift = 0.004;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 p = vec3(wpos.x * scale + TIME * drift, TIME * 0.01, wpos.z * scale);
	float n = fbm3(p);
	float n2 = fbm3(p * 3.0 + 5.0);
	float c = smoothstep(0.3, 0.7, n * 0.75 + n2 * 0.35);
	ALBEDO = mix(shade_col, light_col, c);
	float dist = length(wpos.xz - CAMERA_POSITION_WORLD.xz);
	ALPHA = (0.55 + c * 0.45) * smoothstep(1400.0, 600.0, dist);
	EMISSION = ALBEDO * 0.35;
}
