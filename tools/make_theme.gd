# ui/theme.tres を作る(v0.3.0 のネオンの夜の見た目。project の gui/theme/custom で全部の Control に付く)。色を変えたら回し直してコミットする。
#     python tools/gd.py run res://tools/make_theme.gd
# ボタンは normal / hover / focus / pressed / disabled と、キーボードで選んだ時の型の変種 SelButton(水色の管が灯り、外へ光がにじむ)。
# 入力欄・メニュー・ツールチップ・スクロールバー・つまみ・チェックも作る。絵は ImageTexture(圧縮の形は Web で texture is null になる。KeySwat で分かった)。
extends SceneTree

const Kit := preload("res://ui/kit.gd")
const OUT := "res://ui/theme.tres"


func _initialize() -> void:
	var t := build()
	var err := ResourceSaver.save(t, OUT)
	print("theme: %s -> %s" % [OUT, error_string(err)])
	quit(0 if err == OK else 1)


static func _sb(bg: Color, edge: Color, w: int, radius: int = Kit.RADIUS) -> StyleBoxFlat:
	var s := Kit.box(bg, edge, w, radius)
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


static func _glow(s: StyleBoxFlat, a: float) -> StyleBoxFlat:
	s.shadow_color = Color(Kit.C_CYAN, a)
	s.shadow_size = 12
	return s


# 丸い小さな絵(チェックとつまみ用)。inner が透明でなければ内側を塗る。
static func _icon(size: int, fill: Color, edge: Color, inner: Color = Color(0, 0, 0, 0)) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) / 2.0
	for y in size:
		for x in size:
			var d := Vector2(x - c, y - c).length()
			if d > c + 0.5:
				continue
			var col := edge if d > c - 2.0 else fill
			if inner.a > 0.0 and d < c - 4.0:
				col = inner
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


