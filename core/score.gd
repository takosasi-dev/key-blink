# 点数の決まりと、点・時間の文字の形(仕様書 §9.8)。点を足すのは sim、値はここと balance.gd。整数だけで計算する。
extends RefCounted

const B := preload("res://core/balance.gd")


# クリアの時のボーナス(残機 × CLEAR_BONUS)。
static func clear_bonus(lives: int) -> int:
	return lives * B.CLEAR_BONUS


# 最高は点で比べる(§9.14)。a が b より良ければ真。
static func better(a: Dictionary, b: Dictionary) -> bool:
	return int(a["score"]) > int(b["score"])


# 残り時間「分:秒」(秒は 2 桁。切り上げ)。tick 0 → "3:00"
@warning_ignore("integer_division")
static func remain_text(tick: int) -> String:
	var left := maxi(B.STAGE_TICKS - tick, 0)
	var sec := (left + B.TICK_HZ - 1) / B.TICK_HZ
	return "%d:%02d" % [sec / 60, sec % 60]


# 3 桁ごとにコンマ。48250 → "48,250"
static func comma(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out
