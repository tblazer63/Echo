class_name ResonantCrossing
extends Node3D
## Builds the playable world. Level 1 "The First Resonance" is laid out here;
## Level 2 "Dissonant Heights" is built by LevelTwoLayout using the public
## helper API below (add_island, add_drone, setup_surf, setup_clone_puzzle...).

var level_id := 1
var sky_mat: ProceduralSkyMaterial
var relay: EchoRelay
var gate: LockedGate
var signal_gate: SignalGate
var sun: DirectionalLight3D
var env: Environment
var drones: Array[EchoDrone] = []
var surf: EchoSurf
var switch_a: PressureSwitch
var switch_b: PressureSwitch
var clone_gate: LockedGate
var echo_lifts: Array[EchoLift] = []
var machine: ResonanceMachine
var bridge: TransformBridge
var restoration: RestorationController

const START := Vector3(0, 0, 0)
const ISLAND_A := Vector3(0, 0, -27)
const RELAY_ISLET := Vector3(-24, 0, -27)
const ISLAND_B := Vector3(0, 0, -53)
const ISLAND_C := Vector3(0, 4, -88)
const ISLAND_D := Vector3(29, 4, -88)


var sentinel: Sentinel
var pylons: Array[ShieldPylon] = []
var _clone_hint_t := 0.0
var _clone_hold_hinted := false


func _ready() -> void:
	level_id = Game.level_id
	seed(7 + level_id * 13)
	Game.shards_total = 0
	Game.rings_total = 0
	_build_environment()
	restoration = RestorationController.new()
	add_child(restoration)
	restoration.setup(env, sun)
	Game.player_respawned.connect(_on_respawn)
	if level_id == 2:
		LevelTwoLayout.build(self)
	else:
		_build_layout()
	restoration.set_corrupted()
	_build_background()
	apply_quality(Game.quality)
	Game.quality_changed.connect(apply_quality)


func _on_respawn() -> void:
	for d in get_tree().get_nodes_in_group("drone"):
		if d.has_method("reset_drone"):
			d.call("reset_drone")
	for p in get_tree().get_nodes_in_group("enemy_projectile"):
		p.call("destroy")
	if sentinel and sentinel.active and not sentinel.is_defeated():
		sentinel.reset_fight()


# ===================================================================
# Public level-building API (used by Level 1 below and LevelTwoLayout)
# ===================================================================

func add_island(pos: Vector3, radius: float, depth: float) -> Node3D:
	return Builders.island(self, pos, radius, depth)


func add_checkpoint(pos: Vector3, yaw_rad: float) -> void:
	_checkpoint(pos, yaw_rad)


func add_zone(pos: Vector3, size: Vector3, cb: Callable) -> void:
	_zone(pos, size, cb)


func add_echo_platform(pos: Vector3, size: Vector3) -> EchoPlatform:
	return _echo_platform(pos, size)


func pulse_marker(pos: Vector3) -> void:
	_pulse_marker(pos)


func add_shard(pos: Vector3) -> void:
	var s := EnergyShard.new()
	s.position = pos
	add_child(s)
	Game.shards_total += 1


## Drones added here gate the surf generator: all must be disabled.
func add_drone(pos: Vector3, phantom: bool = false) -> EchoDrone:
	var d: EchoDrone = PhantomDrone.new() if phantom else EchoDrone.new()
	d.position = pos
	add_child(d)
	drones.append(d)
	d.defeated.connect(_on_drone_defeated)
	d.defeated.connect(_on_any_enemy_down)
	return d


## Optional ambush enemies that do not gate progress.
func add_ambush_drone(pos: Vector3, phantom: bool) -> EchoDrone:
	var d: EchoDrone = PhantomDrone.new() if phantom else EchoDrone.new()
	d.position = pos
	add_child(d)
	d.defeated.connect(_on_any_enemy_down)
	return d


func _on_any_enemy_down(d: Node) -> void:
	Game.drones_down += 1
	var p := (d as Node3D).global_position
	Juice.burst(self, p, Color(0.95, 0.3, 0.85), 30, 0.14)
	Juice.burst(self, p, Game.ECHO_CYAN, 16, 0.1)
	Juice.hitstop(get_tree(), 0.07, 0.1)
	Sfx.play("kill", -2.0)
	var pl := get_tree().get_first_node_in_group("player")
	if pl:
		Juice.shake(pl, 0.25)


