# v0.3.0 の UI の作り直しのテスト: theme.tres が全部の Control に付く・5 つの状態・色の板のコントラスト・表示用の字体の字・
# 画面の切り替わりは見た目だけ(入力を飲まない・もう1回は動かない・点滅を弱める 入なら動かない)・時刻で決まる動きの関数・
# 「瞬き」の題材でも、既定で 1 秒に 3 回を超える明滅を作らないこと。作りは KeySwat の tests/test_look.gd。
extends "res://tests/suite.gd"

const MainScene := preload("res://ui/main.tscn")
const Store := preload("res://save/save_store.gd")
const Kit := preload("res://ui/kit.gd")
const Play := preload("res://ui/play.gd")
const Result := preload("res://ui/result.gd")
const Field := preload("res://ui/field.gd")
const Logo := preload("res://ui/logo.gd")
const Lids := preload("res://ui/lids.gd")
const Backdrop := preload("res://ui/backdrop.gd")
const TestUi := preload("res://tests/test_ui.gd")
const Pause := preload("res://ui/pause.gd")


func _main(reduce: bool = false) -> Node:
	if FileAccess.file_exists(Store.PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Store.PATH))
	if reduce:
		var s := Store.new()
		s.set_setting("reduce_flash", true)
	var m := MainScene.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(m)
	return m


func _done(m: Node) -> void:
	m.get_parent().remove_child(m)
	m.free()


func test_theme_is_project_wide_and_complete() -> bool:
	eq(ProjectSettings.get_setting("gui/theme/custom"), "res://ui/theme.tres", "theme は project の設定で付ける")
	var t := load("res://ui/theme.tres") as Theme
	ok(t != null, "theme.tres を読める")
	if t == null:
		return true
	for st: String in ["normal", "hover", "focus", "pressed", "disabled"]:
		ok(t.has_stylebox(st, "Button"), "Button の %s" % st)
	ok(t.has_stylebox("normal", "SelButton") and t.has_stylebox("disabled", "SelButton") and t.get_type_variation_base("SelButton") == &"Button",
		"選んだボタンの型の変種(押せない間も選んだ見た目)")
	for pair: Array in [["read_only", "TextEdit"], ["focus", "TextEdit"], ["panel", "PopupMenu"], ["hover", "PopupMenu"], ["grabber", "VScrollBar"],
			["scroll", "HScrollBar"], ["slider", "HSlider"], ["panel", "TooltipPanel"], ["panel", "Panel"]]:
		ok(t.has_stylebox(pair[0], pair[1]), "%s の %s" % [pair[1], pair[0]])
	ok(t.get_icon("checked", "CheckBox") is ImageTexture and t.get_icon("grabber", "HSlider") is ImageTexture,
		"絵は ImageTexture(圧縮の形は Web で texture is null を出す)")
	eq((t.get_stylebox("normal", "Button") as StyleBoxFlat).border_color, Kit.C_RULE.lightened(0.18), "theme.tres は今の色で作り直してある(tools/make_theme.gd)")
	var m := _main()
	TestUi.kp(m, KEY_X)
	var b: Button = m.current.menu.buttons[1]
	eq((b.get_theme_stylebox("normal") as StyleBoxFlat).border_color, Kit.C_RULE.lightened(0.18), "タイトルのボタンは theme の札")
	eq(b.theme_type_variation, &"", "選んでいないボタンは素の型")
	eq(m.current.menu.buttons[0].theme_type_variation, &"SelButton", "選んだボタンは SelButton")
	_done(m)
	return true


func test_palette_contrast() -> bool:
	var sel_fill := Kit.C_PANEL.lerp(Kit.C_CYAN, 0.16)
	for pair: Array in [[Kit.C_TEXT, Kit.C_BG], [Kit.C_DIM, Kit.C_BG], [Kit.C_DIM, Kit.C_PANEL], [Kit.C_TEXT, Kit.C_PANEL], [Kit.C_KEY_TEXT, Kit.C_OUT],
			[Kit.C_CYAN, Kit.C_BG], [Kit.C_PINK, Kit.C_BG], [Kit.C_WARN, Kit.C_BG], [Kit.C_GOOD, Kit.C_BG], [Kit.C_BG, Kit.C_CYAN],
			[Kit.C_WHITE, sel_fill], [Kit.C_KEY_EDGE, Kit.C_BG], [Kit.C_DIM, Kit.C_OUT], [Kit.C_TEXT, Color("17113A")]]:
		var c := Kit.contrast(pair[0], pair[1])
		ok(c >= 4.5, "%s と %s のコントラスト %.2f" % [pair[0].to_html(false), pair[1].to_html(false), c])
	# 遊ぶ場所の危ない物と的は、夜の地から見分けられる(3:1 以上)
	for c: Color in [Kit.C_BULLET, Kit.C_SMALL, Kit.C_FAN, Kit.C_PILLAR, Kit.C_WALLER, Kit.C_SHIP]:
		ok(Kit.contrast(c, Kit.C_BG) >= 3.0, "%s と夜の地 %.2f" % [c.to_html(false), Kit.contrast(c, Kit.C_BG)])
	return true


