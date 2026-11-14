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
var _t := 0.0
var _qa := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	RenderingServer.global_shader_parameter_set("echo_strength", 0.0)
	level = ResonantCrossing.new()
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level)
	menus = Menus.new()
	add_child(menus)
	menus.play_pressed.connect(_on_play)
	menus.resume_pressed.connect(func() -> void: _set_paused(false))
	menus.restart_pressed.connect(func() -> void:
		_set_paused(false)
		player.respawn())
	menus.menu_pressed.connect(func() -> void: _reload("menu"))
	Game.level_won.connect(_on_won)

	for a in OS.get_cmdline_user_args():
		if a.begins_with("--qa="):
			_qa = a.substr(5)

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
	hud = Hud.new()
	hud.emitter = player.emitter
	add_child(hud)
	menus.hide_all()
	Game.running = true
	Game.set_objective("Cross the gap. Let your echo reveal the way.")
	Game.prompt("WASD move  ·  Mouse look  ·  Space jump  ·  Shift sprint", 5.0, "move_hint")
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
	elif _qa.begins_with("perf"):
		await _qa_perf()


## Stable perf measurement: settle, then average over a window per viewpoint.
func _qa_perf() -> void:
	var spots := [
		["start", Vector3(0, 0.2, 3), 0.0],
		["hub", Vector3(0, 0.2, -22), 0.0],
		["steps", Vector3(0, 0.2, -55), 0.0],
		["gate", Vector3(0, 4.2, -80), 0.0],
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
	_check(player.global_position.y > -5.0, "fall respawns at checkpoint (pos %s)" % str(player.global_position), fails)

	# 7. Timed steps: pulse from B edge reveals first steps but not the last.
	_teleport(Vector3(0, 0.2, -58.5), 0.0)
	await _wait(0.5)
	player.emitter.charge = 1.0
	player.emitter.try_pulse()
	await _wait(1.5)
	var steps := _platforms_between(-79.0, -60.0)
	_check(steps.size() == 5, "5 timed steps exist", fails)
	if steps.size() == 5:
		_check(steps[0].is_active() and not steps[4].is_active(), "first step revealed, last needs a 2nd pulse", fails)

	# 8. Signal gate win.
	_teleport(Vector3(0, 4.2, -83), 0.0)
	await _wait(0.5)
	_check(not Game.won, "not won before reaching gate", fails)
	Input.action_press("move_forward")
	await _wait(2.5)
	Input.action_release("move_forward")
	await _wait(0.3)
	_check(Game.won, "walking into Signal Gate wins (pos %s)" % str(player.global_position), fails)

	print("QA_RESULT ", "PASS" if fails.is_empty() else "FAIL %s" % str(fails))
	get_tree().quit(0 if fails.is_empty() else 1)


func _platforms_between(z_min: float, z_max: float) -> Array:
	var out: Array = []
	for n in get_tree().get_nodes_in_group("echo_reactive"):
		if n is EchoPlatform and n.global_position.z > z_min and n.global_position.z < z_max and absf(n.global_position.x) < 3.0:
			out.append(n)
	out.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.global_position.z > b.global_position.z)
	return out
