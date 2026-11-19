# 日付・共有する文字・点の文字のテスト(AC-16・§9.11・共通 §3 の 13)。
extends "res://tests/suite.gd"

const Day := preload("res://core/day_index.gd")
const Share := preload("res://core/share_text.gd")
const Score := preload("res://core/score.gd")


func test_ac16_day_index() -> bool:
	eq(Day.day_index(2026, 1, 1), 0, "2026-01-01 → 0")
	eq(Day.day_index(2026, 11, 19), 322, "2026-11-19 → 322")
	eq(Day.day_index(2027, 1, 1), 365, "2027-01-01 → 365")
	eq(Day.day_index(2025, 12, 31), 0, "2025-12-31 → 0(E-16)")
	return true


func test_day_seed() -> bool:
	eq(Day.day_seed(322), (323 * 2654435761 + 0x424C) & 0xFFFFFFFF, "共通 §3 の 13 の式(SALT 0x424C)")
	ok(Day.day_seed(0) != Day.day_seed(1), "日で違う")
	return true


func test_ac16_share_text_exact() -> bool:
	var r := {"score": 48250, "clear": true, "lives": 2, "wave": 12, "kills": 83, "grazes": 132, "blinks": 214}
	eq(Share.make("2026-11-19", 0, true, r),
		"KeyBlink 2026-11-19(今日のステージ・1回目)\nクリア 残機 2 / 48,250点 / かすり 132\nhttps://takosasi-dev.github.io/key-blink/", "§9.11 の形")
	ok(Share.make("2026-11-19", 0, false, r).begins_with("KeyBlink 2026-11-19(今日のステージ)\n"), "2 回目以降は「今日のステージ」")
	ok(Share.make("2026-11-19", 1, false, r).begins_with("KeyBlink 2026-11-19(練習)\n"), "練習")
	var lost := {"score": 1200, "clear": false, "lives": 0, "wave": 7, "kills": 5, "grazes": 9, "blinks": 30}
	eq(Share.make("2026-11-19", 1, false, lost).split("\n")[1], "波 7 まで / 1,200点 / かすり 9", "クリアでない時")
	return true


func test_remain_and_comma() -> bool:
	eq(Score.remain_text(0), "3:00", "始め")
	eq(Score.remain_text(B.STAGE_TICKS - 1), "0:01", "残り 1 tick は 0:01")
	eq(Score.remain_text(B.STAGE_TICKS), "0:00", "終わり")
	eq(Score.remain_text(120 * 68), "1:52", "1:52")
	eq(Score.comma(0), "0", "0")
	eq(Score.comma(999), "999", "3 桁")
	eq(Score.comma(1234567), "1,234,567", "3 桁ごと")
	return true
