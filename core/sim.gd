# 1 回のプレイの全状態と step()(仕様書 §9.3〜§9.10)。跳ぶ・力・撃つ・敵・弾・当たり・点数・波はここにだけ書く(INV-1)。
# 入力はキーの番号(0〜29)の「押す」だけ(INV-5)。1 step = 1/120 秒。ui は events() と snapshot() を読んで描くだけ。
# 位置と速さは float の x・y を別々に持つ(§9.1)。速さは 1 tick あたりの px に直して持つ。
extends RefCounted

const B := preload("res://core/balance.gd")
const Keys := preload("res://core/keys.gd")
const Dirs := preload("res://core/dirs.gd")
const Schedule := preload("res://core/schedule.gd")
const Score := preload("res://core/score.gd")

const MODE_DAILY := 0
const MODE_PRACTICE := 1
const SMALL := Schedule.SMALL
const FAN := Schedule.FAN
const PILLAR := Schedule.PILLAR
const WALLER := Schedule.WALLER
# 敵の動きの段
const DESCEND := 0
const ACT := 1
const RETURN := 2
# 柱の光線の段
const L_NONE := -1
const L_WARN := 0
const L_FIRE := 1
const L_REST := 2
# 終わった理由
const OVER_LIVES := 0
const OVER_CLEAR := 1

var mode := MODE_DAILY
var seed_value := 1
var sched: Schedule
var tick := 0
var key := B.START_KEY  # 自機のいる場所(0〜29。INV-4)
var ship_x := 0.0
var ship_y := 0.0
var power := 0
var cooldown := 0
var invuln := 0
var pending := -1  # 覚えている次の跳び先
var lives := B.LIVES
var score := 0
var kills := 0
var grazes := 0
var blinks := 0
var over := false
var reason := -1
var bonus := 0
# 敵: { id, kind, x, y, hp, r, stop_y, col, phase, t, shots, lp, lt, round }。出た順(番号の小さい順)
var enemies: Array[Dictionary] = []
# 敵の弾(並んだ配列。grazed は 1 ならかすり済み)
var bx := PackedFloat64Array()
var by := PackedFloat64Array()
var bvx := PackedFloat64Array()
var bvy := PackedFloat64Array()
var bgrazed := PackedByteArray()
var bborn := PackedInt32Array()  # 出た tick(bot の反応の遅れに使う)
# 壁: { y(上の縁), gx(隙間の中心), vy, born(落ちた tick) }
var walls: Array[Dictionary] = []
# 自機の弾
var shot_x := PackedFloat64Array()
var shot_y := PackedFloat64Array()
var shot_p := PackedInt32Array()

var _plan_i := 0
var _next_id := 0
var _queue: Array[int] = []
var _events: Array = []


# p_mode: 0 = 今日のステージ、1 = 練習。並びは種だけで決まる(FR-21)。
func _init(p_seed: int = 1, p_mode: int = MODE_DAILY) -> void:
	seed_value = p_seed
	mode = p_mode
	sched = Schedule.new(p_seed)
	ship_x = Keys.x_of(key)
	ship_y = Keys.y_of(key)


func queue_press(k: int) -> void:
	if not over and k >= 0 and k < Keys.COUNT:
		_queue.append(k)


# 一時停止に入る時に ui が呼ぶ(FR-25)。
func clear_pending() -> void:
	pending = -1
	_queue.clear()


func events() -> Array:
	return _events


func is_over() -> bool:
	return over


@warning_ignore("integer_division")
static func strength_of(p: int) -> int:
	return 1 + p / B.POWER_STEP


@warning_ignore("integer_division")
func wave() -> int:
	return mini(tick / B.WAVE_TICKS + 1, B.WAVES)


# 弾の速さの倍率 m(w)。波 1 だけは TEACH_BULLET_RATE を掛ける(§9.6)。
static func speed_rate(w: int) -> float:
	var m := 1.0 + B.WAVE_SPEED_STEP * (w - 1)
	return m * B.TEACH_BULLET_RATE if w == 1 else m


