# Ring — p5.js の Triangle Strip を mokume へ

![虹の輪 (frame 1・頂点数 6)](https://i.gyazo.com/af2c41631bf84ad67b6abd8c3a76a9c1.png)

制作トラック ([mokume ADR-0022](https://github.com/mokume-metal/mokume/blob/main/docs/decisions/0022-production-track.md)) の 4 本目。Garden・Solids と同じく、これは作品であると同時に**物差し**である。

Garden が測ったのは 2D の入門語彙、Solids が測ったのは立体の語彙で、**頂点を自分で並べて形を作る経路は 1 度も通っていなかった**。原形 (円・矩形・箱・球) の外へ出る道はここ 1 本しかないうえ、口の数もいちばん多い (`beginShape` / `vertex` / `bezierVertex` / `quadraticVertex` / `curveVertex` / `beginContour` / `normal` / `endShape`)。

[Triangle Strip](https://p5js.org/examples/Angles-And-Motion-Triangle-Strip/) は、二重の円の上に頂点を交互に置いて帯にし、頂点ごとに色を変えて虹にする 38 行の例である。**頂点列を測るには理想の形をしている** — 帯の並べ方・頂点ごとの塗り・マウスで変わる頂点数が、この 1 本に全部入っている。

**作り替えず、1 行ずつ写している。** 面 720x400・背景 0・内半径 100 / 外半径 150・頂点数は `map(mouseX, 0, width, 6, 60)` を丸めたもの・角度の刻みは `180 / pointCount` 度まで原典どおりに保ってあるのは、「p5 の頂点列の語彙のどこに mokume の対応物が無いか」を対応表として取り出すためである。

**そして、この作品は外から動かさないと動かない。**

![外から送ったマウス位置で頂点数が 6 から 60 へ変わる](https://i.gyazo.com/29b005c57f5bac10e449b1a07e8bafe1.webp)

> 撮影範囲: 走っているスケッチの面だけ (`.mokume/observe` が書き出した絵で、画面は撮っていない)。60 枚・4 秒。**外から `mouseMoved` を送っては 1 枚撮る**を往復して、頂点数が 6 → 60 → 6 と変わるところを見てほしい。頂点数はマウスの位置からしか決まらないので、**窓を持たない書き出し (`--render`) では 6 のまま動かない**。

## 走らせる

```bash
mokume run .      # 作って走らせる
mokume watch .    # 保存したら作り直して差し替える
mokume mcp .      # 走っているスケッチを外から観測する
```

書き出しは実行ファイルへ直に渡す (CLI は引数を通さないため)。

```bash
swift run Ring --render <置き場> <番号>   # 1 枚だけ書き出す
swift run Ring --frames <置き場> <数>     # 連番で書き出す
```

## 検証する

**同じフレーム番号からは同じ絵が出る** (mokume の [ADR-0001](https://github.com/mokume-metal/mokume/blob/main/docs/decisions/0001-founding-principles.md) 原則 2)。下のハッシュが食い違ったら、変えたつもりのないところが変わっている。

このスケッチは時刻も乱数も使わない。姿勢を決めるのは `mouseX` だけなので、**書き出した絵はフレーム番号によらず同じ**になる (下の 2 つのハッシュが一致しているのはそのため)。

| | |
| --- | --- |
| works | [#22](https://github.com/mokume-metal/works/pull/22) の merge コミット (`Package.resolved` が同じツリーにある) |
| mokume | `v0.6.0` / `d153f982435b775101772d904153c8d2b6711fd6` (`Package.resolved` が固定している) |

```bash
swift run Ring --render out 1 && shasum -a 256 out/ring-1.png
# 78af752be63c53976014bfdb28eb8e1d86f4d7635247d9eec676c914677785d5

swift run Ring --render out 200 && shasum -a 256 out/ring-200.png
# 78af752be63c53976014bfdb28eb8e1d86f4d7635247d9eec676c914677785d5
```

**`v0.5.0` → `v0.6.0` で、この絵は 1 ビットも動かなかった。** 同じ版上げで Garden の円の縁と Grain の重ね塗りは動いている ([Garden](../Garden/README.md#v060-で動いたもの) / [Grain](../Grain/README.md)) — 動いたのは**塗りの縁が半端な画素に載るとき**の被覆の置き方で、この作品が置く帯は頂点をそのまま並べたものなので当たらない。

**動くところは外から確かめる。** 窓口とスケッチで区画の基準を揃えて立て、`mouseMoved` を送っては撮る。

```bash
MOKUME_WORK_DIR="$PWD" mokume run Ring   # 作品の親から立てるとき
```

送った位置と、スケッチが差し出した頂点数 (`expose`) の実測:

| 送った `mouseX` | `pointCount` | 期待 |
| --- | --- | --- |
| 0 | 6 | 6 |
| 360 | 33 | 33 |
| 719 | 60 | 60 |

**送った座標はそのまま面の座標として届く。** 窓の大きさにも位置にも影響されない。

## p5.js との対応

**帯そのものが無い。** 頂点を並べる口は揃っているが、並べたものを「帯」として読む約束が無いので、原典が 1 語で書いているところが書く側の仕事になる。

| p5.js | mokume | |
| --- | --- | --- |
| `beginShape()` / `vertex(x, y)` / `endShape()` | 同名。引数の順も同じ | そのまま当たる |
| `fill()` を `vertex()` の間で切り替える | **同じように効く** | 置いた時点の塗りが頂点ごとに残る (`BuildingVertex.fill`)。原典の虹はこれがそのまま当たった |
| `beginShape(TRIANGLE_STRIP)` | **無い** | `VertexKind` は `.polygon` / `.points` / `.lines` / `.triangles` の 4 つ。帯は書く側で三角形へ畳む。→ [mokume#882](https://github.com/mokume-metal/mokume/issues/882) |
| `map(v, a, b, c, d)` | **無い** | 割って掛ける。→ [mokume#883](https://github.com/mokume-metal/mokume/issues/883) |
| `angleMode(DEGREES)` | **無い** | 度をラジアンへ直すのは書く側の仕事 (Solids でも同じ場所で詰まった)。→ [mokume#883](https://github.com/mokume-metal/mokume/issues/883) |
| `colorMode(HSB)` + `fill(色相, 255, 255)` | **無い** | 色相から表示値を作る式を書く ([`Hue.swift`](Sources/Ring/Hue.swift))。**Issue にしていない** — `main` には [#778](https://github.com/mokume-metal/mokume/issues/778) で既に入っている |
| `round(x)` | `x.rounded()` | Swift の語彙 |
| `mouseX` | `mouseX` | 同じ。**外から送った座標も面の座標のまま届く** |
| `createP()` / `label.html(...)` | `expose(_:_:)` | DOM は持たない。代わりに観測へ差し出すと、**撮った絵と同じ応答に値が載る** |
| `createCanvas(w, h, WEBGL)` | `SketchSettings(width:height:)` | 描き方のモードが無い。**原点は左上**なので、原典の `translate(-centerX, -centerY)` は**置かなくてよい** (Solids では逆に 1 行増えた) |
| `background(0)` | `background(.display(red:green:blue:))` | 数値 1 つの黒が書けない。3 つ書き下す |
| 既定の輪郭 = 黒 | 既定の輪郭 = **白** | 原典は背景に沈むが、こちらは**三角形の継ぎ目が白く出る**。下記 |
| `describe(...)` | **無い** | 落とした |

### 踏んだもの

#### 1. 頂点の並べ方に、帯も扇も無い

原典は `beginShape(TRIANGLE_STRIP)` の 1 語で「3 つ目からは直前の 2 点を使い回す」と宣言する。mokume の `VertexKind` にあるのは 4 つで、**帯 (`TRIANGLE_STRIP`) も扇 (`TRIANGLE_FAN`) も四角 (`QUADS` / `QUAD_STRIP`) も無い**。

`.triangles` で写せはするが、使い回しは書く側が行うことになる。

```swift
// 帯なら 2n 点。三角形なら 3(n-2) 点 — 60 点の輪で 118 → 174 へ増える
beginShape(.triangles)
for i in 0..<(strip.count - 2) {
    for point in [strip[i], strip[i + 1], strip[i + 2]] {
        fill(point.fill)
        vertex(point.x, point.y)
    }
}
endShape()
```

**同じ頂点を 3 回書くので、位置と色を先に溜める場所も要る** (`Ring.Point`)。原典が置くそばから `vertex()` を呼べるのは、使い回しを面の側が引き受けているからである。

→ [mokume#882](https://github.com/mokume-metal/mokume/issues/882)

#### 2. 角度の単位変換と写像が無い

原典が 1 語で書く `map()` と `angleMode(DEGREES)` に当たるものが無く、どちらも自分で書いた。

```swift
let pointCount = Int((6 + (mouseX / width) * (60 - 6)).rounded())   // map()
private static func radians(_ degrees: Float) -> Float { degrees * .pi / 180 }
```

**これは面の側が待っていたものである。** アンブレラ ([`Sources/mokume/Umbrella.swift`](https://github.com/mokume-metal/mokume/blob/main/Sources/mokume/Umbrella.swift)) は三角関数 7 本を名指しで通したところで、こう書いて止めている。

> 角度の単位変換・補間・写像は**ここに足さない**。「毎回書いている」ものが作品トラック (ADR-0022) から見えてから決める (ADR-0001 原則 4・#193)。

作品トラックから見えたので戻した。Garden は「`map` / `lerp` / `constrain` は無いが 1 度も要らなかった」と書いており、**要った作品はこれが最初**である。

→ [mokume#883](https://github.com/mokume-metal/mokume/issues/883)

### 詰まらなかったが、違うところ

- **既定の輪郭の色が逆を向いている。** p5 の既定は黒で、原典は背景が黒なので線が沈む。mokume の既定は白 (`Canvas.currentStroke`) なので、**同じコードから三角形の継ぎ目が見える絵が出る** (上の静止画)。線を引く場所も本数も原典と同じで、違うのは色だけ。`noStroke()` を 1 行足せば原典の見た目になるが、**原典に無い行なので足していない**
- **原典の `translate(-centerX, -centerY)` を落とせる。** あれは WEBGL の中央原点を左上へ戻す 1 行で、mokume の原点は初めから左上である。Solids では逆に「中央へ寄せる 1 行」を足すことになった — **同じ違いが、例によって足す側にも引く側にも出る**
- **窓が開いた直後だけ、送った位置が上書きされる。** 立ち上げ直後に `mouseMoved` を 1 件送って撮ったら、送っていない値が返った (送 360 に対し 14 = 実際のポインタの位置)。窓が本物のポインタの下に開くと、その位置が出来事として届くためである。**送る → 応答を待つ → 撮る**を往復すれば起きない (上の実測はすべてこの往復で取っている)
- **観測と入力の区画は、起動の瞬間に無いと効かない。** 立ててから `input` を初めて呼ぶと「区画を作ったので起動し直せ」と言われる。既知 ([mokume#464](https://github.com/mokume-metal/mokume/issues/464))
- **`expose()` は観測の応答にそのまま載る。** 撮った絵と同じ応答に `values.pointCount` が入るので、絵と数字の対応を 2 つのファイルを読む間合いに賭けずに済む。works で使ったのはこれが初めて

### 書いた量

| | 実質の行数 (コメント・空行を除く) |
| --- | --- |
| 原典 (p5.js) | 38 |
| Ring (`Ring.swift` + `Hue.swift`) | 65 |

差の 27 行のうち **16 行は `colorMode(HSB)` の代わり**である。残りは帯を三角形へ畳むぶん (5)・頂点を溜める型の宣言 (5)・`map` と `radians` (2)・色を 3 つ書き下すぶん。**移植で「別の書き方に組み替えた」箇所は 1 つだけ** (帯 → 三角形)。

原典が持っていて落としたのは `describe()` と、ラベルを出す DOM の 3 行 (`createP` / `style` / `position`) — 後者は `expose()` 1 行に置き換わっている。

### 書き出しの口を写すのは、これで 4 度目

[`main.swift`](Sources/Ring/main.swift) の `--render` / `--frames` は Solids から写した。Solids は Garden から、Garden は Grain から写している。**4 つを diff すると、違うのはコメントと 3 行の識別子だけ**である。

作品ではないので mokume の Issue にはしていないが、**絵を書き出す口が道具の側に無い**ことの現れではある (`mokume run` は引数を通さないので、書き出しは実行ファイルへ直に渡すしかない)。mokume 側には `save(_:)` と `beginRecord(_:)` があるが、どちらもスケッチの中から呼ぶ口なので、**外から「何枚書き出せ」と言う経路にはならない**。

## mokume へ戻したもの

| 踏んだもの | |
| --- | --- |
| 頂点の並べ方に帯・扇・四角が無く、`TRIANGLE_STRIP` を写すと使い回しが書く側の仕事になる | [mokume#882](https://github.com/mokume-metal/mokume/issues/882) |
| 角度の単位変換と写像 (`map` / `radians`) が無い — アンブレラが待っていた実需 | [mokume#883](https://github.com/mokume-metal/mokume/issues/883) |
