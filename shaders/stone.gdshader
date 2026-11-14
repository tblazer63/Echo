shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://shaders/noise.gdshaderinc"

global uniform vec3 echo_origin;
global uniform float echo_radius;
global uniform float echo_strength;

uniform vec3 stone_light : source_color = vec3(0.78, 0.77, 0.74);
uniform vec3 stone_dark : source_color = vec3(0.50, 0.52, 0.54);
uniform vec3 moss_color : source_color = vec3(0.36, 0.58, 0.20);
uniform float moss_amount : hint_range(0.0, 1.0) = 0.55;
uniform float displace = 0.0;
uniform float block_scale = 1.6;
uniform bool tiles = true;
uniform vec3 echo_color : source_color = vec3(0.25, 0.95, 1.0);
uniform float rune_glow = 0.0;

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (displace > 0.0) {
		float n = fbm3(w * 0.35) - 0.5;
		VERTEX += NORMAL * n * displace;
		w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	}
	wpos = w;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(wnorm);
	// Perf: one fbm + cheap single-octave lookups (runs full-screen on iGPUs).
	float big = fbm3(wpos * 0.18);
	float fine = vnoise(wpos * 1.7);
	vec3 col = mix(stone_dark, stone_light, smoothstep(0.25, 0.75, big * 0.7 + fine * 0.35));

	// Stone block seams (projected on the dominant axis).
	float seam = 0.0;
	if (tiles) {
		vec3 an = abs(n);
		vec2 uvp = an.y > 0.6 ? wpos.xz : (an.x > an.z ? wpos.zy : wpos.xy);
		vec2 b = uvp / block_scale;
		b.x += floor(b.y) * 0.5;
		vec2 f = abs(fract(b) - 0.5);
		seam = smoothstep(0.47, 0.5, max(f.x, f.y));
		col *= 1.0 - seam * 0.35;
	}
	// Cracks.
	float crack = smoothstep(0.018, 0.0, abs(vnoise(wpos * 0.9 + 7.0) * 0.6 + big * 0.4 - 0.5));
	col *= 1.0 - crack * 0.28;
	// Subtle ambient-occlusion-like darkening toward the bottom of faces.
	col *= 0.9 + 0.1 * smoothstep(-0.5, 0.6, n.y);

	// Moss on upward faces and drips down the sides.
	float up = smoothstep(0.35, 0.85, n.y);
	float mossn = vnoise(wpos * 0.6 + 3.0) * 0.6 + big * 0.4;
	float moss = up * smoothstep(1.0 - moss_amount, 1.05 - moss_amount * 0.6, mossn + fine * 0.2);
	float drip = smoothstep(0.62, 0.8, vnoise(vec3(wpos.x * 1.3, wpos.y * 0.25, wpos.z * 1.3))) * (1.0 - up) * moss_amount;
	moss = clamp(moss + drip * 0.8, 0.0, 1.0);
	vec3 mcol = moss_color * (0.75 + 0.5 * fine);
	col = mix(col, mcol, moss);

	ALBEDO = col;
	ROUGHNESS = mix(0.85, 0.95, moss);
	SPECULAR = 0.3;

	// Echo sweep: a cyan ring travels across all stone as the pulse expands.
	float d = distance(wpos, echo_origin);
	float ring = smoothstep(1.4, 0.0, abs(d - echo_radius)) * echo_strength;
	float inside = step(d, echo_radius) * echo_strength * 0.12 * (1.0 - smoothstep(0.0, 1.0, (echo_radius - d) / 8.0));
	EMISSION = echo_color * (ring * (1.2 + seam * 4.0) + inside * seam * 3.0);
	EMISSION += echo_color * rune_glow * seam * 2.5;
}
