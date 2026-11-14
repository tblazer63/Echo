class_name Checkpoint
extends Area3D
## Saves the respawn point when the player enters. Shows a glowing floor ring.

@export var yaw := 0.0
var _mat: StandardMaterial3D
var _active := false


func _ready() -> void:
	var col := CollisionShape3D.new()
	var s := CylinderShape3D.new()
	s.radius = 1.8
	s.height = 3.0
	col.shape = s
	col.position.y = 1.5
	add_child(col)
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Game.ECHO_CYAN
	_mat.emission_enabled = true
	_mat.emission = Game.ECHO_CYAN
	_mat.emission_energy_multiplier = 0.4
	for r in [0.9, 1.5]:
		var ring := MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = r
		t.outer_radius = r + 0.08
		ring.mesh = t
		ring.scale.y = 0.2
		ring.material_override = _mat
		ring.position.y = 0.04
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player") or _active:
		return
	_active = true
	Game.set_checkpoint(global_position + Vector3.UP * 0.3, yaw)
	Sfx.play("checkpoint", -6.0)
	var tw := create_tween()
	tw.tween_property(_mat, "emission_energy_multiplier", 5.0, 0.15)
	tw.tween_property(_mat, "emission_energy_multiplier", 1.6, 0.8)
