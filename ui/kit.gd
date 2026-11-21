# 画面の共通部品(色・字体・ラベル・ボタン・置き場所・ネオンの線)。画面設計書 §8・§10 の色はここに置く。
# 見た目の既定は ui/theme.tres(tools/make_theme.gd が作る。project の gui/theme/custom で全部の Control に付く)。
# 文言は持たない。各画面は文言を core/strings.gd から渡す。作りは KeySwat・RootCall の ui/kit.gd。
extends RefCounted

const SANS := "res://assets/fonts/NotoSansJP-Subset.ttf"
const DISPLAY := "res://assets/fonts/TiltNeon-Subset.ttf"  # 題字・数字(ネオン管の字。ASCII だけ。日本語は Noto へ落とす)

# 遊ぶ場所の意味の色(仕様の色。危ない物の見分けを落とさないよう、UI の飾りには使わない)
const C_SHIP := Color("6BB8FF")
const C_SHOT := Color("BFE3FF")
const C_SMALL := Color("FF8A8A")
const C_FAN := Color("FFB84D")
const C_PILLAR := Color("C792EA")
const C_WALLER := Color("7FDBCA")
const C_BULLET := Color("FF4D6D")
const C_LASER := Color("E0B8FF")
const C_WARN := Color("FFB84D")
const C_GOOD := Color("7EE787")
const C_WHITE := Color("FFFFFF")
const ENEMY_COLORS := [C_SMALL, C_FAN, C_PILLAR, C_WALLER]

# ネオンの夜の板(v0.3.0)。藍の夜・1 段暗い外・板・罫・水色の管・桃の管・字
const C_BG := Color("0D0B1E")
const C_OUT := Color("070614")
const C_PANEL := Color("18153A")
const C_RULE := Color("2E2A55")
const C_CYAN := Color("5CF2FF")
const C_PINK := Color("FF5FC4")
const C_TEXT := Color("EEEBFF")
const C_DIM := Color("A29DCB")
const C_KEY := Color("1C1940")
const C_KEY_EDGE := Color("9A96C4")  # キーの枠(前の #8B95A5 を夜の藍に寄せた)
const C_KEY_TEXT := Color("D9D5F5")
const C_EDGE := C_RULE
const C_SEL := C_CYAN

const RADIUS := 12  # ボタン・板の角の丸み(ネオン管の曲がり)

static var _fonts := {}
static var _num: Font = null


static func font(weight: int = 400) -> Font:
	if not _fonts.has(weight):
		var fv := FontVariation.new()
		fv.base_font = load(SANS)
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		_fonts[weight] = fv
	return _fonts[weight]


# 題字と数字の字体(Tilt Neon)。ASCII に無い字(点・波 など)は Noto Sans JP の 700 で描く。
static func num_font() -> Font:
	if _num == null:
		var fv := FontVariation.new()
		fv.base_font = load(DISPLAY)
		fv.fallbacks = [font(700)]
		_num = fv
	return _num


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


static func box(bg: Color, border: Color, width: int, radius: int = RADIUS) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.corner_detail = 6
	s.content_margin_left = 20
	s.content_margin_right = 20
	s.anti_aliasing = true
	return s


# ボタン。見た目(5 つの状態)は theme.tres。node_name は自動の確認が押す時の目印。
# キーボードの選択は ui/menu.gd が set_selected で型の変種(SelButton)に替える。
static func button(node_name: String, text: String, size: int = 28) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.focus_mode = Control.FOCUS_NONE  # Tab・矢印を Godot のフォーカスの移動に使わせない(選択は menu が持つ)
	b.add_theme_font_size_override("font_size", size)
	return b


static func set_selected(b: Button, on: bool) -> void:
	b.theme_type_variation = &"SelButton" if on else &""
	b.queue_redraw()


static func place(c: Control, x: float, y: float, w: float, h: float) -> Control:
	c.position = Vector2(x, y)
	c.size = Vector2(w, h)
	if c is Button:
		c.custom_minimum_size = Vector2(w, h)
	return c


# ネオン管の線: 太く薄い光を 2 重に敷いてから、細く明るい芯を引く。glow 0 なら芯だけ。
static func neon_line(ci: CanvasItem, pts: PackedVector2Array, color: Color, width: float = 2.0, glow: float = 1.0) -> void:
	if glow > 0.0:
		ci.draw_polyline(pts, Color(color, color.a * 0.10 * glow), width + 10.0, true)
		ci.draw_polyline(pts, Color(color, color.a * 0.22 * glow), width + 4.0, true)
	ci.draw_polyline(pts, color, width, true)
	ci.draw_polyline(pts, Color(C_WHITE, 0.35 * color.a), maxf(width * 0.35, 1.0), true)


