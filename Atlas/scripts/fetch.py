#!/usr/bin/env python3
"""原典と mokume の公開 API を取ってくる。

**取ってきたものは works へコミットしない。** 250 例のうち 34 例は原作者に著作権が
残り (Processing の examples/README.md)、data/ の資材にはライセンス表記が無い。
再現に要るのは中身ではなく「どの版から読んだか」なので、それを ledger/sources.json
へ刻んで、中身は upstream/ (gitignore 済み) へ置く。

    python3 scripts/fetch.py

版を上げるときは下の PIN を書き換える。ledger/sources.json の差分がそのまま
「何が変わって台帳を組み直したか」の記録になる。
"""

import json
import pathlib
import subprocess
import sys
import tarfile
import tempfile

# 取ってくる版。**ここだけが上流への参照**で、他のスクリプトは upstream/ しか読まない
PIN = {
    # 例の正本。processing-docs は非推奨 (README が「will be archived soon」と名乗る)
    "examples": {"repo": "processing/processing-examples", "ref": "main"},
    # リファレンスの項目名。組み込みの語彙かどうかの判定に使う
    "reference": {"repo": "processing/processing-website", "ref": "main"},
    # 定数の正本。リファレンスに項目が無いので (PI ほか 5 つを除く) ここから引く
    "constants": {"repo": "processing/processing4", "ref": "main"},
}

ROOT = pathlib.Path(__file__).resolve().parent.parent
UPSTREAM = ROOT / "upstream"


def gh(*args: str) -> str:
    return subprocess.run(["gh", *args], capture_output=True, text=True, check=True).stdout


def resolve(repo: str, ref: str) -> str:
    """ブランチ名を、いま指しているコミットの SHA へ畳む。"""
    return json.loads(gh("api", f"repos/{repo}/commits/{ref}"))["sha"]


def fetch_examples(repo: str, sha: str, into: pathlib.Path, manifest_path: pathlib.Path) -> int:
    """例の .pde だけを取り出す。

    **資材 (data/ の画像・フォント・モデル・GLSL) は取らない** — ライセンス表記が
    無く、works が再配布する理由もない。ただし**どの例が資材を要るかは要る**ので、
    パスだけ manifest へ記録する。資材が無くて動かないことは mokume の欠けではない
    ので、台帳では「届かない」と別の印を付ける必要がある。
    """
    into.mkdir(parents=True, exist_ok=True)
    manifest: dict[str, dict] = {}
    with tempfile.NamedTemporaryFile(suffix=".tar.gz") as tmp:
        subprocess.run(
            ["gh", "api", f"repos/{repo}/tarball/{sha}"], stdout=tmp, check=True
        )
        tmp.flush()
        count = 0
        with tarfile.open(tmp.name) as tar:
            for member in tar.getmembers():
                if not member.isfile():
                    continue
                parts = pathlib.Path(member.name).parts[1:]
                # <カテゴリ>/<小分類>/<例>/… の下だけを見る
                if len(parts) < 4:
                    continue
                example = "/".join(parts[:3])
                entry = manifest.setdefault(example, {"assets": 0, "shaders": 0})
                if parts[-1].endswith(".pde") and len(parts) == 4:
                    target = into.joinpath(*parts)
                    target.parent.mkdir(parents=True, exist_ok=True)
                    source = tar.extractfile(member)
                    if source is None:
                        continue
                    target.write_bytes(source.read())
                    count += 1
                else:
                    entry["assets"] += 1
                    if parts[-1].endswith((".glsl", ".vert", ".frag")):
                        entry["shaders"] += 1
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
    return count


def fetch_reference_names(repo: str, sha: str, into: pathlib.Path) -> int:
    """リファレンスの項目名。**中身は要らないのでファイル名だけ取る。**"""
    tree = json.loads(gh("api", f"repos/{repo}/git/trees/{sha}?recursive=1"))
    prefix = "content/references/translations/en/processing/"
    names = sorted(
        pathlib.Path(item["path"]).stem
        for item in tree["tree"]
        if item["type"] == "blob"
        and item["path"].startswith(prefix)
        and item["path"].endswith(".json")
    )
    into.parent.mkdir(parents=True, exist_ok=True)
    into.write_text("\n".join(names) + "\n")
    return len(names)


