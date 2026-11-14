class_name EnergyShard
extends Area3D
## Collectible cyan energy crystal. Spins, bobs, pops on pickup.

const CYAN := Color(0.25, 0.95, 1.0)

var _gem: Node3D
var _ring: MeshInstance3D
var _t := 0.0
var _collected := false


func _ready() -> void:
	add_to_group("shard")
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	_t = randf() * TAU
	var col := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.8
	col.shape = sh
	add_child(col)
	_build_visual()
	body_entered.connect(_on_body_entered)


func _build_visual() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 1.0, 1.0)
	mat.emission_enabled = true
	mat.emission = CYAN
	mat.emission_energy_multiplier = 2.2
	mat.roughness = 0.2
	mat.metallic = 0.3
	_gem = Node3D.new()
	add_child(_gem)
	for i in 2:
		var c := CylinderMesh.new()
		c.radial_segments = 6
		c.rings = 1
		c.height = 0.38 if i == 0 else 0.26
		c.top_radius = 0.0 if i == 0 else 0.22
		c.bottom_radius = 0.22 if i == 0 else 0.0
		c.material = mat
		var mi := MeshInstance3D.new()
		mi.mesh = c
		mi.position.y = c.height * 0.5 if i == 0 else -c.height * 0.5
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_gem.add_child(mi)
	var rmat := StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.albedo_color = Color(CYAN.r, CYAN.g, CYAN.b, 0.45)
	var tor := TorusMesh.new()
	tor.inner_radius = 0.3
	tor.outer_radius = 0.4
	tor.rings = 16
	tor.ring_segments = 4
	tor.material = rmat
	_ring = MeshInstance3D.new()
	_ring.mesh = tor
	_ring.position.y = -0.6
	_ring.scale = Vector3(1.0, 0.25, 1.0)
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)


func _process(delta: float) -> void:
	if _collected:
		return
	_t += delta
	_gem.rotation.y += delta * 2.2
	_gem.position.y = sin(_t * 2.5) * 0.12
	var s: float = 1.0 + sin(_t * 2.5) * 0.08
	_ring.scale = Vector3(s, 0.25, s)


func _on_body_entered(body: Node3D) -> void:
	if body is CollisionObject3D and ((body as CollisionObject3D).collision_layer & 2) != 0:
		collect()


## Public: collect this shard (also used by QA).
func collect() -> void:
	if _collected or not is_inside_tree():
		return
	_collected = true
	set_deferred("monitoring", false)
	if Game.has_method("collect_shard"):
		Game.call("collect_shard")
	Sfx.play("shard")
	Juice.burst(get_parent(), global_position, CYAN, 28, 0.1)
	_ring.visible = false
	var tw := create_tween()
	tw.tween_property(_gem, "scale", Vector3(1.6, 1.6, 1.6), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_gem, "scale", Vector3.ZERO, 0.14).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
