#!/usr/bin/env python3
"""原典と並べた比較画像を、公式ページに載る例のぶんだけ作る。

    python3 scripts/compare/serve.py       # 立てて、出た URL をブラウザで開く
    python3 scripts/compare/publish.py     # 出来た絵を Gyazo へ上げ、文書を書き戻す

ブラウザが原典 (processing-website が例ごとに配る `liveSketch.js` — Processing 版と
1 行ずつ対応した p5.js) を走らせ、mokume の書き出しと並べた 1 枚を作って POST で
返してくる。置き場は upstream/compare/shots/ (gitignore 済み)。

**条件を 3 つ揃えてある** — マウスを動かさない (mouseX = 0)・決めた枚数で止める・
等倍 (pixelDensity(1))。揃えないと、比べているのが処理系の差なのか撮り方の差なのか
分からなくなる (実際、最初は原典側だけ 30 フレーム進んで線の位置がずれていた)。

**献立は台帳が決める。** 比べるのは「公式ページに載り」「絵が出せて」「移してある」例
だけで、そのどれが欠けても比べようがない。誰がどれに当たるかは menu.json に出るので、
比べられなかった理由が後から読める。

**進行はこちらが持つ。** 100 本を超えると必ず途中で切れる (面が背面へ回る・1 本が
落ちる・閉じてしまう) ので、まだ撮っていないものを `/todo` が返し、ページはそれが
空になるまで回すだけにしてある。開き直せば続きから走る。
"""

import base64
import json
import pathlib
import re
import struct
import subprocess
import sys
from http.server import HTTPServer, SimpleHTTPRequestHandler

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent.parent
WORK = ROOT / "upstream" / "compare"
PORT = 8731

# **画素の一致率が意味を持たない語彙。** 原典 (p5) と mokume で数列も時計も違うので、
# 同じ絵が出るはずがない。並べた 1 枚は作るが、数字は出さずに「目で見るもの」と印を付ける。
# 一致率が低いことをこちらの欠けとして数えないための区別である。
NONDETERMINISTIC = {
    "random", "randomSeed", "randomGaussian", "noise", "noiseSeed", "noiseDetail",
    "millis", "second", "minute", "hour", "day", "month", "year",
}

# **書体は処理系の差ではなく環境の差。** 原典はブラウザの、mokume は macOS の書体で
# 字を組むので、同じ名前を指定しても字形が違う。字の置き方は目で見られるが、
# 画素の一致率は「入っている書体」を測っているだけになる。
TYPOGRAPHY = {"text", "textFont", "textSize", "textAlign", "textWidth", "textLeading",
              "createFont", "loadFont"}


def ledger() -> list[dict]:
    return [json.loads(line) for line in (ROOT / "ledger" / "examples.jsonl").read_text().splitlines()]


def shots() -> dict:
    """撮影の台帳。**人手の欄 (frame / measure / note) の置き場**でもある。"""
    path = ROOT / "ledger" / "shots.json"
    return json.loads(path.read_text()) if path.exists() else {"shots": {}}


def ported() -> list[str]:
    """移してある例。`--list` が正本で、こちらで数え直さない。"""
    out = subprocess.run(
        ["swift", "run", "-c", "release", "Atlas", "--list"],
        cwd=ROOT, capture_output=True, text=True, check=True)
    return [line.strip() for line in out.stdout.splitlines() if "/" in line]


def slug(example: str) -> str:
    return example.split("/")[-1].lower()


def png_size(path: pathlib.Path) -> tuple[int, int]:
    """PNG の IHDR から縦横を読む。**書き出した絵そのものが正本**。"""
    head = path.read_bytes()[16:24]
    return struct.unpack(">II", head)


def build_menu() -> tuple[list[dict], list[dict]]:
    """比べるものと、比べられなかったものを並べる。"""
    hand = shots().get("shots", {})
    have = set(ported())
    menu, skipped = [], []
    for row in ledger():
        if not row["site"]:
            continue
        # **移植があること自体が証拠。** 台帳が「絵が出せない」と言っていても、実際に
        # 移せて絵が出るなら、外れているのは台帳のほうである (LoadDisplayOBJ が実例 —
        # loadShape に口は無いが、OBJ に限れば loadModel が受ける)。だから台帳の
        # picture ではなく**移植の有無**で献立を組む
        if row["example"] not in have:
            blocked = sorted({"loadShape", "getChild", "getVertex", "getChildCount"} & set(row["vocabulary"]))
            why = f"絵が出せない ({'/'.join(blocked)})" if row["picture"] == "none" and blocked else "まだ移していない"
            skipped.append({"example": row["example"], "why": why})
            continue
        given = hand.get(row["example"], {})
        words = set(row["vocabulary"]) | set(row["constants"])
        if given.get("measure"):
            measure, why = given["measure"], given.get("why")
        elif words & NONDETERMINISTIC:
            measure, why = "none", "乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い"
        elif words & TYPOGRAPHY:
            measure, why = "none", "字を組む。原典はブラウザの、mokume は macOS の書体で字形が違う"
        elif row["origin"] == "png":
            measure, why = "resampled", "原典が 1280x720 の静止画しかない。縮めてから比べるので参考値"
        else:
            measure, why = "pixel", None
        menu.append({
            "example": row["example"],
            "slug": slug(row["example"]),
            "group": row["group"],
            "class": row["class"],
            "origin": row["origin"],          # live = p5 を走らせる / png = site の静止画
            "frame": given.get("frame", 1),   # 何枚目で比べるか。既定は 1 枚目
            "measure": measure,               # pixel = 数で測る / resampled = 参考値 / none = 目で見る
            "why": why,
            "note": given.get("note"),
        })
    return menu, skipped


