# 負荷の場面(敵の弾 400・敵 40・壁 2・光線 2)で、1 フレームの時間を測る(NFR-1・撤退基準 R-4)。書き出しには入らない。
# ヘッドレスは描画が空なので、測れるのは step 2 回(60 fps ぶん)と field の _draw のスクリプトの CPU 時間だけ。本物の GPU ではない。
# 実行: python tools/gd.py run res://tools/perf.gd [フレーム数(既定 3600 = 60 秒)]
extends SceneTree

const B := preload("res://core/balance.gd")
const Sim := preload("res://core/sim.gd")
const Keys := preload("res://core/keys.gd")
const Field := preload("res://ui/field.gd")

# _draw の時間を測る field
class TimedField extends Field:
	var last_us := 0

	func _draw() -> void:
		var t0 := Time.get_ticks_usec()
		super._draw()
		last_us = Time.get_ticks_usec() - t0


var sim: Sim
var field: TimedField
var frames := 3600
var n := 0
var step_us := 0
var times: Array[int] = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		frames = int(args[0])
	sim = Sim.new(1, 1)
	sim.sched.plan.clear()
	for k in B.ENEMY_CAP:
		var kind := Sim.PILLAR if k < 2 else Sim.SMALL
		sim._spawn({"kind": kind, "x": 150.0 + k * 25.0 if kind != Sim.PILLAR else Keys.column_x(7 + k), "stop_y": 150.0, "col": 7 + k})
		var e: Dictionary = sim.enemies[-1]
		e["y"] = 150.0
		e["phase"] = Sim.ACT
		e["hp"] = 1000000000
		if kind == Sim.PILLAR:
			e["lp"] = Sim.L_FIRE
			e["lt"] = 1000000000
	for k in 2:
		sim.walls.append({"y": 300.0 + k * 40.0, "gx": Keys.column_x(3), "vy": 0.0, "born": 0})
	for k in B.BULLET_CAP:
		sim.add_bullet(140.0 + (k % 40) * 25.0, 180.0 + (k / 40) * 20.0, 0.0, 0.0)
	sim.lives = 1000000
	field = TimedField.new()
	field.size = Vector2(1280, 720)
	root.add_child(field)


# 1 フレーム = 前のフレームの step と snapshot の時間 + その後に描いた _draw の時間。
func _process(_delta: float) -> bool:
	if n > 0:
		times.append(step_us + field.last_us)
	var t0 := Time.get_ticks_usec()
	for e: Dictionary in sim.enemies:
		e["t"] = 1  # 帰らせない
	for k in 2:
		sim.step()
	field.snap = sim.snapshot()
	step_us = Time.get_ticks_usec() - t0
	field.queue_redraw()
	n += 1
	if n > frames:
		times.sort()
		var p95: int = times[int(times.size() * 0.95)]
		var med: int = times[times.size() / 2]
		print("フレーム %d 個: 中央値 %.2f ms、95%% 値 %.2f ms、最大 %.2f ms(弾 %d・敵 %d・壁 %d)" % [times.size(), med / 1000.0, p95 / 1000.0,
			times[-1] / 1000.0, sim.bx.size(), sim.enemies.size(), sim.walls.size()])
		print("NFR-1(95%% 値が 16.7 ms 以内): %s。ヘッドレスのスクリプトの CPU 時間だけで、本物の GPU の描画は入っていない" % ("通る" if p95 <= 16700 else "通らない"))
		return true
	return false
