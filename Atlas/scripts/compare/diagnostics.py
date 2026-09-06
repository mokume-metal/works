#!/usr/bin/env python3
"""**mokume が「そうしなかった」と言った一言を集める。**

**名前に `warnings` は使えない。** このフォルダは実行時に import の探し先へ入るので、
標準ライブラリの `warnings` を隠して `subprocess` の import ごと壊す (実際に踏んだ)。

    python3 scripts/compare/diagnostics.py  # upstream/compare/warnings.json へ書く
    python3 scripts/compare/publish.py      # 台帳と comparison.md へ載せる

`Basics/Camera/Perspective` を書き出すと mokume はこう言う。

    mokume: perspective(): 写す範囲が潰れている・数でない値が渡されたので、投影を変えませんでした

**言われたとおりにしなかったという申告**である。これを捨てると、台帳には
「98% 一致」という数字だけが残り、絵が食い違っている理由に辿り着けない。
一致率より先に読むべき事実なので、台帳に持たせる。

**例ごとにプロセスを分ける。** mokume は同じ警告を畳むので (`WarningLog`)、
`--render-all` で 157 本をまとめて回すと 1 行しか出ず、**どの例のものか決まらない**
(実測: 同じ例を 3 枚描いても警告は 1 行)。157 回の起動で 2 分ほど。

**見ているのは静止画の書き出しだけ。** `--motion` (道すじを流しながら 157 本 × 24 枚) は
1 プロセスで回しても**警告が 1 種類も出ない**ので、そのために 157 回の起動を足していない。
畳まれるのは同じ種類どうしなので、1 種類も出ないことは「どの例からも出ていない」と言える。
"""

import json
import pathlib
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
OUT = ROOT / "upstream" / "compare" / "warnings.json"
PREFIX = "mokume: "


def binary() -> pathlib.Path:
    """建てた実行ファイル。**`swift run` を 157 回呼ぶと毎回ビルドを確かめに行く。**"""
    subprocess.run(["swift", "build", "-c", "release"], cwd=ROOT, check=True,
                   stdout=subprocess.DEVNULL)
    path = subprocess.run(["swift", "build", "-c", "release", "--show-bin-path"],
                          cwd=ROOT, capture_output=True, text=True, check=True).stdout.strip()
    return pathlib.Path(path) / "Atlas"


def main() -> int:
    atlas = binary()
    examples = [line.strip() for line in subprocess.run(
        [str(atlas), "--list"], cwd=ROOT, capture_output=True, text=True, check=True
    ).stdout.splitlines() if "/" in line]

    found: dict[str, list[str]] = {}
    with tempfile.TemporaryDirectory() as scratch:
        for index, example in enumerate(examples, 1):
            result = subprocess.run(
                [str(atlas), "--render-all", scratch, "1", example.split("/")[-1]],
                cwd=ROOT, capture_output=True, text=True)
            said = [line[len(PREFIX):] for line in result.stderr.splitlines()
                    if line.startswith(PREFIX)]
            if said:
                found[example] = said
                print(f"  {example}: {' / '.join(said)}", file=sys.stderr)
            if index % 40 == 0:
                print(f"  … {index}/{len(examples)}", file=sys.stderr)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(found, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
    print(f"警告を出した例 {len(found)} 本 / {len(examples)} 本 → {OUT.relative_to(ROOT)}",
          file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
