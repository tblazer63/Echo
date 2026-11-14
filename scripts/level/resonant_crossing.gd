class_name ResonantCrossing
extends Node3D
## Builds the playable level: start ruin -> hidden bridge -> relay islet ->
## locked gate -> timed hidden steps -> Signal Gate.

var relay: EchoRelay
var gate: LockedGate
var signal_gate: SignalGate
var sun: DirectionalLight3D
var env: Environment

const START := Vector3(0, 0, 0)
const ISLAND_A := Vector3(0, 0, -27)
const RELAY_ISLET := Vector3(-24, 0, -27)
const ISLAND_B := Vector3(0, 0, -53)
const ISLAND_C := Vector3(0, 4, -88)


func _ready() -> void:
	seed(7)
	_build_environment()
	_build_layout()
	_build_background()
	apply_quality(Game.quality)
	Game.quality_changed.connect(apply_quality)


func _build_environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.20, 0.47, 0.82)
	sm.sky_horizon_color = Color(0.68, 0.86, 0.96)
	sm.ground_bottom_color = Color(0.55, 0.74, 0.88)
	sm.ground_horizon_color = Color(0.70, 0.86, 0.95)
	sm.sun_angle_max = 25.0
	sm.sun_curve = 0.12
	sm.energy_multiplier = 1.1
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.95
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.set_glow_level(0, 0.0)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 0.8)
	env.set_glow_level(4, 0.5)
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.86, 0.96)
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.2
	env.fog_density = 0.0016
	env.fog_aerial_perspective = 0.2
	env.fog_sky_affect = 0.1
	env.fog_height = -14.0
	env.fog_height_density = 0.035
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.4
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.05
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140.0
	sun.directional_shadow_blend_splits = true
	sun.shadow_blur = 1.5
	sun.rotation = Vector3(deg_to_rad(-38), deg_to_rad(-140), 0)
	add_child(sun)


