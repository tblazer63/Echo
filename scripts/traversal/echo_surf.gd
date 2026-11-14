class_name EchoSurf
extends Node3D
## Echo Surfing: a flowing resonance track from a generator to a landing pad.
## Once activated, the player boards with E, rides the wave automatically and
## steers left/right to collect rings. Completes without any input.

signal boarded
signal ring_collected(count: int, total: int)
signal finished(collected: int, total: int)

const SURF_SHADER := preload("res://shaders/surf_wave.gdshader")
const TRACK_WIDTH := 4.5
const START_SPEED := 8.0
const MAX_SPEED := 22.0
const MAX_LATERAL := 2.5
const FEET_HEIGHT := 0.35
const RING_RADIUS := 1.8
const DORMANT_ENERGY := 0.15
const ACTIVE_ENERGY := 1.0
const RIDE_ENERGY := 1.6
const DIM := Color(0.38, 0.4, 0.43)

## World-space control points: first = generator (island B), last = landing (island D).
var points: PackedVector3Array = PackedVector3Array()
var ring_count := 8
var enabled := false
var riding := false
var collected := 0

var path: Path3D
var curve: Curve3D
var _length := 0.0
var _track_mat: ShaderMaterial
var _energy := DORMANT_ENERGY
var _gen_mat: StandardMaterial3D
var _gen_ring: MeshInstance3D
var _gen_core: MeshInstance3D
var _core_y := 0.0
var _gen_light: OmniLight3D
var _pad_mat: StandardMaterial3D
var _beacon: MeshInstance3D
var _zone: Area3D
var _player_near := false
var _prompt_cd := 0.0
var _rings: Array[MeshInstance3D] = []
var _ring_pos: PackedVector3Array = PackedVector3Array()
var _ring_live: Array[bool] = []
var _spray: CPUParticles3D
var _rider: Player
var _dist := 0.0
var _speed := 0.0
var _lat := 0.0
var _lat_vel := 0.0
var _t := 0.0


func _ready() -> void:
	if points.size() < 2:
		push_warning("EchoSurf needs at least 2 points")
		return
	_build_curve()
	_build_track()
	_build_generator()
	_build_rings()
	_build_landing()
	_build_spray()
	Game.player_respawned.connect(abort)


# ---------------------------------------------------------------- building

func _build_curve() -> void:
	path = Path3D.new()
	curve = Curve3D.new()
	curve.bake_interval = 0.5
	var inv := global_transform.affine_inverse()
	var local := PackedVector3Array()
	for p: Vector3 in points:
		local.append(inv * p)
	var n := local.size()
	for i in n:
		var p := local[i]
		var prev := local[maxi(i - 1, 0)]
		var nxt := local[mini(i + 1, n - 1)]
		var dir := (nxt - prev).normalized()
		curve.add_point(p, -dir * p.distance_to(prev) * 0.25, dir * p.distance_to(nxt) * 0.25)
	path.curve = curve
	add_child(path)
	_length = curve.get_baked_length()


func _sample(d: float) -> Vector3:
	return curve.sample_baked(clampf(d, 0.0, _length), true)


func _tangent(d: float) -> Vector3:
	var t := _sample(d + 0.6) - _sample(d - 0.6)
	if t.length_squared() < 0.0001:
		return Vector3.FORWARD
	return t.normalized()


## Horizontal right vector for a tangent (keeps the track level side to side).
func _right(t: Vector3) -> Vector3:
	var f := Vector3(t.x, 0.0, t.z)
	if f.length_squared() < 0.0001:
		return Vector3.RIGHT
	return f.normalized().cross(Vector3.UP)


