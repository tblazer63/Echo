class_name LevelTwoLayout
extends RefCounted
## LEVEL 2 "Dissonant Heights": start ruin -> fading hidden stair -> drone arena
## (with phantom drones + side detour) -> Echo Surf -> clone-gate pier ->
## machine bridge -> Sentinel + Second Resonance Spire.

const START := Vector3(0, 0, 1)
const ISLAND_E := Vector3(0, 4.5, -38.3)        # arena (near edge z -30.3)
const DETOUR := Vector3(18.8, 6.0, -38.3)       # tiny shard islet east of E
const ISLAND_F := Vector3(-12, 6.5, -82)        # clone puzzle
const ISLAND_G := Vector3(-12, 6.5, -114)       # final (near edge z -104)
const STEP_SIZE := Vector3(2.8, 0.4, 2.8)
const STEP_X: Array[float] = [0.0, 0.8, 1.6, 1.6, 0.8, 0.0]
const PIER_LEN := 7.4                           # F+(0,0,-7.6) -> F+(0,0,-15)
const BRIDGE_LEN := 7.5                         # pivot F.z-15 -> G edge F.z-22 (+0.5)


static func build(level: ResonantCrossing) -> void:
	level.set_golden_hour()
	_build_start(level)
	_build_arena(level)
	_build_surf(level)
	_build_clone_island(level)
	_build_final(level)
	_build_restoration(level)
	Game.set_objective("Climb the Dissonant Heights")


static func _build_start(level: ResonantCrossing) -> void:
	level.add_island(START, 7.5, 9.0)
	level.add_checkpoint(Vector3(0, 0, 3), 0.0)
	Builders.arch(level, Vector3(0, 0, 6.2), 4.0, 5.0, 0.0)
	Builders.pillar(level, Vector3(-5.2, 0, -2.5), 5.5, 1.1, true)
	Builders.pillar(level, Vector3(5.0, 0, -3.5), 7.0)
	Builders.pillar(level, Vector3(4.8, 0, 3.5), 3.0, 1.0, true)
	Builders.waterfall(level, Vector3(-7.45, -0.4, 3.0), 2.0, 18.0, deg_to_rad(-90))
	level.pulse_marker(Vector3(0, 0.03, -4.0))
	level.add_zone(Vector3(0, 1.5, -3.5), Vector3(10, 3, 4), func() -> void:
		Game.prompt("Hidden steps climb to the heights. They FADE after a few seconds: Echo Scan (Q) again mid-climb!", 6.0, "l2_intro"))
	# Six ascending hidden steps: 1.0 m gaps, +0.7 m each (tops 0.7 .. 4.2).
	for i in 6:
		var x: float = STEP_X[i]
		var top := 0.7 * float(i + 1)
		level.add_echo_platform(Vector3(x, top - 0.2, -8.9 - 3.8 * float(i)), STEP_SIZE)
	# Reminder on step 3 (top 2.1): steps 4+ are out of scan range from the start
	# island, and a rescan from step 3 reaches step 6 (~11.6 m) in one go.
	level.add_zone(Vector3(1.6, 3.6, -16.5), Vector3(3, 3, 3), func() -> void:
		Game.prompt("The steps are fading. Scan again from here!", 3.0, "l2_rescan"))


static func _build_arena(level: ResonantCrossing) -> void:
	var e := ISLAND_E
	level.add_island(e, 8.0, 12.0)
	level.add_checkpoint(e + Vector3(0, 0, 5.5), 0.0)
	Builders.pillar(level, e + Vector3(-5.0, 0, -1.0), 6.0)
	Builders.pillar(level, e + Vector3(5.5, 0, -4.0), 4.0, 1.1, true)
	Builders.arch(level, e + Vector3(6.0, 0, 0.0), 3.0, 4.0, deg_to_rad(90))
	Builders.waterfall(level, e + Vector3(-7.95, -0.4, 2.0), 2.5, 24.0, deg_to_rad(-90))
	level.add_shard(e + Vector3(-5.2, 1.2, -2.8))  # tucked behind the pillar
	for off: Vector3 in [Vector3(-3.5, 4.0, -2.5), Vector3(3.5, 3.5, -4.0)]:
		level.add_drone(e + off, false)
	for off: Vector3 in [Vector3(0.0, 5.0, -6.0), Vector3(-4.0, 4.5, 3.0)]:
		level.add_drone(e + off, true)
	level.add_zone(e + Vector3(0, 1.5, 6.5), Vector3(14, 3, 3), func() -> void:
		Game.set_objective("Silence the drones")
		Game.set_progress("Drones disabled  0 / %d" % level.drones.size())
		Game.prompt("Two PHANTOM drones are invisible until your Echo Scan (Q) reveals them!", 6.0, "l2_phantom"))
	# Side detour through the east arch: two hidden steps to a shard islet.
	level.pulse_marker(e + Vector3(7.0, 0.03, 0.0))
	level.add_echo_platform(e + Vector3(10.4, 0.2, 0.0), STEP_SIZE)   # top 4.9
	level.add_echo_platform(e + Vector3(14.2, 0.9, 0.0), STEP_SIZE)   # top 5.6
	level.add_island(DETOUR, 2.2, 4.0)                                # top 6.0
	Builders.pillar(level, DETOUR + Vector3(1.0, 0, -1.0), 2.5, 0.8, true)
	level.add_shard(DETOUR + Vector3(-0.4, 1.2, 0.3))


