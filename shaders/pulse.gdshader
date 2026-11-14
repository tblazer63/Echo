shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 color : source_color = vec3(0.25, 0.95, 1.0);
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

void fragment() {
	float fres = pow(1.0 - abs(dot(NORMAL, VIEW)), 3.0);
	// Concentric bands sweeping across the shell.
	float bands = 0.5 + 0.5 * sin(UV.y * 90.0 - TIME * 8.0);
	// Bright line where the shell intersects geometry.
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	vec4 view = INV_PROJECTION_MATRIX * ndc;
	float scene_z = -view.z / view.w;
	float frag_z = -VERTEX.z;
	float inter = smoothstep(0.35, 0.0, abs(scene_z - frag_z));
	float i = fres * (0.35 + bands * 0.25) + inter * 1.2;
	ALBEDO = color * i * fade;
	ALPHA = 1.0;
}
