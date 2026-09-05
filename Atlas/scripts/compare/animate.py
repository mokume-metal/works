#!/usr/bin/env python3
"""並べた連番を、動くアニメーション WebP 1 枚にまとめる。

    swift run -c release Atlas --motion out/motion 24   # mokume 側の連番
    python3 scripts/compare/serve.py                    # /motion.html を開く (原典側)
    python3 scripts/compare/animate.py                  # 連番を WebP へ畳む

**静止画の置き換えではなく併載である。** 細かい差は静止画のほうが向いており、
こちらは「同じように動くか」を見るためのもの。だから半分の大きさで撮ってある。

**GIF ではなく WebP。** 同じ絵で小さく、色数の多い絵でも劣化しない (個人規約の
gyazo-capture が実測している)。`-mixed` はフレームごとに可逆 / 非可逆を選ばせる指定で、
線画は可逆・写真は非可逆に落ちる。
"""

import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
WORK = ROOT / "upstream" / "compare"
# 12 fps。1 枚あたり 83ms
DELAY = 83


def main() -> int:
    source = WORK / "motion"
    if not source.is_dir():
        print("撮った連番が無い。先に /motion.html を開く", file=sys.stderr)
        return 1
    out = WORK / "webp"
    out.mkdir(parents=True, exist_ok=True)

    built, total = 0, 0
    for folder in sorted(source.iterdir()):
        if not folder.is_dir():
            continue
        frames = sorted(folder.glob("*.png"))
        if not frames:
            continue
        target = out / f"{folder.name}.webp"
        # **連番より新しければ作り直さない。** 118 本を毎回畳むと数分かかる
        if target.exists() and target.stat().st_mtime > max(f.stat().st_mtime for f in frames):
            total += target.stat().st_size
            continue
        subprocess.run(["img2webp", "-loop", "0", "-mixed", "-d", str(DELAY),
                        *[str(f) for f in frames], "-o", str(target)],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        built += 1
        total += target.stat().st_size

    count = len(list(out.glob("*.webp")))
    print(f"作り直した {built} 本 / 全部で {count} 本 / 合わせて {total / 1024 / 1024:.1f} MB",
          file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
