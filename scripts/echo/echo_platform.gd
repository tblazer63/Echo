class_name EchoPlatform
extends StaticBody3D
## A hidden platform. Revealed and solid for `active_time` seconds after an echo
## reaches it, blinking as a warning before it fades away.

const REVEAL_SHADER := preload("res://shaders/reveal.gdshader")
const WARN_TIME := 1.6

@export var size := Vector3(3, 0.4, 3)
@export var active_time := 6.5

var _timer := 0.0
var _reveal := 0.0
var _mat: ShaderMaterial
var _mesh: MeshInstance3D
var _col: CollisionShape3D
var _last_tick := -1


func _ready() -> void:
	add_to_group("echo_reactive")
	_mesh = MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	_mesh.mesh = b
	_mat = ShaderMaterial.new()
	_mat.shader = REVEAL_SHADER
	_mat.set_shader_parameter("half_size", size * 0.5)
	_mat.set_shader_parameter("grid_size", 0.5)
	_mesh.material_override = _mat
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.visible = false
	add_child(_mesh)
	_col = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	_col.shape = shape
	_col.disabled = true
	add_child(_col)


func on_echo(_origin: Vector3, _wave: Node) -> void:
	var was_hidden := _timer <= 0.0
	_timer = active_time
	_col.set_deferred("disabled", false)
	if was_hidden:
		Sfx.play("reveal", -10.0, randf_range(0.9, 1.15))
		# Springy pop-in so the reveal reads instantly.
		_mesh.scale = Vector3(0.6, 0.2, 0.6)
		var tw := create_tween()
		tw.tween_property(_mesh, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func is_active() -> bool:
	return _timer > 0.0


func _process(delta: float) -> void:
	if _timer > 0.0:
		_timer -= delta
		_reveal = minf(_reveal + delta * 4.0, 1.0)
		var warn := _timer < WARN_TIME
		_mat.set_shader_parameter("blink", 1.0 if warn else 0.0)
		if warn:
			var tick := int(_timer * 4.0)
			if tick != _last_tick:
				_last_tick = tick
				if _player_near():
					Sfx.play("tick", -12.0)
					Game.prompt("Paths are fading — pulse again to keep them solid", 3.5, "refresh_hint")
		if _timer <= 0.0:
			_col.set_deferred("disabled", true)
	else:
		_reveal = maxf(_reveal - delta * 2.5, 0.0)
		_mat.set_shader_parameter("blink", 0.0)
	_mat.set_shader_parameter("reveal", _reveal)
	_mesh.visible = _reveal > 0.001


func _player_near() -> bool:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	return p != null and p.global_position.distance_to(global_position) < 6.0
