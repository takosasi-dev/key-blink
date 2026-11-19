# bot 3 種を種 1〜10 で回し、クリアしたか・残機・届いた波・倒した数・かすり・跳んだ回数・終わった tick を印字する(§8.2・AC-15・R-2 を見る道具)。
# 逃げ bot は、画面の弾の最大と、危ない step で安全だったキーの数の最少も出す(R-2 の根拠)。
# 実行: python tools/gd.py run res://tools/bot_report.gd
extends SceneTree

const Sim := preload("res://core/sim.gd")
const Bots := preload("res://core/bots.gd")
const Keys := preload("res://core/keys.gd")
const NAMES := ["逃げ", "何もしない", "下にいる"]


func _initialize() -> void:
	var r2 := 0
	var idle_max := 0
	for s in range(1, 11):
		var row := "種 %2d:" % s
		var extra := ""
		for k in 3:
			var t0 := Time.get_ticks_msec()
			var sim := Sim.new(s, Sim.MODE_PRACTICE)
			var r: Dictionary
			if k == Bots.DODGE:
				var d := Bots.Driver.new(k, s)
				var max_b := 0
				var min_safe := Keys.COUNT
				while not sim.is_over():
					if Bots.Driver.danger(sim, sim.ship_x, sim.ship_y):
						var c := 0
						for j in Keys.COUNT:
							if not Bots.Driver.danger(sim, Keys.x_of(j), Keys.y_of(j)):
								c += 1
						min_safe = mini(min_safe, c)
					d.feed(sim)
					sim.step()
					max_b = maxi(max_b, sim.bx.size())
				r = sim.result()
				extra = "  [逃げ: 弾の最大 %d、危ない時の安全なキーの最少 %d]" % [max_b, min_safe]
			else:
				r = Bots.play(sim, k)
			row += "  %s %s 残機 %d 波 %2d 倒 %3d かすり %4d 跳 %4d tick %5d 点 %6d (%d ms)" % [NAMES[k], "クリア" if r["clear"] else "負け  ",
				r["lives"], r["wave"], r["kills"], r["grazes"], r["blinks"], r["ticks"], r["score"], Time.get_ticks_msec() - t0]
			if k == Bots.DODGE and r["clear"] and int(r["lives"]) >= 2:
				r2 += 1
			if k == Bots.IDLE:
				idle_max = maxi(idle_max, int(r["ticks"]) if not r["clear"] else 999999)
		print(row + extra)
	print("R-2(逃げ bot が残機 2 以上でクリアした種): %d 個 / 10(8 個以上で当たり)" % r2)
	print("AC-15(何もしない bot が残機 0 になった一番遅い tick): %d(10800 = 90 秒以内なら通る)" % idle_max)
	quit()
