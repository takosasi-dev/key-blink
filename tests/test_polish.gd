# 磨き(2026-11-20)で足した演出のテスト: 撃つ前の合図の時刻(sim.ticks_to_shot)が本当に撃つ step と合うこと、
# 柱の光線が当たるキー・壁の隙間に入るキーの印、当たった時の赤み(点滅を弱める時は 20% 以下)と短い止め、タイトルの盤の跳び。
extends "res://tests/suite.gd"

const MainScene := preload("res://ui/main.tscn")
const Store := preload("res://save/save_store.gd")
const Field := preload("res://ui/field.gd")


# 種 3 つで 3000 tick 回し、「1 step 後に撃つ」と言った敵が次の step で弾を出し、出た弾は全部どれかの敵が言い当てていること。
func test_ticks_to_shot_matches_real_shots() -> bool:
	for s in [1, 2, 2026]:
		var sim := Sim.new(s, Sim.MODE_DAILY)
		var said := 0
		var shots := 0
		var missed := 0
		for t in 3000:
			sim.invuln = 1000  # 当たって弾が消えないように(合図の時刻だけを見る)
			var expect := {}
			for e in sim.enemies:
				if sim.ticks_to_shot(e) == 1:
					expect[e["id"]] = true
			var before := sim.tick
			var n0 := sim.bx.size()
			sim.step()
			var born := 0
			for b in sim.bborn:
				if b == before:
					born += 1
			if born > 0:
				shots += 1
				if expect.is_empty():
					missed += 1
			if not expect.is_empty():
				said += 1
				ok(born > 0, "種 %d tick %d: 撃つと言った敵が撃たない(弾 %d → %d)" % [s, before, n0, sim.bx.size()])
		eq(missed, 0, "種 %d: 合図なしに出た弾" % s)
		ok(shots > 10 and said == shots, "種 %d: 撃った step %d・言い当てた step %d" % [s, shots, said])
	return true


func test_ticks_to_shot_counts_down() -> bool:
	var sim := empty_sim()
	var e := put_enemy(sim, Sim.FAN, 400.0)
	eq(sim.ticks_to_shot(e), 1 + B.FAN_EVERY, "扇は着いてから FAN_EVERY 後に撃つ")
	run(sim, 1)
	eq(sim.ticks_to_shot(e), B.FAN_EVERY, "1 step で 1 減る")
	var p := put_enemy(sim, Sim.PILLAR, 0.0, 3)
	eq(sim.ticks_to_shot(p), -1, "柱は弾を撃たない")
	return true


func test_key_marks_follow_core_geometry() -> bool:
	var sim := empty_sim()
	var p := put_enemy(sim, Sim.PILLAR, 0.0, 3)
	run(sim, 1)
	eq(int(p["lp"]), Sim.L_WARN, "柱は予告に入った")
	var f := Field.new()
	f.snap = sim.snapshot()
	for k in Keys.COUNT:
		var c := Vector2(Keys.x_of(k), Keys.y_of(k))
		var want := 1 if Sim.laser_hits(p, c.x, c.y, B.SHIP_R) else 0
		eq(f._key_mark(c), want, "キー %s の光線の印" % Keys.LABELS[k])
	eq(f._key_mark(Vector2(Keys.x_of(idx("F")), Keys.y_of(idx("F")))), 1, "F は光線の中")
	eq(f._key_mark(Vector2(Keys.x_of(idx("K")), Keys.y_of(idx("K")))), 0, "K は外")
	# 壁: 隙間の中心を J の列(6)に。まだ上にある壁なら、3 段とも隙間に入るキーに印
	var sim2 := empty_sim()
	sim2.walls.append({"y": 200.0, "gx": Keys.column_x(6), "vy": 1.0, "born": 0})
	f.snap = sim2.snapshot()
	var marked := 0
	for k in Keys.COUNT:
		var c := Vector2(Keys.x_of(k), Keys.y_of(k))
		if f._key_mark(c) == 2:
			marked += 1
			ok(absf(c.x - Keys.column_x(6)) <= B.WALL_GAP / 2.0, "隙間の外のキー %s に印" % Keys.LABELS[k])
	eq(f._key_mark(Vector2(Keys.x_of(idx("J")), Keys.y_of(idx("J")))), 2, "J は隙間")
	ok(marked >= 3, "3 段のどれにも隙間のキーがある(%d)" % marked)
	# 上の段を通り過ぎた壁は、上の段に印を付けない
	sim2.walls[0]["y"] = Keys.y_of(0) + 20.0
	f.snap = sim2.snapshot()
	eq(f._key_mark(Vector2(Keys.x_of(idx("U")), Keys.y_of(idx("U")))), 0, "通り過ぎた段には印なし")
	# 隙間の違う 2 枚が降りてくる時は、片方の隙間のキーにも印を付けない
	sim2.walls[0]["y"] = 200.0
	sim2.walls.append({"y": 260.0, "gx": Keys.column_x(1), "vy": 1.0, "born": 0})
	f.snap = sim2.snapshot()
	eq(f._key_mark(Vector2(Keys.x_of(idx("J")), Keys.y_of(idx("J")))), 0, "2 枚目に当たる J は緑にしない")
	eq(f._key_mark(Vector2(Keys.x_of(idx("S")), Keys.y_of(idx("S")))), 0, "1 枚目に当たる S も緑にしない")
	f.free()
	return true


func _main() -> Node:
	if FileAccess.file_exists(Store.PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Store.PATH))
	var m := MainScene.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(m)
	return m


func _done(m: Node) -> void:
	m.get_parent().remove_child(m)
	m.free()


static func _key(m: Node, pk: int) -> void:
	var e := InputEventKey.new()
	e.pressed = true
	e.physical_keycode = pk as Key
	m._input(e)


func test_hit_tint_stop_and_mark() -> bool:
	for reduce: bool in [false, true]:
		var m := _main()
		m.store.set_setting("reduce_flash", reduce)
		_key(m, KEY_X)
		_key(m, KEY_ENTER)
		m.play._process(1.0 / 60.0)
		var t: int = m.play.sim.tick
		m.play.on_event({"type": "hit", "lives": 2, "x": 484.0, "y": 548.0}, {})
		m.play._process(1.0 / 60.0)
		var a: float = m.play.tint.color.a
		if reduce:
			ok(a > 0.0 and a <= 0.2, "点滅を弱める時の赤みは 20%% 以下(%.2f)" % a)
		else:
			ok(a > 0.2, "当たった時は画面が赤む(%.2f)" % a)
		eq(m.play.sim.tick, t, "当たった直後は短く止める")
		eq(m.play.field.hit_mark, Vector2(484.0, 548.0), "当たった所に輪")
		_done(m)
	return true


func test_title_demo_blinks() -> bool:
	var m := _main()
	_key(m, KEY_X)
	var title: Node = m.current
	var before: int = title.faint.snap["key"]
	title.demo_step(1000)
	var to: int = B.DEMO_KEYS[0]
	eq(int(title.faint.snap["key"]), to, "盤の自機が跳ぶ")
	eq(title.faint.ghost_key, before, "残像は元の場所")
	eq(title.faint.snap["x"], Keys.x_of(to), "跳んだ先の位置")
	_done(m)
	return true
