# 全部の画面の後ろ(v0.3.0): 藍の夜のなめらかな濃淡(上が少し紫)と、下の縁の桃の照り返し。窓の見えている範囲(view)全体に描く。
# rain の間は細い雨の筋がネオンの色で降る(S0・タイトルだけ。遊ぶ画面には出さない)。animate が偽(点滅を弱める 入)なら雨は止まった絵のまま。
extends Control

const B := preload("res://core/balance.gd")
const Kit := preload("res://ui/kit.gd")

const C_TOP := Color("17113A")

var view := Rect2(0, 0, 1280, 720)  # 舞台の座標で見えている範囲(main が入れる)
var rain := false
var animate := false
var now_ms := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if rain and animate:
		queue_redraw()


# i 本目の雨の筋の [x, y, 長さ, 色](舞台の座標)。時刻と番号だけで決まる(乱数を使わない)。
func drop(i: int, now: int) -> Array:
	var h := (i * 2654435761) & 0xFFFFFF
	var x := view.position.x + fmod(float(h % 9973) / 9973.0 * view.size.x + i * 37.0, view.size.x)
	var length := 14.0 + float((h >> 8) % 26)
	var speed := B.RAIN_SPEED * (0.7 + float((h >> 4) % 60) / 100.0)
	var t := float(now) / 1000.0 if animate else 0.0
	var y := view.position.y + fmod(float(h % 7919) / 7919.0 * (view.size.y + 80.0) + t * speed, view.size.y + 80.0) - 40.0
	var col := Kit.C_CYAN if i % 3 != 0 else Kit.C_PINK
	return [x, y, length, Color(col, 0.05 + 0.05 * float(h % 3))]


func _draw() -> void:
	var r := view
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([C_TOP, C_TOP, Kit.C_BG, Kit.C_BG]))
	# 下の縁の照り返し(桃が下から薄くにじむ)
	var glow_top := maxf(r.end.y - 220.0, r.position.y)
	draw_polygon(PackedVector2Array([Vector2(r.position.x, glow_top), Vector2(r.end.x, glow_top), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([Color(Kit.C_PINK, 0.0), Color(Kit.C_PINK, 0.0), Color(Kit.C_PINK, 0.07), Color(Kit.C_PINK, 0.07)]))
	if not rain:
		return
	var now := now_ms if now_ms > 0 else Time.get_ticks_msec()
	for i in B.RAIN_COUNT:
		var d := drop(i, now)
		var p := Vector2(d[0], d[1])
		draw_line(p, p + Vector2(-d[2] * 0.18, d[2]), d[3], 1.5)
