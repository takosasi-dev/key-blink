# 人に見せる結果の文字(仕様書 §9.11・共通 §3 の 12)。3 行。
extends RefCounted

const S := preload("res://core/strings.gd")
const Score := preload("res://core/score.gd")


# mode: 0 = 今日のステージ、1 = 練習。first_today は今日のステージの 1 回目か。date は "2026-11-19"。
static func make(date: String, mode: int, first_today: bool, result: Dictionary) -> String:
	var label: String = S.MODE_DAILY_FIRST if mode == 0 and first_today else S.MODE_LABEL[mode]
	var pts := Score.comma(int(result["score"]))
	var body: String
	if result["clear"]:
		body = S.SHARE_CLEAR % [int(result["lives"]), pts, int(result["grazes"])]
	else:
		body = S.SHARE_WAVE % [int(result["wave"]), pts, int(result["grazes"])]
	return "\n".join([S.SHARE_HEAD % [S.NAME, date, label], body, S.URL])
