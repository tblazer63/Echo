class_name EnemyProjectile
extends Area3D
## Magenta Dissonance orb fired by drones. Damages the player's `health` on
## contact, pops on anything in the world.

const DISSONANCE := Color(0.95, 0.25, 0.85)
const LIFETIME := 5.0

static var _orb_mesh: SphereMesh
static var _halo_mesh: SphereMesh
static var _orb_mat: StandardMaterial3D
static var _halo_mat: StandardMaterial3D

var velocity := Vector3.ZERO
var damage := 15.0
var _age := 0.0
var _dead := false
var _halo: MeshInstance3D


static func spawn(parent: Node, from: Vector3, target: Vector3, speed: float = 13.0, dmg: float = 15.0) -> EnemyProjectile:
	var p := EnemyProjectile.new()
	var d := target - from
	p.velocity = (d.normalized() if d.length() > 0.001 else Vector3.FORWARD) * speed
	p.damage = dmg
	parent.add_child(p)
	p.global_position = from
	return p


static func _ensure_resources() -> void:
	if _orb_mesh != null:
		return
	_orb_mat = StandardMaterial3D.new()
	_orb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_orb_mat.albedo_color = Color(1.0, 0.75, 0.97)
	_orb_mat.emission_enabled = true
	_orb_mat.emission = DISSONANCE
	_orb_mat.emission_energy_multiplier = 3.0
	_halo_mat = StandardMaterial3D.new()
	_halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_halo_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_halo_mat.albedo_color = Color(DISSONANCE.r, DISSONANCE.g, DISSONANCE.b, 0.35)
	_orb_mesh = SphereMesh.new()
	_orb_mesh.radius = 0.3
	_orb_mesh.height = 0.6
	_orb_mesh.radial_segments = 16
	_orb_mesh.rings = 8
	_orb_mesh.material = _orb_mat
	_halo_mesh = SphereMesh.new()
	_halo_mesh.radius = 0.5
	_halo_mesh.height = 1.0
	_halo_mesh.radial_segments = 16
	_halo_mesh.rings = 8
	_halo_mesh.material = _halo_mat


func _ready() -> void:
	_ensure_resources()
	add_to_group("enemy_projectile")
	collision_layer = 0
	collision_mask = 1 | 2
	monitoring = true
	monitorable = false
	var col := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 0.3
	col.shape = s
	add_child(col)
	var orb := MeshInstance3D.new()
	orb.mesh = _orb_mesh
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(orb)
	_halo = MeshInstance3D.new()
	_halo.mesh = _halo_mesh
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_halo)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_age += delta
	if _age >= LIFETIME:
		_pop()
		return
	global_position += velocity * delta
	_halo.scale = Vector3.ONE * (0.9 + 0.15 * sin(_age * 22.0))


func _on_body_entered(body: Node3D) -> void:
	if _dead:
		return
	if body.is_in_group("player"):
		var h: Variant = body.get("health")
		if h is Object and is_instance_valid(h) and (h as Object).has_method("damage"):
			(h as Object).call("damage", damage, global_position)
	_pop()


## Destroy the orb (e.g. when shot or hit by an echo).
func destroy() -> void:
	_pop()


func _pop() -> void:
	if _dead:
		return
	_dead = true
	set_deferred("monitoring", false)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 1.8, 0.07).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector3.ONE * 0.02, 0.12).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
