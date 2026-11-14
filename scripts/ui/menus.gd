class_name Menus
extends CanvasLayer
## Main menu, pause menu, settings and victory screens.

signal play_pressed
signal play_level(id: int)
signal resume_pressed
signal restart_pressed
signal menu_pressed

var _main: Control
var _pause: Control
var _settings: Control
var _victory: Control
var _victory_time: Label
var _victory_title: Label
var _victory_rank: Label
var _continue: Button
var _settings_back_to: Control


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_main = _build_main()
	_pause = _build_pause()
	_settings = _build_settings()
	_victory = _build_victory()
	for c in [_main, _pause, _settings, _victory]:
		add_child(c)
		c.visible = false


func show_main() -> void:
	_only(_main)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_fade_in(_main)


func show_pause() -> void:
	_only(_pause)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func show_victory(time_text: String) -> void:
	var r := Game.rank()
	_victory_title.text = "SPIRE RESTORED" if Game.level_id == 1 else "THE HEIGHTS SING AGAIN"
	_victory_time.text = "Time  %s     ·     Shards  %d / %d     ·     Rings  %d / %d\nDrones silenced  %d     ·     Falls & defeats  %d" % [
		time_text, Game.shards, Game.shards_total, Game.rings, Game.rings_total, Game.drones_down, Game.deaths]
	_victory_rank.text = "RANK  %s     %d pts" % [r["rank"], r["score"]]
	_continue.visible = Game.level_id == 1
	_only(_victory)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_fade_in(_victory)


func hide_all() -> void:
	_only(null)


func is_open() -> bool:
	return _main.visible or _pause.visible or _settings.visible or _victory.visible


func pause_visible() -> bool:
	return _pause.visible or _settings.visible


func _only(c: Control) -> void:
	for x in [_main, _pause, _settings, _victory]:
		x.visible = x == c


func _fade_in(c: Control) -> void:
	c.modulate.a = 0.0
	create_tween().tween_property(c, "modulate:a", 1.0, 0.6)


func _base(dim: float) -> Control:
	var root := UiKit.full_rect(Control.new())
	var bg := UiKit.full_rect(ColorRect.new()) as ColorRect
	bg.color = Color(0.01, 0.06, 0.1, dim)
	root.add_child(bg)
	return root


func _column(root: Control, pos: Vector2) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.anchor_top = 0.5
	v.anchor_bottom = 0.5
	v.offset_left = pos.x
	v.offset_top = pos.y
	root.add_child(v)
	return v


func _build_main() -> Control:
	var root := _base(0.0)
	# Soft left-side gradient so text reads over the bright scene.
	var grad := TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.01, 0.07, 0.12, 0.75))
	g.set_color(1, Color(0.01, 0.07, 0.12, 0.0))
	gt.gradient = g
	gt.fill_to = Vector2(1, 0)
	grad.texture = gt
	grad.anchor_bottom = 1.0
	grad.offset_right = 900
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(grad)

	var v := _column(root, Vector2(110, -250))
	v.add_child(UiKit.label("ECHO", 120, UiKit.TEXT, UiKit.wide()))
	v.add_child(UiKit.label("THE  LAST  RESONANCE", 26, UiKit.TEXT, UiKit.spaced()))
	var sub := UiKit.label("SOUND  REVEALS  REALITY", 18, UiKit.CYAN, UiKit.spaced())
	v.add_child(sub)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 40
	v.add_child(spacer)
	var play := UiKit.button("▶   LEVEL 1 · THE FIRST RESONANCE")
	play.custom_minimum_size.x = 480
	play.pressed.connect(func() -> void: play_level.emit(1))
	v.add_child(play)
	var play2 := UiKit.button("▶   LEVEL 2 · DISSONANT HEIGHTS")
	play2.custom_minimum_size.x = 480
	play2.pressed.connect(func() -> void: play_level.emit(2))
	v.add_child(play2)
	var settings := UiKit.button("⚙   SETTINGS")
	settings.pressed.connect(func() -> void: _open_settings(_main))
	v.add_child(settings)
	var quit := UiKit.button("✕   QUIT")
	quit.pressed.connect(func() -> void: get_tree().quit())
	quit.visible = not OS.has_feature("web")
	v.add_child(quit)
	var hint := UiKit.label("WASD move  ·  Space jump  ·  Q / RMB  Echo Scan  ·  LMB  Sonic Bolt  ·  F  Dash  ·  R  Record Echo  ·  C  Send Echo  ·  V  Echo Follow  ·  E  Interact", 15, Color(1, 1, 1, 0.85))
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = 110
	hint.offset_top = -70
	root.add_child(hint)
	return root


