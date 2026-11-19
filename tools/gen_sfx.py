"""効果音 12 個(仕様書 §9.12)を合成して assets/sfx/<名前>.wav に書く。標準ライブラリだけ・乱数は使わない(何度回しても同じバイト列)。
16bit PCM・モノラル・22050 Hz。合計 400 KB 以下(非機能 NFR-7)。

    python tools/gen_sfx.py
"""

import math
import struct
import wave
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "assets" / "sfx"
RATE = 22050
TAU = 2 * math.pi


def tone(buf, at, dur, f0, f1=None, gain=1.0, decay=0.0, square=False):
    """音 1 本を buf に足す。f0→f1 へ直線で動き、exp(-decay*t) で消える。square なら矩形に近い音(奇数倍音 3 本)。"""
    f1 = f1 or f0
    start = int(at * RATE)
    n = int(dur * RATE)
    while len(buf) < start + n:
        buf.append(0.0)
    phase = 0.0
    for i in range(n):
        t = i / RATE
        e = gain * math.exp(-decay * t) * min(1.0, (n - i) / (0.004 * RATE), i / (0.001 * RATE))
        s = math.sin(phase)
        if square:
            s += math.sin(3 * phase) / 3 + math.sin(5 * phase) / 5
        buf[start + i] += e * s
        phase += TAU * (f0 + (f1 - f0) * i / n) / RATE


def write(name, buf, peak):
    top = max(abs(x) for x in buf) or 1.0
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(x / top * peak * 32767)) for x in buf))


def main():
    b = []
    tone(b, 0, 0.08, 1800, 600, decay=30)  # 跳ぶ: 短い「シュン」(高い所から下がる)
    tone(b, 0, 0.05, 3200, 1200, gain=0.3, decay=60)
    write("blink", b, 0.4)
    b = []
    for k, f in enumerate([523, 784, 1047]):
        tone(b, k * 0.05, 0.12, f, decay=18)  # 力が上がった: 上がる音
    write("power_up", b, 0.45)
    b = []
    tone(b, 0, 0.03, 900, 700, square=True, decay=80)  # 弾が敵に当たった: 小さい音
    write("shot_hit", b, 0.2)
    b = []
    tone(b, 0, 0.18, 220, 80, square=True, decay=18)  # 倒した: 破裂の音
    tone(b, 0, 0.06, 1400, 500, gain=0.5, decay=50)
    write("kill", b, 0.5)
    b = []
    tone(b, 0, 0.02, 4200, 3600, decay=120)  # かすり: 「チッ」
    write("graze", b, 0.25)
    b = []
    tone(b, 0, 0.5, 90, 110, square=True, decay=3)  # 柱の予告: 低いうなり
    write("laser_warn", b, 0.3)
    b = []
    tone(b, 0, 0.35, 660, 640, square=True, decay=6)  # 光線
    tone(b, 0, 0.35, 990, 960, gain=0.4, decay=6)
    write("laser_fire", b, 0.35)
    b = []
    tone(b, 0, 0.2, 140, 90, square=True, decay=12)  # 壁が現れる: 低い音
    write("wall_drop", b, 0.45)
    b = []
    tone(b, 0, 0.4, 160, 40, square=True, decay=7)  # 当たった: 重い音
    tone(b, 0, 0.1, 900, 200, gain=0.6, decay=30)
    write("hit", b, 0.6)
    b = []
    tone(b, 0, 0.06, 880, decay=30)  # 波の始め: 短い音
    tone(b, 0.07, 0.08, 1175, decay=30)
    write("wave_start", b, 0.35)
    b = []
    for k, f in enumerate([660, 520, 392, 262]):
        tone(b, k * 0.13, 0.32, f, square=True, decay=6)  # 終わり
    write("over", b, 0.55)
    b = []
    for k, f in enumerate([523, 659, 784, 1047]):
        tone(b, k * 0.1, 0.35, f, decay=6)  # クリア
    write("clear", b, 0.5)
    total = sum(p.stat().st_size for p in OUT.glob("*.wav"))
    print(f"{len(list(OUT.glob('*.wav')))} 個、合計 {total:,} バイト")


if __name__ == "__main__":
    main()
