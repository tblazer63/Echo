class_name EchoCloneRecorder
extends Node
## Records the player's movement for up to MAX_TIME seconds (R to start/stop)
## and replays it as a holographic EchoClone that holds its final pose.

signal recording_started
signal recording_progress(t: float, max_t: float)
signal recording_stopped
signal clone_spawned(clone: EchoClone)

const MAX_TIME := 5.0
const MIN_FRAMES := 6

var player: Player
var recording := false
var rec_time := 0.0
var frames: Array[Dictionary] = []
var current_clone: EchoClone

var is_recording: bool:
	get:
		return recording


func _ready() -> void:
	if not Game.player_respawned.is_connected(_on_player_respawned):
		Game.player_respawned.connect(_on_player_respawned)


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	if player.input_enabled and InputMap.has_action("record") and Input.is_action_just_pressed("record"):
		if recording:
			stop()
		else:
			start()
	if not recording:
		return
	frames.append({
		"pos": player.global_position,
		"yaw": player.rotation.y,
		"pitch": player.head.rotation.x if player.head else 0.0,
	})
	rec_time += delta
	recording_progress.emit(minf(rec_time, MAX_TIME), MAX_TIME)
	if rec_time >= MAX_TIME:
		stop()


func start() -> void:
	clear_clone()
	frames.clear()
	recording = true
	rec_time = 0.0
	Sfx.play("clone_rec", -3.0)
	recording_started.emit()
	Game.prompt("Recording echo... (R to stop)", 2.0)


func stop() -> void:
	if not recording:
		return
	recording = false
	recording_stopped.emit()
	if frames.size() < MIN_FRAMES:
		return
	var host: Node = get_tree().current_scene
	if host == null:
		host = player.get_parent() if is_instance_valid(player) else null
	if host == null:
		return
	var clone := EchoClone.new()
	host.add_child(clone)
	clone.play(frames.duplicate())
	current_clone = clone
	Sfx.play("clone_play", -3.0)
	clone_spawned.emit(clone)


## Public wrappers (QA / scripted use).
func start_recording() -> void:
	start()


func stop_recording() -> void:
	stop()


func clear_clone() -> void:
	if is_instance_valid(current_clone):
		current_clone.dismiss()
	current_clone = null


## A respawn mid-recording would teleport the clone; discard that take.
func _on_player_respawned() -> void:
	if recording:
		recording = false
		frames.clear()
		rec_time = 0.0
		recording_stopped.emit()
