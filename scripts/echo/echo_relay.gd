class_name EchoRelay
extends StaticBody3D
## Cracked resonant pillar. When an echo reaches it, it resonates and fires a
## beam of sound at its target (which must implement `unlock()`).

signal resonated

@export var target: Node3D
@export var height := 5.0

var activated := false
var _stone_mat: ShaderMaterial
var _crack_mat: StandardMaterial3D
var _light: OmniLight3D
var _glow := 0.25


func _ready() -> void:
	add_to_group("echo_reactive")
	_stone_mat = Builders.stone_material(0.6)
	# Base, lower shaft, offset broken upper shaft, cap.
	_part(Vector3(1.9, 0.6, 1.9), Vector3(0, 0.3, 0), 0.0)
	_part(Vector3(1.3, height * 0.5, 1.3), Vector3(0, 0.6 + height * 0.25, 0), 0.0)
	_part(Vector3(1.3, height * 0.42, 1.3), Vector3(0.08, 0.6 + height * 0.5 + height * 0.21 + 0.08, 0.05), 6.0)
	_part(Vector3(1.7, 0.4, 1.7), Vector3(0.12, 0.6 + height * 0.92 + 0.3, 0.06), 6.0)
	# Glowing crack.
	_crack_mat = StandardMaterial3D.new()
	_crack_mat.albedo_color = Game.ECHO_CYAN
	_crack_mat.emission_enabled = true
	_crack_mat.emission = Game.ECHO_CYAN
	_crack_mat.emission_energy_multiplier = 1.0
	for i in 5:
		var c := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.08, 0.7, 1.34)
		c.mesh = b
		c.material_override = _crack_mat
		c.position = Vector3(0.62 + (i % 2) * 0.03, 1.4 + i * 0.6, 0)
		c.rotation.z = deg_to_rad(-20 + (i % 2) * 40)
		add_child(c)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.6, height + 1.0, 1.6)
	col.shape = shape
	col.position.y = (height + 1.0) * 0.5
	add_child(col)
	_light = OmniLight3D.new()
	_light.light_color = Game.ECHO_CYAN
	_light.omni_range = 7.0
	_light.light_energy = 0.3
	_light.position = Vector3(1.0, height * 0.6, 0)
	add_child(_light)


func _part(size: Vector3, pos: Vector3, rot_deg: float) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	b.subdivide_width = 3
	b.subdivide_height = 4
	b.subdivide_depth = 3
	m.mesh = b
	m.material_override = _stone_mat
	m.position = pos
	m.rotation.y = deg_to_rad(rot_deg)
	add_child(m)


func echo_point() -> Vector3:
	return global_position + Vector3.UP * 1.5


func top_point() -> Vector3:
	return global_position + Vector3(0.1, height + 0.8, 0.05)


func _process(delta: float) -> void:
	var idle := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.003)
	var target_glow := 4.0 if activated else 0.6 * idle
	_glow = lerpf(_glow, target_glow, clampf(delta * 3.0, 0.0, 1.0))
	_crack_mat.emission_energy_multiplier = _glow
	_light.light_energy = _glow * 0.5


func on_echo(_origin: Vector3, wave: Node) -> void:
	if activated:
		return
	if wave is PulseWave and not (wave as PulseWave).primary:
		return
	activated = true
	_glow = 8.0
	Sfx.play("relay", -2.0)
	resonated.emit()
	await get_tree().create_timer(0.45).timeout
	var w := PulseWave.spawn(get_tree().current_scene, top_point(), 6.0, false)
	w.speed = 14.0
	if target:
		_fire_beam(target)
		await get_tree().create_timer(0.5).timeout
		if target.has_method("unlock"):
			target.call("unlock")


func _fire_beam(t: Node3D) -> void:
	var a := top_point()
	var b: Vector3 = t.call("beam_point") if t.has_method("beam_point") else t.global_position
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.09
	cyl.bottom_radius = 0.09
	cyl.height = a.distance_to(b)
	cyl.radial_segments = 12
	beam.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(0.5, 1.0, 1.0, 1.0)
	mat.emission_enabled = true
	mat.emission = Game.ECHO_CYAN
	mat.emission_energy_multiplier = 6.0
	beam.material_override = mat
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().current_scene.add_child(beam)
	beam.global_position = (a + b) * 0.5
	# Cylinder points along +Y; align it with the beam direction.
	var dir := (b - a).normalized()
	var axis := Vector3.UP.cross(dir)
	if axis.length() > 0.001:
		beam.global_basis = Basis(axis.normalized(), Vector3.UP.angle_to(dir))
	beam.scale = Vector3(0.01, 1, 0.01)
	var tw := beam.create_tween()
	tw.tween_property(beam, "scale", Vector3(1.6, 1, 1.6), 0.2)
	tw.tween_property(beam, "scale", Vector3(0.6, 1, 0.6), 0.6)
	tw.tween_property(mat, "albedo_color:a", 0.0, 1.2)
	tw.tween_callback(beam.queue_free)
