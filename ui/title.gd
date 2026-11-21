# S1 タイトル(画面設計書 §2・§10)。ネオンの看板の題字、入口 2 つ(今日のステージ・練習)と設定、記録、下に 30 キーの枠を薄く(自機は F)。
# 薄い盤の自機は、DEMO_MS ごとに決まった順でキーへ跳んで見せる(遊び方を言葉でなく見せる。2026-11-20 磨きで足した)。点滅を弱める 入なら跳ばない。
extends Control

signal chosen(what: String)  # "daily" / "practice" / "settings"

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Keys := preload("res://core/keys.gd")
const Score := preload("res://core/score.gd")
const Kit := preload("res://ui/kit.gd")
const Menu := preload("res://ui/menu.gd")
const Field := preload("res://ui/field.gd")
const Logo := preload("res://ui/logo.gd")
const KeyHint := preload("res://ui/keyhint.gd")

var menu: Menu
var faint: Field  # 薄い盤
var logo: Logo
var reduce := false
var demo_i := 0  # 次に跳ぶ DEMO_KEYS の番号
var _demo_at := 0
var _notes: Array = []  # [文字, ボタン]。記録の札(_draw で描く)


# store は save_store、day は通し日数、date は "2026-11-19"。p_reduce は点滅を弱める(動きを止める)。
func build(store: RefCounted, day: int, date: String, p_reduce: bool = false) -> void:
	size = Vector2(1280, 720)
	reduce = p_reduce
	faint = Field.new()
	faint.snap = Field.title_snap()
	faint.bare = true
	faint.line_k = 1.8  # 0.6 倍に縮めても線が切れないように
	faint.modulate.a = 0.55
	faint.scale = Vector2(0.6, 0.6)
	Kit.place(faint, 256, 296, 1280, 720)
	add_child(faint)
	_demo_at = Time.get_ticks_msec()
	logo = Logo.new()
	logo.reduce = reduce
	logo.position = Vector2(((1280 - logo.size.x) / 2.0), 4)
	logo.start_ms = Time.get_ticks_msec() - Logo.intro_ms()  # S0 で灯った後なので、灯りきった看板から(光の息だけ続く)
	add_child(logo)
	add_child(Kit.place(Kit.label(S.TAGLINE, 24, Kit.C_DIM, 500), 0, 148, 1280, 40))
	if store.load_failed:
		add_child(Kit.place(Kit.label(S.LOAD_FAILED, 18, Kit.C_WARN, 500), 0, 184, 1280, 26))
	# 入口は真ん中に置く(左に寄せると右半分が空いて見えた。記録の札はボタンの右、x 940〜)
	var daily := Kit.place(Kit.button("daily", "%s   %s" % [S.B_DAILY, date], 30), 380, 214, 520, 88)
	var practice := Kit.place(Kit.button("practice", S.B_PRACTICE, 28), 380, 316, 520, 88)
	var settings := Kit.place(Kit.button("settings", S.B_SETTINGS, 24), 520, 418, 240, 72)
	for b: Button in [daily, practice, settings]:
		add_child(b)
		var what := String(b.name)
		b.pressed.connect(func() -> void: chosen.emit(what))
	var d: Dictionary = store.daily(day)
	var pb: Variant = store.practice_best()
	if d["first"] != null:
		var first: Dictionary = d["first"]
		_note((S.REC_FIRST % [S.REC_CLEAR if first["clear"] else "", Score.comma(first["score"])]) + "\n"
			+ (S.REC_TODAY_BEST % Score.comma(d["best"]["score"])), daily)
	elif pb != null or store.data["daily"] != null:
		_note(S.REC_NONE, daily)  # 初めての起動(記録が何も無い)では記録の行を出さない
	if pb != null:
		_note(S.REC_BEST % Score.comma(pb["score"]), practice)
	var ver := Kit.label(S.VERSION, 18, Kit.C_DIM, 500)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(Kit.place(ver, 28, 678, 200, 30))
	add_child(Kit.place(KeyHint.new([[["up", "down"], S.HINT_SELECT], [["Enter"], S.HINT_OK]], HORIZONTAL_ALIGNMENT_RIGHT), 640, 674, 612, 36))
	menu = Menu.new([daily, practice, settings] as Array[Button], 0)


# 記録の札: ボタンの右に、縦の細い管と 1〜2 行の字。
func _note(text: String, by: Button) -> void:
	var l := Kit.label(text, 20, Kit.C_TEXT, 500)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.name = "note_" + String(by.name)
	add_child(Kit.place(l, by.position.x + by.size.x + 40, by.position.y, 320, by.size.y))
	_notes.append(by)
	queue_redraw()


func _draw() -> void:
	for by: Button in _notes:
		var x := by.position.x + by.size.x + 24.0
		Kit.neon_line(self, PackedVector2Array([Vector2(x, by.position.y + 14), Vector2(x, by.position.y + by.size.y - 14)]), Color(Kit.C_PINK, 0.8), 2.0, 0.6)


func _process(_delta: float) -> void:
	if reduce:
		return
	var now := Time.get_ticks_msec()
	if now - _demo_at >= B.DEMO_MS:
		_demo_at = now
		demo_step(now)
	faint.queue_redraw()


# 薄い盤の自機を次のキーへ跳ばせる(残像・跳んだ筋・キーの光はプレイと同じ描き方)。
func demo_step(now: int) -> void:
	var to: int = B.DEMO_KEYS[demo_i % B.DEMO_KEYS.size()]
	demo_i += 1
	var from: int = faint.snap["key"]
	faint.ghost_key = from
	faint.ghost_to = to
	faint.ghost_at = now
	faint.key_glow_at[to] = now
	faint.snap["key"] = to
	faint.snap["x"] = Keys.x_of(to)
	faint.snap["y"] = Keys.y_of(to)


func key(ev: InputEventKey) -> void:
	menu.key(ev)
