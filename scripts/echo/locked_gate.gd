class_name LockedGate
extends StaticBody3D
## Barred stone gate that opens when `unlock()` is called (e.g. by an EchoRelay).

signal unlocked

@export var width := 3.6
@export var height := 4.4

var is_open := false
var _bars: Node3D
var _lock_mat: StandardMaterial3D
var _col: CollisionShape3D


func _ready() -> void:
	var stone := Builders.stone_material(0.5)
	for side in [-1.0, 1.0]:
		var p := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(1.0, height + 1.2, 1.2)
		b.subdivide_height = 4
		p.mesh = b
		p.material_override = stone
		p.position = Vector3(side * (width * 0.5 + 0.5), (height + 1.2) * 0.5, 0)
		add_child(p)
		var pc := CollisionShape3D.new()
		var ps := BoxShape3D.new()
		ps.size = b.size
		pc.shape = ps
		pc.position = p.position
		add_child(pc)
	var lintel := MeshInstance3D.new()
	var lb := BoxMesh.new()
	lb.size = Vector3(width + 2.6, 1.0, 1.4)
	lintel.mesh = lb
	lintel.material_override = stone
	lintel.position = Vector3(0, height + 1.0, 0)
	add_child(lintel)

	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.13, 0.2, 0.27)
	metal.metallic = 0.7
	metal.roughness = 0.35
	metal.emission_enabled = true
	metal.emission = Color(0.1, 0.5, 0.6)
	metal.emission_energy_multiplier = 0.3
	_bars = Node3D.new()
	add_child(_bars)
	var n := 7
	for i in n:
		var bar := MeshInstance3D.new()
		var bb := BoxMesh.new()
		bb.size = Vector3(0.14, height, 0.14)
		bar.mesh = bb
		bar.material_override = metal
		bar.position = Vector3(-width * 0.5 + (i + 0.5) * width / n, height * 0.5, 0)
		_bars.add_child(bar)
	for y in [0.8, height - 0.6]:
		var rail := MeshInstance3D.new()
		var rb := BoxMesh.new()
		rb.size = Vector3(width, 0.16, 0.2)
		rail.mesh = rb
		rail.material_override = metal
		rail.position = Vector3(0, y, 0)
		_bars.add_child(rail)
	# Lock emblem.
	_lock_mat = StandardMaterial3D.new()
	_lock_mat.albedo_color = Color(1.0, 0.75, 0.35)
	_lock_mat.emission_enabled = true
	_lock_mat.emission = Color(1.0, 0.65, 0.25)
	_lock_mat.emission_energy_multiplier = 2.5
	var lock := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(0.7, 0.6, 0.3)
	lock.mesh = lm
	lock.material_override = _lock_mat
	lock.position = Vector3(0, height * 0.5, 0.05)
	_bars.add_child(lock)
	var shackle := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.18
	tm.outer_radius = 0.27
	shackle.mesh = tm
	shackle.material_override = _lock_mat
	shackle.rotation.x = deg_to_rad(90)
	shackle.position = Vector3(0, height * 0.5 + 0.35, 0.05)
	_bars.add_child(shackle)

	_col = CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = Vector3(width, height, 0.6)
	_col.shape = s
	_col.position.y = height * 0.5
	add_child(_col)


func beam_point() -> Vector3:
	return global_position + Vector3.UP * height * 0.5


func unlock() -> void:
	if is_open:
		return
	is_open = true
	_lock_mat.emission = Game.ECHO_CYAN
	_lock_mat.albedo_color = Game.ECHO_CYAN
	_lock_mat.emission_energy_multiplier = 8.0
	Sfx.play("gate", 0.0)
	PulseWave.spawn(get_tree().current_scene, beam_point(), 4.0, false)
	var tw := create_tween()
	tw.tween_interval(0.4)
	tw.tween_property(_bars, "position:y", -height - 0.5, 1.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		_col.disabled = true
		_bars.visible = false)
	unlocked.emit()
