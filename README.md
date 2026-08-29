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

## 並べ方

**1 作品 = 1 フォルダ = 1 SwiftPM パッケージ = 1 スケッチ。** これは好みではなく
`mokume-cli` の単位である — `run` / `watch` はディレクトリ直下の `Package.swift` を求め、
実行ファイルの名前を `products` から取る。1 つのパッケージに作品を並べると、
**最初の product が黙って起動する**。

```
<作品>/
  Package.swift        products に実行ファイルを 1 つ宣言する
  Package.resolved     どの mokume で描いたか。コミットする
  README.md            その作品の記録
  Sources/<作品>/       スケッチ (assets を置くならこの下・宣言も要る)
```

開発は CLI から:

```bash
mokume-cli run <作品>     # 作って走らせる
mokume-cli watch <作品>   # 保存したら作り直して差し替える
mokume-cli mcp <作品>     # 走っているスケッチを外から観測する
```

フォルダの `README.md` はその作品の記録を持つ — 何を作ったか・走らせ方・**再現の手がかり**
(works と mokume のコミット、書き出した絵のハッシュ)・止まったところ・mokume へ戻したもの。
後から検証するときはそのフォルダだけ読めばよい。

| | |
| --- | --- |
| [Grain](Grain/) | 挽いた板を並べた面。木目を手続き的に作る |

**`Package.resolved` は作品ごとに持ち、コミットする。** 作品のコミットへ戻れば mokume も
当時の版に戻るので、別の作品が新しい mokume を要求しても前の作品の再現は壊れない。

## 規約

**このリポジトリの規約は、このリポジトリが持つ。** mokume の規約は写さない — 写すと必ず片方が古くなる。
