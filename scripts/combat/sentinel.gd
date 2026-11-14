class_name Sentinel
extends CharacterBody3D
## Mini-boss guarding the First Resonance Spire. Its shield is powered by
## ShieldPylons; break them (Echo Scan / bolts), then scan to expose the core.
## Phase 2 (50% HP) re-forms the shield and fires 3-shot spreads.

signal health_changed(hp: float, max_hp: float)
signal phase_changed(phase: int)
signal shield_changed(up: bool)
signal defeated

const DISSONANCE := Color(0.95, 0.25, 0.85)
const TELEGRAPH := 0.8
const STUN_TIME := 1.2
const EXPOSE_TIME := 5.0

var max_hp := 320.0
var hp := 320.0
var phase := 1
var shield_up := true
var active := false
var arena_center := Vector3.ZERO
var pylons: Array = []

var _defeated := false
var _angle := 0.0
var _attack_t := 2.0
var _telegraph_t := -1.0
var _stun_t := 0.0
var _expose_t := 0.0
var _flash := 0.0
var _visual: Node3D
var _ring_a: MeshInstance3D
var _ring_b: MeshInstance3D
var _eye_mat: StandardMaterial3D
var _core_mat: StandardMaterial3D
var _body_mat: StandardMaterial3D
var _shield: MeshInstance3D
var _shield_mat: StandardMaterial3D
var _connected := false


func _ready() -> void:
	add_to_group("boss")
	add_to_group("echo_reactive")
	collision_layer = 8
	collision_mask = 1
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var col := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 1.3
	col.shape = sh
	add_child(col)
	_build_visual()
	_set_shield_visual(true)
	_eye_mat.emission_energy_multiplier = 0.4


func _build_visual() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = Color(0.12, 0.13, 0.17)
	_body_mat.metallic = 0.7
	_body_mat.roughness = 0.35
	_body_mat.emission_enabled = true
	_body_mat.emission = Color.BLACK
	var body := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 1.1
	bm.height = 2.2
	bm.radial_segments = 20
	bm.rings = 10
	body.mesh = bm
	body.material_override = _body_mat
	_visual.add_child(body)

	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.85, 0.7, 0.35)
	gold.metallic = 0.8
	gold.roughness = 0.3
	_ring_a = MeshInstance3D.new()
	var ta := TorusMesh.new()
	ta.inner_radius = 1.55
	ta.outer_radius = 1.75
	ta.rings = 32
	ta.ring_segments = 8
	_ring_a.mesh = ta
	_ring_a.material_override = gold
	_visual.add_child(_ring_a)
	_ring_b = MeshInstance3D.new()
	var tb := TorusMesh.new()
	tb.inner_radius = 1.85
	tb.outer_radius = 2.0
	tb.rings = 32
	tb.ring_segments = 8
	_ring_b.mesh = tb
	_ring_b.material_override = gold
	_ring_b.rotation.x = deg_to_rad(90)
	_visual.add_child(_ring_b)

	_eye_mat = StandardMaterial3D.new()
	_eye_mat.albedo_color = DISSONANCE
	_eye_mat.emission_enabled = true
	_eye_mat.emission = DISSONANCE
	_eye_mat.emission_energy_multiplier = 3.0
	var eye := MeshInstance3D.new()
	var em := SphereMesh.new()
	em.radius = 0.3
	em.height = 0.6
	eye.mesh = em
	eye.material_override = _eye_mat
	eye.position = Vector3(0, 0.15, -1.0)
	eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(eye)

	_core_mat = StandardMaterial3D.new()
	_core_mat.albedo_color = Color(0.2, 0.3, 0.35)
	_core_mat.emission_enabled = true
	_core_mat.emission = Game.ECHO_CYAN
	_core_mat.emission_energy_multiplier = 0.0
	var core := MeshInstance3D.new()
	var cm := SphereMesh.new()
	cm.radius = 0.45
	cm.height = 0.9
	core.mesh = cm
	core.material_override = _core_mat
	core.position = Vector3(0, -0.75, -0.55)
	_visual.add_child(core)

	for i in 4:
		var fin := MeshInstance3D.new()
		var fm := BoxMesh.new()
		fm.size = Vector3(0.15, 0.9, 0.5)
		fin.mesh = fm
		fin.material_override = _body_mat
		var a := float(i) * TAU / 4.0 + PI / 4.0
		fin.position = Vector3(cos(a), 0, sin(a)) * 1.15
		fin.rotation.y = -a
		_visual.add_child(fin)

	_shield_mat = StandardMaterial3D.new()
	_shield_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shield_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shield_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_shield_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_shield_mat.albedo_color = Color(0.9, 0.25, 0.8, 0.22)
	_shield_mat.rim_enabled = false
	_shield = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 2.5
	sm.height = 5.0
	sm.radial_segments = 24
	sm.rings = 12
	_shield.mesh = sm
	_shield.material_override = _shield_mat
	_shield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shield)