func test_display_font_has_its_glyphs() -> bool:
	var f := load(Kit.DISPLAY) as FontFile
	ok(f != null, "Tilt Neon を読める")
	if f == null:
		return true
	var text := S.NAME + "EscEnterR0123456789,:+v. " + String.chr(Logo.DOTLESS_I)
	var missing := ""
	for c in text:
		if c != " " and not f.has_char(c.unicode_at(0)):
			missing += c
	eq(missing, "", "Tilt Neon に無い字")
	ok(FileAccess.file_exists("res://assets/fonts/OFL_TiltNeon.txt"), "OFL を同梱")
	return true


func test_no_symbol_glyphs_in_strings() -> bool:
	var text := FileAccess.get_file_as_string("res://core/strings.gd")
	var found := ""
	for c in "★☆✓✔✗▶◀▲▼→←↑↓×●○◆◇■□♪":
		if text.contains(c):
			found += c
	eq(found, "", "画面の文字に記号の字(印は _draw で描く)")
	return true


func test_transition_is_visual_only_and_keeps_input() -> bool:
	var m := _main()
	TestUi.kp(m, KEY_X)
	eq(m.screen, "title", "S0 のキーでその場で S1")
	ok(m.lids.progress() < 1.0, "タイトルはまぶたが開く")
	eq(m.current.modulate.a, 1.0, "画面そのものは最初から濃い(選んだボタンの印が最初から見える)")
	TestUi.kp(m, KEY_ENTER)  # 動いている間の Enter もそのまま届く
	eq(m.screen, "play", "動いている間の Enter で今日のステージ(飲まない)")
	var p: Node = m.play
	TestUi.kp(m, KEY_ENTER)
	ok(m.play == p, "遊びの画面の Enter で 2 回目は始まらない")
	TestUi.kp(m, KEY_J)
	TestUi.frames(m, 2)
	eq(m.play.sim.key, idx("J"), "まぶたが開いている間も J が効く")
	TestUi.lose_now(m)
	eq(m.screen, "result", "結果")
	eq(String(m.current.menu.buttons[m.current.menu.sel].name), "retry", "結果は「もう1回」を選んである")
	eq(m.current.menu.buttons[0].theme_type_variation, &"SelButton", "押せない間も選んだ見た目")
	m.current._shown_at -= 1000
	TestUi.frames(m, 1)
	m.lids.start_ms = -100000
	TestUi.kp(m, KEY_R)
	eq(m.screen, "play", "もう1回")
	ok(m.lids.progress() >= 1.0 and m.play.modulate.a == 1.0, "もう1回からは動きを付けない(すぐ遊べる)")
	TestUi.kp(m, KEY_ESCAPE)
	ok(m.pause_view != null and m.entering.size() == 1, "一時停止の板は少し上がりながら出る")
	TestUi.kp(m, KEY_ESCAPE)
	ok(m.pause_view == null and not m.stage.get_children().any(func(c: Node) -> bool: return c.has_method("build") and c.get_script() == Pause),
		"続けると板はすぐ木から外れる(消えていく板が押しを飲まない)")
	_done(m)
	return true


func test_lids_do_not_stack_on_mashing() -> bool:
	var l := Lids.new()
	l.now_ms = 10000
	ok(l.run(), "1 回目の瞬き")
	l.now_ms = 10000 + B.LIDS_GAP_MS - 1
	ok(not l.run(), "間が無ければ 2 回目は出さない")
	l.now_ms = 10000 + B.LIDS_GAP_MS
	ok(l.run(), "間が空けば出す")
	ok(1000.0 / B.LIDS_GAP_MS <= 3.0, "瞬きは 1 秒に 3 回まで")
	l.now_ms = l.start_ms + B.LIDS_MS / 2
	ok(l.progress() > 0.0 and l.progress() < 1.0, "まぶたは途中")
	l.now_ms = l.start_ms + B.LIDS_MS
	eq(l.progress(), 1.0, "LIDS_MS で開ききる")
	ok(l.edge_y(640, 1.0, -1.0) < l.view.position.y and l.edge_y(l.view.end.x, 1.0, 1.0) > l.view.end.y, "開ききると真ん中も端も見える")
	ok(B.LIDS_MS >= 150 and B.LIDS_MS <= 350 and B.POP_IN_MS >= 150 and B.POP_IN_MS <= 350, "切り替わりは 150〜350 ms")
	l.free()
	return true


