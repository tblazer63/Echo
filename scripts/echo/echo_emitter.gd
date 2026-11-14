class_name EchoEmitter
extends Node3D
## Emits echo pulses with a cooldown. Exposes `charge` (0..1) for the HUD.

signal pulsed

@export var cooldown := 1.2
@export var max_radius := 14.0

var charge := 1.0


func _process(delta: float) -> void:
	charge = minf(charge + delta / cooldown, 1.0)


func try_pulse() -> bool:
	if charge < 1.0:
		Sfx.play("tick", -8.0, 0.7)
		return false
	charge = 0.0
	var origin := (get_parent() as Node3D).global_position + Vector3.UP * 1.0
	PulseWave.spawn(get_tree().current_scene, origin, max_radius, true)
	Sfx.play("pulse", -2.0, randf_range(0.96, 1.04))
	pulsed.emit()
	return true
