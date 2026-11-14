class_name PressureSwitch
extends Area3D
## Floor plate pressed by the player or an EchoClone. Emits `changed(pressed)`.

signal changed(pressed: bool)

@export var id := "A"

var pressed := false
var _bodies: Array[Node3D] = []
var _plate: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _label: Label3D
var _glow := 0.6


func _init() -> void:
	collision_layer = 0
	collision_mask = 2 | 4
	monitoring = true
	monitorable = false


func _ready() -> void:
	# Stone base (half sunk into the ground so it reads as a floor plate).
	var base := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 1.2
	bc.bottom_radius = 1.2
	bc.height = 0.25
	bc.radial_segments = 24
	base.mesh = bc
	base.material_override = Builders.stone_material(0.2)
	base.position.y = 0.0
	add_child(base)
	# Inner plate.
	_plate = MeshInstance3D.new()
	var pc := CylinderMesh.new()
	pc.top_radius = 0.95
	pc.bottom_radius = 0.95
	pc.height = 0.1
	pc.radial_segments = 24
	_plate.mesh = pc
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.32, 0.36, 0.42)
	pm.roughness = 0.6
	pm.metallic = 0.2
	_plate.material_override = pm
	_plate.position.y = 0.09
	add_child(_plate)
	# Glowing ring.
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.albedo_color = Game.ECHO_CYAN
	_ring_mat.emission_enabled = true
	_ring_mat.emission = Game.ECHO_CYAN
	_ring_mat.emission_energy_multiplier = _glow
	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.97
	tor.outer_radius = 1.07
	tor.rings = 32
	tor.ring_segments = 6
	ring.mesh = tor
	ring.material_override = _ring_mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position.y = 0.13
	add_child(ring)
	# Floating id label.
	_label = Label3D.new()
	_label.text = id
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 96
	_label.pixel_size = 0.005
	_label.outline_size = 18
	_label.modulate = Game.ECHO_CYAN
	_label.outline_modulate = Color(0.02, 0.1, 0.14, 0.9)
	_label.position.y = 1.6
	add_child(_label)
	# Trigger volume.
	var col := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	cs.radius = 1.1
	cs.height = 1.2
	col.shape = cs
	col.position.y = 0.6
	add_child(col)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func is_pressed() -> bool:
	return pressed


func _counts(b: Node) -> bool:
	return b.is_in_group("player") or b.is_in_group("clone")


func _on_body_entered(b: Node3D) -> void:
	if _counts(b) and not _bodies.has(b):
		_bodies.append(b)
	_update()


func _on_body_exited(b: Node3D) -> void:
	_bodies.erase(b)
	_update()


func _update() -> void:
	var now := _bodies.size() > 0
	if now == pressed:
		return
	pressed = now
	if pressed:
		Sfx.play("switch_on", -2.0)
	changed.emit(pressed)


func _physics_process(_delta: float) -> void:
	# Drop freed / dismissed bodies that may not have sent body_exited.
	var dirty := false
	for i in range(_bodies.size() - 1, -1, -1):
		# Untyped on purpose: assigning a freed instance to a typed (Node3D)
		# local raises a runtime error before is_instance_valid can check it.
		var b: Variant = _bodies[i]
		if not is_instance_valid(b) or not (b as Node).is_inside_tree() or not _counts(b as Node):
			_bodies.remove_at(i)
			dirty = true
	if dirty:
		_update()


func _process(delta: float) -> void:
	var k := clampf(delta * 10.0, 0.0, 1.0)
	_plate.position.y = lerpf(_plate.position.y, 0.01 if pressed else 0.09, k)
	var idle := 0.5 + 0.15 * sin(Time.get_ticks_msec() * 0.004)
	_glow = lerpf(_glow, 4.0 if pressed else idle, clampf(delta * 6.0, 0.0, 1.0))
	_ring_mat.emission_energy_multiplier = _glow
	if _label.text != id:
		_label.text = id
