class_name Builders
extends RefCounted
## Procedural helpers that build the floating-ruins environment from primitives
## + custom shaders (no imported assets).

const STONE_SHADER := preload("res://shaders/stone.gdshader")
const WATER_SHADER := preload("res://shaders/water.gdshader")
const FOLIAGE_SHADER := preload("res://shaders/foliage.gdshader")

static var _mats: Dictionary = {}
static var _grass_mesh: ArrayMesh
static var _grass_mat: ShaderMaterial
static var _vine_mat: StandardMaterial3D
static var _water_mat: ShaderMaterial


static func stone_material(moss: float, displace: float = 0.0, tiles: bool = true) -> ShaderMaterial:
	var key := "%s_%s_%s" % [moss, displace, tiles]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = STONE_SHADER
	m.set_shader_parameter("moss_amount", moss)
	m.set_shader_parameter("displace", displace)
	m.set_shader_parameter("tiles", tiles)
	_mats[key] = m
	return m


static func rock_material() -> ShaderMaterial:
	var m := stone_material(0.35, 1.1, false)
	m.set_shader_parameter("stone_light", Color(0.66, 0.65, 0.63))
	m.set_shader_parameter("stone_dark", Color(0.36, 0.38, 0.42))
	return m


## Floating island. Walkable top surface is at `pos.y`.
static func island(parent: Node3D, pos: Vector3, radius: float, depth: float, collide: bool = true, deco: bool = true) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = pos
	root.rotation.y = randf() * TAU
	var top := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = radius
	tm.bottom_radius = radius * 0.96
	tm.height = 1.2
	tm.radial_segments = 40
	tm.rings = 1
	top.mesh = tm
	top.material_override = stone_material(0.45)
	top.position.y = -0.6
	root.add_child(top)
	var under := MeshInstance3D.new()
	var um := CylinderMesh.new()
	um.top_radius = radius * 0.97
	um.bottom_radius = radius * 0.12
	um.height = depth
	um.radial_segments = 28
	um.rings = 10
	under.mesh = um
	under.material_override = rock_material()
	under.position.y = -1.2 - depth * 0.5 + 0.05
	root.add_child(under)
	if collide:
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = 1.2
		col.shape = shape
		col.position.y = -0.6
		body.add_child(col)
		root.add_child(body)
	if deco:
		grass(root, Vector3.ZERO, radius * 0.93, int(radius * radius * 1.4))
		vines(root, radius, int(radius * 1.2))
	return root


static func pillar(parent: Node3D, pos: Vector3, height: float, width: float = 1.1, broken: bool = false, collide: bool = true) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = pos
	var mat := stone_material(0.5)
	_box(root, Vector3(width * 1.35, 0.5, width * 1.35), Vector3(0, 0.25, 0), mat)
	var shaft_h := height - (0.5 if broken else 1.0)
	var shaft := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = width * 0.45
	cm.bottom_radius = width * 0.5
	cm.height = shaft_h
	cm.radial_segments = 10
	cm.rings = 4
	shaft.mesh = cm
	shaft.material_override = mat
	shaft.position.y = 0.5 + shaft_h * 0.5
	root.add_child(shaft)
	if broken:
		shaft.rotation.z = randf_range(-0.04, 0.04)
	else:
		_box(root, Vector3(width * 1.4, 0.5, width * 1.4), Vector3(0, height - 0.25, 0), mat)
	if collide:
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var s := CylinderShape3D.new()
		s.radius = width * 0.6
		s.height = height
		col.shape = s
		col.position.y = height * 0.5
		body.add_child(col)
		root.add_child(body)
	return root


static func arch(parent: Node3D, pos: Vector3, width: float, height: float, rot_y: float, collide: bool = true) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = pos
	root.rotation.y = rot_y
	var mat := stone_material(0.4)
	for side in [-1.0, 1.0]:
		_box(root, Vector3(1.0, height, 1.0), Vector3(side * width * 0.5, height * 0.5, 0), mat, collide)
	_box(root, Vector3(width + 1.6, 0.9, 1.3), Vector3(0, height + 0.45, 0), mat, collide)
	# Corbel blocks under the lintel suggest an arch without a curved mesh.
	for side in [-1.0, 1.0]:
		_box(root, Vector3(0.6, 0.5, 1.1), Vector3(side * (width * 0.5 - 0.6), height - 0.25, 0), mat)
	return root


