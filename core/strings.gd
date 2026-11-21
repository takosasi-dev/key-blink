# 画面に出す文言(INV-7・画面設計書 §6)。文言はここだけに置く。
# 文言を足したら tools/subset_font.py を回し直す(同梱の字体はここの文字に絞ってある)。
extends RefCounted

const NAME := "KeyBlink"
const VERSION := "v0.3.0"
const URL := "https://takosasi-dev.github.io/key-blink/"

# S0(共通 §6)
const S0_START := "クリックかキーで始める"
const S0_KEYBOARD := "キーボードで遊ぶゲーム"
const TOUCH := "このゲームはキーボードで遊ぶ。PC で開いてほしい"
const IME := "日本語入力を切って(半角英数で)遊んでほしい"

# S1 タイトル
const TAGLINE := "押したキーの場所へ、一瞬で跳ぶ"
const B_DAILY := "今日のステージ"
const B_PRACTICE := "練習(毎回ちがう並び)"
const B_SETTINGS := "設定"
const REC_FIRST := "1回目 %s%s点"
const REC_CLEAR := "クリア "
const REC_TODAY_BEST := "今日の最高 %s点"
const REC_BEST := "最高 %s点"
const REC_NONE := "まだ遊んでいない"
const LOAD_FAILED := "保存を読めなかったので、記録を初めからにした"

# S2 プレイ
const ESC := "Esc"
const BAR_POINTS := "%s点"
const BAR_WAVE := "波 %d  %s"
const BAR_POWER := "力"
const WAVE_NOTE := "波 %d"
const CLEAR := "クリア"
const FLOAT := "+%s"

# S3 結果
const RES_CLEAR := "クリア(残機 %d)"
const RES_WAVE := "波 %d で終わった"
const RES_POINTS := "%s点"
const RES_NEW_BEST := "最高 +%s(新しい記録)"
const RES_TO_BEST := "最高まで −%s"
const RES_WAVES := "届いた波 %d"
const RES_KILLS := "倒した数 %d"
const RES_GRAZES := "かすり %d"
const RES_BLINKS := "跳んだ回数 %d"
const B_RETRY := "もう1回"
const B_COPY := "コピー"
const B_TITLE := "タイトルへ"
const COPIED := "コピーを試した。貼れない時は枠から写す"
const SAVE_FAILED := "このブラウザでは記録を残せない"

# 共有する文字(§9.11)
const SHARE_HEAD := "%s %s(%s)"
const SHARE_CLEAR := "クリア 残機 %d / %s点 / かすり %d"
const SHARE_WAVE := "波 %d まで / %s点 / かすり %d"
const MODE_DAILY_FIRST := "今日のステージ・1回目"
const MODE_LABEL := ["今日のステージ", "練習"]

# S4 設定・S5 一時停止(共通 §6)
const SETTINGS := "設定"
const SET_VOLUME := "音量"
const SET_SHAKE := "画面の揺れ"
const SET_FLASH := "点滅を弱める"
const ON := "入"
const OFF := "切"
const B_BACK := "戻る"
const PAUSE := "一時停止"
const B_RESUME := "続ける"
const B_RESTART := "やり直す"

# 画面の下のキーの案内(v0.3.0。キーの形は ui/keyhint.gd が描く)
const HINT_SELECT := "選ぶ"
const HINT_OK := "決める"
const HINT_CHANGE := "変える"

# キーの確かめ(共通 §3 の 22)
const KEYS_TITLE := "キーの確かめ(押したキーを下に出す。Esc 2 回でタイトルへ)"
