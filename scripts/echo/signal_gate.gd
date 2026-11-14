class_name SignalGate
extends Node3D
## The level exit: a giant ring gate. Restores itself when the player reaches it.

signal restored

var _outer: Node3D
var _inner: Node3D
var _core_mat: StandardMaterial3D
var _beam: MeshInstance3D
var _light: OmniLight3D
var _spin := 0.08
var _power := 0.35
var _target_power := 0.35
var _rune_mat: StandardMaterial3D
var _area: Area3D


func _ready() -> void:
	var stone := Builders.stone_material(0.25)
	_rune_mat = StandardMaterial3D.new()
	_rune_mat.albedo_color = Game.ECHO_CYAN
	_rune_mat.emission_enabled = true
	_rune_mat.emission = Game.ECHO_CYAN
	_rune_mat.emission_energy_multiplier = 1.5

	# Stepped base.
	for i in 3:
		var step := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(12.0 - i * 2.5, 0.5, 5.0 - i * 1.0)
		step.mesh = b
		step.material_override = stone
		step.position = Vector3(0, 0.25 + i * 0.5, 0)
		add_child(step)

	# Outer ring (segmented stone blocks).
	_outer = Node3D.new()
	_outer.position.y = 7.0
	add_child(_outer)
	# Ring blocks + runes as two MultiMeshes (2 draw calls instead of 40).
	var seg := 22
	var slots: Array[int] = []
	for i in seg:
		if i != 5 and i != 16:  # broken gaps like the concept art
			slots.append(i)
	var bm := BoxMesh.new()
	bm.size = Vector3(1.55, 1.1, 1.3)
	var rm := BoxMesh.new()
	rm.size = Vector3(0.18, 0.5, 0.06)
	var blocks := MultiMesh.new()
	blocks.transform_format = MultiMesh.TRANSFORM_3D
	blocks.mesh = bm
	blocks.instance_count = slots.size()
	var runes := MultiMesh.new()
	runes.transform_format = MultiMesh.TRANSFORM_3D
	runes.mesh = rm
	runes.instance_count = slots.size()
	for k in slots.size():
		var a := TAU * slots[k] / seg
		var b := Basis(Vector3.BACK, a + PI * 0.5)
		var p := Vector3(cos(a), sin(a), 0) * 6.2
		blocks.set_instance_transform(k, Transform3D(b, p))
		runes.set_instance_transform(k, Transform3D(b, p + Vector3(0, 0, 0.66)))
	var bmi := MultiMeshInstance3D.new()
	bmi.multimesh = blocks
	bmi.material_override = stone
	_outer.add_child(bmi)
	var rmi := MultiMeshInstance3D.new()
	rmi.multimesh = runes
	rmi.material_override = _rune_mat
	rmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_outer.add_child(rmi)

	# Inner glowing ring.
	_inner = Node3D.new()
	_inner.position.y = 7.0
	add_child(_inner)
	var tor := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 4.3
	tm.outer_radius = 4.6
	tm.rings = 64
	tor.mesh = tm
	tor.material_override = _rune_mat
	tor.rotation.x = deg_to_rad(90)
	_inner.add_child(tor)
	for i in 3:
		var spoke := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.12, 4.4, 0.12)
		spoke.mesh = sm
		spoke.material_override = _rune_mat
		spoke.rotation.z = TAU * i / 3.0
		spoke.position = Vector3(0, 0, 0)
		var holder := Node3D.new()
		holder.rotation.z = TAU * i / 3.0
		_inner.add_child(holder)
		spoke.rotation.z = 0
		spoke.position = Vector3(0, 2.2, 0)
		holder.add_child(spoke)

	# Core orb.
	_core_mat = StandardMaterial3D.new()
	_core_mat.albedo_color = Color(0.8, 1, 1)
	_core_mat.emission_enabled = true
	_core_mat.emission = Game.ECHO_CYAN
	_core_mat.emission_energy_multiplier = 2.0
	var core := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.7
	sp.height = 1.4
	core.mesh = sp
	core.material_override = _core_mat
	core.position.y = 7.0
	add_child(core)

	# Sky beam (appears on restore).
	_beam = MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 0.6
	bc.bottom_radius = 0.6
	bc.height = 400.0
	_beam.mesh = bc
	var bmat := StandardMaterial3D.new()
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bmat.albedo_color = Color(0.4, 0.95, 1.0)
	_beam.material_override = bmat
	_beam.position.y = 207.0
	_beam.scale = Vector3(0.0, 1, 0.0)
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_beam)

	_light = OmniLight3D.new()
	_light.light_color = Game.ECHO_CYAN
	_light.omni_range = 18.0
	_light.light_energy = 0.8
	_light.position = Vector3(0, 7, 2)
	add_child(_light)

	var area := Area3D.new()
	_area = area
	area.collision_layer = 0
	area.collision_mask = 2  # player
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(7, 6, 4)
	col.shape = shape
	area.add_child(col)
	area.position = Vector3(0, 4, 1.5)
	add_child(area)
	area.body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_power = lerpf(_power, _target_power, clampf(delta * 1.5, 0.0, 1.0))
	_outer.rotation.z += delta * _spin * 0.4
	_inner.rotation.z -= delta * _spin
	_core_mat.emission_energy_multiplier = 1.0 + _power * 8.0
	_rune_mat.emission_energy_multiplier = 0.8 + _power * 5.0
	_light.light_energy = _power * 3.0


## While sealed (Sentinel alive) the Spire cannot be restored.
var sealed := false


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player") or Game.won:
		return
	if sealed:
		Game.prompt("The Sentinel's dissonance seals the Spire. Defeat it first!", 3.0)
		return
	restore()


## Re-checks the trigger (player may already be standing inside when unsealed).
func recheck() -> void:
	for b in _area.get_overlapping_bodies():
		_on_body_entered(b)


func restore() -> void:
	_target_power = 1.0
	Sfx.play("win", 0.0)
	Sfx.play("gate", -4.0, 0.7)
	PulseWave.spawn(get_tree().current_scene, global_position + Vector3.UP * 7.0, 40.0, true)
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "_spin", 2.5, 2.0)
	tw.tween_property(_beam, "scale", Vector3(1, 1, 1), 1.2).set_delay(0.6)
	restored.emit()
	Game.win()
