# core の決まりのテスト(AC-3〜AC-15・E-2〜E-5・E-9)。場面を組み、step を進めて値で確かめる。
extends "res://tests/suite.gd"

const Schedule := preload("res://core/schedule.gd")
const Bots := preload("res://core/bots.gd")


func test_ac3_key_positions() -> bool:
	var want := {"Q": Vector2(172, 452), "P": Vector2(1036, 452), "A": Vector2(196, 548), "F": Vector2(484, 548),
		"J": Vector2(772, 548), ";": Vector2(1060, 548), "Z": Vector2(244, 644), "/": Vector2(1108, 644)}
	for l: String in want:
		var k := idx(l)
		eq(Vector2(Keys.x_of(k), Keys.y_of(k)), want[l], "%s の場所" % l)
	eq(Keys.COUNT, 30, "30 キー")
	eq(Keys.index_of_physical(KEY_SEMICOLON), idx(";"), "; の物理キー")
	eq(Keys.index_of_physical(KEY_SLASH), 29, "/ は 29")
	eq(Keys.index_of_physical(KEY_1), -1, "数字の段は使わない")
	return true


func test_ac4_blink_cost_and_cooldown() -> bool:
	var sim := empty_sim()
	sim.power = 600
	press(sim, idx("J"))
	eq(Vector2(sim.ship_x, sim.ship_y), Vector2(772, 548), "J へ移る")
	eq(sim.power, 100, "力 600 − 500")
	eq(sim.cooldown, 15, "待ち 15")
	eq(sim.blinks, 1, "跳んだ回数")
	return true


func test_ac5_last_press_during_cooldown() -> bool:
	var sim := empty_sim()
	press(sim, idx("J"))
	press(sim, idx("K"))
	press(sim, idx("L"))
	var jumped_to: Array = []
	for k in 20:
		for e: Dictionary in run(sim, 1):
			if e["type"] == "blink":
				jumped_to.append(Keys.LABELS[e["to"]])
	eq(jumped_to, ["L"], "待ちの後に L だけへ跳ぶ")
	return true


func test_e4_two_presses_same_step() -> bool:
	var sim := empty_sim()
	sim.queue_press(idx("K"))
	sim.queue_press(idx("L"))
	run(sim, 1)
	eq(sim.key, idx("L"), "同じ step の後の物")
	return true


func test_ac6_same_key_no_blink() -> bool:
	var sim := empty_sim()
	sim.power = 600
	var ev := press(sim, idx("F"))
	eq(of_type(ev, "blink").size(), 0, "跳ばない")
	eq(sim.power, 605, "力は減らず、たまる")
	eq(sim.pending, -1, "跳び先を消す")
	return true


func test_ac7_power_fills_and_strength() -> bool:
	var sim := empty_sim()
	var ups: Array = []
	for k in 200:
		for e: Dictionary in run(sim, 1):
			if e["type"] == "power_up":
				ups.append(e["strength"])
	eq(sim.power, 1000, "200 tick で 1000")
	eq(ups, [2, 3], "500 と 1000 で power_up")
	eq(Sim.strength_of(499), 1, "強さ 1")
	eq(Sim.strength_of(500), 2, "強さ 2")
	eq(Sim.strength_of(1000), 3, "強さ 3")
	return true


func test_ac8_hit_and_graze_distance() -> bool:
	var sim := empty_sim()
	sim.add_bullet(sim.ship_x + 12.0 - 0.01, sim.ship_y, 0.0, 0.0)
	run(sim, 1)
	eq(sim.lives, 2, "6 + 6 − 0.01 で当たり")
	sim = empty_sim()
	sim.add_bullet(sim.ship_x + 12.0 + 0.01, sim.ship_y, 0.0, 0.0)
	run(sim, 1)
	eq(sim.lives, 3, "6 + 6 + 0.01 で当たらない")
	eq(sim.grazes, 1, "かすり 1")
	eq(sim.score, B.GRAZE_POINTS, "かすりの点")
	run(sim, 5)
	eq(sim.grazes, 1, "同じ弾で 2 回目は数えない")
	return true


