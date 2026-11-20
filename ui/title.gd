# S1 タイトル(画面設計書 §2)。入口 2 つ(今日のステージ・練習)と設定、記録、下に 30 キーの枠を薄く(自機は F)。
# 薄い盤の自機は、DEMO_MS ごとに決まった順でキーへ跳んで見せる(遊び方を言葉でなく見せる。2026-11-20 磨きで足した)。
extends Control

signal chosen(what: String)  # "daily" / "practice" / "settings"

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Keys := preload("res://core/keys.gd")
const Score := preload("res://core/score.gd")
const Kit := preload("res://ui/kit.gd")
const Menu := preload("res://ui/menu.gd")
const Field := preload("res://ui/field.gd")

var menu: Menu
var faint: Field  # 薄い盤
var demo_i := 0  # 次に跳ぶ DEMO_KEYS の番号
var _demo_at := 0


# store は save_store、day は通し日数、date は "2026-11-19"。
func build(store: RefCounted, day: int, date: String) -> void:
	size = Vector2(1280, 720)
	faint = Field.new()
	faint.snap = Field.title_snap()
	faint.bare = true
	faint.line_k = 1.8  # 0.6 倍に縮めても線が切れないように
	faint.modulate.a = 0.6
	faint.scale = Vector2(0.6, 0.6)
	Kit.place(faint, 256, 296, 1280, 720)
	add_child(faint)
	_demo_at = Time.get_ticks_msec()
	add_child(Kit.place(Kit.label(S.NAME, 72, Kit.C_TEXT, 800), 0, 20, 1280, 100))
	add_child(Kit.place(Kit.label(S.TAGLINE, 28, Kit.C_DIM, 500), 0, 116, 1280, 44))
	if store.load_failed:
		add_child(Kit.place(Kit.label(S.LOAD_FAILED, 18, Kit.C_WARN), 0, 160, 1280, 28))
	var daily := Kit.place(Kit.button("daily", "%s   %s" % [S.B_DAILY, date], 30), 140, 196, 520, 88)
	var practice := Kit.place(Kit.button("practice", S.B_PRACTICE, 28), 140, 296, 520, 88)
	var settings := Kit.place(Kit.button("settings", S.B_SETTINGS, 24), 140, 396, 240, 72)
	for b: Button in [daily, practice, settings]:
		add_child(b)
		var what := String(b.name)
		b.pressed.connect(func() -> void: chosen.emit(what))
	var d: Dictionary = store.daily(day)
	var pb: Variant = store.practice_best()
	if d["first"] != null:
		var first: Dictionary = d["first"]
		_note((S.REC_FIRST % [S.REC_CLEAR if first["clear"] else "", Score.comma(first["score"])]) + " / "
			+ (S.REC_TODAY_BEST % Score.comma(d["best"]["score"])), daily)
	elif pb != null or store.data["daily"] != null:
		_note(S.REC_NONE, daily)  # 初めての起動(記録が何も無い)では記録の行を出さない
	if pb != null:
		_note(S.REC_BEST % Score.comma(pb["score"]), practice)
	var ver := Kit.label(S.VERSION, 20, Kit.C_DIM)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(Kit.place(ver, 24, 676, 200, 32))
	menu = Menu.new([daily, practice, settings] as Array[Button], 0)


func _note(text: String, by: Button) -> void:
	var l := Kit.label(text, 20, Kit.C_DIM, 500)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(Kit.place(l, by.position.x + by.size.x + 24, by.position.y, 560, by.size.y))


func _process(_delta: float) -> void:
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
