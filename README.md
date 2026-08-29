# works

[mokume](https://github.com/mokume-metal/mokume) で作った作品を置く。

## mokume との関係

**依存は一方向で、こちらが mokume を使う。** mokume はこのリポジトリを参照しない — あちらの `Package.swift` にも CI にも入らない。だから**ここが壊れても mokume は赤くならない**。作品は道具の検証物ではないので、壊れていることは情報であって故障ではない。

作りながら踏んだことは、mokume 側の Issue 1 本にして戻す。

| 踏んだもの | mokume 側 |
| --- | --- |
| 約束されていないことが**できない** | `Feature` の Issue。どの作品で何を作ろうとして何ができなかったかを書き、こちらへリンクを張る |
| 約束されていることが**期待と違う** | `Bug` の Issue。再現は mokume の中の最小のスケッチかテストへ落とす |

体制の正典は mokume 側の [ADR-0022](https://github.com/mokume-metal/mokume/blob/main/docs/decisions/0022-production-track.md)。

## 規約

**このリポジトリの規約は、このリポジトリが持つ。** mokume の規約は写さない — 写すと必ず片方が古くなる。