func _glow_mat(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


func _mesh(mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	add_child(mi)
	return mi


func _build_track() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := maxi(int(_length / 0.5), 2)
	var hw := TRACK_WIDTH * 0.5
	for i in steps + 1:
		var d := _length * float(i) / float(steps)
		var p := _sample(d) + Vector3.UP * 0.06
		var r := _right(_tangent(d))
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(0.0, d))
		st.add_vertex(p - r * hw)
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(1.0, d))
		st.add_vertex(p + r * hw)
	for i in steps:
		var a := i * 2
		st.add_index(a)
		st.add_index(a + 1)
		st.add_index(a + 2)
		st.add_index(a + 1)
		st.add_index(a + 3)
		st.add_index(a + 2)
	_track_mat = ShaderMaterial.new()
	_track_mat.shader = SURF_SHADER
	_track_mat.set_shader_parameter("color", Game.ECHO_CYAN)
	_track_mat.set_shader_parameter("energy", _energy)
	_track_mat.set_shader_parameter("track_length", _length)
	_mesh(st.commit(), _track_mat, Vector3.ZERO)


func _build_generator() -> void:
	var p0 := _sample(0.0)
	var t0 := _tangent(0.0)
	var back := Vector3(t0.x, 0.0, t0.z)
	back = back.normalized() if back.length_squared() > 0.0001 else Vector3.FORWARD
	var g := p0 - back * 3.2
	var stone := Builders.stone_material(0.4)
	Builders._box(self, Vector3(2.4, 0.3, 2.4), g + Vector3(0, 0.05, 0), stone)
	Builders._box(self, Vector3(1.4, 1.5, 1.4), g + Vector3(0, 0.75, 0), stone, true)
	_gen_mat = _glow_mat(DIM, 0.15)
	var core := SphereMesh.new()
	core.radius = 0.38
	core.height = 0.76
	core.radial_segments = 12
	core.rings = 6
	_core_y = 2.25
	_gen_core = _mesh(core, _gen_mat, g + Vector3(0, _core_y, 0))
	var tor := TorusMesh.new()
	tor.inner_radius = 0.6
	tor.outer_radius = 0.74
	tor.rings = 24
	tor.ring_segments = 8
	_gen_ring = _mesh(tor, _gen_mat, g + Vector3(0, _core_y, 0))
	_gen_ring.rotation.x = deg_to_rad(70)
	_gen_light = OmniLight3D.new()
	_gen_light.light_color = Game.ECHO_CYAN
	_gen_light.omni_range = 9.0
	_gen_light.light_energy = 0.0
	_gen_light.shadow_enabled = false
	_gen_light.position = g + Vector3(0, 2.6, 0)
	add_child(_gen_light)
	# Launch pad ring on the floor at the start of the track.
	_pad_mat = _glow_mat(Game.ECHO_CYAN, 0.5)
	var pad := TorusMesh.new()
	pad.inner_radius = 1.35
	pad.outer_radius = 1.6
	pad.rings = 32
	pad.ring_segments = 6
	var pad_mi := _mesh(pad, _pad_mat, p0 + Vector3.UP * 0.05)
	pad_mi.scale = Vector3(1, 0.4, 1)
	# Boarding zone.
	_zone = Area3D.new()
	_zone.collision_layer = 0
	_zone.collision_mask = 2
	var col := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 3.0
	col.shape = sph
	_zone.add_child(col)
	_zone.position = p0 + Vector3.UP
	add_child(_zone)
	_zone.body_entered.connect(_on_zone_entered)
	_zone.body_exited.connect(_on_zone_exited)


func _on_zone_entered(b: Node3D) -> void:
	if b is Player:
		_player_near = true


func _on_zone_exited(b: Node3D) -> void:
	if b is Player:
		_player_near = false


func _build_rings() -> void:
	var tor := TorusMesh.new()
	tor.inner_radius = 0.9
	tor.outer_radius = 1.1
	tor.rings = 28
	tor.ring_segments = 8
	var mat := _glow_mat(Color(1.0, 0.82, 0.38), 3.0)
	mat.rim_enabled = true
	mat.rim = 1.0
	mat.rim_tint = 0.0
	for i in ring_count:
		var f := 0.5 if ring_count == 1 else 0.15 + 0.75 * float(i) / float(ring_count - 1)
		var d := _length * f
		var t := _tangent(d)
		var r := _right(t)
		var side := -1.0 if i % 2 == 0 else 1.0
		var lat := side * (1.2 + 0.8 * float((i >> 1) % 2))
		var pos := _sample(d) + r * lat + Vector3.UP * 1.6
		var m := _mesh(tor, mat, Vector3.ZERO)
		m.transform = Transform3D(Basis(r, t, r.cross(t)), pos)
		m.visible = false
		_rings.append(m)
		_ring_pos.append(pos)
		_ring_live.append(false)


