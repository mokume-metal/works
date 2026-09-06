# Garden — p5.js の Data Structure Garden を mokume へ

![咲きそろった庭 (frame 1)](https://i.gyazo.com/6a87b51fd3410c3ce87b87ffcbc8c56e.png)

制作トラック ([mokume ADR-0022](https://github.com/mokume-metal/mokume/blob/main/docs/decisions/0022-production-track.md)) の 3 本目。これは作品であると同時に**物差し**である。

Grain (面) と OrbitControl (視点) は mokume が得意な方向を伸ばしたものだが、**p5.js の入門者が最初に書く形のスケッチ**をそのまま書けるかは測られていなかった。[Data Structure Garden](https://p5js.org/tutorials/data-structure-garden/) はその典型 — 構造体を配列に溜め、クリックで足し、寿命が尽きたら消す。描画は `ellipse` / `circle` / `fill` / `noStroke` だけ。

**作り替えず、1 行ずつ写している。** 面 400x400・lightblue の背景・初期 20 本・毎フレーム `size *= 0.99` と `lifespan -= 1` まで原典どおりに保ってあるのは、「p5 の語彙のどこに mokume の対応物が無いか」を対応表として取り出すためである。

**20 本が萎れて消え、そのあと外から送った 5 回のクリックで植わるまで** (観測は `.mokume/observe`、クリックは `.mokume/input` から)。

![20 本が萎れきった庭に、1 要求で送った 5 クリックが植わる](https://i.gyazo.com/6e7bef42b927f2f2e03b098d4eaf1ac0.webp)

> 撮影範囲: 走っているスケッチの面だけ (`.mokume/observe` が書き出した絵で、画面は撮っていない)。70 枚・約 6 秒。**5 クリックを 1 つの要求にまとめて送って、5 本とも植わる**ところを見てほしい。`v0.5.0` まではこれが 0 本だった — [下記](#踏んでいた-1-つは-v060-で塞がった)。

## 走らせる

```bash
mokume run .      # 作って走らせる
mokume watch .    # 保存したら作り直して差し替える
mokume mcp .      # 走っているスケッチを外から観測する
```

書き出しは実行ファイルへ直に渡す (CLI は引数を通さないため)。

```bash
swift run Garden --render <置き場> <番号>   # 1 枚だけ書き出す
swift run Garden --frames <置き場> <数>     # 連番で書き出す
```

## 検証する

**同じフレーム番号からは同じ絵が出る** (mokume の [ADR-0001](https://github.com/mokume-metal/mokume/blob/main/docs/decisions/0001-founding-principles.md) 原則 2)。下のハッシュが食い違ったら、変えたつもりのないところが変わっている。

`random()` の種も既定の 0 で固定されているので、**「でたらめな 20 本」も毎回同じ**である (p5 は起動ごとに違う庭が出る)。

<!-- verify:pins -->
| | |
| --- | --- |
| works | [#22](https://github.com/mokume-metal/works/pull/22) の merge コミット (`Package.resolved` が同じツリーにある) |
| mokume | `v0.7.0` / `86b6fa147e6bd38b24768fbc5890c0ee5031298c` (`Package.resolved` が固定している) |
<!-- verify:end -->

<!-- verify:renders -->
```bash
swift run Garden --render out 1 && shasum -a 256 out/garden-1.png
# 214a852fd10b92ca3673358d8b55118102ec49e44621388c1afaf8bbae5ce5b0

swift run Garden --render out 200 && shasum -a 256 out/garden-200.png
# 1e95966084e8bb86a33e1cd059f515da1213f45bcab1aeaab025d0ad7f507e0e
```
<!-- verify:end -->

### v0.6.0 で動いたもの

**`v0.5.0` → `v0.6.0` で、円の縁だけが動いた。** frame 1 は 160000 画素のうち 4232 (2.6%)、frame 200 は 574 (0.4%)。**差の出た 4232 画素のうち 4231 は旧版で縁だったところ**で、花の内側も背景も 1 ビットも動いていない。

| x (y=8) | 旧 | 新 |
| --- | --- | --- |
| 160 | (173,216,230) — 背景そのもの | (170,212,229) |
| 161 | (83,44,197) — 花そのもの | (85,50,197) |

**旧版は縁を画素の境界へ吸わせ、新版は被覆どおりに均している。** 3 行のスケッチで切り分けられる — `rect(4, 4, 16, 8)` (整数の境界に載る) は両版で 1 ビットも変わらず、`rect(4, 20.5, 16, 8)` (半端な境界に載る) だけが変わる。旧版は半分掛かった行を落とし (0)、新版は被覆どおりに置く (188)。**円は縁が常に半端な位置に載る**ので、全周がこれに当たる。

改善の方向なので mokume へは戻していない。**上の絵は貼り替えた** — 縁の均しは目で見て分かる。

## p5.js との対応

原典が使う API を 1 つずつ当てた。**大半はそのまま当たる** — 綴りも引数の順も同じで、写経は機械的に進んだ。

| p5.js | mokume | |
| --- | --- | --- |
| `setup()` / `draw()` | `func setup()` / `func draw()` | 同じ |
| `createCanvas(400, 400)` | `SketchSettings(width:height:)` | 面は設定で宣言する (`draw` の中で作らない) |
| `ellipse(x, y, w, h)` | `ellipse(_:_:_:_:)` | 同じ。**既定の座標の読み方も同じ中心** |
| `circle(x, y, d)` | `circle(_:_:_:)` | 同じ |
| `noStroke()` / `fill()` | `noStroke()` / `fill(_:)` | 同じ |
| `random(lo, hi)` / `random(hi)` | `random(_:_:)` / `random(_:)` | 同じ (ただし種の既定が違う。下記) |
| `text()` / `textSize()` | `text(_:_:_:)` / `textSize(_:)` | 同じ |
| `mouseX` / `mouseY` | `mouseX` / `mouseY` | 同じ |
| `array.push(x)` | `array.append(x)` | Swift の語彙 |
| `background("lightblue")` | `background(173, 216, 230)` | **名前で色を引けない**。CSS の値 (#ADD8E6) を自分で書き下す |
| `color(r, g, b)` (0…255) | `color(_:_:_:)` (0…255) | **`v0.6.0` から同じ目盛りで同じ形**。0…1 で書きたいときは `LinearRGBA.display` が残っている |
| `fill(255, 204, 0)` | `fill(_:_:_:)` (0…255) | 同上 |
| `for (let f of flowers) { f.size *= 0.99 }` | `for i in flowers.indices { flowers[i].size *= 0.99 }` | **Swift の構造体は値型**なので、`for f in flowers` では書き換えが配列へ戻らない |
| `flowers.indexOf(f)` + `splice(i, 1)` | `removeAll(where:)` | 反復しながら縮められないので、描き終えてからまとめて |
| `mousePressed()` | `func mousePressed()` | **`v0.6.0` から同じ綴りで書けば呼ばれる** (`override` は要らない)。下記 |

### 踏んでいた 1 つは `v0.6.0` で塞がった

**押下を出来事として受け取る口が無かった。** 読めるのは「いま押されているか」だけだったので、押した瞬間は前のフレームとの差から自分で作ることになっていた。

```swift
// v0.5.0 まで — 原典の function mousePressed() { ... } に当たるもの
private var wasMousePressed = false

private func plantOnPress() {
    let isDown = isMousePressed
    defer { wasMousePressed = isDown }
    guard isDown, !wasMousePressed else { return }
    ...
}
```

書けはした。**書けなかったのは、1 フレームに収まった押下である** — 溜まった出来事はフレームの頭で「いまの状態」へ畳まれるので、`mouseDown` の直後に `mouseUp` が来ると押されたことがどこにも残らない。窓を人が触るぶんには滅多に起きないが、**外から送る経路 (`.mokume/input`) では構造的に起きた** — 1 回の要求に押下と解放を並べたクリックは 1 本も植わらなかった。

→ [mokume#723](https://github.com/mokume-metal/mokume/issues/723) (**閉じた**)

**`v0.6.0` は畳むのをやめたのではなく、1 件当てるごとに配るようにした。** 原典と同じ綴りで書けば呼ばれ、中で読む `mouseX` / `mouseY` はその押下を当てた直後の値になる。

```swift
// v0.6.0 から — 原典と同じ
func mousePressed() {
    var flower = createFlower()
    flower.x = mouseX
    flower.y = mouseY
    flowers.append(flower)
}
```

`.mokume/input` から送って `.mokume/observe` で数えた実測 (咲いている数は `expose` で差し出している):

| 送り方 | v0.5.0 (ポーリング) | v0.6.0 (`mousePressed()`) |
| --- | --- | --- |
| 1 要求に押下と解放を並べる | 0 本 | **5 クリックで 5 本** |
| 押下と解放を別の要求で、間を置かず送る | 0 本 | 植わる |
| 押下と解放を別の要求で、間に観測を 1 回挟む | 1 本 | 植わる |

**口が増えただけでは直らない。** `v0.6.0` のライブラリのまま、書き直す前の**ポーリングのコードで測ると 1 要求のクリックは 0 本のまま**だった ([works#22](https://github.com/mokume-metal/works/pull/22) で実測) — `draw()` から見える最終状態は今までと変わらないためである。**恩恵を受けるのは書き直した側だけ**で、それがこの作品を書き直した理由でもある。

### 詰まらなかったが、違うところ

- **`random()` の種は 0 で固定されている。** p5 は起動ごとに違う庭が出るが、こちらは毎回同じ 20 本が同じ場所に咲く。絵の再現 (ADR-0001 原則 2) を取った結果で、毎回変えたいなら `randomSeed()` へ時計を渡す
- **型を宣言する。** 原典のオブジェクトリテラルは形を持たないが、Swift では `struct Flower` を書く。5 行増えるかわりに、綴りを間違えた欄はビルドで落ちる — `flower.sizee` が `undefined` として静かに流れることがない
- **global が無い。** 原典がファイル先頭に置く `let flowers = []` は、スケッチの格納プロパティになる。描画 API がスケッチのメソッドとして生えている以上、状態も同じ所へ置くのが自然な形になった
- **`map` / `radians` は `v0.6.0` から面にある** (`lerp` / `constrain` はまだ無い)。どちらにせよこの作品では 1 度も要らなかった (原典も使っていない)

### 書いた量

| | 実質の行数 (コメント・空行を除く) |
| --- | --- |
| 原典 (p5.js) | 約 47 |
| Garden (`Flower.swift` + `Garden.swift`) — `v0.5.0` のとき | 76 |
| Garden — `v0.6.0` の語彙で書き直した後 | **66** |

**10 行減った。** 内訳は押下の立ち上がりを持つぶん (6) と、色を 255 で割るための記述 (4)。どちらも `v0.6.0` が面に口を足したぶんそのままで、こちらの工夫ではない。

残る差の内訳は、型の宣言 (8)・咲いている数を出す 2 行 (原典に無い。札と `expose`)。**移植で「別の書き方に組み替えた」箇所は 2 つだけ** (値型のための添字反復と、まとめての除去)。

## mokume へ戻したもの

**閉じた。消さずに残す** — 何を踏んで、どの版で塞がったかは記録である。

| 踏んだもの | | いま |
| --- | --- | --- |
| 押下を出来事として受け取れず、1 フレームに収まったクリックが消える | [mokume#723](https://github.com/mokume-metal/mokume/issues/723) | 閉じた (`v0.6.0`)。`mousePressed()` ほか 8 つの口が入った |