func _build_layout() -> void:
	# --- Start ruin ---
	Builders.island(self, START + Vector3(0, 0, 1), 7.5, 9.0)
	Builders.arch(self, START + Vector3(0, 0, 6.2), 4.0, 5.0, 0.0)
	Builders.pillar(self, START + Vector3(-5.2, 0, -2.5), 5.5, 1.1, true)
	Builders.pillar(self, START + Vector3(5.0, 0, -3.5), 7.0)
	Builders.pillar(self, START + Vector3(4.8, 0, 3.5), 3.0, 1.0, true)
	_pulse_marker(START + Vector3(0, 0.03, -4.0))
	_checkpoint(START + Vector3(0, 0, 3), 0.0)

	# Hidden bridge 1 (z -7 -> -19), straight.
	for i in 4:
		_echo_platform(Vector3(0, -0.2, -7.95 - i * 3.15), Vector3(2.8, 0.4, 3.2))
	_zone(Vector3(0, 1.5, -4), Vector3(8, 3, 4), func() -> void:
		Game.prompt("Press  Q  or  Right-Click  to emit an Echo", 6.0, "pulse_hint"))

	# --- Island A (hub) ---
	Builders.island(self, ISLAND_A, 8.0, 12.0)
	_checkpoint(ISLAND_A + Vector3(0, 0, 5.0), 0.0)
	Builders.pillar(self, ISLAND_A + Vector3(5.5, 0, 2.0), 6.0)
	Builders.pillar(self, ISLAND_A + Vector3(5.8, 0, -4.0), 4.0, 1.1, true)
	Builders.arch(self, ISLAND_A + Vector3(3.5, 0, -6.5), 3.0, 4.0, deg_to_rad(30), true)
	Builders.waterfall(self, ISLAND_A + Vector3(7.95, -0.4, 1.0), 3.0, 26.0, deg_to_rad(90))
	_zone(ISLAND_A + Vector3(0, 1.5, 4), Vector3(14, 3, 4), func() -> void:
		Game.set_objective("Resonate the cracked pillar to unlock the gate")
		Game.prompt("The cracked pillar echoes far... but your pulse can't reach it from here", 5.0, "relay_hint"))

	# Hidden steps west to the relay islet (x -9.5 -> -19).
	for i in 3:
		_echo_platform(ISLAND_A + Vector3(-9.7 - i * 3.3, -0.2, 0.0), Vector3(3.4, 0.4, 2.8))

	# --- Relay islet ---
	Builders.island(self, RELAY_ISLET, 4.2, 7.0)
	relay = EchoRelay.new()
	relay.position = RELAY_ISLET + Vector3(-1.2, 0, 0)
	add_child(relay)
	_checkpoint(RELAY_ISLET + Vector3(1.6, 0, 0.0), deg_to_rad(90))

	# --- Locked gate + solid bridge to island B ---
	Builders.walkway(self, ISLAND_A + Vector3(0, 0, -7.5), ISLAND_B + Vector3(0, 0, 5.5), 3.6)
	gate = LockedGate.new()
	gate.position = ISLAND_A + Vector3(0, 0, -9.5)
	add_child(gate)
	relay.target = gate
	relay.resonated.connect(func() -> void:
		Game.set_objective("Pass through the opened gate"))
	gate.unlocked.connect(func() -> void:
		Game.prompt("The gate answers your echo", 3.0))

	# --- Island B ---
	Builders.island(self, ISLAND_B, 6.0, 10.0)
	_checkpoint(ISLAND_B + Vector3(0, 0, 2.5), 0.0)
	Builders.pillar(self, ISLAND_B + Vector3(-4.0, 0, -2.0), 5.0, 1.0, true)
	Builders.pillar(self, ISLAND_B + Vector3(4.0, 0, -2.0), 6.5)
	Builders.waterfall(self, ISLAND_B + Vector3(-5.95, -0.4, 0.5), 2.5, 22.0, deg_to_rad(-90))
	_zone(ISLAND_B + Vector3(0, 1.5, 2), Vector3(12, 3, 4), func() -> void:
		Game.set_objective("Climb to the Signal Gate")
		Game.prompt("Hidden steps rise toward the gate. Pulse again mid-climb if needed.", 5.0, "climb_hint"))

	# Timed ascending hidden steps (B -> C).
	var steps := [
		Vector3(0, 0.6, -61.5), Vector3(2.2, 1.4, -65.5), Vector3(0, 2.2, -69.5),
		Vector3(-2.2, 3.0, -73.5), Vector3(0, 3.8, -77.0),
	]
	for p: Vector3 in steps:
		_echo_platform(p, Vector3(2.8, 0.4, 2.8))

	# --- Island C: Signal Gate ---
	Builders.island(self, ISLAND_C, 9.5, 14.0)
	_checkpoint(ISLAND_C + Vector3(0, 0, 7.0), 0.0)
	signal_gate = SignalGate.new()
	signal_gate.position = ISLAND_C + Vector3(0, 0, -5.0)
	add_child(signal_gate)
	Builders.pillar(self, ISLAND_C + Vector3(-7.0, 0, 2.0), 8.0)
	Builders.pillar(self, ISLAND_C + Vector3(7.0, 0, 2.0), 8.0)
	Builders.pillar(self, ISLAND_C + Vector3(-6.0, 0, 6.5), 4.5, 1.0, true)
	Builders.waterfall(self, ISLAND_C + Vector3(9.45, -0.4, -2.0), 4.0, 30.0, deg_to_rad(90))
	Builders.waterfall(self, ISLAND_C + Vector3(-9.45, -0.4, -4.0), 3.0, 28.0, deg_to_rad(-90))

	# Holographic hints of the hidden world near the path.
	_holo_arch(Vector3(-11, 0, -14), deg_to_rad(70))
	_holo_arch(Vector3(12, 1, -40), deg_to_rad(-60))
	_holo_arch(Vector3(-10, 2, -66), deg_to_rad(80))


