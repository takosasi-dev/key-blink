# S3 結果(画面設計書 §4・§10)。クリアか届いた波、点を 600 ms で数え上げ、最高との差・4 つの数の升・共有する文字を出す。
# 新しい記録の時は、数え上がった所で差の行が桃のネオンの看板として灯る(祝いはこの 1 か所。点滅を弱める 入なら最初から灯っている)。
# もう1回は 300 ms 後から押せる(Enter・R でも)。最初から選んである印は出す。コピーは clipboard_set を試し、選べる枠も出す(E-14)。
# 作りは KeySwat・RootCall の ui/result.gd。
extends Control

signal retry
signal to_title

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Score := preload("res://core/score.gd")
const Kit := preload("res://ui/kit.gd")
const Menu := preload("res://ui/menu.gd")
const KeyHint := preload("res://ui/keyhint.gd")

var menu: Menu
var share := ""
var new_best := false
var reduce := false
var _points := 0
var _head := ""
var _head_color := Kit.C_TEXT
var _diff := ""  # 最高との差の行(前の最高が無ければ空)
var _stats: Array = []  # [名前, 数の文字]
var _shown_at := 0
var _retry: Button
var _copied: Label


# rec は save_store.record() の戻り値。
func build(result: Dictionary, rec: Dictionary, share_text: String, p_reduce: bool = false) -> void:
	size = Vector2(1280, 720)
	share = share_text
	reduce = p_reduce
	_points = int(result["score"])
	_shown_at = Time.get_ticks_msec()
	_head = S.RES_CLEAR % int(result["lives"]) if result["clear"] else S.RES_WAVE % int(result["wave"])
	_head_color = Kit.C_GOOD if result["clear"] else Kit.C_TEXT
	new_best = bool(rec["new_best"]) and rec["prev_best"] != null
	if rec["prev_best"] != null:
		var diff := _points - int(rec["prev_best"]["score"])
		_diff = S.RES_NEW_BEST % Score.comma(diff) if rec["new_best"] else S.RES_TO_BEST % Score.comma(-diff)
	_stats = [[S.RES_WAVES.trim_suffix(" %d"), str(int(result["wave"]))], [S.RES_KILLS.trim_suffix(" %d"), str(int(result["kills"]))],
		[S.RES_GRAZES.trim_suffix(" %d"), str(int(result["grazes"]))], [S.RES_BLINKS.trim_suffix(" %d"), str(int(result["blinks"]))]]
	_retry = Kit.place(Kit.button("retry", S.B_RETRY, 30), 490, 368, 300, 72)
	_retry.disabled = true
	add_child(_retry)
	var box := TextEdit.new()
	box.name = "share"
	box.text = share
	box.editable = false
	box.context_menu_enabled = false  # Godot の右クリックのメニューは英語の項目で、画面の言葉と合わない。選んで Ctrl+C で写せる
	box.focus_mode = Control.FOCUS_CLICK
	add_child(Kit.place(box, 290, 458, 700, 102))
	var copy := Kit.place(Kit.button("copy", S.B_COPY, 22), 420, 574, 200, 56)
	var title := Kit.place(Kit.button("title", S.B_TITLE, 22), 660, 574, 200, 56)
	add_child(copy)
	add_child(title)
	_copied = Kit.label("", 18, Kit.C_DIM, 500)
	add_child(Kit.place(_copied, 0, 634, 1280, 28))
	if not rec.get("saved", true):
		add_child(Kit.place(Kit.label(S.SAVE_FAILED, 20, Kit.C_WARN, 500), 0, 634, 1280, 28))
	add_child(Kit.place(KeyHint.new([[["Enter", "R"], S.B_RETRY]], HORIZONTAL_ALIGNMENT_RIGHT), 640, 674, 612, 36))
	_retry.pressed.connect(func() -> void: retry.emit())
	copy.pressed.connect(_copy)
	title.pressed.connect(func() -> void: to_title.emit())
	menu = Menu.new([_retry, copy, title] as Array[Button], 0)


func _copy() -> void:
	DisplayServer.clipboard_set(share)
	_copied.text = S.COPIED


