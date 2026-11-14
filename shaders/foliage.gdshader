shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap, specular_disabled;

#include "res://shaders/noise.gdshaderinc"

uniform vec3 tip : source_color = vec3(0.58, 0.80, 0.32);
uniform vec3 root : source_color = vec3(0.16, 0.34, 0.13);
uniform float sway = 0.12;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = clamp(UV.y < 0.5 ? 1.0 - UV.y : 1.0 - UV.y, 0.0, 1.0);
	float wind = sin(TIME * 1.7 + w.x * 0.4 + w.z * 0.3) + 0.5 * sin(TIME * 3.1 + w.z);
	VERTEX.x += wind * sway * h * h;
	VERTEX.z += wind * sway * 0.5 * h * h;
}

void fragment() {
	// Blade cutout from UV: several tapered blades per quad.
	float x = UV.x * 11.0;
	float blade = abs(fract(x) - 0.5) * 2.0;
	float height = 0.55 + 0.45 * hash13(vec3(floor(x), 1.0, 2.0));
	float y = 1.0 - UV.y;
	float shape = step(blade, (1.0 - y / height)) * step(y, height);
	if (shape < 0.5) {
		discard;
	}
	ALBEDO = mix(root, tip, y / height);
	BACKLIGHT = vec3(0.3, 0.45, 0.1);
	ROUGHNESS = 0.8;
}