func start_fight() -> void:
	if active or _defeated:
		return
	active = true
	_attack_t = 2.5
	for p in pylons:
		if p is ShieldPylon:
			var py := p as ShieldPylon
			py.target = self
			if not _connected:
				py.state_changed.connect(_on_pylon_changed)
	_connected = true
	_eye_mat.emission_energy_multiplier = 3.0
	Sfx.play("gate", 0.0, 0.6)
	Sfx.play("drone_charge", -2.0, 0.5)
	var tw := create_tween()
	_visual.scale = Vector3.ONE * 0.6
	tw.tween_property(_visual, "scale", Vector3.ONE, 0.8).set_trans(Tween.TRANS_BACK)
	_update_shield()
	health_changed.emit(hp, max_hp)


func is_defeated() -> bool:
	return _defeated


func reset_fight() -> void:
	if _defeated:
		return
	hp = max_hp
	phase = 1
	_stun_t = 0.0
	_expose_t = 0.0
	_telegraph_t = -1.0
	_attack_t = 2.5
	for p in pylons:
		if p is ShieldPylon:
			(p as ShieldPylon).reset_pylon()
	_update_shield()
	health_changed.emit(hp, max_hp)


func _on_pylon_changed(_a: bool) -> void:
	_update_shield()


func _update_shield() -> void:
	var any := false
	for p in pylons:
		if p is ShieldPylon and (p as ShieldPylon).active:
			any = true
	if any == shield_up and _shield.visible == any:
		return
	shield_up = any
	_set_shield_visual(any)
	shield_changed.emit(any)
	if not any and active and not _defeated:
		Sfx.play("shatter", 0.0, 0.8)
		Game.prompt("Shield down! Echo Scan exposes the Sentinel's core.", 4.0, "sentinel_shield")


func _set_shield_visual(up: bool) -> void:
	_shield.visible = up


func _player() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D


