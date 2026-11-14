class_name Hud
extends CanvasLayer
## In-game HUD modeled on the ECHO concept: objective (TL), crosshair,
## segmented Sound Energy bar (BL), contextual prompts, pause hint (TR).

var emitter: EchoEmitter
var _objective_label: Label
var _objective_panel: PanelContainer
var _prompt_label: Label
var _prompt_panel: PanelContainer
var _prompt_tween: Tween
var _energy: EnergyBar
var _flash: ColorRect


func _ready() -> void:
	layer = 5
	var root := UiKit.full_rect(Control.new())
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# --- Top-left: logo + objective ---
	var tl := VBoxContainer.new()
	tl.position = Vector2(36, 26)
	tl.add_theme_constant_override("separation", 10)
	root.add_child(tl)
	var logo := UiKit.label("ECHO", 34, UiKit.TEXT, UiKit.wide())
	tl.add_child(logo)
	_objective_panel = PanelContainer.new()
	_objective_panel.add_theme_stylebox_override("panel", UiKit.panel_style())
	tl.add_child(_objective_panel)
	var ov := VBoxContainer.new()
	ov.add_theme_constant_override("separation", 2)
	_objective_panel.add_child(ov)
	ov.add_child(UiKit.label("◆  OBJECTIVE", 13, UiKit.CYAN, UiKit.spaced()))
	_objective_label = UiKit.label(Game.objective, 22)
	ov.add_child(_objective_label)

	# --- Top-right: pause hint ---
	var tr := UiKit.label("ESC  ‖  PAUSE", 14, Color(1, 1, 1, 0.75), UiKit.spaced())
	tr.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(tr, Vector2(1, 0), Rect2(-260, 34, 224, 30))
	root.add_child(tr)

	# --- Center: crosshair ---
	var ch := Crosshair.new()
	ch.set_anchors_preset(Control.PRESET_CENTER)
	root.add_child(ch)

	# --- Bottom-left: sound energy ---
	_energy = EnergyBar.new()
	_place(_energy, Vector2(0, 1), Rect2(30, -126, 460, 100))
	root.add_child(_energy)

	# --- Bottom-center: prompt ---
	var pc := CenterContainer.new()
	pc.anchor_left = 0.0
	pc.anchor_right = 1.0
	pc.anchor_top = 1.0
	pc.anchor_bottom = 1.0
	pc.offset_top = -250
	pc.offset_bottom = -180
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pc)
	_prompt_panel = PanelContainer.new()
	_prompt_panel.add_theme_stylebox_override("panel", UiKit.panel_style(0.9))
	_prompt_panel.modulate.a = 0.0
	pc.add_child(_prompt_panel)
	_prompt_label = UiKit.label("", 21)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_panel.add_child(_prompt_label)

	_flash = UiKit.full_rect(ColorRect.new()) as ColorRect
	_flash.color = Color(0.8, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_flash)

	Game.objective_changed.connect(_on_objective)
	Game.prompt_requested.connect(_on_prompt)
	Game.player_respawned.connect(func() -> void: flash(Color(0.02, 0.1, 0.15), 0.6))
	Game.checkpoint_reached.connect(func(_p: Vector3) -> void: _energy.pulse_glow())


func _process(_d: float) -> void:
	if emitter:
		_energy.charge = emitter.charge


func _on_objective(text: String) -> void:
	_objective_label.text = text
	var tw := create_tween()
	_objective_panel.modulate = Color(2.2, 2.2, 2.2)
	tw.tween_property(_objective_panel, "modulate", Color.WHITE, 0.6)


func _on_prompt(text: String, duration: float) -> void:
	_prompt_label.text = text
	if _prompt_tween:
		_prompt_tween.kill()
	_prompt_tween = create_tween()
	_prompt_tween.tween_property(_prompt_panel, "modulate:a", 1.0, 0.25)
	_prompt_tween.tween_interval(duration)
	_prompt_tween.tween_property(_prompt_panel, "modulate:a", 0.0, 0.5)


## Anchors `c` at `anchor` (0..1 per axis) with a rect offset from that anchor.
static func _place(c: Control, anchor: Vector2, r: Rect2) -> void:
	c.anchor_left = anchor.x
	c.anchor_right = anchor.x
	c.anchor_top = anchor.y
	c.anchor_bottom = anchor.y
	c.offset_left = r.position.x
	c.offset_top = r.position.y
	c.offset_right = r.position.x + r.size.x
	c.offset_bottom = r.position.y + r.size.y


func flash(color: Color, time: float) -> void:
	_flash.color = Color(color.r, color.g, color.b, 1.0)
	create_tween().tween_property(_flash, "color:a", 0.0, time)


class Crosshair extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := Color(1, 1, 1, 0.85)
		for i in 4:
			var a := i * PI * 0.5 + PI * 0.25
			draw_arc(Vector2.ZERO, 11.0, a - 0.45, a + 0.45, 8, c, 1.6, true)
		draw_circle(Vector2.ZERO, 1.8, c)


class EnergyBar extends Control:
	var charge := 1.0
	var _glow := 0.0
	const SEGMENTS := 10

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := UiKit.label("SOUND  ENERGY", 15, UiKit.TEXT, UiKit.spaced())
		l.position = Vector2(104, 14)
		add_child(l)

	func pulse_glow() -> void:
		_glow = 1.0

	func _process(delta: float) -> void:
		_glow = maxf(_glow - delta, 0.0)
		queue_redraw()

	func _draw() -> void:
		var cy := UiKit.CYAN
		var center := Vector2(48, 50)
		# Waveform badge.
		draw_circle(center, 38, Color(0.02, 0.1, 0.16, 0.65))
		draw_arc(center, 38, 0, TAU, 48, Color(cy.r, cy.g, cy.b, 0.8), 2.0, true)
		var pts := PackedVector2Array()
		var t := Time.get_ticks_msec() * 0.006
		for i in 25:
			var x := -24.0 + i * 2.0
			var env := 1.0 - absf(x) / 24.0
			var amp := 14.0 * env * (0.35 + 0.65 * charge)
			pts.append(center + Vector2(x, sin(x * 0.55 + t) * amp * sin(i * 1.7 + t * 0.5)))
		draw_polyline(pts, cy, 2.0, true)
		# Segmented, slanted bar.
		var origin := Vector2(100, 46)
		var w := 30.0
		var h := 20.0
		var filled := charge * SEGMENTS
		var bg := Color(0.02, 0.1, 0.16, 0.7)
		for i in SEGMENTS:
			var x := origin.x + i * (w + 4.0)
			var poly := PackedVector2Array([
				Vector2(x + 6, origin.y), Vector2(x + w + 6, origin.y),
				Vector2(x + w, origin.y + h), Vector2(x, origin.y + h)])
			draw_colored_polygon(poly, bg)
			var f := clampf(filled - i, 0.0, 1.0)
			if f > 0.0:
				var bright := 1.0 + _glow * 1.5 + (0.6 if charge >= 1.0 else 0.0)
				var col := Color(cy.r * bright, cy.g * bright, cy.b * bright, 0.35 + 0.65 * f)
				draw_colored_polygon(poly, col)
		draw_polyline(PackedVector2Array([origin + Vector2(-4, h + 8), origin + Vector2(SEGMENTS * (w + 4) + 6, h + 8)]), Color(cy.r, cy.g, cy.b, 0.4), 1.0)
