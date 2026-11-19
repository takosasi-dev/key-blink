# 30 キーの場所の表(仕様書 §9.2): 段・列・刻印・物理キー(physical_keycode)・画面の位置。
# 表は KeySwat の core/layout.gd の段 1〜3 を写した物(依頼者の許可あり)。位置は x = 124 + (x0 − 1.5 + 列 + 0.5) × 96、y = 452 + 96 × 段。
extends RefCounted

const B := preload("res://core/balance.gd")

const COUNT := 30
const PER_ROW := 10
const LABELS := [
	"Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P",
	"A", "S", "D", "F", "G", "H", "J", "K", "L", ";",
	"Z", "X", "C", "V", "B", "N", "M", ",", ".", "/",
]
# 番号 → physical_keycode(US 配列の上の位置。共通 §3 の 2)
const PHYSICAL := [
	KEY_Q, KEY_W, KEY_E, KEY_R, KEY_T, KEY_Y, KEY_U, KEY_I, KEY_O, KEY_P,
	KEY_A, KEY_S, KEY_D, KEY_F, KEY_G, KEY_H, KEY_J, KEY_K, KEY_L, KEY_SEMICOLON,
	KEY_Z, KEY_X, KEY_C, KEY_V, KEY_B, KEY_N, KEY_M, KEY_COMMA, KEY_PERIOD, KEY_SLASH,
]


@warning_ignore("integer_division")
static func row_of(k: int) -> int:
	return k / PER_ROW


static func col_of(k: int) -> int:
	return k % PER_ROW


static func x_of(k: int) -> float:
	var x0: float = B.KEY_X0[row_of(k)]
	return B.FIELD_LEFT + (x0 - 1.5 + col_of(k) + 0.5) * B.KEY_PITCH


static func y_of(k: int) -> float:
	return B.KEY_ROW_Y0 + B.KEY_PITCH * row_of(k)


# 柱の列・壁の隙間の中心(中の段のキー c の x)。
static func column_x(c: int) -> float:
	return x_of(PER_ROW + c)


static func index_of_physical(code: int) -> int:
	return PHYSICAL.find(code)
