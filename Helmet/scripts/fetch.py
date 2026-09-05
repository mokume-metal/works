#!/usr/bin/env python3
"""読む資産を取ってくる。

**取ってきたものは works へコミットしない。** どれも第三者の著作物で、works が
再配布する理由が無い。再現に要るのは中身ではなく「どの版のどれを読んだか」なので、
それを `sources.json` へ刻んで、中身は `upstream/` (gitignore 済み) へ置く。

    python3 scripts/fetch.py

版を上げるときは下の PIN を書き換える。`sources.json` の差分がそのまま
「何を読み替えたか」の記録になる。

帰属は `README.md` が持つ。**ライセンスはここにも刻む** — 取ってきた本人が
後から「これは何だったか」を辿れるようにするためで、README とは役割が違う。
"""

import hashlib
import json
import pathlib
import subprocess
import sys
import urllib.error
import urllib.request

# 取ってくるもの。**ここだけが上流への参照**で、スケッチは upstream/ しか読まない
PIN = {
    # glTF の正本。webgl_loader_gltf が実際に読んでいるリポジトリ
    "gltf-sample-assets": {"repo": "KhronosGroup/glTF-Sample-Assets", "ref": "main"},
}

# Khronos から取るモデル。ディレクトリごと取る (中身の一覧は API に聞くので、
# ファイル名を here に書き並べない — 上流が増やしたら勝手に付いてくる)
MODELS = {
    "DamagedHelmet": {
        "path": "Models/DamagedHelmet/glTF",
        "license": "CC BY 4.0 (2018, ctxwing) / CC BY-NC 4.0 (2016, theblueturtle_)",
        "why": "主題。webgl_loader_gltf の初期モデルで、PBR マップの全種が揃っている",
    },
    "NormalTangentTest": {
        "path": "Models/NormalTangentTest/glTF",
        "license": "CC0 1.0 (Analytical Graphics, Inc. / Ed Mackey)",
        "why": "接線を実行時に作れるかを測るための専用モデル。TANGENT を持たない",
    },
}

# Poly Haven から取る環境。webgl_loader_gltf が読んでいるものと同じ
HDRIS = {
    "royal_esplanade": {
        "resolution": "2k",
        "format": "hdr",
        "license": "CC0 1.0 (Greg Zaal / Poly Haven)",
        "why": "環境マップ。webgl_loader_gltf が読んでいるものと同じ",
    },
}

ROOT = pathlib.Path(__file__).resolve().parent.parent
UPSTREAM = ROOT / "upstream"
SOURCES = ROOT / "sources.json"


def gh(*args: str) -> str:
    return subprocess.run(["gh", *args], capture_output=True, text=True, check=True).stdout


def resolve(repo: str, ref: str) -> str:
    """ブランチ名を、いま指しているコミットの SHA へ畳む。"""
    return json.loads(gh("api", f"repos/{repo}/commits/{ref}"))["sha"]


# **名乗る。** 素の urllib の User-Agent (`Python-urllib/3.x`) は Poly Haven の
# 配信元が 403 で弾く (実測)。取りに行く側が誰かを名乗るのは礼儀でもある
AGENT = "mokume-works-Helmet (+https://github.com/mokume-metal/works)"


def open_url(url: str):
    return urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": AGENT}))


def download(url: str, into: pathlib.Path) -> tuple[int, str]:
    """1 ファイル取ってくる。返すのはバイト数と md5。"""
    into.parent.mkdir(parents=True, exist_ok=True)
    with open_url(url) as response:
        data = response.read()
    into.write_bytes(data)
    return len(data), hashlib.md5(data).hexdigest()


def fetch_model(repo: str, sha: str, name: str, path: str) -> dict:
    """モデルのディレクトリを、中身の一覧を API に聞いてから丸ごと取る。"""
    listing = json.loads(gh("api", f"repos/{repo}/contents/{path}?ref={sha}"))
    into = UPSTREAM / "models" / name
    files: dict[str, int] = {}
    for entry in listing:
        if entry["type"] != "file":
            continue
        # raw から取る。contents API は 1MB を超える中身を返さないので
        # (テクスチャは 2048x2048 で軽く超える)、download_url を使う
        size, _ = download(entry["download_url"], into / entry["name"])
        files[entry["name"]] = size
    return {"files": files, "path": path}


def fetch_hdri(name: str, resolution: str, suffix: str) -> dict:
    """Poly Haven から HDRI を 1 枚取る。

    URL は API に聞く — 直に組むと、置き場が変わった日に黙って 404 になる。
    """
    with open_url(f"https://api.polyhaven.com/files/{name}") as response:
        listing = json.loads(response.read())
    spec = listing["hdri"][resolution][suffix]
    into = UPSTREAM / "hdris" / f"{name}_{resolution}.{suffix}"
    size, digest = download(spec["url"], into)
    # **上流が md5 を配っているので照合する。** 途中で切れた絵を「環境が変」と
    # 読み違えないための歯止め
    if digest != spec["md5"]:
        raise ValueError(f"md5 が合わない: 取れたもの {digest} / 上流 {spec['md5']}")
    return {"url": spec["url"], "bytes": size, "md5": digest}


def main() -> int:
    UPSTREAM.mkdir(parents=True, exist_ok=True)
    record: dict = {
        "note": "取ってきた資産の出どころ。中身は upstream/ にあり、works へはコミットしない",
        "models": {},
        "hdris": {},
    }

    pin = PIN["gltf-sample-assets"]
    sha = resolve(pin["repo"], pin["ref"])
    print(f"{pin['repo']} @ {sha[:12]}")
    for name, spec in MODELS.items():
        got = fetch_model(pin["repo"], sha, name, spec["path"])
        total = sum(got["files"].values())
        print(f"  {name}: {len(got['files'])} ファイル / {total:,} バイト")
        record["models"][name] = {
            "repo": pin["repo"],
            "sha": sha,
            "path": spec["path"],
            "license": spec["license"],
            "why": spec["why"],
            "files": got["files"],
        }

    for name, spec in HDRIS.items():
        try:
            got = fetch_hdri(name, spec["resolution"], spec["format"])
        except (urllib.error.URLError, KeyError, ValueError) as error:
            # **環境が取れなくても止めない。** 環境マップは測る項目の 1 つで、
            # 他の項目 (形・テクスチャ・法線マップ) は環境なしでも測れる
            print(f"  {name}: 取れなかった ({error})", file=sys.stderr)
            continue
        print(f"  {name}: {got['bytes']:,} バイト")
        record["hdris"][name] = {
            "source": "https://polyhaven.com/a/" + name,
            "url": got["url"],
            "license": spec["license"],
            "why": spec["why"],
            "bytes": got["bytes"],
            "md5": got["md5"],
        }

    SOURCES.write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")
    print(f"\n{SOURCES.relative_to(ROOT)} へ刻んだ")
    return 0


if __name__ == "__main__":
    sys.exit(main())
