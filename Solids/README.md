# Solids — p5.js の 3D Geometries を mokume へ

![8 つの立体が並んで回る (frame 200)](https://i.gyazo.com/9511d705106a31fa01e769664eee2fef.png)

制作トラック ([mokume ADR-0022](https://github.com/mokume-metal/mokume/blob/main/docs/decisions/0022-production-track.md)) の 4 本目。Garden と同じく、これは作品であると同時に**物差し**である。

Garden が測ったのは p5 の **2D の入門語彙だけ**だった (`ellipse` / `fill` / `random` / `mousePressed`)。mokume が売りにしている**立体の語彙は 1 つも測られていない** — Grain の `Slab` は立体だが、p5 の書き方を持ち込んだものではないので対応表にはならない。

[3D Geometries](https://p5js.org/examples/3D-Geometries/) は、p5 の WEBGL モードが持つ原形 7 つ (plane / box / cylinder / cone / torus / sphere / ellipsoid) と `model()` を 1 画面に並べ、全部を毎フレーム 1 度ずつ 3 軸に回すだけの例である。**立体の語彙の対応を測るには理想の形をしている。**

**作り替えず、1 行ずつ写している。** 面 710x400・背景 250・8 つの区画の座標・毎フレーム 1 度まで原典どおりに保ってあるのは、「p5 の立体の語彙のどこに mokume の対応物が無いか」を対応表として取り出すためである。

**そして、いちばん大きい差は動かすと出る。**

![回しても面の色が動かない](https://i.gyazo.com/e1c41c62db30204953b3830be5603d2d.webp)

> 撮影範囲: 書き出した連番 PNG (`--frames`) から作ったもので、画面は撮っていない。120 フレーム (6 秒・20fps)、形は 120 度回っている。**回っているのに、面ごとの色が 1 度も入れ替わらない**ところを見てほしい — 原典では回すたびに色が泳ぐ。理由は[下記](#踏んだもの)。

## 走らせる

```bash
mokume run .      # 作って走らせる
mokume watch .    # 保存したら作り直して差し替える
mokume mcp .      # 走っているスケッチを外から観測する
```

書き出しは実行ファイルへ直に渡す (CLI は引数を通さないため)。

```bash
swift run Solids --render <置き場> <番号>   # 1 枚だけ書き出す
swift run Solids --frames <置き場> <数>     # 連番で書き出す
```

## 検証する

**同じフレーム番号からは同じ絵が出る** (mokume の [ADR-0001](https://github.com/mokume-metal/mokume/blob/main/docs/decisions/0001-founding-principles.md) 原則 2)。下のハッシュが食い違ったら、変えたつもりのないところが変わっている。

このスケッチは乱数も揺らぎも使わないので、姿勢はフレーム番号だけで決まる (原典と同じく `frameCount` から角度を作る)。

| | |
| --- | --- |
| works | [#6](https://github.com/mokume-metal/works/pull/6) の merge コミット (`Package.resolved` が同じツリーにある) |
| mokume | `v0.5.0` / `f0d136d1d70b172b49b3419f795feba018fe4101` (`Package.resolved` が固定している) |

```bash
swift run Solids --render out 1 && shasum -a 256 out/solids-1.png
# 3c3dcaa190679f9d8829653c473a5d211405ea21f0301ebc0fc9fec415f5a211

swift run Solids --render out 200 && shasum -a 256 out/solids-200.png
# 2f1ecdf61dc7af538640d5bf8500884113791e48a5af88adb5c965340578cef0
```

## p5.js との対応

**原形は 7 つのうち 6 つが同名で当たる。** 綴りも引数の順も同じで、置くところまでは機械的に進んだ。詰まったのは**形ではなく、面の塗り方と線**である。

| p5.js | mokume | |
| --- | --- | --- |
| `plane` / `box` / `cylinder` / `cone` / `torus` / `sphere` | 同名。引数の順も同じ | `plane(70)` の**1 引数の短縮形だけ無い** (`plane(70, 70)` と書く) |
| `push()` / `pop()` | `push()` / `pop()` | 同じ。行列と塗りの両方を積む |
| `translate(x, y, z)` / `rotateX` / `rotateY` / `rotateZ` | 同じ | そのまま当たる |
| `scale(x, y, z)` | 同じ | 軸ごとに違う倍率も効く (下の `ellipsoid` で使う) |
| `frameCount` | `frameCount` | 同じ。1 から始まるのも同じ |
| `loadModel(path)` | `loadModel(_:normalize:)` / `requestModel(_:normalize:)` | **`normalize` の既定が逆** (p5 は整えない・mokume は整える)。読むのは OBJ だけで、材質は読まない |
| `model(geometry)` | `model(_:)` | 同じ |
| `background(250)` | `background(.display(red:green:blue:))` | **数値 1 つの灰色が書けない**。3 つ書き下す |
| `createCanvas(w, h, WEBGL)` | `SketchSettings(width:height:)` | **描き方のモードが無い** (立体も面も同じ面に出る)。ただし**原点は左上**なので、原典の座標を使うには中央へ寄せる 1 行が要る |
| `angleMode(DEGREES)` | **無い** | 度をラジアンへ直すのは書く側の仕事 |
| `ellipsoid(a, b, c)` | **無い** | `scale(a, b, c)` + `sphere(1)` で作る。→ [mokume#849](https://github.com/mokume-metal/mokume/issues/849) |
| `normalMaterial()` | **無い** | 断片で書く。ただし**原典と同じ絵にはならない**。下記 |
| `stroke(0)` + `sphere(50)` | **効かない** | 組み込みの立体は線を持たない。下記 |
| `describe(...)` | **無い** | 落とした |

### 踏んだもの

#### 1. 面の向きを、世界でも視点でもない座標でしか受け取れない

原典は `normalMaterial()` で塗る — 面の向きをそのまま色にする材質で、p5 はこれを**視点の座標**で渡す (`gl_FragColor = vec4(vVertexNormal, 1.0)`)。だから**回すと色が泳ぐ**。原典の説明文が「多色の表面」と言っているのはこの動きのことである。

mokume の材質は `shininess` / `metalness` / `ambient` / `emissive` の 4 つで、面の向きを色にするものは無い。断片で書くことになるが、断片が受け取れる向きは `Fragment.shapeNormal` **ただ 1 つで、これは形自身の座標である**。

```metal
float3 normal = in.shapeNormal;   // 形を回しても値が変わらない
```

模様を表面に留めるにはちょうどよい約束だが (Grain がこれを求めていた)、`normalMaterial()` を写すには足りない。**世界の座標でも視点の座標でも面の向きを受け取る手が無い。**

結果、上のアニメーションのとおり**面ごとの色が固定される**。平らな面はいちばんはっきり出る — 原典の plane は回るたびに色が変わるが、こちらは 120 フレームを通して 1 ビットも動かない (実測: frame 1 も frame 200 も `#0000ff` 一色)。

→ [mokume#847](https://github.com/mokume-metal/mokume/issues/847)

#### 2. 組み込みの立体に `stroke()` が効かない

原典は球にだけ黒い線を置く。コメントに「動きを見せるため」と書いてあるとおり、**塗りだけでは回っているかどうかが分からない**からである (球は回しても輪郭が変わらない)。

mokume では**何も出ない。** `stroke()` を置いても置かなくても絵が変わらない。

```bash
# 太さ 6 の赤にしても、1 ビットも変わらない (実測)
# 2f1ecdf61dc7af538640d5bf8500884113791e48a5af88adb5c965340578cef0  stroke なし
# 2f1ecdf61dc7af538640d5bf8500884113791e48a5af88adb5c965340578cef0  strokeWeight(6) + 赤
```

線を引く仕掛け自体はある (`Canvas+Solid.swift` の `strokeSolidRing` — 視線に正対する帯として世界の座標で組む) が、**そこへ入るのは `beginShape()` で自分で並べた頂点だけ**で、`box` / `sphere` などが通る `place()` は塗りしか置かない。

→ [mokume#850](https://github.com/mokume-metal/mokume/issues/850)

#### 3. 表示値と線形の値を行き来する関数が断片に無い

`paint()` が返すのは線形の色だが、p5 が書き出しているのは表示値である。そのまま返すと**原典より 1 段暗い**絵になるので、`sRGB` の式を断片の中に自分で書いた ([`NormalPaint.swift`](Sources/Solids/NormalPaint.swift))。

Swift 側には `LinearRGBA.display(red:green:blue:)` があるので、**同じ式が断片の側にだけ無い**という形の欠けである。Issue にはしていない — 5 行で書けるうえ、断片へ渡す `values` を `.color(.display(...))` にすれば変換済みで届くので、本当に要るのは今回のように**断片の中で数から色を作るとき**に限られる。

### 詰まらなかったが、違うところ

- **`plane()` の断片にも面の向きが届く。** `Fragment.shapeNormal` の但し書きは「平面では 0」と言っているが、これは 2D の描画のことで、立体としての `plane()` は向きを持つ (実測: `#0000ff` 一色 = 法線 `(0, 0, 1)`)
- **`loadModel()` の `normalize` の既定が原典と逆。** p5 は整えないのが既定、mokume は整えるのが既定で、いちばん長い辺が面の短いほうの半分 (この面では 200 画素) になる。既定のままだと 175 画素おきの区画からはみ出すので、原典に合わせて `normalize: false` を渡した
- **`normalize: false` にすると縦軸が裏返らない。** 縦を面の約束 (下向き) へ合わせるのは*整える側*の仕事なので、OBJ の約束どおり y を上向きに書いたモデルは逆さに出る。原典がモデルを起こすために 1 行足しているのと同じ場所に `rotateX(.pi)` を置くことになった
- **モデルは宣言しないと見つからない。** `loadModel()` が探すのは作業ディレクトリと、実行ファイルの隣に並ぶ `*.bundle` の中である。`Package.swift` の `resources` を落とすと包みが作られず、**窓からは読めて `swift run` からは読めない**、が起きる

### 原典と違えたところ

**読むモデルだけ。** 原典は NASA の `astronaut.obj` (523KB) を読むが、こちらは向きの読める矢じりを自分で書いた ([`assets/arrowhead.obj`](Sources/Solids/assets/arrowhead.obj)・14 面)。測りたいのは `loadModel()` / `model()` が通るかであってモデルの形ではないので、第三者のアセットを持ち込む理由が無い。

### 書いた量

| | 実質の行数 (コメント・空行を除く) |
| --- | --- |
| 原典 (p5.js) | 60 |
| Solids (`Solids.swift` + `NormalPaint.swift`) | 93 |

差の 33 行のうち **19 行は `normalMaterial()` の代わりの断片**である。残りは中央へ寄せる 1 行・度をラジアンへ直す 1 行・`ellipsoid` を作る 1 行・色を 3 つ書き下すぶん・`Model` と `Shader` を持つ格納プロパティと `try?` の受け。**移植で「別の書き方に組み替えた」箇所は 1 つだけ** (`ellipsoid` → `scale` + `sphere`)。

### 書き出しの口を写すのは、これで 3 度目

[`main.swift`](Sources/Solids/main.swift) の `--render` / `--frames` は Garden から写した。Garden は Grain から写している。**3 つを diff すると、違うのはコメントと 3 行の識別子だけ**で、残りは 1 文字も変わらない。

作品ではないので mokume の Issue にはしていないが、**絵を書き出す口が道具の側に無い**ことの現れではある (`mokume run` は引数を通さないので、書き出しは実行ファイルへ直に渡すしかない)。

## mokume へ戻したもの

| 踏んだもの | |
| --- | --- |
| 面の向きを世界／視点の座標で受け取れず、`normalMaterial()` に当たるものが書けない | [mokume#847](https://github.com/mokume-metal/mokume/issues/847) |
| 原形が 7 つのうち 6 つで、`ellipsoid()` が無い | [mokume#849](https://github.com/mokume-metal/mokume/issues/849) |
| 組み込みの立体に `stroke()` が効かない | [mokume#850](https://github.com/mokume-metal/mokume/issues/850) |
