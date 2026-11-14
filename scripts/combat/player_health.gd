class_name PlayerHealth
extends Node
## Player hit points: post-hit i-frames, external invulnerability (dash) and
## delayed regeneration.

signal changed(hp: float, max_hp: float)
signal damaged(amount: float, from_pos: Vector3)
signal died

const HIT_IFRAMES := 0.8
const REGEN_DELAY := 4.0
const REGEN_RATE := 8.0

var max_hp := 100.0
var hp := 100.0
## Set externally (e.g. dash). Counts down by itself; damage ignored while > 0.
var invulnerable_timer := 0.0
var dead := false
var _iframes := 0.0
var _since_hit := 99.0


func _ready() -> void:
	hp = max_hp


func _process(delta: float) -> void:
	_iframes = maxf(_iframes - delta, 0.0)
	invulnerable_timer = maxf(invulnerable_timer - delta, 0.0)
	_since_hit += delta
	if not dead and hp < max_hp and _since_hit >= REGEN_DELAY:
		hp = minf(hp + REGEN_RATE * delta, max_hp)
		changed.emit(hp, max_hp)


func damage(amount: float, from_pos: Vector3) -> void:
	if dead or amount <= 0.0 or _iframes > 0.0 or invulnerable_timer > 0.0 or Game.won:
		return
	hp = maxf(hp - amount, 0.0)
	_iframes = HIT_IFRAMES
	_since_hit = 0.0
	Sfx.play("hurt", -3.0, randf_range(0.92, 1.08))
	damaged.emit(amount, from_pos)
	changed.emit(hp, max_hp)
	if hp <= 0.0 and not dead:
		dead = true
		died.emit()


func heal_full() -> void:
	hp = max_hp
	dead = false
	_iframes = 0.0
	_since_hit = 99.0
	changed.emit(hp, max_hp)


func grant_iframes(seconds: float) -> void:
	_iframes = maxf(_iframes, seconds)


func is_dead() -> bool:
	return dead


func ratio() -> float:
	return hp / max_hp if max_hp > 0.0 else 0.0