func _build_landing() -> void:
	var pe := _sample(_length)
	var tor := TorusMesh.new()
	tor.inner_radius = 1.6
	tor.outer_radius = 2.0
	tor.rings = 32
	tor.ring_segments = 6
	var land := _mesh(tor, _pad_mat, pe + Vector3.UP * 0.05)
	land.scale = Vector3(1, 0.35, 1)
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.12
	cyl.bottom_radius = 0.2
	cyl.height = 14.0
	cyl.radial_segments = 8
	cyl.rings = 1
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bm.albedo_color = Color(0.3, 0.95, 1.0, 0.45)
	_beacon = _mesh(cyl, bm, pe + Vector3.UP * 7.0)
	_beacon.visible = false


func _build_spray() -> void:
	_spray = CPUParticles3D.new()
	_spray.amount = 24
	_spray.lifetime = 0.5
	_spray.emitting = false
	_spray.local_coords = false
	_spray.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_spray.emission_box_extents = Vector3(0.5, 0.05, 0.3)
	_spray.direction = Vector3(0, 0.7, 1)
	_spray.spread = 35.0
	_spray.initial_velocity_min = 3.0
	_spray.initial_velocity_max = 6.0
	_spray.gravity = Vector3(0, -8, 0)
	_spray.scale_amount_min = 0.6
	_spray.scale_amount_max = 1.3
	var q := QuadMesh.new()
	q.size = Vector2(0.14, 0.14)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(0.45, 1.0, 1.0, 0.9)
	q.material = m
	_spray.mesh = q
	_spray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_spray)


# ---------------------------------------------------------------- API