func _on_drone_defeated(_d: Node) -> void:
	var n := 0
	for d in drones:
		if d.is_defeated():
			n += 1
	Game.set_progress("Drones disabled  %d / %d" % [n, drones.size()])
	if n == drones.size() and surf:
		Game.set_objective("Ride the Echo Wave (press E at the generator)")
		Game.set_progress("")
		surf.activate()


func setup_surf(points: PackedVector3Array, ring_count: int, obstacle_count: int) -> EchoSurf:
	surf = EchoSurf.new()
	surf.points = points
	surf.ring_count = ring_count
	surf.obstacle_count = obstacle_count
	add_child(surf)
	Game.rings_total += ring_count
	surf.boarded.connect(func() -> void:
		Game.set_objective("Ride the Echo Wave. Steer with A / D")
		Game.set_progress(""))
	surf.ring_collected.connect(func(_c: int, _t: int) -> void:
		Game.rings += 1)
	surf.finished.connect(func(_c: int, _t: int) -> void:
		if clone_gate and not clone_gate.is_open:
			Game.set_objective("Aim at switch A and press C to send your echo there (or stand on it + R)")
			Game.set_progress("Then stand on switch B while your echo holds A")
			Game.prompt("Two switches, one of you. Aim at switch A and press  C  to send your ECHO there.", 6.0, "clone_hint"))
	return surf


## Two-switch Echo Clone puzzle that opens a LockedGate.
func setup_clone_puzzle(a_pos: Vector3, b_pos: Vector3, gate_pos: Vector3, gate_yaw_deg: float) -> void:
	switch_a = PressureSwitch.new()
	switch_a.id = "A"
	switch_a.position = a_pos
	add_child(switch_a)
	switch_b = PressureSwitch.new()
	switch_b.id = "B"
	switch_b.position = b_pos
	add_child(switch_b)
	switch_a.changed.connect(_on_switch_changed)
	switch_b.changed.connect(_on_switch_changed)
	_sign(a_pos + Vector3.UP * 2.35, "1 · SEND YOUR ECHO HERE\n(aim here + C, or stand here + R)")
	_sign(b_pos + Vector3.UP * 2.35, "2 · THEN STAND HERE\nwhile your echo holds A")
	clone_gate = LockedGate.new()
	clone_gate.position = gate_pos
	clone_gate.rotation.y = deg_to_rad(gate_yaw_deg)
	add_child(clone_gate)
	clone_gate.unlocked.connect(func() -> void:
		if machine:
			machine.enabled = true
		Game.set_progress("")
		Game.prompt("Two echoes, one key. The gate opens!", 3.0)
		Game.set_objective("Echo Scan the ancient machine on the pier"))


## Co-op puzzle "Echo Lift": the echo holds a remote switch while you ride the
## lift up to a hidden ledge with a shard. Optional, so it can never soft-lock.
func add_echo_lift(island_center: Vector3, switch_pos: Vector3, lift_pos: Vector3, rise: float) -> EchoLift:
	var sw := PressureSwitch.new()
	sw.id = "LIFT"
	sw.position = switch_pos
	add_child(sw)
	var lift := EchoLift.new()
	lift.position = lift_pos
	lift.rise = rise
	lift.sw = sw
	add_child(lift)
	var out := Vector3(lift_pos.x - island_center.x, 0.0, lift_pos.z - island_center.z).normalized()
	var ledge := lift_pos + out * 3.9 + Vector3.UP * rise
	Builders.island(self, ledge, 2.4, 3.0)
	add_shard(ledge + Vector3.UP * 1.2)
	_sign(switch_pos + Vector3.UP * 2.5, "ECHO LIFT · send your echo here (aim + C)\nthen ride the lift yourself")
	_sign(lift_pos + Vector3.UP * 2.2, "LIFT · rises while the switch is held")
	echo_lifts.append(lift)
	return lift


func _sign(pos: Vector3, text: String) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 48
	l.pixel_size = 0.006
	l.outline_size = 12
	l.modulate = Color(0.9, 1.0, 1.0)
	l.outline_modulate = Color(0.02, 0.1, 0.14, 0.9)
	l.position = pos
	add_child(l)


