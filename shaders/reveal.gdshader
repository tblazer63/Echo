shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_opaque, shadows_disabled;

// Holographic "revealed" look for echo-reactive structures.
uniform vec3 color : source_color = vec3(0.25, 0.95, 1.0);
uniform float reveal : hint_range(0.0, 1.0) = 0.0;
uniform float blink : hint_range(0.0, 1.0) = 0.0;
uniform float grid_size = 0.5;
uniform vec3 half_size = vec3(1.0);

varying vec3 lpos;

void vertex() {
	lpos = VERTEX;
}

void fragment() {
	vec3 p = lpos;
	// Grid lines on each face.
	vec3 g = abs(fract(p / grid_size) - 0.5);
	vec3 gx = smoothstep(vec3(0.45), vec3(0.5), g);
	vec3 tangent_mask = step(abs(p), half_size - vec3(0.02));
	gx *= tangent_mask;
	float grid = max(max(gx.x, gx.y), gx.z);
	// Box edges.
	vec3 e = smoothstep(half_size - vec3(0.06), half_size, abs(p));
	float edge = max(max(e.x * e.y, e.y * e.z), e.x * e.z);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	float scan = 0.5 + 0.5 * sin(TIME * 4.0 + (p.y + p.x) * 6.0);

	float flicker = 1.0 - blink * (0.5 + 0.5 * sign(sin(TIME * 22.0)));
	float a = reveal * flicker;
	vec3 c = color * (0.35 + grid * 1.2 + edge * 3.0 + fres * 0.8 + scan * 0.1);
	ALBEDO = c;
	EMISSION = color * (grid * 0.8 + edge * 2.5) * a;
	ALPHA = clamp(a * (0.34 + grid * 0.6 + edge + fres * 0.4), 0.0, 1.0);
}