func _physics_process(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	_ring_a.rotation.y += delta * (1.2 if not _defeated else 0.2)
	_ring_b.rotation.z += delta * (0.8 if not _defeated else 0.1)
	_flash = maxf(_flash - delta * 4.0, 0.0)
	_body_mat.emission = Color(1, 1, 1) * _flash
	_expose_t = maxf(_expose_t - delta, 0.0)
	_core_mat.emission_energy_multiplier = (4.0 + 2.0 * sin(t * 12.0)) if _expose_t > 0.0 else 0.0
	if _shield.visible:
		_shield_mat.albedo_color.a = 0.18 + 0.06 * sin(t * 5.0)
		_shield.rotation.y += delta * 0.6

	if _defeated:
		var rest := arena_center + Vector3.UP * 2.5
		global_position = global_position.lerp(rest, clampf(delta * 0.8, 0.0, 1.0))
		return
	if not active:
		global_position.y = arena_center.y + 5.5 + sin(t) * 0.3
		return

	# Orbit the arena and face the player.
	_angle += delta * (0.25 if phase == 1 else 0.38)
	var target_pos := arena_center + Vector3(cos(_angle) * 4.0, 6.0 + sin(t * 1.3) * 0.6, sin(_angle) * 4.0)
	velocity = (target_pos - global_position) * 2.0
	if _stun_t > 0.0:
		velocity = Vector3(0, -0.6, 0)
	move_and_slide()
	var p := _player()
	if p:
		var look := p.global_position + Vector3.UP * 1.4
		var flat := Vector3(look.x - global_position.x, 0, look.z - global_position.z)
		if flat.length() > 0.1:
			var yaw := atan2(-flat.x, -flat.z)
			_visual.rotation.y = lerp_angle(_visual.rotation.y, yaw, clampf(delta * 4.0, 0.0, 1.0))

	if _stun_t > 0.0:
		_stun_t -= delta
		_visual.rotation.z = sin(t * 30.0) * 0.15
		_telegraph_t = -1.0
		return
	_visual.rotation.z = 0.0

	if _telegraph_t >= 0.0:
		_telegraph_t += delta
		_eye_mat.emission_energy_multiplier = 3.0 + _telegraph_t * 12.0
		if _telegraph_t >= TELEGRAPH:
			_telegraph_t = -1.0
			_eye_mat.emission_energy_multiplier = 3.0
			_fire(p)
		return
	_attack_t -= delta
	if _attack_t <= 0.0 and p and p.global_position.distance_to(global_position) < 40.0:
		_attack_t = 2.2 if phase == 1 else 2.0
		_telegraph_t = 0.0
		Sfx.play("drone_charge", -2.0, 0.7)


func _fire(p: Node3D) -> void:
	if p == null:
		return
	var from := global_position + (_visual.global_basis * Vector3(0, 0.15, -1.3))
	var aim := p.global_position + Vector3.UP * 1.2
	if phase == 1:
		EnemyProjectile.spawn(get_tree().current_scene, from, aim, 14.0, 15.0)
	else:
		var dir := aim - from
		for deg in [-12.0, 0.0, 12.0]:
			var d := dir.rotated(Vector3.UP, deg_to_rad(deg))
			EnemyProjectile.spawn(get_tree().current_scene, from, from + d, 15.0, 12.0)
	Sfx.play("drone_shot", 0.0, 0.7)


func echo_point() -> Vector3:
	return global_position


func on_echo(_origin: Vector3, wave: Node) -> void:
	if _defeated or not active:
		return
	if not (wave is PulseWave and (wave as PulseWave).primary):
		return
	if shield_up:
		_flash = 0.5
		return
	_stun_t = STUN_TIME
	_expose_t = EXPOSE_TIME
	Game.prompt("Core exposed. Fire!", 2.0, "sentinel_core")


func take_damage(amount: float, _hit_pos: Vector3) -> void:
	if _defeated or not active:
		return
	if shield_up:
		_flash = 0.3
		Sfx.play("tick", -6.0, 1.4)
		return
	var dmg := amount * (2.0 if _expose_t > 0.0 else 1.0)
	hp = maxf(hp - dmg, 0.0)
	_flash = 1.0
	health_changed.emit(hp, max_hp)
	if phase == 1 and hp <= max_hp * 0.5:
		phase = 2
		_expose_t = 0.0
		phase_changed.emit(2)
		for p in pylons:
			if p is ShieldPylon:
				(p as ShieldPylon).reset_pylon()
		_update_shield()
		Game.prompt("The Sentinel re-forms its shield!", 3.5)
		Sfx.play("relay", 0.0, 0.6)
	elif hp <= 0.0:
		_defeat()


func _defeat() -> void:
	if _defeated:
		return
	_defeated = true
	active = false
	Sfx.play("drone_down", 0.0, 0.6)
	Sfx.play("shatter", 0.0)
	_set_shield_visual(false)
	_eye_mat.albedo_color = Game.ECHO_CYAN
	_eye_mat.emission = Game.ECHO_CYAN
	_eye_mat.emission_energy_multiplier = 2.0
	_core_mat.emission_energy_multiplier = 3.0
	_flash = 0.0
	collision_layer = 0
	for p in pylons:
		if p is ShieldPylon:
			(p as ShieldPylon).disable()
	defeated.emit()
