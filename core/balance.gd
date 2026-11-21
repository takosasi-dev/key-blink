# 調整値(仕様書 §9.9・INV-7)。時間は tick(1/120 秒)の整数、速さは px/秒で持つ。
# 演出の時間(ms)・設定の段・日替わりの種の値もここに置く。ほかのファイルに数値の調整値を書かない。
extends RefCounted

const TICK_HZ := 120
const MAX_STEPS_PER_FRAME := 8

# 遊ぶ場所(§9.1)
const FIELD_LEFT := 124.0
const FIELD_RIGHT := 1156.0
const FIELD_TOP := 64.0
const FIELD_BOTTOM := 720.0
const KEY_PITCH := 96.0  # キー 1 つの幅(px)
const KEY_ROW_Y0 := 452.0  # 上の段の y
const KEY_X0 := [1.5, 1.75, 2.25]  # 段ごとの始まり(キー幅。KeySwat の layout.gd と同じ段のずれ)
const START_KEY := 13  # F

# 跳ぶ・力(§9.4)
const BLINK_COOLDOWN := 15
const BLINK_COST := 500
const POWER_RATE := 5
const POWER_MAX := 1000
const POWER_STEP := 500  # 弾の強さ = 1 + 力 ÷ これ

# 自機の弾(§9.5)
const FIRE_INTERVAL := 8
const SHOT_SPEED := 900.0
const SHOT_R := 4.0

# 当たり(§9.10)
const SHIP_R := 6.0
const GRAZE_R := 28.0
const LIVES := 3
const INVULN_TICKS := 240

# 敵(§9.6)
const ENEMY_SPEED := 120.0
const ENEMY_SPAWN_Y := -40.0
const BULLET_SPEED := 750.0  # R-2 の調整 2(§9.9 の初期値は 150)
const TEACH_BULLET_RATE := 0.6
const WAVE_SPEED_STEP := 0.05  # 弾の速さの倍率 m(w) = 1 + これ × (w − 1)
const BULLET_R := 6.0
# 種類ごとの値。番号は sim の SMALL・FAN・PILLAR・WALLER
const ENEMY_HP := [3, 14, 10, 10]
const ENEMY_R := [16.0, 24.0, 22.0, 22.0]
const ENEMY_POINTS := [100, 400, 300, 300]
const SMALL_SECOND_SHOT_WAVE := 5  # この波から小物が 2 発目を撃つ
const SMALL_SECOND_SHOT := 150
const SMALL_STAY := 300
const FAN_STOP_Y := 160.0
const FAN_EVERY := 90  # R-2 の調整 2(初期値 180)
const FAN_SHOTS := 8  # R-2 の調整 2(初期値 4)
const FAN_DEG := [0, 15, 345, 30, 330]  # 自機へ向けた向きからの回し(度)。前から出す
const PILLAR_STOP_Y := 100.0
const LASER_WARN := 120
const LASER_FIRE := 60
const LASER_REST := 120
const LASER_ROUNDS := 2
const LASER_W := 144.0
const WALLER_STOP_Y := 100.0
const WALL_EVERY := 360
const WALL_COUNT := 2
const WALL_H := 16.0
const WALL_GAP := 144.0
const WALL_SPEED := 180.0
const WALL_OFFSET_Y := 20.0

# 波と敵の並び(§9.7。波 1〜4 は INV-6: 中身を変えない)
const WAVE_TICKS := 1800
const WAVES := 12
const STAGE_TICKS := 21600
const SPAWN_X_FROM := 172
const SPAWN_X_SPAN := 937
const STOP_Y_FROM := 120
const STOP_Y_SPAN := 181
const SPAWN_T_SPAN := 1440
const TEACH_STOP_Y := 200
const TEACH_X := [484, 772]
const TEACH_T := [60, 360]
const TEACH_LATE_T := 660
const TEACH_LATE_SPAN := 900
const TEACH_FAN_T := 600
const TEACH_PILLAR_T := 300
const TEACH_PILLAR_COL := 3
const TEACH_WALL_T := 300
const BUDGET_BASE := 10
const BUDGET_STEP := 2
const BUDGET_COST := [1, 4, 3, 3]

# 点(§9.8)
const GRAZE_POINTS := 10
const CLEAR_BONUS := 2000

# 上限(§9.10・E-9・E-10)
const BULLET_CAP := 400
const ENEMY_CAP := 40

# 日替わりの種(共通 §3 の 13)
const DAY_SEED_MUL := 2654435761
const DAY_SALT := 0x424C
const EPOCH_YEAR := 2026

# テスト用の bot(§9.13)
const BOT_LOOKAHEAD_TICKS := 24  # 逃げ bot の先読み(2026-11-19 依頼者の判断。元は 30)
const BOT_REACT_TICKS := 24  # 逃げ bot の反応の遅れ: 出てからこの tick が経つまで、その脅威を知らない
const BOT_UNDER_EVERY := 120
const BOT_RNG_XOR := 0x626C6E6B

