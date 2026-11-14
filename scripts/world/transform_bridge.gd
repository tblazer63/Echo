class_name TransformBridge
extends Node3D
## Shattered stone bridge that swings back into place when `activate()` is
## called. The deck runs from this node's origin along local -Z for `length`;
## its walkable top surface is at local y = 0 once settled.

signal transformed

const BROKEN_ROT_DEG := Vector3(-28.0, 55.0, 12.0)
const BROKEN_OFFSET := Vector3(2.6, -3.5, 0.0)

var length := 11.0
var width := 3.6
var active := false
var body: AnimatableBody3D
var _settled := false
var _broken_rot := Vector3.ZERO
var _seam_mat: StandardMaterial3D


func _ready() -> void:
	_broken_rot = Vector3(deg_to_rad(BROKEN_ROT_DEG.x), deg_to_rad(BROKEN_ROT_DEG.y), deg_to_rad(BROKEN_ROT_DEG.z))
	body = AnimatableBody3D.new()
	body.sync_to_physics = true
	body.collision_layer = 1
	add_child(body)

	var stone := Builders.stone_material(0.4)
	Builders._box(body, Vector3(width, 0.7, length), Vector3(0, -0.35, -length * 0.5), stone)
	# Tapered keel underneath for visual weight.
	Builders._box(body, Vector3(width * 0.6, 0.6, length * 0.86), Vector3(0, -0.95, -length * 0.5), Builders.stone_material(0.6))

	# Broken rail posts.
	var post_mat := Builders.stone_material(0.6)
	var n := int(length / 2.2)
	for i in n:
		for s in 2:
			if (i + s * 2) % 3 == 0:
				continue
			var side := -1.0 if s == 0 else 1.0
			var h := 0.45 + fmod(float(i) * 0.37 + float(s) * 0.21, 0.65)
			Builders._box(body, Vector3(0.32, h, 0.32), Vector3(side * (width * 0.5 - 0.2), h * 0.5, -1.0 - i * 2.2), post_mat)

	# Glowing resonance seams along both edges.
	_seam_mat = StandardMaterial3D.new()
	_seam_mat.albedo_color = Game.ECHO_CYAN
	_seam_mat.emission_enabled = true
	_seam_mat.emission = Game.ECHO_CYAN
	_seam_mat.emission_energy_multiplier = 0.6
	for s in 2:
		var side := -1.0 if s == 0 else 1.0
		var seam := Builders._box(body, Vector3(0.07, 0.1, length * 0.97), Vector3(side * (width * 0.5 + 0.02), -0.09, -length * 0.5), _seam_mat)
		seam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, 0.7, length)
	col.shape = shape
	col.position = Vector3(0, -0.35, -length * 0.5)
	body.add_child(col)

	body.transform = _pose(0.0)


func _pose(t: float) -> Transform3D:
	# Lerp (not slerp) so TRANS_BACK overshoot extrapolates smoothly.
	var rot := _broken_rot.lerp(Vector3.ZERO, t)
	return Transform3D(Basis.from_euler(rot), BROKEN_OFFSET.lerp(Vector3.ZERO, t))


func _apply_pose(t: float) -> void:
	body.transform = _pose(t)


func activate() -> void:
	if active:
		return
	if body == null:
		push_warning("TransformBridge.activate() called before _ready; ignored")
		return
	active = true
	Sfx.play("bridge")
	_dust(20)
	var tw := create_tween()
	tw.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_method(_apply_pose, 0.0, 1.0, 2.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_seam_mat, "emission_energy_multiplier", 6.0, 1.4)
	tw.tween_callback(_on_settled)
	tw.tween_property(_seam_mat, "emission_energy_multiplier", 2.4, 1.2)


func _on_settled() -> void:
	body.transform = Transform3D.IDENTITY
	_settled = true
	_dust(14)
	transformed.emit()


func is_settled() -> bool:
	return _settled


func _dust(amount: int) -> void:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.one_shot = true
	p.explosiveness = 0.85
	p.lifetime = 1.6
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(width * 0.5, 0.3, length * 0.5)
	p.direction = Vector3.UP
	p.spread = 60.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 2.6
	p.gravity = Vector3(0, -1.5, 0)
	p.scale_amount_min = 0.3
	p.scale_amount_max = 0.8
	var m := SphereMesh.new()
	m.radius = 0.12
	m.height = 0.24
	m.radial_segments = 6
	m.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	m.material = mat
	p.mesh = m
	var g := Gradient.new()
	g.set_color(0, Color(0.85, 0.82, 0.74, 0.35))
	g.set_color(1, Color(0.85, 0.82, 0.74, 0.0))
	p.color_ramp = g
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(p)
	p.position = Vector3(0, -0.4, -length * 0.5)
	p.emitting = true
	get_tree().create_timer(3.0).timeout.connect(p.queue_free)
