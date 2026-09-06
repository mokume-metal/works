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

**`measure` が `none` の例は、回すたびに絵が変わる** (乱数・雑音・時計を使うため)。
指紋は「移植と測り方」で作ってあるので上げ直さない — `sha256` は**上げたバイト列**を
指しており、手元の絵と食い違うのが正しい。ここを絵そのもので見張ると、38 本が毎回
上がり直して台帳が意味もなく動く。

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
RENDERS = ROOT / "ledger" / "renders.txt"
BEGIN, END = "<!-- compare:begin -->", "<!-- compare:end -->"
TOKEN_REF = "op://Automation/Gyazo API/credential"
# 並べた 1 枚の刷り方の版。**変えたら全部撮り直す** — 指紋に混ぜてあるので
# --check が古い絵を捕まえ、publish が上げ直す
SHEET = "4"
# 動きの証跡の版。合成の仕方や枚数を変えたら上げる
MOTION = "1"
# 動きを撮った枚数 (scripts/compare/serve.py の MOTION_FRAMES と揃える)
MOTION_FRAMES = 24


def blankness(entry: dict) -> str | None:
    """どちらの面が背景だけだったか。`scripts/compare/index.html` の同名の関数と同じ判定。"""
    drawn = entry.get("ink")
    if not drawn:
        return None
    if drawn["origin"] == 0 and drawn["port"] == 0:
        return "both"
    if drawn["origin"] == 0:
        return "origin"
    if drawn["port"] == 0:
        return "port"
    return None


def reason(entry: dict) -> str:
    """測らない理由。**撮るたびに描かれた量から作り直す** — 台帳へは文を置かない。"""
    if blankness(entry) == "origin":
        return "原典が 1 画素も描かなかった。mokume だけが描いている"
    return entry.get("why") or "原典と条件が揃わない"


def caption(entry: dict) -> str:
    """シートと `comparison.md` に刷る 1 行。**指紋にも混ぜる。**

    指紋は移植と frame と measure から作っていたので、**測り方を変えて数字が動いても
    指紋は動かず、古い絵が上がったまま残った**。刷る文そのものを混ぜれば、数字が変われば
    必ず上げ直しになる。逆に乱数の例は絵が毎回変わっても文は変わらないので、
    意味の無い上げ直しが起きない。
    """
    diff = entry.get("diff")
    if not diff:
        return f"**測らない** — {reason(entry)}"
    line = (f"その場 **{diff['near']:.1f}%** ・ 半画素 {diff.get('half', 0):.1f}%"
            f" ・ 形 {diff.get('shape', 0):.1f}% ・ 完全 {diff['same']:.1f}%")
    blank = blankness(entry)
    if blank == "both":
        line += " ・ どちらも背景だけ"
    elif blank == "port":
        line += " ・ **mokume は 1 画素も描いていない**"
    return line


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
    digest.update(caption(entry).encode())
    return digest.hexdigest()


def motion_fingerprint(example: str) -> str:
    """動きの証跡の指紋。**静止画とは別に持つ** — 撮り方も枚数も違う。"""
    digest = hashlib.sha256()
    port = port_path(example)
    digest.update(port.read_bytes() if port else b"")
    digest.update(f"{MOTION_FRAMES}|{MOTION}".encode())
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


def diagnostics() -> dict[str, list[str]] | None:
    """`scripts/compare/diagnostics.py` が集めた、mokume の一言。

    **無ければ None を返す。** 集めていない回に台帳から消してしまうと、警告を残すために
    毎回 157 回の起動が要ることになる。
    """
    path = WORK / "warnings.json"
    return json.loads(path.read_text()) if path.exists() else None


