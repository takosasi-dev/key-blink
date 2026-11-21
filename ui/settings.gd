# S4 設定(共通 §6・画面設計書 §10)。音量(5 段)・画面の揺れ・点滅を弱める。変えたらすぐ保存し、音量はその音量で 1 回鳴らす。
# ← → でも値を変えられる。Esc か「戻る」で来た画面へ。各行は左に名前、右に今の値の絵(音量は 5 本の棒と数、入・切はつまみの位置と字)。
# 作りは RootCall の ui/settings.gd。
extends Control

signal back

const B := preload("res://core/balance.gd")
const S := preload("res://core/strings.gd")
const Kit := preload("res://ui/kit.gd")
const Menu := preload("res://ui/menu.gd")
const KeyHint := preload("res://ui/keyhint.gd")

var menu: Menu
var store: RefCounted
var _vol: Button
var _shake: Button
var _flash: Button


func build(p_store: RefCounted) -> void:
	store = p_store
	size = Vector2(1280, 720)
	var card := Panel.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(Kit.place(card, 270, 134, 740, 424))
	add_child(Kit.place(Kit.label(S.SETTINGS, 40, Kit.C_TEXT, 700), 0, 58, 1280, 60))
	_vol = Kit.place(Kit.button("volume", "", 26), 310, 166, 660, 68)
	_shake = Kit.place(Kit.button("shake", "", 26), 310, 250, 660, 68)
	_flash = Kit.place(Kit.button("reduce_flash", "", 26), 310, 334, 660, 68)
	var ret := Kit.place(Kit.button("back", S.B_BACK, 24), 520, 452, 240, 64)
	for b: Button in [_vol, _shake, _flash, ret]:
		add_child(b)
	_vol.draw.connect(_draw_row.bind(_vol, S.SET_VOLUME, "volume"))
	_shake.draw.connect(_draw_row.bind(_shake, S.SET_SHAKE, "shake"))
	_flash.draw.connect(_draw_row.bind(_flash, S.SET_FLASH, "reduce_flash"))
	_vol.pressed.connect(func() -> void: _step_volume(1))
	_shake.pressed.connect(func() -> void: _toggle("shake"))
	_flash.pressed.connect(func() -> void: _toggle("reduce_flash"))
	ret.pressed.connect(func() -> void: back.emit())
	add_child(Kit.place(KeyHint.new([[["up", "down"], S.HINT_SELECT], [["left", "right"], S.HINT_CHANGE], [["Esc"], S.B_BACK]]), 0, 596, 1280, 36))
	menu = Menu.new([_vol, _shake, _flash, ret] as Array[Button], 0)
	_paint()


# 今の値の文字(テストと自動の確かめが読む)。
func value_text(k: String) -> String:
	var st: Dictionary = store.settings()
	if k == "volume":
		return str(int(st["volume"]))
	return S.ON if st[k] else S.OFF


func _paint() -> void:
	for b: Button in [_vol, _shake, _flash]:
		b.queue_redraw()


# 行の名前(左)と今の値の絵(右)。
func _draw_row(b: Button, title: String, k: String) -> void:
	var on_sel := menu != null and menu.buttons[menu.sel] == b
	var jp := Kit.font(700)
	var cy := b.size.y / 2.0
	b.draw_string(jp, Vector2(56, cy + 10), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Kit.C_WHITE if on_sel else Kit.C_TEXT)
	var right := b.size.x - 28.0
	var st: Dictionary = store.settings()
	if k == "volume":
		var v := int(st["volume"])
		var num := Kit.num_font()
		b.draw_string(num, Vector2(right - 52, cy + 11), str(v), HORIZONTAL_ALIGNMENT_RIGHT, 52, 28, Kit.C_TEXT)
		for i in 4:  # 25・50・75・100 の 4 本(0 は全部消える)
			var h := 12.0 + 6.0 * i
			var r := Rect2(right - 140 + i * 18, cy + 14 - h, 10, h)
			if v >= B.VOLUMES[i + 1]:
				b.draw_rect(r, Kit.C_CYAN)
			else:
				b.draw_rect(r, Kit.C_DIM, false, 1.5)
	else:
		var on: bool = st[k]
		var track := Rect2(right - 140, cy - 14, 60, 28)
		var p := Kit.round_rect_points(track, 14.0)
		b.draw_colored_polygon(p, Color(Kit.C_CYAN, 0.25) if on else Kit.C_OUT)
		p.append(p[0])
		b.draw_polyline(p, Kit.C_CYAN if on else Kit.C_DIM, 2.0, true)
		b.draw_circle(Vector2(track.end.x - 14 if on else track.position.x + 14, cy), 9.0, Kit.C_CYAN if on else Kit.C_DIM)
		b.draw_string(jp, Vector2(right - 52, cy + 10), S.ON if on else S.OFF, HORIZONTAL_ALIGNMENT_RIGHT, 52, 26, Kit.C_TEXT if on else Kit.C_DIM)


func _step_volume(d: int) -> void:
	var i: int = B.VOLUMES.find(int(store.settings()["volume"]))
	var v: int = B.VOLUMES[(i + d + B.VOLUMES.size()) % B.VOLUMES.size()]
	store.set_setting("volume", v)
	Sfx.set_volume(v)
	Sfx.play("blink")
	_paint()


func _toggle(k: String) -> void:
	store.set_setting(k, not store.settings()[k])
	_paint()


func key(ev: InputEventKey) -> void:
	if not ev.pressed or ev.echo:
		return
	if ev.physical_keycode == KEY_ESCAPE:
		back.emit()
	elif menu.sel == 0 and ev.physical_keycode in [KEY_LEFT, KEY_RIGHT]:
		_step_volume(-1 if ev.physical_keycode == KEY_LEFT else 1)
	elif menu.sel in [1, 2] and ev.physical_keycode in [KEY_LEFT, KEY_RIGHT]:
		_toggle(["", "shake", "reduce_flash"][menu.sel])
	else:
		menu.key(ev)
