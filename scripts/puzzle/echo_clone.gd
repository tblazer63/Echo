class_name EchoClone
extends AnimatableBody3D
## Holographic replay of a recorded player path. Replays one frame per physics
## tick, then holds the final pose forever (so it can keep a switch pressed).

signal blocked

enum Mode { REPLAY, MOVE, FOLLOW }

const REVEAL_SHADER := preload("res://shaders/reveal.gdshader")
const REVEAL := 1.0
const WALK_SPEED := 5.0
const FOLLOW_DIST := 2.5
const FOLLOW_MAX := 14.0

var mode := Mode.REPLAY
var frames: Array = []
var _target := Vector3.ZERO
var _follow: Node3D
var _stuck_t := 0.0
var holding := false
var _idx := 0
var _mat: ShaderMaterial
var _ring_mat: StandardMaterial3D
var _ring: MeshInstance3D
var _visual: Node3D
var _head: Node3D
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _col: CollisionShape3D
var _fade := 0.0
var _dismissing := false
var _t := 0.0
var _phase := 0.0
var _swing := 0.0
var _blink_t := 0.0
var _last_pos := Vector3.ZERO


func _init() -> void:
	sync_to_physics = false
	collision_layer = 4
	collision_mask = 0


func _ready() -> void:
	add_to_group("clone")
	_col = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.8
	_col.shape = cap
	_col.position.y = 0.9
	add_child(_col)

	_mat = ShaderMaterial.new()
	_mat.shader = REVEAL_SHADER
	_mat.set_shader_parameter("color", Game.ECHO_CYAN)
	_mat.set_shader_parameter("reveal", 0.0)
	_mat.set_shader_parameter("blink", 0.0)
	_mat.set_shader_parameter("grid_size", 0.15)
	_mat.set_shader_parameter("half_size", Vector3(0.3, 0.9, 0.3))

	_visual = Node3D.new()
	add_child(_visual)
	# Torso.
	_part(_visual, _capsule(0.22, 0.75), Vector3(0, 1.22, 0))
	# Head (pivot at neck so pitch tilts it) + visor facing -Z.
	_head = Node3D.new()
	_head.position.y = 1.5
	_visual.add_child(_head)
	var sph := SphereMesh.new()
	sph.radius = 0.16
	sph.height = 0.32
	sph.radial_segments = 16
	sph.rings = 8
	_part(_head, sph, Vector3(0, 0.18, 0))
	var visor := BoxMesh.new()
	visor.size = Vector3(0.22, 0.06, 0.06)
	_part(_head, visor, Vector3(0, 0.2, -0.14))
	# Legs (pivot at hip).
	for side in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(side * 0.12, 0.88, 0)
		_visual.add_child(hip)
		_part(hip, _capsule(0.1, 0.86), Vector3(0, -0.42, 0))
		_legs.append(hip)
	# Arms (pivot at shoulder).
	for side in [-1.0, 1.0]:
		var sh := Node3D.new()
		sh.position = Vector3(side * 0.31, 1.47, 0)
		sh.rotation.z = side * deg_to_rad(8)
		_visual.add_child(sh)
		_part(sh, _capsule(0.07, 0.7), Vector3(0, -0.32, 0))
		_arms.append(sh)

	# Glowing floor ring.
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_ring_mat.albedo_color = Color(Game.ECHO_CYAN, 0.0)
	_ring = MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.42
	tor.outer_radius = 0.52
	tor.rings = 24
	tor.ring_segments = 6
	_ring.mesh = tor
	_ring.material_override = _ring_mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.position.y = 0.04
	_ring.scale = Vector3(1, 0.3, 1)
	add_child(_ring)
	# Floating marker so the echo is easy to find.
	var tag := Label3D.new()
	tag.text = "ECHO"
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.font_size = 40
	tag.pixel_size = 0.006
	tag.outline_size = 10
	tag.modulate = Game.ECHO_CYAN
	tag.outline_modulate = Color(0.02, 0.1, 0.14, 0.9)
	tag.position.y = 2.25
	add_child(tag)


func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 12
	c.rings = 4
	return c