# 画面に入ってからの時間で、数え上げた点。
@warning_ignore("integer_division")
static func shown_points(points: int, t: int, p_reduce: bool) -> int:
	return points if p_reduce or t >= B.COUNT_MS else points * maxi(t, 0) / B.COUNT_MS


# 新しい記録の看板の灯り(0→1): 数え上げが終わってから SIGN_MS で灯る(明るさは上がるだけ)。灯る前は 0。
static func sign_k(t: int, p_reduce: bool) -> float:
	if p_reduce:
		return 1.0
	return Kit.ease_out(float(t - B.COUNT_MS) / B.SIGN_MS)


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() - _shown_at
	if _retry.disabled and t >= B.RETRY_LOCK_MS:
		_retry.disabled = false
	if t < B.COUNT_MS + B.SIGN_MS + 50:
		queue_redraw()


func _draw() -> void:
	var t := Time.get_ticks_msec() - _shown_at
	var num := Kit.num_font()
	var jp := Kit.font(700)
	# 見出しと両側の短い管
	var half := jp.get_string_size(_head, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x / 2.0
	draw_string(jp, Vector2(0, 58), _head, HORIZONTAL_ALIGNMENT_CENTER, 1280, 30, _head_color)
	for sx: float in [-1.0, 1.0]:
		Kit.neon_line(self, PackedVector2Array([Vector2(640 + sx * (half + 24), 47), Vector2(640 + sx * (half + 96), 47)]), Color(Kit.C_CYAN, 0.7), 2.0, 0.6)
	# 点(数え上げ)。新しい記録の時は桃の光、ふだんは水色の光
	var pts := Score.comma(shown_points(_points, t, reduce))
	var w := Kit.digits_width(num, pts, 120)
	var unit := jp.get_string_size(S.RES_POINTS % "", HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
	var x0 := 640.0 - (w + 12.0 + unit) / 2.0
	Kit.draw_digits(self, num, x0, 188, pts, 120, Kit.C_PINK if new_best else Kit.C_CYAN, HORIZONTAL_ALIGNMENT_LEFT, 1.6)  # 光(コンマの光が下の看板に触れないよう 188)
	Kit.draw_digits(self, num, x0, 188, pts, 120, Kit.C_WHITE)  # 芯
	draw_string(jp, Vector2(x0 + w + 12.0, 184), S.RES_POINTS % "", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Kit.C_DIM)
	# 最高との差。新しい記録なら桃の看板が灯る
	if _diff != "":
		var tw := jp.get_string_size(_diff, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		if new_best:
			var k := sign_k(t, reduce)
			if k > 0.0:
				var r := Rect2(640 - tw / 2.0 - 26, 220, tw + 52, 44)
				draw_rect(r.grow(-2), Color(Kit.C_PINK, 0.10 * k))
				Kit.neon_rect(self, r, Color(Kit.C_PINK, k), 2.0, 1.2 * k, 14)
				Kit.neon_text(self, jp, Vector2(0, 250), _diff, 24, Color(Kit.C_WHITE, k), 0.0, HORIZONTAL_ALIGNMENT_CENTER, 1280)
		else:
			draw_string(jp, Vector2(0, 250), _diff, HORIZONTAL_ALIGNMENT_CENTER, 1280, 24, Kit.C_DIM)
	# 4 つの数の升
	for k in _stats.size():
		var r := Rect2(176 + k * 236, 274, 220, 76)
		var p := Kit.round_rect_points(r, 10.0)
		draw_colored_polygon(p, Color(Kit.C_PANEL, 0.9))
		p.append(p[0])
		draw_polyline(p, Kit.C_RULE.lightened(0.15), 2.0, true)
		draw_string(Kit.font(500), Vector2(r.position.x, r.position.y + 26), _stats[k][0], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 18, Kit.C_DIM)
		Kit.draw_digits(self, num, r.get_center().x, r.position.y + 64, _stats[k][1], 34, Kit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)


func key(ev: InputEventKey) -> void:
	if ev.pressed and not ev.echo and ev.physical_keycode == KEY_R and not _retry.disabled:
		Sfx.play("confirm")
		retry.emit()
		return
	menu.key(ev)