func _on_switch_changed(_p: bool) -> void:
	if clone_gate == null or clone_gate.is_open:
		return
	var count := int(switch_a.is_pressed()) + int(switch_b.is_pressed())
	Game.set_progress("Switches  %d / 2" % count)
	if count == 2:
		clone_gate.unlock()


## Context hints so the clone puzzle teaches itself.
func _process(delta: float) -> void:
	if clone_gate == null or clone_gate.is_open or switch_a == null:
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	var clones := get_tree().get_nodes_in_group("clone")
	var on_switch: PressureSwitch = null
	for s: PressureSwitch in [switch_a, switch_b]:
		if s.global_position.distance_to(player.global_position) < 1.3:
			on_switch = s
	if on_switch and clones.is_empty():
		_clone_hint_t += delta
		if _clone_hint_t > 1.5:
			_clone_hint_t = -6.0
			Game.prompt("Press  R  to record your echo on switch %s  (or aim at it from afar + C)" % on_switch.id, 4.0)
	else:
		_clone_hint_t = minf(_clone_hint_t, 0.0)
	if not _clone_hold_hinted:
		for c in clones:
			for s: PressureSwitch in [switch_a, switch_b]:
				if (c as Node3D).global_position.distance_to(s.global_position) < 1.2 and s.is_pressed():
					_clone_hold_hinted = true
					var other := switch_b if s == switch_a else switch_a
					Game.prompt("Your echo holds switch %s. Now stand on switch %s!" % [s.id, other.id], 5.0)
					Game.set_objective("Stand on switch %s while your echo holds %s" % [other.id, s.id])


func setup_machine_bridge(machine_pos: Vector3, bridge_pivot: Vector3, bridge_yaw_deg: float, length: float) -> void:
	machine = ResonanceMachine.new()
	machine.position = machine_pos
	add_child(machine)
	bridge = TransformBridge.new()
	bridge.length = length
	bridge.position = bridge_pivot
	bridge.rotation.y = deg_to_rad(bridge_yaw_deg)
	add_child(bridge)
	machine.activated_signal.connect(func() -> void:
		bridge.activate()
		Game.set_objective("Cross the bridge to the Resonance Spire"))


func setup_spire(pos: Vector3) -> SignalGate:
	signal_gate = SignalGate.new()
	signal_gate.position = pos
	add_child(signal_gate)
	signal_gate.restored.connect(func() -> void:
		restoration.restore(signal_gate.global_position + Vector3.UP * 7.0)
		Sfx.set_restored_music(true))
	return signal_gate


## The Sentinel guards the Spire; pylons power its shield.
func build_sentinel_arena(arena_center: Vector3, pylon_positions: Array, max_hp: float, zone_pos: Vector3, zone_size: Vector3) -> void:
	for pp in pylon_positions:
		var p := ShieldPylon.new()
		p.position = pp
		add_child(p)
		pylons.append(p)
	sentinel = Sentinel.new()
	sentinel.arena_center = arena_center
	sentinel.max_hp = max_hp
	sentinel.hp = max_hp
	sentinel.pylons = pylons
	add_child(sentinel)
	sentinel.global_position = arena_center + Vector3.UP * 5.5
	sentinel.health_changed.connect(func(hp: float, mx: float) -> void:
		Game.boss_hud.emit(true, "THE SENTINEL", hp / mx, sentinel.shield_up))
	sentinel.shield_changed.connect(func(up: bool) -> void:
		Game.boss_hud.emit(true, "THE SENTINEL", sentinel.hp / sentinel.max_hp, up)
		if up:
			Game.set_progress("Break the shield pylons (Echo Scan or Sonic Bolt)")
		else:
			Game.set_progress("Shield down. Echo Scan the core, then shoot!"))
	sentinel.defeated.connect(func() -> void:
		_on_any_enemy_down(sentinel)
		Game.boss_hud.emit(false, "", 0.0, false)
		Game.set_progress("")
		Game.set_objective("Restore the Resonance Spire")
		signal_gate.sealed = false
		signal_gate.recheck())
	_zone(zone_pos, zone_size, func() -> void:
		if sentinel.is_defeated():
			return
		signal_gate.sealed = true
		sentinel.start_fight()
		Game.set_objective("Defeat the Sentinel")
		Game.set_progress("Break the shield pylons (Echo Scan or Sonic Bolt)")
		Game.prompt("THE SENTINEL awakens! Its shield draws power from the pylons.", 5.0))
	signal_gate.sealed = true


