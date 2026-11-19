# 押したキーをキーの番号(0〜29)へ直す(FR-2・FR-27)。physical_keycode で取り、表は core/keys.gd の PHYSICAL。
# 押しっぱなしの繰り返しと、Ctrl・Alt・Meta と一緒のキーは捨てる(-1)。表に無いキーも -1。
extends RefCounted

const Keys := preload("res://core/keys.gd")


static func index_of(ev: InputEventKey) -> int:
	if not ev.pressed or ev.echo or ev.ctrl_pressed or ev.alt_pressed or ev.meta_pressed:
		return -1
	return Keys.index_of_physical(ev.physical_keycode)
