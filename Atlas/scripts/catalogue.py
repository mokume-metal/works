#!/usr/bin/env python3
"""移した例の一覧を、置いてあるファイルから組み直す。

    python3 scripts/catalogue.py          # Sources/Atlas/Catalogue.swift を書き直す
    python3 scripts/catalogue.py --check  # 台帳と食い違っていないか見る

**手で並べない。** 例が 150 本を超えると、足したのに一覧へ書き忘れた 1 本は
「移していない例」と見分けが付かなくなる (どちらも比較の献立から落ちる)。
置き場そのものを正本にすれば、書き忘れは起こりようがない。

    Sources/Atlas/Examples/<カテゴリ>/<群>/<例>.swift  →  <カテゴリ>/<群>/<例>

**型の名前はファイルから読む。** `Basics/Arrays/Array` のように、例の名前が Swift や
mokume の型とぶつかるものがある。ぶつかったら型だけ改名できるように、綴りを決め打ちせず
`final class 〜: Sketch` を読む。
"""

import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
EXAMPLES = ROOT / "Sources" / "Atlas" / "Examples"
TARGET = ROOT / "Sources" / "Atlas" / "Catalogue.swift"


def entries() -> list[tuple[str, str, pathlib.Path]]:
    """(例名, 型名, ファイル) を、例名の順に並べる。"""
    found = []
    for path in sorted(EXAMPLES.rglob("*.swift")):
        name = "/".join(path.relative_to(EXAMPLES).with_suffix("").parts)
        match = re.search(r"^(?:final )?class (\w+): Sketch\b", path.read_text(), re.M)
        if not match:
            print(f"{path.relative_to(ROOT)}: `final class 〜: Sketch` が見つからない", file=sys.stderr)
            raise SystemExit(1)
        found.append((name, match.group(1), path))
    return found


def render(found: list[tuple[str, str, pathlib.Path]]) -> str:
    lines = [
        "import mokume",
        "",
        "/// 移した例。**scripts/catalogue.py が置き場から組み直す** ので手で並べない。",
        "///",
        "/// 並びは台帳 (`ledger/examples.jsonl`) の例名の順。`Sketch.main()` は",
        "/// `@MainActor static func main()` なので `any Sketch` からは呼べず、例が増えると",
        "/// 起動の分岐も増える。`SketchApplication(sketch:gpu:)` は `any Sketch` を取るので、",
        "/// ここの戻り値をそのまま渡せる (`Sketch.main()` の中身と同じ経路)。",
        "let catalogue: [(name: String, make: () -> any Sketch)] = [",
    ]
    for name, kind, _ in found:
        lines.append(f'    ("{name}", {{ {kind}() }}),')
    lines.append("]")
    return "\n".join(lines) + "\n"


def check(found: list[tuple[str, str, pathlib.Path]]) -> int:
    """台帳と突き合わせる。**数え合わせを手でやらない。**"""
    rows = {json.loads(l)["example"]: json.loads(l)
            for l in (ROOT / "ledger" / "examples.jsonl").read_text().splitlines()}
    problems = []
    have = {name for name, _, _ in found}
    for name in sorted(have):
        if name not in rows:
            problems.append(f"{name}: 移植はあるが、台帳に無い")
        elif not rows[name]["site"]:
            problems.append(f"{name}: 公式ページに載っていない例を移している")
    todo = sorted(n for n, r in rows.items() if r["site"] and r["picture"] != "none" and n not in have)
    for problem in problems:
        print(f"  {problem}", file=sys.stderr)
    print(f"移した {len(have)} 本 / 残り {len(todo)} 本"
          + (f" (先頭 {todo[0]})" if todo else " — 全部移した"), file=sys.stderr)
    return 1 if problems else 0


if __name__ == "__main__":
    found = entries()
    if "--check" in sys.argv:
        raise SystemExit(check(found))
    TARGET.write_text(render(found))
    print(f"{len(found)} 本を {TARGET.relative_to(ROOT)} へ", file=sys.stderr)
    raise SystemExit(check(found))
