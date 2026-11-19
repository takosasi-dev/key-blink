# 画面の流れのテスト(AC-18〜AC-20・FR-2・FR-17・FR-20・FR-25・FR-27・FR-29・E-20)。main.tscn を木に置き、キーのイベントを直接渡し、
# フレームは _process を呼んで進める。ブラウザでは確かめていない(ヘッドレスだけ)。
extends "res://tests/suite.gd"

const MainScene := preload("res://ui/main.tscn")
const Store := preload("res://save/save_store.gd")


static func kev(pk: int, echo: bool = false) -> InputEventKey:
	var e := InputEventKey.new()
	e.pressed = true
	e.physical_keycode = pk as Key
	e.keycode = pk as Key
	e.echo = echo
	return e


func _main() -> Node:
	if FileAccess.file_exists(Store.PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Store.PATH))
	var m := MainScene.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(m)
	return m


func _done(m: Node) -> void:
	m.get_parent().remove_child(m)
	m.free()


static func kp(m: Node, pk: int) -> void:
	m._input(kev(pk))


static func frames(m: Node, n: int, dt: float = 1.0 / 60.0) -> void:
	for k in n:
		if m.play != null:
			m.play._process(dt)
		if m.current != null and m.current.has_method("_process") and m.current != m.play:
			m.current._process(dt)


static func lose_now(m: Node) -> void:
	m.play.sim.lives = 1
	m.play.sim.invuln = 0
	m.play.sim.add_bullet(m.play.sim.ship_x, m.play.sim.ship_y, 0.0, 0.0)
	frames(m, 1)
	m.play.finished.emit(m.play.sim.result())  # 終わった後の 600 ms を待たない


func test_ac18_flow_keyboard_only() -> bool:
	var m := _main()
	eq(m.screen, "gate", "S0 から始まる")
	kp(m, KEY_X)
	eq(m.screen, "title", "どれかのキーで S1")
	ok(m.play == null, "S0 のキーはゲームの操作に数えない")
	eq(String(m.current.menu.buttons[0].name), "daily", "一番上は今日のステージ")
	kp(m, KEY_ENTER)
	eq(m.screen, "play", "Enter で今日のステージ")
	eq(int(m.run["mode"]), Sim.MODE_DAILY, "今日のステージ")
	kp(m, KEY_J)
	frames(m, 1)
	eq(m.play.sim.key, idx("J"), "J で J へ跳ぶ(FR-3)")
	lose_now(m)
	eq(m.screen, "result", "終わると S3")
	ok(m.current.share.begins_with("KeyBlink ") and m.current.share.contains("今日のステージ・1回目"), "共有する文字")
	var seed_before: int = m.run["seed"]
	kp(m, KEY_ENTER)
	eq(m.screen, "result", "300 ms の前は押せない")
	m.current._shown_at -= 1000
	frames(m, 1)
	kp(m, KEY_ENTER)
	eq(m.screen, "play", "もう1回(Enter)")
	eq(int(m.run["seed"]), seed_before, "今日のステージは同じ種(FR-20)")
	eq(m.play.sim.tick, 0, "新しい回")
	lose_now(m)
	ok(m.current.share.contains("(今日のステージ)"), "2 回目は「今日のステージ」")
	m.current._shown_at -= 1000
	frames(m, 1)
	kp(m, KEY_R)
	eq(m.screen, "play", "R でももう1回")
	_done(m)
	return true


func test_clear_path_to_result() -> bool:
	var m := _main()
	kp(m, KEY_X)
	kp(m, KEY_DOWN)
	kp(m, KEY_ENTER)
	eq(int(m.run["mode"]), Sim.MODE_PRACTICE, "練習")
	m.play.sim.sched.plan.clear()
	m.play.sim.tick = B.STAGE_TICKS - 1
	m.play.sim.lives = 2
	frames(m, 1)
	ok(m.play.sim.is_over() and m.play.sim.reason == Sim.OVER_CLEAR, "クリアで終わる")
	ok(m.play._clear.visible or m.play._clear_until > 0, "「クリア」を出す")
	m.play._over_at -= 2000
	frames(m, 1)
	eq(m.screen, "result", "クリアの後に S3")
	ok(m.current.share.contains("クリア 残機 2"), "共有する文字にクリアと残機")
	ok(m.current.share.contains("(練習)"), "練習の共有する文字")
	ok(m.store.practice_best() != null and m.store.practice_best()["clear"] == true, "練習の最高を保存")
	m.current._shown_at -= 1000
	frames(m, 1)
	kp(m, KEY_DOWN)
	kp(m, KEY_DOWN)
	kp(m, KEY_ENTER)
	eq(m.screen, "title", "タイトルへ")
	_done(m)
	return true


