# S2 プレイ(画面設計書 §3)。sim をたまった時間ぶん進め(1 フレーム 8 tick まで)、events で演出と音を出し、snapshot を field に渡す。
# ゲームの決まりは持たない(INV-1)。押したキーは ui/keymap で番号にして sim.queue_press に渡すだけ。
# 上の帯(点・波と残り時間・力の 5 つの四角・残機の三角)は bar とラベルで描く。帯は遊ぶ場所より上に重ね、入ってくる敵を帯の下に隠す。
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
var _points: Label
var _wave: Label
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
	_points = Kit.label("", 26, Kit.C_TEXT, 700)
	_points.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(Kit.place(_points, 124, 8, 300, 48))
	_wave = Kit.label("", 26, Kit.C_TEXT, 700)
	add_child(Kit.place(_wave, 440, 8, 400, 48))
	_note = Kit.label("", 48, Kit.C_TEXT, 800)
	add_child(Kit.place(_note, 0, 220, 1280, 72))
	_clear = Kit.label(S.CLEAR, 64, Kit.C_GOOD, 800)
	add_child(Kit.place(_clear, 0, 200, 1280, 96))
	_ime = Kit.label(S.IME, 24, Kit.C_WARN, 700)
	add_child(Kit.place(_ime, 0, 380, 1280, 40))


func start(p_mode: int, p_seed: int) -> void:
	mode = p_mode
	seed_value = p_seed
	sim = Sim.new(p_seed, p_mode)
	paused = false
	_acc = 0.0
	_over_at = -1
	field.reduce_flash = reduce_flash
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
			field.hit_at[e["id"]] = now
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
	_points.text = S.BAR_POINTS % Score.comma(int(_snap["score"]))
	_wave.text = S.BAR_WAVE % [int(_snap["wave"]), Score.remain_text(int(_snap["tick"]))]
	bar.queue_redraw()


# 上の帯の右: 「力」と 5 つの四角(力 200 ごとに 1 つ塗る。強さ 2・3 で縁を太く)、残機の三角(失った物は線だけ)。
@warning_ignore("integer_division")
func _draw_bar() -> void:
	bar.draw_rect(Rect2(-2000, -2000, 5280, 2000 + B.FIELD_TOP), Kit.C_OUT)
	bar.draw_rect(Rect2(-2000, B.FIELD_BOTTOM, 5280, 2000), Kit.C_OUT)  # 縦長の窓で、y 720 より下の余りに光線や壁の切れ目を見せない
	bar.draw_line(Vector2(B.FIELD_LEFT, B.FIELD_TOP), Vector2(B.FIELD_RIGHT, B.FIELD_TOP), Kit.C_EDGE, 1.0)
	if _snap.is_empty():
		return
	var f := Kit.font(700)
	var power: int = _snap["power"]
	var strength: int = _snap["strength"]
	bar.draw_string(f, Vector2(860, 42), S.BAR_POWER, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Kit.C_DIM)
	for k in 5:
		var r := Rect2(892 + k * 26, 20, 20, 20)
		if power >= (k + 1) * (B.POWER_MAX / 5):
			bar.draw_rect(r, Kit.C_SHIP)
		bar.draw_rect(r, Kit.C_SHIP, false, 1.0 + 1.5 * (strength - 1))
	var lives: int = _snap["lives"]
	for k in B.LIVES:
		var c := Vector2(1060 + k * 34, 32)
		var pts := PackedVector2Array([c + Vector2(0, -12), c + Vector2(11, 10), c + Vector2(-11, 10), c + Vector2(0, -12)])
		if k < lives:
			bar.draw_colored_polygon(pts.slice(0, 3), Kit.C_SHIP)
		else:
			bar.draw_polyline(pts, Kit.C_DIM, 1.5, true)
