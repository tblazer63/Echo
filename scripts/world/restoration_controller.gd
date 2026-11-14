class_name RestorationController
extends Node
## Owns the "Dissonance" corruption of the world (magenta crystals, desaturated
## grade, dry waterfalls, bare islands) and its restoration in `restore()`.

signal restored_signal

const CORRUPT := Color(0.95, 0.25, 0.85)
const FLOWER_COLORS: Array[Color] = [
	Color(0.7, 0.42, 1.0),
	Color(1.0, 1.0, 1.0),
	Color(1.0, 0.86, 0.3),
	Color(0.9, 0.55, 0.95),
]

var restored := false
var env: Environment
var sun: DirectionalLight3D
var _crystal_mat: StandardMaterial3D
var _crystal_mesh: CylinderMesh
var _flower_mesh: ArrayMesh
var _burst_mesh: SphereMesh
## Each: {mmi, mm, base: Array[Transform3D], radius}
var _clusters: Array[Dictionary] = []
## Each: {parent, top, width, height, facing}
var _falls: Array[Dictionary] = []
## Each: {mmi, mm, base: Array[Transform3D], delays: Array[float]}
var _flowers: Array[Dictionary] = []


func setup(e: Environment, s: DirectionalLight3D) -> void:
	env = e
	sun = s
	set_corrupted()


func set_corrupted() -> void:
	if env != null:
		env.adjustment_enabled = true
		env.adjustment_saturation = 0.78
		env.fog_light_color = Color(0.74, 0.72, 0.92)
	if sun != null:
		sun.light_energy = 1.1
		sun.light_color = Color(0.86, 0.88, 1.0)


# ------------------------------------------------------------- registration

## Corruption crystals around the rim of an island whose top surface is at
## `center` (in `parent`'s local space). One MultiMesh (1 draw call) per call.
func add_crystals(parent: Node3D, center: Vector3, radius: float, count: int) -> MultiMeshInstance3D:
	if _crystal_mat == null:
		_crystal_mat = StandardMaterial3D.new()
		_crystal_mat.albedo_color = Color(0.42, 0.1, 0.5)
		_crystal_mat.roughness = 0.25
		_crystal_mat.metallic = 0.2
		_crystal_mat.emission_enabled = true
		_crystal_mat.emission = CORRUPT
		_crystal_mat.emission_energy_multiplier = 1.8
		_crystal_mesh = CylinderMesh.new()
		_crystal_mesh.top_radius = 0.06
		_crystal_mesh.bottom_radius = 0.5
		_crystal_mesh.height = 1.0
		_crystal_mesh.radial_segments = 5
		_crystal_mesh.rings = 1
	count = maxi(count, 1)
	var base: Array[Transform3D] = []
	while base.size() < count:
		var a := randf() * TAU
		var d := radius * randf_range(0.6, 0.95)
		var root := Vector3(cos(a) * d, 0.0, sin(a) * d)
		var clump := mini(randi_range(1, 3), count - base.size())
		for k in clump:
			var h := randf_range(0.6, 2.2) if k == 0 else randf_range(0.6, 1.3)
			var w := h * randf_range(0.28, 0.42)
			var pos := root
			if k > 0:
				pos += Vector3(randf_range(-0.7, 0.7), 0.0, randf_range(-0.7, 0.7))
			var ta := randf() * TAU
			var axis := Vector3(cos(ta), 0.0, sin(ta))
			var b := Basis(axis, randf_range(0.08, 0.5)) * Basis(Vector3.UP, randf() * TAU) * Basis.from_scale(Vector3(w, h, w))
			base.append(Transform3D(b, pos + Vector3.UP * (h * 0.4)))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _crystal_mesh
	mm.instance_count = base.size()
	for i in base.size():
		mm.set_instance_transform(i, base[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _crystal_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)
	mmi.position = center
	_clusters.append({"mmi": mmi, "mm": mm, "base": base, "radius": radius})
	return mmi


## A waterfall that only exists after restoration (built with Builders.waterfall).
func add_waterfall_spot(parent: Node3D, top: Vector3, width: float, height: float, facing: float) -> void:
	_falls.append({"parent": parent, "top": top, "width": width, "height": height, "facing": facing})


## Flower patch (hidden, scale 0) that blooms on restoration. 2 draw calls.
func add_flowers(parent: Node3D, center: Vector3, radius: float, count: int) -> MultiMeshInstance3D:
	if _flower_mesh == null:
		_flower_mesh = _make_flower()
	count = maxi(count, 1)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _flower_mesh
	mm.instance_count = count
	var base: Array[Transform3D] = []
	var delays: Array[float] = []
	for i in count:
		var r := radius * sqrt(randf())
		var a := randf() * TAU
		var s := randf_range(0.7, 1.3)
		var pos := Vector3(cos(a) * r, 0.0, sin(a) * r)
		var tr := Transform3D(Basis(Vector3.UP, randf() * TAU) * Basis.from_scale(Vector3.ONE * s), pos)
		base.append(tr)
		delays.append(randf() * 0.6)
		mm.set_instance_color(i, FLOWER_COLORS[randi() % FLOWER_COLORS.size()])
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * 0.001), pos))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visible = false
	parent.add_child(mmi)
	mmi.position = center
	_flowers.append({"mmi": mmi, "mm": mm, "base": base, "delays": delays})
	return mmi


