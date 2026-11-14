extends Node
## Global game state: input map, objectives, prompts, checkpoints, settings.

signal objective_changed(text: String)
signal prompt_requested(text: String, duration: float)
signal checkpoint_reached(pos: Vector3)
signal level_won
signal player_respawned
## Secondary objective line (e.g. "Drones disabled 1 / 3").
signal progress_changed(text: String)

var progress: String = ""
## Which level to build (1 = Resonant Crossing, 2 = Dissonant Heights).
var level_id: int = 1
const LEVEL_NAMES := ["", "THE FIRST RESONANCE", "DISSONANT HEIGHTS"]
# Run stats for the victory screen.
var shards: int = 0
var shards_total: int = 0
var rings: int = 0
var rings_total: int = 0
var deaths: int = 0
var drones_down: int = 0
signal shards_changed(n: int, total: int)


func collect_shard() -> void:
	shards += 1
	shards_changed.emit(shards, shards_total)
	prompt("Energy Shard  %d / %d" % [shards, shards_total], 2.0)


## 0..100 score and letter rank for the victory screen.
func rank() -> Dictionary:
	var s := 0.0
	if shards_total > 0:
		s += 35.0 * float(shards) / float(shards_total)
	if rings_total > 0:
		s += 20.0 * float(rings) / float(rings_total)
	s += 25.0 if run_time < 300.0 else (15.0 if run_time < 480.0 else 6.0)
	s += 20.0 if deaths == 0 else (12.0 if deaths <= 2 else (5.0 if deaths <= 5 else 0.0))
	var r := "C"
	if s >= 85.0:
		r = "S"
	elif s >= 65.0:
		r = "A"
	elif s >= 45.0:
		r = "B"
	return {"score": int(round(s)), "rank": r}
## Boss HUD: visible, title, health ratio, shielded.
signal boss_hud(show: bool, title: String, ratio: float, shielded: bool)


func set_progress(text: String) -> void:
	progress = text
	progress_changed.emit(text)

const ECHO_CYAN := Color(0.25, 0.95, 1.0)

var checkpoint_pos: Vector3 = Vector3(0, 1.2, 3)
var checkpoint_yaw: float = 0.0
var objective: String = ""
var mouse_sensitivity: float = 0.0025
var won: bool = false
var run_time: float = 0.0
var running: bool = false
## Set by main.gd before a reload: "menu" or "play".
var start_mode: String = "menu"
var shown_prompts: Dictionary = {}
## "quality" or "performance". Auto: performance on integrated GPUs.
var quality: String = "quality"

signal quality_changed(q: String)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	var gpu := RenderingServer.get_video_adapter_name().to_lower()
	var integrated := RenderingServer.get_video_adapter_type() == RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU
	# D3D12 often reports iGPUs as "other": fall back to common iGPU names.
	for hint in ["radeon(tm) graphics", "radeon graphics", "vega", "intel(r) uhd", "intel(r) iris", "intel(r) arc(tm) graphics", "uhd graphics", "iris"]:
		if gpu.contains(hint):
			integrated = true
	if integrated:
		quality = "performance"
	print("ECHO: GPU=%s quality=%s" % [RenderingServer.get_video_adapter_name(), quality])


func set_quality(q: String) -> void:
	quality = q
	quality_changed.emit(q)


func _process(delta: float) -> void:
	if running and not won and not get_tree().paused:
		run_time += delta


func _setup_input() -> void:
	_bind("move_forward", [KEY_W, KEY_UP])
	_bind("move_back", [KEY_S, KEY_DOWN])
	_bind("move_left", [KEY_A, KEY_LEFT])
	_bind("move_right", [KEY_D, KEY_RIGHT])
	_bind("jump", [KEY_SPACE])
	_bind("sprint", [KEY_SHIFT])
	_bind("pulse", [KEY_Q], [MOUSE_BUTTON_RIGHT])
	_bind("interact", [KEY_E])
	_bind("pause", [KEY_ESCAPE])
	_bind("fire", [], [MOUSE_BUTTON_LEFT])
	_bind("record", [KEY_R])
	_bind("command", [KEY_C], [MOUSE_BUTTON_MIDDLE])
	_bind("follow", [KEY_V])
	_bind("dash", [KEY_F, KEY_CTRL])


func _bind(action: StringName, keys: Array, mouse_buttons: Array = []) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k: int in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
	for b: int in mouse_buttons:
		var mb := InputEventMouseButton.new()
		mb.button_index = b
		InputMap.action_add_event(action, mb)


func reset_run() -> void:
	won = false
	run_time = 0.0
	running = false
	shown_prompts.clear()
	progress = ""
	shards = 0
	rings = 0
	deaths = 0
	drones_down = 0
	checkpoint_pos = Vector3(0, 1.2, 3)
	checkpoint_yaw = 0.0


func set_objective(text: String) -> void:
	if text == objective:
		return
	objective = text
	objective_changed.emit(text)


## Shows a prompt. If `once_key` is given, the prompt is only shown once per run.
func prompt(text: String, duration: float = 4.0, once_key: String = "") -> void:
	if once_key != "":
		if shown_prompts.has(once_key):
			return
		shown_prompts[once_key] = true
	prompt_requested.emit(text, duration)


func set_checkpoint(pos: Vector3, yaw: float) -> void:
	if pos.is_equal_approx(checkpoint_pos):
		return
	checkpoint_pos = pos
	checkpoint_yaw = yaw
	checkpoint_reached.emit(pos)


func win() -> void:
	if won:
		return
	won = true
	level_won.emit()


func format_time(t: float) -> String:
	var m := int(t) / 60
	var s := int(t) % 60
	return "%d:%02d" % [m, s]
