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
const CMD_RANGE := 45.0

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
	if player.input_enabled and not recording:
		if InputMap.has_action("command") and Input.is_action_just_pressed("command"):
			_aim_command()
		elif InputMap.has_action("follow") and Input.is_action_just_pressed("follow"):
			command_follow()
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
	clone.blocked.connect(_on_clone_blocked)
	current_clone = clone
	Sfx.play("clone_play", -3.0)
	clone_spawned.emit(clone)


## C: send the echo to the ground point under the crosshair.
func _aim_command() -> void:
	var cam := player.camera
	if cam == null:
		return
	var from := cam.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from - cam.global_basis.z * CMD_RANGE, 1)
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or (hit["normal"] as Vector3).y < 0.5:
		Game.prompt("Aim at the ground to send your echo there", 2.0)
		return
	command_move(hit["position"])


## Command the echo (spawning one beside the player if needed) to walk to `target` and hold.
func command_move(target: Vector3) -> void:
	var c := _ensure_clone()
	if c == null:
		return
	c.move_to(target)
	_marker(target)
	Sfx.play("tick", -4.0)
	Game.prompt("Echo: moving there and holding", 1.5)


## V: the echo follows you (and rejoins you if it gets stuck or left behind).
func command_follow() -> void:
	var c := _ensure_clone()
	if c == null:
		return
	c.follow(player)
	Sfx.play("tick", -4.0)
	Game.prompt("Echo: following you", 1.5)


func _ensure_clone() -> EchoClone:
	if is_instance_valid(current_clone) and not current_clone.is_dismissing():
		return current_clone
	if player == null or not is_instance_valid(player):
		return null
	var host: Node = get_tree().current_scene
	if host == null:
		host = player.get_parent()
	var clone := EchoClone.new()
	host.add_child(clone)
	clone.global_position = player.global_position
	clone.rotation.y = player.rotation.y
	clone.mode = EchoClone.Mode.MOVE
	clone.holding = true
	clone.blocked.connect(_on_clone_blocked)
	current_clone = clone
	Sfx.play("clone_play", -3.0)
	clone_spawned.emit(clone)
	return clone


func _on_clone_blocked() -> void:
	Game.prompt("Your echo can't reach there (gap or wall). It waits here. Send it closer, or press V.", 3.0, "clone_blocked")


func _marker(at: Vector3) -> void:
	var host: Node = get_tree().current_scene
	if host == null:
		return
	var m := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.5
	tor.outer_radius = 0.62
	tor.rings = 24
	tor.ring_segments = 6
	m.mesh = tor
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(Game.ECHO_CYAN, 0.9)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(m)
	m.global_position = at + Vector3.UP * 0.08
	m.scale = Vector3(1.6, 0.3, 1.6)
	var tw := m.create_tween().set_parallel(true)
	tw.tween_property(m, "scale", Vector3(0.8, 0.3, 0.8), 1.6)
	tw.tween_property(mat, "albedo_color:a", 0.0, 1.6)
	tw.chain().tween_callback(m.queue_free)


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
