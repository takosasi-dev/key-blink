# S2 プレイ(画面設計書 §3)。sim をたまった時間ぶん進め(1 フレーム 8 tick まで)、events で演出と音を出し、snapshot を field に渡す。
# ゲームの決まりは持たない(INV-1)。押したキーは ui/keymap で番号にして sim.queue_press に渡すだけ。
# 上の帯(点・波と残り時間・力の 5 つの四角・残機の三角)は bar が描く。帯は遊ぶ場所より上に重ね、入ってくる敵を帯の下に隠す。
# v0.3.0: 点はネオン管の大きな数字で本当の点へ数え上がり、増えた時と波が変わった時に小さくはねる(点滅を弱める 入なら即座・はね無し)。
# 遊ぶ場所の左右の縁は細い水色の管、帯の下の縁も管にして、タイトルと同じ夜の街に見せる。
extends Control

signal finished(result: Dictionary)
signal pause_requested

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Sim := preload("res://core/sim.gd")
const Score := preload("res://core/score.gd")
const Bots := preload("res://core/bots.gd")
const Kit := preload("res://ui/kit.gd")
const Keymap := preload("res://ui/keymap.gd")
const Field := preload("res://ui/field.gd")
const Fx := preload("res://ui/fx.gd")

var sim: Sim = null
var mode := 0
var seed_value := 1
var paused := false
var shake_on := true
var reduce_flash := false
var bot: Bots.Driver = null  # 自動の確かめ(smoke)だけで使う
var field: Field
var fx: Fx
var _acc := 0.0
var _over_at := -1
var _over_wait := B.OVER_MS
var _shake_until := 0
var _shake_px := 0.0
var _wave_until := 0
var _clear_until := 0
var _ime_until := 0
var shown_score := 0.0  # 帯に出している点(本当の点へ数え上がる)
var _score_bump_at := -100000
var _wave_bump_at := -100000
var _last_wave := 0
var _note: Label
var _clear: Label
var _ime: Label
var _snap: Dictionary = {}
var bar: Control  # 上の帯(背景と、力・残機の絵)
var tint: ColorRect  # 当たった時の画面の赤み
var _tint_at := -100000
var _stop_until := 0  # 当たった時の短い止め(この時刻まで step しない)
var key_at := 0  # 跳ぶキーを受けた時刻(usec。押してから描くまでを main が測る)


func _ready() -> void:
	size = Vector2(1280, 720)
	field = Field.new()
	Kit.place(field, 0, 0, 1280, 720)
	add_child(field)
	fx = Fx.new()
	Kit.place(fx, 0, 0, 1280, 720)
	add_child(fx)
	tint = ColorRect.new()
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tint.color = Color(Kit.C_BULLET, 0.0)
	add_child(Kit.place(tint, -2000, -2000, 5280, 4720))
	bar = Control.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(_draw_bar)
	add_child(Kit.place(bar, 0, 0, 1280, 720))
	var esc := Kit.place(Kit.button("Esc", S.ESC, 18), 24, 12, 72, 40)
	esc.pressed.connect(func() -> void: pause_requested.emit())
	add_child(esc)
	_note = _sign_label("", 52, Kit.C_TEXT, Kit.C_CYAN)
	add_child(Kit.place(_note, 0, 216, 1280, 76))
	_clear = _sign_label(S.CLEAR, 68, Kit.C_GOOD, Kit.C_GOOD)
	add_child(Kit.place(_clear, 0, 198, 1280, 100))
	_ime = Kit.label(S.IME, 24, Kit.C_WARN, 700)
	add_child(Kit.place(_ime, 0, 380, 1280, 40))


# 遊ぶ場所の上に出す大きな字(「波 4」「クリア」)。ネオンの光(太い薄い縁)と暗い縁取りで、どの背景の上でも読める。
static func _sign_label(text: String, size: int, color: Color, glow: Color) -> Label:
	var l := Kit.label(text, size, color, 800)
	l.add_theme_font_override("font", Kit.num_font())
	l.add_theme_constant_override("outline_size", 14)
	l.add_theme_color_override("font_outline_color", Color(glow.darkened(0.55), 0.85))
	l.add_theme_constant_override("shadow_outline_size", 22)
	l.add_theme_color_override("font_shadow_color", Color(glow, 0.18))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 0)
	return l


