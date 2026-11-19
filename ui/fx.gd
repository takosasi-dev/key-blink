# 遊ぶ場所の上の演出(仕様書 §9.12): 倒した・当たった時の四角の破片(400 ms)、上へ流れる「+400」(600 ms)、かすりの火花(150 ms)。
# 見た目だけで、ゲームの決まりは持たない。時刻(ms)で描き、終わった物は捨てる。数に上限を置く。作りは KeySwat の ui/fx.gd。
extends Control

const B := preload("res://core/balance.gd")
const Kit := preload("res://ui/kit.gd")

var shards: Array = []  # [at, 中心, 向き, 色]
var floats: Array = []  # [at, 位置, 文字]
var sparks: Array = []  # [at, 位置]
var now_ms := 0
var draws := 0  # 描いた回数(smoke が読む)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _now() -> int:
	return now_ms if now_ms > 0 else Time.get_ticks_msec()


func burst(at: Vector2, color: Color) -> void:
	var t := _now()
	for k in B.SHARDS:
		var ang := TAU * k / B.SHARDS + 0.3
		shards.append([t, at, Vector2(cos(ang), sin(ang)), color])
	while shards.size() > B.SHARDS_MAX:
		shards.pop_front()


func float_text(at: Vector2, text: String) -> void:
	floats.append([_now(), at, text])
	while floats.size() > B.FLOATS_MAX:
		floats.pop_front()


func spark(at: Vector2) -> void:
	sparks.append([_now(), at])
	while sparks.size() > B.SPARKS_MAX:
		sparks.pop_front()


func tick() -> void:
	var t := _now()
	shards = shards.filter(func(s: Array) -> bool: return t - int(s[0]) < B.SHARD_MS)
	floats = floats.filter(func(f: Array) -> bool: return t - int(f[0]) < B.FLOAT_MS)
	sparks = sparks.filter(func(s: Array) -> bool: return t - int(s[0]) < B.SPARK_MS)
	queue_redraw()


func _draw() -> void:
	draws += 1
	var t := _now()
	for s: Array in shards:
		var k := float(t - int(s[0])) / B.SHARD_MS
		var p: Vector2 = s[1] + s[2] * (10.0 + 70.0 * k)
		draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), Color(s[3], 1.0 - k))
	for s: Array in sparks:
		var k := float(t - int(s[0])) / B.SPARK_MS
		var p: Vector2 = s[1]
		var r := 4.0 + 8.0 * k
		var c := Color(Kit.C_WARN, 1.0 - k)
		draw_line(p - Vector2(r, 0), p + Vector2(r, 0), c, 2.0)
		draw_line(p - Vector2(0, r), p + Vector2(0, r), c, 2.0)
	for f: Array in floats:
		var k := float(t - int(f[0])) / B.FLOAT_MS
		var p: Vector2 = f[1] - Vector2(100, B.FLOAT_RISE_PX * k)
		draw_string(Kit.font(800), p, f[2], HORIZONTAL_ALIGNMENT_CENTER, 200, 24, Color(Kit.C_TEXT, 1.0 - k * k))
