# S5 一時停止(共通 §6・画面設計書 §10)。プレイ画面を暗くした上に、細い管で囲った板を重ねる。続ける・やり直す・設定・タイトルへ。
# Esc で続ける、R でやり直す(板の下に書いてある)。
extends Control

signal picked(what: String)  # "resume" / "restart" / "settings" / "title"

const S := preload("res://core/strings.gd")
const Kit := preload("res://ui/kit.gd")
const Menu := preload("res://ui/menu.gd")
const KeyHint := preload("res://ui/keyhint.gd")

const CARD := Rect2(440, 96, 400, 456)  # 下の余白を上の題と揃える(買った人の目の見直し 2026-11-21)

var menu: Menu


func build() -> void:
	size = Vector2(1280, 720)
	var dim := ColorRect.new()
	dim.color = Color(Kit.C_OUT, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(Kit.place(dim, -2000, -2000, 5280, 4720))  # 窓の余りまで暗く
	var card := Panel.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(Kit.place(card, CARD.position.x, CARD.position.y, CARD.size.x, CARD.size.y))
	card.draw.connect(func() -> void:  # 題の下の短い管
		Kit.neon_line(card, PackedVector2Array([Vector2(160, 86), Vector2(240, 86)]), Kit.C_CYAN, 2.0, 0.8))
	add_child(Kit.place(Kit.label(S.PAUSE, 36, Kit.C_TEXT, 700), CARD.position.x, 118, CARD.size.x, 56))
	var list: Array[Button] = []
	var y := 204.0
	for pair: Array in [["resume", S.B_RESUME], ["restart", S.B_RESTART], ["settings", S.B_SETTINGS], ["title", S.B_TITLE]]:
		var b := Kit.place(Kit.button(pair[0], pair[1], 26), 490, y, 300, 64)
		var what: String = pair[0]
		b.pressed.connect(func() -> void: picked.emit(what))
		add_child(b)
		list.append(b)
		y += 80
	add_child(Kit.place(KeyHint.new([[["Esc"], S.B_RESUME], [["R"], S.B_RESTART]]), 0, 574, 1280, 36))
	menu = Menu.new(list, 0)


func key(ev: InputEventKey) -> void:
	if ev.pressed and not ev.echo and ev.physical_keycode == KEY_ESCAPE:
		picked.emit("resume")
	elif ev.pressed and not ev.echo and ev.physical_keycode == KEY_R:
		picked.emit("restart")
	else:
		menu.key(ev)
