class_name HoloDecor
extends MeshInstance3D
## Decorative hidden structure: faintly visible, flares up when an echo passes.

const REVEAL_SHADER := preload("res://shaders/reveal.gdshader")

@export var base_reveal := 0.18
var half_size := Vector3.ONE
var _mat: ShaderMaterial
var _flare := 0.0


func _ready() -> void:
	add_to_group("echo_reactive")
	_mat = ShaderMaterial.new()
	_mat.shader = REVEAL_SHADER
	_mat.set_shader_parameter("half_size", half_size)
	_mat.set_shader_parameter("grid_size", 1.0)
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func on_echo(_origin: Vector3, _wave: Node) -> void:
	_flare = 1.0


func _process(delta: float) -> void:
	_flare = maxf(_flare - delta * 0.35, 0.0)
	_mat.set_shader_parameter("reveal", clampf(base_reveal + _flare * 0.8, 0.0, 1.0))