static func build() -> Theme:
	var t := Theme.new()
	t.default_font = Kit.font(500)
	t.default_font_size = 22
	var ink := Kit.C_BG
	var panel := Kit.C_PANEL
	var cyan := Kit.C_CYAN

	# ボタン: 細い管で囲った角の丸い札。選ぶと水色の管が灯る
	t.set_font("font", "Button", Kit.font(700))
	t.set_font_size("font_size", "Button", 26)
	t.set_stylebox("normal", "Button", _sb(Color(panel, 0.9), Kit.C_RULE.lightened(0.18), 2))
	t.set_stylebox("hover", "Button", _sb(panel.lerp(cyan, 0.08), Color(cyan, 0.6), 2))
	t.set_stylebox("focus", "Button", _glow(_sb(Color(0, 0, 0, 0), cyan, 2), 0.3))
	t.set_stylebox("pressed", "Button", _glow(_sb(cyan, cyan, 2), 0.45))
	t.set_stylebox("disabled", "Button", _sb(ink, Color(Kit.C_RULE, 0.8), 2))
	for c: String in ["font_color", "font_hover_color", "font_focus_color"]:
		t.set_color(c, "Button", Kit.C_TEXT)
	t.set_color("font_pressed_color", "Button", ink)
	t.set_color("font_hover_pressed_color", "Button", ink)
	t.set_color("font_disabled_color", "Button", Color(Kit.C_DIM, 0.6))
	t.set_constant("outline_size", "Button", 0)
	t.set_type_variation("SelButton", "Button")
	var sel := _glow(_sb(panel.lerp(cyan, 0.16), cyan, 2), 0.32)
	t.set_stylebox("normal", "SelButton", sel)
	t.set_stylebox("hover", "SelButton", sel)
	t.set_color("font_color", "SelButton", Kit.C_WHITE)
	t.set_color("font_hover_color", "SelButton", Kit.C_WHITE)
	var sel_off := _glow(_sb(panel.lerp(cyan, 0.08), Color(cyan, 0.55), 2), 0.12)  # 選んであるがまだ押せない(結果の「もう1回」の最初の 300 ms)
	t.set_stylebox("disabled", "SelButton", sel_off)
	t.set_color("font_disabled_color", "SelButton", Color(Kit.C_TEXT, 0.65))

	# 字・板
	t.set_color("font_color", "Label", Kit.C_TEXT)
	t.set_stylebox("panel", "Panel", _sb(Color(panel, 0.94), Kit.C_RULE, 2))
	t.set_stylebox("panel", "PanelContainer", _sb(Color(panel, 0.94), Kit.C_RULE, 2))

	# 入力欄(結果の共有する文字の枠)
	for type: String in ["TextEdit", "LineEdit"]:
		var n := _sb(Color(Kit.C_OUT, 0.9), Kit.C_RULE, 2, 8)
		n.content_margin_left = 16
		n.content_margin_right = 16
		var f := n.duplicate() as StyleBoxFlat
		f.border_color = cyan
		t.set_stylebox("normal", type, n)
		t.set_stylebox("read_only", type, n)
		t.set_stylebox("focus", type, f)
		t.set_font("font", type, Kit.font(500))
		t.set_font_size("font_size", type, 18)
		t.set_color("font_color", type, Kit.C_TEXT)
		t.set_color("font_readonly_color", type, Kit.C_KEY_TEXT)
		t.set_color("font_selected_color", type, Kit.C_WHITE)
		t.set_color("selection_color", type, Color(cyan, 0.35))
		t.set_color("caret_color", type, cyan)
		t.set_color("font_placeholder_color", type, Kit.C_DIM)

	# 右クリックのメニュー・ツールチップ(今の画面では出さないが、出た時に既定の見た目に戻らないように)
	var pop := _sb(panel, cyan, 2, 8)
	pop.content_margin_left = 6
	pop.content_margin_right = 6
	t.set_stylebox("panel", "PopupMenu", pop)
	t.set_stylebox("hover", "PopupMenu", _sb(Color(cyan, 0.22), Color(0, 0, 0, 0), 0, 6))
	t.set_font("font", "PopupMenu", Kit.font(500))
	t.set_font_size("font_size", "PopupMenu", 18)
	t.set_color("font_color", "PopupMenu", Kit.C_TEXT)
	t.set_color("font_hover_color", "PopupMenu", Kit.C_WHITE)
	t.set_color("font_disabled_color", "PopupMenu", Kit.C_DIM)
	t.set_color("font_separator_color", "PopupMenu", Kit.C_DIM)
	var line := StyleBoxLine.new()
	line.color = Kit.C_RULE
	line.thickness = 2
	t.set_stylebox("separator", "PopupMenu", line)
	t.set_stylebox("panel", "TooltipPanel", _sb(panel, cyan, 2, 6))
	t.set_color("font_color", "TooltipLabel", Kit.C_TEXT)
	t.set_font_size("font_size", "TooltipLabel", 16)

	# スクロールバー
	for type: String in ["VScrollBar", "HScrollBar"]:
		var track := StyleBoxFlat.new()
		track.bg_color = Kit.C_OUT
		track.set_corner_radius_all(4)
		var grab := StyleBoxFlat.new()
		grab.bg_color = Kit.C_RULE.lightened(0.2)
		grab.set_corner_radius_all(4)
		var grab_hi := grab.duplicate() as StyleBoxFlat
		grab_hi.bg_color = Color(cyan, 0.7)
		var grab_on := grab.duplicate() as StyleBoxFlat
		grab_on.bg_color = cyan
		t.set_stylebox("scroll", type, track)
		t.set_stylebox("scroll_focus", type, track)
		t.set_stylebox("grabber", type, grab)
		t.set_stylebox("grabber_highlight", type, grab_hi)
		t.set_stylebox("grabber_pressed", type, grab_on)

	# つまみ(今は画面で使っていないが、後から足した時に既定の見た目に戻らないように)
	var rail := StyleBoxFlat.new()
	rail.bg_color = Kit.C_RULE
	rail.set_corner_radius_all(3)
	rail.content_margin_top = 3
	rail.content_margin_bottom = 3
	var rail_on := rail.duplicate() as StyleBoxFlat
	rail_on.bg_color = cyan
	var grab_n := _icon(18, Kit.C_TEXT, Kit.C_TEXT)  # 絵は 1 枚ずつ作って使い回す(書き出しを重くしない)
	var grab_h := _icon(18, cyan, cyan)
	var grab_d := _icon(18, Kit.C_DIM, Kit.C_DIM)
	for type: String in ["HSlider", "VSlider"]:
		t.set_stylebox("slider", type, rail)
		t.set_stylebox("grabber_area", type, rail_on)
		t.set_stylebox("grabber_area_highlight", type, rail_on)
		t.set_icon("grabber", type, grab_n)
		t.set_icon("grabber_highlight", type, grab_h)
		t.set_icon("grabber_disabled", type, grab_d)

	# チェック
	var off := _icon(20, Color(0, 0, 0, 0), Kit.C_DIM)
	var on := _icon(20, Color(0, 0, 0, 0), cyan, cyan)
	for type: String in ["CheckBox", "CheckButton"]:
		t.set_icon("unchecked", type, off)
		t.set_icon("checked", type, on)
		t.set_icon("unchecked_disabled", type, off)
		t.set_icon("checked_disabled", type, on)
		t.set_font("font", type, Kit.font(700))
		t.set_color("font_color", type, Kit.C_TEXT)
		t.set_color("font_hover_color", type, Kit.C_WHITE)
		t.set_color("font_pressed_color", type, Kit.C_TEXT)
		t.set_color("font_focus_color", type, Kit.C_TEXT)
		for st: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			t.set_stylebox(st, type, StyleBoxEmpty.new())
		t.set_stylebox("focus", type, _sb(Color(0, 0, 0, 0), cyan, 2, 6))
	return t