func test_fr27_echo_and_modifiers_do_not_reach_sim() -> bool:
	var m := _main()
	kp(m, KEY_X)
	kp(m, KEY_ENTER)
	for mod in ["ctrl_pressed", "alt_pressed", "meta_pressed"]:
		var e := kev(KEY_J)
		e.set(mod, true)
		m._input(e)
	m._input(kev(KEY_J, true))
	m._input(kev(KEY_SPACE))
	m._input(kev(KEY_ENTER))
	m._input(kev(KEY_UP))
	m._input(kev(KEY_1))
	frames(m, 2)
	eq(m.play.sim.blinks, 0, "押しっぱなし・Ctrl・Alt・Meta 付き・30 キー以外は届かない")
	ok(m.play.sim.tick > 0, "進んではいる")
	kp(m, KEY_J)
	frames(m, 1)
	eq(m.play.sim.blinks, 1, "Shift なしの J は届く")
	_done(m)
	return true


func test_ac19_pause_clears_pending_and_freezes() -> bool:
	var m := _main()
	kp(m, KEY_X)
	kp(m, KEY_ENTER)
	frames(m, 30)
	kp(m, KEY_J)
	frames(m, 1)
	kp(m, KEY_K)  # 待ちの間なので覚える
	frames(m, 0)
	m.play.sim.step()
	eq(m.play.sim.pending, idx("K"), "待ちの間は次の跳び先を覚える")
	kp(m, KEY_ESCAPE)
	ok(m.pause_view != null, "Esc で一時停止")
	eq(m.play.sim.pending, -1, "一時停止に入ると次の跳び先が消える")
	var t: int = m.play.sim.tick
	var ys: Array = m.play.sim.enemies.map(func(e: Dictionary) -> float: return e["y"])
	kp(m, KEY_L)
	frames(m, 120)
	eq(m.play.sim.tick, t, "止まる")
	eq(m.play.sim.enemies.map(func(e: Dictionary) -> float: return e["y"]), ys, "敵が動かない")
	kp(m, KEY_ESCAPE)
	ok(m.pause_view == null, "Esc で続ける")
	frames(m, 2)
	ok(m.play.sim.tick > t, "続けると進む")
	eq(m.play.sim.key, idx("J"), "一時停止の間のキーは届かない")
	m._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	ok(m.pause_view != null, "フォーカスが外れると一時停止(E-11)")
	var t2: int = m.play.sim.tick
	frames(m, 60)
	eq(m.play.sim.tick, t2, "戻っても自動では再開しない")
	_done(m)
	return true


func test_pause_settings_back_and_restart() -> bool:
	var m := _main()
	kp(m, KEY_X)
	kp(m, KEY_ENTER)
	kp(m, KEY_ESCAPE)
	kp(m, KEY_DOWN)
	kp(m, KEY_DOWN)
	kp(m, KEY_ENTER)
	eq(m.screen, "settings", "一時停止から設定")
	kp(m, KEY_DOWN)
	kp(m, KEY_ENTER)
	eq(m.store.settings()["shake"], false, "揺れを切って保存")
	kp(m, KEY_DOWN)
	kp(m, KEY_ENTER)
	eq(m.store.settings()["reduce_flash"], true, "点滅を弱めるを入れて保存")
	kp(m, KEY_ESCAPE)
	eq(m.screen, "play", "戻ると一時停止へ")
	ok(m.pause_view != null and m.pause_view.visible, "一時停止の画面")
	eq(m.play.shake_on, false, "設定がプレイに届く")
	ok(m.play.field.reduce_flash, "点滅を弱めるが描画に届く")
	kp(m, KEY_R)
	eq(m.screen, "play", "R でやり直す")
	ok(m.pause_view == null and m.play.sim.tick == 0, "新しい回")
	_done(m)
	return true


