# Atlas — Processing の Examples を全数で mokume に当てる

制作トラック ([mokume ADR-0022](https://github.com/mokume-metal/mokume/blob/main/docs/decisions/0022-production-track.md)) の 5 本目。**これは作品ではなく物差しである** — 既存 4 本が「作品であると同時に物差し」だったのに対して、こちらは測ることしかしない。

Garden・Solids・Ring は p5.js の例を 1 本ずつ写し、その 1 本で踏んだ穴を対応表にして mokume へ戻してきた。**この形では穴の重みが分からない。** Ring は「`map` と `radians` が無い」を [#883](https://github.com/mokume-metal/mokume/issues/883) にしたが、それが Ring 1 本の都合なのか、Processing の例の 4 分の 1 が止まる話なのかは、1 本ずつ写している限り出てこない。

[Processing 公式の Examples](https://processing.org/examples/) を全数で当てると、穴ごとに**何本の例を止めるか**が出る。台帳は processing-examples の 254 本を机上で当て、**実測は公式ページに並ぶ 162 本を全部移して**原典と並べる。

## 台帳

| 区分 | 例数 | `v0.5.0` のとき | |
| --- | ---: | ---: | --- |
| `clean` | **90** | 64 | そのまま届く |
| `write-only` | **8** | 23 | 書けば届く |
| `bend` | **54** | 63 | 書けるが歪む |
| `blocked` | **51** | 53 | 口が無くて止まる |
| `out-of-scope` | 51 | 51 | 測らないと決めた |
| **合計** | **254** | **254** | |

**`v0.6.0` で 26 本が `clean` へ移った。** works が戻した Issue が 3 本まとめて閉じたためで、
これは**台帳が予測した重みの答え合わせ**にあたる — 下の表で `map` (33 例) と `radians`
(23 例) と `mousePressed` (18 例) と `keyPressed` (11 例) が上位から消えている。

`out-of-scope` は GLSL を書く例 (`Topics/Shaders` ほか)・性能測定と処理系の試験 (`Demos/Performance` / `Demos/Tests`)・ファイル入出力とネットワークが主題の例。**台帳から消さずに理由を持たせて残している** — 消すと「測っていない」と「測ったが届かない」の区別が付かなくなる。

### 何本の例を止めるか

| 何本の例を止めるか | 語彙 | 判定 | mokume では |
| ---: | --- | --- | --- |
| 25 | `PVector` | `bend` | SIMD2\<Float\> / SIMD3\<Float\> |
| 20 | `frameRate` | `bend` | SketchSettings.frameRate (起動時だけ) |
| 18 | `noLoop` | `none` ([#900](https://github.com/mokume-metal/mokume/issues/900)) | — |
| 12 | `colorMode` | `bend` | color(hue:saturation:brightness:) — **目盛りは張り替えられない** |
| 10 | `dist` | `write` | — |
| 10 | `updatePixels` | `none` | — |
| 9 | `constrain` | `write` | — |
| 8 | `QUADS` | `bend` ([#882](https://github.com/mokume-metal/mokume/issues/882)) | — |
| 7 | `mag` | `write` | — |
| 6 | `QUAD_STRIP` | `bend` ([#882](https://github.com/mokume-metal/mokume/issues/882)) | — |

全 20 行は [`ledger/summary.md`](ledger/summary.md)。

**`v0.5.0` のときの上位 4 つは、この表から消えた。**

| 語彙 | `v0.5.0` の判定 | 止めていた例数 | `v0.6.0` |
| --- | --- | ---: | --- |
| `map` | `write` ([#883](https://github.com/mokume-metal/mokume/issues/883)) | 33 | `same` — 同名・同じ引数の形 |
| `radians` | `write` ([#883](https://github.com/mokume-metal/mokume/issues/883)) | 23 | `same` |
| `mousePressed` | `bend` ([#723](https://github.com/mokume-metal/mokume/issues/723)) | 18 | `same` — 出来事の口が入った |
| `keyPressed` | `bend` ([#723](https://github.com/mokume-metal/mokume/issues/723)) | 11 | `same` |

**台帳がいちばん重いと数えたものから順に埋まった。** 1 本ずつの移植では出なかった重みが、
実際に直す順番と一致していたことになる。

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

見ているのは**名前と定数だけ**なので、同名で当たってしまう違い (引数の形・既定値・振る舞い) は写らない。**移してみると、当たっていたのは半分ほどだった** — 下の「移して分かったこと」がその一覧である。だから台帳は移すたびに直す。

## 実測 — 公式ページの 162 本

**移せる 157 本を全部移した。** 残る 5 本 (`Basics/Shape` の SVG を読むもの) は `loadShape` に口が無く、形そのものが来ないので面が空になる。作り替えず 1 行ずつ写し、**書けない口は書けないまま残している** — 動くように書き替えると、止まったこと自体が消えるため (ADR-0022 決定 4)。

### 面の外に書き足したもの

Processing にあって mokume に無い語彙のうち、**面の外に書けば済むもの**は [`Sources/Atlas/Support/Processing.swift`](Sources/Atlas/Support/Processing.swift) 1 つに集めてある。**このファイルの長さがそのまま「Processing の例を書くのに mokume の外へどれだけ書き足す必要があるか」の答え**になる。

**`v0.6.0` で 177 行から 98 行になった。** 12 個が面へ移り、呼ぶ側の 150 ファイル・390 箇所が
原典の字面へ近づいた。

| 面へ移ったもの | 面の口 |
| --- | --- |
| `gray` / `rgb` / `hex` | `fill(_:)` / `fill(_:_:_:)` / `color(hex:)` — **目盛りは 0–255 で原典と同じ** |
| `hsb` | `color(hue:saturation:brightness:)` — 目盛りは 360/100/100 |
| `map` / `radians` / `degrees` | 同名・同じ引数の形 |
| `red` / `green` / `blue` / `brightness` | 同名。0–255 と 0–100 で返る |

| まだ外に要るもの | なぜ |
| --- | --- |
| `dist` / `constrain` / `lerp` / `norm` / `sq` / `mag` | 面に無い |
| `lerpColor` | 面に無い。**混ぜる空間が違う**ので、書いても原典と中間色が変わる |
| `second` / `minute` / `hour` / `millis` | 壁時計が無い。**値は Foundation が持っている**ので、無いのは読む口だけ |
| `asset` | 資材はリポジトリに置けないので、束の外から読む |

### 移して分かったこと

台帳が名前しか見ていないために写らなかったもの。**どれも「名前は当たるのに形が違う」**。

| | 何本に効くか |
| --- | --- |
| ~~**数を 1 つ / 2 つで渡す色が書けない**~~ (`fill(153)` / `fill(255, 204)`) — **`v0.6.0` で書ける**。150 ファイルが原典の字面に戻った | ほぼ全部 |
| **自分で描けるクラスが書けない。** 原典のクラスは `PApplet` の内側にいるので `fill` も `ellipse` もそのまま呼べるが、mokume の描く口は `Sketch` の上にあるので面を持ち回る | クラスを持つ例すべて |
| **`PVector` に当たるメソッドが 1 つも無い** (`add` / `sub` / `mult` / `div` / `normalize` / `limit` / `mag` / `dist` / `heading` / `rotate` / `setMag` / `copy` / `random2D`) | Motion / Vectors / Simulate の 17 本 |
| ~~**キーの出来事を受ける口が無い**~~ — **`v0.6.0` で入った** ([#723](https://github.com/mokume-metal/mokume/issues/723) 閉じた) | 11 本 |
| ~~**押した瞬間を受ける口が無い**~~ — 同上。ポーリングの足場を撤去した本もある (`Handles` / `Scrollbar`) | 18 本 |
| **立体の `line` が無い。** 原典の 1 行が `beginShape(.lines)` + 3 次元の `vertex` で 4 行になる | `MoveEye` |
| **`Image` に `pixels` の 1 次元の並びが無い**。`createImage` も形式の引数を取らない | Image Processing の 6 本 |
| **`background()` に絵を渡す形が無い** | `BackgroundImage` |
| **書体ファイルを読む口が無い。** システムの書体へ置き換えれば絵は出るが、字形が環境で決まる | 6 本 |
| **`scale` の引数 1 つの一様な拡大が無い** / **`spotLight` の集中度が渡せない** / **鏡の反射 (`specular`) が書けない** / **均しを切る口 (`noSmooth`) が無い** | それぞれ 1〜3 本 |
| **光は `setup()` に置けない。** 「光はフレームごとに置き直すもの」なので、静止形の例を `setup()` へ写すと光だけが無視される | `Primitives3D` |

**台帳を覆したものもある。** `Basics/Shape/LoadDisplayOBJ` は「絵が出せない」と判定されていたが、`loadShape` に口が無いのは本当でも **OBJ に限れば `loadModel` がある**。Processing が SVG と OBJ を 1 つの名前で受けているのに対し、mokume はそこを分けているためで、**語彙の名前 1 つに判定を 1 つ持たせている限り、同じ名前で 2 つのものを読む語彙は正しく測れない**。`mask` も同じで、`get` / `set` で画素を移し替えれば書ける (`none` ではなく `write`)。

### 原典と同じ見た目になっているか

**移した 157 本を、原典と並べて画素で突き合わせた。** 原典は processing-website が例ごとに配る `liveSketch.js` (Processing 版と 1 行ずつ対応した p5.js) をブラウザで走らせたもので、**mokume と条件を揃えてある** — マウスを動かさない (`mouseX` = 0)・決めた枚数で止める・等倍 (`pixelDensity(1)`) の 3 つ。

**画素の完全一致では測れない。** 目には同じ絵でも数字だけが落ちる原因が 3 つあるので、4 つの数を出す。**半画素ずらして合うかを測る**のが肝で、ずらすと合うなら違いの正体は線の載せ方だと言い切れる (ぼかしでは言い切れない)。

| | 何を見るか |
| --- | --- |
| その場で一致 | そのままの位置で、色が差 8 以内 (目で見て同じ色) |
| 半画素ずらして | mokume を半画素動かしてよいとしたとき |
| 形が一致 | 明るさの縁だけを取り出し、1 画素の幅を許して比べたもの |
| 完全一致 | 1 画素も違わない |

**測れない例には数を出さない。** 乱数・時計・書体を使う例は原典と mokume で列が違うので、一致率は「入っている乱数と書体」を測っているだけになる。並べた 1 枚は作るが、数字の代わりに理由を絵に刷る。

**どれが「同じ絵」かは決めていない。** 数と並べた 1 枚を出すところまでが機械の仕事で、見て決めるのは人である。

**止まった 1 枚では判断できないものには、動くものを併載してある。** 決まった道すじでマウスを流しながら 24 枚撮り、原典と並べたアニメーション WebP にしたもので、**123 本に付いている**。置き換えではない — 細かい差は静止画のほうが向いている。

道すじは式で決めてある ([`Support/MousePath.swift`](Sources/Atlas/Support/MousePath.swift) と [`scripts/compare/motion.html`](scripts/compare/motion.html) に同じ式)。**揃っていないと、動きの違いなのか入力の違いなのか分からなくなる。** 原典の側では `mousePressed()` などの出来事も起こす — 本物のブラウザなら呼ばれるものなので、呼ばないと原典だけ手加減したことになる。

**動きが付いていない 34 本**は、道すじを流しても絵が 1 枚も変わらなかったもの (Processing の静止形)。

**`v0.5.0` のときは 117 本だった。** 増えた 6 本は、出来事の口が入って**マウスの道すじに反応するようになった**例である — 動きの証跡の本数そのものが、口が増えたことの目盛りになっている。

<!-- compare:begin -->
| その場で一致 | 本数 |
| --- | ---: |
| 100% | 13 |
| 99% 以上 | 50 |
| 95% 以上 | 14 |
| 90% 以上 | 6 |
| 90% 未満 | 24 |
| 数を出さない | 50 |

移した 157 本ぶん。うち 1 本は原典が静止画しかなく、縮めて比べているので参考値。**どれが「同じ絵」かは決めていない** — 数と並べた 1 枚を出すところまでが機械の仕事で、見て決めるのは人である。

**数を出さない理由は 1 つではない** — 乱数・雑音・時計 30 本・字を組む 7 本・原典が 2 つ食い違う 10 本・原典が 1 画素も描かない 2 本・面の大きさが違う 1 本。原典どうしが食い違う例と、原典が 1 画素も描かない例には数を出さない ([`scripts/origins.py`](scripts/origins.py) が前者を機械で探す)。

**157 枚を並べたものが [`ledger/comparison.md`](ledger/comparison.md)** にある (リンクではなく埋め込んであるので、上から流し読みできる)。

![Basics/Form/Bezier — 原典と mokume](https://i.gyazo.com/6ff2bfe81e2ad2ff547000e2a668fe74.png)

![Basics/Math/Map — 原典と mokume](https://i.gyazo.com/46af99de5c9d9aa743e8e51aed426371.png)

![Topics/Drawing/ContinuousLines — 原典と mokume](https://i.gyazo.com/43f8b666348bc84787692376db7652b5.png)
<!-- compare:end -->

**形と位置はよく合っている。** 157 本のうち 68 本が「その場で一致 99% 以上」で、差が出たものも輪郭の均し・色の作り方・線の載せ方の 3 つにほぼ収まる。

#### 1. 半透明を重ねると色が変わる (`Mouse2D`)

<!-- compare:image Basics/Input/Mouse2D -->
![Basics/Input/Mouse2D — 原典と mokume](https://i.gyazo.com/b0043f7a48c18cfe0199553b20dd3a8f.png)

原典の `fill(255, 204)` — 白を 80% の濃さで、51 の背景へ重ねる 1 行。**出てくる色が違う。**

| | 矩形の色 |
| --- | --- |
| 原典 (p5) | `214` |
| mokume | `232` |

**mokume は線形の空間で混ぜ、p5 は表示値のまま混ぜている。** `255 × 0.8 + 51 × 0.2 = 214` が p5 で、線形へ直してから混ぜて戻すと 232 になる。型の名前 (`LinearRGBA` = 「作業空間の色」) が言うとおりの振る舞いなので**これは mokume の意図**だが、**同じコードから違う絵が出る**ことは記録しておく。一致率が 92.1% まで落ちているのは、矩形が面の 7% を占めるためである (背景は 1 画素も違わない)。

#### 2. 同じ数から違う色が出る (`StatementsComments`)

<!-- compare:image Basics/Structure/StatementsComments -->
![Basics/Structure/StatementsComments — 原典と mokume](https://i.gyazo.com/eccfb4d17f8f621dffdc23708a3865f0.png)

原典は `background(204, 153, 0)` の 1 行だけの例で、**面ぜんぶが 9 ずれる。**

| | 面の色 |
| --- | --- |
| 原典 (p5) | `204, 153, 0` |
| mokume | `213, 150, 0` |

**mokume の書き出しは Display P3 として刻まれる** (`sips -g profile` で確かめられる)。同じ数を渡しても原色が違うので、彩度のある色ほどずれる。**灰色は 1 画素も違わない** — 赤と緑と青が等しい色は原色の取り方に依らないからで、この節の他の例で灰色が合っているのはそのためである。`WidthHeight` の `fill(129, 206, 15)` は `101, 208, 0` になり、28 ずれる。

型の名前 (`LinearRGBA` = 「作業空間の色」) は空間を名乗っているが、**どの原色の空間かは名乗っていない**。半透明の合成 (下記 1) と同じで、これも mokume の意図した振る舞いだと思われるが、**同じコードから違う色が出る**ことは記録しておく。

#### 3. 1px の線をピクセルに載せるか、またがせるか (`NoLoop`)

<!-- compare:image Basics/Structure/NoLoop -->
![Basics/Structure/NoLoop — 原典と mokume](https://i.gyazo.com/a57a486bad51f567042a317a4f0adcdf.png)

`line(0, 180, width, 180)` の 1 本が、**p5 では 2 行に 128 ずつ・mokume では 1 行に 255** で出る。p5 は線をピクセルの境界にまたがらせて均し、mokume はピクセルに載せる。線 1 本ぶん (640 画素 = 面の 0.28%) の差なので一致率は 99.2% に留まる。

**この 3 つは台帳では絶対に出ない。** 語彙の名前は当たっていて、絵だけが違う。

### 止まったところ

**完成していない例がある。止まった形のまま残してある。** ADR-0022 決定 4 の言うとおり、作ろうとして止まったこと自体が実需だからである。

**`v0.6.0` で 27 本が動くようになった。** 残っているのは次のとおり。

| 例 | 何が無くて止まっているか |
| --- | --- |
| `Basics/Structure/NoLoop` / `Loop` / `Redraw` | 進行を握る 3 本。止める口も動かす口も描き直しを頼む口も無い ([#900](https://github.com/mokume-metal/mokume/issues/900))。**`Loop` は押される側だけ埋まった** — 押されても呼ぶ先が無い |
| `Basics/Web/LoadingImages` | `loadImage()` に URL を渡す口が無い。読めないので面が黒いまま |
| `Basics/Lights/Reflection` | 鏡の反射 (`lightSpecular` / `specular`) を書く口が無い。2 行を落とした。**`v0.6.0` にも無い** (あるのは `shininess` / `metalness`) |
| `Basics/Web/EmbeddedLinks` | 押されたことは受け取れるが、`link()` でページを開く口が無い。**口が 1 つ埋まっても主題が移らない例** |
| `Basics/Shape` の 5 本 | `loadShape` に口が無い。**移していない** — 形が来ないので面が空になる |

**「段階の違い」がここに出ている。** 同じ `blocked` でも、口が 1 つ増えれば動く例 (27 本)・
2 つ揃わないと動かない例 (`Loop`)・別の口を待っている例 (`EmbeddedLinks`) がある。

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

<!-- verify:pins -->
| | |
| --- | --- |
| works | この作品のコミット (`Package.resolved` が同じツリーにある) |
| mokume | `v0.6.0` / `d153f982435b775101772d904153c8d2b6711fd6` (`Package.resolved` が固定している) |
| 原典 | `processing/processing-examples` @ `b10c9e9a05a0d6c20d233ca7f30d315b5047720e` ([`ledger/sources.json`](ledger/sources.json) が刻む) |
<!-- verify:end -->

**先に上流を取る** (`python3 scripts/fetch.py`)。取っていないと**資材を読む 18 本の絵が変わる** — 画像・データ・OBJ を読む例は、資材が無いと原典と違うものを描く。

<!-- verify:renders -->
```bash
swift run -c release Atlas --render-all out 1
diff <(shasum -a 256 out/*.png | sed 's|out/||' \
        | grep -vE ' (clock-1\.png|intlistlottery-1\.png)$') \
     <(grep -v '^#' ledger/renders.txt)
```
<!-- verify:end -->

155 行の一覧は [`ledger/renders.txt`](ledger/renders.txt)。**乱数を使う例も入っている** — mokume の乱数は同じフレーム番号から同じ値を出すので (ADR-0001 原則 2)、書き出しは再現する。

**2 本だけ載せていない。** `Clock` は壁時計を読み、`IntListLottery` は Swift の `shuffle()` (系の乱数で種を指せない) を呼ぶので、**同じフレーム番号からでも毎回違う絵になる**。載せると突き合わせが毎回 2 行ずれるので、両側から外してある (名前と理由は `renders.txt` の冒頭にも書いてある)。**mokume の外から値を取っているのはこの 2 本だけ**である。

**マウスで変わる例は、窓を持たない書き出しでは動かない。** `mouseX` が 0 のまま撮れる。外から動かすときは窓口と基準を揃える (Ring と同じ手順):

```bash
MOKUME_WORK_DIR="$PWD" mokume run Atlas
```

台帳が再現できることは、上流の版を固定してあるので確かめられる。

```bash
python3 scripts/fetch.py && python3 scripts/ledger.py
git diff --stat ledger/    # 差分が出なければ、同じ版から同じ台帳が組める
```

**原典と並べた比較も作り直せる。** 立てて、出た URL をブラウザで開くと、原典 (p5) と
mokume を横に並べた 1 枚が `upstream/compare/shots/` に出る。**献立は台帳が決める**ので、
移植を足せば次から比較の対象に入る (mokume の絵は足りないぶんだけ勝手に書き出される)。

```bash
swift run -c release Atlas --motion out/motion 24   # 動きの証跡 (mokume 側の連番)
python3 scripts/compare/serve.py            # http://127.0.0.1:8731/ と /motion.html を開く
python3 scripts/compare/animate.py          # 連番を WebP へ畳む
python3 scripts/compare/diagnostics.py      # mokume が「そうしなかった」と言った一言を集める
python3 scripts/compare/publish.py          # Gyazo へ上げ、台帳と文書を書き戻す
python3 scripts/compare/publish.py --check  # 撮り直していないものを捕まえる
python3 scripts/origins.py --check          # 原典どうしが食い違うのに測っていないか
```

比べているのが処理系の差であって撮り方の差ではないように、条件を 3 つ揃えてある
([`scripts/compare/index.html`](scripts/compare/index.html) にその理由も書いた)。

**数を出さないと決めるものが 3 種類ある。**

| | 誰が決めるか |
| --- | --- |
| 乱数・雑音・時計を使う / 字を組む | 台帳の語彙から `serve.py` が決める |
| **原典どうしが食い違う** (`.pde` と site の p5) | [`scripts/origins.py`](scripts/origins.py) が数値リテラルで探し、人が台帳へ書く |
| **原典が 1 画素も描かなかった** | 撮るたびに `index.html` が数えて決める。台帳へは理由を書かず、描かれた量 (`ink`) だけ残す |

最後の 1 つを台帳へ文で書かないのは、**絵が出るようになっても理由だけが残り、台帳が古い話を
し続ける**のを避けるため。逆向きの「原典は絵を出したのに移植が 1 画素も描いていない」は
`publish.py --check` が落とす — 157 枚を目で見張るのは回らない。

**mokume が「そうしなかった」と言ったら、数字より先にそれを読む。** 書き出しのとき mokume は
`mokume: perspective(): 写す範囲が潰れている…投影を変えませんでした` のように標準エラーへ
1 行出す。**言われたとおりにしなかったという申告**なので、一致率だけを見ても絵が食い違って
いる理由には辿り着けない。`diagnostics.py` が集めて台帳へ入れ、`comparison.md` の数字の前に
置く。**例ごとにプロセスを分けている** — mokume は同じ警告を畳むので、157 本をまとめて回すと
どの例のものか決まらない。いま出ているのは 1 本だけ (`Basics/Camera/Perspective`) で、
動きの書き出しでは 1 種類も出ていない。
**揃える前は原典側だけ 30 フレーム進み、線が 1 本ぶんずれていた。**

**本文の画像行は手で書かない。** 撮った証跡の台帳は [`ledger/shots.json`](ledger/shots.json) で、
`ledger/comparison.md` は丸ごと生成物、README のこの節も印 (`<!-- compare:begin -->`) で
囲った区間だけが生成物である。`--check` は移植・枚数・測り方・mokume の版を撮影時の指紋と
突き合わせ、**直したのに撮り直していない**を捕まえる (画像そのものは比べないので GPU も要らない)。
**捕まえられるのはこちら側の変化だけ** — 原典が変わったことは、取ってきたときにしか分からない。

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

**戻したもののうち 3 本が `v0.6.0` で閉じた。消さずに残す** — 何を踏んで、どの版で塞がったかは記録である。

| 踏んだもの | | いま |
| --- | --- | --- |
| `map` / `radians` が無い — 台帳では **33 例 / 23 例**を止める。`Basics/Math/Map` を移して踏んだ | [mokume#883](https://github.com/mokume-metal/mokume/issues/883) | **閉じた** (`v0.6.0`) |
| 帯・扇・四角の並べ方が無い — `QUADS` 8 例・`QUAD_STRIP` 6 例 | [mokume#882](https://github.com/mokume-metal/mokume/issues/882) | **閉じた** (`v0.6.0`)。ただし入ったのは**帯と扇だけ**で、四角の 14 例は止まったまま |
| 入力が出来事として届かない — `mousePressed` 18 例・`keyPressed` 11 例・`mouseDragged` 6 例 | [mokume#723](https://github.com/mokume-metal/mokume/issues/723) | **閉じた** (`v0.6.0`)。27 本が動くようになった |
| 色空間を切り替える口が無い — `colorMode` 12 例 | [mokume#778](https://github.com/mokume-metal/mokume/issues/778) | **入った** (`v0.6.0`)。ただし**目盛りは張り替えられない**ので `colorMode` は `bend` のまま |
| **`SketchApplication` が投げる失敗を、外から人に見せられない** — `RenderFailure.message` が internal なので、`Sketch.main()` と同じ文面が書けない ([`main.swift`](Sources/Atlas/main.swift)) | [mokume#899](https://github.com/mokume-metal/mokume/issues/899) | 開いたまま |
| **進行を止める口が無い** — `noLoop` 18 例・`redraw`。`Basics/Structure/NoLoop` がここで止まった | [mokume#900](https://github.com/mokume-metal/mokume/issues/900) | 開いたまま。**いまいちばん重い欠け** |

157 本を並べて撮って、**台帳では原理的に見えなかった差が 4 つ出た**。どれも語彙の名前は当たっていて、絵だけが違う。

| 踏んだもの | |
| --- | --- |
| **書き出しが Display P3 で刻まれ、同じ数から違う色が出る** — `background(204,153,0)` が `213,150,0` になる。灰色は 1 画素も違わないので気付かれにくい。**32 本が「形は合うが色が違う」に落ちる** | [mokume#911](https://github.com/mokume-metal/mokume/issues/911) |
| **太さ 1 の線が半画素ずれた画素に載る** — p5 は 2 列に 77+77、mokume は 1 列に 153。**半画素ずらすと 99.9% 合う**ので、正体は言い切れる。9 本がこれだけで落ちる | [mokume#912](https://github.com/mokume-metal/mokume/issues/912) |
| **同じ光の指定で、Processing より明るい陰影が出る** — `directionalLight` で 59 対 103。立体を扱う 13 本がまとめて落ちる | [mokume#913](https://github.com/mokume-metal/mokume/issues/913) |
| **半透明の合成が線形空間で起きる** — `fill(255, 204)` が 214 ではなく 232 になる | [mokume#669](https://github.com/mokume-metal/mokume/issues/669) へ材料として |

出来事の口 ([#723](https://github.com/mokume-metal/mokume/issues/723)) と進行を止める口 ([#900](https://github.com/mokume-metal/mokume/issues/900)) には、157 本を移して分かった**段階の違い**を書き足した — 同じ「口が無い」でも、ポーリングで書き直せるもの・前のフレームを覚えれば作れるもの・**例そのものが移せない**ものの 3 段階がある。

### 絵の差の 4 つは、`v0.6.0` でも埋まっていない

**語彙の判定は大きく動いたのに、原典との画素の一致はほとんど動かなかった。**

3 つの版すべてで数を出した 107 本で並べる (11 本は**原典どうしが食い違う**と分かって
数を出さなくなった。[#18](https://github.com/mokume-metal/works/issues/18))。

| | 平均一致率 | 動かない | 下がった | 上がった |
| --- | ---: | ---: | ---: | ---: |
| `v0.5.0` | 88.91% | — | — | — |
| `v0.6.0` + 書き直し | **89.80%** | 90 本 | 13 本 | 4 本 |
| 透明も差に入れたいま | **88.80%** | 102 本 | 5 本 | 0 本 |

`v0.6.0` で下がった 13 本は、**塗りの縁の均しが変わったため**である。`v0.6.0` は縁が半端な
画素に載るときに被覆どおり均すようになった ([works#22](https://github.com/mokume-metal/works/pull/22)
で切り分けた) — **絵としては素直になったが、p5 の均し方と揃ったわけではない**ので、
縁の画素を多く持つ例ほど差が開く。

**最後の 1% は mokume が変わったのではなく、測り方の甘さが取れたぶんである。**
差の取り方が alpha を見ておらず、**何も塗っていない透明な面と `background(0)` の黒が
完全一致になっていた** ([#17](https://github.com/mokume-metal/works/issues/17))。
`Basics/Web/LoadingImages` の「100%」がそれで、いまは 0.0% と出る。

**上の 4 つが閉じるまで、この数字は動かない。** 一致を止めているのは語彙ではなく、
Display P3・線の載り方・光の強さ・線形空間での合成だからである。**台帳の判定と画素の一致は
別の物差しで、片方が良くなっても片方は動かない** — 今回それが実測で出た。
