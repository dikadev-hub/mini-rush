# scripts/ui/ui_theme.gd
# Helper Theme global Mini Rush. Owner: A8. Kontrak README 5.7.
# Palet: 1 primer, 1 aksen, 1 netral gelap; tanpa neon. Font Nunito (OFL).
class_name UITheme
extends RefCounted

const FONT_PATH: String = "res://assets/ui/nunito.ttf"
const BASE_FONT_SIZE: int = 28
const CORNER_RADIUS: int = 18
const SHADOW_SIZE: int = 6

# Palet: primer teal gelap, aksen oranye hangat, netral abu gelap.
const COLOR_PRIMARY: Color = Color(0.145, 0.431, 0.529)
const COLOR_ACCENT: Color = Color(0.941, 0.529, 0.2)
const COLOR_DARK: Color = Color(0.117, 0.157, 0.184)
const COLOR_TEXT: Color = Color(0.95, 0.96, 0.97)
const COLOR_TEXT_DIM: Color = Color(0.7, 0.74, 0.78)


## Bangun Theme global (dipakai semua scene UI).
static func build() -> Theme:
	var theme := Theme.new()
	if ResourceLoader.exists(FONT_PATH):
		var font: Font = load(FONT_PATH) as Font
		if font != null:
			theme.default_font = font
	theme.default_font_size = BASE_FONT_SIZE

	theme.set_color("font_color", "Label", COLOR_TEXT)
	theme.set_color("font_color", "Button", COLOR_TEXT)
	theme.set_color("font_color", "LineEdit", COLOR_TEXT)

	# Button normal / hover / pressed.
	theme.set_stylebox("normal", "Button", _button_style(COLOR_PRIMARY))
	theme.set_stylebox("hover", "Button", _button_style(COLOR_PRIMARY.lightened(0.08)))
	theme.set_stylebox("pressed", "Button", _button_style(COLOR_DARK))
	theme.set_stylebox("disabled", "Button", _button_style(Color(0.3, 0.34, 0.38)))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())

	# Panel umum.
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(COLOR_DARK.r, COLOR_DARK.g, COLOR_DARK.b, 0.94)
	panel.set_corner_radius_all(CORNER_RADIUS)
	panel.set_content_margin_all(16)
	panel.shadow_size = SHADOW_SIZE
	panel.shadow_color = Color(0, 0, 0, 0.25)
	theme.set_stylebox("panel", "PanelContainer", panel)

	# LineEdit.
	var le := StyleBoxFlat.new()
	le.bg_color = Color(COLOR_DARK.r + 0.04, COLOR_DARK.g + 0.04, COLOR_DARK.b + 0.04)
	le.set_corner_radius_all(CORNER_RADIUS)
	le.set_content_margin_all(10)
	theme.set_stylebox("normal", "LineEdit", le)

	# Slider.
	theme.set_constant("grabber_offset", "HSlider", 0)
	return theme


static func _button_style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(CORNER_RADIUS)
	sb.set_content_margin_all(12)
	sb.shadow_size = SHADOW_SIZE
	sb.shadow_color = Color(0, 0, 0, 0.2)
	sb.shadow_offset = Vector2(0, 2)
	return sb


## Tombol dengan gaya aksen (untuk aksi utama seperti Play).
static func accent_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	var accent := _button_style(COLOR_ACCENT)
	accent.set_corner_radius_all(CORNER_RADIUS)
	b.add_theme_stylebox_override("normal", accent)
	var hover := _button_style(COLOR_ACCENT.lightened(0.08))
	b.add_theme_stylebox_override("hover", hover)
	return b


## Label dengan ukuran besar (judul / countdown).
static func big_label(text: String, font_size: int = 64) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	return l


## Format waktu ms -> "m:ss.mmm".
static func format_time_ms(time_ms: int) -> String:
	if time_ms < 0:
		return "-"
	var minutes: int = time_ms / 60000
	var seconds: int = (time_ms % 60000) / 1000
	var millis: int = time_ms % 1000
	return "%d:%02d.%03d" % [minutes, seconds, millis]
