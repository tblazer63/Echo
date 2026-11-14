class_name SonicBolt
extends Node3D
## Fast cyan sound bolt fired by the gauntlet. Ray-casts every physics step and
## calls `take_damage(amount, hit_pos)` on the first thing it hits (or an ancestor).

const SPEED := 45.0
const DAMAGE := 20.0
const LIFETIME := 1.5
const MASK := 1 | 8
const TRAIL_MAX := 2.6

static var _core_mesh: CapsuleMesh
static var _trail_mesh: CapsuleMesh
static var _flash_mesh: SphereMesh
static var _core_mat: StandardMaterial3D
static var _trail_mat: StandardMaterial3D

var dir := Vector3.FORWARD
var _age := 0.0
var _travel := 0.0
var _trail: MeshInstance3D
var _done := false


static func fire(parent: Node, from: Vector3, direction: Vector3) -> SonicBolt:
	var b := SonicBolt.new()
	b.dir = direction.normalized() if direction.length() > 0.001 else Vector3.FORWARD
	parent.add_child(b)
	b.global_position = from
	var up: Vector3 = Vector3.RIGHT if absf(b.dir.y) > 0.98 else Vector3.UP
	b.global_basis = Basis.looking_at(b.dir, up)
	return b


static func _ensure_resources() -> void:
	if _core_mesh != null:
		return
	_core_mat = StandardMaterial3D.new()
	_core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_core_mat.albedo_color = Color(0.85, 1.0, 1.0)
	_core_mat.emission_enabled = true
	_core_mat.emission = Color(0.25, 0.95, 1.0)
	_core_mat.emission_energy_multiplier = 4.0
	_trail_mat = StandardMaterial3D.new()
	_trail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_trail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_trail_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_trail_mat.albedo_color = Color(0.25, 0.95, 1.0, 0.45)
	_core_mesh = CapsuleMesh.new()
	_core_mesh.radius = 0.06
	_core_mesh.height = 0.7
	_core_mesh.radial_segments = 10
	_core_mesh.rings = 2
	_core_mesh.material = _core_mat
	_trail_mesh = CapsuleMesh.new()
	_trail_mesh.radius = 0.045
	_trail_mesh.height = 1.0
	_trail_mesh.radial_segments = 8
	_trail_mesh.rings = 2
	_trail_mesh.material = _trail_mat
	_flash_mesh = SphereMesh.new()
	_flash_mesh.radius = 0.5
	_flash_mesh.height = 1.0
	_flash_mesh.radial_segments = 16
	_flash_mesh.rings = 8


func _ready() -> void:
	_ensure_resources()
	var core := MeshInstance3D.new()
	core.mesh = _core_mesh
	core.rotation.x = PI * 0.5
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(core)
	_trail = MeshInstance3D.new()
	_trail.mesh = _trail_mesh
	_trail.rotation.x = PI * 0.5
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_trail.scale = Vector3(1, 0.01, 1)
	add_child(_trail)


func _physics_process(delta: float) -> void:
	if _done:
		return
	_age += delta
	if _age >= LIFETIME:
		_done = true
		queue_free()
		return
	var from := global_position
	var to := from + dir * SPEED * delta
	var q := PhysicsRayQueryParameters3D.create(from, to, MASK)
	q.collide_with_areas = false
	q.collide_with_bodies = true
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		_impact(hit)
		return
	global_position = to
	_travel += SPEED * delta
	var l := minf(_travel, TRAIL_MAX)
	_trail.scale = Vector3(1, maxf(l, 0.01), 1)
	_trail.position = Vector3(0, 0, l * 0.5)


func _impact(hit: Dictionary) -> void:
	_done = true
	var pos: Vector3 = hit["position"]
	var n := hit["collider"] as Node
	var enemy := false
	var depth := 0
	while n != null and depth < 4:
		if n.has_method("take_damage"):
			n.call("take_damage", DAMAGE, pos)
			enemy = true
			break
		n = n.get_parent()
		depth += 1
	if enemy:
		Sfx.play("hit", -2.0, randf_range(0.9, 1.1))
	var p := get_parent()
	if p != null:
		_spawn_flash(p, pos, enemy)
	queue_free()


static func _spawn_flash(parent: Node, pos: Vector3, enemy: bool) -> void:
	_ensure_resources()
	var f := MeshInstance3D.new()
	f.mesh = _flash_mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(1.0, 1.0, 1.0, 0.9) if enemy else Color(0.4, 1.0, 1.0, 0.8)
	f.material_override = m
	f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(f)
	f.global_position = pos
	f.scale = Vector3.ONE * 0.15
	var s: float = 1.1 if enemy else 0.7
	var tw := f.create_tween().set_parallel(true)
	tw.tween_property(f, "scale", Vector3.ONE * s, 0.14).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.2)
	tw.chain().tween_callback(f.queue_free)
