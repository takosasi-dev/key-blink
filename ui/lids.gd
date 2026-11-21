# 画面の切り替わり(v0.3.0): 瞬き。閉じたまぶた(夜の色の上下 2 枚。縁は水色の管)が、真ん中から目の形に開いて新しい画面を見せる。LIDS_MS で終わる。
# 見た目だけで入力は飲まない(新しい画面は最初から押せる。マウスも通す)。点滅を弱める 入なら main が呼ばない。
# 連打で明滅が重ならないよう、前の瞬きから LIDS_GAP_MS 経っていなければ出さない(既定でも 1 秒に 3 回を超えない)。
extends Control

const B := preload("res://core/balance.gd")
const Kit := preload("res://ui/kit.gd")

const STEPS := 24

var view := Rect2(0, 0, 1280, 720)
var start_ms := -100000
var now_ms := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _now() -> int:
	return now_ms if now_ms > 0 else Time.get_ticks_msec()


# 瞬きを始める。出したら真(前の瞬きから間が無ければ出さない)。
func run() -> bool:
	var now := _now()
	if now - start_ms < B.LIDS_GAP_MS:
		return false
	start_ms = now
	queue_redraw()
	return true


# 開ききるまでの割合(0→1)。動いていなければ 1。
func progress() -> float:
	return clampf(float(_now() - start_ms) / B.LIDS_MS, 0.0, 1.0)


func _process(_delta: float) -> void:
	if _now() - start_ms <= B.LIDS_MS + 50:
		queue_redraw()


# まぶたの縁の y(上のまぶたなら side = -1)。開き具合 o(0→1)で、真ん中ほど大きく開く目の形。
func edge_y(x: float, o: float, side: float) -> float:
	var cy := view.get_center().y
	var half := view.size.x / 2.0
	var dx := (x - view.get_center().x) / half
	var gap := o * (view.size.y / 2.0 + 40.0) * (1.0 + 1.2 * (1.0 - dx * dx))  # 両端でも開ききる
	return cy + side * gap


func outer_y(side: float) -> float:
	return view.position.y - 10.0 if side < 0.0 else view.end.y + 10.0


# まぶたの縁の点(左から右へ STEPS + 1 個)。外の線を越えた所は外の線で止める。
func lid_edge(o: float, side: float) -> PackedVector2Array:
	var oy := outer_y(side)
	var edge := PackedVector2Array()
	for i in STEPS + 1:
		var x := view.position.x + view.size.x * i / STEPS
		var y := edge_y(x, o, side)
		edge.append(Vector2(x, maxf(y, oy) if side < 0.0 else minf(y, oy)))
	return edge


# まぶた 1 枚を、縁から外の線までの縦の帯の四角に分けた物。高さの無い帯は入れない。
# 1 枚の多角形(draw_colored_polygon)にすると、開き始め(縁が一直線)と、真ん中の縁が外の線を越えた時(自己交差)に
# Web の描画で三角に割れず「Invalid polygon data, triangulation failed」になっていた(1 回の瞬きに 8 回)→ 割らずに描ける四角(draw_primitive)にする。
func lid_quads(o: float, side: float) -> Array[PackedVector2Array]:
	var oy := outer_y(side)
	var edge := lid_edge(o, side)
	var quads: Array[PackedVector2Array] = []
	for i in range(1, edge.size()):
		var a := edge[i - 1]
		var b := edge[i]
		if absf(a.y - oy) > 0.5 or absf(b.y - oy) > 0.5:
			quads.append(PackedVector2Array([a, b, Vector2(b.x, oy), Vector2(a.x, oy)]))
	return quads


func _draw() -> void:
	var k := progress()
	if k >= 1.0:
		return
	var o := Kit.ease_out(k)
	var col := Color(Kit.C_OUT, 0.97)
	var cols := PackedColorArray([col, col, col, col])
	for side: float in [-1.0, 1.0]:
		for q in lid_quads(o, side):
			draw_primitive(q, cols, PackedVector2Array())
		Kit.neon_line(self, lid_edge(o, side), Color(Kit.C_CYAN, 0.9 * (1.0 - k)), 2.0, 1.0 - k)
