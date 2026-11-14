class_name PhantomDrone
extends EchoDrone
## Cloaked variant of EchoDrone. Nearly invisible (and immune) until an echo
## reveals it for a few seconds; blinks sideways while hunting the player.

const REVEAL_TIME := 4.0
const BLINK_INTERVAL := 3.5
const CLOAK_ALPHA := 0.08
const VIOLET := Color(0.62, 0.32, 1.0)

var _reveal_t := 0.0
var _blink_t := BLINK_INTERVAL
var _kick := 0.0
var _alpha := 1.0
var _transparent := false


func _ready() -> void:
	super._ready()
	add_to_group("phantom")
	detect_range = 22.0
	attack_interval = 2.0
	max_hp = 40.0
	hp = max_hp
	_body_mat.albedo_color = Color(0.17, 0.1, 0.26)
	_ring_mat.albedo_color = VIOLET
	_ring_mat.emission = VIOLET
	_eye_mat.albedo_color = VIOLET.lerp(DISSONANCE, 0.5)
	_eye_mat.emission = VIOLET.lerp(DISSONANCE, 0.5)
	_blink_t = randf_range(2.0, BLINK_INTERVAL)
	_alpha = CLOAK_ALPHA
	_apply_alpha(CLOAK_ALPHA)
	_update_bar()


func is_revealed() -> bool:
	return _reveal_t > 0.0 or is_defeated()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_reveal_t = maxf(_reveal_t - delta, 0.0)
	if state == State.ALERT and not is_revealed():
		_blink_t -= delta
		if _blink_t <= 0.0 and _tele_t < 0.0:
			_blink_t = BLINK_INTERVAL + randf_range(-0.4, 0.4)
			_blink()
	else:
		_blink_t = maxf(_blink_t, 1.2)


func _blink() -> void:
	var p := _get_player()
	if p == null:
		return
	var to_p := p.global_position - global_position
	to_p.y = 0.0
	if to_p.length() < 0.1:
		to_p = Vector3.FORWARD
	var side := to_p.normalized().cross(Vector3.UP)
	var dist := randf_range(3.0, 5.0)
	var sgn := 1.0 if randf() < 0.5 else -1.0
	var space := get_world_3d().direct_space_state
	for _attempt in 2:
		var target := global_position + side * dist * sgn
		var off := target - home
		if off.length() > leash:
			target = home + off.normalized() * leash
		target.y = global_position.y
		var dir := target - global_position
		if dir.length() < 1.0:
			sgn = -sgn
			continue
		var q := PhysicsRayQueryParameters3D.create(global_position, target + dir.normalized() * 0.8, 1)
		q.collide_with_areas = false
		if space.intersect_ray(q).is_empty():
			_burst(global_position)
			global_position = target
			velocity = Vector3.ZERO
			_burst(target)
			_kick = 0.5
			Sfx.play("dash", -10.0, 1.5)
			return
		sgn = -sgn


func _burst(at: Vector3) -> void:
	var parent: Node = get_tree().current_scene
	if parent == null:
		parent = get_parent()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(DISSONANCE.r, DISSONANCE.g, DISSONANCE.b, 0.6)
	var s := SphereMesh.new()
	s.radius = 0.4
	s.height = 0.8
	s.radial_segments = 12
	s.rings = 6
	var m := MeshInstance3D.new()
	m.mesh = s
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	m.global_position = at
	var tw := m.create_tween().set_parallel(true)
	tw.tween_property(m, "scale", Vector3.ONE * 2.4, 0.35)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tw.chain().tween_callback(m.queue_free)


func on_echo(origin: Vector3, wave: Node) -> void:
	if is_defeated():
		return
	super.on_echo(origin, wave)
	_reveal_t = REVEAL_TIME
	Game.prompt("Phantoms are revealed by your Echo Scan!", 3.0, "phantom_hint")


func take_damage(amount: float, hit_pos: Vector3) -> void:
	if is_defeated():
		return
	if not is_revealed():
		# Cloaked: the hit slides through. Tiny shimmer + tick as feedback.
		_kick = 0.35
		_aggro_t = 6.0
		if state == State.PATROL:
			_enter_alert()
		Sfx.play("tick", -8.0, 1.6)
		Game.prompt("Phantoms are revealed by your Echo Scan!", 3.0, "phantom_hint")
		return
	super.take_damage(amount, hit_pos)


## Respawn reset: also re-cloak.
func reset_drone() -> void:
	super.reset_drone()
	if is_defeated():
		return
	_reveal_t = 0.0
	_kick = 0.0
	_blink_t = randf_range(2.0, BLINK_INTERVAL)


func _defeat() -> void:
	_reveal_t = 0.0
	_alpha = 1.0
	_apply_alpha(1.0)
	super._defeat()


func _process(delta: float) -> void:
	super._process(delta)
	_kick = move_toward(_kick, 0.0, delta * 1.5)
	var target_a := 1.0
	if not is_revealed():
		target_a = CLOAK_ALPHA + absf(sin(_t * 6.0)) * 0.05 + _kick
	_alpha = move_toward(_alpha, target_a, delta * 4.0)
	_apply_alpha(_alpha)
	if not is_defeated():
		_bar_root.visible = is_revealed() and hp < max_hp


func _apply_alpha(a: float) -> void:
	var want := a < 0.99
	var mats: Array[StandardMaterial3D] = [_body_mat, _ring_mat, _eye_mat, _core_mat]
	if want != _transparent:
		_transparent = want
		for m in mats:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if want else BaseMaterial3D.TRANSPARENCY_DISABLED
		# Body + fins are the only shadow casters; hide their shadow while cloaked.
		if _visual != null:
			for n in _visual.find_children("*", "MeshInstance3D", true, false):
				var mi := n as MeshInstance3D
				if mi != null and mi.material_override == _body_mat:
					mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if want else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var av := a if want else 1.0
	for m in mats:
		m.albedo_color.a = av
