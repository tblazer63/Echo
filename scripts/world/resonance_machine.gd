class_name ResonanceMachine
extends StaticBody3D
## Ancient resonance engine: a stone pedestal with a floating crystal and two
## gyroscopic rings. Once `enabled`, an echo reaching the crystal activates it.

signal activated_signal

const CRYSTAL_Y := 3.0

var enabled := false
var activated := false
var _crystal: Node3D
var _crystal_mat: StandardMaterial3D
var _ring_mat: StandardMaterial3D
var _rings: Array[MeshInstance3D] = []
var _light: OmniLight3D
var _glow := 0.3
var _spin := 0.5
var _t := 0.0


func _ready() -> void:
	add_to_group("echo_reactive")
	collision_layer = 1
	var stone := Builders.stone_material(0.5)
	Builders._box(self, Vector3(2.4, 0.5, 2.4), Vector3(0, 0.25, 0), stone)
	Builders._box(self, Vector3(1.5, 1.3, 1.5), Vector3(0, 1.15, 0), stone)
	Builders._box(self, Vector3(1.9, 0.3, 1.9), Vector3(0, 1.95, 0), stone)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.4, 2.1, 2.4)
	col.shape = shape
	col.position.y = 1.05
	add_child(col)

	# Floating crystal: two tapered hexagonal prisms.
	_crystal_mat = StandardMaterial3D.new()
	_crystal_mat.albedo_color = Color(0.55, 0.95, 1.0)
	_crystal_mat.roughness = 0.15
	_crystal_mat.metallic = 0.2
	_crystal_mat.emission_enabled = true
	_crystal_mat.emission = Game.ECHO_CYAN
	_crystal_mat.emission_energy_multiplier = _glow
	_crystal = Node3D.new()
	_crystal.position.y = CRYSTAL_Y
	add_child(_crystal)
	_prism(0.02, 0.38, 1.0, 0.5)
	_prism(0.38, 0.02, 0.6, -0.3)

	_ring_mat = StandardMaterial3D.new()
	_ring_mat.albedo_color = Color(0.2, 0.35, 0.4)
	_ring_mat.metallic = 0.6
	_ring_mat.roughness = 0.3
	_ring_mat.emission_enabled = true
	_ring_mat.emission = Game.ECHO_CYAN
	_ring_mat.emission_energy_multiplier = 0.8
	for i in 2:
		var r := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.95 + i * 0.32
		tm.outer_radius = 1.05 + i * 0.32
		tm.rings = 32
		tm.ring_segments = 6
		r.mesh = tm
		r.material_override = _ring_mat
		r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		r.position.y = CRYSTAL_Y
		r.rotation = Vector3(0.45, 0.0, 0.0) if i == 0 else Vector3(0.0, 0.0, 0.6)
		add_child(r)
		_rings.append(r)

	_light = OmniLight3D.new()
	_light.light_color = Game.ECHO_CYAN
	_light.omni_range = 6.0
	_light.light_energy = 0.2
	_light.shadow_enabled = false
	_light.position.y = CRYSTAL_Y
	add_child(_light)


func _prism(top_r: float, bottom_r: float, h: float, y: float) -> void:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = top_r
	c.bottom_radius = bottom_r
	c.height = h
	c.radial_segments = 6
	c.rings = 1
	m.mesh = c
	m.material_override = _crystal_mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position.y = y
	_crystal.add_child(m)


func _process(delta: float) -> void:
	_t += delta
	var target_spin := 4.5 if activated else 0.5
	_spin = lerpf(_spin, target_spin, clampf(delta * 1.5, 0.0, 1.0))
	_rings[0].rotate_y(_spin * delta)
	_rings[1].rotate_x(_spin * 0.8 * delta)
	_crystal.position.y = CRYSTAL_Y + sin(_t * 1.6) * 0.12
	_crystal.rotate_y(delta * (0.3 + _spin * 0.4))
	var target_glow: float
	if activated:
		target_glow = 3.0 + sin(_t * 3.0) * 0.6
	elif enabled:
		target_glow = 0.6 + 0.3 * sin(_t * 2.5)
	else:
		target_glow = 0.3
	_glow = lerpf(_glow, target_glow, clampf(delta * 2.5, 0.0, 1.0))
	_crystal_mat.emission_energy_multiplier = _glow
	_ring_mat.emission_energy_multiplier = 0.5 + _glow * 0.6
	_light.light_energy = _glow * 0.4


func echo_point() -> Vector3:
	if _crystal != null and _crystal.is_inside_tree():
		return _crystal.global_position
	return global_position + Vector3.UP * CRYSTAL_Y


func on_echo(_origin: Vector3, _wave: Node) -> void:
	if not enabled:
		return
	if activated:
		return
	# Only the player's own Echo Scan wakes the machine (not gate/relay waves).
	if _wave is PulseWave and not (_wave as PulseWave).primary:
		return
	_activate()


## QA / debug: activates regardless of `enabled`.
func force_activate() -> void:
	if activated:
		return
	_activate()


func _activate() -> void:
	activated = true
	_glow = 9.0
	_spin = 9.0
	Sfx.play("relay", -1.0)
	var wave_parent: Node = get_tree().current_scene
	if wave_parent == null:
		wave_parent = get_parent()
	if wave_parent != null:
		PulseWave.spawn(wave_parent, echo_point(), 5.0, false)
	_crystal.scale = Vector3.ONE * 1.6
	var tw := create_tween()
	tw.tween_property(_crystal, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	activated_signal.emit()