# Web で「Invalid polygon data, triangulation failed」が出ないこと: まぶたは開き始めから開ききるまで、
# 面積のある四角だけで描く(縁は外の線を越えない)。ヘッドレスの描画は三角に割らないので、形を値で確かめる。
func test_lid_shapes_are_valid() -> bool:
	var l := Lids.new()
	var bad := 0
	for step in 41:
		var o := step / 40.0
		for side: float in [-1.0, 1.0]:
			var oy := l.outer_y(side)
			for q in l.lid_quads(o, side):
				var area := 0.0
				for i in 4:
					area += q[i].cross(q[(i + 1) % 4])
				var inside := (q[0].y >= oy and q[1].y >= oy) if side < 0.0 else (q[0].y <= oy and q[1].y <= oy)
				if q.size() != 4 or absf(area) < 1.0 or not inside or Geometry2D.triangulate_polygon(q).is_empty():
					bad += 1
	eq(bad, 0, "まぶたの四角は全部、面積があり外の線の内側で、三角に割れる")
	ok(l.lid_quads(0.0, -1.0).size() == Lids.STEPS, "閉じた時は上のまぶたが全部の帯で覆う")
	ok(l.lid_quads(1.0, -1.0).is_empty() and l.lid_quads(1.0, 1.0).is_empty(), "開ききると帯は 1 つも無い")
	l.free()
	return true


func test_reduce_flash_stops_motion() -> bool:
	var m := _main(true)
	ok(m.reduce_motion(), "点滅を弱める 入")
	ok(m.current.get_child(0).lit(0) == 1.0, "S0 の題字は灯ったまま")
	TestUi.kp(m, KEY_X)
	ok(m.lids.progress() >= 1.0, "切り替わりの瞬きなし")
	ok(not m.backdrop.animate and m.backdrop.rain, "雨は止まった絵")
	var k0: int = m.current.faint.snap["key"]
	m.current._demo_at -= 10000
	TestUi.frames(m, 3)
	eq(int(m.current.faint.snap["key"]), k0, "タイトルの盤の自機は跳ばない")
	eq(m.current.logo.hum(), 1.0, "題字は息をしない")
	_done(m)
	var n := _main()
	TestUi.kp(n, KEY_X)
	ok(n.backdrop.animate and n.backdrop.rain, "ふだんはタイトルに雨が降る")
	n.current._demo_at -= 10000
	TestUi.frames(n, 1)
	ok(int(n.current.faint.snap["key"]) != B.START_KEY, "ふだんはタイトルの盤の自機が跳ぶ")
	TestUi.kp(n, KEY_ENTER)
	ok(not n.backdrop.rain, "遊ぶ画面に雨は出さない")
	_done(n)
	return true


# 既定で 1 秒に 3 回を超えて明るさが行き来する物を作らない: 濃淡の 1 往復は 333 ms 以上、白く光る敵は 350 ms に 1 回まで。
func test_no_fast_flashing() -> bool:
	ok(B.INVULN_PULSE_MS >= 334, "無敵の濃淡は 1 秒に 3 回まで(%d ms で 1 往復)" % B.INVULN_PULSE_MS)
	ok(B.HUM_MS >= 334 and B.BREATH_MS >= 334, "題字の息・始めるの字の濃淡")
	ok(B.HIT_FLASH_GAP_MS >= 334, "弾が当たった敵の白い光")
	# 無敵の間、自機は消えない(濃淡だけ)・点滅を弱めると一定
	var lo := 1.0
	for t in range(0, 1000, 10):
		lo = minf(lo, Field.invuln_alpha(100, t, false))
		eq(Field.invuln_alpha(100, t, true), B.INVULN_ALPHA_REDUCED, "点滅を弱めると無敵の間も一定(%d ms)" % t)
	ok(lo >= B.INVULN_ALPHA[0] - 0.001 and lo > 0.0, "無敵の間も自機は消えない(一番薄くて %.2f)" % lo)
	eq(Field.invuln_alpha(0, 50, false), 1.0, "無敵でなければ濃い")
	# 弾が続けて当たっても、白く光らせる時刻は HIT_FLASH_GAP_MS に 1 回しか更新しない
	var m := _main()
	TestUi.kp(m, KEY_X)
	TestUi.kp(m, KEY_ENTER)
	var flashes := 0
	var last := -1
	var t0 := Time.get_ticks_msec()
	for k in 15:  # 1 秒に 15 発(弾は 8 tick ごと)
		m.play.on_event({"type": "shot_hit", "id": 7, "x": 400.0, "y": 200.0}, {})
		var at := int(m.play.field.hit_at.get(7, -1))
		if at != last:
			flashes += 1
			last = at
		OS.delay_msec(66)
	var spent := Time.get_ticks_msec() - t0  # 機械が重いと 1 秒より延びる。その分だけ許す
	ok(flashes <= spent / B.HIT_FLASH_GAP_MS + 1 and flashes < 15, "15 発当たっても白い光は %d 回(%d ms)" % [flashes, spent])
	_done(m)
	return true


