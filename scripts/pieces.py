#!/usr/bin/env python3
"""作品の並びと、その版。

**1 作品 = 1 フォルダ = 1 SwiftPM パッケージ**なので (ルート README)、直下で
`Package.swift` を持つディレクトリがそのまま作品の一覧になる。作品が増えても
この関数は何も知らずに拾う。

    from pieces import pieces, pinned

**作品は普通に作った例として置いてあるので、再現を機械で測る仕掛けは持たない** (ルート
README の「並べ方」)。台帳 (`checks.json`) と README の生成区間を扱う口は、台帳を持つ
Atlas と一緒に [probes](https://github.com/mokume-metal/probes) へ移した。
"""

import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent


def pieces() -> list[pathlib.Path]:
    """作品のフォルダ。並びは名前順で固定する (出力を読む側が予測できるように)。"""
    return sorted(p.parent for p in ROOT.glob("*/Package.swift"))


def piece(name: str) -> pathlib.Path:
    """名前から作品のフォルダ。大文字小文字は問わない。"""
    for path in pieces():
        if path.name.lower() == name.lower():
            return path
    raise SystemExit(f"そんな作品は無い: {name} (あるのは {', '.join(p.name for p in pieces())})")


def pinned(path: pathlib.Path) -> dict[str, str]:
    """`Package.resolved` がいま固定している mokume の版と revision。"""
    resolved = json.loads((path / "Package.resolved").read_text())
    pin = next(p for p in resolved["pins"] if p["identity"] == "mokume")
    return {"version": pin["state"]["version"], "revision": pin["state"]["revision"]}


def declared(path: pathlib.Path) -> str:
    """`Package.swift` が `from:` で名乗っている版。

    **留め金ではなく記録である** — SwiftPM の `from:` は 0.x を特別扱いしないので、
    古いまま置いても `swift package update` は新しい版を拾う (works#22 で実測)。
    実際に固定しているのは `Package.resolved` のほう。
    """
    for line in (path / "Package.swift").read_text().splitlines():
        if "from:" in line:
            return line.split('from:')[1].strip().strip('")],').strip('"')
    raise SystemExit(f"{path.name}/Package.swift に from: が無い")