static func _build_surf(level: ResonantCrossing) -> void:
	var f := ISLAND_F
	var pts := PackedVector3Array([
		ISLAND_E + Vector3(-2.5, 0.0, -5.0),   # generator on E
		Vector3(-3.5, 4.3, -50.5),             # stays above E's rim, then dives
		Vector3(1.5, 0.0, -56.5),
		Vector3(4.5, -1.5, -63.0),             # 6 m below the arena
		Vector3(2.0, 1.0, -70.0),
		Vector3(-3.5, 6.2, -74.0),
		f + Vector3(3.0, 0.0, 5.0),            # landing on F
	])
	level.setup_surf(pts, 10, 6)


static func _build_clone_island(level: ResonantCrossing) -> void:
	var f := ISLAND_F
	level.add_island(f, 8.0, 12.0)
	level.add_checkpoint(f + Vector3(1.5, 0, 2.5), 0.0)
	Builders.pillar(level, f + Vector3(0, 0, -0.5), 9.0, 1.6)       # splits the switches
	Builders.pillar(level, f + Vector3(-5.0, 0, 5.0), 3.5, 1.0, true)
	Builders.arch(level, f + Vector3(0, 0, -6.4), 4.0, 5.0, 0.0)    # frames the pier
	Builders.waterfall(level, f + Vector3(7.95, -0.4, -2.0), 3.0, 26.0, deg_to_rad(90))
	level.add_shard(f + Vector3(5.5, 1.2, -4.5))
	# Prompt only: the surf's `finished` handler already sets the step-by-step
	# switch objective, which this zone must not overwrite.
	level.add_zone(f + Vector3(1.5, 1.5, 3.0), Vector3(10, 3, 6), func() -> void:
		Game.prompt("Press  R  to record an Echo Clone, then hold the other switch yourself.", 6.0, "l2_clone"))
	# Pier toward -Z; gate 1.3 m past the island edge (edge at f.z - 8).
	Builders.walkway(level, f + Vector3(0, 0, -7.6), f + Vector3(0, 0, -7.6 - PIER_LEN), 3.6)
	level.setup_clone_puzzle(f + Vector3(4.5, 0, -0.5), f + Vector3(-4.5, 0, -0.5), f + Vector3(0, 0, -9.3), 0.0)
	level.setup_machine_bridge(f + Vector3(1.3, 0, -14.0), f + Vector3(0, 0, -15.0), 0.0, BRIDGE_LEN)
	level.add_checkpoint(f + Vector3(-0.8, 0, -12.0), 0.0)


static func _build_final(level: ResonantCrossing) -> void:
	var g := ISLAND_G
	level.add_island(g, 10.0, 14.0)
	level.add_checkpoint(g + Vector3(-1.5, 0, 7.5), 0.0)
	level.setup_spire(g + Vector3(0, 0, -5.0))
	Builders.pillar(level, g + Vector3(-8.2, 0, -4.0), 9.0)
	Builders.pillar(level, g + Vector3(8.2, 0, -4.0), 9.0)
	Builders.pillar(level, g + Vector3(-6.0, 0, 6.5), 4.0, 1.0, true)
	level.add_shard(g + Vector3(-4.5, 1.2, -7.8))   # behind the spire (r 9.0 of 10)
	var pylons: Array = [g + Vector3(-7.6, 0, 0.5), g + Vector3(7.6, 0, 0.5), g + Vector3(4.5, 0, 6.8)]
	# The fight trigger spans the island's full width (z +1 .. +9), so every
	# route from the bridge to the (sealed) spire wakes the Sentinel.
	level.build_sentinel_arena(g + Vector3(0, 0, 2.0), pylons, 380.0, g + Vector3(0, 1.5, 5.0), Vector3(20, 4, 8))


static func _build_restoration(level: ResonantCrossing) -> void:
	var r: RestorationController = level.restoration
	if r == null:
		return
	r.add_crystals(level, START, 7.5, 6)
	r.add_crystals(level, ISLAND_E, 8.0, 8)
	r.add_crystals(level, DETOUR, 2.0, 2)
	r.add_crystals(level, ISLAND_F, 8.0, 7)
	r.add_crystals(level, ISLAND_G, 10.0, 10)
	r.add_flowers(level, ISLAND_G, 9.0, 150)
	r.add_flowers(level, ISLAND_F, 7.0, 50)
	r.add_waterfall_spot(level, ISLAND_G + Vector3(-9.95, -0.4, -2.0), 3.0, 30.0, deg_to_rad(-90))
	r.add_waterfall_spot(level, ISLAND_G + Vector3(9.95, -0.4, 2.0), 3.5, 30.0, deg_to_rad(90))


## Standing positions (feet height + 1.2, like the player spawn) for QA teleports.
static func spawn_points() -> Dictionary:
	var f := ISLAND_F
	var g := ISLAND_G
	var up := Vector3(0, 1.2, 0)
	return {
		"steps_start": Vector3(0, 0, -5.5) + up,
		"arena": ISLAND_E + Vector3(0, 0, 5.5) + up,
		# On the launch pad; the generator column sits at about E+(-2.06,0,-1.83).
		"surf_start_island": ISLAND_E + Vector3(-2.5, 0, -4.2) + up,
		"clone_island": f + Vector3(1.5, 0, 2.5) + up,
		"switch_a": f + Vector3(4.5, 0, -0.5) + up,
		"switch_b": f + Vector3(-4.5, 0, -0.5) + up,
		"pier_machine_side": f + Vector3(0, 0, -12.0) + up,
		# x -0.9 keeps the 0.38 m capsule clear of the machine box (x 0.1 .. 2.5).
		"bridge_walk_start": f + Vector3(-0.9, 0, -14.5) + up,
		"bridge_yaw_deg": 0.0,
		"spire_front": g + Vector3(0, 0, 0.0) + up,
		"final_island": g + Vector3(0, 0, 8.0) + up,
	}