func _build_pause() -> Control:
	var root := _base(0.55)
	var v := _column(root, Vector2(110, -170))
	v.add_child(UiKit.label("PAUSED", 56, UiKit.TEXT, UiKit.wide()))
	var resume := UiKit.button("▶   RESUME")
	resume.pressed.connect(func() -> void: resume_pressed.emit())
	v.add_child(resume)
	var restart := UiKit.button("↺   RESTART FROM CHECKPOINT")
	restart.pressed.connect(func() -> void: restart_pressed.emit())
	v.add_child(restart)
	var settings := UiKit.button("⚙   SETTINGS")
	settings.pressed.connect(func() -> void: _open_settings(_pause))
	v.add_child(settings)
	var menu := UiKit.button("⌂   MAIN MENU")
	menu.pressed.connect(func() -> void: menu_pressed.emit())
	v.add_child(menu)
	return root


func _build_settings() -> Control:
	var root := _base(0.6)
	var v := _column(root, Vector2(110, -150))
	v.add_child(UiKit.label("SETTINGS", 56, UiKit.TEXT, UiKit.wide()))
	v.add_child(UiKit.label("MOUSE SENSITIVITY", 16, UiKit.CYAN, UiKit.spaced()))
	var s := HSlider.new()
	s.min_value = 0.0005
	s.max_value = 0.006
	s.step = 0.0001
	s.value = Game.mouse_sensitivity
	s.custom_minimum_size = Vector2(320, 30)
	s.value_changed.connect(func(val: float) -> void: Game.mouse_sensitivity = val)
	v.add_child(s)
	var fs := CheckButton.new()
	fs.text = "Fullscreen"
	fs.add_theme_font_override("font", UiKit.spaced())
	fs.add_theme_font_size_override("font_size", 18)
	fs.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fs.toggled.connect(func(on: bool) -> void:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED))
	v.add_child(fs)
	var hq := CheckButton.new()
	hq.text = "High quality graphics (SSAO, full resolution)"
	hq.add_theme_font_override("font", UiKit.spaced())
	hq.add_theme_font_size_override("font_size", 18)
	hq.button_pressed = Game.quality == "quality"
	hq.toggled.connect(func(on: bool) -> void: Game.set_quality("quality" if on else "performance"))
	v.add_child(hq)
	var back := UiKit.button("←   BACK")
	back.pressed.connect(func() -> void:
		_only(_settings_back_to))
	v.add_child(back)
	return root


func _open_settings(from: Control) -> void:
	_settings_back_to = from
	_only(_settings)


func _build_victory() -> Control:
	var root := _base(0.0)
	var grad := TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.01, 0.06, 0.11, 0.88))
	g.set_color(1, Color(0.01, 0.06, 0.11, 0.0))
	gt.gradient = g
	gt.fill_to = Vector2(1, 0)
	grad.texture = gt
	grad.anchor_bottom = 1.0
	grad.offset_right = 1250
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(grad)
	var v := _column(root, Vector2(110, -240))
	_victory_title = UiKit.label("SPIRE RESTORED", 64, UiKit.TEXT, UiKit.wide())
	v.add_child(_victory_title)
	v.add_child(UiKit.label("The ancient network hums back to life.", 24, UiKit.CYAN))
	_victory_time = UiKit.label("", 19, Color(1, 1, 1, 0.9), UiKit.spaced())
	v.add_child(_victory_time)
	_victory_rank = UiKit.label("", 40, Color(1.0, 0.85, 0.4), UiKit.wide())
	v.add_child(_victory_rank)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 16
	v.add_child(spacer)
	_continue = UiKit.button("▶   CONTINUE · LEVEL 2")
	_continue.pressed.connect(func() -> void: play_level.emit(2))
	v.add_child(_continue)
	var again := UiKit.button("↺   PLAY AGAIN")
	again.pressed.connect(func() -> void: play_level.emit(Game.level_id))
	v.add_child(again)
	var menu := UiKit.button("⌂   MAIN MENU")
	menu.pressed.connect(func() -> void: menu_pressed.emit())
	v.add_child(menu)
	return root
