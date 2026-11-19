# 画面の共通部品(色・字体・ラベル・ボタン・置き場所)。画面設計書 §8 の色はここに置く。
# 文言は持たない。各画面は文言を core/strings.gd から渡す。作りは KeySwat・RootCall の ui/kit.gd。
extends RefCounted

const SANS := "res://assets/fonts/NotoSansJP-Subset.ttf"

const C_BG := Color("0B0E14")
const C_OUT := Color("07090D")
const C_KEY := Color("1E2530")
const C_KEY_EDGE := Color("8B95A5")
const C_KEY_TEXT := Color("C9D1D9")
const C_SHIP := Color("6BB8FF")
const C_SHOT := Color("BFE3FF")
const C_SMALL := Color("FF8A8A")
const C_FAN := Color("FFB84D")
const C_PILLAR := Color("C792EA")
const C_WALLER := Color("7FDBCA")
const C_BULLET := Color("FF4D6D")
const C_LASER := Color("E0B8FF")
const C_WARN := Color("FFB84D")
const C_WHITE := Color("FFFFFF")
const C_TEXT := Color("E6E6E6")
const C_DIM := Color("8B95A5")
const C_GOOD := Color("7EE787")
const C_PANEL := Color("161B22")
const C_EDGE := Color("3A4250")
const C_SEL := Color("6BB8FF")
const ENEMY_COLORS := [C_SMALL, C_FAN, C_PILLAR, C_WALLER]

static var _fonts := {}


static func font(weight: int = 400) -> Font:
	if not _fonts.has(weight):
		var fv := FontVariation.new()
		fv.base_font = load(SANS)
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		_fonts[weight] = fv
	return _fonts[weight]


static func label(text: String, size: int, color: Color = C_TEXT, weight: int = 400) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func box(bg: Color, border: Color, width: int, radius: int = 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 20
	s.content_margin_right = 20
	s.anti_aliasing = true
	return s


# ボタン。node_name は自動の確認が押す時の目印。キーボードでの選択は ui/menu.gd が見た目を変える。
static func button(node_name: String, text: String, size: int = 28) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.focus_mode = Control.FOCUS_NONE  # Tab・矢印を Godot のフォーカスの移動に使わせない
	b.add_theme_font_override("font", font(700))
	b.add_theme_font_size_override("font_size", size)
	set_selected(b, false)
	b.add_theme_stylebox_override("pressed", box(Color(C_SEL, 0.3), C_SEL, 3))
	b.add_theme_stylebox_override("disabled", box(Color(1, 1, 1, 0.02), Color(C_DIM, 0.3), 2))
	for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, C_TEXT)
	b.add_theme_color_override("font_disabled_color", Color(C_DIM, 0.5))
	return b


static func set_selected(b: Button, on: bool) -> void:
	var edge := C_SEL if on else Color(C_TEXT, 0.55)
	var fill := Color(C_SEL, 0.16) if on else Color(1, 1, 1, 0.04)
	b.add_theme_stylebox_override("normal", box(fill, edge, 3 if on else 2))
	b.add_theme_stylebox_override("hover", box(Color(C_SEL, 0.12), C_SEL, 3))


static func place(c: Control, x: float, y: float, w: float, h: float) -> Control:
	c.position = Vector2(x, y)
	c.size = Vector2(w, h)
	if c is Button:
		c.custom_minimum_size = Vector2(w, h)
	return c
