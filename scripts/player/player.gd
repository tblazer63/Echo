class_name Player
extends CharacterBody3D
## First-person controller with an echo gauntlet.

const WALK_SPEED := 5.5
const SPRINT_SPEED := 8.5
const GROUND_ACCEL := 12.0
const AIR_ACCEL := 4.0
const JUMP_VELOCITY := 6.2
const GRAVITY := 15.0
const COYOTE_TIME := 0.15
const JUMP_BUFFER := 0.15
const FALL_LIMIT := -22.0

var head: Node3D
var camera: Camera3D
var arm: Node3D
var emitter: EchoEmitter
var _coyote := 0.0
var _jump_buffer := 0.0
var _bob_t := 0.0
var _arm_kick := 0.0
var _base_fov := 75.0
var _respawning := false
var input_enabled := true
var health: PlayerHealth
var _dash_t := 0.0
var _dash_dir := Vector3.ZERO
var _shake := 0.0
const DASH_SPEED := 17.0
const DASH_TIME := 0.18


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	health = PlayerHealth.new()
	add_child(health)
	health.damaged.connect(func(_a: float, _p: Vector3) -> void:
		_shake = 0.35
		Sfx.play("hurt", -3.0))
	health.died.connect(func() -> void:
		respawn()
		health.heal_full())
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.8
	col.shape = cap
	col.position.y = 0.9
	add_child(col)
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(50.0)

	head = Node3D.new()
	head.position.y = 1.62
	add_child(head)
	camera = Camera3D.new()
	camera.fov = _base_fov
	camera.near = 0.05
	camera.far = 3000.0
	camera.current = true
	head.add_child(camera)

	arm = _build_arm()
	camera.add_child(arm)

	emitter = EchoEmitter.new()
	add_child(emitter)
	emitter.pulsed.connect(_on_pulsed)
	emitter.fired.connect(func() -> void: _arm_kick = maxf(_arm_kick, 0.45))

	rotation.y = Game.checkpoint_yaw
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_add_motes()