# 帯の点を本当の点へ近づける(1 フレームぶん)。点滅を弱める 入なら即座に合わせる。点が減った(新しい回)ら即座に合わせる。
static func count_up(shown: float, target: int, dt: float, p_reduce: bool) -> float:
	if p_reduce or target < shown:
		return float(target)
	var next := shown + (target - shown) * minf(1.0, B.COUNT_UP_RATE * dt)
	return float(target) if target - next < 1.0 else next


# 変わってからの時間で、はねの大きさ(1 = はね無し)。
static func bump_scale(since_ms: int) -> float:
	if since_ms < 0 or since_ms >= B.BUMP_MS:
		return 1.0
	return 1.0 + B.BUMP_SCALE * (1.0 - float(since_ms) / B.BUMP_MS)


func start(p_mode: int, p_seed: int) -> void:
	mode = p_mode
	seed_value = p_seed
	sim = Sim.new(p_seed, p_mode)
	paused = false
	_acc = 0.0
	_over_at = -1
	field.reduce_flash = reduce_flash
	shown_score = 0.0
	_last_wave = 0
	_refresh()


func is_playing() -> bool:
	return sim != null and not sim.is_over()


# S2 のキー。Esc は一時停止、30 キーは sim へ。Space・Enter・矢印などは何もしない(画面設計書 §7)。
func key(ev: InputEventKey) -> void:
	if ev.pressed and not ev.echo and ev.physical_keycode == KEY_ESCAPE:
		pause_requested.emit()
		return
	if ev.pressed and ev.physical_keycode == KEY_NONE:
		_ime_until = Time.get_ticks_msec() + B.IME_NOTE_MS  # 共通 §3 の 9: 日本語入力で物理キーが取れない
	if sim == null or sim.is_over() or paused:
		return
	var k := Keymap.index_of(ev)
	if k >= 0:
		if sim.cooldown == 0 and k != sim.key:
			key_at = Time.get_ticks_usec()
		sim.queue_press(k)


func _process(delta: float) -> void:
	if sim == null:
		return
	var now := Time.get_ticks_msec()
	position = Vector2.ZERO
	if shake_on and now < _shake_until:
		position = Vector2(randf_range(-_shake_px, _shake_px), randf_range(-_shake_px, _shake_px))
	_note.visible = now < _wave_until
	_clear.visible = now < _clear_until
	_ime.visible = now < _ime_until
	fx.tick()
	if _snap.has("score"):
		var target := int(_snap["score"])
		if target > int(shown_score) and not reduce_flash and now - _score_bump_at > B.BUMP_MS:
			_score_bump_at = now
		shown_score = count_up(shown_score, target, delta, reduce_flash)
		bar.queue_redraw()
	var tk := float(now - _tint_at) / B.HIT_TINT_MS
	var peak := B.HIT_TINT_ALPHA_REDUCED if reduce_flash else B.HIT_TINT_ALPHA
	tint.color.a = peak * (1.0 - tk) if tk >= 0.0 and tk < 1.0 else 0.0
	field.queue_redraw()
	if _over_at >= 0:
		if now - _over_at >= _over_wait:
			_over_at = -2
			finished.emit(sim.result())
		return
	if paused or _over_at == -2:
		return  # 一時停止の間は step を呼ばず、たまった時間も持たない(AC-19)
	if now < _stop_until:
		_acc = 0.0
		return  # 当たった時の短い止め(止めた分の時間は持ち越さない)
	_acc += delta * B.TICK_HZ
	var n := int(_acc)
	_acc -= n
	if n > B.MAX_STEPS_PER_FRAME:
		n = B.MAX_STEPS_PER_FRAME  # E-20: 超えた分は捨てる
		_acc = 0.0
	var heard := {}
	for k in n:
		if bot != null:
			bot.feed(sim)
		sim.step()
		for e: Dictionary in sim.events():
			on_event(e, heard)
	_refresh()