func _part(parent: Node3D, mesh: Mesh, pos: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = _mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = pos
	parent.add_child(m)
	return m


## frames: Array of {"pos": Vector3, "yaw": float, "pitch": float}.
func play(rec_frames: Array) -> void:
	frames = rec_frames
	_idx = 0
	holding = frames.is_empty()
	if not frames.is_empty():
		_apply(frames[0])
		_last_pos = _get_pos()
		# Frame 0 is already applied; continue from frame 1 next tick so the
		# first pose is not replayed twice.
		_idx = 1
		holding = frames.size() <= 1


func dismiss() -> void:
	if _dismissing:
		return
	_dismissing = true
	remove_from_group("clone")
	if _col:
		_col.set_deferred("disabled", true)


func _get_pos() -> Vector3:
	return global_position if is_inside_tree() else position


func _apply(f: Dictionary) -> void:
	var p: Vector3 = f.get("pos", Vector3.ZERO)
	if is_inside_tree():
		global_position = p
	else:
		position = p
	rotation.y = float(f.get("yaw", 0.0))
	if _head:
		_head.rotation.x = clampf(float(f.get("pitch", 0.0)) * 0.6, -0.7, 0.7)


## Command: walk to a point on the ground and hold there.
func move_to(target: Vector3) -> void:
	mode = Mode.MOVE
	_target = target
	frames = []
	holding = false
	_stuck_t = 0.0


## Command: follow the given node (the player), rejoining it if left behind.
func follow(who: Node3D) -> void:
	mode = Mode.FOLLOW
	_follow = who
	frames = []
	holding = false
	_stuck_t = 0.0


func is_dismissing() -> bool:
	return _dismissing


func _ground_at(p: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.2, p + Vector3.DOWN * 2.5, 1)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or (hit["normal"] as Vector3).y < 0.5:
		return {}
	return hit


func _rejoin(p: Vector3) -> void:
	var g := _ground_at(p)
	if g.is_empty():
		return
	global_position = g["position"]
	_fade = 0.15
	_stuck_t = 0.0
	Sfx.play("clone_play", -10.0)


func _command_step(delta: float) -> void:
	var goal := _target
	var stop_dist := 0.12
	if mode == Mode.FOLLOW:
		if not is_instance_valid(_follow):
			mode = Mode.MOVE
			_target = global_position
			return
		goal = _follow.global_position
		stop_dist = FOLLOW_DIST
		if global_position.distance_to(goal) > FOLLOW_MAX or _stuck_t > 1.2:
			_rejoin(goal + _follow.global_basis.z * 1.6)
			return
	var to := Vector3(goal.x - global_position.x, 0.0, goal.z - global_position.z)
	var dist := to.length()
	if dist <= stop_dist:
		holding = true
		_stuck_t = 0.0
		return
	var dir := to / dist
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), clampf(delta * 10.0, 0.0, 1.0))
	var speed := WALK_SPEED * (1.4 if dist > 6.0 and mode == Mode.FOLLOW else 1.0)
	var step := minf(speed * delta, dist - stop_dist * 0.5)
	var space := get_world_3d().direct_space_state
	var wall := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.0,
		global_position + Vector3.UP * 1.0 + dir * (step + 0.45), 1)
	var g: Dictionary = {}
	if space.intersect_ray(wall).is_empty():
		g = _ground_at(global_position + dir * step)
	if g.is_empty():
		holding = true
		if mode == Mode.MOVE:
			_target = global_position
			blocked.emit()
		else:
			_stuck_t += delta
		return
	holding = false
	_stuck_t = 0.0
	global_position = g["position"]
	_phase += delta * speed * 1.8
	_swing = lerpf(_swing, 1.0, clampf(delta * 10.0, 0.0, 1.0))


func _physics_process(delta: float) -> void:
	if mode != Mode.REPLAY:
		_command_step(delta)
		return
	if holding or frames.is_empty():
		return
	if _idx < frames.size():
		_apply(frames[_idx])
		_idx += 1
		var cur := global_position
		var hv := Vector2(cur.x - _last_pos.x, cur.z - _last_pos.z).length() / maxf(delta, 0.0001)
		_last_pos = cur
		_phase += delta * hv * 1.8
		_swing = lerpf(_swing, clampf(hv / 5.5, 0.0, 1.0), clampf(delta * 10.0, 0.0, 1.0))
	if _idx >= frames.size():
		holding = true


func _process(delta: float) -> void:
	_t += delta
	# Fade in / out.
	var target := 0.0 if _dismissing else 1.0
	_fade = move_toward(_fade, target, delta * (2.5 if _dismissing else 1.6))
	if _dismissing and _fade <= 0.001:
		queue_free()
		return
	# Subtle flicker: occasional short glitch bursts.
	_blink_t -= delta
	if _blink_t <= 0.0 and randf() < delta * 0.5:
		_blink_t = randf_range(0.05, 0.15)
	var blink := 0.6 if _blink_t > 0.0 else 0.0
	var shimmer := 0.93 + 0.07 * sin(_t * 9.0)
	_mat.set_shader_parameter("reveal", REVEAL * _fade * shimmer)
	_mat.set_shader_parameter("blink", blink)

	# Limb swing while replaying, idle bob while holding (visual only).
	if holding:
		_swing = move_toward(_swing, 0.0, delta * 3.0)
		_visual.position.y = sin(_t * 2.2) * 0.035
	else:
		_visual.position.y = lerpf(_visual.position.y, 0.0, clampf(delta * 8.0, 0.0, 1.0))
	var s := sin(_phase) * 0.55 * _swing
	_legs[0].rotation.x = s
	_legs[1].rotation.x = -s
	_arms[0].rotation.x = -s * 0.8
	_arms[1].rotation.x = s * 0.8

	var pulse := 0.5 + 0.5 * sin(_t * 3.0)
	_ring_mat.albedo_color = Color(Game.ECHO_CYAN, (0.45 + 0.35 * pulse) * _fade)
	var rs := 1.0 + 0.08 * pulse
	_ring.scale = Vector3(rs, 0.3, rs)
