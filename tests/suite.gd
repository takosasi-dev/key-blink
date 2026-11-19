# テストの土台。ok / eq で確かめ、失敗は errors にたまる。敵の無い場面を作って進める道具も持つ。
# 各テストは最後に true を返す(途中で止まったことを見分けるため)。
extends RefCounted

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Sim := preload("res://core/sim.gd")
const Keys := preload("res://core/keys.gd")

var errors: Array = []


func ok(cond: bool, msg: String) -> void:
	if not cond:
		errors.append(msg)


func eq(got: Variant, want: Variant, msg: String) -> void:
	if typeof(got) != typeof(want) or got != want:
		errors.append("%s: %s のはずが %s" % [msg, want, got])


# 予定の敵を出さない場面(自機は F)。
static func empty_sim(p_seed: int = 1) -> Sim:
	var sim := Sim.new(p_seed, Sim.MODE_PRACTICE)
	sim.sched.plan.clear()
	return sim


# 次の step で止まる高さに着く敵を 1 体置く(倒れないように体力を大きくする)。
static func put_enemy(sim: Sim, kind: int, x: float, col: int = -1) -> Dictionary:
	var stop: float = [150.0, B.FAN_STOP_Y, B.PILLAR_STOP_Y, B.WALLER_STOP_Y][kind]
	sim._spawn({"kind": kind, "x": Keys.column_x(col) if kind == Sim.PILLAR else x, "stop_y": stop, "col": col})
	var e: Dictionary = sim.enemies[-1]
	e["y"] = stop - 0.5
	e["hp"] = 1000000
	return e


static func run(sim: Sim, ticks: int) -> Array:
	var ev: Array = []
	for k in ticks:
		sim.step()
		ev.append_array(sim.events())
	return ev


static func press(sim: Sim, k: int) -> Array:
	sim.queue_press(k)
	return run(sim, 1)


static func of_type(ev: Array, t: String) -> Array:
	return ev.filter(func(e: Dictionary) -> bool: return e["type"] == t)


static func idx(label: String) -> int:
	return Keys.LABELS.find(label)
