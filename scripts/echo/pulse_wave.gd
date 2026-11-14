class_name PulseWave
extends Node3D
## An expanding sound wavefront. Calls `on_echo(origin)` on every node in the
## "echo_reactive" group once the wavefront reaches it.

const PULSE_SHADER := preload("res://shaders/pulse.gdshader")

var origin: Vector3
var max_radius := 14.0
var speed := 18.0
var radius := 0.0
var primary := true
var color := Color(0.25, 0.95, 1.0)
var _hit: Dictionary = {}
var _mesh: MeshInstance3D
var _mat: ShaderMaterial
var _fade_t := 0.0


static func spawn(parent: Node, at: Vector3, max_r: float, is_primary: bool) -> PulseWave:
	var w := PulseWave.new()
	w.origin = at
	w.max_radius = max_r
	w.primary = is_primary
	parent.add_child(w)
	w.global_position = at
	return w


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = 48
	s.rings = 24
	_mesh.mesh = s
	_mat = ShaderMaterial.new()
	_mat.shader = PULSE_SHADER
	_mat.set_shader_parameter("color", color)
	_mesh.material_override = _mat
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.scale = Vector3.ONE * 0.01
	add_child(_mesh)


func _process(delta: float) -> void:
	radius += speed * delta * lerpf(1.4, 0.7, radius / max_radius)
	var done := radius >= max_radius
	radius = minf(radius, max_radius)
	_mesh.scale = Vector3.ONE * maxf(radius, 0.01)
	var f := 1.0 - pow(radius / max_radius, 3.0)
	_mat.set_shader_parameter("fade", f)
	if primary:
		RenderingServer.global_shader_parameter_set("echo_origin", origin)
		RenderingServer.global_shader_parameter_set("echo_radius", radius)
		RenderingServer.global_shader_parameter_set("echo_strength", f)

	for n in get_tree().get_nodes_in_group("echo_reactive"):
		if _hit.has(n):
			continue
		var n3 := n as Node3D
		if n3 == null:
			continue
		var p: Vector3 = n3.call("echo_point") if n3.has_method("echo_point") else n3.global_position
		if p.distance_to(origin) <= radius + 0.5:
			_hit[n] = true
			n3.call("on_echo", origin, self)

	if done:
		if primary:
			RenderingServer.global_shader_parameter_set("echo_strength", 0.0)
		queue_free()
