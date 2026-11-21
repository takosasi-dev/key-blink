# 遊ぶ場所の描画(仕様書 §9.1・画面設計書 §3・§8)。sim.snapshot() の中身を形で描くだけ(INV-1)。
# 敵の種類は形で分ける(小物 = ひし形、扇 = 縁の太い円と 5 本の線、柱 = 下向きの三角、壁の敵 = 横長の四角。NFR-11)。
# 跳んだ時の残像・キーの枠の光・敵の白い光・当たった所の輪は、play が時刻(ms)を書き込み、ここで時刻から描く。
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
var line_k := 1.0  # 線の太さの倍率(タイトルの縮めた盤で線が消えないように)
var key_glow_at: Array[int] = []
var hit_at := {}  # 敵の id → 白く光らせた時刻
var ghost_key := -1
var ghost_to := -1
var ghost_at := -100000
var ring_glow_at := -100000
var hit_mark_at := -100000
var hit_mark := Vector2.ZERO
var now_ms := 0  # 描く時刻(テストが固定できるように持つ)
var draws := 0  # 描いた回数(smoke が読む)
var key_state: Array[int] = []  # 最後に描いたキーの印(0 = 無し、1 = 光線が当たる、2 = 壁の隙間。テストが読む)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in Keys.COUNT:
		key_glow_at.append(-100000)
		key_state.append(0)


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
		# 遊ぶ場所の外は 1 段暗く(窓の余りの部分まで)
		draw_rect(Rect2(-2000, -2000, 2000 + B.FIELD_LEFT, 4720), Kit.C_OUT)
		draw_rect(Rect2(B.FIELD_RIGHT, -2000, 2000 + 1280 - B.FIELD_RIGHT, 4720), Kit.C_OUT)
	_lasers()
	_keys(now)
	_walls()
	var ns: PackedInt32Array = snap.get("next_shot", PackedInt32Array())
	var enemies: Array = snap["enemies"]
	for i in enemies.size():
		_enemy(enemies[i], now)
		if i < ns.size() and ns[i] > 0 and ns[i] <= B.TELL_TICKS:
			_tell(enemies[i], ns[i])
	_shots()
	_bullets()
	_ship(now)
	_hit_mark(now)


# キーの枠。光線が当たるキーは柱の色、壁の隙間に入るキーは緑の線にする(枠は線だけ。中は塗らない)。
func _keys(now: int) -> void:
	var f := Kit.font(700)
	var cur: int = snap["key"]
	for k in Keys.COUNT:
		var c := Vector2(Keys.x_of(k), Keys.y_of(k))
		var r := Rect2(c - Vector2(KEY_BOX, KEY_BOX) / 2.0, Vector2(KEY_BOX, KEY_BOX))
		var a := 0.8 if k == cur else 0.35
		var col := Kit.C_KEY_EDGE
		var width := 1.0
		key_state[k] = _key_mark(c)
		if key_state[k] == 1:
			col = Kit.C_PILLAR
			a = maxf(a, 0.9)
			width = 2.0
		elif key_state[k] == 2:
			col = Kit.C_GOOD
			a = maxf(a, 0.6)
			width = 2.0
		var g := now - key_glow_at[k]
		if g >= 0 and g < B.KEY_GLOW_MS:
			a = 1.0
			width = 3.0
		_round_rect(r, Color(col, a), width * line_k)
		draw_string(f, Vector2(r.position.x + 8, r.position.y + 24), Keys.LABELS[k], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(col, a))


# このキーの場所に、予告中・撃っている柱の光線が当たるか(1)、まだ通り過ぎていない壁の隙間に入るか(2)。当たりの式は core のもの。
func _key_mark(c: Vector2) -> int:
	for e: Dictionary in snap["enemies"]:
		if int(e["kind"]) == Sim.PILLAR and int(e["lp"]) in [Sim.L_WARN, Sim.L_FIRE] and Sim.laser_hits(e, c.x, c.y, B.SHIP_R):
			return 1
	# 緑は、まだこの段を通り過ぎていない壁が 1 枚以上あり、その全部の隙間に入る時だけ(隙間の違う 2 枚なら付かない)
	var coming := 0
	for w: Dictionary in snap["walls"]:
		if float(w["y"]) <= c.y + B.SHIP_R:
			coming += 1
			var at_row := {"y": c.y - B.WALL_H / 2.0, "gx": w["gx"]}  # 壁がこの段に来た時
			if Sim.wall_hits(at_row, c.x, c.y, B.SHIP_R):
				return 0
	return 2 if coming > 0 else 0


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


# 柱: 予告は帯の両端の点線と、光線に近づくほど濃くなる薄い塗り。光線は帯。
func _lasers() -> void:
	for e: Dictionary in snap["enemies"]:
		if int(e["kind"]) != Sim.PILLAR:
			continue
		var x: float = e["x"]
		var y0: float = e["y"]
		var half := B.LASER_W / 2.0
		match int(e["lp"]):
			Sim.L_WARN:
				var k := clampf(1.0 - float(e["lt"]) / B.LASER_WARN, 0.0, 1.0)
				var fill: float = lerpf(B.WARN_FILL_ALPHA[0], B.WARN_FILL_ALPHA[1], k)
				draw_rect(Rect2(x - half, y0, B.LASER_W, B.FIELD_BOTTOM - y0), Color(Kit.C_PILLAR, fill))
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
		col = col.lerp(Kit.C_WHITE, 0.35 if reduce_flash else 0.85)  # 点滅を弱める 入なら少し明るくするだけ
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


