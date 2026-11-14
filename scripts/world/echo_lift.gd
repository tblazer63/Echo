class_name EchoLift
extends AnimatableBody3D
## Cooperative elevator: rises while its linked switch is held (by your echo),
## sinks back when released. You can't hold the switch and ride at once.

const SPEED := 2.4

var sw: PressureSwitch
var rise := 8.0
var base_y := 0.0
var _mat: StandardMaterial3D
var _was_up := false


func _init() -> void:
	collision_layer = 1
	collision_mask = 0
	sync_to_physics = true


func _ready() -> void:
	base_y = position.y
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(3.0, 0.4, 3.0)
	col.shape = bs
	col.position.y = -0.2
	add_child(col)
	Builders._box(self, Vector3(3.0, 0.4, 3.0), Vector3(0, -0.2, 0), Builders.stone_material(0.1), false)
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Game.ECHO_CYAN
	_mat.emission_enabled = true
	_mat.emission = Game.ECHO_CYAN
	_mat.emission_energy_multiplier = 0.6
	for s in [-1.0, 1.0]:
		Builders._box(self, Vector3(3.05, 0.1, 0.12), Vector3(0, 0.02, s * 1.47), _mat, false)
		Builders._box(self, Vector3(0.12, 0.1, 3.05), Vector3(s * 1.47, 0.02, 0), _mat, false)


func is_up() -> bool:
	return position.y > base_y + rise - 0.3


func _physics_process(delta: float) -> void:
	var up := sw != null and sw.is_pressed()
	if up != _was_up:
		_was_up = up
		Sfx.play("bridge", -10.0)
	position.y = move_toward(position.y, base_y + (rise if up else 0.0), SPEED * delta)
	_mat.emission_energy_multiplier = lerpf(_mat.emission_energy_multiplier, 3.0 if up else 0.6, clampf(delta * 5.0, 0.0, 1.0))
