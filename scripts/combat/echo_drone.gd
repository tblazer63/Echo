class_name EchoDrone
extends CharacterBody3D
## Dissonance drone. Patrols around its home, harasses the player with magenta
## orbs, gets stunned and has its core exposed by echoes. Leashed to home.

signal defeated(drone: EchoDrone)

enum State { PATROL, ALERT, STUNNED, DEFEATED, FRIEND }

const DISSONANCE := Color(0.95, 0.25, 0.85)
const TELEGRAPH := 0.6
const STUN_TIME := 1.5
const EXPOSE_TIME := 5.0

@export var patrol_radius := 4.0
@export var detect_range := 18.0
@export var leash := 16.0
@export var max_hp := 60.0
@export var attack_interval := 2.4

var hp := 60.0
var home := Vector3.ZERO
var state: State = State.PATROL
var exposed_timer := 0.0

var _home_set := false
var _t := 0.0
var _stun_t := 0.0
var _attack_t := 1.5
var _tele_t := -1.0
var _aggro_t := 0.0
var _strafe := 1.0
var _strafe_t := 3.0
var _flash := 0.0
var _defeat_emitted := false
var _orbit_center := Vector3.ZERO
var _orbit_r := 7.0
var _orbit_h := 6.0
var _orbit_phase := 0.0
var _player: Node3D
var _sink_tween: Tween
var _punch_tween: Tween

var _col: CollisionShape3D
var _visual: Node3D
var _ring: MeshInstance3D
var _eye: MeshInstance3D
var _core: MeshInstance3D
var _bar_root: Node3D
var _bar_fill: MeshInstance3D
var _body_mat: StandardMaterial3D
var _eye_mat: StandardMaterial3D
var _ring_mat: StandardMaterial3D
var _core_mat: StandardMaterial3D


func _ready() -> void:
	add_to_group("drone")
	add_to_group("echo_reactive")
	collision_layer = 8
	collision_mask = 1
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	hp = max_hp
	if not _home_set:
		home = global_position
	_t = randf() * TAU
	_strafe = 1.0 if randf() < 0.5 else -1.0
	_col = CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.6
	_col.shape = sh
	add_child(_col)
	_build_visual()
	_update_bar()


## Optional: set the patrol/leash centre explicitly.
func set_home(p: Vector3) -> void:
	home = p
	_home_set = true


func echo_point() -> Vector3:
	return global_position


func is_defeated() -> bool:
	return state == State.DEFEATED or state == State.FRIEND


func is_exposed() -> bool:
	return exposed_timer > 0.0


# ------------------------------------------------------------------ behaviour

func _physics_process(delta: float) -> void:
	if not _home_set:
		# Position may be assigned after add_child: the first tick is authoritative.
		home = global_position
		_home_set = true
	_t += delta
	exposed_timer = maxf(exposed_timer - delta, 0.0)
	_aggro_t = maxf(_aggro_t - delta, 0.0)
	match state:
		State.PATROL:
			_do_patrol(delta)
		State.ALERT:
			_do_alert(delta)
		State.STUNNED:
			_do_stunned(delta)
		State.FRIEND:
			_do_friend(delta)
		_:
			pass


func _get_player() -> Node3D:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	return _player


func _player_in_range(mult: float) -> bool:
	var p := _get_player()
	if p == null:
		return false
	var pp := p.global_position
	return global_position.distance_to(pp) <= detect_range * mult and pp.distance_to(home) <= leash + 10.0


func _steer(target: Vector3, max_speed: float, delta: float) -> void:
	var desired := ((target - global_position) * 1.6).limit_length(max_speed)
	velocity = velocity.lerp(desired, clampf(delta * 3.0, 0.0, 1.0))
	move_and_slide()


func _face(target: Vector3, delta: float) -> void:
	var d := target - global_position
	d.y = 0.0
	if d.length() < 0.05:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-d.x, -d.z), clampf(delta * 6.0, 0.0, 1.0))


func _do_patrol(delta: float) -> void:
	var a := _t * 0.45
	var target := home + Vector3(cos(a) * patrol_radius, sin(_t * 1.7) * 0.35, sin(a) * patrol_radius)
	_steer(target, 3.5, delta)
	if velocity.length() > 0.3:
		_face(global_position + velocity, delta)
	if _player_in_range(1.0):
		_enter_alert()