func test_motion_curves() -> bool:
	eq(Play.count_up(0.0, 100, 1.0 / 60.0, true), 100.0, "点滅を弱めるとすぐ本当の点")
	var s := Play.count_up(0.0, 1000, 1.0 / 60.0, false)
	ok(s > 0.0 and s < 1000.0, "ふだんは数え上がる(%s)" % s)
	eq(Play.count_up(999.5, 1000, 1.0 / 60.0, false), 1000.0, "最後は本当の点に揃う")
	eq(Play.count_up(500.0, 100, 0.016, false), 100.0, "新しい回で点が減ったらすぐ合わせる")
	ok(Play.bump_scale(0) > 1.0 and is_equal_approx(Play.bump_scale(B.BUMP_MS), 1.0), "はねは BUMP_MS で戻る")
	eq(Result.shown_points(1000, 0, false), 0, "結果の点は 0 から")
	eq(Result.shown_points(1000, B.COUNT_MS, false), 1000, "COUNT_MS で数え上がる")
	eq(Result.shown_points(1000, 0, true), 1000, "点滅を弱めると数え上げない")
	eq(Result.sign_k(B.COUNT_MS - 1, false), 0.0, "新しい記録の看板は数え上げの後に灯る")
	eq(Result.sign_k(B.COUNT_MS + B.SIGN_MS, false), 1.0, "SIGN_MS で灯りきる")
	eq(Result.sign_k(0, true), 1.0, "点滅を弱めると最初から灯っている")
	var logo := Logo.new()
	logo.start_ms = 1000
	logo.now_ms = 1000
	eq(logo.lit(0), 0.0, "題字の 1 字目はまだ暗い")
	eq(logo.jump(), -1.0, "三角はまだ跳んでいない")
	logo.now_ms = 1000 + Logo.intro_ms()
	eq(logo.lit(S.NAME.length() - 1), 1.0, "最後の字まで灯った")
	eq(logo.jump(), 1.0, "三角が i の上へ跳んだ")
	var prev := 0.0
	var rising := true
	for t in range(0, B.LOGO_LIGHT_MS + 1, 10):
		logo.now_ms = 1000 + t
		rising = rising and logo.lit(0) >= prev
		prev = logo.lit(0)
	ok(rising, "字の灯りは上がるだけ(消えたり点いたりしない)")
	logo.free()
	return true


func test_new_best_result_has_one_celebration() -> bool:
	var r := Result.new()
	r.build({"score": 500, "wave": 3, "kills": 5, "grazes": 2, "blinks": 9, "lives": 0, "clear": false},
		{"prev_best": {"score": 300}, "new_best": true, "first_today": false}, "KeyBlink x")
	ok(r.new_best, "前の最高を超えたら看板を灯す")
	eq(r._diff, S.RES_NEW_BEST % "200", "看板の字は差の行そのもの(同じ言葉を 2 か所に出さない)")
	eq(r.get_children().filter(func(c: Node) -> bool: return c is Label and String(c.text).contains("新しい記録")).size(), 0,
		"「新しい記録」のラベルを別に置かない")
	r.free()
	var q := Result.new()
	q.build({"score": 500, "wave": 3, "kills": 5, "grazes": 2, "blinks": 9, "lives": 0, "clear": false},
		{"prev_best": null, "new_best": true, "first_today": true}, "KeyBlink x")
	ok(not q.new_best, "初めての回(比べる最高が無い)には灯さない")
	q.free()
	return true