# ---------------------------------------------------------------- restoring

func restore(spire_pos: Vector3) -> void:
	if restored:
		return
	restored = true
	Sfx.play("shatter")
	get_tree().create_timer(0.35).timeout.connect(func() -> void: Sfx.play("restore"))

	# Crystals flash cyan, burst, and shrink away.
	if _crystal_mat != null:
		var mt := create_tween().set_parallel(true)
		mt.tween_property(_crystal_mat, "emission", Game.ECHO_CYAN, 0.4)
		mt.tween_property(_crystal_mat, "emission_energy_multiplier", 6.0, 0.4)
	for cd in _clusters:
		var mmi: MultiMeshInstance3D = cd["mmi"]
		if not is_instance_valid(mmi):
			continue
		_burst(mmi, float(cd["radius"]))
		var tw := create_tween()
		tw.tween_interval(randf_range(0.0, 0.25))
		tw.tween_method(_scale_cluster.bind(cd), 1.0, 0.0, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_callback(_hide_if_valid.bind(mmi))

	# Colour grade + sun.
	if env != null:
		var et := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		et.tween_property(env, "adjustment_saturation", 1.15, 3.0)
		et.tween_property(env, "fog_light_color", Color(0.72, 0.86, 0.96), 3.0)
	if sun != null:
		var st := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		st.tween_property(sun, "light_energy", 1.4, 3.0)
		st.tween_property(sun, "light_color", Color(1.0, 0.95, 0.86), 3.0)

	# Waterfalls pour down from their lip.
	var delay := 0.6
	for fd in _falls:
		var p: Node3D = fd["parent"]
		if not is_instance_valid(p):
			continue
		var holder := Node3D.new()
		p.add_child(holder)
		holder.position = fd["top"]
		Builders.waterfall(holder, Vector3.ZERO, float(fd["width"]), float(fd["height"]), float(fd["facing"]))
		holder.scale = Vector3(1.0, 0.01, 1.0)
		holder.visible = false
		var wt := create_tween()
		wt.tween_interval(delay)
		wt.tween_callback(holder.show)
		wt.tween_property(holder, "scale", Vector3.ONE, 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		delay += 0.25

	# Flowers bloom, staggered.
	for fl in _flowers:
		var fmmi: MultiMeshInstance3D = fl["mmi"]
		if not is_instance_valid(fmmi):
			continue
		var ft := create_tween()
		ft.tween_interval(1.0 + randf() * 0.6)
		ft.tween_callback(fmmi.show)
		ft.tween_method(_grow_flowers.bind(fl), 0.0, 1.0, 2.6)

	for n in get_tree().get_nodes_in_group("drone"):
		if n.has_method("befriend"):
			n.call("befriend", spire_pos)
	restored_signal.emit()


func _hide_if_valid(n: Node3D) -> void:
	if is_instance_valid(n):
		n.hide()


func _scale_cluster(f: float, cd: Dictionary) -> void:
	var mm: MultiMesh = cd["mm"]
	var base: Array[Transform3D] = cd["base"]
	var s := Basis.from_scale(Vector3.ONE * maxf(f, 0.001))
	for i in base.size():
		var tr := base[i]
		mm.set_instance_transform(i, Transform3D(tr.basis * s, tr.origin))


func _grow_flowers(t: float, fd: Dictionary) -> void:
	var mm: MultiMesh = fd["mm"]
	var base: Array[Transform3D] = fd["base"]
	var delays: Array[float] = fd["delays"]
	for i in base.size():
		var x := clampf((t - delays[i]) / 0.4, 0.0, 1.0)
		var tr := base[i]
		mm.set_instance_transform(i, Transform3D(tr.basis * Basis.from_scale(Vector3.ONE * maxf(_back_out(x), 0.001)), tr.origin))


static func _back_out(x: float) -> float:
	const C1 := 1.70158
	const C3 := C1 + 1.0
	return 1.0 + C3 * pow(x - 1.0, 3.0) + C1 * pow(x - 1.0, 2.0)


func _burst(mmi: MultiMeshInstance3D, radius: float) -> void:
	if _burst_mesh == null:
		_burst_mesh = SphereMesh.new()
		_burst_mesh.radius = 0.1
		_burst_mesh.height = 0.2
		_burst_mesh.radial_segments = 4
		_burst_mesh.rings = 2
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.vertex_color_use_as_albedo = true
		_burst_mesh.material = mat
	var parent := mmi.get_parent()
	if parent == null:
		return
	var p := CPUParticles3D.new()
	p.amount = 30
	p.one_shot = true
	p.explosiveness = 0.85
	p.lifetime = 1.4
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(radius * 0.8, 0.6, radius * 0.8)
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 7.0
	p.gravity = Vector3(0, -4.0, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	p.mesh = _burst_mesh
	var g := Gradient.new()
	g.set_color(0, CORRUPT)
	g.set_color(1, Color(Game.ECHO_CYAN, 0.0))
	g.add_point(0.45, Game.ECHO_CYAN)
	p.color_ramp = g
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.position = mmi.position + Vector3.UP * 0.8
	p.emitting = true
	get_tree().create_timer(2.5).timeout.connect(p.queue_free)


## Small flower: crossed-quad stem (surface 0, green) + star-shaped head
## (surface 1, tinted by the MultiMesh instance colour).
func _make_flower() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := 0.025
	var h := 0.28
	for k in 2:
		var dir := Vector3(1, 0, 0) if k == 0 else Vector3(0, 0, 1)
		var d := dir * w
		var verts := [-d + Vector3.UP * h, d + Vector3.UP * h, d, -d]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP)
			st.add_vertex(verts[idx])
	var mesh := st.commit()

	var hs := SurfaceTool.new()
	hs.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := Vector3(0, h + 0.02, 0)
	var pts := 10
	for i in pts:
		var a0 := TAU * i / pts
		var a1 := TAU * (i + 1) / pts
		var r0 := 0.13 if i % 2 == 0 else 0.05
		var r1 := 0.13 if (i + 1) % 2 == 0 else 0.05
		var p0 := Vector3(cos(a0) * r0, h - 0.01, sin(a0) * r0)
		var p1 := Vector3(cos(a1) * r1, h - 0.01, sin(a1) * r1)
		for v in [c, p0, p1]:
			hs.set_normal(Vector3.UP)
			hs.set_color(Color.WHITE)
			hs.add_vertex(v)
	hs.commit(mesh)

	var stem_mat := StandardMaterial3D.new()
	stem_mat.albedo_color = Color(0.3, 0.6, 0.22)
	stem_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	stem_mat.roughness = 0.9
	var head_mat := StandardMaterial3D.new()
	head_mat.vertex_color_use_as_albedo = true
	head_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	head_mat.roughness = 0.7
	mesh.surface_set_material(0, stem_mat)
	mesh.surface_set_material(1, head_mat)
	return mesh