def publish(force: bool) -> int:
    book = load()
    stats, menu = collect()
    said = diagnostics()
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
        # **描かれた量。** 一致率が「背景が揃っただけ」でないことの裏付けで、
        # 測らない理由もここから作り直す (理由そのものは台帳へ置かない — 絵が出る
        # ようになっても文だけが残り、台帳が古い話をし続ける)
        if measured.get("ink"):
            entry["ink"] = measured["ink"]
        else:
            entry.pop("ink", None)
        # **mokume が「そうしなかった」と言った一言。** 一致率より先に読むべき事実なので
        # 台帳に持つ。集めていない回は前の値をそのまま残す (消すと集め直しが要る)
        if said is not None:
            if said.get(example):
                entry["warnings"] = said[example]
            else:
                entry.pop("warnings", None)
        # **測れないと言った例に数字を付けない。** 付けると乱数の例が実行のたびに違う
        # 数を出し、台帳が意味もなく動く。読み手も 0% を「まったく違う」と読んでしまう
        # **測らなかった回は、前に測った数字を残さない。** 測るかどうかは撮るたびに
        # 決まる (原典が 1 画素も描かなければ測れない) ので、消さないと古い数字が居座る
        if measured["measure"] == "none" or not measured.get("diff"):
            entry.pop("diff", None)
        else:
            entry["diff"] = {k: round(v, 4) for k, v in measured["diff"].items()}

        mark = fingerprint(example, entry)
        shot = WORK / "shots" / f"{entry['slug']}.png"
        if not force and entry.get("url") and entry.get("source") == mark:
            book["shots"][example] = entry
            continue
        if not shot.exists():
            print(f"  {example}: 撮った絵が無い", file=sys.stderr)
            continue
        # **同じバイト列なら上げ直さない。** 指紋の作り方を変えた回に全 157 枚が
        # 上がってしまうのを防ぐ。上げ直しても同じ絵に別の URL が付くだけで、
        # 直すべきは台帳の指紋のほうである
        if not force and entry.get("url") and hashlib.sha256(shot.read_bytes()).hexdigest() == entry.get("sha256"):
            entry["source"] = mark
            book["shots"][example] = entry
            save(book)
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

    # 動きの証跡。**静止画の置き換えではなく併載**なので、別に持って別に上げる
    for example, entry in sorted(book["shots"].items()):
        webp = WORK / "webp" / f"{entry['slug']}.webp"
        if not webp.exists():
            entry.pop("motion", None)
            continue
        mark = motion_fingerprint(example)
        if not force and entry.get("motion", {}).get("url") and entry["motion"].get("source") == mark:
            continue
        result = upload(webp, f"{example} — 動き (原典と mokume)")
        entry["motion"] = {"url": result["url"], "source": mark,
                           "sha256": hashlib.sha256(webp.read_bytes()).hexdigest()}
        uploaded += 1
        print(f"  {example} (動き) → {result['url']}", file=sys.stderr)
        save(book)
    save(book)
    write_renders(book)
    write_gallery(book)
    write_readme(book)
    print(f"上げた {uploaded} 枚 / 台帳 {len(book['shots'])} 件", file=sys.stderr)
    return 0


# **ハッシュを載せない例。** 面の外の値を読むので、同じフレーム番号からでも
# 同じ絵にならない。載せると `--render-all` の diff が毎回 2 行ずれる。
#
# **mokume の乱数はここに来ない** — 同じフレーム番号から同じ値を出すので
# (ADR-0001 原則 2)、`random()` を使う例の書き出しは再現する。ここに来るのは
# mokume の外から値を取っているものだけである。
NOT_REPRODUCIBLE = {
    "clock-1.png": "壁時計 (second / minute / hour) を読む",
    "intlistlottery-1.png": "Swift の shuffle() を呼ぶ (系の乱数で、種を指せない)",
}


def write_renders(book: dict) -> None:
    """mokume が書き出した絵のハッシュ。**再現の手がかり。**

    README に全数を貼れないのでここに置く。**乱数を使う例も入る** — mokume の
    乱数は同じフレーム番号から同じ値を出すので (ADR-0001 原則 2)、書き出しは
    再現する。再現しないのは原典 (ブラウザ) の側と、``NOT_REPRODUCIBLE`` が
    名指す例だけである。
    """
    lines = ["# swift run -c release Atlas --render-all out 1 && shasum -a 256 out/*.png",
             f"# mokume v{book['tool']['mokume']}",
             "#",
             "# **次の例はハッシュを載せない** (面の外の値を読むので毎回変わる)。",
             "# README の突き合わせでも両側から外している:"]
    lines += [f"#   {name} — {why}" for name, why in sorted(NOT_REPRODUCIBLE.items())]

    # **ファイル名の順に書く。** README の突き合わせは `shasum -a 256 out/*.png` と
    # 行ごとに比べるので、こちらが例の名前順だと中身が同じでも全行ずれる
    # (実際にずれていた)。
    hashed = []
    for example, entry in rows(book):
        shot = ROOT / "out" / f"{entry['slug']}-{entry['frame']}.png"
        if shot.exists() and shot.name not in NOT_REPRODUCIBLE:
            hashed.append(f"{hashlib.sha256(shot.read_bytes()).hexdigest()}  {shot.name}")
    RENDERS.write_text("\n".join(lines + sorted(hashed, key=lambda l: l.split()[1])) + "\n")


def rows(book: dict) -> list[tuple[str, dict]]:
    return sorted(book["shots"].items())


# **どれが「同じ絵」かは機械が決めない。** 数と並べた 1 枚を出すところまでが仕事で、
# 見て決めるのは人である。測り方そのものは scripts/compare/index.html のコメントが正本。


