# 遊ぶ場所の描画(仕様書 §9.1・画面設計書 §3・§8)。sim.snapshot() の中身を形で描くだけ(INV-1)。
# 敵の種類は形で分ける(小物 = ひし形、扇 = 縁の太い円と 5 本の線、柱 = 下向きの三角、壁の敵 = 横長の四角。NFR-11)。
# 跳んだ時の残像・キーの枠の光・敵の白い光は、play が時刻(ms)を書き込み、ここで時刻から描く。
extends Control

const B := preload("res://core/balance.gd")
const Sim := preload("res://core/sim.gd")
const Keys := preload("res://core/keys.gd")
const Kit := preload("res://ui/kit.gd")

const KEY_BOX := 80.0
const SHIP_W := 28.0
const RING_R := 30.0
const SHOT_LEN := 16.0

var snap: Dictionary = {}
var reduce_flash := false
var bare := false  # 背景と外側を描かない(タイトルの薄い盤)
var key_glow_at: Array[int] = []
var hit_at := {}  # 敵の id → 白く光らせた時刻
var ghost_key := -1
var ghost_at := -100000
var ring_glow_at := -100000
var now_ms := 0  # 描く時刻(テストが固定できるように持つ)
var draws := 0  # 描いた回数(smoke が読む)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in Keys.COUNT:
		key_glow_at.append(-100000)


# タイトルに薄く出す盤(自機は F)。
static func title_snap() -> Dictionary:
	var k := B.START_KEY
	return {"key": k, "x": Keys.x_of(k), "y": Keys.y_of(k), "power": 0, "strength": 1, "cooldown": 0, "invuln": 0,
		"enemies": [], "bx": PackedFloat64Array(), "by": PackedFloat64Array(), "walls": [], "shot_x": PackedFloat64Array(),
		"shot_y": PackedFloat64Array(), "shot_p": PackedInt32Array()}


func _draw() -> void:
	draws += 1
	if snap.is_empty():
		return
	var now := now_ms if now_ms > 0 else Time.get_ticks_msec()
	if not bare:
		draw_rect(Rect2(0, 0, B.FIELD_LEFT, 720), Kit.C_OUT)
		draw_rect(Rect2(B.FIELD_RIGHT, 0, 1280 - B.FIELD_RIGHT, 720), Kit.C_OUT)
	_lasers()
	_keys(now)
	_walls()
	for e: Dictionary in snap["enemies"]:
		_enemy(e, now)
	_shots()
	_bullets()
	_ship(now)


func _keys(now: int) -> void:
	var f := Kit.font(700)
	var cur: int = snap["key"]
	for k in Keys.COUNT:
		var c := Vector2(Keys.x_of(k), Keys.y_of(k))
		var r := Rect2(c - Vector2(KEY_BOX, KEY_BOX) / 2.0, Vector2(KEY_BOX, KEY_BOX))
		var a := 0.8 if k == cur else 0.35
		var g := now - key_glow_at[k]
		var width := 1.0
		if g >= 0 and g < B.KEY_GLOW_MS:
			a = 1.0
			width = 3.0
		_round_rect(r, Color(Kit.C_KEY_EDGE, a), width)
		draw_string(f, Vector2(r.position.x + 8, r.position.y + 24), Keys.LABELS[k], HORIZONTAL_ALIGNMENT_LEFT, -1, 20,
			Color(Kit.C_KEY_EDGE, a))


# 角の丸い四角の線(角は 8 px)。
func _round_rect(r: Rect2, color: Color, width: float) -> void:
	var rad := 8.0
	var p := r.position
	var s := r.size
	draw_line(p + Vector2(rad, 0), p + Vector2(s.x - rad, 0), color, width, true)
	draw_line(p + Vector2(rad, s.y), p + Vector2(s.x - rad, s.y), color, width, true)
	draw_line(p + Vector2(0, rad), p + Vector2(0, s.y - rad), color, width, true)
	draw_line(p + Vector2(s.x, rad), p + Vector2(s.x, s.y - rad), color, width, true)
	draw_arc(p + Vector2(rad, rad), rad, PI, PI * 1.5, 6, color, width, true)
	draw_arc(p + Vector2(s.x - rad, rad), rad, PI * 1.5, TAU, 6, color, width, true)
	draw_arc(p + Vector2(s.x - rad, s.y - rad), rad, 0, PI * 0.5, 6, color, width, true)
	draw_arc(p + Vector2(rad, s.y - rad), rad, PI * 0.5, PI, 6, color, width, true)


func _lasers() -> void:
	for e: Dictionary in snap["enemies"]:
		if int(e["kind"]) != Sim.PILLAR:
			continue
		var x: float = e["x"]
		var y0: float = e["y"]
		var half := B.LASER_W / 2.0
		match int(e["lp"]):
			Sim.L_WARN:
				for ex: float in [x - half, x + half]:
					draw_dashed_line(Vector2(ex, y0), Vector2(ex, B.FIELD_BOTTOM), Kit.C_PILLAR, 2.0, 10.0)
			Sim.L_FIRE:
				var a := B.REDUCED_FLASH_ALPHA if reduce_flash else 0.65
				draw_rect(Rect2(x - half, y0, B.LASER_W, B.FIELD_BOTTOM - y0), Color(Kit.C_LASER, a))


