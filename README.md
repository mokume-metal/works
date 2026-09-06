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

**作品は普通に作った例として置く。** 絵を書き出す口も、組み立てを測る口も持たない —
道具を測る仕掛けは、作品を読もうとした人が最初に出会うものではないからである。原典 157 本の
語彙を数える Atlas だけが**物差し**で、あちらは台帳 (`ledger/`) を持つが、**絵を書き出す口は
同じく持たない** ([#39](https://github.com/mokume-metal/works/pull/39) で畳んだ)。

**縛っているのは product が 1 つであることで、スケッチの数ではない。** Grain は
`Grain slab` で 2 本目を持ち、product は 1 つなので `mokume run` の側からは同じに見える。
選ぶのは**実行ファイルへ直に渡した引数**である (`mokume run` / `watch` / `mcp` は引数を
通さないので、窓の経路は既定の 1 本に固定される)。

```
<作品>/
  Package.swift        products に実行ファイルを 1 つ宣言する
  Package.resolved     どの mokume で描いたか。コミットする
  README.md            その作品の記録
  Sources/<作品>/       スケッチ (assets を置くならこの下・宣言も要る)
```

**[Atlas](Atlas/) だけがこの形に収まらない。** あちらは作品ではなく物差しで、Processing の
例 157 本を**それぞれ独立した mokume のスケッチ**として持つ — 1 フォルダの中に 157 個の
`Package.swift` がある。**引数で例を選ぶ形をやめたのは、`mokume watch` が通らないため**で、
1 本ずつ手元で見るには 1 本ずつがパッケージである必要があった。

```bash
mokume watch Atlas/Examples/Basics/Input/Mouse2D
```

作品を数える道具 ([`scripts/pieces.py`](scripts/pieces.py)) は**直下に `Package.swift` を
持つディレクトリ**を 1 作品として数えるので、入れ子の 157 枚は拾わない。Atlas はいまも
1 作品で、`Atlas/Package.swift` は例が引く共有の面と版の正本を持つ (executable は無い)。

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
(works と mokume のコミット、どの版で描いたか)・止まったところ・mokume へ戻したもの。
後から検証するときはそのフォルダだけ読めばよい。

| | |
| --- | --- |
| [Grain](Grain/) | 挽いた板を並べた面。木目を手続き的に作る |
| [Garden](Garden/) | p5.js の Data Structure Garden を 1 行ずつ移した庭。作品であると同時に、p5 の語彙との対応を測る物差し |
| [Solids](Solids/) | p5.js の 3D Geometries を 1 行ずつ移した立体の並び。Garden が測らなかった**立体の**語彙の物差し |
| [Ring](Ring/) | p5.js の Triangle Strip を 1 行ずつ移した虹の輪。原形の外へ出る唯一の道である**頂点列**の物差し |
| [Atlas](Atlas/) | Processing の Examples を全数で当てた台帳と、[公式ページ](https://processing.org/examples/)の 162 本のうち移せる 157 本の実測。**作品ではなく物差し**で、1 本ずつでは出ない「どの欠けが何本の例を止めるか」を数える。**mokume `v0.6.0` で 26 本が `clean` へ移り、台帳が重いと数えた欠けから順に埋まった** |
| [Helmet](Helmet/) | three.js の webgl_loader_gltf 相当を目標に、Khronos の DamagedHelmet を読んで PBR で見せようとした記録。語彙ではなく**資産と質感のパイプライン**を測る 1 本目。**絵を 1 枚貼るところで折れ**、その原因は mokume `v0.6.0` で直った |
| [Nebula](Nebula/) | 4K の面に 100 万粒を撒き、3 次元の渦に巻いて瞬かせる星雲。**粒 (`makeParticles`) を使う 1 本目**で、mokume 自身が描いたことのない規模 (上流の参照スケッチは最大 24,000 粒) を測る物差しでもある。**確保も 60fps も通り、足りなかったのは「動く粒をキラキラさせる語彙」のほう** |
| [Prism](Prism/) | 白色光を三角プリズムへ通し、波長ごとの屈折率差で虹に分ける幾何光学。**触って動かせる 1 本目**で、光線ではなく**幅を持つ帯**を追うので扇は連続したグラデーションになる。毎フレームの仕事の大半が CPU にある作品も初めてで、**release と debug で 3.2 倍の差**が出た |

**全 8 作品が mokume `v0.7.0` を引いている** ([#21](https://github.com/mokume-metal/works/issues/21))。

**`v0.7.0` への追随で 2 つ踏んだ。** どちらも #983 が描画の受け口を `Float` から
`some ScalarConvertible` へ広げた副作用で、**総称の引数では型推論の既定が変わる**ことによる:

| 踏んだもの | | 効き方 |
| --- | --- | --- |
| `rotateX(.pi)` が通らなくなった (暗黙メンバ参照が解決できない) | [mokume#1017](https://github.com/mokume-metal/mokume/issues/1017) | **赤くなる。** Atlas 22 箇所・Solids 1 箇所を `Float.pi` へ書き換えた |
| `fill(255, 255 * 50 / 100)` が 127.5 から 127 になる (リテラルが `Int` へ倒れ整数除算になる) | [mokume#1018](https://github.com/mokume-metal/mokume/issues/1018) | **黙る。** Atlas の `additivewave-1.png` が動いて初めて気付いた |

後者は**指紋を持っていたから見つかった**。絵のハッシュを版ごとに記録していなければ、
「そういう絵だった」で通り過ぎていた。**その指紋はもう無い** — Atlas が絵を撮って突き合わせる
仕組みを畳み ([#39](https://github.com/mokume-metal/works/pull/39))、作品からも計測と検証を
外した ([#40](https://github.com/mokume-metal/works/pull/40))。同じことが次に起きたら通り
過ぎる。**版を上げたら窓を開けて目で見る**、がいまの担保である。承知のうえで、works に置くのは
作品の例だと決めた。

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

## 版を上げる

mokume は週に 1 度 (月曜 00:00 UTC) 版を出す。**追随は works の裁量**で、あちらから
通知は来ない — mokume の [ADR-0022](https://github.com/mokume-metal/mokume/blob/main/docs/decisions/0022-production-track.md)
が「依存は一方向」と決めているので、こちらから見に行く形しかない。

```bash
python3 scripts/status.py      # いま何を引いていて、mokume はどこまで行っているか
python3 scripts/api-diff.py    # 版の間で増えた口・消えた口
python3 scripts/bump.py 0.7.0  # 引く版を上げる (中身は変えない)
python3 scripts/verify.py      # ビルドと版の刻印が揃っているか (台帳を持つ Atlas だけ)
python3 scripts/upstream.py    # 戻した Issue がいまどうなっているか
```

**何が増えたかは、リリースノートではなく公開 API 一覧の差分で見る。** ノートの
「新機能」は散文なのでシンボル名を取りこぼすし、閉じた Issue はそもそも載らない。
一覧は Release 資産として版ごとに配られるので、2 版ぶん取って集合の差を見れば
**書けるようになったものが全部出る**。

**気付くのは CI がやる。** [`.github/workflows/mokume-watch.yml`](.github/workflows/mokume-watch.yml)
が日次で mokume の最新版と各 `Package.resolved` を見比べ、食い違ったら追随の Issue を立てる。
**遅れていること自体は赤にしない** — 差は情報であって故障ではないので、ジョブが落ちるのは
*見に行けなかった* ときだけである。手順の正典は
[`.claude/skills/mokume-bump/`](.claude/skills/mokume-bump/SKILL.md)。

**`checks.json` を持つのは Atlas だけで、いまは版の刻印しか持たない** (絵の期待ハッシュは
[#39](https://github.com/mokume-metal/works/pull/39) で空になった)。その README の「検証する」
節は印 (`<!-- verify:pins -->` / `<!-- verify:renders -->`) で囲った区間だけが生成物である。
**手で書いた数字は腐る** — 囲いの外の散文は手書きのままなので、何が動いたのかはそこへ書く。

**作品には台帳が無いので、版上げで動くのは `Package.swift` と `Package.resolved` だけ**
である。絵が動いたかどうかは走らせて見て、気付いたことは各 README の散文へ書く。

## 規約

**このリポジトリの規約は、このリポジトリが持つ。** mokume の規約は写さない — 写すと必ず片方が古くなる。