# 演出の表(§9.12)。演出は events を受けたフレームに始める。同じ音は 1 フレーム 1 回。
func on_event(e: Dictionary, heard: Dictionary) -> void:
	var now := Time.get_ticks_msec()
	var t: String = e["type"]
	var sound := t
	match t:
		"blink":
			field.ghost_key = int(e["from"])
			field.ghost_to = int(e["to"])
			field.ghost_at = now
			field.key_glow_at[int(e["to"])] = now
		"power_up":
			field.ring_glow_at = now
		"shot_hit":
			if now - int(field.hit_at.get(e["id"], -100000)) >= B.HIT_FLASH_GAP_MS:
				field.hit_at[e["id"]] = now  # 白く光らせるのは HIT_FLASH_GAP_MS に 1 回まで(1 秒に 3 回を超えて明滅させない)
		"kill":
			var at := Vector2(float(e["x"]), float(e["y"]))
			fx.burst(at, Kit.ENEMY_COLORS[int(e["kind"])])
			fx.float_text(at - Vector2(0, 24), S.FLOAT % Score.comma(int(e["points"])))
			if int(e["kind"]) == Sim.FAN:
				_shake(B.SHAKE_FAN_PX, B.SHAKE_FAN_MS)
			field.hit_at.erase(e["id"])
		"graze":
			fx.spark(Vector2(float(e["x"]), float(e["y"])))
		"hit":
			fx.burst(Vector2(float(e["x"]), float(e["y"])), Kit.C_SHIP)
			_shake(B.SHAKE_HIT_PX, B.SHAKE_HIT_MS)
			field.hit_mark = Vector2(float(e["x"]), float(e["y"]))
			field.hit_mark_at = now
			_tint_at = now
			_stop_until = now + B.HIT_STOP_MS
		"wave_start":
			_note.text = S.WAVE_NOTE % int(e["wave"])
			_wave_until = now + B.WAVE_NOTE_MS
		"over":
			_over_at = now
			if int(e["reason"]) == Sim.OVER_CLEAR:
				_clear_until = now + B.CLEAR_NOTE_MS
				_over_wait = B.CLEAR_WAIT_MS
				sound = "clear"
			else:
				_over_wait = B.OVER_MS
	if bot != null and t in ["laser_fire", "wall_drop", "wave_start"]:
		print("SMOKE event=%s tick=%d" % [t, sim.tick])  # smoke で柱・壁・波の先まで描いたかを見る
	if not heard.has(sound):
		Sfx.play(sound)
	heard[sound] = true


func _shake(px: float, ms: int) -> void:
	if not shake_on:
		return
	_shake_px = maxf(_shake_px if Time.get_ticks_msec() < _shake_until else 0.0, px)
	_shake_until = maxi(_shake_until, Time.get_ticks_msec() + ms)


func _refresh() -> void:
	_snap = sim.snapshot()
	field.snap = _snap
	var w := int(_snap["wave"])
	if w != _last_wave:
		if _last_wave > 0 and not reduce_flash:
			_wave_bump_at = Time.get_ticks_msec()
		_last_wave = w
	bar.queue_redraw()


