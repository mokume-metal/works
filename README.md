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
道具を測る仕掛けは、作品を読もうとした人が最初に出会うものではないからである。

**mokume を測る物差しは [probes](https://github.com/mokume-metal/probes) に置く。** 原典 157 本の
語彙を数える Atlas、約束を 1 枚の絵で突く Probe、動きで突く Drift の 3 本は、もともとここに
あったが、2026-09 にあちらへ移した ([#100](https://github.com/mokume-metal/works/pull/100))。
移す前の履歴はこのリポジトリで辿れる。

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
  Tests/<作品>Tests/    振る舞いの検査。持つ作品だけ (いまは Apex)。product は増えない
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
(works と mokume のコミット、どの版で描いたか)・止まったところ・mokume へ戻したもの。
後から検証するときはそのフォルダだけ読めばよい。

| | |
| --- | --- |
| [Grain](Grain/) | 挽いた板を並べた面。木目を手続き的に作る |
| [Garden](Garden/) | p5.js の Data Structure Garden を 1 行ずつ移した庭。作品であると同時に、p5 の語彙との対応を測る物差し |
| [Solids](Solids/) | p5.js の 3D Geometries を 1 行ずつ移した立体の並び。Garden が測らなかった**立体の**語彙の物差し |
| [Ring](Ring/) | p5.js の Triangle Strip を 1 行ずつ移した虹の輪。原形の外へ出る唯一の道である**頂点列**の物差し |
| [Helmet](Helmet/) | three.js の webgl_loader_gltf 相当を目標に、Khronos の DamagedHelmet を読んで PBR で見せようとした記録。語彙ではなく**資産と質感のパイプライン**を測る 1 本目。**絵を 1 枚貼るところで折れ**、その原因は mokume `v0.6.0` で直った |
| [Nebula](Nebula/) | 4K の面に 100 万粒を撒き、3 次元の渦に巻いて瞬かせる星雲。**粒 (`makeParticles`) を使う 1 本目**で、mokume 自身が描いたことのない規模 (上流の参照スケッチは最大 24,000 粒) を測る物差しでもある。**確保も 60fps も通り、足りなかったのは「動く粒をキラキラさせる語彙」のほう** |
| [Prism](Prism/) | 白色光を三角プリズムへ通し、波長ごとの屈折率差で虹に分ける幾何光学。**触って動かせる 1 本目**で、光線ではなく**幅を持つ帯**を追うので扇は連続したグラデーションになる。毎フレームの仕事の大半が CPU にある作品も初めてで、**release と debug で 3.2 倍の差**が出た |
| [Pond](Pond/) | 池の水面と錦鯉。**高さ場の傾きだけを絵にする** 1 本目で、屈折・焦線・鏡面反射が同じ `∇h` から出るので、風を 0 にすると 3 つとも同時に消える。面を 2 枚焼いて断片から名前で読み、**CPU が書いた数 (`Numbers`) を断片が読む**のもここが初めて |
| [Quarry](Quarry/) | 掘って積むボクセル世界。**100 万個のブロックを 76,031 枚の面に落として形として焼く** 1 本目で、掘ったところはそのチャンクだけを走っている最中に焼き直す。一人称の自由カメラも、押しっぱなしのキーも、**触ると形そのものが変わる**のもここが初めて |
| [Tempo](Tempo/) | 譜面から導く 16 秒のモーショングラフィックス。**絵が拍の関数で、状態をどこにも持たない** 1 本目 — ドラッグで時間を擦れ、同じ拍へ戻せば 1 バイトも違わない絵が出る。**文字を輪郭から形として扱う**のも、平行投影も、置き場所を配って 1 回で描くのも、自作の後処理もここが初めて |
| [Cast](Cast/) | 1 つの塊が、向きによって円・三角・四角の影を落とす 48 秒。**影を落とす 1 本目**で、読めるのは影だけ — 塊は距離の関数 `f ≤ 0` として彫ってあり、**影が狙いの外へ出ないことが定義から出る** (欠けだけが起きる)。4 つの幕はどれも同じ式の別の見え方で、**塊を回すことと光を回すことが同じ**だと最後に分かる |
| [Marble](Marble/) | 墨を流して指でかき混ぜる水盤。**計算 (`compute`) を使う 1 本目**で、絵は毎フレーム解いた非圧縮 Navier–Stokes の積分結果 — 置いている図形は矩形 1 枚だけで、状態は GPU の並びにしかない。**混ぜても濁らない**のは非圧縮の流れが伸ばして畳むだけだからで、色は `mix` でも加算でもなく**吸収 (Lambert–Beer) で混ざる** |
| [Apex](Apex/) | 3 周を走って順位を競うサーキット。**勝ち負けと終わりがある 1 本目**で、12 本の眺めと、触れる Prism・Quarry・Marble のどれにも目的は無かった。**「全開では曲がれない」はタイヤが出せる横 G の上限で角速度を頭打ちにする 1 行から出る** — ヘアピンを回れるのは 54 km/h、高速コーナーは 120 km/h と、コーナーごとの差が同じ式から出る。相手の 3 台は人と同じ操作の構造体しか返せないので、速いとしたら同じ車をうまく操っているからである。**追うカメラと、速さで広がる視野角**もここが初めて |

**13 作品が mokume `v0.9.0` を引いている。**

**`v0.7.0` への追随で 2 つ踏んだ。** どちらも #983 が描画の受け口を `Float` から
`some ScalarConvertible` へ広げた副作用で、**総称の引数では型推論の既定が変わる**ことによる:

| 踏んだもの | | 効き方 |
| --- | --- | --- |
| `rotateX(.pi)` が通らなくなった (暗黙メンバ参照が解決できない) | [mokume#1017](https://github.com/mokume-metal/mokume/issues/1017) | **赤くなる。** Atlas 22 箇所・Solids 1 箇所を `Float.pi` へ書き換えた |
| `fill(255, 255 * 50 / 100)` が 127.5 から 127 になる (リテラルが `Int` へ倒れ整数除算になる) | [mokume#1018](https://github.com/mokume-metal/mokume/issues/1018) | **黙る。** 当時ここにあった Atlas の `additivewave-1.png` が動いて初めて気付いた |

後者は**指紋を持っていたから見つかった**。絵のハッシュを版ごとに記録していなければ、
「そういう絵だった」で通り過ぎていた。**その指紋はもう無い** — Atlas が絵を撮って突き合わせる
仕組みを畳み ([#39](https://github.com/mokume-metal/works/pull/39))、作品からも計測と検証を
外した ([#40](https://github.com/mokume-metal/works/pull/40))。Atlas は後に物差しとして
[probes](https://github.com/mokume-metal/probes) へ移った。同じことが次に起きたら通り
過ぎる。**版を上げたら窓を開けて目で見る**、がいまの担保である。承知のうえで、works に置くのは
作品の例だと決めた。

**`v0.9.0` への追随では、その場で指紋を作って測った。** 版を上げる前に 13 本を走らせ、
観測の区画 (`.mokume/observe`) へ要求を置いて同じフレーム番号の絵を撮り、版を上げて
撮り直して画素差を数えた。**撮った絵はコミットしていない** — 作品に物差しを持たせないという
決定は動かさず、版上げの間だけ手元に基準線を置く形である。

**そこで分かったのは、「同じフレーム番号からは同じ絵が出る」が窓を開けている間は成り立たない
ことだった。** mokume の時計は 2 つあり、**画面に出しながら動かすときの既定は実時間**
(`Clock.wallClock`) で、フレーム番号から導く `frameIndex` は別物である。だから時計を読む
作品では、同じ版で 2 回撮っても同じ番号の絵が一致しない。**時計を読まない 4 本
(Garden・Grain・Ring・Solids) だけが 1 ビットも違わなかった。**

| | |
| --- | --- |
| **床が 0 で、差がまるごと版差だと言える** | Garden・Grain・Ring・Solids |
| **床より桁違いに大きく、版差が支配的** | Apex・Prism・Quarry・Tempo・Marble (最初の数フレームだけ) |
| **床と同じ大きさで、切り分けられない** | Cast (2 枚目から)・Helmet・Nebula・Pond |

**`v0.9.0` で踏んだものは 1 つも無い。** 13 本とも 1 行も直さずに建ち、走り、mokume の
警告も出なかった。破壊的変更 3 つはどれも**絵の出方**の変更で、しかも**どれも works 自身が
戻した Issue が塞がった結果**である:

| 変わったもの | 戻した先 | 効き方 |
| --- | --- | --- |
| 数で書いた色を sRGB の原色として受ける | [mokume#911](https://github.com/mokume-metal/mokume/issues/911) | **彩度のある絵が全部動く。** Garden の背景は打った数 (`173, 216, 230`) がそのまま出るようになった |
| 画素の格子を「塗りは角、線は中心」へ揃えた | [mokume#912](https://github.com/mokume-metal/mokume/issues/912) | **縁だけが動く。** 白黒しか使わない Cast では、これだけが出た |
| 組み込みの立体とモデルに `stroke()` が効く | [mokume#850](https://github.com/mokume-metal/mokume/issues/850) | **Solids の球に原典どおりの線が出た。** `noStroke()` の中にある他の立体は動かない |

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

**作品には台帳が無いので、版上げで動くのは `Package.swift` と `Package.resolved` だけ**
である。絵が動いたかどうかは走らせて見て、気付いたことは各 README の散文へ書く。

## 規約

**このリポジトリの規約は、このリポジトリが持つ。** mokume の規約は写さない — 写すと必ず片方が古くなる。