func _build_background() -> void:
	# Sea of clouds below the ruins.
	var clouds := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(3000, 3000)
	clouds.mesh = pm
	var cm := ShaderMaterial.new()
	cm.shader = preload("res://shaders/clouds.gdshader")
	clouds.material_override = cm
	clouds.position = Vector3(0, -38, -60)
	clouds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(clouds)

	# Distant floating islands with ruins (no grass/vines/shadows: perf).
	var bg := Node3D.new()
	add_child(bg)
	for i in 28:
		var a := randf_range(-PI, PI)
		var d := randf_range(70.0, 260.0)
		var center := Vector3(sin(a) * d, randf_range(-18.0, 35.0), -60.0 + cos(a) * d)
		var r := randf_range(4.0, 16.0)
		var isl := Builders.island(bg, center, r, r * randf_range(1.2, 2.2), false, false)
		if randf() < 0.7:
			for k in randi_range(1, 3):
				var off := Vector3(randf_range(-r, r) * 0.5, 0, randf_range(-r, r) * 0.5)
				Builders.pillar(isl, off, randf_range(4.0, 14.0), randf_range(1.0, 2.2), randf() < 0.5, false)
		if randf() < 0.3:
			Builders.arch(isl, Vector3.ZERO, r * 0.6, r * 0.6, randf() * TAU, false)
		if randf() < 0.35 and d < 180.0:
			Builders.waterfall(bg, center + Vector3(r * 0.97, -0.3, 0), r * 0.3, 40.0, deg_to_rad(90))
	_no_shadows(bg)

	# Tall spires behind the Signal Gate.
	for i in 9:
		var p := Vector3(randf_range(-70, 70), -30, randf_range(-170, -260))
		var sp := MeshInstance3D.new()
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var cyl := CylinderMesh.new()
		var w := randf_range(4.0, 9.0)
		cyl.top_radius = w * 0.5
		cyl.bottom_radius = w
		cyl.height = randf_range(60.0, 130.0)
		cyl.radial_segments = 6
		cyl.rings = 8
		sp.mesh = cyl
		sp.material_override = Builders.stone_material(0.3)
		sp.position = p + Vector3.UP * cyl.height * 0.5
		add_child(sp)

	# Huge faraway floating masses for depth (fog fades them into the sky).
	for i in 8:
		var a := deg_to_rad(-120.0 + i * 34.0 + randf_range(-8, 8))
		var c := Vector3(sin(a) * 520.0, randf_range(10.0, 70.0), -60.0 - cos(a) * 520.0)
		var r := randf_range(35.0, 60.0)
		Builders.island(self, c, r, r * 1.6, false, false)


func _no_shadows(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_no_shadows(c)


## Applies a graphics preset. "performance" targets integrated GPUs.
func apply_quality(q: String) -> void:
	var high := q == "quality"
	env.ssao_enabled = high
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if high else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 120.0 if high else 55.0
	var vp := get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
	vp.scaling_3d_scale = 1.0 if high else 0.67
	vp.msaa_3d = Viewport.MSAA_2X if high else Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED if high else Viewport.SCREEN_SPACE_AA_FXAA
	RenderingServer.directional_soft_shadow_filter_set_quality(
		RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM if high else RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW)
	RenderingServer.directional_shadow_atlas_set_size(4096 if high else 2048, true)


func _echo_platform(pos: Vector3, size: Vector3) -> EchoPlatform:
	var p := EchoPlatform.new()
	p.size = size
	p.position = pos
	add_child(p)
	return p


func _checkpoint(pos: Vector3, yaw: float) -> void:
	var c := Checkpoint.new()
	c.yaw = yaw
	c.position = pos
	add_child(c)


func _zone(pos: Vector3, size: Vector3, cb: Callable) -> void:
	var z := TriggerZone.new()
	z.size = size
	z.callback = cb
	z.position = pos
	add_child(z)


func _pulse_marker(pos: Vector3) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Game.ECHO_CYAN
	mat.emission_enabled = true
	mat.emission = Game.ECHO_CYAN
	mat.emission_energy_multiplier = 2.0
	for r in [0.35, 0.8, 1.3]:
		var ring := MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = r
		t.outer_radius = r + 0.07
		ring.mesh = t
		ring.scale.y = 0.15
		ring.material_override = mat
		ring.position = pos
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)


func _holo_arch(pos: Vector3, rot_y: float) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = rot_y
	add_child(root)
	var parts := [
		[Vector3(1, 6, 1), Vector3(-2.5, 3, 0)],
		[Vector3(1, 6, 1), Vector3(2.5, 3, 0)],
		[Vector3(7, 1, 1.2), Vector3(0, 6.5, 0)],
		[Vector3(7, 0.4, 3), Vector3(0, -0.2, 0)],
	]
	for p in parts:
		var h := HoloDecor.new()
		var b := BoxMesh.new()
		b.size = p[0]
		h.mesh = b
		h.half_size = p[0] * 0.5
		h.position = p[1]
		root.add_child(h)