func _walls() -> void:
	var half := B.WALL_GAP / 2.0
	for w: Dictionary in snap["walls"]:
		var y: float = w["y"]
		var gx: float = w["gx"]
		var l := minf(gx - half, B.FIELD_RIGHT)
		var r := maxf(gx + half, B.FIELD_LEFT)
		if l > B.FIELD_LEFT:
			draw_rect(Rect2(B.FIELD_LEFT, y, l - B.FIELD_LEFT, B.WALL_H), Kit.C_WALLER)
			draw_line(Vector2(l, y - 8), Vector2(l, y + B.WALL_H + 8), Kit.C_WALLER, 2.0)
		if r < B.FIELD_RIGHT:
			draw_rect(Rect2(r, y, B.FIELD_RIGHT - r, B.WALL_H), Kit.C_WALLER)
			draw_line(Vector2(r, y - 8), Vector2(r, y + B.WALL_H + 8), Kit.C_WALLER, 2.0)


func _enemy(e: Dictionary, now: int) -> void:
	var kind: int = e["kind"]
	var c := Vector2(float(e["x"]), float(e["y"]))
	var col: Color = Kit.ENEMY_COLORS[kind]
	var h := now - int(hit_at.get(e["id"], -100000))
	if h >= 0 and h < B.SHOT_HIT_MS:
		col = Kit.C_WHITE
	# 体力が減ると縁が細くなる
	var w := 1.0 + 3.0 * clampf(float(e["hp"]) / float(B.ENEMY_HP[kind]), 0.0, 1.0)
	match kind:
		Sim.SMALL:
			var pts := PackedVector2Array([c + Vector2(0, -16), c + Vector2(16, 0), c + Vector2(0, 16), c + Vector2(-16, 0), c + Vector2(0, -16)])
			draw_colored_polygon(pts.slice(0, 4), Color(col, 0.35))
			draw_polyline(pts, col, w, true)
		Sim.FAN:
			draw_arc(c, 24.0 - w / 2.0, 0.0, TAU, 32, col, w + 2.0, true)
			for d: float in [-60.0, -30.0, 0.0, 30.0, 60.0]:
				var v := Vector2.DOWN.rotated(deg_to_rad(d))
				draw_line(c + v * 26.0, c + v * 36.0, col, 2.0, true)
		Sim.PILLAR:
			var pts := PackedVector2Array([c + Vector2(-22, -14), c + Vector2(22, -14), c + Vector2(0, 22), c + Vector2(-22, -14)])
			draw_colored_polygon(pts.slice(0, 3), Color(col, 0.35))
			draw_polyline(pts, col, w, true)
		Sim.WALLER:
			var r := Rect2(c - Vector2(32, 14), Vector2(64, 28))
			draw_rect(r, Color(col, 0.35))
			draw_rect(r, col, false, w)


func _bullets() -> void:
	var bx: PackedFloat64Array = snap["bx"]
	var by: PackedFloat64Array = snap["by"]
	for i in bx.size():
		var p := Vector2(bx[i], by[i])
		draw_circle(p, B.BULLET_R, Kit.C_WHITE)
		draw_circle(p, B.BULLET_R - 2.0, Kit.C_BULLET)


func _shots() -> void:
	var sx: PackedFloat64Array = snap["shot_x"]
	var sy: PackedFloat64Array = snap["shot_y"]
	var sp: PackedInt32Array = snap["shot_p"]
	for i in sx.size():
		draw_line(Vector2(sx[i], sy[i]), Vector2(sx[i], sy[i] + SHOT_LEN), Kit.C_SHOT, 2.0 * sp[i])


func _ship(now: int) -> void:
	var c := Vector2(float(snap["x"]), float(snap["y"]))
	var g := now - ghost_at
	if ghost_key >= 0 and g >= 0 and g < B.GHOST_MS:
		_triangle(Vector2(Keys.x_of(ghost_key), Keys.y_of(ghost_key)), Color(Kit.C_SHIP, 0.5 * (1.0 - float(g) / B.GHOST_MS)))
	var invuln: int = snap["invuln"]
	var visible_now := invuln <= 0 or (now / B.BLINK_INVULN_MS) % 2 == 0
	var power: int = snap["power"]
	var glow := now - ring_glow_at
	var ring_c := Kit.C_WHITE if glow >= 0 and glow < B.RING_GLOW_MS else Kit.C_SHIP
	draw_arc(c, RING_R, 0.0, TAU, 40, Color(Kit.C_SHIP, 0.15), 2.0, true)
	if power > 0:
		var ring_w := 2.0 + 1.5 * (int(snap["strength"]) - 1)
		draw_arc(c, RING_R, -PI / 2.0, -PI / 2.0 + TAU * power / B.POWER_MAX, 40, ring_c, ring_w, true)
	var cd: int = snap["cooldown"]
	if cd > 0:
		draw_arc(c, RING_R - 6.0, -PI / 2.0, -PI / 2.0 + TAU * cd / B.BLINK_COOLDOWN, 24, Color(Kit.C_TEXT, 0.7), 1.0, true)
	if visible_now:
		_triangle(c, Kit.C_SHIP)
	draw_circle(c, B.SHIP_R, Kit.C_WHITE)  # 当たりの点は常に見せる


func _triangle(c: Vector2, col: Color) -> void:
	var h := SHIP_W * 0.9
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -h * 0.66), c + Vector2(SHIP_W / 2.0, h * 0.34), c + Vector2(-SHIP_W / 2.0, h * 0.34)]), col)