func step() -> void:
	_events = []
	# 1
	if over:
		_queue.clear()
		return
	# 2
	cooldown = maxi(cooldown - 1, 0)
	invuln = maxi(invuln - 1, 0)
	# 3. 押すを来た順に(後の物が前の物を置き換える。E-4)
	for k in _queue:
		pending = k
	_queue.clear()
	# 4. 跳ぶ
	var blinked := false
	if cooldown == 0 and pending >= 0:
		blinked = _blink(pending)
	# 5. 力
	if not blinked:
		var before := strength_of(power)
		power = mini(power + B.POWER_RATE, B.POWER_MAX)
		var after := strength_of(power)
		if after > before:
			_events.append({"type": "power_up", "strength": after})
	# 6. 撃つ
	if tick % B.FIRE_INTERVAL == 0:
		shot_x.append(ship_x)
		shot_y.append(ship_y)
		shot_p.append(strength_of(power))
	# 7. 波の始めと、予定の敵
	if tick % B.WAVE_TICKS == 0:
		_events.append({"type": "wave_start", "wave": wave()})
	while _plan_i < sched.plan.size() and int(sched.plan[_plan_i]["t"]) <= tick and enemies.size() < B.ENEMY_CAP:
		_spawn(sched.plan[_plan_i])
		_plan_i += 1
	# 8. 敵を動かし、撃たせる。柱と壁の状態を進める
	for e in enemies:
		_enemy_step(e)
	# 9. 自機の弾・敵の弾・壁を動かす
	var sv := B.SHOT_SPEED / B.TICK_HZ
	for i in shot_y.size():
		shot_y[i] -= sv
	for i in bx.size():
		bx[i] += bvx[i]
		by[i] += bvy[i]
	for w in walls:
		w["y"] = float(w["y"]) + float(w["vy"])
	# 10. 自機の弾の当たり
	_shots_vs_enemies()
	# 11. 自機の当たり
	if invuln == 0 and _ship_hit():
		_on_hit()
		if lives <= 0:
			_finish(OVER_LIVES)
			return
	# 12. かすり
	if invuln == 0:
		_graze()
	# 13. 外へ出た物と、帰り終わった物を消す
	_cleanup()
	# 14. tick
	tick += 1
	if tick >= B.STAGE_TICKS:
		bonus = Score.clear_bonus(lives)
		score += bonus
		_finish(OVER_CLEAR)


# §9.4。跳んだら真。
func _blink(k: int) -> bool:
	pending = -1
	if k == key:
		return false  # E-2: 跳ばない。力も減らない
	var from := key
	key = k
	ship_x = Keys.x_of(k)
	ship_y = Keys.y_of(k)
	cooldown = B.BLINK_COOLDOWN
	power = maxi(0, power - B.BLINK_COST)
	blinks += 1
	_events.append({"type": "blink", "from": from, "to": k})
	return true


func _spawn(p: Dictionary) -> void:
	var kind: int = p["kind"]
	_next_id += 1
	enemies.append({"id": _next_id, "kind": kind, "x": float(p["x"]), "y": B.ENEMY_SPAWN_Y, "hp": int(B.ENEMY_HP[kind]),
		"r": float(B.ENEMY_R[kind]), "stop_y": float(p["stop_y"]), "col": int(p["col"]), "phase": DESCEND, "t": 0, "shots": 0,
		"lp": L_NONE, "lt": 0, "round": 0})


func _enemy_step(e: Dictionary) -> void:
	var v := B.ENEMY_SPEED / B.TICK_HZ
	match int(e["phase"]):
		DESCEND:
			e["y"] = float(e["y"]) + v
			if float(e["y"]) >= float(e["stop_y"]):
				e["y"] = e["stop_y"]
				e["phase"] = ACT
				e["t"] = 0
				_arrive(e)
		ACT:
			e["t"] = int(e["t"]) + 1
			_act(e)
		RETURN:
			e["y"] = float(e["y"]) - v


# 着いた step(§9.6)。
func _arrive(e: Dictionary) -> void:
	match int(e["kind"]):
		SMALL:
			_aimed(e, [0])
		PILLAR:
			e["lp"] = L_WARN
			e["lt"] = B.LASER_WARN
			_events.append({"type": "laser_warn", "x": e["x"], "id": e["id"]})