static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, collide: bool = false) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = mat
	m.position = pos
	parent.add_child(m)
	if collide:
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var s := BoxShape3D.new()
		s.size = size
		col.shape = s
		body.add_child(col)
		body.position = pos
		parent.add_child(body)
	return m


## Solid stone walkway (box) from a to b at the height of a.
static func walkway(parent: Node3D, a: Vector3, b: Vector3, width: float) -> void:
	var mid := (a + b) * 0.5
	var len := Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
	var root := Node3D.new()
	parent.add_child(root)
	root.position = mid
	root.look_at_from_position(mid, Vector3(b.x, mid.y, b.z), Vector3.UP)
	_box(root, Vector3(width, 0.7, len), Vector3(0, -0.35, 0), stone_material(0.5), true)
	# Side rails / broken posts.
	for i in int(len / 2.5):
		if randf() < 0.35:
			continue
		var z := -len * 0.5 + 1.0 + i * 2.5
		for side in [-1.0, 1.0]:
			if randf() < 0.5:
				_box(root, Vector3(0.35, randf_range(0.4, 1.0), 0.35), Vector3(side * (width * 0.5 - 0.15), 0.3, z), stone_material(0.6))


static func grass(parent: Node3D, center: Vector3, radius: float, count: int) -> void:
	if _grass_mesh == null:
		_grass_mesh = _make_tuft()
		_grass_mat = ShaderMaterial.new()
		_grass_mat.shader = FOLIAGE_SHADER
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _grass_mesh
	mm.instance_count = count
	for i in count:
		var r := radius * sqrt(randf_range(0.15, 1.0))
		var a := randf() * TAU
		var s := randf_range(0.45, 0.95)
		var basis := Basis(Vector3.UP, randf() * TAU).scaled(Vector3(s, s * randf_range(0.8, 1.3), s))
		mm.set_instance_transform(i, Transform3D(basis, center + Vector3(cos(a) * r, 0.0, sin(a) * r)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _grass_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)


static func _make_tuft() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := 0.45
	var h := 0.45
	for k in 3:
		var a := PI * k / 3.0
		var d := Vector3(cos(a), 0, sin(a)) * w
		var verts := [-d + Vector3.UP * h, d + Vector3.UP * h, d, -d]
		var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP)
			st.set_uv(uvs[idx])
			st.add_vertex(verts[idx])
	return st.commit()


static func vines(parent: Node3D, radius: float, count: int) -> void:
	if _vine_mat == null:
		_vine_mat = StandardMaterial3D.new()
		_vine_mat.albedo_color = Color(0.28, 0.5, 0.18)
		_vine_mat.roughness = 0.9
	# One MultiMesh per island (1 draw call) instead of one node per vine.
	var unit := BoxMesh.new()
	unit.size = Vector3(1, 1, 0.12)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = unit
	mm.instance_count = count
	for i in count:
		var a := randf() * TAU
		var len := randf_range(1.0, 4.5)
		var basis := Basis(Vector3.UP, -a).scaled(Vector3(randf_range(0.12, 0.35), len, 1.0))
		var pos := Vector3(cos(a) * radius * 0.985, -len * 0.5 + 0.02, sin(a) * radius * 0.985)
		mm.set_instance_transform(i, Transform3D(basis, pos))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _vine_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)


static func waterfall(parent: Node3D, top: Vector3, width: float, height: float, facing: float) -> void:
	if _water_mat == null:
		_water_mat = ShaderMaterial.new()
		_water_mat.shader = WATER_SHADER
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(width, height)
	q.mesh = qm
	q.material_override = _water_mat
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(q)
	q.position = top + Vector3.DOWN * height * 0.5
	q.rotation.y = facing
	# Mist at the lip.
	var mist := CPUParticles3D.new()
	mist.amount = 24
	mist.lifetime = 2.5
	mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	mist.emission_box_extents = Vector3(width * 0.4, 0.2, 0.2)
	mist.direction = Vector3.DOWN
	mist.spread = 15.0
	mist.initial_velocity_min = 2.0
	mist.initial_velocity_max = 4.0
	mist.gravity = Vector3(0, -3, 0)
	mist.scale_amount_min = 0.8
	mist.scale_amount_max = 2.0
	var pm := SphereMesh.new()
	pm.radius = 0.3
	pm.height = 0.6
	pm.radial_segments = 6
	pm.rings = 3
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.albedo_color = Color(1, 1, 1, 0.25)
	pm.material = mm
	mist.mesh = pm
	mist.rotation.y = facing
	parent.add_child(mist)
	mist.position = top + Vector3.DOWN * 0.5