## Drifting light motes around the player for atmosphere.
func _add_motes() -> void:
	var p := CPUParticles3D.new()
	p.amount = 70
	p.lifetime = 6.0
	p.preprocess = 6.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(14, 5, 14)
	p.direction = Vector3.UP
	p.spread = 180.0
	p.gravity = Vector3(0, 0.05, 0)
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.3
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(0.2, 1))
	curve.add_point(Vector2(0.8, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(0.7, 1.0, 1.0, 0.8)
	q.material = m
	p.mesh = q
	p.position.y = 2.0
	add_child(p)


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var m := event as InputEventMouseMotion
		rotate_y(-m.relative.x * Game.mouse_sensitivity)
		head.rotate_x(-m.relative.y * Game.mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-85), deg_to_rad(85))
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
		_coyote -= delta
	else:
		_coyote = COYOTE_TIME

	var dir := Vector3.ZERO
	var sprinting := false
	if input_enabled:
		if Input.is_action_just_pressed("jump"):
			_jump_buffer = JUMP_BUFFER
		if Input.is_action_just_pressed("pulse"):
			emitter.try_pulse()
		if Input.is_action_pressed("fire") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			emitter.try_fire(camera, _muzzle())
		if Input.is_action_just_pressed("dash") and _dash_t <= 0.0:
			_start_dash()
		var iv := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		dir = (transform.basis * Vector3(iv.x, 0, iv.y)).normalized()
		sprinting = Input.is_action_pressed("sprint")
	_jump_buffer -= delta

	if _jump_buffer > 0.0 and _coyote > 0.0:
		velocity.y = JUMP_VELOCITY
		_jump_buffer = 0.0
		_coyote = 0.0

	var speed := SPRINT_SPEED if sprinting else WALK_SPEED
	var accel := GROUND_ACCEL if is_on_floor() else AIR_ACCEL
	var target := dir * speed
	if _dash_t > 0.0:
		_dash_t -= delta
		velocity.x = _dash_dir.x * DASH_SPEED
		velocity.z = _dash_dir.z * DASH_SPEED
		velocity.y = maxf(velocity.y, 0.0)
	else:
		velocity.x = lerpf(velocity.x, target.x, clampf(accel * delta, 0.0, 1.0))
		velocity.z = lerpf(velocity.z, target.z, clampf(accel * delta, 0.0, 1.0))
	move_and_slide()

	if global_position.y < FALL_LIMIT and not _respawning:
		respawn()


func _process(delta: float) -> void:
	# Head bob + arm sway.
	var hv := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and hv > 0.5:
		_bob_t += delta * hv * 1.6
	var bob := sin(_bob_t) * 0.03 * clampf(hv / WALK_SPEED, 0.0, 1.0)
	camera.position.y = bob
	_shake = maxf(_shake - delta, 0.0)
	camera.position.x = randf_range(-1.0, 1.0) * _shake * 0.08
	camera.position.y += randf_range(-1.0, 1.0) * _shake * 0.08
	_arm_kick = move_toward(_arm_kick, 0.0, delta * 3.0)
	arm.position = Vector3(0.32, -0.30 + bob * 0.5, -0.55 - _arm_kick * 0.18)
	arm.rotation = Vector3(deg_to_rad(8 + _arm_kick * 25.0), deg_to_rad(-12), deg_to_rad(-8))
	var target_fov := _base_fov + (6.0 if hv > WALK_SPEED + 0.5 else 0.0) + _arm_kick * 6.0
	camera.fov = lerpf(camera.fov, target_fov, clampf(delta * 6.0, 0.0, 1.0))


func respawn() -> void:
	_respawning = true
	Sfx.play("respawn", -4.0)
	velocity = Vector3.ZERO
	global_position = Game.checkpoint_pos
	rotation.y = Game.checkpoint_yaw
	head.rotation.x = 0.0
	Game.player_respawned.emit()
	await get_tree().physics_frame
	_respawning = false


func _on_pulsed() -> void:
	_arm_kick = 1.0


func _muzzle() -> Vector3:
	return camera.global_position - camera.global_basis.z * 0.6 + camera.global_basis.x * 0.25 - camera.global_basis.y * 0.2


func _start_dash() -> void:
	if not emitter.spend(EchoEmitter.DASH_COST):
		return
	var iv := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	_dash_dir = (transform.basis * Vector3(iv.x, 0, iv.y)).normalized()
	if _dash_dir == Vector3.ZERO:
		_dash_dir = -transform.basis.z
	_dash_t = DASH_TIME
	health.grant_iframes(0.35)
	Sfx.play("dash", -4.0)
	camera.fov += 8.0


func _build_arm() -> Node3D:
	var root := Node3D.new()
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.09, 0.11, 0.14)
	dark.roughness = 0.55
	dark.metallic = 0.3
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.16, 0.19, 0.23)
	cloth.roughness = 0.9
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Game.ECHO_CYAN
	glow.emission_enabled = true
	glow.emission = Game.ECHO_CYAN
	glow.emission_energy_multiplier = 1.4

	# Forearm (sleeve).
	var fore := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.055
	cyl.bottom_radius = 0.07
	cyl.height = 0.6
	fore.mesh = cyl
	fore.material_override = cloth
	fore.rotation.x = deg_to_rad(90)
	fore.position = Vector3(0, 0, 0.32)
	root.add_child(fore)
	# Bracer.
	var bracer := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 0.068
	bc.bottom_radius = 0.075
	bc.height = 0.2
	bracer.mesh = bc
	bracer.material_override = dark
	bracer.rotation.x = deg_to_rad(90)
	bracer.position = Vector3(0, 0, 0.1)
	root.add_child(bracer)
	# Glowing ring + emitter disc.
	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.07
	tor.outer_radius = 0.085
	ring.mesh = tor
	ring.material_override = glow
	ring.rotation.x = deg_to_rad(90)
	ring.position = Vector3(0, 0, 0.05)
	root.add_child(ring)
	var disc := MeshInstance3D.new()
	var dc := CylinderMesh.new()
	dc.top_radius = 0.018
	dc.bottom_radius = 0.018
	dc.height = 0.012
	disc.mesh = dc
	disc.material_override = glow
	disc.position = Vector3(0, 0.076, 0.12)
	root.add_child(disc)
	# Hand (palm + fingers).
	var palm := MeshInstance3D.new()
	var pb := BoxMesh.new()
	pb.size = Vector3(0.1, 0.035, 0.11)
	palm.mesh = pb
	palm.material_override = dark
	palm.position = Vector3(0, 0, -0.06)
	root.add_child(palm)
	for i in 4:
		var f := MeshInstance3D.new()
		var fb := CapsuleMesh.new()
		fb.radius = 0.011
		fb.height = 0.09
		f.mesh = fb
		f.material_override = dark
		f.rotation.x = deg_to_rad(80 + i * 4)
		f.position = Vector3(-0.036 + i * 0.024, 0.005, -0.15)
		root.add_child(f)
	var thumb := MeshInstance3D.new()
	var tb := CapsuleMesh.new()
	tb.radius = 0.012
	tb.height = 0.07
	thumb.mesh = tb
	thumb.material_override = dark
	thumb.rotation = Vector3(deg_to_rad(70), 0, deg_to_rad(50))
	thumb.position = Vector3(-0.065, 0, -0.07)
	root.add_child(thumb)
	return root