## Warm golden-hour palette for Level 2.
func set_golden_hour() -> void:
	sky_mat.sky_top_color = Color(0.28, 0.45, 0.78)
	sky_mat.sky_horizon_color = Color(0.98, 0.80, 0.62)
	sky_mat.ground_horizon_color = Color(0.95, 0.80, 0.68)
	sky_mat.ground_bottom_color = Color(0.70, 0.66, 0.78)
	sun.light_color = Color(1.0, 0.82, 0.62)
	sun.rotation = Vector3(deg_to_rad(-22), deg_to_rad(-120), 0)
	env.fog_light_color = Color(0.95, 0.82, 0.74)


func _build_environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.20, 0.47, 0.82)
	sm.sky_horizon_color = Color(0.68, 0.86, 0.96)
	sm.ground_bottom_color = Color(0.55, 0.74, 0.88)
	sm.ground_horizon_color = Color(0.70, 0.86, 0.95)
	sm.sun_angle_max = 25.0
	sm.sun_curve = 0.12
	sm.energy_multiplier = 1.1
	sky_mat = sm
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.95
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.set_glow_level(0, 0.0)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 0.8)
	env.set_glow_level(4, 0.5)
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.86, 0.96)
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.2
	env.fog_density = 0.0016
	env.fog_aerial_perspective = 0.2
	env.fog_sky_affect = 0.1
	env.fog_height = -14.0
	env.fog_height_density = 0.035
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.4
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.05
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140.0
	sun.directional_shadow_blend_splits = true
	sun.shadow_blur = 1.5
	sun.rotation = Vector3(deg_to_rad(-38), deg_to_rad(-140), 0)
	add_child(sun)