def bucket(book: dict) -> dict[str, int]:
    counts = {"pixel": 0, "resampled": 0, "none": 0}
    for _, entry in rows(book):
        counts[entry["measure"]] += 1
    return counts


def unmeasured(book: dict) -> list[tuple[str, int]]:
    """**数を出さなかった例の内訳。** 理由が 1 つでないので、まとめて「乱数・時計・書体」と
    書くと嘘になる (原典どうしが食い違う例と、原典が絵を出さない例が混ざっている)。"""
    kinds = [
        ("乱数・雑音・時計", "乱数"),
        ("字を組む", "字を組む"),
        ("原典が 2 つ食い違う", "原典が 2 つある"),
        ("原典が 1 画素も描かない", "原典が 1 画素"),
        ("面の大きさが違う", "面の大きさ"),
    ]
    counts = {label: 0 for label, _ in kinds}
    other = 0
    for _, entry in rows(book):
        if entry.get("diff"):
            continue
        why = reason(entry)
        for label, mark in kinds:
            if why.startswith(mark):
                counts[label] += 1
                break
        else:
            other += 1
    out = [(label, counts[label]) for label, _ in kinds if counts[label]]
    if other:
        out.append(("その他", other))
    return out


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
    """全数の置き場。**丸ごと生成物**なので手で直さない。

    **絵はリンクではなく埋め込む。** 157 本を突き合わせた結果は、数字の表だけ見ても
    「同じ絵になっているか」が分からない — 1 枚ずつ開かせると、まとめて眺めるという
    いちばん自然な見方ができなくなる。上から流し読みできることを優先する。
    """
    groups: dict[str, list] = {}
    for example, entry in rows(book):
        groups.setdefault(entry["group"], []).append((example, entry))

    counts = bucket(book)
    measured = sum(1 for _, e in rows(book) if e.get("diff"))
    said = sum(1 for _, e in rows(book) if e.get("warnings"))
    out = [
        "# 原典と並べた全数",
        "",
        "<!-- scripts/compare/publish.py が書く。手で直さない -->",
        "",
        f"移した {len(book['shots'])} 本を、原典と並べて突き合わせたもの。**左が原典・右が"
        " mokume。** 原典は processing-website が例ごとに配る `liveSketch.js`"
        " (Processing 版と 1 行ずつ対応した p5.js) を走らせたもので、**条件を 3 つ揃えて"
        "ある** — マウスを動かさない・決めた枚数で止める・等倍。",
        "",
        f"数を出したのが {measured} 本 (うち {counts['resampled']} 本は原典が静止画しか無く、"
        "縮めて比べているので参考値)、**数を出さなかったのが"
        f" {len(book['shots']) - measured} 本**。理由は 1 つではない — "
        + "・".join(f"{label} {n} 本" for label, n in unmeasured(book)) + "。",
        "",
        "数は 4 つ出す。**どれが「同じ絵」かは決めていない** — 見て決めるのは人である。",
        "",
        f"**mokume が「そうしなかった」と言った例には、数字より先にその一言を置いてある**"
        f" ({said} 本)。言われたとおりにしなかったという申告なので、一致率だけを見ても"
        "絵が食い違っている理由には辿り着けない。",
        "",
        "| | 何を見るか |",
        "| --- | --- |",
        "| その場 | そのままの位置で、色が差 8 以内 (目で見て同じ色) |",
        "| 半画素 | mokume を半画素動かしてよいとしたとき。**ずらすと合うなら、正体は線の載せ方** |",
        "| 形 | 明るさの縁だけを取り出し、1 画素の幅を許して比べたもの |",
        "| 完全 | 1 画素も違わない |",
        "",
        f"道具は mokume v{book['tool']['mokume']} / p5.js {book['tool']['p5']}。",
        "",
        "## 動きの証跡について",
        "",
        f"**静止画の下に動くものが付いている例が {sum(1 for _, e in rows(book) if e.get('motion'))} 本ある。**"
        " 止まった 1 枚では正しいかどうか判断できないもの (動く例・マウスが要る例) には、"
        "アニメーション WebP を併載してある。**置き換えではない** — 細かい差は静止画の"
        "ほうが向いている。",
        "",
        "- **撮影範囲**: スケッチの面だけ (窓の縁も他のアプリも入らない)。左が原典・右が mokume",
        f"- **何を撮ったか**: 12 fps で {MOTION_FRAMES} 枚 = 2 秒。半分の大きさ",
        "- **マウスは決まった道すじで動かす**。横に 1 往復・縦に 2 往復し、**真ん中の"
        " 3 分の 1 だけ押す**。原典と mokume で式が同じでないと、動きの違いなのか入力の"
        "違いなのか分からなくなるので、[`Support/MousePath.swift`](../Sources/Atlas/Support/MousePath.swift) と"
        " [`scripts/compare/motion.html`](../scripts/compare/motion.html) に同じ式を置いている",
        "- **原典の側では出来事も起こす** (`mousePressed()` / `mouseDragged()` など)。"
        "本物のブラウザなら呼ばれるものなので、呼ばないと原典だけ手加減したことになる。"
        "mokume にその口が無いことは差として出てよい",
        "- **動きが付いていない例**は、決まった道すじで動かしても絵が 1 枚も変わらなかったもの"
        " (静止形の例と、出来事の口が無くて止まっている例)",
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
        out += [f"## {group}", ""]
        for example, entry in items:
            leaf = example.split("/")[-1]
            score = caption(entry)
            note = f" ・ {entry['note']}" if entry.get("note") else ""
            frame = f" ・ {entry['frame']} 枚目" if entry.get("frame", 1) > 1 else ""
            out += [f"### `{leaf}`", ""]
            # **mokume がそうしなかったと言っているなら、数字より先に読ませる。**
            # 一致率だけを見ても、絵が食い違っている理由には辿り着けない
            for line in entry.get("warnings", []):
                out += [f"> **mokume はこう言っている** — {line}", ""]
            out += [f"台帳は `{entry['class']}`{frame} ・ {score}{note}", "",
                    f"![{example}]({entry['url']})", ""]
            if entry.get("motion", {}).get("url"):
                out += [f"![{example} の動き]({entry['motion']['url']})", ""]
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
        f"| 数を出さない | {sum(n for _, n in unmeasured(book))} |",
        "",
        f"移した {total} 本ぶん。うち {counts['resampled']} 本は原典が静止画しかなく、"
        "縮めて比べているので参考値。**どれが「同じ絵」かは決めていない** — 数と並べた"
        " 1 枚を出すところまでが機械の仕事で、見て決めるのは人である。",
        "",
        "**数を出さない理由は 1 つではない** — "
        + "・".join(f"{label} {n} 本" for label, n in unmeasured(book))
        + "。原典どうしが食い違う例と、原典が 1 画素も描かない例には数を出さない"
        " ([`scripts/origins.py`](scripts/origins.py) が前者を機械で探す)。",
        "",
        "**157 枚を並べたものが [`ledger/comparison.md`](ledger/comparison.md)** にある"
        " (リンクではなく埋め込んであるので、上から流し読みできる)。",
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
    said = diagnostics()
    problems: list[str] = []
    if book.get("tool", {}).get("mokume") != mokume_version():
        problems.append(f"道具を上げたのに撮り直していない (台帳 {book.get('tool', {}).get('mokume')} / いま {mokume_version()})")
    for example, entry in rows(book):
        if entry.get("source") != fingerprint(example, entry):
            problems.append(f"{example}: 移植か測り方を変えたのに撮り直していない")
        if entry["measure"] == "none" and entry.get("diff"):
            problems.append(f"{example}: 測れないと言った例に数字が付いている")
        # **原典が絵を出したのに移植が背景だけ、は移植の側の疑いである。**
        # 157 枚を目で見張るのは回らないので、ここで落とす。
        #
        # ただし**原典が数画素しか描いていないときは黙る** — 潰れた図形の縁が 1 画素だけ
        # 残る類 (Pattern の `ellipse(0,0,0,0)` が 1 画素、PenroseSnowflake の
        # 面の外を通る線が 12 画素) で、絵と呼べるものが無い。面の 0.1% を目安にする
        drawn = entry.get("ink")
        if drawn and drawn["port"] == 0 and drawn["origin"] >= entry["width"] * entry["height"] / 1000:
            problems.append(f"{example}: 原典は絵を出しているのに、移植が 1 画素も描いていない")
        if entry["measure"] != "none" and not entry.get("ink"):
            problems.append(f"{example}: 描かれた量を数える前に撮ったまま (撮り直す)")
        if said is not None and said.get(example, []) != entry.get("warnings", []):
            problems.append(f"{example}: mokume の一言が変わったのに台帳へ載せていない")
        if entry.get("url") and entry["url"] not in GALLERY.read_text():
            problems.append(f"{example}: 台帳にある絵が comparison.md に出ていない")
        motion = entry.get("motion")
        if motion and motion.get("source") != motion_fingerprint(example):
            problems.append(f"{example}: 移植を変えたのに動きを撮り直していない")
        if motion and motion.get("url") not in GALLERY.read_text():
            problems.append(f"{example}: 台帳にある動きが comparison.md に出ていない")
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