func test_ac20_no_shake_when_off() -> bool:
	var m := _main()
	m.store.set_setting("shake", false)
	kp(m, KEY_X)
	kp(m, KEY_ENTER)
	m.play.on_event({"type": "hit", "lives": 2, "x": 484.0, "y": 548.0}, {})
	frames(m, 3)
	eq(m.play.position, Vector2.ZERO, "揺れを切ると当たっても動かない")
	m.play.shake_on = true
	m.play.on_event({"type": "hit", "lives": 2, "x": 484.0, "y": 548.0}, {})
	var moved := false
	for k in 5:
		frames(m, 1, 0.0)
		moved = moved or m.play.position != Vector2.ZERO
	ok(moved, "入なら揺れる")
	_done(m)
	return true


func test_fr17_every_event_type_is_handled() -> bool:
	var m := _main()
	kp(m, KEY_X)
	kp(m, KEY_ENTER)
	var list := [
		{"type": "blink", "from": 13, "to": 16},
		{"type": "power_up", "strength": 2},
		{"type": "shot_hit", "id": 1, "x": 400.0, "y": 200.0},
		{"type": "kill", "id": 1, "kind": Sim.FAN, "x": 400.0, "y": 200.0, "points": 400},
		{"type": "graze", "x": 480.0, "y": 530.0},
		{"type": "laser_warn", "x": 484.0, "id": 2},
		{"type": "laser_fire", "x": 484.0, "id": 2},
		{"type": "wall_drop", "gx": 484.0, "y": 120.0},
		{"type": "hit", "lives": 2, "x": 484.0, "y": 548.0},
		{"type": "wave_start", "wave": 4},
	]
	var heard := {}
	for e: Dictionary in list:
		m.play.on_event(e, heard)
	eq(heard.size(), list.size(), "全部の type を受けた")
	eq(m.play.fx.floats.size(), 1, "倒した時の「+400」")
	ok(m.play.fx.shards.size() > 0, "破片")
	eq(m.play.fx.sparks.size(), 1, "かすりの火花")
	eq(m.play.field.ghost_key, 13, "残像は元の場所")
	eq(m.play._note.text, "波 4", "波の始め")
	frames(m, 1)
	ok(m.play._note.visible, "「波 4」を出す")
	_done(m)
	return true


func test_e20_at_most_8_ticks_per_frame() -> bool:
	var m := _main()
	kp(m, KEY_X)
	kp(m, KEY_ENTER)
	frames(m, 1)
	var t: int = m.play.sim.tick
	frames(m, 1, 1.0)
	eq(m.play.sim.tick - t, B.MAX_STEPS_PER_FRAME, "1 フレーム 8 tick まで")
	_done(m)
	return true


func test_gate_touch_note() -> bool:
	var m := _main()
	var t := InputEventScreenTouch.new()
	t.pressed = true
	m._input(t)
	var mb := InputEventMouseButton.new()
	mb.pressed = true
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.device = InputEvent.DEVICE_ID_EMULATION
	m._input(mb)
	eq(m.screen, "gate", "タッチと、そこから作られたマウスでは進まない(FR-29)")
	ok(m._touch_note.visible, "キーボードで遊ぶ案内が出る")
	_done(m)
	return true


func test_ime_note_on_zero_keycode() -> bool:
	var m := _main()
	kp(m, KEY_X)
	kp(m, KEY_ENTER)
	m._input(kev(KEY_NONE))
	frames(m, 1)
	ok(m.play._ime.visible, "physical_keycode が 0 のキーで日本語入力の案内(共通 §3 の 9)")
	_done(m)
	return true


func test_title_records() -> bool:
	var m := _main()
	kp(m, KEY_X)
	eq(m.current.get_children().filter(func(c: Node) -> bool: return c is Label and c.text == S.REC_NONE).size(), 0,
		"初めての起動では記録の行を出さない")
	_done(m)
	return true