func test_ac9_pillar_warn_then_fire() -> bool:
	var sim := empty_sim()
	var e := put_enemy(sim, Sim.PILLAR, 0.0, 3)
	var fire_steps := 0
	var hit_in_warn := false
	for k in 120:
		run(sim, 1)
		hit_in_warn = hit_in_warn or sim.lives < 3
		ok(int(e["lp"]) == Sim.L_WARN, "予告の間(step %d)" % k)
	ok(not hit_in_warn, "予告の 120 tick は当たらない(E-7)")
	sim.invuln = 1000000  # 光線の長さを数えるため、当たっても止めない
	for k in 70:
		run(sim, 1)
		if int(e["lp"]) == Sim.L_FIRE:
			fire_steps += 1
			ok(Sim.laser_hits(e, sim.ship_x, sim.ship_y, B.SHIP_R), "光線は F に重なる")
	eq(fire_steps, 60, "光線は 60 tick")
	sim = empty_sim()
	put_enemy(sim, Sim.PILLAR, 0.0, 3)
	run(sim, 121)
	eq(sim.lives, 2, "光線が出た step に当たる")
	return true


func test_ac10_wall_gap_has_a_key_in_every_row() -> bool:
	for c in 10:
		var gx := Keys.column_x(c)
		for row in 3:
			var found := false
			for k in range(row * 10, row * 10 + 10):
				if absf(Keys.x_of(k) - gx) <= 66.0:
					var w := {"y": Keys.y_of(k) - B.WALL_H / 2.0, "gx": gx}
					ok(not Sim.wall_hits(w, Keys.x_of(k), Keys.y_of(k), B.SHIP_R), "列 %d の段 %d のキー %s は隙間" % [c, row, Keys.LABELS[k]])
					found = true
			ok(found, "列 %d の段 %d に隙間のキーがある" % [c, row])
	var sim := empty_sim()
	sim.walls.append({"y": sim.ship_y - 30.0, "gx": Keys.column_x(9), "vy": 20.0})
	run(sim, 1)
	eq(sim.lives, 2, "隙間でない所の壁に当たる")
	return true


func test_wall_passed_is_safe() -> bool:
	var sim := empty_sim()
	sim.walls.append({"y": Keys.y_of(idx("F")) + 20.0, "gx": Keys.column_x(9), "vy": 1.5})
	press(sim, idx("R"))
	run(sim, 30)
	eq(sim.lives, 3, "通り過ぎた壁より上の段は安全(E-8)")
	return true


func test_ac11_hit_resets() -> bool:
	var sim := empty_sim()
	sim.power = 800
	put_enemy(sim, Sim.PILLAR, 0.0, 9)
	sim.walls.append({"y": 300.0, "gx": 500.0, "vy": 0.0})
	for k in 5:
		sim.add_bullet(300.0 + k * 20.0, 200.0, 0.0, 0.0)
	sim.add_bullet(sim.ship_x, sim.ship_y, 0.0, 0.0)
	sim.queue_press(idx("J"))
	sim.cooldown = 5
	var ev := run(sim, 1)
	eq(sim.lives, 2, "残機 −1")
	eq(sim.bx.size(), 0, "弾が 0")
	eq(sim.walls.size(), 0, "壁が 0")
	eq(sim.invuln, 240, "無敵 240")
	eq(sim.power, 0, "力 0")
	eq(sim.pending, -1, "次の跳び先を消す")
	eq(of_type(ev, "hit").size(), 1, "hit")
	sim.add_bullet(sim.ship_x, sim.ship_y, 0.0, 0.0)
	run(sim, 10)
	eq(sim.lives, 2, "無敵の間は当たらない(E-6)")
	eq(sim.grazes, 0, "無敵の間はかすりも数えない")
	return true


func test_e5_blink_into_bullet() -> bool:
	var sim := empty_sim()
	sim.add_bullet(Keys.x_of(idx("J")), Keys.y_of(idx("J")), 0.0, 0.0)
	press(sim, idx("J"))
	eq(sim.lives, 2, "跳んだ先の弾に当たる")
	return true


func test_laser_stops_on_hit() -> bool:
	var sim := empty_sim()
	var e := put_enemy(sim, Sim.PILLAR, 0.0, 3)
	run(sim, 121)
	eq(int(e["lp"]), Sim.L_REST, "当たると光線を止めて休みへ")
	return true


func test_lives_zero_ends() -> bool:
	var sim := empty_sim()
	sim.lives = 1
	sim.add_bullet(sim.ship_x, sim.ship_y, 0.0, 0.0)
	var ev := run(sim, 1)
	ok(sim.is_over(), "残機 0 で終わる")
	eq(sim.reason, Sim.OVER_LIVES, "理由 = 残機")
	eq(of_type(ev, "over").size(), 1, "over")
	var t := sim.tick
	run(sim, 10)
	eq(sim.tick, t, "終わった後は進まない")
	return true


