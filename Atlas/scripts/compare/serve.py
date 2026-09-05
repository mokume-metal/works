#!/usr/bin/env python3
"""原典と並べた比較画像を作る。

    swift run Atlas --render-all out 1     # 先に mokume の絵を書き出しておく
    python3 scripts/compare/serve.py       # 立てて、出た URL をブラウザで開く

ブラウザが原典 (processing-website が例ごとに配る `liveSketch.js` — Processing 版と
1 行ずつ対応した p5.js) を走らせ、mokume の書き出しと並べた 1 枚を作って POST で
返してくる。置き場は upstream/compare/shots/ (gitignore 済み)。

**条件を 3 つ揃えてある** — マウスを動かさない (mouseX = 0)・1 フレーム目で止める・
等倍 (pixelDensity(1))。揃えないと、比べているのが処理系の差なのか撮り方の差なのか
分からなくなる (実際、最初は原典側だけ 30 フレーム進んで線の位置がずれていた)。
"""

import base64
import json
import pathlib
import subprocess
import sys
from http.server import HTTPServer, SimpleHTTPRequestHandler

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent.parent
WORK = ROOT / "upstream" / "compare"
PORT = 8731

# 移した例と、その書き出しの綴り。Sources/Atlas/main.swift のカタログと揃える
EXAMPLES = {
    "mouse2d": "Basics/Input/Mouse2D",
    "map": "Basics/Math/Map",
    "bezier": "Basics/Form/Bezier",
    "noloop": "Basics/Structure/NoLoop",
    "continuouslines": "Topics/Drawing/ContinuousLines",
}


def prepare() -> None:
    """原典の p5 と、mokume が書き出した絵を、配る場所へ集める。"""
    sha = json.loads((ROOT / "ledger" / "sources.json").read_text())["reference"]["sha"]
    (WORK / "live").mkdir(parents=True, exist_ok=True)
    (WORK / "mokume").mkdir(parents=True, exist_ok=True)
    (WORK / "shots").mkdir(parents=True, exist_ok=True)

    for slug, example in EXAMPLES.items():
        live = WORK / "live" / f"{slug}.js"
        if not live.exists():
            body = subprocess.run(
                ["gh", "api", f"repos/processing/processing-website/contents/content/examples/{example}/liveSketch.js?ref={sha}", "--jq", ".content"],
                capture_output=True, text=True, check=True,
            ).stdout
            live.write_bytes(base64.b64decode(body))

        shot = ROOT / "out" / f"{slug}-1.png"
        if not shot.exists():
            print(f"{shot.relative_to(ROOT)} が無い。先に `swift run Atlas --render-all out 1`", file=sys.stderr)
            raise SystemExit(1)
        (WORK / "mokume" / f"{slug}.png").write_bytes(shot.read_bytes())

    # 比較ページはこのスクリプトの隣にある
    (WORK / "index.html").write_bytes((HERE / "index.html").read_bytes())


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(WORK), **kwargs)

    def do_POST(self):
        if self.path != "/save":
            self.send_error(404)
            return
        size = int(self.headers.get("Content-Length", 0))
        payload = self.rfile.read(size).decode("utf-8", errors="replace")
        slug, _, data_url = payload.partition("|")
        _, _, b64 = data_url.partition(",")
        target = WORK / "shots" / f"{slug}.png"
        target.write_bytes(base64.b64decode(b64))
        body = f"{target.stat().st_size} bytes".encode()
        self.send_response(200)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    prepare()
    print(f"http://127.0.0.1:{PORT}/ を開くと、比較画像が {WORK.relative_to(ROOT)}/shots/ に出る", file=sys.stderr)
    HTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