# 上の帯: 左に点(大きなネオンの数字。一番目立たせる)、真ん中に波と残り時間、右に「力」と 5 つの四角(力 200 ごとに 1 つ塗る。
# 強さ 2・3 で縁を太く)、残機の三角(失った物は線だけ)。遊ぶ場所の左右の縁と、帯の下の縁は細い水色の管。
@warning_ignore("integer_division")
func _draw_bar() -> void:
	bar.draw_rect(Rect2(-2000, -2000, 5280, 2000 + B.FIELD_TOP), Kit.C_OUT)
	bar.draw_rect(Rect2(-2000, B.FIELD_BOTTOM, 5280, 2000), Kit.C_OUT)  # 縦長の窓で、y 720 より下の余りに光線や壁の切れ目を見せない
	var rail := Color(Kit.C_CYAN, 0.45)
	Kit.neon_line(bar, PackedVector2Array([Vector2(B.FIELD_LEFT - 3, B.FIELD_TOP), Vector2(B.FIELD_RIGHT + 3, B.FIELD_TOP)]), rail, 1.5, 0.6)
	for x: float in [B.FIELD_LEFT - 3, B.FIELD_RIGHT + 3]:
		Kit.neon_line(bar, PackedVector2Array([Vector2(x, B.FIELD_TOP), Vector2(x, B.FIELD_BOTTOM)]), Color(Kit.C_CYAN, 0.28), 1.5, 0.5)
		var out := -1.0 if x < 640 else 1.0
		for k in 3:  # キーの段の高さに、外へ向けた桃の短い目盛り
			var y := B.KEY_ROW_Y0 + B.KEY_PITCH * k
			bar.draw_line(Vector2(x + out * 6, y), Vector2(x + out * 22, y), Color(Kit.C_PINK, 0.6), 2.0, true)
	if _snap.is_empty():
		return
	var now := Time.get_ticks_msec()
	var num := Kit.num_font()
	# 点
	var pts := Score.comma(int(shown_score))
	var sc := bump_scale(now - _score_bump_at)
	bar.draw_set_transform(Vector2(124, 48), 0.0, Vector2(sc, sc))
	var w := Kit.draw_digits(bar, num, 0, 0, pts, 38, Kit.C_WHITE, HORIZONTAL_ALIGNMENT_LEFT, 0.9)
	bar.draw_string(Kit.font(700), Vector2(w + 6, -2), S.BAR_POINTS % "", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Kit.C_DIM)
	bar.draw_set_transform(Vector2.ZERO)
	# 波と残り時間
	var wsc := bump_scale(now - _wave_bump_at)
	bar.draw_set_transform(Vector2(640, 44), 0.0, Vector2(wsc, wsc))
	var wave_text := S.WAVE_NOTE % int(_snap["wave"])
	var ww := num.get_string_size(wave_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
	var time_text := Score.remain_text(int(_snap["tick"]))
	var tw := num.get_string_size(time_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	var x0 := -(ww + 18 + tw) / 2.0
	Kit.neon_text(bar, num, Vector2(x0, 0), wave_text, 28, Kit.C_TEXT, 0.6)
	bar.draw_string(num, Vector2(x0 + ww + 18, 0), time_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Kit.C_DIM)
	bar.draw_set_transform(Vector2.ZERO)
	# 力
	var power: int = _snap["power"]
	var strength: int = _snap["strength"]
	bar.draw_string(Kit.font(700), Vector2(856, 42), S.BAR_POWER, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Kit.C_DIM)
	for k in 5:
		var r := Rect2(886 + k * 26, 21, 20, 20)
		if power >= (k + 1) * (B.POWER_MAX / 5):
			bar.draw_rect(r.grow(3), Color(Kit.C_SHIP, 0.18))
			bar.draw_rect(r, Kit.C_SHIP)
		bar.draw_rect(r, Kit.C_SHIP, false, 1.0 + 1.5 * (strength - 1))
	# 残機
	var lives: int = _snap["lives"]
	for k in B.LIVES:
		var c := Vector2(1060 + k * 34, 32)
		var tri := PackedVector2Array([c + Vector2(0, -12), c + Vector2(11, 10), c + Vector2(-11, 10), c + Vector2(0, -12)])
		if k < lives:
			bar.draw_circle(c + Vector2(0, 2), 15.0, Color(Kit.C_SHIP, 0.12))
			bar.draw_colored_polygon(tri.slice(0, 3), Kit.C_SHIP)
		else:
			bar.draw_polyline(tri, Kit.C_DIM, 1.5, true)
