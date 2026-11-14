class_name TriggerZone
extends Area3D
## Box trigger that runs a callback once when the player enters.

var size := Vector3(4, 4, 4)
var callback: Callable
var once := true
var _fired := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # player
	var col := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	col.shape = s
	add_child(col)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if once and _fired:
		return
	_fired = true
	if callback.is_valid():
		callback.call()
