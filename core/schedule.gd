# 敵の並びを種から作る(仕様書 §9.7・D-11・INV-3)。並び(時刻・種類・出る x・止まる高さ・列)は種だけで決まり、操作では変わらない。
# 波 1〜4 は教える順の表のとおり(INV-6)。1 体ぶんは 出る時刻 → 出る x → 止まる高さ(小物)→ 列(柱・壁)の順に引く。
extends RefCounted

const B := preload("res://core/balance.gd")
const Rng := preload("res://core/rng.gd")
const Keys := preload("res://core/keys.gd")

const SMALL := 0
const FAN := 1
const PILLAR := 2
const WALLER := 3

# 1 体ぶん: { t(ステージの tick), kind, x, stop_y, col }。t の小さい順(同じ時刻は引いた順)
var plan: Array = []
var _rng: Rng


# 仕様書の schedule.build(seed) にあたる(Schedule.new(seed) で作る)。
func _init(p_seed: int = 1) -> void:
	_rng = Rng.new(p_seed)
	for w in range(1, B.WAVES + 1):
		var wave: Array = []
		match w:
			1:
				for i in 2:
					wave.append(_fixed(SMALL, B.TEACH_T[i], float(B.TEACH_X[i]), float(B.TEACH_STOP_Y), -1))
				for i in 3:
					wave.append(_pick(SMALL, B.TEACH_LATE_T + _rng.next_int(B.TEACH_LATE_SPAN)))
			2:
				_add(wave, SMALL, 8)
				wave.append(_pick(FAN, B.TEACH_FAN_T))
			3:
				_add(wave, SMALL, 6)
				wave.append(_fixed(PILLAR, B.TEACH_PILLAR_T, 0.0, B.PILLAR_STOP_Y, B.TEACH_PILLAR_COL))
			4:
				_add(wave, SMALL, 6)
				wave.append(_pick(WALLER, B.TEACH_WALL_T))
			5:
				_add(wave, SMALL, 8)
				_add(wave, FAN, 1)
				_add(wave, PILLAR, 1)
			6:
				_add(wave, SMALL, 8)
				_add(wave, FAN, 1)
				_add(wave, WALLER, 1)
			_:
				var budget := B.BUDGET_BASE + B.BUDGET_STEP * (w - 7)
				while budget > 0:
					var r := _rng.next_int(10)
					var kind := SMALL if r <= 4 else (FAN if r <= 6 else (PILLAR if r <= 8 else WALLER))
					if int(B.BUDGET_COST[kind]) > budget:
						kind = SMALL
					budget -= int(B.BUDGET_COST[kind])
					wave.append(_pick(kind, _rng.next_int(B.SPAWN_T_SPAN)))
		# 出る時刻の小さい順(同じ時刻は引いた順。sort_custom は安定でないので、引いた順を鍵に入れる)
		for i in wave.size():
			wave[i]["order"] = i
		wave.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return a["t"] < b["t"] or (a["t"] == b["t"] and a["order"] < b["order"]))
		for e: Dictionary in wave:
			e["t"] = int(e["t"]) + (w - 1) * B.WAVE_TICKS
			e.erase("order")
			plan.append(e)


func _add(wave: Array, kind: int, n: int) -> void:
	for i in n:
		wave.append(_pick(kind, _rng.next_int(B.SPAWN_T_SPAN)))


# 時刻が決まった 1 体。残り(出る x・止まる高さ・列)を種類に応じて引く。
func _pick(kind: int, t: int) -> Dictionary:
	var x := 0.0
	var stop_y := 0.0
	var col := -1
	if kind != PILLAR:
		x = float(B.SPAWN_X_FROM + _rng.next_int(B.SPAWN_X_SPAN))
	if kind == SMALL:
		stop_y = float(B.STOP_Y_FROM + _rng.next_int(B.STOP_Y_SPAN))
	elif kind == FAN:
		stop_y = B.FAN_STOP_Y
	elif kind == PILLAR:
		stop_y = B.PILLAR_STOP_Y
	else:
		stop_y = B.WALLER_STOP_Y
	if kind == PILLAR or kind == WALLER:
		col = _rng.next_int(10)
	return _fixed(kind, t, x, stop_y, col)


# 柱の x は列の x(中の段のキーの x)。
static func _fixed(kind: int, t: int, x: float, stop_y: float, col: int) -> Dictionary:
	return {"t": t, "kind": kind, "x": Keys.column_x(col) if kind == PILLAR else x, "stop_y": stop_y, "col": col}