func _enter_alert() -> void:
	state = State.ALERT
	_attack_t = maxf(_attack_t, 1.0)
	_tele_t = -1.0


func _do_alert(delta: float) -> void:
	var p := _get_player()
	if p == null or (not _player_in_range(1.3) and _aggro_t <= 0.0) or p.global_position.distance_to(home) > leash + 10.0:
		state = State.PATROL
		_tele_t = -1.0
		return
	var pp := p.global_position
	_strafe_t -= delta
	if _strafe_t <= 0.0:
		_strafe_t = randf_range(2.5, 5.0)
		_strafe = -_strafe
	var flat := global_position - pp
	flat.y = 0.0
	if flat.length() < 0.1:
		flat = Vector3.FORWARD
	var dir := flat.normalized().rotated(Vector3.UP, 0.22 * _strafe)
	var target := pp + dir * 9.0
	target.y = pp.y + 3.0 + sin(_t * 1.9) * 0.3
	var off := target - home
	if off.length() > leash:
		target = home + off.normalized() * leash
	_steer(target, 4.5, delta)
	_face(pp, delta)

	if Game.won:
		_tele_t = -1.0
		return
	if _tele_t >= 0.0:
		_tele_t += delta
		if _tele_t >= TELEGRAPH:
			_tele_t = -1.0
			_attack_t = attack_interval
			_shoot(pp + Vector3(0, 1.2, 0))
	else:
		_attack_t -= delta
		if _attack_t <= 0.0:
			if _has_los(pp + Vector3(0, 1.2, 0)):
				_tele_t = 0.0
				Sfx.play("drone_charge", -6.0)
			else:
				_attack_t = 0.5