def render(menu: list[dict]) -> None:
    """mokume 側の絵を、足りないぶんだけ書き出す。

    **枚数ごとにまとめて 1 回呼ぶ。** 1 本ずつ呼ぶと面を作り直すぶんだけ本数に比例して
    待つことになる (100 本を超えると数分の差になる)。
    """
    out = ROOT / "out"
    todo: dict[int, list[str]] = {}
    for entry in menu:
        if not (out / f"{entry['slug']}-{entry['frame']}.png").exists():
            todo.setdefault(entry["frame"], []).append(entry["example"])
    for frame, names in sorted(todo.items()):
        print(f"mokume の絵を {frame} 枚目まで書き出す ({len(names)} 本)…", file=sys.stderr)
        # **書き出しは release で。** 画素を舐める例 (Image Processing の 6 本) は
        # 1 枚あたり 200 万回の呼び出しになり、debug では分の単位で待つ
        subprocess.run(["swift", "run", "-c", "release", "Atlas", "--render-all", "out", str(frame), *names],
                       cwd=ROOT, check=True, stdout=subprocess.DEVNULL)


def fetch_manual(sha: str) -> pathlib.Path:
    """site が別のフォルダに置いている資材を取ってくる。

    **原典が読む先は 2 つある。** 例の `data/` と同じものが `static/livesketch/` に
    置かれるほかに、`static/livesketch-manual/` がある — p5 が読めない形式 (動く GIF)
    を PNG へ直したものや、例の data/ に無い絵がここに入る。原典は絶対パスで
    `/livesketch-manual/…` を読むので、配らないと **setup が永久に返らない**。
    """
    into = WORK / "livesketch-manual"
    if into.exists():
        return into
    into.mkdir(parents=True, exist_ok=True)
    tree = json.loads(subprocess.run(
        ["gh", "api", f"repos/processing/processing-website/git/trees/{sha}?recursive=1"],
        capture_output=True, text=True, check=True).stdout)
    prefix = "static/livesketch-manual/"
    wanted = [i for i in tree["tree"] if i["type"] == "blob" and i["path"].startswith(prefix)]
    print(f"site だけが持つ資材を {len(wanted)} 件…", file=sys.stderr)
    for item in wanted:
        target = into / item["path"][len(prefix):]
        target.parent.mkdir(parents=True, exist_ok=True)
        blob = json.loads(subprocess.run(
            ["gh", "api", f"repos/processing/processing-website/git/blobs/{item['sha']}"],
            capture_output=True, text=True, check=True).stdout)
        target.write_bytes(base64.b64decode(blob["content"]))
    return into


def gh_content(path: str, sha: str) -> bytes:
    body = subprocess.run(
        ["gh", "api", f"repos/processing/processing-website/contents/{path}?ref={sha}", "--jq", ".content"],
        capture_output=True, text=True, check=True).stdout
    return base64.b64decode(body)