# 撃つ前の「ため」: 敵のまわりに縮んでいく輪と、撃つ向き(今の自機へ向けた向き。扇は 5 本)の短い線。n は撃つまでの tick。
func _tell(e: Dictionary, n: int) -> void:
	var k := 1.0 - float(n - 1) / B.TELL_TICKS  # 0 → 1(撃つ step で 1)
	var c := Vector2(float(e["x"]), float(e["y"]))
	var er: float = e["r"]
	draw_arc(c, er + 4.0 + 20.0 * (1.0 - k), 0.0, TAU, 32, Color(Kit.C_BULLET, 0.25 + 0.6 * k), 2.0, true)
	var to := Vector2(float(snap["x"]), float(snap["y"])) - c
	var dir := to.normalized() if to.length() > 0.0 else Vector2.DOWN
	var degs: Array = [0] if int(e["kind"]) == Sim.SMALL else B.FAN_DEG
	for d: int in degs:
		var v := dir.rotated(deg_to_rad(d))
		draw_line(c + v * (er + 6.0), c + v * (er + 26.0 + 40.0 * k), Color(Kit.C_BULLET, 0.55 * k), 2.0, true)


# 敵の弾: 縁の白い円と、進む向きの後ろに短い尾(TRAIL_TICKS ぶん)。速い弾の向きが止めた絵でも分かるように。
func _bullets() -> void:
	var bx: PackedFloat64Array = snap["bx"]
	var by: PackedFloat64Array = snap["by"]
	var vx: PackedFloat64Array = snap.get("bvx", PackedFloat64Array())
	var vy: PackedFloat64Array = snap.get("bvy", PackedFloat64Array())
	var tail := vx.size() == bx.size()
	for i in bx.size():
		var p := Vector2(bx[i], by[i])
		if tail:
			var back := p - Vector2(vx[i], vy[i]) * B.TRAIL_TICKS
			draw_line(back, p, Color(Kit.C_BULLET, 0.45), B.BULLET_R * 1.4, true)
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
		var fade := 1.0 - float(g) / B.GHOST_MS
		var from := Vector2(Keys.x_of(ghost_key), Keys.y_of(ghost_key))
		if ghost_to >= 0:
			# 跳んだ筋(一瞬で移ったことが見えるように、元の場所から新しい場所へ細い線)
			draw_line(from, Vector2(Keys.x_of(ghost_to), Keys.y_of(ghost_to)), Color(Kit.C_SHIP, 0.35 * fade), 3.0 * line_k, true)
		_triangle(from, Color(Kit.C_SHIP, 0.5 * fade))
	var invuln: int = snap["invuln"]
	var ship_a := invuln_alpha(invuln, now, reduce_flash)
	var power: int = snap["power"]
	var glow := now - ring_glow_at
	var ring_c := Kit.C_WHITE if glow >= 0 and glow < B.RING_GLOW_MS else Kit.C_SHIP
	draw_arc(c, RING_R, 0.0, TAU, 40, Color(Kit.C_SHIP, 0.15), 2.0 * line_k, true)
	if power > 0:
		var ring_w := 2.0 + 1.5 * (int(snap["strength"]) - 1)
		draw_arc(c, RING_R, -PI / 2.0, -PI / 2.0 + TAU * power / B.POWER_MAX, 40, ring_c, ring_w, true)
	var cd: int = snap["cooldown"]
	if cd > 0:
		draw_arc(c, RING_R - 6.0, -PI / 2.0, -PI / 2.0 + TAU * cd / B.BLINK_COOLDOWN, 24, Color(Kit.C_TEXT, 0.7), 1.0, true)
	_triangle(c, Color(Kit.C_SHIP, ship_a))
	draw_circle(c, B.SHIP_R, Kit.C_WHITE)  # 当たりの点は常に見せる


# 無敵の間の自機の濃さ。INVULN_PULSE_MS で 1 往復するなめらかな濃淡(1 秒に 2 回。消えたり点いたりはしない)。
# 点滅を弱める 入なら INVULN_ALPHA_REDUCED のまま動かさない。v0.3.0 で 100 ms ごとの点滅(1 秒に 5 回)から変えた。
static func invuln_alpha(invuln: int, now: int, p_reduce: bool) -> float:
	if invuln <= 0:
		return 1.0
	if p_reduce:
		return B.INVULN_ALPHA_REDUCED
	return lerpf(B.INVULN_ALPHA[0], B.INVULN_ALPHA[1], Kit.tri(now, B.INVULN_PULSE_MS))


# 当たった所に広がる赤い輪(何に当たったかを目で追えるように)。
func _hit_mark(now: int) -> void:
	var g := now - hit_mark_at
	if g < 0 or g >= B.HIT_MARK_MS:
		return
	var k := float(g) / B.HIT_MARK_MS
	draw_arc(hit_mark, 10.0 + 50.0 * k, 0.0, TAU, 40, Color(Kit.C_BULLET, 1.0 - k), 4.0 * (1.0 - k) + 1.0, true)


func _triangle(c: Vector2, col: Color) -> void:
	var h := SHIP_W * 0.9
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -h * 0.66), c + Vector2(SHIP_W / 2.0, h * 0.34), c + Vector2(-SHIP_W / 2.0, h * 0.34)]), col)