func test_ac14_clear_bonus() -> bool:
	var sim := empty_sim()
	sim.tick = B.STAGE_TICKS - 1
	sim.lives = 2
	sim.score = 1000
	run(sim, 1)
	ok(sim.is_over(), "tick 21600 で終わる")
	eq(sim.reason, Sim.OVER_CLEAR, "クリア")
	eq(sim.score, 1000 + 4000, "残機 2 で 4000 点")
	ok(sim.result()["clear"], "result の clear")
	eq(sim.result()["wave"], 12, "届いた波 12")
	return true


func test_e9_bullet_cap() -> bool:
	var sim := empty_sim()
	for k in B.BULLET_CAP - 2:
		sim.add_bullet(200.0, 120.0, 0.0, 0.0)
	var e := put_enemy(sim, Sim.FAN, 800.0)
	e["t"] = 0
	sim._aimed(e, B.FAN_DEG)
	eq(sim.bx.size(), B.BULLET_CAP, "扇の 5 発は入る数だけ")
	return true


func test_shot_kills_and_points() -> bool:
	var sim := empty_sim()
	sim._spawn({"kind": Sim.SMALL, "x": Keys.x_of(13), "stop_y": 300.0, "col": -1})
	var ev := run(sim, 400)
	eq(of_type(ev, "kill").size(), 1, "真上の小物を倒す")
	eq(sim.kills, 1, "倒した数")
	eq(sim.score, 100, "小物 100 点")
	return true


func test_fan_fires_five() -> bool:
	var sim := empty_sim()
	put_enemy(sim, Sim.FAN, 800.0)
	sim.invuln = 1000000
	run(sim, 1 + B.FAN_EVERY)
	eq(sim.bx.size(), 5, "扇は 5 方向")
	return true


func test_wall_dropper_drops_two() -> bool:
	var sim := empty_sim()
	put_enemy(sim, Sim.WALLER, 800.0, 4)
	sim.invuln = 1000000
	var ev := run(sim, 1 + B.WALL_EVERY * 2)
	eq(of_type(ev, "wall_drop").size(), 2, "壁を 2 枚")
	return true


func test_ac12_schedule_independent_of_input() -> bool:
	var a := Sim.new(77, 0)
	var b := Sim.new(77, 0)
	Bots.play(a, Bots.IDLE, 3000)
	Bots.play(b, Bots.DODGE, 3000)
	eq(a.sched.plan, b.sched.plan, "同じ種なら並びが同じ")
	eq(Schedule.new(77).plan, a.sched.plan, "種だけで決まる")
	ok(Schedule.new(78).plan != a.sched.plan, "種が違えば違う")
	return true


func test_ac13_teaching_waves() -> bool:
	var plan: Array = Schedule.new(5).plan
	eq([plan[0]["t"], plan[0]["x"], plan[0]["stop_y"]], [60, 484.0, 200.0], "1 体目は F の真上")
	eq([plan[1]["t"], plan[1]["x"], plan[1]["stop_y"]], [360, 772.0, 200.0], "2 体目は J の真上")
	var first := {}
	for p: Dictionary in plan:
		if not first.has(p["kind"]):
			first[p["kind"]] = p
	eq(int(first[Sim.FAN]["t"]), B.WAVE_TICKS + 600, "扇は波 2 の tick 600")
	eq([int(first[Sim.PILLAR]["t"]), int(first[Sim.PILLAR]["col"])], [2 * B.WAVE_TICKS + 300, 3], "柱は波 3 の tick 300、列 3")
	eq(int(first[Sim.WALLER]["t"]), 3 * B.WAVE_TICKS + 300, "壁は波 4 の tick 300")
	var counts := [[5, 0, 0, 0], [8, 1, 0, 0], [6, 0, 1, 0], [6, 0, 0, 1], [8, 1, 1, 0], [8, 1, 0, 1]]
	for w in 6:
		var c := [0, 0, 0, 0]
		for p: Dictionary in plan:
			if int(p["t"]) / B.WAVE_TICKS == w:
				c[int(p["kind"])] += 1
		eq(c, counts[w], "波 %d の中身" % (w + 1))
	return true


func test_ac15_idle_bot_loses_within_90s() -> bool:
	for s in range(1, 11):
		var r: Dictionary = Bots.play(Sim.new(s, 1), Bots.IDLE, 10800)
		ok(not r["clear"] and int(r["lives"]) == 0, "種 %d: 90 秒以内に残機 0(tick %d)" % [s, r["ticks"]])
	return true
