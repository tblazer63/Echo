extends Node3D
## Root orchestrator: builds the level, then runs either the main menu (orbiting
## camera over the ruins) or gameplay. Also hosts automated QA modes:
##   godot --path . -- --qa=logic            scripted gameplay assertions
##   godot --path . -- --qa=shots:<dir>      gameplay screenshots
##   godot --path . -- --qa=menu:<dir>       menu screenshot

var level: ResonantCrossing
var player: Player
var hud: Hud
var menus: Menus
var orbit_cam: Camera3D
var recorder: EchoCloneRecorder
var _t := 0.0
var _qa := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	RenderingServer.global_shader_parameter_set("echo_strength", 0.0)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--qa="):
			_qa = a.substr(5)
	if _qa.ends_with("2") or _qa.begins_with("tour2") or _qa.begins_with("shots2"):
		Game.level_id = 2
	level = ResonantCrossing.new()
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level)
	menus = Menus.new()
	add_child(menus)
	menus.play_pressed.connect(_on_play)
	menus.play_level.connect(func(id: int) -> void:
		if player == null and id == Game.level_id:
			_start_play()
		else:
			Game.level_id = id
			_reload("play"))
	menus.resume_pressed.connect(func() -> void: _set_paused(false))
	menus.restart_pressed.connect(func() -> void:
		_set_paused(false)
		player.respawn())
	menus.menu_pressed.connect(func() -> void: _reload("menu"))
	Game.level_won.connect(_on_won)

	if _qa.begins_with("menu"):
		_start_menu()
	elif Game.start_mode == "play" or _qa != "":
		_start_play()
	else:
		_start_menu()
	if _qa != "":
		_run_qa.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	if orbit_cam:
		orbit_cam.position = Vector3(3.0 * sin(_t * 0.08) + 1.0, 3.4 + 0.4 * sin(_t * 0.13), -1.5)
		orbit_cam.look_at(Vector3(0, 7.5, -95.0))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and player != null and not Game.won:
		_set_paused(not get_tree().paused)


func _start_menu() -> void:
	orbit_cam = Camera3D.new()
	orbit_cam.fov = 62.0
	orbit_cam.far = 3000.0
	add_child(orbit_cam)
	orbit_cam.current = true
	menus.show_main()


func _start_play() -> void:
	if orbit_cam:
		orbit_cam.queue_free()
		orbit_cam = null
	Game.reset_run()
	player = Player.new()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	player.global_position = Game.checkpoint_pos
	recorder = EchoCloneRecorder.new()
	recorder.player = player
	player.add_child(recorder)
	hud = Hud.new()
	hud.emitter = player.emitter
	hud.player = player
	hud.recorder = recorder
	add_child(hud)
	menus.hide_all()
	Game.running = true
	if Game.level_id == 1:
		Game.set_objective("Cross the gap. Let your echo reveal the way.")
		Game.prompt("LEVEL 1 · THE FIRST RESONANCE      WASD move · Space jump · Q Echo Scan", 5.0)
	else:
		Game.set_objective("Climb the Dissonant Heights")
		Game.prompt("LEVEL 2 · DISSONANT HEIGHTS      Hidden steps fade. Scan again mid-climb!", 6.0)
	Game.set_progress("")
	hud.flash(Color(0.85, 1, 1), 1.2)


func _on_play() -> void:
	if player == null:
		_start_play()
	else:
		_reload("play")


func _reload(mode: String) -> void:
	Game.start_mode = mode
	get_tree().paused = false
	get_tree().reload_current_scene()


func _set_paused(p: bool) -> void:
	get_tree().paused = p
	if p:
		menus.show_pause()
	else:
		menus.hide_all()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_won() -> void:
	player.input_enabled = false
	player.velocity = Vector3.ZERO
	hud.flash(Color(0.85, 1, 1), 2.0)
	Game.set_objective("Signal restored")
	# Cinematic: step back and look up at the restored gate.
	var gate_center := level.signal_gate.global_position + Vector3.UP * 7.0
	var back := Vector3(gate_center.x, player.global_position.y, gate_center.z + 13.0)
	var eye := back + Vector3.UP * 1.62
	var to := gate_center - eye
	var yaw := atan2(-to.x, -to.z)
	var pitch := atan2(to.y, Vector2(to.x, to.z).length())
	player.set_physics_process(false)
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(player, "global_position", back, 3.0)
	tw.tween_property(player, "rotation:y", yaw, 3.0)
	tw.tween_property(player.head, "rotation:x", pitch, 3.0)
	player.arm.visible = false
	await get_tree().create_timer(3.6).timeout
	hud.visible = false
	menus.show_victory(Game.format_time(Game.run_time))


