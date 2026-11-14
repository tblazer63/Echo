class_name EchoEmitter
extends Node3D
## The Resonance Gauntlet's power source: shared Echo Energy for every ability.
## Energy regenerates quickly, so the player can never be soft-locked.

signal pulsed
signal fired

const MAX_ENERGY := 100.0
const REGEN := 30.0
const REGEN_DELAY := 0.4
const PULSE_COST := 30.0
const PULSE_COOLDOWN := 1.0
const BOLT_COST := 8.0
const BOLT_INTERVAL := 0.22
const DASH_COST := 20.0

@export var max_radius := 14.0

var energy := MAX_ENERGY
var _since_use := 10.0
var _pulse_cd := 0.0
var _bolt_cd := 0.0

## 0..1 view of energy (HUD + QA). Setting it refills energy and clears cooldowns.
var charge: float:
	get:
		return energy / MAX_ENERGY
	set(v):
		energy = clampf(v, 0.0, 1.0) * MAX_ENERGY
		_pulse_cd = 0.0
		_bolt_cd = 0.0


func _process(delta: float) -> void:
	_since_use += delta
	_pulse_cd = maxf(_pulse_cd - delta, 0.0)
	_bolt_cd = maxf(_bolt_cd - delta, 0.0)
	if _since_use > REGEN_DELAY:
		energy = minf(energy + REGEN * delta, MAX_ENERGY)


func spend(amount: float) -> bool:
	if energy < amount:
		Sfx.play("tick", -8.0, 0.7)
		return false
	energy -= amount
	_since_use = 0.0
	return true


func try_pulse() -> bool:
	if _pulse_cd > 0.0:
		Sfx.play("tick", -8.0, 0.7)
		return false
	if not spend(PULSE_COST):
		return false
	_pulse_cd = PULSE_COOLDOWN
	var origin := (get_parent() as Node3D).global_position + Vector3.UP * 1.0
	PulseWave.spawn(get_tree().current_scene, origin, max_radius, true)
	Sfx.play("pulse", -2.0, randf_range(0.96, 1.04))
	pulsed.emit()
	return true


## Fires a Sonic Bolt from the camera along its forward axis.
func try_fire(cam: Camera3D, muzzle: Vector3) -> bool:
	if _bolt_cd > 0.0:
		return false
	if not spend(BOLT_COST):
		return false
	_bolt_cd = BOLT_INTERVAL
	var dir := -cam.global_basis.z
	# Aim converges on whatever the crosshair points at.
	var space := cam.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position + dir * 120.0, 1 | 8)
	var hit := space.intersect_ray(q)
	var target: Vector3 = hit.position if hit else cam.global_position + dir * 120.0
	SonicBolt.fire(get_tree().current_scene, muzzle, (target - muzzle).normalized())
	Sfx.play("bolt", -6.0, randf_range(0.95, 1.08))
	fired.emit()
	return true
