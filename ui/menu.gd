# キーボードでボタンを選ぶ(共通 §3 の 18)。↑↓ で選び、Enter か Space で押す(押した瞬間に効く)。マウスでも押せる。
# 選んだボタンは型の変種 SelButton(theme.tres。水色の管が灯る)になり、左に自機の三角が乗る(キーの上に居る自機と同じ形)。
# 選びを動かすと select、押すと confirm の小さな音。押した時の動きはボタンの pressed に繋いでおく。
extends RefCounted

const Kit := preload("res://ui/kit.gd")

var buttons: Array[Button] = []
var sel := 0


func _init(list: Array[Button], first: int = 0) -> void:
	buttons = list
	sel = clampi(first, 0, maxi(buttons.size() - 1, 0))
	for b in buttons:
		b.mouse_entered.connect(func() -> void:
			if buttons.find(b) != sel:
				select(buttons.find(b))
				Sfx.play("select"))
		b.pressed.connect(func() -> void: Sfx.play("confirm"))
		b.draw.connect(_mark.bind(b))
	_paint()


func select(i: int) -> void:
	if i < 0 or i >= buttons.size():
		return
	sel = i
	_paint()


func _paint() -> void:
	for k in buttons.size():
		Kit.set_selected(buttons[k], k == sel)


# 選んだボタンの左の三角(押せない間は薄く)。
func _mark(b: Button) -> void:
	if buttons.find(b) != sel:
		return
	var c := Vector2(26.0, b.size.y / 2.0 + 2.0)
	var a := 0.5 if b.disabled else 1.0
	b.draw_circle(c, 13.0, Color(Kit.C_CYAN, 0.12 * a))
	Kit.ship(b, c, 18.0, Color(Kit.C_CYAN, a))


# キーを受ける。使ったら真。
func key(ev: InputEventKey) -> bool:
	if not ev.pressed or ev.echo or buttons.is_empty():
		return false
	match ev.physical_keycode:
		KEY_UP:
			_move(-1)
		KEY_DOWN:
			_move(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			var b := buttons[sel]
			if not b.disabled:
				b.pressed.emit()
		_:
			return false
	return true


func _move(d: int) -> void:
	select((sel + d + buttons.size()) % buttons.size())
	Sfx.play("select")