def prepare(menu: list[dict], skipped: list[dict]) -> dict[str, pathlib.Path]:
    """原典と mokume の絵を、配る場所へ集める。戻り値は資材の置き場 (slug → data/)。"""
    sha = json.loads((ROOT / "ledger" / "sources.json").read_text())["reference"]["sha"]
    for name in ["live", "mokume", "shots", "png"]:
        (WORK / name).mkdir(parents=True, exist_ok=True)

    assets: dict[str, pathlib.Path] = {}
    seen: dict[str, list[pathlib.Path]] = {}
    for entry in list(menu):
        example, name = entry["example"], entry["slug"]
        if entry["origin"] == "live":
            live = WORK / "live" / f"{name}.js"
            if not live.exists():
                live.write_bytes(gh_content(f"content/examples/{example}/liveSketch.js", sha))
            source = live.read_text(errors="replace")
            # **原典の面の大きさは liveSketch が決める。** 原典の .pde が size(600, 360)
            # と書いていても、site は liveSketch を一律 640x360 に書き直していることが
            # ある (Basics/Camera/Orthographic)。比べているのは liveSketch なので、
            # .pde の数を信じると違う大きさの絵を引き伸ばして突き合わせることになる
            found = re.search(r"createCanvas\(\s*(\d+)\s*,\s*(\d+)([^)]*)\)", source)
            entry["origin_size"] = [int(found.group(1)), int(found.group(2))] if found else None
            entry["webgl"] = bool(found and "WEBGL" in found.group(3))
        else:
            # **原典が p5 で配られていない例。** site は代わりに 1280x720 の静止画を
            # 見せているので、それを縮めて原典に使う (縮小するぶん一致率は参考値)
            still = WORK / "png" / f"{name}.png"
            if not still.exists():
                still.write_bytes(gh_content(f"content/examples/{example}/{example.split('/')[-1]}.png", sha))
            entry["origin_size"] = list(png_size(still))
            entry["webgl"] = False

        shot = ROOT / "out" / f"{name}-{entry['frame']}.png"
        (WORK / "mokume" / f"{name}.png").write_bytes(shot.read_bytes())
        entry["size"] = list(png_size(shot))

        # **大きさが違うなら引き伸ばさない。** 引き伸ばして突き合わせると一致率だけが
        # 落ち、原因が「mokume の絵が違う」に見える。並べては見せるが、数は出さない
        origin = entry["origin_size"]
        if origin and entry["measure"] != "none" and (
            origin != entry["size"] and not (entry["measure"] == "resampled" and origin == [s * 2 for s in entry["size"]])
        ):
            entry["measure"] = "none"
            entry["why"] = f"面の大きさが違う (原典 {origin[0]}x{origin[1]} / mokume {entry['size'][0]}x{entry['size'][1]})"

        data = ROOT / "upstream" / "examples" / example / "data"
        if data.is_dir():
            assets[name] = data
            for file in data.iterdir():
                if file.is_file():
                    seen.setdefault(file.name, []).append(file)

    fetch_manual(sha)
    (WORK / "menu.json").write_text(json.dumps(
        {"compare": menu, "skipped": skipped}, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
    (WORK / "index.html").write_bytes((HERE / "index.html").read_bytes())
    Handler.roots = {name: files[0] for name, files in seen.items() if len(files) == 1}
    return assets


class Handler(SimpleHTTPRequestHandler):
    assets: dict[str, pathlib.Path] = {}
    # **site の根から読む原典がある。** LoadSaveJSON の p5 は `/data.json` を読む
    # (例の data/ にある同じ名前のファイル)。名前が例をまたいで重ならないものだけ、
    # 根から引けるようにする — 重なるものを黙って結ぶと、別の例の資材を返してしまう
    roots: dict[str, pathlib.Path] = {}
    menu: list[dict] = []

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(WORK), **kwargs)

    def translate_path(self, path: str) -> str:
        """原典が読む資材の道を、例の data/ へ繋ぐ。

        p5 の側は site に置かれたまま `/livesketch/<小文字の例名>/<ファイル>` を読む。
        資材はライセンス表記が無いのでコミットせず、`upstream/examples/…/data/` に
        置いてある実体をここで指し直す。**mokume 側の移植も同じ実体を読む**ので、
        両側が食い違ったバイト列を読んで嘘の差が出ることがない。
        """
        parts = path.split("?")[0].strip("/").split("/")
        if len(parts) == 3 and parts[0] == "livesketch" and parts[1] in self.assets:
            return str(self.assets[parts[1]] / parts[2])
        if len(parts) == 1 and parts[0] in self.roots:
            return str(self.roots[parts[0]])
        return super().translate_path(path)

    def do_GET(self):
        if self.path == "/todo":
            # **まだ撮っていないものだけを返す。** ページはこれが空になるまで回す
            done = {p.stem for p in (WORK / "shots").glob("*.png")}
            rest = [m for m in self.menu if m["slug"] not in done]
            body = json.dumps(rest, ensure_ascii=False).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        super().do_GET()

    def do_POST(self):
        if self.path != "/save":
            self.send_error(404)
            return
        size = int(self.headers.get("Content-Length", 0))
        payload = self.rfile.read(size).decode("utf-8", errors="replace")
        name, _, rest = payload.partition("|")
        if name == "stats":
            # **測った数と、落ちた例の記録。** 追記で持つので開き直しても消えない
            path = WORK / "stats.json"
            have = json.loads(path.read_text()) if path.exists() else {}
            have.update(json.loads(rest))
            path.write_text(json.dumps(have, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
            body = f"{len(have)} 件".encode()
        else:
            _, _, b64 = rest.partition(",")
            target = WORK / "shots" / f"{name}.png"
            target.write_bytes(base64.b64decode(b64))
            body = f"{target.stat().st_size} bytes".encode()
        self.send_response(200)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    menu, skipped = build_menu()
    if not menu:
        print("比べられる例が無い。先に移植を足す", file=sys.stderr)
        raise SystemExit(1)
    render(menu)
    Handler.assets = prepare(menu, skipped)
    Handler.menu = menu
    print(f"比べる {len(menu)} 本 / 比べない {len(skipped)} 本", file=sys.stderr)
    print(f"http://127.0.0.1:{PORT}/ を開くと、比較画像が {WORK.relative_to(ROOT)}/shots/ に出る", file=sys.stderr)
    HTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
