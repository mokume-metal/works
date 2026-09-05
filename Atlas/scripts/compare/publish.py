#!/usr/bin/env python3
"""比較の 1 枚を Gyazo へ上げ、台帳と文書を書き戻す。

    python3 scripts/compare/serve.py            # 先に絵を作る (ブラウザで開く)
    python3 scripts/compare/publish.py          # 上げて、ledger/ と README を書き戻す
    python3 scripts/compare/publish.py --check  # 上げずに、鮮度だけ見る
    python3 scripts/compare/publish.py --force  # 撮り直したので上げ直す

**本文の画像行を手で書かない。** 比べる例が 100 本を超えると、撮り直すたびに本文と
画像の対応が腐る。台帳 (`ledger/shots.json`) を正本にして、`ledger/comparison.md` は
丸ごと生成し、README は印で囲った区間だけを差し替える。

**台帳は追記型で、生成物ではない。** 撮り直すと Gyazo の URL が変わるので、同じ入力
から 1 バイト違わず出るのは `comparison.md` の側だけである。撮り直さなければ
`shots.json` は 1 バイトも動かない。

**鮮度検査が見るのはこちら側だけ。** 移植・枚数・測り方・道具の版を変えたのに撮り
直していない、は捕まえられる。原典が変わった、は取ってきたときにしか分からない
(`upstream/` は gitignore 済みで、手元にしか無い)。
"""

import hashlib
import json
import re
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
WORK = ROOT / "upstream" / "compare"
SHOTS = ROOT / "ledger" / "shots.json"
GALLERY = ROOT / "ledger" / "comparison.md"
BEGIN, END = "<!-- compare:begin -->", "<!-- compare:end -->"
TOKEN_REF = "op://Automation/Gyazo API/credential"
# 並べた 1 枚の刷り方の版。**変えたら全部撮り直す** — 指紋に混ぜてあるので
# --check が古い絵を捕まえ、publish が上げ直す
SHEET = "4"


def port_path(example: str) -> pathlib.Path | None:
    """その例の移植。**群ごとのフォルダに分かれていても引ける。**"""
    leaf = example.split("/")[-1]
    found = sorted((ROOT / "Sources" / "Atlas" / "Examples").rglob(f"{leaf}.swift"))
    return found[0] if found else None


def fingerprint(example: str, entry: dict) -> str:
    """撮ったときのこちら側の指紋。**絵を変えうる入力を全部混ぜる。**

    原典 (liveSketch) と mokume の版は混ぜない — 前者は手元にしか無く、後者は例ごとに
    持つと版を上げた瞬間に全行が同時に腐って読めなくなる。どちらも台帳の頭に 1 つ持つ。
    """
    digest = hashlib.sha256()
    port = port_path(example)
    digest.update(port.read_bytes() if port else b"")
    digest.update(f"{entry['frame']}|{entry['measure']}|{entry['width']}x{entry['height']}|{SHEET}".encode())
    return digest.hexdigest()


def upload(path: pathlib.Path, title: str) -> dict:
    """Gyazo へ上げる。**合言葉は引数に置かない** (ps で見えるため設定を標準入力から渡す)。"""
    token = subprocess.run(["secret-read", TOKEN_REF], capture_output=True, text=True, check=True).stdout.strip()
    config = "\n".join([
        'url = "https://upload.gyazo.com/api/upload"',
        f'form = "access_token={token}"',
        f'form = "imagedata=@{path}"',
        f'form = "title={title}"',
        "silent",
    ])
    out = subprocess.run(["curl", "--config", "-"], input=config, capture_output=True, text=True, check=True).stdout
    return json.loads(out)


def load() -> dict:
    if SHOTS.exists():
        return json.loads(SHOTS.read_text())
    return {"comment": "scripts/compare/publish.py が書く。人が書くのは frame / measure / why / note / featured だけ",
            "tool": {}, "shots": {}}


def save(book: dict) -> None:
    SHOTS.write_text(json.dumps(book, ensure_ascii=False, indent=2, sort_keys=True) + "\n")


def mokume_version() -> str:
    resolved = json.loads((ROOT / "Package.resolved").read_text())
    return next(p for p in resolved["pins"] if p["identity"] == "mokume")["state"]["version"]


def collect() -> tuple[dict, dict]:
    stats = json.loads((WORK / "stats.json").read_text())
    menu = {m["example"]: m for m in json.loads((WORK / "menu.json").read_text())["compare"]}
    return stats, menu