# 着いた後の 1 step(t は着いてからの tick)。
func _act(e: Dictionary) -> void:
	var t: int = e["t"]
	match int(e["kind"]):
		SMALL:
			if t == B.SMALL_SECOND_SHOT and wave() >= B.SMALL_SECOND_SHOT_WAVE:
				_aimed(e, [0])
			if t >= B.SMALL_STAY:
				e["phase"] = RETURN
		FAN:
			if t % B.FAN_EVERY == 0:
				_aimed(e, B.FAN_DEG)
				e["shots"] = int(e["shots"]) + 1
				if int(e["shots"]) >= B.FAN_SHOTS:
					e["phase"] = RETURN
		PILLAR:
			e["lt"] = int(e["lt"]) - 1
			if int(e["lt"]) > 0:
				return
			match int(e["lp"]):
				L_WARN:
					e["lp"] = L_FIRE
					e["lt"] = B.LASER_FIRE
					_events.append({"type": "laser_fire", "x": e["x"], "id": e["id"]})
				L_FIRE:
					e["lp"] = L_REST
					e["lt"] = B.LASER_REST
				L_REST:
					e["round"] = int(e["round"]) + 1
					if int(e["round"]) >= B.LASER_ROUNDS:
						e["lp"] = L_NONE
						e["phase"] = RETURN
					else:
						e["lp"] = L_WARN
						e["lt"] = B.LASER_WARN
						_events.append({"type": "laser_warn", "x": e["x"], "id": e["id"]})
		WALLER:
			if t % B.WALL_EVERY == 0:
				var gx := Keys.column_x(int(e["col"]))
				var y := float(e["y"]) + B.WALL_OFFSET_Y
				walls.append({"y": y, "gx": gx, "vy": B.WALL_SPEED * speed_rate(wave()) / B.TICK_HZ, "born": tick})
				_events.append({"type": "wall_drop", "gx": gx, "y": y})
				e["shots"] = int(e["shots"]) + 1
				if int(e["shots"]) >= B.WALL_COUNT:
					e["phase"] = RETURN


# 自機へ向けた向きと、そこから degs 度回した向きに 1 発ずつ。上限に届いたら出さない(§9.10・E-9)。
func _aimed(e: Dictionary, degs: Array) -> void:
	var ex: float = e["x"]
	var ey: float = e["y"]
	var dx := ship_x - ex
	var dy := ship_y - ey
	var d := sqrt(dx * dx + dy * dy)
	if d > 0.0:
		dx /= d
		dy /= d
	else:
		dx = 0.0
		dy = 1.0
	var sp := B.BULLET_SPEED * speed_rate(wave()) / B.TICK_HZ
	for deg: int in degs:
		if bx.size() >= B.BULLET_CAP:
			return
		var r: Array[float] = Dirs.rotate(dx, dy, deg)
		add_bullet(ex, ey, r[0] * sp, r[1] * sp)


# 敵の弾を 1 発足す(テストも使う)。
func add_bullet(x: float, y: float, vx: float, vy: float) -> void:
	bx.append(x)
	by.append(y)
	bvx.append(vx)
	bvy.append(vy)
	bgrazed.append(0)
	bborn.append(tick)


func _shots_vs_enemies() -> void:
	var keep := PackedInt32Array()
	for i in shot_x.size():
		var used := false
		for e in enemies:
			if int(e["hp"]) <= 0:
				continue
			var dx: float = shot_x[i] - float(e["x"])
			var dy: float = shot_y[i] - float(e["y"])
			var rr: float = B.SHOT_R + float(e["r"])
			if dx * dx + dy * dy <= rr * rr:
				e["hp"] = int(e["hp"]) - shot_p[i]
				_events.append({"type": "shot_hit", "id": e["id"], "x": e["x"], "y": e["y"]})
				used = true
				break
		if not used:
			keep.append(i)
	if keep.size() != shot_x.size():
		var nx := PackedFloat64Array()
		var ny := PackedFloat64Array()
		var np := PackedInt32Array()
		for i in keep:
			nx.append(shot_x[i])
			ny.append(shot_y[i])
			np.append(shot_p[i])
		shot_x = nx
		shot_y = ny
		shot_p = np
	var alive: Array[Dictionary] = []
	for e in enemies:
		if int(e["hp"]) > 0:
			alive.append(e)
			continue
		var pts: int = B.ENEMY_POINTS[int(e["kind"])]
		score += pts
		kills += 1
		_events.append({"type": "kill", "id": e["id"], "kind": e["kind"], "x": e["x"], "y": e["y"], "points": pts})
	if alive.size() != enemies.size():
		enemies = alive


# 円と帯の重なり(§9.10): 帯の中で自機に一番近い点と自機の距離の 2 乗 ≤ SHIP_R の 2 乗。
static func circle_rect(cx: float, cy: float, r: float, x0: float, y0: float, x1: float, y1: float) -> bool:
	if x1 <= x0 or y1 <= y0:
		return false
	var nx := clampf(cx, x0, x1)
	var ny := clampf(cy, y0, y1)
	return (cx - nx) * (cx - nx) + (cy - ny) * (cy - ny) <= r * r


# 壁が (cx, cy) の半径 r の円に当たるか(隙間を除く)。
static func wall_hits(w: Dictionary, cx: float, cy: float, r: float) -> bool:
	var y0: float = w["y"]
	var gx: float = w["gx"]
	var half := B.WALL_GAP / 2.0
	return circle_rect(cx, cy, r, B.FIELD_LEFT, y0, minf(gx - half, B.FIELD_RIGHT), y0 + B.WALL_H) \
		or circle_rect(cx, cy, r, maxf(gx + half, B.FIELD_LEFT), y0, B.FIELD_RIGHT, y0 + B.WALL_H)