func _build_layout() -> void:
	# --- Start ruin ---
	Builders.island(self, START + Vector3(0, 0, 1), 7.5, 9.0)
	Builders.arch(self, START + Vector3(0, 0, 6.2), 4.0, 5.0, 0.0)
	Builders.pillar(self, START + Vector3(-5.2, 0, -2.5), 5.5, 1.1, true)
	Builders.pillar(self, START + Vector3(5.0, 0, -3.5), 7.0)
	Builders.pillar(self, START + Vector3(4.8, 0, 3.5), 3.0, 1.0, true)
	_pulse_marker(START + Vector3(0, 0.03, -4.0))
	_checkpoint(START + Vector3(0, 0, 3), 0.0)

	# Hidden bridge 1 (z -7 -> -19), straight.
	for i in 4:
		_echo_platform(Vector3(0, -0.2, -7.95 - i * 3.15), Vector3(2.8, 0.4, 3.2))
	_zone(Vector3(0, 1.5, -4), Vector3(8, 3, 4), func() -> void:
		Game.prompt("Press  Q  or  Right-Click  to emit an Echo", 6.0, "pulse_hint"))

	# --- Island A (hub) ---
	Builders.island(self, ISLAND_A, 8.0, 12.0)
	_checkpoint(ISLAND_A + Vector3(0, 0, 5.0), 0.0)
	Builders.pillar(self, ISLAND_A + Vector3(5.5, 0, 2.0), 6.0)
	Builders.pillar(self, ISLAND_A + Vector3(5.8, 0, -4.0), 4.0, 1.1, true)
	Builders.arch(self, ISLAND_A + Vector3(3.5, 0, -6.5), 3.0, 4.0, deg_to_rad(30), true)
	Builders.waterfall(self, ISLAND_A + Vector3(7.95, -0.4, 1.0), 3.0, 26.0, deg_to_rad(90))
	_zone(ISLAND_A + Vector3(0, 1.5, 4), Vector3(14, 3, 4), func() -> void:
		Game.set_objective("Resonate the cracked pillar to unlock the gate")
		Game.prompt("The cracked pillar echoes far... but your pulse can't reach it from here", 5.0, "relay_hint"))

	# Hidden steps west to the relay islet (x -9.5 -> -19).
	for i in 3:
		_echo_platform(ISLAND_A + Vector3(-9.7 - i * 3.3, -0.2, 0.0), Vector3(3.4, 0.4, 2.8))

	# --- Relay islet ---
	Builders.island(self, RELAY_ISLET, 4.2, 7.0)
	relay = EchoRelay.new()
	relay.position = RELAY_ISLET + Vector3(-1.2, 0, 0)
	add_child(relay)
	_checkpoint(RELAY_ISLET + Vector3(1.6, 0, 0.0), deg_to_rad(90))

	# --- Locked gate + solid bridge to island B ---
	Builders.walkway(self, ISLAND_A + Vector3(0, 0, -7.5), ISLAND_B + Vector3(0, 0, 5.5), 3.6)
	gate = LockedGate.new()
	gate.position = ISLAND_A + Vector3(0, 0, -9.5)
	add_child(gate)
	relay.target = gate
	relay.resonated.connect(func() -> void:
		Game.set_objective("Pass through the opened gate"))
	gate.unlocked.connect(func() -> void:
		Game.prompt("The gate answers your echo", 3.0))

	# --- Optional side path (Level 1 extension): hidden steps to a shard islet ---
	add_echo_platform(Vector3(7.0, -0.2, -3.5), Vector3(2.8, 0.4, 2.8))
	add_echo_platform(Vector3(9.8, -0.2, -4.5), Vector3(2.8, 0.4, 2.8))
	Builders.island(self, Vector3(13.2, 0, -5.0), 2.6, 5.0)
	Builders.pillar(self, Vector3(14.0, 0, -5.8), 3.0, 0.8, true)
	add_shard(Vector3(13.0, 1.2, -4.6))
	add_shard(START + Vector3(0, 1.2, 6.2))
	add_shard(ISLAND_A + Vector3(6.2, 1.2, 4.0))
	add_shard(RELAY_ISLET + Vector3(-2.6, 1.2, 1.8))
	# Phantom ambush over the hub (optional fight, lengthens the level).
	add_ambush_drone(ISLAND_A + Vector3(-3.5, 4.0, -3.0), true)
	add_ambush_drone(ISLAND_A + Vector3(4.0, 4.5, -4.5), false)

	# --- Island B: Courtyard Interference (combat) ---
	Builders.island(self, ISLAND_B, 6.5, 10.0)
	_checkpoint(ISLAND_B + Vector3(0, 0, 3.0), 0.0)
	Builders.pillar(self, ISLAND_B + Vector3(-4.3, 0, -2.0), 5.0, 1.0, true)
	Builders.pillar(self, ISLAND_B + Vector3(-1.5, 0, -4.5), 6.5)
	Builders.waterfall(self, ISLAND_B + Vector3(-6.45, -0.4, 0.5), 2.5, 22.0, deg_to_rad(-90))
	for off: Vector3 in [Vector3(-3.5, 3.5, -3.0), Vector3(3.5, 4.0, -4.0), Vector3(0.0, 5.0, -8.0)]:
		add_drone(ISLAND_B + off)
	add_shard(ISLAND_B + Vector3(-5.2, 1.2, -3.6))
	_zone(ISLAND_B + Vector3(0, 1.5, 4.5), Vector3(13, 3, 3), func() -> void:
		Game.set_objective("Disable the corrupted Echo Drones")
		Game.set_progress("Drones disabled  0 / %d" % drones.size())
		Game.prompt("LMB fires a Sonic Bolt.  Echo Scan (Q) stuns drones and exposes their cores!", 6.0, "combat_hint"))

	# --- Echo Surf: B -> island D over the clouds (with obstacles + time trial) ---
	setup_surf(PackedVector3Array([
		ISLAND_B + Vector3(3.8, 0.0, -2.5), Vector3(10.0, -0.8, -57.5), Vector3(19.0, -3.0, -62.0),
		Vector3(28.0, -1.5, -66.5), Vector3(35.0, 1.5, -73.0), Vector3(34.5, 4.0, -80.0),
		ISLAND_D + Vector3(1.5, 0.0, 4.0),
	]), 8, 4)

	# --- Island D: The Duplicate Key (clone puzzle) ---
	Builders.island(self, ISLAND_D, 7.5, 10.0)
	_checkpoint(ISLAND_D + Vector3(2.0, 0, 3.0), deg_to_rad(90))
	Builders.pillar(self, ISLAND_D + Vector3(4.5, 0, -4.5), 7.0)
	Builders.pillar(self, ISLAND_D + Vector3(-1.0, 0, -6.0), 4.0, 1.0, true)
	Builders.arch(self, ISLAND_D + Vector3(4.0, 0, 0.0), 3.4, 4.5, deg_to_rad(90))
	add_shard(ISLAND_D + Vector3(5.6, 1.2, 0.0))
	add_echo_lift(ISLAND_D, ISLAND_D + Vector3(2.5, 0, 5.5), ISLAND_D + Vector3(8.3, 0, 2.5), 8.0)
	# Pier west of D with the clone gate and the resonance machine.
	Builders.walkway(self, ISLAND_D + Vector3(-7.0, 0, 0), ISLAND_D + Vector3(-13.0, 0, 0), 3.6)
	setup_clone_puzzle(ISLAND_D + Vector3(-1.5, 0.0, 3.6), ISLAND_D + Vector3(-1.5, 0.0, -3.6),
		ISLAND_D + Vector3(-8.3, 0, 0), 90.0)
	setup_machine_bridge(ISLAND_D + Vector3(-12.0, 0, 1.3), ISLAND_D + Vector3(-13.0, 0, 0), 90.0, 7.0)
	_checkpoint(ISLAND_D + Vector3(-11.0, 0, -0.6), deg_to_rad(90))

	# --- Island C: Signal Gate = First Resonance Spire ---
	Builders.island(self, ISLAND_C, 9.5, 14.0)
	_checkpoint(ISLAND_C + Vector3(6.5, 0, 0.0), deg_to_rad(90))
	setup_spire(ISLAND_C + Vector3(0, 0, -5.0))
	add_shard(ISLAND_C + Vector3(-6.5, 1.2, -5.0))
	Builders.pillar(self, ISLAND_C + Vector3(-7.0, 0, 2.0), 8.0)
	Builders.pillar(self, ISLAND_C + Vector3(7.0, 0, 4.5), 8.0)
	Builders.pillar(self, ISLAND_C + Vector3(-6.0, 0, 6.5), 4.5, 1.0, true)
	restoration.add_waterfall_spot(self, ISLAND_C + Vector3(-9.45, -0.4, -4.0), 3.0, 28.0, deg_to_rad(-90))
	restoration.add_waterfall_spot(self, ISLAND_C + Vector3(0.0, -0.4, 9.45), 4.0, 30.0, 0.0)
	restoration.add_flowers(self, ISLAND_C, 8.5, 140)
	restoration.add_flowers(self, ISLAND_D, 6.5, 60)

	# Dissonance crystals scattered on the route.
	restoration.add_crystals(self, START + Vector3(0, 0, 1), 7.5, 6)
	restoration.add_crystals(self, ISLAND_A, 8.0, 8)
	restoration.add_crystals(self, ISLAND_B, 6.5, 7)
	restoration.add_crystals(self, ISLAND_D, 7.5, 7)
	restoration.add_crystals(self, ISLAND_C, 9.5, 10)
	build_sentinel_arena(ISLAND_C + Vector3(-2.5, 0, 2.0),
		[ISLAND_C + Vector3(-7.6, 0, -1.0), ISLAND_C + Vector3(7.8, 0, -2.6)], 320.0,
		ISLAND_C + Vector3(6.0, 1.5, 0.0), Vector3(5, 3, 12))

	# Holographic hints of the hidden world near the path.
	_holo_arch(Vector3(-11, 0, -14), deg_to_rad(70))
	_holo_arch(Vector3(12, 1, -40), deg_to_rad(-60))
	_holo_arch(Vector3(-10, 2, -66), deg_to_rad(80))


