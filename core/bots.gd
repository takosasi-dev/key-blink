# テスト用の bot 3 種(仕様書 §9.13): 逃げ bot・何もしない bot・下にいる bot。AC-15 と撤退基準 R-2 の判定に使う。
# Driver.feed(sim) を sim.step() の前に毎回呼ぶと、その tick の押すを queue_press する。乱数は sim と別の rng(種 ^ BOT_RNG_XOR)。
# 逃げ bot は人に近づけてある(2026-11-19 依頼者の判断): 出てから BOT_REACT_TICKS 経つまで、その弾・壁・柱の予告を知らない。
# 先読みは BOT_LOOKAHEAD_TICKS: 弾は今の速さのまま直進、壁は今の速さで降りる、柱は今の段の残りのまま進む(予告の残りが先読みの内なら光線に数える)。
extends RefCounted

const B := preload("res://core/balance.gd")
const Rng := preload("res://core/rng.gd")
const Sim := preload("res://core/sim.gd")
const Keys := preload("res://core/keys.gd")

const DODGE := 0
const IDLE := 1
const UNDER := 2


class Driver:
	var kind := 0
	var rng: Rng
	var n := 0

	func _init(p_kind: int, p_seed: int) -> void:
		kind = p_kind
		var s := (p_seed ^ B.BOT_RNG_XOR) & Rng.MASK
		rng = Rng.new(s if s != 0 else 1)

	func feed(sim: Sim) -> void:
		match kind:
			DODGE:
				if danger(sim, sim.ship_x, sim.ship_y):
					var safe: Array[int] = []
					for k in Keys.COUNT:
						if k != sim.key and not danger(sim, Keys.x_of(k), Keys.y_of(k)):
							safe.append(k)
					if not safe.is_empty():
						sim.queue_press(safe[rng.next_int(safe.size())])
			UNDER:
				if n % B.BOT_UNDER_EVERY == 0:
					var k := under_key(sim)
					if k >= 0:
						sim.queue_press(k)
		n += 1

	# (x, y) にいるとして、BOT_LOOKAHEAD_TICKS の間に、知っている弾・壁・柱のどれかに当たるか。
	static func danger(sim: Sim, x: float, y: float) -> bool:
		var la := float(B.BOT_LOOKAHEAD_TICKS)
		var rr: float = B.SHIP_R + B.BULLET_R
		var seen := sim.tick - B.BOT_REACT_TICKS  # この tick までに出た物だけを知っている
		for i in sim.bx.size():
			if sim.bborn[i] > seen:
				continue
			var dx: float = sim.bx[i] - x
			var dy: float = sim.by[i] - y
			var vx: float = sim.bvx[i]
			var vy: float = sim.bvy[i]
			var vv := vx * vx + vy * vy
			var t := 0.0
			if vv > 0.0:
				t = clampf(-(dx * vx + dy * vy) / vv, 0.0, la)
			var cx := dx + vx * t
			var cy := dy + vy * t
			if cx * cx + cy * cy <= rr * rr:
				return true
		for w in sim.walls:
			if int(w["born"]) > seen:
				continue
			# 降りる間に通る範囲を 1 枚の厚い帯にして見る
			var half := B.WALL_GAP / 2.0
			var y0: float = w["y"]
			var y1: float = y0 + float(w["vy"]) * la + B.WALL_H
			var gx: float = w["gx"]
			if Sim.circle_rect(x, y, B.SHIP_R, B.FIELD_LEFT, y0, minf(gx - half, B.FIELD_RIGHT), y1) \
					or Sim.circle_rect(x, y, B.SHIP_R, maxf(gx + half, B.FIELD_LEFT), y0, B.FIELD_RIGHT, y1):
				return true
		for e in sim.enemies:
			if int(e["kind"]) != Sim.PILLAR:
				continue
			var lp: int = e["lp"]
			if lp == Sim.L_WARN and B.LASER_WARN - int(e["lt"]) < B.BOT_REACT_TICKS:
				continue  # 予告が見えてからまだ反応できていない
			if (lp == Sim.L_FIRE or (lp == Sim.L_WARN and int(e["lt"]) <= B.BOT_LOOKAHEAD_TICKS)) and Sim.laser_hits(e, x, y, B.SHIP_R):
				return true
		return false

	# 一番近い敵の真下に一番近い、中の段のキー。敵がいなければ -1。
	static func under_key(sim: Sim) -> int:
		var best: Dictionary = {}
		var best_d := 0.0
		for e in sim.enemies:
			var dx: float = float(e["x"]) - sim.ship_x
			var dy: float = float(e["y"]) - sim.ship_y
			var d := dx * dx + dy * dy
			if best.is_empty() or d < best_d:
				best = e
				best_d = d
		if best.is_empty():
			return -1
		var k_best := Keys.PER_ROW
		for c in Keys.PER_ROW:
			if absf(Keys.column_x(c) - float(best["x"])) < absf(Keys.x_of(k_best) - float(best["x"])):
				k_best = Keys.PER_ROW + c
		return k_best


# 終わるまで遊ばせる(cap tick で打ち切る)。result を返す。
static func play(sim: Sim, kind: int, cap: int = B.STAGE_TICKS) -> Dictionary:
	var d := Driver.new(kind, sim.seed_value)
	while not sim.is_over() and sim.tick < cap:
		d.feed(sim)
		sim.step()
	return sim.result()