# 撃っている柱の光線が (cx, cy) の半径 r の円に当たるか。
static func laser_hits(e: Dictionary, cx: float, cy: float, r: float) -> bool:
	var x: float = e["x"]
	return circle_rect(cx, cy, r, x - B.LASER_W / 2.0, float(e["y"]), x + B.LASER_W / 2.0, B.FIELD_BOTTOM)


func _ship_hit() -> bool:
	for i in bx.size():
		var dx: float = bx[i] - ship_x
		var dy: float = by[i] - ship_y
		var rr: float = B.SHIP_R + B.BULLET_R
		if dx * dx + dy * dy <= rr * rr:
			return true
	for e in enemies:
		if int(e["kind"]) == PILLAR and int(e["lp"]) == L_FIRE and laser_hits(e, ship_x, ship_y, B.SHIP_R):
			return true
	for w in walls:
		if wall_hits(w, ship_x, ship_y, B.SHIP_R):
			return true
	return false


# 当たった時(§9.10・D-9)。
func _on_hit() -> void:
	lives -= 1
	bx.clear()
	by.clear()
	bvx.clear()
	bvy.clear()
	bgrazed.clear()
	bborn.clear()
	walls.clear()
	for e in enemies:
		if int(e["lp"]) == L_FIRE:
			e["lp"] = L_REST
			e["lt"] = B.LASER_REST
	invuln = B.INVULN_TICKS
	power = 0
	pending = -1
	_events.append({"type": "hit", "lives": lives, "x": ship_x, "y": ship_y})


func _graze() -> void:
	var rr: float = B.GRAZE_R + B.BULLET_R
	for i in bx.size():
		if bgrazed[i] != 0:
			continue
		var dx: float = bx[i] - ship_x
		var dy: float = by[i] - ship_y
		if dx * dx + dy * dy <= rr * rr:
			bgrazed[i] = 1
			grazes += 1
			score += B.GRAZE_POINTS
			_events.append({"type": "graze", "x": bx[i], "y": by[i]})


func _cleanup() -> void:
	var n := bx.size()
	var j := 0
	for i in n:
		var x: float = bx[i]
		var y: float = by[i]
		if x < B.FIELD_LEFT or x > B.FIELD_RIGHT or y < B.FIELD_TOP or y > B.FIELD_BOTTOM:
			continue
		bx[j] = x
		by[j] = y
		bvx[j] = bvx[i]
		bvy[j] = bvy[i]
		bgrazed[j] = bgrazed[i]
		bborn[j] = bborn[i]
		j += 1
	if j != n:
		bx.resize(j)
		by.resize(j)
		bvx.resize(j)
		bvy.resize(j)
		bgrazed.resize(j)
		bborn.resize(j)
	j = 0
	n = shot_y.size()
	for i in n:
		if shot_y[i] < B.FIELD_TOP:
			continue
		shot_x[j] = shot_x[i]
		shot_y[j] = shot_y[i]
		shot_p[j] = shot_p[i]
		j += 1
	if j != n:
		shot_x.resize(j)
		shot_y.resize(j)
		shot_p.resize(j)
	for i in range(walls.size() - 1, -1, -1):
		if float(walls[i]["y"]) > B.FIELD_BOTTOM:
			walls.remove_at(i)
	for i in range(enemies.size() - 1, -1, -1):
		var e := enemies[i]
		if int(e["phase"]) == RETURN and float(e["y"]) < B.ENEMY_SPAWN_Y:
			enemies.remove_at(i)


func _finish(why: int) -> void:
	over = true
	reason = why
	_queue.clear()
	pending = -1
	_events.append({"type": "over", "reason": why, "bonus": bonus})


# 描画用。配列は sim の物をそのまま渡す(ui は書き換えない)。
func snapshot() -> Dictionary:
	return {"key": key, "x": ship_x, "y": ship_y, "power": power, "strength": strength_of(power), "cooldown": cooldown,
		"invuln": invuln, "pending": pending, "lives": lives, "score": score, "wave": wave(), "tick": tick,
		"enemies": enemies, "bx": bx, "by": by, "walls": walls, "shot_x": shot_x, "shot_y": shot_y, "shot_p": shot_p,
		"kills": kills, "grazes": grazes, "blinks": blinks, "over": over, "reason": reason}


func result() -> Dictionary:
	return {"score": score, "clear": reason == OVER_CLEAR, "lives": lives, "wave": wave(), "kills": kills, "grazes": grazes,
		"blinks": blinks, "reason": reason, "ticks": tick}
