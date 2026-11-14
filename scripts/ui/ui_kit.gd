class_name UiKit
extends RefCounted
## Shared fonts/styles for a consistent ECHO look.

const CYAN := Color(0.30, 0.95, 1.0)
const PANEL_BG := Color(0.02, 0.10, 0.16, 0.62)
const TEXT := Color(0.92, 0.98, 1.0)
const DARK_TEXT := Color(0.02, 0.12, 0.18)

static var _font: SystemFont
static var _spaced: FontVariation
static var _wide: FontVariation


static func font() -> Font:
	if _font == null:
		_font = SystemFont.new()
		_font.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "Arial"])
	return _font


static func spaced() -> Font:
	if _spaced == null:
		_spaced = FontVariation.new()
		_spaced.base_font = font()
		_spaced.spacing_glyph = 4
	return _spaced


static func wide() -> Font:
	if _wide == null:
		_wide = FontVariation.new()
		_wide.base_font = font()
		_wide.spacing_glyph = 18
	return _wide


static func label(text: String, size: int, color: Color = TEXT, f: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", f if f else font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0.08, 0.12, 0.55))
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func panel_style(alpha: float = 1.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(PANEL_BG.r, PANEL_BG.g, PANEL_BG.b, PANEL_BG.a * alpha)
	s.border_color = Color(CYAN.r, CYAN.g, CYAN.b, 0.55)
	s.set_border_width_all(1)
	s.border_width_left = 3
	s.set_corner_radius_all(4)
	s.corner_radius_top_left = 14
	s.corner_radius_bottom_right = 14
	s.content_margin_left = 18
	s.content_margin_right = 22
	s.content_margin_top = 10
	s.content_margin_bottom = 12
	return s


static func button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 54)
	b.add_theme_font_override("font", spaced())
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", TEXT)
	for k in ["font_hover_color", "font_focus_color", "font_pressed_color"]:
		b.add_theme_color_override(k, DARK_TEXT)
	var normal := panel_style()
	normal.content_margin_left = 26
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(CYAN.r, CYAN.g, CYAN.b, 0.92)
	hover.border_color = Color(1, 1, 1, 0.9)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.mouse_entered.connect(func() -> void: Sfx.play("ui", -10.0))
	b.pressed.connect(func() -> void: Sfx.play("ui", -4.0, 1.3))
	return b


static func full_rect(c: Control) -> Control:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	return c
