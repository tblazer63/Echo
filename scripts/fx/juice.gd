class_name Juice
extends RefCounted
## Static game-feel helpers. Every function is null-safe and never crashes if
## the given node is missing or outside the tree.

static var _hitstop_id: int = 0


## Freeze-frame: slow time to `scale` for `duration` real seconds.
static func hitstop(tree: SceneTree, duration: float = 0.06, scale: float = 0.08) -> void:
	if tree == null:
		return
	_hitstop_id += 1
	var my_id: int = _hitstop_id
	Engine.time_scale = scale
	var t: SceneTreeTimer = tree.create_timer(duration, true, false, true)
	t.timeout.connect(func() -> void:
		if my_id == Juice._hitstop_id:
			Engine.time_scale = 1.0
	)


static func _ok(parent: Node) -> bool:
	return parent != null and is_instance_valid(parent) and parent.is_inside_tree()


static func _glow_mat(color: Color, vertex: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	m.vertex_color_use_as_albedo = vertex
	return m


## One-shot particle explosion at world position `pos`; frees itself.
static func burst(parent: Node, pos: Vector3, color: Color, amount: int = 24, size: float = 0.12) -> void:
	if not _ok(parent):
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = maxi(amount, 1)
	p.lifetime = 0.6
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 7.0
	p.gravity = Vector3(0, -4.0, 0)
	p.damping_min = 2.0
	p.damping_max = 4.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	g.set_color(1, Color(color.r, color.g, color.b, 0.0))
	g.add_point(0.25, Color(color.r, color.g, color.b, 1.0))
	p.color_ramp = g
	var mesh := SphereMesh.new()
	mesh.radius = size * 0.5
	mesh.height = size
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.material = _glow_mat(Color(1.4, 1.4, 1.4), true)
	p.mesh = mesh
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	var t: SceneTreeTimer = p.get_tree().create_timer(p.lifetime + 0.3, true, false, true)
	t.timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free()
	)


## Floating damage number at world position `pos`; rises and fades.
static func damage_number(parent: Node, pos: Vector3, amount: float, crit: bool = false) -> void:
	if not _ok(parent):
		return
	var l := Label3D.new()
	l.text = str(roundi(amount)) + ("!" if crit else "")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = false
	l.pixel_size = 0.006
	l.font_size = 72 if crit else 48
	l.outline_size = 12
	l.modulate = Color(1.0, 0.82, 0.25) if crit else Color(0.25, 0.95, 1.0)
	l.outline_modulate = Color(0.02, 0.05, 0.1, 1.0)
	l.render_priority = 10
	l.outline_render_priority = 9
	parent.add_child(l)
	l.global_position = pos + Vector3(randf_range(-0.2, 0.2), 0.0, randf_range(-0.2, 0.2))
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y + 1.2, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.15)
	tw.tween_property(l, "outline_modulate:a", 0.0, 0.7).set_delay(0.15)
	tw.chain().tween_callback(l.queue_free)


## Camera shake, if the node supports add_shake(strength).
static func shake(camera_owner: Node, strength: float) -> void:
	if camera_owner != null and is_instance_valid(camera_owner) and camera_owner.has_method("add_shake"):
		camera_owner.call("add_shake", strength)


## Tiny cyan flash at `local_pos` in `parent`'s space; frees after 0.08 s.
static func muzzle_flash(parent: Node3D, local_pos: Vector3) -> void:
	if not _ok(parent):
		return
	var holder := Node3D.new()
	holder.position = local_pos
	var light := OmniLight3D.new()
	light.light_color = Color(0.25, 0.95, 1.0)
	light.omni_range = 3.0
	light.light_energy = 3.0
	light.shadow_enabled = false
	holder.add_child(light)
	var s := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.07
	sm.height = 0.14
	sm.radial_segments = 8
	sm.rings = 4
	sm.material = _glow_mat(Color(0.7, 1.0, 1.0, 0.95))
	s.mesh = sm
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(s)
	parent.add_child(holder)
	var tw := holder.create_tween()
	tw.set_parallel(true)
	tw.tween_property(light, "light_energy", 0.0, 0.08)
	tw.tween_property(s, "scale", Vector3(1.8, 1.8, 1.8), 0.08)
	tw.tween_property(s, "transparency", 1.0, 0.08)
	tw.chain().tween_callback(holder.queue_free)