func _has_los(to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(_eye.global_position, to, 1)
	q.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _shoot(target: Vector3) -> void:
	var parent := get_tree().current_scene
	if parent == null:
		parent = get_parent()
	EnemyProjectile.spawn(parent, _eye.global_position, target)
	Sfx.play("drone_shot", -4.0, randf_range(0.95, 1.05))
	velocity += global_basis.z * 1.5


func _do_stunned(delta: float) -> void:
	_stun_t -= delta
	velocity = velocity.lerp(Vector3.ZERO, clampf(delta * 3.0, 0.0, 1.0))
	move_and_slide()
	if _stun_t <= 0.0:
		_attack_t = attack_interval * 0.6
		# Still aggro'd (echo / recent hit): go alert; _do_alert enforces the leash.
		if _player_in_range(1.3) or _aggro_t > 0.0:
			_enter_alert()
		else:
			state = State.PATROL


func _do_friend(delta: float) -> void:
	_orbit_phase += delta * 0.35
	var target := _orbit_center + Vector3(cos(_orbit_phase) * _orbit_r, _orbit_h + sin(_t * 1.3) * 0.4, sin(_orbit_phase) * _orbit_r)
	var prev := global_position
	global_position = global_position.lerp(target, clampf(delta * 1.2, 0.0, 1.0))
	_face(global_position + (global_position - prev) * 10.0, delta)


# ------------------------------------------------------------------ interface

func on_echo(_origin: Vector3, _wave: Node) -> void:
	if is_defeated():
		return
	state = State.STUNNED
	_stun_t = STUN_TIME
	_tele_t = -1.0
	exposed_timer = EXPOSE_TIME
	_aggro_t = 6.0
	Game.prompt("Your echo exposes the drone's core — strike now!", 3.0, "core_hint")


func take_damage(amount: float, _hit_pos: Vector3) -> void:
	if is_defeated():
		return
	hp -= amount * (2.0 if exposed_timer > 0.0 else 1.0)
	_flash = 1.0
	_aggro_t = 6.0
	if _punch_tween != null and _punch_tween.is_valid():
		_punch_tween.kill()
	_punch_tween = _visual.create_tween()
	_punch_tween.tween_property(_visual, "scale", Vector3.ONE * 1.25, 0.05)
	_punch_tween.tween_property(_visual, "scale", Vector3.ONE, 0.15)
	if state == State.PATROL:
		_enter_alert()
	_update_bar()
	if hp <= 0.0:
		_defeat()


func _defeat() -> void:
	state = State.DEFEATED
	hp = 0.0
	exposed_timer = 0.0
	_tele_t = -1.0
	velocity = Vector3.ZERO
	Sfx.play("drone_down", -2.0)
	collision_layer = 0
	_col.set_deferred("disabled", true)
	_body_mat.albedo_color = Color(0.36, 0.36, 0.38)
	_body_mat.metallic = 0.2
	_body_mat.roughness = 0.85
	_eye_mat.emission_energy_multiplier = 0.0
	_eye_mat.albedo_color = Color(0.15, 0.15, 0.16)
	_ring_mat.emission_energy_multiplier = 0.0
	_ring_mat.albedo_color = Color(0.3, 0.3, 0.32)
	_core_mat.emission_energy_multiplier = 0.0
	_core.scale = Vector3.ONE
	_eye.scale = Vector3.ONE
	# _process stops updating these once DEFEATED, so clear them here.
	_flash = 0.0
	_body_mat.emission = Color.BLACK
	_update_bar()
	_sink_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_sink_tween.tween_property(self, "global_position", global_position + Vector3.DOWN * 1.2, 1.4)
	_sink_tween.tween_property(_visual, "rotation", Vector3(0.45, 0.0, 0.3), 1.4)
	if not _defeat_emitted:
		_defeat_emitted = true
		defeated.emit(self)


## Restore an undefeated drone (e.g. after the player respawns).
func reset_drone() -> void:
	if is_defeated():
		return
	hp = max_hp
	exposed_timer = 0.0
	_stun_t = 0.0
	_tele_t = -1.0
	_aggro_t = 0.0
	_attack_t = 1.5
	velocity = Vector3.ZERO
	global_position = home
	state = State.PATROL
	_update_bar()


## Turn a defeated drone into a friendly cyan satellite orbiting `center`.
func befriend(center: Vector3) -> void:
	if state != State.DEFEATED:
		return
	state = State.FRIEND
	_orbit_center = center
	_orbit_r = randf_range(6.0, 8.0)
	_orbit_h = randf_range(5.0, 8.0)
	_orbit_phase = randf() * TAU
	if _sink_tween != null and _sink_tween.is_valid():
		_sink_tween.kill()
	var cyan: Color = Game.ECHO_CYAN
	_body_mat.albedo_color = Color(0.55, 0.62, 0.68)
	_body_mat.metallic = 0.7
	_body_mat.roughness = 0.35
	_eye_mat.albedo_color = cyan
	_eye_mat.emission = cyan
	_eye_mat.emission_energy_multiplier = 3.0
	_ring_mat.albedo_color = cyan
	_ring_mat.emission = cyan
	_ring_mat.emission_energy_multiplier = 2.0
	_core_mat.emission = cyan
	_core_mat.emission_energy_multiplier = 1.5
	var tw := create_tween()
	tw.tween_property(_visual, "rotation", Vector3.ZERO, 0.8)


# ------------------------------------------------------------------ visuals

func _process(delta: float) -> void:
	_ring.rotation.y += delta * (0.6 if state == State.DEFEATED else 2.4)
	if state == State.DEFEATED:
		return
	_visual.position.y = sin(_t * 2.2) * 0.08
	if state == State.STUNNED:
		_visual.rotation = Vector3(sin(_t * 13.0) * 0.3, wrapf(_visual.rotation.y + delta * 9.0, -PI, PI), sin(_t * 17.0) * 0.3)
	else:
		_visual.rotation = _visual.rotation.lerp(Vector3.ZERO, clampf(delta * 5.0, 0.0, 1.0))
	if state == State.FRIEND:
		return

	var eye_e := 2.0
	var eye_s := 1.0
	if _tele_t >= 0.0:
		var k := _tele_t / TELEGRAPH
		eye_e = lerpf(3.0, 14.0, k) + sin(_t * 60.0) * 1.5
		eye_s = 1.0 + 0.6 * k
	elif state == State.STUNNED:
		eye_e = 0.4 + absf(sin(_t * 25.0)) * 1.5
	_eye_mat.emission_energy_multiplier = eye_e
	_eye.scale = Vector3.ONE * eye_s

	if exposed_timer > 0.0:
		_core_mat.emission = Game.ECHO_CYAN
		_core_mat.emission_energy_multiplier = 5.0 + sin(_t * 12.0) * 2.0
		_core.scale = Vector3.ONE * 1.4
	else:
		_core_mat.emission = DISSONANCE.darkened(0.3)
		_core_mat.emission_energy_multiplier = 0.4
		_core.scale = Vector3.ONE

	_flash = move_toward(_flash, 0.0, delta * 6.0)
	_body_mat.emission = Color.WHITE * _flash * 2.5

	if _bar_root.visible:
		var cam := get_viewport().get_camera_3d()
		if cam != null:
			_bar_root.global_basis = cam.global_basis


func _update_bar() -> void:
	if _bar_root == null:
		return
	_bar_root.visible = hp < max_hp and not is_defeated()
	var frac: float = clampf(hp / max_hp, 0.0, 1.0) if max_hp > 0.0 else 0.0
	_bar_fill.scale = Vector3(maxf(frac, 0.001), 1, 1)
	_bar_fill.position = Vector3(-(1.0 - frac) * 0.43, 0, 0.01)


func _emissive(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


func _mi(mesh: Mesh, mat: Material, pos: Vector3, parent: Node3D, shadow: bool) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	if not shadow:
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	return m


func _build_visual() -> void:
	_visual = Node3D.new()
	add_child(_visual)

	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = Color(0.11, 0.11, 0.15)
	_body_mat.metallic = 0.85
	_body_mat.roughness = 0.3
	_body_mat.emission_enabled = true
	_body_mat.emission = Color.BLACK
	var body := SphereMesh.new()
	body.radius = 0.45
	body.height = 0.9
	body.radial_segments = 20
	body.rings = 10
	_mi(body, _body_mat, Vector3.ZERO, _visual, true)

	# Fins radiating from the rear.
	var fin := BoxMesh.new()
	fin.size = Vector3(0.05, 0.34, 0.32)
	for i in 3:
		var a: float = PI * 0.5 + float(i) * TAU / 3.0
		var f := _mi(fin, _body_mat, Vector3(cos(a) * 0.42, sin(a) * 0.42, 0.12), _visual, true)
		f.rotation.z = a - PI * 0.5

	_ring_mat = _emissive(DISSONANCE, 1.2)
	var tor := TorusMesh.new()
	tor.inner_radius = 0.6
	tor.outer_radius = 0.68
	tor.rings = 24
	tor.ring_segments = 6
	var ring_pivot := Node3D.new()
	ring_pivot.rotation = Vector3(0.35, 0.0, 0.2)
	_visual.add_child(ring_pivot)
	_ring = _mi(tor, _ring_mat, Vector3.ZERO, ring_pivot, false)

	_eye_mat = _emissive(DISSONANCE, 2.0)
	var eye := SphereMesh.new()
	eye.radius = 0.12
	eye.height = 0.24
	eye.radial_segments = 12
	eye.rings = 6
	_eye = _mi(eye, _eye_mat, Vector3(0, 0.05, -0.41), _visual, false)

	# Core sits on the underside so the player (below) can see it light up.
	_core_mat = _emissive(DISSONANCE.darkened(0.3), 0.4)
	var core := SphereMesh.new()
	core.radius = 0.17
	core.height = 0.34
	core.radial_segments = 12
	core.rings = 6
	_core = _mi(core, _core_mat, Vector3(0, -0.36, 0), _visual, false)

	# Health bar (camera-facing; hidden at full hp).
	_bar_root = Node3D.new()
	_bar_root.position.y = 0.95
	add_child(_bar_root)
	var bg_mat := StandardMaterial3D.new()
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bg_mat.albedo_color = Color(0.03, 0.02, 0.05, 0.65)
	var bg := QuadMesh.new()
	bg.size = Vector2(0.9, 0.1)
	_mi(bg, bg_mat, Vector3.ZERO, _bar_root, false)
	var fill_mat := StandardMaterial3D.new()
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fill_mat.albedo_color = Color(1.0, 0.4, 0.9, 1.0)
	fill_mat.render_priority = 1
	var fq := QuadMesh.new()
	fq.size = Vector2(0.86, 0.065)
	_bar_fill = _mi(fq, fill_mat, Vector3(0, 0, 0.01), _bar_root, false)
	_bar_root.visible = false
