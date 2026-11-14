shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

// Flowing energy track for Echo Surfing. UV.x = across (0..1), UV.y = metres along.
uniform vec3 color : source_color = vec3(0.25, 0.95, 1.0);
uniform vec3 core_color : source_color = vec3(0.75, 1.0, 1.0);
uniform float energy : hint_range(0.0, 2.0) = 0.15;
uniform float track_length = 100.0;
uniform float flow_speed = 1.0;

void fragment() {
	float x = UV.x * 2.0 - 1.0;
	float ax = abs(x);
	float d = UV.y;
	float t = TIME * flow_speed;
	// Bright rails at both edges, soft fade-out right at the border.
	float edge = smoothstep(0.72, 0.93, ax) * (1.0 - smoothstep(0.95, 1.0, ax));
	float center = 1.0 - smoothstep(0.0, 0.85, ax);
	// Chevron bands flowing forward along the track.
	float chev = pow(0.5 + 0.5 * sin((d - ax * 1.6) * 0.9 - t * 9.0), 8.0);
	// Slow broad ripples + fine streaks.
	float ripple = 0.5 + 0.5 * sin(d * 0.25 - t * 3.0 + x * 2.5);
	float streak = pow(0.5 + 0.5 * sin(x * 18.0 + sin(d * 0.3 + t) * 2.0), 12.0);
	float rail_pulse = 0.7 + 0.3 * sin(d * 0.6 - t * 6.0);
	// Fade in/out at the ends of the track.
	float ends = smoothstep(0.0, 3.0, d) * (1.0 - smoothstep(track_length - 3.0, track_length, d));
	float dormant = 1.0 - smoothstep(0.2, 0.6, energy);
	// When dormant, only a faint dotted outline remains.
	float dots = step(0.5, fract(d * 0.5));
	float body = center * (0.12 + chev * 0.9 + ripple * 0.15 + streak * 0.25);
	float rails = edge * rail_pulse * 1.6;
	float lum = mix(body + rails, rails * dots * 0.8 + center * 0.03, dormant);
	vec3 c = mix(color, core_color, clamp(chev * center + edge * 0.3, 0.0, 1.0));
	float e = clamp(energy, 0.0, 2.0);
	// Additive blend: brightness alone controls visibility.
	ALBEDO = c * lum * e * ends;
}