func _build_background() -> void:
	# Sea of clouds below the ruins.
	var clouds := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(3000, 3000)
	clouds.mesh = pm
	var cm := ShaderMaterial.new()
	cm.shader = preload("res://shaders/clouds.gdshader")
	clouds.material_override = cm
	clouds.position = Vector3(0, -38, -60)
	clouds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(clouds)

	# Distant floating islands with ruins (no grass/vines/shadows: perf).
	var bg := Node3D.new()
	add_child(bg)
	for i in 28:
		var a := randf_range(-PI, PI)
		var d := randf_range(70.0, 260.0)
		var center := Vector3(sin(a) * d, randf_range(-18.0, 35.0), -60.0 + cos(a) * d)
		var r := randf_range(4.0, 16.0)
		var isl := Builders.island(bg, center, r, r * randf_range(1.2, 2.2), false, false)
		if randf() < 0.7:
			for k in randi_range(1, 3):
				var off := Vector3(randf_range(-r, r) * 0.5, 0, randf_range(-r, r) * 0.5)
				Builders.pillar(isl, off, randf_range(4.0, 14.0), randf_range(1.0, 2.2), randf() < 0.5, false)
		if randf() < 0.3:
			Builders.arch(isl, Vector3.ZERO, r * 0.6, r * 0.6, randf() * TAU, false)
		if randf() < 0.35 and d < 180.0:
			Builders.waterfall(bg, center + Vector3(r * 0.97, -0.3, 0), r * 0.3, 40.0, deg_to_rad(90))
	_no_shadows(bg)

	# Tall spires behind the Signal Gate.
	for i in 9:
		var p := Vector3(randf_range(-70, 70), -30, randf_range(-170, -260))
		var sp := MeshInstance3D.new()
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var cyl := CylinderMesh.new()
		var w := randf_range(4.0, 9.0)
		cyl.top_radius = w * 0.5
		cyl.bottom_radius = w
		cyl.height = randf_range(60.0, 130.0)
		cyl.radial_segments = 6
		cyl.rings = 8
		sp.mesh = cyl
		sp.material_override = Builders.stone_material(0.3)
		sp.position = p + Vector3.UP * cyl.height * 0.5
		add_child(sp)

	# Huge faraway floating masses for depth (fog fades them into the sky).
	for i in 8:
		var a := deg_to_rad(-120.0 + i * 34.0 + randf_range(-8, 8))
		var c := Vector3(sin(a) * 520.0, randf_range(10.0, 70.0), -60.0 - cos(a) * 520.0)
		var r := randf_range(35.0, 60.0)
		Builders.island(self, c, r, r * 1.6, false, false)


