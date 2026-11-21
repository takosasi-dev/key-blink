# 題字(v0.3.0): KeyBlink をネオン管の看板にする。字は Tilt Neon の桃の管で、i の点の代わりに自機の水色の三角が乗る。
# 入った時は管が左から 1 字ずつ灯り(明るさは上がるだけで、消えたり点いたりしない)、灯りきると三角が K の前から i の上へ跳ぶ(残像と跳んだ筋)。
# その後は光がゆっくり息をする(HUM_MS で 1 往復)。点滅を弱める 入なら止まった絵のまま。_draw だけで描く。
extends Control

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Kit := preload("res://ui/kit.gd")

const SIZE := 112
const BASE_Y := 112.0  # 字の下の線(この Control の座標)
const DOTLESS_I := 0x131

var start_ms := 0  # 入りの動きの始まり(0 なら動かさない)
var reduce := false
var now_ms := 0
var _chars: Array = []  # [字, x]
var _tittle := Vector2.ZERO  # 三角を置く所(i の点の場所)
var _from := Vector2.ZERO  # 三角が跳ぶ前に居る所(K の左下)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var f := Kit.num_font()
	var x := 0.0
	for c in S.NAME:
		var ch := String.chr(DOTLESS_I) if c == "i" else c
		var w := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE).x
		if c == "i":
			_tittle = Vector2(x + w / 2.0, BASE_Y - SIZE * 0.517 - 26.0)
		_chars.append([ch, x])
		x += w
	size = Vector2(x, 150)
	_from = Vector2(-34.0, BASE_Y - 16.0)


func play_intro() -> void:
	start_ms = Time.get_ticks_msec()


func _process(_delta: float) -> void:
	if not reduce and start_ms > 0:
		queue_redraw()


func _now() -> int:
	return now_ms if now_ms > 0 else Time.get_ticks_msec()


static func intro_ms() -> int:
	return B.LOGO_STAGGER_MS * S.NAME.length() + B.LOGO_LIGHT_MS + B.LOGO_JUMP_MS


# k 番目の字の灯り(0→1)。動かさない時は 1。
func lit(k: int) -> float:
	if reduce or start_ms <= 0:
		return 1.0
	return Kit.ease_out(float(_now() - start_ms - k * B.LOGO_STAGGER_MS) / B.LOGO_LIGHT_MS)


# 三角が跳んでからの割合(0→1)。跳ぶ前は -1。動かさない時は 1。
func jump() -> float:
	if reduce or start_ms <= 0:
		return 1.0
	var t := _now() - start_ms - B.LOGO_STAGGER_MS * S.NAME.length() - B.LOGO_LIGHT_MS
	return -1.0 if t < 0 else clampf(float(t) / B.LOGO_JUMP_MS, 0.0, 1.0)


# 光の強さ(灯りきった後にゆっくり息をする)。動かさない時は 1。
func hum() -> float:
	if reduce or start_ms <= 0 or jump() < 1.0:
		return 1.0
	return 0.8 + 0.2 * Kit.tri(_now() - start_ms, B.HUM_MS)


func _draw() -> void:
	var f := Kit.num_font()
	var g := hum()
	for k in _chars.size():
		var a := lit(k)
		if a <= 0.0:
			continue
		var at := Vector2(_chars[k][1], BASE_Y)
		# 外の広いにじみ(看板の管が夜の空気を照らす。2 重のにじみだけでは光が弱く見えた。見直し 2026-11-21)
		draw_string_outline(f, at, _chars[k][0], HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE, 44, Color(Kit.C_PINK, 0.07 * g * a))
		Kit.neon_text(self, f, at, _chars[k][0], SIZE, Color(Kit.C_PINK, a), 1.6 * g * a)
		draw_string(f, at, _chars[k][0], HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE, Color(Kit.C_WHITE, 0.25 * a))  # 管の芯の白み
	var j := jump()
	if j < 0.0:
		Kit.ship(self, _from, 30.0, Color(Kit.C_CYAN, 0.5))  # 跳ぶ前は K の左で待つ
		return
	if j < 1.0:
		var fade := 1.0 - j
		draw_line(_from, _tittle, Color(Kit.C_CYAN, 0.45 * fade), 3.0, true)
		Kit.ship(self, _from, 30.0, Color(Kit.C_CYAN, 0.5 * fade))
	# 三角の光(にじみ 2 重)と本体
	draw_circle(_tittle + Vector2(0, -2), 22.0, Color(Kit.C_CYAN, 0.08 * g))
	draw_circle(_tittle + Vector2(0, -2), 14.0, Color(Kit.C_CYAN, 0.14 * g))
	Kit.ship(self, _tittle, 30.0, Kit.C_CYAN)
	draw_circle(_tittle + Vector2(0, 1), 3.0, Kit.C_WHITE)
