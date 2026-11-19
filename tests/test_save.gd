# 保存のテスト(仕様書 §9.14・AC-17・E-12・E-15・NFR-9)。テストでは user:// の別のファイルを使う。
extends "res://tests/suite.gd"

const Store := preload("res://save/save_store.gd")
const P := "user://test_save.json"


func _fresh(text: Variant = null) -> Store:
	if FileAccess.file_exists(P):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(P))
	if text != null:
		var f := FileAccess.open(P, FileAccess.WRITE)
		f.store_string(text)
		f.close()
	return Store.new(P)


static func rec(score: int, clear: bool = true, lives: int = 2) -> Dictionary:
	return {"score": score, "clear": clear, "lives": lives}


func test_ac17_empty_broken_version() -> bool:
	var st := _fresh()
	eq(st.data, Store.defaults(), "空")
	ok(not st.load_failed, "空は失敗ではない")
	st = _fresh("{not json")
	eq(st.data, Store.defaults(), "壊れた JSON")
	ok(st.load_failed, "壊れた時は知らせる(E-12)")
	st = _fresh('{"version": 2, "practice_best": {"score": 5, "clear": true, "lives": 1}}')
	eq(st.data, Store.defaults(), "version が 2")
	ok(st.load_failed, "知らない version も知らせる")
	eq(Store.default_settings(), {"volume": 75, "shake": true, "reduce_flash": false}, "既定値: 音量 75・揺れ 入・点滅を弱める 切")
	return true


func test_practice_best() -> bool:
	var st := _fresh()
	var r1 := st.record(1, 322, rec(52300, true, 1))
	ok(r1["new_best"] and r1["prev_best"] == null, "初めての最高")
	var r2 := st.record(1, 322, rec(7000, true, 3))
	ok(not r2["new_best"], "低い点は最高にしない(残機が多くても)")
	eq(Store.new(P).practice_best(), rec(52300, true, 1), "読み直しても残る")
	return true


func test_daily_first_and_best() -> bool:
	var st := _fresh()
	var a := st.record(0, 322, rec(48250))
	ok(a["first_today"], "1 回目")
	st.record(0, 322, rec(50100))
	var d := Store.new(P).daily(322)
	eq(d["first"], rec(48250), "1 回目は残る")
	eq(d["best"], rec(50100), "最高")
	var b := st.record(0, 323, rec(5000, false, 0))
	ok(b["first_today"], "日付が変われば作り直す")
	eq(Store.new(P).daily(322)["first"], null, "前の日の記録は消える")
	return true


func test_e15_old_day_does_not_overwrite() -> bool:
	var st := _fresh()
	st.record(0, 323, rec(5000))
	var r := st.record(0, 322, rec(9999))
	ok(not r["first_today"] and not r["new_best"], "古い日の回は記録しない")
	eq(Store.new(P).daily(323)["best"], rec(5000), "新しい日のまま")
	return true


func test_settings_persist_and_bad_values() -> bool:
	var st := _fresh()
	st.set_setting("volume", 25)
	st.set_setting("shake", false)
	eq(Store.new(P).settings(), {"volume": 25, "shake": false, "reduce_flash": false}, "設定が残る")
	st = _fresh('{"version": 1, "settings": {"volume": 33, "shake": "yes"}, "practice_best": {"score": 5, "clear": "x", "lives": 1}}')
	eq(st.settings(), Store.default_settings(), "おかしな値は既定値")
	eq(st.practice_best(), null, "おかしな記録は無し")
	ok(not st.load_failed, "形は読めた")
	return true


func test_save_shape_matches_spec() -> bool:
	var st := _fresh()
	st.record(0, 322, rec(48250))
	var j := JSON.new()
	eq(j.parse(FileAccess.get_file_as_string(P)), OK, "JSON で書く")
	var keys: Array = j.data.keys()
	keys.sort()
	eq(keys, ["daily", "practice_best", "settings", "version"], "§9.14 の形")
	var first: Dictionary = j.data["daily"]["first"]
	var fk: Array = first.keys()
	fk.sort()
	eq(fk, ["clear", "lives", "score"], "記録は score・clear・lives")
	ok(FileAccess.get_file_as_string(P).length() <= 2048, "2 KB 以下")
	eq(Store.WEB_KEY, "key-blink/save", "localStorage のキー名(INV-8)")
	return true
