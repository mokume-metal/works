#!/usr/bin/env python3
"""**原典が 2 つ食い違っていないか**を、数値リテラルで突き合わせる。

    python3 scripts/origins.py          # 食い違いを並べる
    python3 scripts/origins.py --check  # 申告していない食い違いがあれば 1 で終わる

Atlas の原典は 2 つある。`processing/processing-examples` の `.pde` と、公式ページが
例ごとに配る `liveSketch.js` (p5.js) である。**この 2 つは 1 行ずつ対応しているはずだが、
そうでない例がある** — `Basics/Arrays/Array` は p5 だけが線を 1 本おきに引き
(`i += 2`)、`Basics/Structure/SetupDraw` は線の初期位置が 180 対 100 で 80 画素ずれている。

比べているのは `.pde` を写した移植と、走らせた p5 なので、**原典どうしが違えば一致率は
移植の出来を表さない**。しかも絵の差が小さいと数字は高いままで、`SetupDraw` は
別の場所に線を引いていても 99% と出る。**数字だけを見ていては気付けない。**
156 本を人が読み比べるのも回らないので、機械に探させる。

**見るのは数値リテラルだけ。** 関数名は言語差 (`pushMatrix` 対 `push`、`s.` の前置き、
メソッドを代入で名乗る p5 の書き方) で雑音が多すぎて、本物が埋もれる。

**`.pde` にだけある数**を主な手掛かりにする。p5 にだけある数は「Processing が暗黙に
持つ 0〜255 の目盛りを p5 が書き出した」類が多く、それ自体は差ではない。

雑音のうち最も多いのは、**p5 が絶対値を面の大きさの割合で書き直したもの**
(`320` 対 `width * 0.5`)。これは機械で畳める — 片側の数がもう片側の数の
`width` 倍か `height` 倍なら、同じものとして両側から落とす。

`upstream/compare/live/` は `scripts/compare/serve.py` が並べるので、**先に一度
serve.py を走らせてから**使う。
"""

import collections
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
COMMENT = re.compile(r"//[^\n]*|/\*.*?\*/", re.S)
NUMBER = re.compile(r"(?<![\w.])(\d+\.\d+|\.\d+|\d+)(?![\w.])")
# 添字や引数の個数として至るところに出るので、差として数えても意味が無い
ORDINARY = {0.0, 1.0, 2.0, 3.0, 4.0}

# **食い違いに見えるが、同じ絵になるもの。** 読んで確かめたものだけを置く。
# ここへ足すときは「なぜ同じなのか」を 1 行で書く (書けないなら食い違いである)
BENIGN: dict[str, str] = {
    "Topics/Fractals and L-Systems/Koch":
        "`radians(60)` と `PI / 3` は同じ角",
    "Topics/Fractals and L-Systems/PenroseTile":
        "基底クラスの `startLength` と `somestep` はどちらの版でも読まれない死んだ値",
}


def numbers(text: str) -> collections.Counter:
    stripped = COMMENT.sub(" ", text)
    found = (float(m.group(1)) for m in NUMBER.finditer(stripped))
    return collections.Counter(v for v in found if v not in ORDINARY)


def fold_ratios(lost: collections.Counter, added: collections.Counter,
                width: int, height: int) -> None:
    """**面の大きさの割合で書き直しただけの数**を、両側から落とす (`320` = `width * 0.5`)。"""
    for absolute in list(lost):
        for ratio in list(added):
            if abs(absolute - ratio * width) < 0.5 or abs(absolute - ratio * height) < 0.5:
                shared = min(lost[absolute], added[ratio])
                lost[absolute] -= shared
                added[ratio] -= shared
                if lost[absolute] <= 0:
                    del lost[absolute]
                if added[ratio] <= 0:
                    del added[ratio]
                break


def declared(entry: dict) -> bool:
    """台帳が「この例は測らない」と申告しているか。**測っていなければ数字は嘘をつけない。**"""
    return entry.get("measure") == "none"


def compare() -> list[dict]:
    shots = json.loads((ROOT / "ledger" / "shots.json").read_text())["shots"]
    live = ROOT / "upstream" / "compare" / "live"
    rows = []
    for example, entry in sorted(shots.items()):
        script = live / f"{entry['slug']}.js"
        pdes = sorted((ROOT / "upstream" / "examples" / example).glob("*.pde"))
        if not script.exists() or not pdes:
            continue
        pde = numbers("\n".join(p.read_text(errors="replace") for p in pdes))
        # p5 は `s.background(…)` と書くので、スケッチの前置きだけ落とす
        js = numbers(re.sub(r"\bs\.", " ", script.read_text(errors="replace")))
        lost, added = pde - js, js - pde
        fold_ratios(lost, added, entry["width"], entry["height"])
        if not lost:
            continue
        rows.append({"example": example, "lost": dict(lost), "added": dict(added),
                     "measure": entry.get("measure"), "declared": declared(entry),
                     "benign": BENIGN.get(example)})
    return rows


def show(found: dict) -> str:
    return " ".join(f"{k:g}" + (f"×{v}" if v > 1 else "") for k, v in sorted(found.items())) or "-"


def main() -> int:
    rows = compare()
    undeclared = [r for r in rows if not r["declared"] and not r["benign"]]
    for row in rows:
        if row["benign"]:
            mark = f"同じもの — {row['benign']}"
        elif row["declared"]:
            mark = "申告済み (測っていない)"
        else:
            mark = "**未申告**"
        print(f"{row['example']}  ({row['measure']})  {mark}")
        print(f"    .pde にだけ: {show(row['lost'])}")
        print(f"    p5 にだけ  : {show(row['added'])}")
    print(f"\n食い違い {len(rows)} 件 / 申告済み {sum(1 for r in rows if r['declared'])} 件"
          f" / 同じもの {sum(1 for r in rows if r['benign'])} 件"
          f" / 未申告 {len(undeclared)} 件", file=sys.stderr)
    if "--check" in sys.argv and undeclared:
        print("原典が食い違うのに測っている。台帳へ measure: none と理由を書くか、"
              "同じものなら BENIGN へ理由を添えて足す", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