# 設定(共通 §3 の 17)
const VOLUMES := [0, 25, 50, 75, 100]
const DEFAULT_VOLUME := 75

# 演出(§9.12・画面設計書 §8)。ms と px
const GHOST_MS := 150
const KEY_GLOW_MS := 200
const RING_GLOW_MS := 300
const SHOT_HIT_MS := 50
const SHARD_MS := 400
const SHARDS := 8
const SHARDS_MAX := 320
const FLOAT_MS := 600
const FLOATS_MAX := 24
const FLOAT_RISE_PX := 50
const SPARK_MS := 150
const SPARKS_MAX := 40
const SHAKE_FAN_PX := 4.0
const SHAKE_FAN_MS := 100
const SHAKE_HIT_PX := 8.0
const SHAKE_HIT_MS := 200
const WAVE_NOTE_MS := 1000
const CLEAR_NOTE_MS := 1000
const OVER_MS := 600
const CLEAR_WAIT_MS := 1000
const COUNT_MS := 600
const RETRY_LOCK_MS := 300
const IME_NOTE_MS := 3000
const INVULN_PULSE_MS := 500  # 無敵の間、自機の濃さが 1 往復する時間(v0.3.0: 1 秒に 2 回。前は 100 ms ごとの点滅で 1 秒に 5 回だった)
const INVULN_ALPHA := [0.3, 1.0]  # 往復する濃さ(点滅を弱める 入なら INVULN_ALPHA_REDUCED のまま)
const INVULN_ALPHA_REDUCED := 0.55
const REDUCED_FLASH_ALPHA := 0.2

# 磨きで足した演出(2026-11-20。遊びの決まりは変えない)。ms・tick・不透明度
const TELL_TICKS := 36  # 小物・扇が撃つ前の「ため」の合図を出し始める(撃つ何 tick 前から)
const TRAIL_TICKS := 3.0  # 敵の弾の尾の長さ(何 tick ぶん後ろまで)
const HIT_STOP_MS := 90  # 当たった時に止める時間
const HIT_MARK_MS := 500  # 当たった所に広がる輪
const HIT_TINT_MS := 300  # 当たった時の画面の赤み
const HIT_TINT_ALPHA := 0.3
const HIT_TINT_ALPHA_REDUCED := 0.12  # 点滅を弱める時(共通 §3 の 17: 20% 以下)
const WARN_FILL_ALPHA := [0.04, 0.16]  # 柱の予告の帯の塗り(出始め → 光線の直前)
const DEMO_MS := 700  # タイトルの盤で自機が跳ぶ間隔
const DEMO_KEYS := [16, 2, 25, 19, 13, 7, 21, 11, 28, 13]  # タイトルの盤で跳ぶ順(J E N ; F U X S . F)

# UI の作り直し(v0.3.0)で足した見た目の動き。画面設計書 §10。点滅を弱める 入 では全部止める(動きを減らす設定を兼ねる)。
# どれも既定で 1 秒に 3 回を超えて明るさが行き来しないようにする(題材が「瞬き」でも)
const HIT_FLASH_GAP_MS := 350  # 弾が当たった敵を白く光らせる間隔の下限(弾は 1 秒に 15 発当たるので、毎回光らせると 15 回の明滅になる)
const LIDS_MS := 280  # 画面の切り替わり: 閉じたまぶたが開く
const LIDS_GAP_MS := 450  # この間に次の切り替わりが来たら、まぶたは出さない(連打で明滅を重ねない)
const POP_IN_MS := 160  # 一時停止・設定の板が出る
const POP_RISE_PX := 10.0
const LOGO_STAGGER_MS := 55  # 題字の管が 1 字ずつ灯る間隔
const LOGO_LIGHT_MS := 160  # 1 字が灯りきるまで
const LOGO_JUMP_MS := 260  # 灯った後、自機の三角が K から i の点へ跳ぶ(跳んだ筋が消えるまで)
const HUM_MS := 4000  # 題字の光がゆっくり息をする 1 往復(1 秒に 0.25 回)
const RAIN_SPEED := 70.0  # タイトルの背景の雨の速さ(px/秒)
const RAIN_COUNT := 48
const BREATH_MS := 1800  # 「クリックかキーで始める」の濃淡の 1 往復
const BUMP_MS := 160  # 点・波が変わった時のはね
const BUMP_SCALE := 0.14
const COUNT_UP_RATE := 14.0  # 上の帯の点が本当の点へ追いつく速さ(1 秒あたりの割合)
const SIGN_MS := 320  # 新しい記録の看板が灯る(数え上げが終わってから)