func activate() -> void:
	if enabled:
		return
	enabled = true
	Sfx.play("relay")
	Game.prompt("The Surf Generator hums to life. Press E to ride the Echo Wave", 5.0)
	_prompt_cd = 5.0
	_energy = maxf(_energy, 0.5)
	if _beacon:
		_beacon.visible = true
	for i in _rings.size():
		_ring_live[i] = true
		var m := _rings[i]
		m.visible = true
		m.scale = Vector3.ONE * 0.01
		var tw := m.create_tween()
		tw.tween_interval(0.3 + 0.15 * i)
		tw.tween_property(m, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func is_riding() -> bool:
	return riding


func board(player: Player) -> void:
	if riding or curve == null or not is_instance_valid(player):
		return
	_rider = player
	riding = true
	_dist = 0.0
	_speed = START_SPEED
	var p0 := _sample(0.0)
	_lat = clampf((player.global_position - to_global(p0)).dot(global_basis * _right(_tangent(0.0))), -MAX_LATERAL, MAX_LATERAL)
	_lat_vel = 0.0
	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	_spray.global_position = player.global_position
	_spray.emitting = true
	Sfx.play("surf_start")
	boarded.emit()


## Ends a ride in place without emitting `finished` (e.g. player death/respawn).
func abort() -> void:
	if not riding:
		return
	riding = false
	_spray.emitting = false
	if is_instance_valid(_rider):
		_rider.camera.rotation.z = 0.0
		_rider.set_physics_process(true)
	_rider = null


# ---------------------------------------------------------------- runtime

func _process(delta: float) -> void:
	if curve == null:
		return
	_t += delta
	var target := RIDE_ENERGY if riding else (ACTIVE_ENERGY if enabled else DORMANT_ENERGY)
	_energy = lerpf(_energy, target, clampf(delta * 1.5, 0.0, 1.0))
	_track_mat.set_shader_parameter("energy", _energy)
	_track_mat.set_shader_parameter("flow_speed", 1.6 if riding else 1.0)
	var k := clampf((_energy - DORMANT_ENERGY) / (ACTIVE_ENERGY - DORMANT_ENERGY), 0.0, 1.0)
	var pulse := 0.85 + 0.15 * sin(_t * 3.0)
	_gen_mat.albedo_color = DIM.lerp(Game.ECHO_CYAN, k)
	_gen_mat.emission = DIM.lerp(Game.ECHO_CYAN, k)
	_gen_mat.emission_energy_multiplier = lerpf(0.15, 4.0, k) * pulse
	_gen_light.light_energy = k * 2.0 * pulse
	_pad_mat.emission_energy_multiplier = 0.3 + _energy * 2.5
	# Spin the tilted ring around the world vertical (spinning a torus about its
	# own axis would be invisible).
	_gen_ring.rotate_y(delta * lerpf(0.3, 3.0, k))
	_gen_core.position.y = _gen_ring.position.y + sin(_t * 2.0) * 0.08 * (0.3 + k)

	if enabled and _player_near and not riding:
		_prompt_cd -= delta
		if _prompt_cd <= 0.0:
			_prompt_cd = 2.0
			Game.prompt("Press  E  to ride the Echo Wave", 1.5, "")
		if Input.is_action_just_pressed("interact"):
			var p := get_tree().get_first_node_in_group("player") as Player
			if p:
				board(p)


func _physics_process(delta: float) -> void:
	if not riding:
		return
	if not is_instance_valid(_rider):
		riding = false
		_spray.emitting = false
		return
	_speed = lerpf(_speed, MAX_SPEED, clampf(delta * 0.9, 0.0, 1.0))
	_dist += _speed * delta
	if _dist >= _length:
		_dismount()
		return
	var t := _tangent(_dist)
	var r := _right(t)
	var steer := Input.get_axis("move_left", "move_right") if _rider.input_enabled else 0.0
	_lat_vel = lerpf(_lat_vel, steer * 7.0, clampf(delta * 6.0, 0.0, 1.0))
	var prev := _lat
	_lat = clampf(_lat + _lat_vel * delta, -MAX_LATERAL, MAX_LATERAL)
	if _length - _dist < 8.0:
		_lat = lerpf(_lat, 0.0, clampf(delta * 4.0, 0.0, 1.0))
	var eff := (_lat - prev) / maxf(delta, 0.0001)

	var feet_local := _sample(_dist) + r * _lat + Vector3.UP * FEET_HEIGHT
	var feet := to_global(feet_local)
	_rider.global_position = feet
	var gt := global_basis * t
	var yaw := atan2(-gt.x, -gt.z)
	_rider.rotation.y = lerp_angle(_rider.rotation.y, yaw, clampf(delta * 5.0, 0.0, 1.0))
	var roll := clampf(-eff * 0.035, -0.22, 0.22)
	_rider.camera.rotation.z = lerpf(_rider.camera.rotation.z, roll, clampf(delta * 6.0, 0.0, 1.0))
	_spray.global_transform = Transform3D(_rider.global_basis.orthonormalized(), feet)

	var chest := feet_local + Vector3.UP
	for i in _rings.size():
		if _ring_live[i] and chest.distance_to(_ring_pos[i]) < RING_RADIUS:
			_collect(i)


func _collect(i: int) -> void:
	_ring_live[i] = false
	collected += 1
	var m := _rings[i]
	var tw := m.create_tween()
	tw.tween_property(m, "scale", Vector3.ONE * 1.7, 0.12)
	tw.tween_property(m, "scale", Vector3.ONE * 0.01, 0.18)
	tw.tween_callback(m.hide)
	Sfx.play("ring", -2.0, 1.0 + 0.06 * collected)
	ring_collected.emit(collected, _rings.size())


func _dismount() -> void:
	var r := _rider
	riding = false
	_rider = null
	_spray.emitting = false
	var t := _tangent(_length)
	var flat := Vector3(t.x, 0.0, t.z)
	flat = flat.normalized() if flat.length_squared() > 0.0001 else Vector3.FORWARD
	if is_instance_valid(r):
		r.global_position = to_global(_sample(_length)) + Vector3.UP * 0.3
		r.velocity = (global_basis * flat).normalized() * 6.0
		r.camera.rotation.z = 0.0
		r.set_physics_process(true)
	var total := _rings.size()
	finished.emit(collected, total)
	Game.prompt("Rings collected: %d / %d" % [collected, total], 4.0)