def publish(force: bool) -> int:
    book = load()
    stats, menu = collect()
    book["tool"] = {
        "mokume": mokume_version(),
        "p5": "1.9.4",
        "reference": json.loads((ROOT / "ledger" / "sources.json").read_text())["reference"]["sha"],
    }
    uploaded = 0
    for example, measured in sorted(stats.items()):
        if measured.get("status") != "ok":
            continue
        entry = dict(book["shots"].get(example, {}))
        entry.update({
            "slug": menu[example]["slug"], "group": menu[example]["group"],
            "class": menu[example]["class"], "origin": menu[example]["origin"],
            "frame": measured["frame"], "measure": measured["measure"],
            "width": measured["width"], "height": measured["height"],
        })
        if measured.get("why"):
            entry["why"] = measured["why"]
        # **測れないと言った例に数字を付けない。** 付けると乱数の例が実行のたびに違う
        # 数を出し、台帳が意味もなく動く。読み手も 0% を「まったく違う」と読んでしまう
        if measured["measure"] == "none":
            entry.pop("diff", None)
        elif measured.get("diff"):
            entry["diff"] = {k: round(v, 4) for k, v in measured["diff"].items()}

        mark = fingerprint(example, entry)
        if not force and entry.get("url") and entry.get("source") == mark:
            book["shots"][example] = entry
            continue
        shot = WORK / "shots" / f"{entry['slug']}.png"
        if not shot.exists():
            print(f"  {example}: 撮った絵が無い", file=sys.stderr)
            continue
        result = upload(shot, f"{example} — 原典と mokume")
        entry["url"] = result["url"]
        entry["sha256"] = hashlib.sha256(shot.read_bytes()).hexdigest()
        entry["source"] = mark
        book["shots"][example] = entry
        uploaded += 1
        print(f"  {example} → {result['url']}", file=sys.stderr)
        # 1 枚ごとに書く。**まとめて最後に書くと、途中で落ちたときに上げたのに
        # URL を失った絵が Gyazo に残る**
        save(book)
    save(book)
    write_gallery(book)
    write_readme(book)
    print(f"上げた {uploaded} 枚 / 台帳 {len(book['shots'])} 件", file=sys.stderr)
    return 0


def rows(book: dict) -> list[tuple[str, dict]]:
    return sorted(book["shots"].items())


# **どれが「同じ絵」かは機械が決めない。** 数と並べた 1 枚を出すところまでが仕事で、
# 見て決めるのは人である。測り方そのものは scripts/compare/index.html のコメントが正本。


def bucket(book: dict) -> dict[str, int]:
    counts = {"pixel": 0, "resampled": 0, "none": 0}
    for _, entry in rows(book):
        counts[entry["measure"]] += 1
    return counts


def bands(book: dict) -> list[tuple[str, int]]:
    """その場で一致した割合の分布。**線を引かず、並べるだけ。**"""
    scores = [e["diff"]["near"] for _, e in rows(book) if e.get("diff")]
    edges = [(100.0, "100%"), (99.0, "99% 以上"), (95.0, "95% 以上"), (90.0, "90% 以上"), (0.0, "90% 未満")]
    out, rest = [], sorted(scores, reverse=True)
    seen = 0
    for i, (low, label) in enumerate(edges):
        high = 101.0 if i == 0 else edges[i - 1][0]
        n = sum(1 for s in rest if (s >= low if i == 0 else low <= s < high))
        out.append((label, n)); seen += n
    return out


def write_gallery(book: dict) -> None:
    """全数の置き場。**丸ごと生成物**なので手で直さない。"""
    groups: dict[str, list] = {}
    for example, entry in rows(book):
        groups.setdefault(entry["group"], []).append((example, entry))

    counts = bucket(book)
    out = [
        "# 原典と並べた全数",
        "",
        "<!-- scripts/compare/publish.py が書く。手で直さない -->",
        "",
        f"移した {len(book['shots'])} 本を、原典と並べて突き合わせたもの。原典は"
        " processing-website が例ごとに配る `liveSketch.js` (Processing 版と 1 行ずつ"
        "対応した p5.js) を走らせたもので、**条件を 3 つ揃えてある** — マウスを動かさない"
        "・決めた枚数で止める・等倍。",
        "",
        f"画素で測れたのが {counts['pixel']} 本、原典が静止画しか無くて参考値なのが"
        f" {counts['resampled']} 本、測らないと決めたのが {counts['none']} 本"
        " (乱数・時計・書体を使う例は、原典と mokume で列が違うので一致率に意味が無い)。",
        "",
        f"道具は mokume v{book['tool']['mokume']} / p5.js {book['tool']['p5']}。",
        "",
        "| 群 | 本数 | 測った | その場で一致の中央値 |",
        "| --- | ---: | ---: | ---: |",
    ]
    for group, items in sorted(groups.items()):
        measured = [e["diff"]["near"] for _, e in items if e.get("diff")]
        median = f"{sorted(measured)[len(measured) // 2]:.1f}%" if measured else "—"
        anchor = group.lower().replace("/", "").replace(" ", "-")
        out.append(f"| [{group}](#{anchor}) | {len(items)} | {len(measured)} | {median} |")
    out.append("")

    for group, items in sorted(groups.items()):
        out += [f"## {group}", "",
                "| 例 | 台帳 | その場で一致 | 半画素ずらして | 形が一致 | 完全一致 | 差はどこから | 並べた 1 枚 |",
                "| --- | --- | ---: | ---: | ---: | ---: | --- | --- |"]
        for example, entry in items:
            leaf = example.split("/")[-1]
            diff = entry.get("diff")
            if diff:
                near, half = f"{diff.get('near', 0):.1f}%", f"{diff.get('half', 0):.1f}%"
                shape, same = f"{diff.get('shape', 0):.1f}%", f"{diff['same']:.1f}%"
            else:
                near = half = shape = same = "—"
            why = entry.get("note") or entry.get("why") or ""
            out.append(f"| `{leaf}` | `{entry['class']}` | {near} | {half} | {shape} | {same}"
                       f" | {why} | [見る]({entry['url']}) |")
        out.append("")
    GALLERY.write_text("\n".join(out) + "\n")