# ------------------------------------------------------------------ QA

func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _shot(dir: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := dir.path_join(name)
	img.save_png(path)
	print("QA_SHOT %s  fps=%d  draw_calls=%d" % [path, Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])


func _teleport(pos: Vector3, yaw_deg: float, pitch_deg: float = 0.0) -> void:
	player.global_position = pos
	player.velocity = Vector3.ZERO
	player.rotation.y = deg_to_rad(yaw_deg)
	player.head.rotation.x = deg_to_rad(pitch_deg)


func _run_qa() -> void:
	if _qa.begins_with("menu:"):
		await _wait(3.0)
		await _shot(_qa.substr(5), "00_menu.png")
		get_tree().quit()
	elif _qa.begins_with("shots:"):
		await _qa_shots(_qa.substr(6))
	elif _qa == "logic":
		await _qa_logic()
	elif _qa == "logic2":
		await _qa_logic2()
	elif _qa.begins_with("perf"):
		await _qa_perf()
	elif _qa.begins_with("tour:"):
		await _qa_tour(_qa.substr(5))
	elif _qa.begins_with("tour2:"):
		await _qa_tour2(_qa.substr(6))


func _qa_tour2(dir: String) -> void:
	var sp: Dictionary = LevelTwoLayout.spawn_points()
	player.health.grant_iframes(999.0)
	await _wait(3.0)
	await _shot(dir, "30_l2_start.png")
	_teleport(sp["steps_start"], 0.0, 10.0)
	await _wait(0.5)
	player.emitter.charge = 1.0
	player.emitter.try_pulse()
	await _wait(1.2)
	await _shot(dir, "31_l2_steps.png")
	_teleport(sp["arena"], 0.0, 15.0)
	await _wait(2.0)
	player.emitter.charge = 1.0
	player.emitter.try_pulse()
	await _wait(0.6)
	await _shot(dir, "32_l2_arena_phantoms.png")
	for d in level.drones:
		var tries := 0
		while not d.is_defeated() and tries < 20:
			if d is PhantomDrone and not (d as PhantomDrone).is_revealed():
				d.on_echo(d.global_position, PulseWave.spawn(self, d.global_position, 0.5, true))
			d.take_damage(40.0, d.global_position)
			await _wait(0.1)
			tries += 1
	await _wait(1.0)
	_teleport(sp["surf_start_island"], 0.0)
	await _wait(0.3)
	level.surf.board(player)
	await _wait(1.8)
	await _shot(dir, "33_l2_surf_obstacles.png")
	while level.surf.is_riding():
		await _wait(0.2)
	await _wait(0.8)
	_teleport(sp["clone_island"], 0.0, 5.0)
	await _wait(1.0)
	await _shot(dir, "34_l2_clone_island.png")
	_teleport(sp["switch_a"], 0.0)
	await _press("record")
	await _wait(0.8)
	await _press("record")
	await _wait(0.4)
	_teleport(sp["switch_b"], 0.0)
	await _wait(3.0)
	_teleport(sp["pier_machine_side"], 0.0)
	player.emitter.charge = 1.0
	player.emitter.try_pulse()
	await _wait(4.0)
	_teleport(sp["bridge_walk_start"], sp["bridge_yaw_deg"], 6.0)
	await _wait(0.8)
	await _shot(dir, "35_l2_bridge.png")
	_teleport(Vector3(sp["final_island"]) + Vector3(0, 0, 6.0), 0.0, 18.0)
	await _wait(2.5)
	await _shot(dir, "36_l2_sentinel.png")
	var boss := level.sentinel
	if not boss.active:
		boss.start_fight()
	var guard := 0
	while not boss.is_defeated() and guard < 120:
		if boss.shield_up:
			for p in level.pylons:
				p.disable()
		boss.take_damage(20.0, boss.global_position)
		await _wait(0.05)
		guard += 1
	await _wait(1.0)
	_teleport(sp["spire_front"], 0.0)
	Input.action_press("move_forward")
	await _wait(1.6)
	Input.action_release("move_forward")
	await _wait(3.5)
	await _shot(dir, "37_l2_restored.png")
	await _wait(1.5)
	await _shot(dir, "38_l2_victory.png")
	print("QA_TOUR_DONE")
	get_tree().quit()


func _press(action: String) -> void:
	Input.action_press(action)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(action)


## Level 2 "Dissonant Heights" scripted playthrough.
func _qa_logic2() -> void:
	var fails: Array = []
	var sp: Dictionary = LevelTwoLayout.spawn_points()
	player.health.grant_iframes(999.0)
	var waited := 0.0
	while not player.is_on_floor() and waited < 6.0:
		await _wait(0.1)
		waited += 0.1
	_check(player.is_on_floor(), "L2: player spawns on floor (pos %s)" % str(player.global_position), fails)
	_check(Game.level_id == 2, "L2: level 2 is loaded", fails)
	_check(Game.shards_total >= 3, "L2: has %d shards" % Game.shards_total, fails)

	# 1. Hidden ascending steps reveal on scan.
	var steps_start: Vector3 = sp["steps_start"]
	_teleport(steps_start + Vector3.UP * 0.2, 0.0)
	await _wait(0.6)
	player.emitter.charge = 1.0
	player.emitter.try_pulse()
	await _wait(1.0)
	var active := 0
	for n in get_tree().get_nodes_in_group("echo_reactive"):
		if n is EchoPlatform and (n as EchoPlatform).is_active():
			active += 1
	_check(active >= 2, "L2: scan reveals hidden steps (%d active)" % active, fails)

	# 2. Arena: phantoms are immune until revealed, then all drones go down.
	var arena: Vector3 = sp["arena"]
	_teleport(arena + Vector3.UP * 0.2, 0.0)
	await _wait(1.5)
	var drones := level.drones
	_check(drones.size() >= 4, "L2: arena has %d drones" % drones.size(), fails)
	var phantom: PhantomDrone = null
	for d in drones:
		if d is PhantomDrone:
			phantom = d
	_check(phantom != null, "L2: arena includes a Phantom drone", fails)
	if phantom:
		var hp0: float = phantom.hp
		phantom.take_damage(20.0, phantom.global_position)
		_check(is_equal_approx(phantom.hp, hp0), "L2: cloaked phantom ignores damage", fails)
	_check(not level.surf.enabled, "L2: surf dormant before arena cleared", fails)
	for d in drones:
		var tries := 0
		while not d.is_defeated() and tries < 20:
			if d is PhantomDrone and not (d as PhantomDrone).is_revealed():
				_teleport(d.global_position + Vector3(0, -3.0, 2.0), 0.0)
				player.emitter.charge = 1.0
				player.emitter.try_pulse()
				await _wait(0.8)
			var from := d.global_position + Vector3(0, 0.5, 3.0)
			SonicBolt.fire(self, from, (d.global_position - from).normalized())
			await _wait(0.25)
			tries += 1
	_check(drones.all(func(x: EchoDrone) -> bool: return x.is_defeated()), "L2: all arena drones defeated (phantoms via scan)", fails)
	await _wait(0.5)
	_check(level.surf.enabled, "L2: clearing the arena activates the surf", fails)

	# 3. Surf with obstacles to the clone island.
	_teleport(arena + Vector3.UP * 0.2, 0.0)
	await _wait(0.3)
	level.surf.board(player)
	var ride := 0.0
	while level.surf.is_riding() and ride < 25.0:
		await _wait(0.25)
		ride += 0.25
	await _wait(0.8)
	var clone_island: Vector3 = sp["clone_island"]
	_check(player.global_position.distance_to(clone_island) < 10.0, "L2: surf (%.1fs) lands on the clone island (pos %s)" % [ride, str(player.global_position)], fails)

	# 4. Clone puzzle with the real R key.
	var sa: Vector3 = sp["switch_a"]
	var sb: Vector3 = sp["switch_b"]
	_teleport(sa + Vector3.UP * 0.2, 0.0)
	await _wait(0.5)
	await _press("record")
	await _wait(1.0)
	await _press("record")
	await _wait(0.6)
	_teleport(sb + Vector3.UP * 0.2, 0.0)
	await _wait(1.0)
	_check(level.clone_gate.is_open, "L2: echo clone + player open the gate", fails)

	# 5. Machine + bridge.
	await _wait(2.5)
	var ms: Vector3 = sp["pier_machine_side"]
	_teleport(ms + Vector3.UP * 0.2, 0.0)
	await _wait(0.5)
	player.emitter.charge = 1.0
	player.emitter.try_pulse()
	await _wait(4.0)
	_check(level.bridge.active and level.bridge.is_settled(), "L2: scan transforms the bridge", fails)
	var bws: Vector3 = sp["bridge_walk_start"]
	var byaw: float = sp["bridge_yaw_deg"]
	_teleport(bws + Vector3.UP * 0.2, byaw)
	await _wait(0.4)
	Input.action_press("move_forward")
	await _wait(2.6)
	Input.action_release("move_forward")
	await _wait(0.5)
	var fin: Vector3 = sp["final_island"]
	var dfin := Vector2(player.global_position.x - fin.x, player.global_position.z - fin.z).length()
	_check(dfin < 10.5 and player.global_position.y > fin.y - 2.5, "L2: crossed the bridge to the final island (d %.1f, pos %s)" % [dfin, str(player.global_position)], fails)

	# 6. Sentinel (3 pylons).
	await _wait(1.0)
	var boss := level.sentinel
	if not boss.active:
		boss.start_fight()
		level.signal_gate.sealed = true
	_check(level.pylons.size() == 3, "L2: Sentinel has 3 pylons", fails)
	var guard := 0
	while not boss.is_defeated() and guard < 120:
		if boss.shield_up:
			for p in level.pylons:
				p.disable()
		boss.take_damage(20.0, boss.global_position)
		await _wait(0.05)
		guard += 1
	await _wait(0.5)
	_check(boss.is_defeated() and not level.signal_gate.sealed, "L2: Sentinel defeated, spire unsealed", fails)

	# 7. Final spire.
	var front: Vector3 = sp["spire_front"]
	_teleport(front + Vector3.UP * 0.2, 0.0)
	await _wait(0.3)
	Input.action_press("move_forward")
	await _wait(1.8)
	Input.action_release("move_forward")
	await _wait(1.5)
	_check(Game.won and level.restoration.restored, "L2: restoring the Second Spire wins (pos %s)" % str(player.global_position), fails)
	print("QA_RESULT ", "PASS" if fails.is_empty() else "FAIL %s" % str(fails))
	get_tree().quit(0 if fails.is_empty() else 1)


## Screenshot tour of the Last Resonance systems (combat, surf, clone, bridge, restoration).
func _qa_tour(dir: String) -> void:
	player.health.grant_iframes(999.0)
	var B := ResonantCrossing.ISLAND_B
	var D := ResonantCrossing.ISLAND_D
	_teleport(B + Vector3(0, 0.2, 5.0), 0.0, 14.0)
	await _wait(3.0)
	await _shot(dir, "10_combat.png")
	player.emitter.charge = 1.0
	player.emitter.try_pulse()
	await _wait(0.5)
	await _shot(dir, "11_combat_scan.png")
	for i in 4:
		player.emitter.charge = 1.0
		player.emitter.try_fire(player.camera, player._muzzle())
		await _wait(0.12)
	await _shot(dir, "12_bolts.png")
	for d in level.drones:
		var tries := 0
		while not d.is_defeated() and tries < 15:
			var from := d.global_position + Vector3(0, 0.5, 3.0)
			SonicBolt.fire(self, from, (d.global_position - from).normalized())
			await _wait(0.3)
			tries += 1
	await _wait(1.0)
	_teleport(B + Vector3(3.0, 0.2, 0.5), 160.0, 0.0)
	await _wait(1.0)
	await _shot(dir, "13_generator.png")
	level.surf.board(player)
	await _wait(1.6)
	await _shot(dir, "14_surf.png")
	while level.surf.is_riding():
		await _wait(0.2)
	await _wait(0.6)
	_teleport(D + Vector3(4.0, 0.2, 0.0), 90.0, 12.0)
	await _wait(1.2)
	await _shot(dir, "15_temple_isle.png")
	_teleport(level.switch_a.global_position + Vector3.UP * 0.2, 90.0)
	await _wait(0.4)
	recorder.start_recording()
	await _wait(0.8)
	recorder.stop_recording()
	await _wait(0.5)
	_teleport(D + Vector3(3.5, 0.2, -1.0), 70.0, 8.0)
	await _wait(1.0)
	await _shot(dir, "16_clone.png")
	_teleport(level.switch_b.global_position + Vector3.UP * 0.2, 90.0)
	await _wait(3.0)
	_teleport(D + Vector3(-10.0, 0.2, -0.6), 90.0, 4.0)
	await _wait(0.6)
	player.emitter.charge = 1.0
	player.emitter.try_pulse()
	await _wait(1.6)
	await _shot(dir, "17_bridge_moving.png")
	await _wait(2.6)
	await _shot(dir, "18_bridge_done.png")
	_teleport(ResonantCrossing.ISLAND_C + Vector3(7.5, 0.2, 2.5), 85.0, 22.0)
	await _wait(2.5)
	await _shot(dir, "18b_sentinel.png")
	for p in level.pylons:
		p.disable()
	await _wait(0.6)
	player.emitter.charge = 1.0
	player.emitter.try_pulse()
	await _wait(0.5)
	await _shot(dir, "18c_sentinel_exposed.png")
	var guard := 0
	while not level.sentinel.is_defeated() and guard < 80:
		if level.sentinel.shield_up:
			for p in level.pylons:
				p.disable()
		level.sentinel.take_damage(20.0, level.sentinel.global_position)
		await _wait(0.05)
		guard += 1
	await _wait(1.5)
	_teleport(Vector3(0, 4.2, -84), 0.0, 0.0)
	await _wait(0.5)
	await _shot(dir, "19_spire_corrupted.png")
	Input.action_press("move_forward")
	await _wait(1.6)
	Input.action_release("move_forward")
	await _wait(3.5)
	await _shot(dir, "20_restored.png")
	await _wait(2.0)
	await _shot(dir, "21_victory.png")
	print("QA_TOUR_DONE")
	get_tree().quit()


## Stable perf measurement: settle, then average over a window per viewpoint.
func _qa_perf() -> void:
	var spots := [
		["start", Vector3(0, 0.2, 3), 0.0],
		["hub", Vector3(0, 0.2, -22), 0.0],
		["combat", Vector3(0, 0.2, -49), 0.0],
		["temple", Vector3(33, 4.2, -88), 90.0],
		["spire", Vector3(5, 4.2, -84), 45.0],
	]
	await _wait(4.0)
	for s in spots:
		_teleport(s[1], s[2], 0.0)
		await _wait(2.5)  # let shaders compile / caches warm
		var frames := 0
		var t0 := Time.get_ticks_usec()
		var proc := 0.0
		var phys := 0.0
		while Time.get_ticks_usec() - t0 < 3_000_000:
			await get_tree().process_frame
			frames += 1
			proc += Performance.get_monitor(Performance.TIME_PROCESS)
			phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		var secs := (Time.get_ticks_usec() - t0) / 1_000_000.0
		print("QA_PERF %-6s fps=%.1f  cpu_process=%.1fms  cpu_physics=%.1fms  draw_calls=%d  quality=%s" % [
			s[0], frames / secs, proc / frames * 1000.0, phys / frames * 1000.0,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Game.quality])
	get_tree().quit()


func _qa_shots(dir: String) -> void:
	await _wait(2.5)
	await _shot(dir, "01_start.png")
	player.emitter.try_pulse()
	await _wait(0.45)
	await _shot(dir, "02_start_pulse.png")
	await _wait(1.2)
	await _shot(dir, "03_bridge_revealed.png")
	_teleport(Vector3(-6, 0.2, -24), 125.0, -3.0)
	await _wait(1.5)
	player.emitter.try_pulse()
	await _wait(0.6)
	await _shot(dir, "04_hub_pulse.png")
	_teleport(Vector3(-21.5, 0.2, -25.0), 75.0, 6.0)
	await _wait(1.3)
	player.emitter.try_pulse()
	await _wait(1.0)
	await _shot(dir, "05_relay_beam.png")
	_teleport(Vector3(0, 0.2, -55), 0.0, 8.0)
	await _wait(1.5)
	player.emitter.try_pulse()
	await _wait(0.9)
	await _shot(dir, "06_steps.png")
	_teleport(Vector3(2, 4.2, -80), 0.0, 10.0)
	await _wait(1.5)
	await _shot(dir, "07_signal_gate.png")
	_teleport(Vector3(0, 4.2, -89.2), 0.0, 14.0)
	await _wait(2.5)
	await _shot(dir, "08_restored.png")
	await _wait(2.0)
	await _shot(dir, "09_victory.png")
	print("QA_SHOTS_DONE")
	get_tree().quit()


func _check(ok: bool, what: String, fails: Array) -> void:
	print(("QA_PASS " if ok else "QA_FAIL ") + what)
	if not ok:
		fails.append(what)


func _qa_logic() -> void:
	var fails: Array = []
	var waited := 0.0
	while not player.is_on_floor() and waited < 6.0:
		await _wait(0.1)
		waited += 0.1
	_check(player.is_on_floor() and player.global_position.y > -0.2, "player spawns on floor (pos %s, %.1fs)" % [str(player.global_position), waited], fails)
	_check(Game.shards_total >= 6, "level 1 has %d energy shards" % Game.shards_total, fails)
	_teleport(Vector3(0, 0.2, 6.2), 0.0)
	await _wait(0.6)
	_check(Game.shards == 1, "walking into a shard collects it", fails)
	_teleport(Vector3(0, 0.2, 3.0), 0.0)
	await _wait(0.3)

	# 1. Bridge hidden before pulse: walking forward should NOT be possible yet.
	var bridge := _platforms_between(-20.0, -6.0)
	_check(bridge.size() == 4, "4 hidden bridge platforms exist (got %d)" % bridge.size(), fails)
	_check(bridge.all(func(p: EchoPlatform) -> bool: return not p.is_active()), "bridge inactive before pulse", fails)

	# 2. Pulse from the marker and actually walk across with simulated input.
	_teleport(Vector3(0, 0.2, -4.5), 0.0)
	await _wait(0.4)
	_check(player.emitter.try_pulse(), "pulse fires", fails)
	await _wait(1.0)
	_check(bridge.all(func(p: EchoPlatform) -> bool: return p.is_active()), "bridge active after pulse", fails)
	Input.action_press("move_forward")
	await _wait(3.6)
	Input.action_release("move_forward")
	await _wait(0.3)
	_check(player.global_position.z < -19.5 and player.global_position.y > -1.0,
		"walked across revealed bridge (pos %s)" % str(player.global_position), fails)

	# 3. Cooldown blocks immediate re-pulse.
	player.emitter.charge = 1.0
	player.emitter.try_pulse()
	_check(not player.emitter.try_pulse(), "cooldown blocks spam", fails)

	# 4. Gate locked; relay out of reach from hub edge.
	_check(not level.gate.is_open, "gate starts locked", fails)
	_teleport(Vector3(-7.5, 0.2, -27), 90.0)
	await _wait(1.3)
	player.emitter.charge = 1.0
	player.emitter.try_pulse()
	await _wait(1.5)
	_check(not level.relay.activated, "relay NOT reachable from hub edge", fails)

	# 5. Pulse on relay islet opens the gate.
	_teleport(Vector3(-22.5, 0.2, -27), 90.0)
	await _wait(0.5)
	player.emitter.charge = 1.0
	player.emitter.try_pulse()
	await _wait(2.5)
	_check(level.relay.activated, "relay activated from islet", fails)
	_check(level.gate.is_open, "gate opened by relay", fails)

	# 6. Platforms expire and respawn works.
	await _wait(7.5)
	_check(bridge.all(func(p: EchoPlatform) -> bool: return not p.is_active()), "bridge deactivates after timeout", fails)
	_teleport(Vector3(0, -30, -40), 0.0)
	await _wait(0.5)
	_check(player.global_position.y > -5.0 and player.global_position.distance_to(Vector3(-22.4, 0.0, -27.0)) < 1.0,
		"fall respawns at the LAST checkpoint, relay islet (pos %s)" % str(player.global_position), fails)

	# 7. Combat on island B (player made invulnerable so the test is deterministic).
	player.health.grant_iframes(999.0)
	_teleport(ResonantCrossing.ISLAND_B + Vector3(0, 0.2, 4.0), 0.0)
	await _wait(1.5)
	var drones := level.drones
	_check(drones.size() == 3, "3 Echo Drones on island B", fails)
	_check(not level.surf.enabled, "surf generator dormant before combat", fails)
	player.emitter.charge = 1.0
	_check(player.emitter.try_fire(player.camera, player._muzzle()), "Sonic Bolt fires", fails)
	for d in drones:
		var tries := 0
		while not d.is_defeated() and tries < 15:
			var from := d.global_position + Vector3(0, 0.5, 3.0)
			SonicBolt.fire(self, from, (d.global_position - from).normalized())
			await _wait(0.3)
			tries += 1
	_check(drones.all(func(d: EchoDrone) -> bool: return d.is_defeated()), "all drones disabled by Sonic Bolts", fails)
	await _wait(0.5)
	_check(level.surf.enabled, "clearing drones activates the surf generator", fails)

	# 8. Echo Surf B -> D.
	level.surf.board(player)
	var ride := 0.0
	while level.surf.is_riding() and ride < 20.0:
		await _wait(0.25)
		ride += 0.25
	await _wait(0.8)
	_check(player.global_position.distance_to(ResonantCrossing.ISLAND_D) < 8.0 and player.global_position.y > 3.0,
		"surf delivers player to island D in %.1fs (pos %s)" % [ride, str(player.global_position)], fails)

	# 9. Clone puzzle: clone holds switch A while the player stands on B.
	_check(not level.clone_gate.is_open, "clone gate starts locked", fails)
	# 9a. Commanded echo: C sends it to switch A, V makes it follow away.
	var mid := (level.switch_a.global_position + level.switch_b.global_position) * 0.5
	_teleport(mid + Vector3.UP * 0.2, 90.0)
	await _wait(0.4)
	recorder.command_move(level.switch_a.global_position)
	await _wait(2.2)
	var cc := recorder.current_clone
	_check(cc != null and cc.global_position.distance_to(level.switch_a.global_position) < 0.6,
		"commanded echo walks onto switch A (%s)" % (str(cc.global_position) if cc else "none"), fails)
	_check(level.switch_a.is_pressed() and not level.clone_gate.is_open, "commanded echo holds switch A (gate still locked)", fails)
	_teleport(ResonantCrossing.ISLAND_D + Vector3(3.0, 0.2, 0.0), 90.0)
	await _wait(0.2)
	recorder.command_follow()
	await _wait(2.5)
	_check(not level.switch_a.is_pressed() and cc != null and cc.global_position.distance_to(player.global_position) < 4.0,
		"V: echo follows the player off switch A (dist %.1f)" % (cc.global_position.distance_to(player.global_position) if cc else -1.0), fails)
	recorder.clear_clone()
	await _wait(0.6)
	# 9b. Echo Lift co-op puzzle: echo holds the LIFT switch, the lift rises.
	_check(level.echo_lifts.size() == 1, "level 1 has an Echo Lift", fails)
	if level.echo_lifts.size() == 1:
		var lift: EchoLift = level.echo_lifts[0]
		_teleport(ResonantCrossing.ISLAND_D + Vector3(0.5, 0.2, 6.5), 90.0)
		await _wait(0.3)
		_check(not lift.is_up(), "lift starts down", fails)
		recorder.command_move(lift.sw.global_position)
		await _wait(5.5)
		_check(lift.sw.is_pressed() and lift.is_up(), "echo on the LIFT switch raises the lift (y %.1f)" % lift.position.y, fails)
		recorder.clear_clone()
		await _wait(0.6)
	_teleport(level.switch_a.global_position + Vector3.UP * 0.2, 90.0)
	await _wait(0.5)
	await _press("record")
	await _wait(0.2)
	_check(recorder.is_recording, "R key starts echo recording", fails)
	await _wait(0.8)
	await _press("record")
	await _wait(0.6)
	_check(get_tree().get_nodes_in_group("clone").size() == 1, "R key again spawns the echo clone", fails)
	_teleport(level.switch_b.global_position + Vector3.UP * 0.2, 90.0)
	await _wait(1.0)
	_check(level.switch_a.is_pressed(), "clone keeps switch A pressed", fails)
	_check(level.switch_b.is_pressed(), "player presses switch B", fails)
	_check(level.clone_gate.is_open, "two switches open the temple gate", fails)

	# 10. Resonance machine transforms the bridge; walk across it to the spire.
	await _wait(2.5)
	_check(not level.bridge.active, "bridge broken before machine", fails)
	_teleport(ResonantCrossing.ISLAND_D + Vector3(-10.5, 0.2, -0.5), 90.0)
	await _wait(0.5)
	player.emitter.charge = 1.0
	player.emitter.try_pulse()
	await _wait(4.0)
	_check(level.machine.activated, "echo activates the resonance machine", fails)
	_check(level.bridge.active and level.bridge.is_settled(), "bridge transformed into place", fails)
	_teleport(ResonantCrossing.ISLAND_D + Vector3(-12.0, 0.2, -0.5), 90.0)
	await _wait(0.4)
	Input.action_press("move_forward")
	await _wait(2.2)
	Input.action_release("move_forward")
	await _wait(0.4)
	_check(player.global_position.x < 9.0 and player.global_position.y > 3.0,
		"walked across the bridge to the spire island (pos %s)" % str(player.global_position), fails)

	# 10b. Sentinel mini-boss (entered the arena by walking off the bridge).
	await _wait(1.0)
	var boss := level.sentinel
	_check(boss.active, "Sentinel awakens when the player enters the arena", fails)
	_check(level.signal_gate.sealed, "Spire sealed while the Sentinel lives", fails)
	var hp0 := boss.hp
	boss.take_damage(50.0, boss.global_position)
	_check(is_equal_approx(boss.hp, hp0), "shield blocks damage while pylons stand", fails)
	for p in level.pylons:
		p.disable()
	await _wait(0.3)
	_check(not boss.shield_up, "breaking both pylons drops the shield", fails)
	var guard := 0
	while boss.phase == 1 and guard < 60:
		boss.take_damage(20.0, boss.global_position)
		await _wait(0.05)
		guard += 1
	await _wait(0.3)
	_check(boss.phase == 2 and boss.shield_up, "phase 2 re-forms the shield", fails)
	for p in level.pylons:
		p.disable()
	await _wait(0.3)
	guard = 0
	while not boss.is_defeated() and guard < 60:
		boss.take_damage(20.0, boss.global_position)
		await _wait(0.05)
		guard += 1
	await _wait(0.5)
	_check(boss.is_defeated(), "Sentinel defeated", fails)
	_check(not level.signal_gate.sealed, "defeating the Sentinel unseals the Spire", fails)

	# 11. Signal gate win + world restoration.
	_check(not level.restoration.restored, "world starts corrupted", fails)
	_teleport(Vector3(0, 4.2, -83), 0.0)
	await _wait(0.5)
	_check(not Game.won, "not won before reaching gate", fails)
	Input.action_press("move_forward")
	await _wait(2.5)
	Input.action_release("move_forward")
	await _wait(0.3)
	_check(Game.won, "walking into Signal Gate wins (pos %s)" % str(player.global_position), fails)
	await _wait(1.0)
	_check(level.restoration.restored, "spire restoration transforms the world", fails)

	print("QA_RESULT ", "PASS" if fails.is_empty() else "FAIL %s" % str(fails))
	get_tree().quit(0 if fails.is_empty() else 1)


func _platforms_between(z_min: float, z_max: float) -> Array:
	var out: Array = []
	for n in get_tree().get_nodes_in_group("echo_reactive"):
		if n is EchoPlatform and n.global_position.z > z_min and n.global_position.z < z_max and absf(n.global_position.x) < 3.0:
			out.append(n)
	out.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.global_position.z > b.global_position.z)
	return out
