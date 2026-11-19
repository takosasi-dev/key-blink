# 敵の並び・決定性・向きの表・上限のテスト(仕様書 §9.7・AC-2・NFR-4・E-10・共通 §3 の 15)。
extends "res://tests/suite.gd"

const Schedule := preload("res://core/schedule.gd")
const Bots := preload("res://core/bots.gd")
const Dirs := preload("res://core/dirs.gd")

# 決定性の固定値(Windows と CI の Linux で同じになること。NFR-4)。値を変えたら測り直す
const GOLDEN_SEED := 2026
const GOLDEN_DODGE := {"score": 420, "lives": 3, "wave": 4, "kills": 4, "grazes": 2, "ticks": 6000}
const GOLDEN_IDLE := {"score": 130, "lives": 0, "wave": 1, "kills": 1, "grazes": 3, "ticks": 1775}


static func _pick(r: Dictionary) -> Dictionary:
	return {"score": r["score"], "lives": r["lives"], "wave": r["wave"], "kills": r["kills"], "grazes": r["grazes"], "ticks": r["ticks"]}


func test_ac2_same_input_same_result_100_times() -> bool:
	# 押す記録: 60 tick ごとに決まったキー
	var first := {}
	for n in 100:
		var sim := Sim.new(31, 1)
		for t in 2400:
			if t % 60 == 0:
				sim.queue_press((t / 60 * 7) % 30)
			sim.step()
		var r := _pick(sim.result())
		if n == 0:
			first = r
		elif r != first:
			eq(r, first, "%d 回目" % n)
			break
	ok(int(first["ticks"]) > 0, "進んだ")
	return true


func test_golden_values() -> bool:
	var d := _pick(Bots.play(Sim.new(GOLDEN_SEED, 0), Bots.DODGE, 6000))
	var i := _pick(Bots.play(Sim.new(GOLDEN_SEED, 0), Bots.IDLE))
	print("      GOLDEN dodge=%s idle=%s" % [d, i])
	eq(d, GOLDEN_DODGE, "逃げ bot 6000 tick の固定値")
	eq(i, GOLDEN_IDLE, "何もしない bot の固定値")
	return true


func test_plan_shape() -> bool:
	var plan: Array = Schedule.new(9).plan
	var last := -1
	var budget := []
	for w in 13:
		budget.append(0)
	for p: Dictionary in plan:
		ok(int(p["t"]) >= last, "時刻は増える")
		last = p["t"]
		ok(int(p["t"]) < B.STAGE_TICKS, "3 分の中")
		if int(p["kind"]) != Sim.PILLAR:
			ok(float(p["x"]) >= 172.0 and float(p["x"]) <= 1108.0, "出る x は 172〜1108")
		if int(p["kind"]) == Sim.SMALL and int(p["t"]) >= B.WAVE_TICKS:
			ok(float(p["stop_y"]) >= 120.0 and float(p["stop_y"]) <= 300.0, "止まる高さは 120〜300")
		if int(p["kind"]) in [Sim.PILLAR, Sim.WALLER]:
			ok(int(p["col"]) >= 0 and int(p["col"]) < 10, "列は 0〜9")
		var w := int(p["t"]) / B.WAVE_TICKS + 1
		if w >= 7:
			budget[w] += int(B.BUDGET_COST[int(p["kind"])])
	for w in range(7, 13):
		eq(budget[w], 10 + 2 * (w - 7), "波 %d の予算" % w)
	ok(plan.size() <= 120, "最大 120 体(非機能 §2)")
	return true


func test_e10_enemy_cap_waits() -> bool:
	var sim := empty_sim()
	for k in B.ENEMY_CAP:
		put_enemy(sim, Sim.SMALL, 200.0 + k)
	sim.sched.plan = [{"t": 0, "kind": Sim.SMALL, "x": 500.0, "stop_y": 200.0, "col": -1}]
	run(sim, 1)
	eq(sim.enemies.size(), B.ENEMY_CAP, "40 体の間は出さない")
	sim.enemies.pop_front()
	run(sim, 1)
	eq(sim.enemies.size(), B.ENEMY_CAP, "空いた step に出す")
	return true


func test_dirs_table() -> bool:
	eq(Dirs.DIRS.size(), 360, "360 の向き")
	eq(Dirs.DIRS[0], [1.0, 0.0], "0 度")
	eq(Dirs.DIRS[90], [0.0, 1.0], "90 度")
	var r: Array[float] = Dirs.rotate(1.0, 0.0, -90)
	ok(absf(r[0]) < 1e-12 and absf(r[1] + 1.0) < 1e-12, "−90 度")
	for d: int in B.FAN_DEG:
		var v: Array[float] = Dirs.rotate(0.0, 1.0, d)
		ok(absf(v[0] * v[0] + v[1] * v[1] - 1.0) < 1e-9, "回しても長さ 1")
	return true


func test_wave_and_speed_rate() -> bool:
	eq(Sim.speed_rate(1), 0.6, "波 1 は 0.6")
	eq(Sim.speed_rate(2), 1.05, "波 2 は 1.05")
	var sim := empty_sim()
	sim.tick = B.WAVE_TICKS * 3
	eq(sim.wave(), 4, "tick 5400 は波 4")
	var ev := run(sim, 1)
	eq(of_type(ev, "wave_start").size(), 1, "波の始めの events")
	return true