def fetch_constants(repo: str, sha: str, into: pathlib.Path) -> int:
    """PConstants.java から定数名を起こす。

    **リファレンスには CENTER も TRIANGLE_STRIP も HSB も項目が無い** (項目化されて
    いるのは PI / HALF_PI / QUARTER_PI / TWO_PI / TAU の 5 つだけ)。Ring が実際に
    詰まったのは TRIANGLE_STRIP なので、ここを落とすと台帳が最も重要な穴を見落とす。
    """
    import re

    path = "core/src/processing/core/PConstants.java"
    body = gh("api", f"repos/{repo}/contents/{path}?ref={sha}", "--jq", ".content")
    import base64

    source = base64.b64decode(body).decode("utf-8", errors="replace")
    # **PConstants は interface なので `static final` が省いてある** (`int HSB = 3;`)。
    # 修飾子を要求すると 6 件しか採れない
    names = sorted(set(re.findall(
        r"^\s*(?:public\s+|static\s+|final\s+)*(?:int|float|char|String|boolean|double|long)(?:\[\])?\s+([A-Z][A-Z0-9_]+)\s*=",
        source, re.M)))
    into.parent.mkdir(parents=True, exist_ok=True)
    into.write_text("\n".join(names) + "\n")
    return len(names)


def fetch_mokume_api(into: pathlib.Path) -> tuple[str, int]:
    """mokume の公開 API 一覧。**版は Package.resolved が決める** (作品の作法)。

    一覧はリポジトリに置かれず Release 資産として配られる (mokume ADR-0001 原則 8)。
    """
    resolved = json.loads((ROOT / "Package.resolved").read_text())
    pin = next(p for p in resolved["pins"] if p["identity"] == "mokume")
    version = pin["state"]["version"]
    asset_name = f"mokume-api-v{version}.md"
    assets = json.loads(gh("api", f"repos/mokume-metal/mokume/releases/tags/v{version}"))["assets"]
    asset = next(a for a in assets if a["name"] == asset_name)
    body = subprocess.run(
        ["gh", "api", f"repos/mokume-metal/mokume/releases/assets/{asset['id']}",
         "-H", "Accept: application/octet-stream"],
        capture_output=True, check=True,
    ).stdout
    into.parent.mkdir(parents=True, exist_ok=True)
    into.write_bytes(body)
    return version, len(body.splitlines())


def main() -> int:
    UPSTREAM.mkdir(exist_ok=True)
    sources: dict[str, object] = {}

    for key, pin in PIN.items():
        sha = resolve(pin["repo"], pin["ref"])
        sources[key] = {"repo": pin["repo"], "sha": sha}
        print(f"{pin['repo']} @ {sha[:12]}", file=sys.stderr)

    n = fetch_examples(
        PIN["examples"]["repo"], sources["examples"]["sha"],
        UPSTREAM / "examples", UPSTREAM / "manifest.json",
    )
    sources["examples"]["pde_files"] = n
    print(f"  例の .pde を {n} 本", file=sys.stderr)

    n = fetch_reference_names(PIN["reference"]["repo"], sources["reference"]["sha"], UPSTREAM / "reference-names.txt")
    sources["reference"]["entries"] = n
    print(f"  リファレンスの項目名を {n} 件", file=sys.stderr)

    n = fetch_constants(PIN["constants"]["repo"], sources["constants"]["sha"], UPSTREAM / "constants.txt")
    sources["constants"]["entries"] = n
    print(f"  定数を {n} 件", file=sys.stderr)

    version, lines = fetch_mokume_api(UPSTREAM / "mokume-api.md")
    sources["mokume"] = {"version": version, "lines": lines}
    print(f"  mokume v{version} の公開 API ({lines} 行)", file=sys.stderr)

    out = ROOT / "ledger" / "sources.json"
    out.write_text(json.dumps(sources, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
    print(f"\n刻んだ: {out.relative_to(ROOT)}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