def write_readme(book: dict) -> None:
    """README の印で囲った区間だけを差し替える。区間の外は人が書く。"""
    path = ROOT / "README.md"
    text = path.read_text()
    if BEGIN not in text or END not in text:
        print("README に compare の印が無い。区間を作ってから", file=sys.stderr)
        return
    counts = bucket(book)
    total = len(book["shots"])
    body = [
        "",
        "| その場で一致 | 本数 |",
        "| --- | ---: |",
    ]
    for label, n in bands(book):
        body.append(f"| {label} | {n} |")
    body += [
        f"| 測らない (乱数・時計・書体) | {counts['none']} |",
        "",
        f"移した {total} 本ぶん。うち {counts['resampled']} 本は原典が静止画しかなく、"
        "縮めて比べているので参考値。**どれが「同じ絵」かは決めていない** — 数と並べた"
        " 1 枚を出すところまでが機械の仕事で、見て決めるのは人である。",
        "",
        "全数は [`ledger/comparison.md`](ledger/comparison.md)。",
        "",
    ]
    for example, entry in rows(book):
        if entry.get("featured"):
            body.append(f"![{example} — 原典と mokume]({entry['url']})")
            body.append("")
    head, _, rest = text.partition(BEGIN)
    _, _, tail = rest.partition(END)
    text = head + BEGIN + "\n".join(body) + END + tail

    # **文章の途中に置く 1 枚も、書くのはこちら。** 掘り下げの節は人が書くが、そこへ
    # 貼る絵の URL まで人が書くと、撮り直したときに本文だけが古い絵を指す。
    # `<!-- compare:image <例名> -->` と書いておけば、次の行をこちらが差し替える
    def place(match: "re.Match[str]") -> str:
        example = match.group(1).strip()
        entry = book["shots"].get(example)
        if not entry or not entry.get("url"):
            return match.group(0)
        return f"<!-- compare:image {example} -->\n![{example} — 原典と mokume]({entry['url']})\n"

    text = re.sub(r"<!-- compare:image (.+?) -->\n(?:!\[[^\]]*\]\([^)]*\)\n)?", place, text)
    path.write_text(text)


def check() -> int:
    """撮り直していないものを捕まえる。**画像そのものは比較しない。**"""
    book = load()
    problems: list[str] = []
    if book.get("tool", {}).get("mokume") != mokume_version():
        problems.append(f"道具を上げたのに撮り直していない (台帳 {book.get('tool', {}).get('mokume')} / いま {mokume_version()})")
    for example, entry in rows(book):
        if entry.get("source") != fingerprint(example, entry):
            problems.append(f"{example}: 移植か測り方を変えたのに撮り直していない")
        if entry["measure"] == "none" and entry.get("diff"):
            problems.append(f"{example}: 測れないと言った例に数字が付いている")
        if entry.get("url") and entry["url"] not in GALLERY.read_text():
            problems.append(f"{example}: 台帳にある絵が comparison.md に出ていない")
    readme = (ROOT / "README.md").read_text()
    for example in re.findall(r"<!-- compare:image (.+?) -->", readme):
        entry = book["shots"].get(example.strip())
        if not entry or entry.get("url", "") not in readme:
            problems.append(f"{example}: README が指す絵が台帳に無い / 貼られていない")
    listed = {line.strip() for line in subprocess.run(
        ["swift", "run", "-c", "release", "Atlas", "--list"], cwd=ROOT, capture_output=True, text=True, check=True
    ).stdout.splitlines() if "/" in line}
    for example in sorted(set(book["shots"]) - listed):
        problems.append(f"{example}: 台帳にあるが、移植が無い")
    for problem in problems:
        print(f"  {problem}", file=sys.stderr)
    print(f"{'古い' if problems else '全部新鮮'} — {len(book['shots'])} 件を見た", file=sys.stderr)
    return 1 if problems else 0


if __name__ == "__main__":
    if "--check" in sys.argv:
        raise SystemExit(check())
    raise SystemExit(publish(force="--force" in sys.argv))
