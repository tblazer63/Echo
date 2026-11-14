class_name ShieldPylon
extends StaticBody3D
## Corrupted pylon that powers the Sentinel's shield. Broken by the player's
## Echo Scan or by two Sonic Bolts. Reset when the Sentinel re-forms its shield.

signal state_changed(active: bool)

const DISSONANCE := Color(0.95, 0.25, 0.85)
const MAX_HP := 40.0
const CRYSTAL_Y := 3.9

var active := true
var target: Node3D
var hp := MAX_HP
var _crystal: MeshInstance3D
var _crystal_mat: StandardMaterial3D
var _beam: MeshInstance3D
var _beam_mat: StandardMaterial3D


func _ready() -> void:
	add_to_group("echo_reactive")
	collision_layer = 1 | 8
	collision_mask = 0
	var stone := Builders.stone_material(0.3)
	Builders._box(self, Vector3(1.6, 0.4, 1.6), Vector3(0, 0.2, 0), stone)
	Builders._box(self, Vector3(0.9, 2.8, 0.9), Vector3(0, 1.8, 0), stone)
	Builders._box(self, Vector3(1.3, 0.3, 1.3), Vector3(0, 3.3, 0), stone)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.4, 4.6, 1.4)
	col.shape = shape
	col.position.y = 2.3
	add_child(col)

	_crystal_mat = StandardMaterial3D.new()
	_crystal_mat.albedo_color = DISSONANCE
	_crystal_mat.emission_enabled = true
	_crystal_mat.emission = DISSONANCE
	_crystal_mat.emission_energy_multiplier = 2.5
	_crystal = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.38
	cm.height = 1.1
	cm.radial_segments = 6
	cm.rings = 1
	_crystal.mesh = cm
	_crystal.material_override = _crystal_mat
	_crystal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_crystal.position.y = CRYSTAL_Y
	add_child(_crystal)
	var bottom := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.38
	bm.bottom_radius = 0.0
	bm.height = 0.6
	bm.radial_segments = 6
	bm.rings = 1
	bottom.mesh = bm
	bottom.position.y = -0.85
	bottom.material_override = _crystal_mat
	_crystal.add_child(bottom)

	_beam_mat = StandardMaterial3D.new()
	_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_beam_mat.albedo_color = Color(0.9, 0.3, 0.85)
	_beam = MeshInstance3D.new()
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 0.06
	beam_mesh.bottom_radius = 0.06
	beam_mesh.height = 1.0
	beam_mesh.radial_segments = 6
	beam_mesh.rings = 1
	_beam.mesh = beam_mesh
	_beam.material_override = _beam_mat
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.top_level = true
	_beam.visible = false
	add_child(_beam)


func echo_point() -> Vector3:
	return global_position + Vector3.UP * CRYSTAL_Y


func _process(delta: float) -> void:
	if active:
		_crystal.rotation.y += delta * 1.5
		_crystal.position.y = CRYSTAL_Y + sin(Time.get_ticks_msec() * 0.003) * 0.12
	var show: bool = active and target != null and is_instance_valid(target) and target.is_inside_tree() \
		and target.get("active") == true
	_beam.visible = show
	if show:
		var a := _crystal.global_position
		var b := target.global_position
		var len := a.distance_to(b)
		if len < 0.1:
			_beam.visible = false
			return
		var dir := (b - a) / len
		var axis := Vector3.UP.cross(dir)
		var basis := Basis.IDENTITY
		if axis.length() > 0.001:
			basis = Basis(axis.normalized(), Vector3.UP.angle_to(dir))
		_beam.global_transform = Transform3D(basis.scaled(Vector3(1.0 + 0.4 * sin(Time.get_ticks_msec() * 0.02), len, 1.0)), (a + b) * 0.5)


func on_echo(_origin: Vector3, wave: Node) -> void:
	if active and wave is PulseWave and (wave as PulseWave).primary:
		disable()


func take_damage(amount: float, _hit_pos: Vector3) -> void:
	if not active:
		return
	hp -= amount
	_crystal_mat.emission_energy_multiplier = 8.0
	create_tween().tween_property(_crystal_mat, "emission_energy_multiplier", 2.5, 0.25)
	if hp <= 0.0:
		disable()


func disable() -> void:
	if not active:
		return
	active = false
	_crystal_mat.albedo_color = Color(0.35, 0.36, 0.4)
	_crystal_mat.emission = Color(0.1, 0.1, 0.12)
	_crystal_mat.emission_energy_multiplier = 0.2
	_beam.visible = false
	Sfx.play("shatter", -4.0)
	var tw := create_tween()
	_crystal.scale = Vector3.ONE * 1.4
	tw.tween_property(_crystal, "scale", Vector3.ONE * 0.75, 0.35).set_trans(Tween.TRANS_BACK)
	state_changed.emit(false)


func reset_pylon() -> void:
	hp = MAX_HP
	if active:
		return
	active = true
	_crystal_mat.albedo_color = DISSONANCE
	_crystal_mat.emission = DISSONANCE
	_crystal_mat.emission_energy_multiplier = 2.5
	_crystal.scale = Vector3.ONE
	state_changed.emit(true)