func _no_shadows(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_no_shadows(c)


## Applies a graphics preset. "performance" targets integrated GPUs.
func apply_quality(q: String) -> void:
	var high := q == "quality"
	env.ssao_enabled = high
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if high else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 120.0 if high else 55.0
	var vp := get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
	vp.scaling_3d_scale = 1.0 if high else 0.67
	vp.msaa_3d = Viewport.MSAA_2X if high else Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED if high else Viewport.SCREEN_SPACE_AA_FXAA
	RenderingServer.directional_soft_shadow_filter_set_quality(
		RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM if high else RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW)
	RenderingServer.directional_shadow_atlas_set_size(4096 if high else 2048, true)


func _echo_platform(pos: Vector3, size: Vector3) -> EchoPlatform:
	var p := EchoPlatform.new()
	p.size = size
	p.position = pos
	add_child(p)
	return p


func _checkpoint(pos: Vector3, yaw: float) -> void:
	var c := Checkpoint.new()
	c.yaw = yaw
	c.position = pos
	add_child(c)


func _zone(pos: Vector3, size: Vector3, cb: Callable) -> void:
	var z := TriggerZone.new()
	z.size = size
	z.callback = cb
	z.position = pos
	add_child(z)


func _pulse_marker(pos: Vector3) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Game.ECHO_CYAN
	mat.emission_enabled = true
	mat.emission = Game.ECHO_CYAN
	mat.emission_energy_multiplier = 2.0
	for r in [0.35, 0.8, 1.3]:
		var ring := MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = r
		t.outer_radius = r + 0.07
		ring.mesh = t
		ring.scale.y = 0.15
		ring.material_override = mat
		ring.position = pos
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)


func _holo_arch(pos: Vector3, rot_y: float) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = rot_y
	add_child(root)
	var parts := [
		[Vector3(1, 6, 1), Vector3(-2.5, 3, 0)],
		[Vector3(1, 6, 1), Vector3(2.5, 3, 0)],
		[Vector3(7, 1, 1.2), Vector3(0, 6.5, 0)],
		[Vector3(7, 0.4, 3), Vector3(0, -0.2, 0)],
	]
	for p in parts:
		var h := HoloDecor.new()
		var b := BoxMesh.new()
		b.size = p[0]
		h.mesh = b
		h.half_size = p[0] * 0.5
		h.position = p[1]
		root.add_child(h)