# 角の丸い四角の線(ネオン管で囲った枠)。
static func neon_rect(ci: CanvasItem, r: Rect2, color: Color, width: float = 2.0, glow: float = 1.0, rad: float = RADIUS) -> void:
	var pts := round_rect_points(r, rad)
	pts.append(pts[0])
	neon_line(ci, pts, color, width, glow)


# 角の丸い四角の輪郭の点(閉じていない。線にする時は最初の点を足す)。
static func round_rect_points(r: Rect2, p_rad: float) -> PackedVector2Array:
	var rad := minf(p_rad, minf(r.size.x, r.size.y) / 2.0 - 0.5)  # 半分ちょうどだと点が重なり、塗りの三角分けが失敗する
	var pts := PackedVector2Array()
	var corners := [[r.position + Vector2(rad, rad), PI], [Vector2(r.end.x - rad, r.position.y + rad), PI * 1.5],
		[r.end - Vector2(rad, rad), 0.0], [Vector2(r.position.x + rad, r.end.y - rad), PI * 0.5]]
	for c: Array in corners:
		for k in 5:
			var a: float = c[1] + PI * 0.5 * k / 4.0
			pts.append(c[0] + Vector2(cos(a), sin(a)) * rad)
	return pts


# ネオン管の字: 外へにじむ光(輪郭を太く薄く 2 重)の上に字を置く。
static func neon_text(ci: CanvasItem, f: Font, at: Vector2, text: String, size: int, color: Color, glow: float = 1.0,
		align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1) -> void:
	if glow > 0.0:
		ci.draw_string_outline(f, at, text, align, width, size, maxi(int(size / 5.0), 6), Color(color, color.a * 0.10 * glow))
		ci.draw_string_outline(f, at, text, align, width, size, maxi(int(size / 12.0), 3), Color(color, color.a * 0.25 * glow))
	ci.draw_string(f, at, text, align, width, size, color)


# 数字を 1 字ずつ同じ幅の升に置いて描く(数字が変わっても横に揺れない)。x は align に合わせた基準(左・中・右)。描いた幅を返す。
static func draw_digits(ci: CanvasItem, f: Font, x: float, baseline: float, text: String, size: int, color: Color,
		align: int = HORIZONTAL_ALIGNMENT_LEFT, glow: float = 0.0) -> float:
	var total := digits_width(f, text, size)
	var cell := f.get_char_size("0".unicode_at(0), size).x
	var px := x - (total / 2.0 if align == HORIZONTAL_ALIGNMENT_CENTER else total if align == HORIZONTAL_ALIGNMENT_RIGHT else 0.0)
	for c in text:
		var cw := f.get_string_size(c, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var w := cell if _is_digit(c) else cw
		neon_text(ci, f, Vector2(px + (w - cw) / 2.0, baseline), c, size, color, glow)
		px += w
	return total


static func digits_width(f: Font, text: String, size: int) -> float:
	var cell := f.get_char_size("0".unicode_at(0), size).x
	var total := 0.0
	for c in text:
		total += cell if _is_digit(c) else f.get_string_size(c, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	return total


static func _is_digit(c: String) -> bool:
	return c >= "0" and c <= "9"


# 自機の形(上向きの三角、幅 w)。選んだボタンの印やタイトルの題字でも使う。
static func ship(ci: CanvasItem, c: Vector2, w: float, col: Color) -> void:
	var h := w * 0.9
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -h * 0.66), c + Vector2(w / 2.0, h * 0.34), c + Vector2(-w / 2.0, h * 0.34)]), col)


# 0→1 を減速で(入りの動き)。
static func ease_out(k: float) -> float:
	var t := clampf(k, 0.0, 1.0)
	return 1.0 - (1.0 - t) * (1.0 - t) * (1.0 - t)


# 0→1→0 の三角の波(period ms で 1 往復)。濃淡の息に使う(明滅でなく、なめらかに行き来する)。
static func tri(now: int, period: int) -> float:
	var k := fmod(float(now), float(period)) / float(period)
	return 1.0 - absf(k * 2.0 - 1.0)


# 相対輝度のコントラスト比(WCAG 2)。色の板のテストが使う。
static func contrast(a: Color, b: Color) -> float:
	var la := a.srgb_to_linear().get_luminance()
	var lb := b.srgb_to_linear().get_luminance()
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)
