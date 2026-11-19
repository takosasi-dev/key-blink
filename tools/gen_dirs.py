"""360 の向きの表(cos・sin)を core/dirs.gd に書き出す(共通 §3 の 15・非機能 §5)。core/dirs.gd は手で書き換えない。
値は repr で全桁を書く(Windows・Linux・Web で同じ数になるように、実行時に sin・cos を呼ばない)。

    python tools/gen_dirs.py
"""

import math
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "core" / "dirs.gd"


def main() -> None:
    lines = [
        "# 360 の向きの表(共通 §3 の 15)。DIRS[度] = [cos, sin]。tools/gen_dirs.py が作る。手で書き換えない。",
        "# core は sin・cos を呼ばず、この表で向きを回す(x cos − y sin, x sin + y cos)。",
        "extends RefCounted",
        "",
        "const DIRS := [",
    ]
    for d in range(360):
        r = math.radians(d)
        c, s = math.cos(r), math.sin(r)
        # 0・90・180・270 はちょうどの値にする
        c = round(c) if abs(c - round(c)) < 1e-12 else c
        s = round(s) if abs(s - round(s)) < 1e-12 else s
        lines.append(f"\t[{float(c)!r}, {float(s)!r}],")
    lines += [
        "]",
        "",
        "",
        "# (x, y) を deg 度回す。戻り値は [x, y]。",
        "static func rotate(x: float, y: float, deg: int) -> Array[float]:",
        "\tvar cs: Array = DIRS[posmod(deg, 360)]",
        "\tvar c: float = cs[0]",
        "\tvar s: float = cs[1]",
        "\treturn [x * c - y * s, x * s + y * c]",
        "",
    ]
    OUT.write_text("\n".join(lines), encoding="utf-8", newline="\n")
    print(f"{OUT} に 360 の向きを書いた")


if __name__ == "__main__":
    main()
