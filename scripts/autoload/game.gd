extends Node
## Global game state: input map, objectives, prompts, checkpoints, settings.

signal objective_changed(text: String)
signal prompt_requested(text: String, duration: float)
signal checkpoint_reached(pos: Vector3)
signal level_won
signal player_respawned

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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()


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
