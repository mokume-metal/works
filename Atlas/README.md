# Atlas — Processing の Examples を全数で mokume に当てる

制作トラック ([mokume ADR-0022](https://github.com/mokume-metal/mokume/blob/main/docs/decisions/0022-production-track.md)) の 5 本目。**これは作品ではなく物差しである** — 既存 4 本が「作品であると同時に物差し」だったのに対して、こちらは測ることしかしない。

Garden・Solids・Ring は p5.js の例を 1 本ずつ写し、その 1 本で踏んだ穴を対応表にして mokume へ戻してきた。**この形では穴の重みが分からない。** Ring は「`map` と `radians` が無い」を [#883](https://github.com/mokume-metal/mokume/issues/883) にしたが、それが Ring 1 本の都合なのか、Processing の例の 4 分の 1 が止まる話なのかは、1 本ずつ写している限り出てこない。

[Processing 公式の Examples](https://processing.org/examples/) 254 本を全数で当てると、穴ごとに**何本の例を止めるか**が出る。

## 台帳

| 区分 | 例数 | |
| --- | ---: | --- |
| `clean` | 64 | そのまま届く |
| `write-only` | 23 | 書けば届く |
| `bend` | 62 | 書けるが歪む |
| `blocked` | 54 | 口が無くて止まる |
| `out-of-scope` | 51 | 測らないと決めた |
| **合計** | **254** | |

`out-of-scope` は GLSL を書く例 (`Topics/Shaders` ほか)・性能測定と処理系の試験 (`Demos/Performance` / `Demos/Tests`)・ファイル入出力とネットワークが主題の例。**台帳から消さずに理由を持たせて残している** — 消すと「測っていない」と「測ったが届かない」の区別が付かなくなる。

### 何本の例を止めるか

| 何本の例を止めるか | 語彙 | 判定 | mokume では |
| ---: | --- | --- | --- |
| 33 | `map` | `write` ([#883](https://github.com/mokume-metal/mokume/issues/883)) | — |
| 25 | `PVector` | `bend` | SIMD2\<Float\> / SIMD3\<Float\> |
| 23 | `radians` | `write` ([#883](https://github.com/mokume-metal/mokume/issues/883)) | — |
| 20 | `frameRate` | `bend` | SketchSettings.frameRate (起動時だけ) |
| 18 | `mousePressed` | `bend` ([#723](https://github.com/mokume-metal/mokume/issues/723)) | isMousePressed |
| 18 | `noLoop` | `none` | — |
| 12 | `colorMode` | `bend` ([#778](https://github.com/mokume-metal/mokume/issues/778)) | — |
| 11 | `keyPressed` | `bend` ([#723](https://github.com/mokume-metal/mokume/issues/723)) | isKeyDown(code:) |
| 10 | `dist` | `write` | — |
| 10 | `updatePixels` | `none` | — |
| 9 | `constrain` | `write` | — |
| 8 | `QUADS` | `bend` ([#882](https://github.com/mokume-metal/mokume/issues/882)) | — |

全 20 行は [`ledger/summary.md`](ledger/summary.md)。**`#883` が名指す 2 本が 33 例と 23 例を止めている**、という数字は 1 本ずつの移植からは出ない。

### 判定の意味

**上の 4 つは届く。下の 3 つが穴。**

| | |
| --- | --- |
| `same` | mokume に同名がある。機械が置く |
| `renamed` | 口はあるが別名・別の形 (`CENTER` → `ShapeMode.center`) |
| `host` | mokume ではなく Swift の語彙で当たる (`PI` → `Float.pi`) |
| `drop` | 原典にはあるが mokume では要らない (`P3D` — 描き方のモードを持たない) |
| `write` | 面に無いが、面の外に書けば済む (`map` / `radians` / `dist`) |
| `bend` | 書けるが歪む。原典の形が保てない (`TRIANGLE_STRIP` / `mousePressed()`) |
| `none` | 口が無い (`loadFont` / `noLoop`) |

**`write` と `bend` を分けるのが肝。** どちらも「mokume に無い」だが、前者は不便なだけで、後者は原典の構造が壊れる。ADR-0022 決定 3 が Feature Issue に求める「書けなかったか、書けたが歪んだか」がこの区別そのものである。

### 台帳は予測であって、検証ではない

見ているのは**名前と定数だけ**なので、同名で当たってしまう違い (引数の形・既定値・振る舞い) は写らない。実際、移した 5 本のうち**2 本で台帳が外れた** (下記)。だから台帳は移すたびに直す。

## 実測

台帳の各区分から選んで実際に移した。**作り替えず 1 行ずつ写している。**

| 例 | 台帳の判定 | 実測 |
| --- | --- | --- |
| [`Basics/Input/Mouse2D`](Sources/Atlas/Examples/Mouse2D.swift) | `clean` | **外れ。** `background(51)` と `fill(255, 204)` は名前が当たるのに、数を 1 つ / 2 つで渡す形が無い |
| [`Topics/Drawing/ContinuousLines`](Sources/Atlas/Examples/ContinuousLines.swift) | `clean` | **外れ。** 原典の `mousePressed` は**変数**で、呼び出しの形をしていないので抽出に乗らなかった |
| [`Basics/Math/Map`](Sources/Atlas/Examples/Map.swift) | `write-only` | 当たり。`map()` を割り算で書く |
| [`Basics/Form/Bezier`](Sources/Atlas/Examples/Bezier.swift) | `bend` | 当たり。単独の `bezier()` が無く、`beginShape` + `vertex` + `bezierVertex` の 3 行になる |
| [`Basics/Structure/NoLoop`](Sources/Atlas/Examples/NoLoop.swift) | `blocked` | 当たり。**ここで止まっている** — `noLoop()` が無いので原典の「1 度だけ描く」が消える |

### 台帳が外した 2 つ

どちらも**名前は当たるのに形が違う**もので、名前しか見ない台帳の構造的な穴である。

1. **数の渡し方が写らない。** `background(51)` (灰色 1 つ)・`fill(255, 204)` (明るさ + 透かし) に対応する形が無く、`LinearRGBA.display(red:green:blue:alpha:)` で書き下すことになる。Ring が `background(0)` で踏んだのと同じ場所で、**`background` は台帳の上ではいまも `same` のまま**である (引数の形を持つ欄を `vocabulary.jsonl` に足すのが次の一手)
2. **変数として使う語彙が抽出に乗らない。** `mousePressed` は関数としても変数としても使え、原典の `if (mousePressed == true)` は後者。呼び出しの形 (`識別子 + (`) で拾う限り見えない

**この 2 つは移して初めて出た。** 移す前の台帳は 254 例のうち 64 例を `clean` と言っていたが、そのうち何本が同じ理由で外れているかは、移した本数だけしか分からない。

### 止まったところ

[`NoLoop`](Sources/Atlas/Examples/NoLoop.swift) は完成していない。原典は `setup()` で `noLoop()` を呼んで `draw()` を 1 度だけ走らせるが、mokume に進行を止める口が無いので線が流れ続ける。**動くように書き替えていない** — ADR-0022 決定 4 の言うとおり、作ろうとして止まったこと自体が実需なので、止まった形のまま残す。

## 走らせる

```bash
mokume run .      # 作って走らせる (台帳が並べた最初の例)
mokume watch .    # 保存したら作り直して差し替える
mokume mcp .      # 走っているスケッチを外から観測する
```

**`mokume run` / `watch` / `mcp` は引数を通さない**ので、窓の経路は既定の 1 本に固定される。例を選ぶときは実行ファイルへ直に渡す。

```bash
swift run Atlas --list                        # 移した例を並べる
swift run Atlas Mouse2D                       # その 1 本を窓で出す
swift run Atlas --render <置き場> <数> Mouse2D  # 1 枚だけ書き出す
swift run Atlas --frames <置き場> <数> Mouse2D  # 連番で書き出す
swift run Atlas --render-all <置き場> <数>      # 移した全部を 1 枚ずつ
```

**`--render-all` があるのは、版を上げたときに全部のハッシュを一度に取り直すため。** 既存 4 作品は 1 本ずつ手で確かめており、版上げのたびに同じ手順を作品の数だけ踏む。Atlas は移した例が増え続けるので、その手順が本数に比例しては回らない。

台帳を組み直すときは:

```bash
python3 scripts/fetch.py     # 上流を取ってくる (upstream/ は gitignore 済み)
python3 scripts/ledger.py    # ledger/ を組み直す
```

## 検証する

**同じフレーム番号からは同じ絵が出る** (mokume の [ADR-0001](https://github.com/mokume-metal/mokume/blob/main/docs/decisions/0001-founding-principles.md) 原則 2)。下のハッシュが食い違ったら、変えたつもりのないところが変わっている。

| | |
| --- | --- |
| works | この作品のコミット (`Package.resolved` が同じツリーにある) |
| mokume | `v0.5.0` / `f0d136d1d70b172b49b3419f795feba018fe4101` |
| 原典 | `processing/processing-examples` @ `b10c9e9a05a0d6c20d233ca7f30d315b5047720e` ([`ledger/sources.json`](ledger/sources.json) が刻む) |

```bash
swift run Atlas --render-all out 1 && shasum -a 256 out/*.png
# cf2346e6bc897ea807a86a00cfad4c5128aa522a885ed670fc63085e6ad0b9b6  out/bezier-1.png
# 05d6d0077fe33581c9ebf62646f89bda013559ad84d19e44f969aa145d3d8b35  out/continuouslines-1.png
# 0e0ee57ac3c1651c5f7275e4eb5f7dceb073f6de4f1ab034980e92f2f77abbf0  out/map-1.png
# b1834be0fa1567323fb4fb37c31d0bbbdbb54f3871d34ba181338981c408a32b  out/mouse2d-1.png
# 94963a46a045893d9e1bc91f4e42facc9160459a3622acb06fac39da7cc6febd  out/noloop-1.png
```

**マウスで変わる 3 本 (`Mouse2D` / `Map` / `ContinuousLines`) は、窓を持たない書き出しでは動かない。** `mouseX` が 0 のまま撮れる。外から動かすときは窓口と基準を揃える (Ring と同じ手順):

```bash
MOKUME_WORK_DIR="$PWD" mokume run Atlas
```

台帳が再現できることは、上流の版を固定してあるので確かめられる。

```bash
python3 scripts/fetch.py && python3 scripts/ledger.py
git diff --stat ledger/    # 差分が出なければ、同じ版から同じ台帳が組める
```

## 台帳の作り

**原典は works にコミットしていない。** 254 例のうち 37 例は原作者に著作権が残り (Processing の `examples/README.md` — クレジット行の無いものと Daniel Shiffman のものだけがパブリックドメイン)、`data/` の資材にはライセンス表記が無い。台帳が要るのは中身ではなく「どの例がどの語彙を使うか」なので、上流の版を [`ledger/sources.json`](ledger/sources.json) へ刻んで、中身は `upstream/` (gitignore 済み) へ置く。

**移せるのはパブリックドメインの 217 本まで** (測る対象に入るものに限れば 168 本)。台帳の判定 (読むだけ) は 254 本すべてにかけられるが、移植物は原典の翻訳物なので、クレジット行を持つ 37 本は移さない。`ledger/examples.jsonl` の `license` 欄がその区別を持つ。

| ファイル | 何を持つ | どの版に依存するか |
| --- | --- | --- |
| [`ledger/examples.jsonl`](ledger/examples.jsonl) | 例 → 使う語彙・区分・権利 (254 行) | Processing |
| [`ledger/vocabulary.jsonl`](ledger/vocabulary.jsonl) | 語彙 → mokume の対応 (189 行) | mokume |
| [`ledger/demand.jsonl`](ledger/demand.jsonl) | まだ判定していない語彙と、それを使う例 | 両方 |
| [`ledger/sources.json`](ledger/sources.json) | 上流 3 リポのコミットと mokume の版 | — |

**2 つに割ってあるのは、片方だけ見直せるようにするため。** mokume が上がったら `vocabulary.jsonl` の `checked` が古い行だけを、Processing が上がったら `examples.jsonl` だけを見直す。

`vocabulary.jsonl` に**行が無い語彙は未判定**である。番人の値 (`"unknown"`) を置いていないのは、集計側が数え忘れて静かに嘘の数字を出すのを防ぐため — 未判定を含む例は届く / 届かないのどちらにも数えない。いま未判定が 48 語あるが、どれも `out-of-scope` の例にしか出ないので区分には効いていない。

### 書き出しの口を写すのは、これで 5 度目

[`main.swift`](Sources/Atlas/main.swift) の `--render` / `--frames` は Ring から写した。Ring は Solids から、Solids は Garden から、Garden は Grain から写している。**5 つを diff すると、違うのはコメントと識別子だけ**である。

ただし Atlas は 1 product に例を N 本持つので、Grain の `makeSketch(_:)` を広げた。Grain が `if arguments.first == "slab" { Slab.main() } else { Grain.main() }` と分岐していたのは、**`Sketch.main()` が `@MainActor static func main()` で `any Sketch` から呼べない**ためで、例が増えると分岐も増える。`SketchApplication(sketch:gpu:)` は `any Sketch` を取るので、こちらを使うと分岐が消える (`Sketch.main()` の中身と同じ経路)。

## mokume へ戻したもの

台帳が出した重みは、既に立っている実需の**順位**の材料になる。新しく起票するのは、実測で 1 本以上踏んだものに限る — 机上の数字だけで起票すると「一般にそういう API があるから」に落ちる (ADR-0022 決定 6 が禁じている)。

| 踏んだもの | |
| --- | --- |
| `map` / `radians` が無い — 台帳では **33 例 / 23 例**を止める。`Basics/Math/Map` を移して踏んだ | [mokume#883](https://github.com/mokume-metal/mokume/issues/883) に重みを足す |
| 帯・扇・四角の並べ方が無い — `QUADS` 8 例・`QUAD_STRIP` 6 例 | [mokume#882](https://github.com/mokume-metal/mokume/issues/882) に重みを足す |
| 入力が出来事として届かない — `mousePressed` 18 例・`keyPressed` 11 例・`mouseDragged` 6 例 | [mokume#723](https://github.com/mokume-metal/mokume/issues/723) に重みを足す |
| **`SketchApplication` が投げる失敗を、外から人に見せられない** — `RenderFailure.message` が internal なので、`Sketch.main()` と同じ文面が書けない ([`main.swift`](Sources/Atlas/main.swift)) | 起票する |
| **進行を止める口が無い** — `noLoop` 18 例・`redraw`。`Basics/Structure/NoLoop` がここで止まった | 起票する |
