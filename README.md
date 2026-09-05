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
`mokume` の単位である — `run` / `watch` はディレクトリ直下の `Package.swift` を求め、
実行ファイルの名前を `products` から取る。1 つのパッケージに作品を並べると、
**最初の product が黙って起動する**。

**縛っているのは product が 1 つであることで、スケッチの数ではない。** Grain は
`Grain slab` で 2 本目を持ち、Atlas は移した例を何本も持つ。どちらも product は 1 つ
なので `mokume run` の側からは同じに見え、選ぶのは**実行ファイルへ直に渡した引数**である
(`mokume run` / `watch` / `mcp` は引数を通さないので、窓の経路は既定の 1 本に固定される)。

```
<作品>/
  Package.swift        products に実行ファイルを 1 つ宣言する
  Package.resolved     どの mokume で描いたか。コミットする
  README.md            その作品の記録
  Sources/<作品>/       スケッチ (assets を置くならこの下・宣言も要る)
```

開発は CLI から:

```bash
mokume run <作品>     # 作って走らせる
mokume watch <作品>   # 保存したら作り直して差し替える
mokume mcp <作品>     # 走っているスケッチを外から観測する
```

道具は Homebrew で入る ([mokume#383](https://github.com/mokume-metal/mokume/issues/383) が tap を用意した):

```bash
brew install mokume-metal/tap/mokume
brew upgrade mokume                    # 古いと感じたら
```

**手元でビルドした `mokume-cli` を使い続けない。** 道具は自分の版を名乗れないので
([mokume#634](https://github.com/mokume-metal/mokume/issues/634))、古いソースから作った実行
ファイルは**ファイルの日付が新しくても中身が古く**、それに気付く手掛かりが無い。解消済みの
不具合を新しい不具合として起票する事故が実際に起きている
([mokume#633](https://github.com/mokume-metal/mokume/issues/633))。

フォルダの `README.md` はその作品の記録を持つ — 何を作ったか・走らせ方・**再現の手がかり**
(works と mokume のコミット、書き出した絵のハッシュ)・止まったところ・mokume へ戻したもの。
後から検証するときはそのフォルダだけ読めばよい。

| | |
| --- | --- |
| [Grain](Grain/) | 挽いた板を並べた面。木目を手続き的に作る |
| [Garden](Garden/) | p5.js の Data Structure Garden を 1 行ずつ移した庭。作品であると同時に、p5 の語彙との対応を測る物差し |
| [Solids](Solids/) | p5.js の 3D Geometries を 1 行ずつ移した立体の並び。Garden が測らなかった**立体の**語彙の物差し |
| [Ring](Ring/) | p5.js の Triangle Strip を 1 行ずつ移した虹の輪。原形の外へ出る唯一の道である**頂点列**の物差し |
| [Atlas](Atlas/) | Processing の Examples を全数で当てた台帳と、[公式ページ](https://processing.org/examples/)の 162 本のうち移せる 157 本の実測。**作品ではなく物差し**で、1 本ずつでは出ない「どの欠けが何本の例を止めるか」を数える |

**`Package.resolved` は作品ごとに持ち、コミットする。** 作品のコミットへ戻れば mokume も
当時の版に戻るので、別の作品が新しい mokume を要求しても前の作品の再現は壊れない。

## 窓口 (`mcp`) を使うとき

エージェントの MCP 宣言は作業ディレクトリを渡せないので、窓口は**セッションを開いた場所**で
立つ。作品の親 (このリポジトリの直下) でセッションを開いたなら、見張る側の基準も揃える:

```bash
MOKUME_WORK_DIR="$PWD" mokume watch <作品>
```

揃っていないと `observe` が空振りする。いまどちらの基準で走っているかは `mokume doctor` が
「区画の基準」として出す。

## 規約

**このリポジトリの規約は、このリポジトリが持つ。** mokume の規約は写さない — 写すと必ず片方が古くなる。
