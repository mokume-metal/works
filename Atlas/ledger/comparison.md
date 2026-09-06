# 原典と並べた全数

<!-- scripts/compare/publish.py が書く。手で直さない -->

移した 157 本を、原典と並べて突き合わせたもの。**左が原典・右が mokume。** 原典は processing-website が例ごとに配る `liveSketch.js` (Processing 版と 1 行ずつ対応した p5.js) を走らせたもので、**条件を 3 つ揃えてある** — マウスを動かさない・決めた枚数で止める・等倍。

数を出したのが 107 本 (うち 1 本は原典が静止画しか無く、縮めて比べているので参考値)、**数を出さなかったのが 50 本**。理由は 1 つではない — 乱数・雑音・時計 30 本・字を組む 7 本・原典が 2 つ食い違う 10 本・原典が 1 画素も描かない 2 本・面の大きさが違う 1 本。

数は 4 つ出す。**どれが「同じ絵」かは決めていない** — 見て決めるのは人である。

**mokume が「そうしなかった」と言った例には、数字より先にその一言を置いてある** (1 本)。言われたとおりにしなかったという申告なので、一致率だけを見ても絵が食い違っている理由には辿り着けない。

| | 何を見るか |
| --- | --- |
| その場 | そのままの位置で、色が差 8 以内 (目で見て同じ色) |
| 半画素 | mokume を半画素動かしてよいとしたとき。**ずらすと合うなら、正体は線の載せ方** |
| 形 | 明るさの縁だけを取り出し、1 画素の幅を許して比べたもの |
| 完全 | 1 画素も違わない |

道具は mokume v0.6.0 / p5.js 1.9.4。

## 動きの証跡について

**静止画の下に動くものが付いている例が 123 本ある。** 止まった 1 枚では正しいかどうか判断できないもの (動く例・マウスが要る例) には、アニメーション WebP を併載してある。**置き換えではない** — 細かい差は静止画のほうが向いている。

- **撮影範囲**: スケッチの面だけ (窓の縁も他のアプリも入らない)。左が原典・右が mokume
- **何を撮ったか**: 12 fps で 24 枚 = 2 秒。半分の大きさ
- **マウスは決まった道すじで動かす**。横に 1 往復・縦に 2 往復し、**真ん中の 3 分の 1 だけ押す**。原典と mokume で式が同じでないと、動きの違いなのか入力の違いなのか分からなくなるので、[`Support/MousePath.swift`](../Sources/Atlas/Support/MousePath.swift) と [`scripts/compare/motion.html`](../scripts/compare/motion.html) に同じ式を置いている
- **原典の側では出来事も起こす** (`mousePressed()` / `mouseDragged()` など)。本物のブラウザなら呼ばれるものなので、呼ばないと原典だけ手加減したことになる。mokume にその口が無いことは差として出てよい
- **動きが付いていない例**は、決まった道すじで動かしても絵が 1 枚も変わらなかったもの (静止形の例と、出来事の口が無くて止まっている例)

| 群 | 本数 | 測った | その場で一致の中央値 |
| --- | ---: | ---: | ---: |
| [Basics/Arrays](#basicsarrays) | 3 | 0 | — |
| [Basics/Camera](#basicscamera) | 3 | 1 | 36.9% |
| [Basics/Color](#basicscolor) | 7 | 6 | 100.0% |
| [Basics/Control](#basicscontrol) | 5 | 4 | 92.8% |
| [Basics/Data](#basicsdata) | 6 | 4 | 98.1% |
| [Basics/Form](#basicsform) | 8 | 7 | 98.9% |
| [Basics/Image](#basicsimage) | 7 | 5 | 78.7% |
| [Basics/Input](#basicsinput) | 12 | 9 | 99.9% |
| [Basics/Lights](#basicslights) | 6 | 5 | 83.2% |
| [Basics/Math](#basicsmath) | 20 | 12 | 99.7% |
| [Basics/Objects](#basicsobjects) | 4 | 3 | 99.2% |
| [Basics/Shape](#basicsshape) | 1 | 1 | 90.8% |
| [Basics/Structure](#basicsstructure) | 10 | 8 | 99.1% |
| [Basics/Transform](#basicstransform) | 6 | 5 | 97.1% |
| [Basics/Typography](#basicstypography) | 3 | 0 | — |
| [Basics/Web](#basicsweb) | 2 | 2 | 99.4% |
| [Topics/Advanced Data](#topicsadvanced-data) | 4 | 1 | 100.0% |
| [Topics/Animation](#topicsanimation) | 2 | 2 | 100.0% |
| [Topics/Cellular Automata](#topicscellular-automata) | 2 | 0 | — |
| [Topics/Drawing](#topicsdrawing) | 3 | 3 | 100.0% |
| [Topics/File IO](#topicsfile-io) | 3 | 1 | 99.6% |
| [Topics/Fractals and L-Systems](#topicsfractals-and-l-systems) | 6 | 6 | 99.9% |
| [Topics/GUI](#topicsgui) | 4 | 4 | 99.4% |
| [Topics/Image Processing](#topicsimage-processing) | 6 | 4 | 100.0% |
| [Topics/Interaction](#topicsinteraction) | 7 | 6 | 99.3% |
| [Topics/Motion](#topicsmotion) | 9 | 5 | 100.0% |
| [Topics/Simulate](#topicssimulate) | 5 | 0 | — |
| [Topics/Vectors](#topicsvectors) | 3 | 3 | 99.8% |

## Basics/Arrays

### `Array`

台帳は `blocked` ・ **測らない** — 原典が 2 つある — site の p5 は線を 1 本おきに引く (i += 2)。移植は Processing の .pde に従っている

![Basics/Arrays/Array](https://i.gyazo.com/de1eef549a05299ed0b1a7dfdfb7ec98.png)

### `Array2D`

台帳は `blocked` ・ **測らない** — 原典が 2 つある — site の p5 は `strokeWeight(6)` を落とし、点が 1 画素になる。移植は Processing の .pde に従っている

![Basics/Arrays/Array2D](https://i.gyazo.com/1ba48e9bb8275a84b1f4912db7e42244.png)

### `ArrayObjects`

台帳は `clean` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Basics/Arrays/ArrayObjects](https://i.gyazo.com/71a3cf539225b3edd457455dd102f3f3.png)

![Basics/Arrays/ArrayObjects の動き](https://i.gyazo.com/7708e439e1e70eff2067606978ca3f7b.webp)

## Basics/Camera

### `MoveEye`

台帳は `clean` ・ その場 **36.9%** ・ 半画素 36.9% ・ 形 98.5% ・ 完全 36.9%

![Basics/Camera/MoveEye](https://i.gyazo.com/f80f5442ee9764cde56f6aeed5357e8c.png)

![Basics/Camera/MoveEye の動き](https://i.gyazo.com/37e667dde5cfd94bbb3181ed4c8e7ade.webp)

### `Orthographic`

台帳は `clean` ・ **測らない** — 面の大きさが違う (原典 640x360 / mokume 600x360)

![Basics/Camera/Orthographic](https://i.gyazo.com/4118c33a6163975a5e55114396d9f977.png)

![Basics/Camera/Orthographic の動き](https://i.gyazo.com/8b798272efb85981ca6ced27eeaf69f7.webp)

### `Perspective`

> **mokume はこう言っている** — perspective(): 写す範囲が潰れている・数でない値が渡されたので、投影を変えませんでした

台帳は `clean` ・ **測らない** — 原典が 1 画素も描かなかった。mokume だけが描いている

![Basics/Camera/Perspective](https://i.gyazo.com/81bf5c63510d6ce0a97721427810ff4f.png)

![Basics/Camera/Perspective の動き](https://i.gyazo.com/b07ac26e622373931ad78794b3fe38a4.webp)

## Basics/Color

### `Brightness`

台帳は `bend` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 100.0% ・ どちらも背景だけ

![Basics/Color/Brightness](https://i.gyazo.com/7f7758f15a725ff2bd402676669e4604.png)

![Basics/Color/Brightness の動き](https://i.gyazo.com/ef44d3607263d4ab7722ba253c461fdb.webp)

### `ColorVariables`

台帳は `clean` ・ その場 **65.3%** ・ 半画素 65.3% ・ 形 100.0% ・ 完全 0.0%

![Basics/Color/ColorVariables](https://i.gyazo.com/d7d7f87b58baae3d367d54f5d08ef692.png)

### `Hue`

台帳は `bend` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 100.0%

![Basics/Color/Hue](https://i.gyazo.com/1134d788a2a7959f485d79f986166fb5.png)

![Basics/Color/Hue の動き](https://i.gyazo.com/aa66fa611360567388c827a4911341bd.webp)

### `LinearGradient`

台帳は `blocked` ・ その場 **0.0%** ・ 半画素 0.0% ・ 形 99.7% ・ 完全 0.0%

![Basics/Color/LinearGradient](https://i.gyazo.com/41df4004afcdd940ae53bf83dc347e06.png)

### `RadialGradient`

台帳は `bend` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Basics/Color/RadialGradient](https://i.gyazo.com/e2ab33f6f249e6fcd65d47b5351b1a0c.png)

![Basics/Color/RadialGradient の動き](https://i.gyazo.com/0b8f38017ad35cd6f3da2e922702b9ec.webp)

### `Relativity`

台帳は `blocked` ・ その場 **39.5%** ・ 半画素 39.5% ・ 形 100.0% ・ 完全 0.0%

![Basics/Color/Relativity](https://i.gyazo.com/6c434c8117436b250f63bd1e137740b7.png)

### `Saturation`

台帳は `bend` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 100.0%

![Basics/Color/Saturation](https://i.gyazo.com/bb30dfa18ff401d2f65db98b1f3f738b.png)

![Basics/Color/Saturation の動き](https://i.gyazo.com/37883846ed8a6be6c9f823361aeb1444.webp)

## Basics/Control

### `Conditionals1`

台帳は `clean` ・ その場 **92.8%** ・ 半画素 99.9% ・ 形 100.0% ・ 完全 92.8%

![Basics/Control/Conditionals1](https://i.gyazo.com/99cca3ac8e171ad48a8ba0963882d448.png)

### `Conditionals2`

台帳は `clean` ・ その場 **56.9%** ・ 半画素 99.9% ・ 形 78.3% ・ 完全 56.9% ・ 縦線が半画素ずれる。ずらすと 99.9% 合う

![Basics/Control/Conditionals2](https://i.gyazo.com/981cd557502f05458a2be728afd94150.png)

### `EmbeddedIteration`

台帳は `clean` ・ **測らない** — 原典が 2 つある — 線の濃さが `stroke(255, 100)` 対 `stroke(255, 50)` で倍違う

![Basics/Control/EmbeddedIteration](https://i.gyazo.com/c891c5e171356b49d16a79da2b3ad1c9.png)

### `Iteration`

台帳は `clean` ・ その場 **98.1%** ・ 半画素 98.1% ・ 形 99.6% ・ 完全 98.1%

![Basics/Control/Iteration](https://i.gyazo.com/a14519e7fc53b5ad258c96be83329e64.png)

### `LogicalOperators`

台帳は `clean` ・ その場 **81.7%** ・ 半画素 99.7% ・ 形 99.9% ・ 完全 81.7%

![Basics/Control/LogicalOperators](https://i.gyazo.com/fb8a559db7ab39745677bfa40403af5c.png)

## Basics/Data

### `CharactersStrings`

台帳は `blocked` ・ **測らない** — 字を組む。原典はブラウザの、mokume は macOS の書体で字形が違う

![Basics/Data/CharactersStrings](https://i.gyazo.com/4c6bc5ecff3dae9d2de6f085d12e399f.png)

### `DatatypeConversion`

台帳は `blocked` ・ **測らない** — 字を組む。原典はブラウザの、mokume は macOS の書体で字形が違う

![Basics/Data/DatatypeConversion](https://i.gyazo.com/06b92bc0d0acfd7fdd30537acb75b31a.png)

### `IntegersFloats`

台帳は `clean` ・ その場 **99.7%** ・ 半画素 99.9% ・ 形 100.0% ・ 完全 99.7%

![Basics/Data/IntegersFloats](https://i.gyazo.com/191e5b49d652bacb3731c21169234d27.png)

![Basics/Data/IntegersFloats の動き](https://i.gyazo.com/4597021cceaf8fff5948f29167415d2e.webp)

### `TrueFalse`

台帳は `clean` ・ その場 **91.4%** ・ 半画素 99.9% ・ 形 100.0% ・ 完全 91.4%

![Basics/Data/TrueFalse](https://i.gyazo.com/a4da7787bc9d679fb25f225e548568f6.png)

### `VariableScope`

台帳は `blocked` ・ その場 **86.4%** ・ 半画素 99.8% ・ 形 88.0% ・ 完全 86.4%

![Basics/Data/VariableScope](https://i.gyazo.com/061980b747a0c8799b6d94fe6f5e1093.png)

### `Variables`

台帳は `clean` ・ その場 **98.1%** ・ 半画素 98.1% ・ 形 100.0% ・ 完全 98.1%

![Basics/Data/Variables](https://i.gyazo.com/e4133c65d58248fddfc11a911ef196e8.png)

## Basics/Form

### `Bezier`

台帳は `bend` ・ その場 **96.1%** ・ 半画素 97.2% ・ 形 99.9% ・ 完全 96.1% ・ 曲線の輪郭のアンチエイリアス

![Basics/Form/Bezier](https://i.gyazo.com/6ff2bfe81e2ad2ff547000e2a668fe74.png)

![Basics/Form/Bezier の動き](https://i.gyazo.com/44126782f06198914f544018951b7c4f.webp)

### `PieChart`

台帳は `blocked` ・ その場 **99.2%** ・ 半画素 99.6% ・ 形 100.0% ・ 完全 93.9%

![Basics/Form/PieChart](https://i.gyazo.com/66daf505a597a927cdd25263be837c58.png)

### `PointsLines`

台帳は `clean` ・ その場 **99.7%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 99.7%

![Basics/Form/PointsLines](https://i.gyazo.com/b7d2953af479cd30a4a882c538636eee.png)

### `Primitives3D`

台帳は `clean` ・ その場 **66.4%** ・ 半画素 66.4% ・ 形 67.3% ・ 完全 66.4%

![Basics/Form/Primitives3D](https://i.gyazo.com/6c232a862640edc0b905a90b9b2c2abf.png)

### `RegularPolygon`

台帳は `clean` ・ その場 **98.9%** ・ 半画素 98.9% ・ 形 99.9% ・ 完全 98.9%

![Basics/Form/RegularPolygon](https://i.gyazo.com/233c8a54f602d4da259f3a306faf9410.png)

![Basics/Form/RegularPolygon の動き](https://i.gyazo.com/702cf12d22cc02faec98df189150228f.webp)

### `ShapePrimitives`

台帳は `clean` ・ その場 **99.2%** ・ 半画素 99.3% ・ 形 100.0% ・ 完全 99.1%

![Basics/Form/ShapePrimitives](https://i.gyazo.com/f642282b74aa7c405fef09602b747b38.png)

### `Star`

台帳は `clean` ・ **測らない** — 原典が 2 つある — 真ん中の星の回転が `frameCount / 400` 対 `/ 50` で 8 倍速い

![Basics/Form/Star](https://i.gyazo.com/3476252f29bab2e011e05dd3d8c27944.png)

![Basics/Form/Star の動き](https://i.gyazo.com/68d97d44b0ad1891213f89f2b5db2dda.webp)

### `TriangleStrip`

台帳は `clean` ・ その場 **98.2%** ・ 半画素 98.2% ・ 形 98.8% ・ 完全 98.2%

![Basics/Form/TriangleStrip](https://i.gyazo.com/72f39cc6388b8b26f19e340a80b74a79.png)

![Basics/Form/TriangleStrip の動き](https://i.gyazo.com/7f7ee0e86beaa0f9e57ff04861d04a17.webp)

## Basics/Image

### `Alphamask`

台帳は `blocked` ・ その場 **1.3%** ・ 半画素 1.4% ・ 形 83.7% ・ 完全 0.0%

![Basics/Image/Alphamask](https://i.gyazo.com/eb47a8e2e4cf4d2dd2c08247e1003be7.png)

![Basics/Image/Alphamask の動き](https://i.gyazo.com/ee36614a1af9380a62bc08c434368acf.webp)

### `BackgroundImage`

台帳は `clean` ・ その場 **99.7%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 55.5%

![Basics/Image/BackgroundImage](https://i.gyazo.com/baf9de9304ea84e8a3ff2d6fc0120f56.png)

![Basics/Image/BackgroundImage の動き](https://i.gyazo.com/a028d01e5f2c1ca4a45ca99c6a3e0b5f.webp)

### `CreateImage`

台帳は `clean` ・ その場 **72.6%** ・ 半画素 72.8% ・ 形 100.0% ・ 完全 71.7%

![Basics/Image/CreateImage](https://i.gyazo.com/80e1e1e5fb09e234945c7f1957d8bef2.png)

![Basics/Image/CreateImage の動き](https://i.gyazo.com/5ba360bcdbdfb3be9e87e6835c3cd6ef.webp)

### `LoadDisplayImage`

台帳は `clean` ・ その場 **98.7%** ・ 半画素 98.8% ・ 形 100.0% ・ 完全 45.7%

![Basics/Image/LoadDisplayImage](https://i.gyazo.com/a71672ca91a65aa6622ecb330cc196da.png)

### `Pointillism`

台帳は `clean` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Basics/Image/Pointillism](https://i.gyazo.com/7946804aab12ada9b5f01739f8e5018f.png)

![Basics/Image/Pointillism の動き](https://i.gyazo.com/a1bd98106e4268ba96c796229dc74975.webp)

### `RequestImage`

台帳は `clean` ・ **測らない** — 原典が 1 画素も描かなかった。mokume だけが描いている

![Basics/Image/RequestImage](https://i.gyazo.com/5690c049cda0695d76245756324565d9.png)

![Basics/Image/RequestImage の動き](https://i.gyazo.com/ad00efe64c08c45c597820217831f18b.webp)

### `Transparency`

台帳は `clean` ・ その場 **78.7%** ・ 半画素 81.5% ・ 形 99.7% ・ 完全 13.5%

![Basics/Image/Transparency](https://i.gyazo.com/fca829bf4b99e7631db5817aae6d86bc.png)

![Basics/Image/Transparency の動き](https://i.gyazo.com/3fd935382417ebc0f1e9a24989b625e2.webp)

## Basics/Input

### `Clock`

台帳は `blocked` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Basics/Input/Clock](https://i.gyazo.com/468169a83bf9306954d0c4ebf09e00db.png)

![Basics/Input/Clock の動き](https://i.gyazo.com/b600c25422df4c3f252b3cedac5dc55d.webp)

### `Constrain`

台帳は `write-only` ・ その場 **99.9%** ・ 半画素 99.9% ・ 形 100.0% ・ 完全 99.9%

![Basics/Input/Constrain](https://i.gyazo.com/73994e00b42c255b74703232221335a1.png)

![Basics/Input/Constrain の動き](https://i.gyazo.com/1b5195887ab4409c58a0d9c878305c74.webp)

### `Easing`

台帳は `clean` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 100.0%

![Basics/Input/Easing](https://i.gyazo.com/4525c5391c2969306dd4a9d5565d4a9f.png)

![Basics/Input/Easing の動き](https://i.gyazo.com/a9b2049d5c8023822c8590da32cb8589.webp)

### `Keyboard`

台帳は `blocked` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Basics/Input/Keyboard](https://i.gyazo.com/3df7fe5b08860222c3cb39ad7d330a21.png)

### `KeyboardFunctions`

台帳は `bend` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 0.0% ・ どちらも背景だけ

![Basics/Input/KeyboardFunctions](https://i.gyazo.com/29ea3a296bf99f619ca5b0844a3a8a40.png)

### `Milliseconds`

台帳は `blocked` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Basics/Input/Milliseconds](https://i.gyazo.com/03c158b715acde4d8413767020b334b2.png)

![Basics/Input/Milliseconds の動き](https://i.gyazo.com/7bc01fbf85f420de70fc42c0933eca80.webp)

### `Mouse1D`

台帳は `bend` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 100.0%

![Basics/Input/Mouse1D](https://i.gyazo.com/f339ca3d0fc0fd8f99db3b003ab6ea49.png)

![Basics/Input/Mouse1D の動き](https://i.gyazo.com/9caf012f793a101c3d5e6d2a1a38dcb7.webp)

### `Mouse2D`

台帳は `clean` ・ その場 **92.1%** ・ 半画素 92.1% ・ 形 100.0% ・ 完全 92.1% ・ 半透明の合成 (線形空間で混ぜるので 214 ではなく 232)

![Basics/Input/Mouse2D](https://i.gyazo.com/b0043f7a48c18cfe0199553b20dd3a8f.png)

![Basics/Input/Mouse2D の動き](https://i.gyazo.com/cf887f0ff6262b04f4eca199fb9e8d48.webp)

### `MouseFunctions`

台帳は `clean` ・ その場 **99.7%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 99.7%

![Basics/Input/MouseFunctions](https://i.gyazo.com/1d5702fca6283ae762bdefd246d3745f.png)

![Basics/Input/MouseFunctions の動き](https://i.gyazo.com/b17e1312a4726115aabe2014ba1026ab.webp)

### `MousePress`

台帳は `clean` ・ その場 **99.9%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 99.9%

![Basics/Input/MousePress](https://i.gyazo.com/3affe41ebf6f7d65d635496d6889e857.png)

![Basics/Input/MousePress の動き](https://i.gyazo.com/6fe726bb5191c6ae91f5e0c1227b0746.webp)

### `MouseSignals`

台帳は `clean` ・ その場 **99.1%** ・ 半画素 99.1% ・ 形 100.0% ・ 完全 99.1%

![Basics/Input/MouseSignals](https://i.gyazo.com/2c0cdd521499745b94d1e8f600b2eae2.png)

![Basics/Input/MouseSignals の動き](https://i.gyazo.com/6def14c5545d022b7d05541f0fbd5c15.webp)

### `StoringInput`

台帳は `clean` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 99.9%

![Basics/Input/StoringInput](https://i.gyazo.com/79bd99701dcd7751eb24ca0f10c29279.png)

![Basics/Input/StoringInput の動き](https://i.gyazo.com/fe3e7d64123e2105b904df1488ccd5f7.webp)

## Basics/Lights

### `Directional`

台帳は `clean` ・ その場 **83.6%** ・ 半画素 83.7% ・ 形 99.4% ・ 完全 83.3%

![Basics/Lights/Directional](https://i.gyazo.com/e8f2719331fdf89f066b362749c46c6a.png)

![Basics/Lights/Directional の動き](https://i.gyazo.com/f1ca74bae7a939405841e501d96411e6.webp)

### `Mixture`

台帳は `clean` ・ その場 **83.2%** ・ 半画素 83.2% ・ 形 99.2% ・ 完全 83.2%

![Basics/Lights/Mixture](https://i.gyazo.com/688af6dbde49d23fa09d730f0ad0deb5.png)

![Basics/Lights/Mixture の動き](https://i.gyazo.com/cb32c5d30ff36e4cd49351b5b461c595.webp)

### `MixtureGrid`

台帳は `clean` ・ その場 **20.0%** ・ 半画素 20.1% ・ 形 100.0% ・ 完全 0.9%

![Basics/Lights/MixtureGrid](https://i.gyazo.com/2e735070e91c012443448d8cd9cb4a30.png)

![Basics/Lights/MixtureGrid の動き](https://i.gyazo.com/0f008eef29d07fb269aaa79faa161674.webp)

### `OnOff`

台帳は `clean` ・ その場 **88.8%** ・ 半画素 88.8% ・ 形 99.0% ・ 完全 84.0%

![Basics/Lights/OnOff](https://i.gyazo.com/66e5997a798f07acbe9ee795d6350311.png)

![Basics/Lights/OnOff の動き](https://i.gyazo.com/d5beee7f583bcd39d81b306232fe5ed2.webp)

### `Reflection`

台帳は `bend` ・ その場 **77.8%** ・ 半画素 77.8% ・ 形 99.5% ・ 完全 77.4%

![Basics/Lights/Reflection](https://i.gyazo.com/a474267e10947c391866210a73d7d17e.png)

### `Spot`

台帳は `clean` ・ **測らない** — 原典が 2 つある — p5 は WEBGL の中心原点へ光を移してあり、`mouseY - 90` は面の中心と 90 画素ずれる

![Basics/Lights/Spot](https://i.gyazo.com/00c17f8317a931346ecbf8da512b6fc8.png)

![Basics/Lights/Spot の動き](https://i.gyazo.com/b8dd79d5979119d618c64d491d07932a.webp)

## Basics/Math

### `AdditiveWave`

台帳は `bend` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Basics/Math/AdditiveWave](https://i.gyazo.com/ff8a0d73d155e6fd4ac493dafa8696db.png)

![Basics/Math/AdditiveWave の動き](https://i.gyazo.com/abc38523414d3acc22515a85db53a51d.webp)

### `Arctangent`

台帳は `clean` ・ その場 **93.6%** ・ 半画素 93.8% ・ 形 100.0% ・ 完全 93.5%

![Basics/Math/Arctangent](https://i.gyazo.com/38e1104c14914510983bc11ee3a384ba.png)

![Basics/Math/Arctangent の動き](https://i.gyazo.com/3e0e1db6e907016bdd109f200374c012.webp)

### `Distance1D`

台帳は `clean` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 100.0%

![Basics/Math/Distance1D](https://i.gyazo.com/14ef6768271f5abecd394d473a0eae77.png)

![Basics/Math/Distance1D の動き](https://i.gyazo.com/a9c50e38edc9dd2fd14c37b80c52a4a9.webp)

### `Distance2D`

台帳は `write-only` ・ その場 **96.9%** ・ 半画素 97.2% ・ 形 100.0% ・ 完全 96.7%

![Basics/Math/Distance2D](https://i.gyazo.com/2a4b67e3575440a0a7ee97bd9f883327.png)

![Basics/Math/Distance2D の動き](https://i.gyazo.com/cf4575205f332a859c19e9704d7ad145.webp)

### `DoubleRandom`

台帳は `bend` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Basics/Math/DoubleRandom](https://i.gyazo.com/05693d7ad187bf9370ea442b8cd774c4.png)

![Basics/Math/DoubleRandom の動き](https://i.gyazo.com/7829ba101653b2c1d3f7e88818b4cb44.webp)

### `Graphing2DEquation`

台帳は `blocked` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 98.9%

![Basics/Math/Graphing2DEquation](https://i.gyazo.com/366cdaf35d265e4121828c0221c92266.png)

![Basics/Math/Graphing2DEquation の動き](https://i.gyazo.com/5476fc1d4cec455df69c85f85404b4cf.webp)

### `IncrementDecrement`

台帳は `bend` ・ その場 **99.7%** ・ 半画素 99.9% ・ 形 100.0% ・ 完全 99.7%

![Basics/Math/IncrementDecrement](https://i.gyazo.com/323c71f6ae11d0a561c68b4035f55fd4.png)

![Basics/Math/IncrementDecrement の動き](https://i.gyazo.com/faec52cc2908df18c364b77f5d462a6f.webp)

### `Interpolate`

台帳は `write-only` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 100.0%

![Basics/Math/Interpolate](https://i.gyazo.com/86cf9b4ff23f0a930c0750f3212ce5c8.png)

![Basics/Math/Interpolate の動き](https://i.gyazo.com/b5300e82351147ad523e6662bc946e45.webp)

### `Map`

台帳は `clean` ・ その場 **99.9%** ・ 半画素 99.9% ・ 形 100.0% ・ 完全 99.9% ・ 円の輪郭のアンチエイリアス

![Basics/Math/Map](https://i.gyazo.com/46af99de5c9d9aa743e8e51aed426371.png)

![Basics/Math/Map の動き](https://i.gyazo.com/d51b466cf963c2e887b7d65dc4671ee4.webp)

### `Noise1D`

台帳は `clean` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Basics/Math/Noise1D](https://i.gyazo.com/001e39b755af289b329f249427abd4ff.png)

![Basics/Math/Noise1D の動き](https://i.gyazo.com/01af599481238dda8b136ba748a1b0bb.webp)

### `Noise2D`

台帳は `blocked` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Basics/Math/Noise2D](https://i.gyazo.com/f76233447798cf3da30763dc302f6aa0.png)

![Basics/Math/Noise2D の動き](https://i.gyazo.com/8fc7a3fecd1ea8f180ac01cd71a544c2.webp)

### `Noise3D`

台帳は `blocked` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Basics/Math/Noise3D](https://i.gyazo.com/e25d466da9ada351af61b8ec35b7dcee.png)

![Basics/Math/Noise3D の動き](https://i.gyazo.com/cea8d23ed142cb040c2fae9ec7c3691b.webp)

### `NoiseWave`

台帳は `clean` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Basics/Math/NoiseWave](https://i.gyazo.com/2ac0f1978cfa9416ffff50e952c7ec95.png)

![Basics/Math/NoiseWave の動き](https://i.gyazo.com/18e790e486c8b0785a1eb7994ba265fa.webp)

### `OperatorPrecedence`

台帳は `clean` ・ その場 **43.6%** ・ 半画素 99.5% ・ 形 52.0% ・ 完全 43.6% ・ 同上。線でできた例はここが効く

![Basics/Math/OperatorPrecedence](https://i.gyazo.com/41fd34f96bf659d4d6ec529ca4d72f2f.png)

### `PolarToCartesian`

台帳は `clean` ・ その場 **99.9%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 99.9%

![Basics/Math/PolarToCartesian](https://i.gyazo.com/a117940aad84eecddc4c8ac6da03bbfa.png)

![Basics/Math/PolarToCartesian の動き](https://i.gyazo.com/0fcf5bad995af32e9850c55b483992b7.webp)

### `Random`

台帳は `bend` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Basics/Math/Random](https://i.gyazo.com/237f1f3a0cc9d65122dec8989d7a5f48.png)

![Basics/Math/Random の動き](https://i.gyazo.com/1efb04926cefefd8e26aa931bfab97b8.webp)

### `RandomGaussian`

台帳は `write-only` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Basics/Math/RandomGaussian](https://i.gyazo.com/befb5b6046cbac68e504db34a4ef3944.png)

![Basics/Math/RandomGaussian の動き](https://i.gyazo.com/29376036d49795efb517aa15c5002bbe.webp)

### `Sine`

台帳は `clean` ・ その場 **99.1%** ・ 半画素 99.1% ・ 形 100.0% ・ 完全 43.7%

![Basics/Math/Sine](https://i.gyazo.com/27b2d3cde14f749ccacbb86549d7b9b0.png)

![Basics/Math/Sine の動き](https://i.gyazo.com/4ea1c92e0bc128a5573c28fe37f49f59.webp)

### `SineCosine`

台帳は `clean` ・ その場 **99.5%** ・ 半画素 99.6% ・ 形 100.0% ・ 完全 93.1%

![Basics/Math/SineCosine](https://i.gyazo.com/db4880069987c3346ebcc519878d8fd1.png)

![Basics/Math/SineCosine の動き](https://i.gyazo.com/d5c675dbb09f10d89c3bea0d6fd2d1d8.webp)

### `SineWave`

台帳は `clean` ・ その場 **98.9%** ・ 半画素 99.0% ・ 形 100.0% ・ 完全 98.9%

![Basics/Math/SineWave](https://i.gyazo.com/55dccb035e190126399d71af2c236e06.png)

![Basics/Math/SineWave の動き](https://i.gyazo.com/82a3fa68c693a52d969a58aca5e6472c.webp)

## Basics/Objects

### `CompositeObjects`

台帳は `clean` ・ **測らない** — 原典が 2 つある — 揺れの速さが `2` / `10` 対 `0.1` / `0.05` で桁ごと違う

![Basics/Objects/CompositeObjects](https://i.gyazo.com/4373899f633cdd6a44acb020f212e0ea.png)

![Basics/Objects/CompositeObjects の動き](https://i.gyazo.com/25e5b4786d1432ec7876472595f852ec.webp)

### `Inheritance`

台帳は `clean` ・ その場 **99.7%** ・ 半画素 99.9% ・ 形 100.0% ・ 完全 99.6%

![Basics/Objects/Inheritance](https://i.gyazo.com/5dd2f0583f6b8379952ddb04d7455c37.png)

![Basics/Objects/Inheritance の動き](https://i.gyazo.com/dafdd93cca177400fe64f34082a5c74e.webp)

### `MultipleConstructors`

台帳は `blocked` ・ その場 **99.2%** ・ 半画素 99.2% ・ 形 99.9% ・ 完全 99.1%

![Basics/Objects/MultipleConstructors](https://i.gyazo.com/8ed28415aa022054188801b046a60045.png)

![Basics/Objects/MultipleConstructors の動き](https://i.gyazo.com/09b797766596806e41af906260e1b0f1.webp)

### `Objects`

台帳は `clean` ・ その場 **90.7%** ・ 半画素 90.7% ・ 形 100.0% ・ 完全 90.2%

![Basics/Objects/Objects](https://i.gyazo.com/c67753b29747fdab9d35d47203506291.png)

![Basics/Objects/Objects の動き](https://i.gyazo.com/39d0f89191f48dfe4ebcbd53b5768cea.webp)

## Basics/Shape

### `LoadDisplayOBJ`

台帳は `blocked` ・ その場 **90.8%** ・ 半画素 90.8% ・ 形 98.7% ・ 完全 90.8%

![Basics/Shape/LoadDisplayOBJ](https://i.gyazo.com/a9ea8c8aa5cdaa56d79aaa93407881ca.png)

![Basics/Shape/LoadDisplayOBJ の動き](https://i.gyazo.com/8d92e4aca2c13b0bfaf64e3febb27745.webp)

## Basics/Structure

### `Coordinates`

台帳は `clean` ・ **測らない** — 原典が 2 つある — 横線が `120` 対 `height * 0.33` (118.8) で 1.2 画素ずれる

![Basics/Structure/Coordinates](https://i.gyazo.com/c763a7f722e6c0a78bb5784ab45f0679.png)

### `CreateGraphics`

台帳は `clean` ・ その場 **99.1%** ・ 半画素 99.1% ・ 形 99.6% ・ 完全 99.1%

![Basics/Structure/CreateGraphics](https://i.gyazo.com/5e0bdf00b2d811958c42aca2bd25b9ec.png)

![Basics/Structure/CreateGraphics の動き](https://i.gyazo.com/f0c8b3de5f30c75b1039cfcc59be0f9f.webp)

### `Functions`

台帳は `blocked` ・ その場 **97.5%** ・ 半画素 99.5% ・ 形 99.9% ・ 完全 66.0%

![Basics/Structure/Functions](https://i.gyazo.com/a87790221bb574b3986dc9a00738967e.png)

![Basics/Structure/Functions の動き](https://i.gyazo.com/f7c20d5e8695ce3dfdfe30c37fa838b8.webp)

### `Loop`

台帳は `blocked` ・ その場 **99.4%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 99.4%

![Basics/Structure/Loop](https://i.gyazo.com/ad85028b34242961979c6f7e61f7e03e.png)

![Basics/Structure/Loop の動き](https://i.gyazo.com/6be09b3760dcd39da3de39da13f76801.webp)

### `NoLoop`

台帳は `blocked` ・ その場 **99.2%** ・ 半画素 99.4% ・ 形 99.7% ・ 完全 99.2% ・ 1px の線の置き方 (p5 は 2 行に 128、mokume は 1 行に 255)

![Basics/Structure/NoLoop](https://i.gyazo.com/a57a486bad51f567042a317a4f0adcdf.png)

![Basics/Structure/NoLoop の動き](https://i.gyazo.com/7b84f49b91b59bbf992c6ff58edae0b2.webp)

### `Recursion`

台帳は `blocked` ・ その場 **96.5%** ・ 半画素 98.4% ・ 形 99.9% ・ 完全 60.7%

![Basics/Structure/Recursion](https://i.gyazo.com/707e0ec52aa86b4d2c7decd1085becce.png)

![Basics/Structure/Recursion の動き](https://i.gyazo.com/b1b606f4f0ca2dcd5f55b9a8c411682a.webp)

### `Redraw`

台帳は `blocked` ・ その場 **99.4%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 99.4%

![Basics/Structure/Redraw](https://i.gyazo.com/212b1bb0fdf3b9a2718208e6ddcd26ee.png)

![Basics/Structure/Redraw の動き](https://i.gyazo.com/94db59fbc9a6b3ff34350a4ae497432b.webp)

### `SetupDraw`

台帳は `clean` ・ **測らない** — 原典が 2 つある — 線の初期位置が `180` 対 `100` で 80 画素ずれる。絵が細いので一致率は 99% のまま嘘をつく

![Basics/Structure/SetupDraw](https://i.gyazo.com/f7b74fd3fb314791cf967975fe4f9c8e.png)

![Basics/Structure/SetupDraw の動き](https://i.gyazo.com/670a056f2539382d2bcef125d67c10d0.webp)

### `StatementsComments`

台帳は `clean` ・ その場 **0.0%** ・ 半画素 0.0% ・ 形 100.0% ・ 完全 0.0% ・ どちらも背景だけ ・ 面ぜんぶが 9 ずれる。書き出しが Display P3 で刻まれるため

![Basics/Structure/StatementsComments](https://i.gyazo.com/eccfb4d17f8f621dffdc23708a3865f0.png)

### `WidthHeight`

台帳は `clean` ・ その場 **57.4%** ・ 半画素 57.4% ・ 形 100.0% ・ 完全 57.4% ・ 色の帯が 28 ずれる (129,206,15 → 101,208,0)。灰色と白は一致

![Basics/Structure/WidthHeight](https://i.gyazo.com/7653a6633dab7b25179100ea855c0015.png)

## Basics/Transform

### `Arm`

台帳は `clean` ・ その場 **97.1%** ・ 半画素 97.1% ・ 形 100.0% ・ 完全 97.0%

![Basics/Transform/Arm](https://i.gyazo.com/4d7437bed669cdc8d38a4f5e8a3d1d22.png)

![Basics/Transform/Arm の動き](https://i.gyazo.com/bf3d89076926e859b7bad181294312a6.webp)

### `Rotate`

台帳は `blocked` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Basics/Transform/Rotate](https://i.gyazo.com/a734b6db96ccc3e50fbaf2dadc55b1e8.png)

![Basics/Transform/Rotate の動き](https://i.gyazo.com/7c8bb0b8d634b48a48548d98dbc69450.webp)

### `RotatePushPop`

台帳は `clean` ・ その場 **57.3%** ・ 半画素 57.5% ・ 形 93.2% ・ 完全 0.3%

![Basics/Transform/RotatePushPop](https://i.gyazo.com/a46b0925b21d63fc86d6fd6a21e6a495.png)

![Basics/Transform/RotatePushPop の動き](https://i.gyazo.com/a03bb6ae23bff8d9449ee1bc7593c97f.webp)

### `RotateXY`

台帳は `clean` ・ その場 **89.8%** ・ 半画素 89.8% ・ 形 99.8% ・ 完全 89.8%

![Basics/Transform/RotateXY](https://i.gyazo.com/808a5fa6ea2937fb7752c4c8cb7c198f.png)

![Basics/Transform/RotateXY の動き](https://i.gyazo.com/cbfaad7c5dd35207d6051090e342709b.webp)

### `Scale`

台帳は `bend` ・ その場 **99.7%** ・ 半画素 99.7% ・ 形 100.0% ・ 完全 99.5%

![Basics/Transform/Scale](https://i.gyazo.com/fbe0f75dfde7f5f824e12368908b4bef.png)

![Basics/Transform/Scale の動き](https://i.gyazo.com/2d6bcf0425ceb0ae3e8eedd10f3e90f1.webp)

### `Translate`

台帳は `clean` ・ その場 **99.9%** ・ 半画素 99.9% ・ 形 100.0% ・ 完全 99.9%

![Basics/Transform/Translate](https://i.gyazo.com/342586fd2f7122c57acaab8bcc786043.png)

![Basics/Transform/Translate の動き](https://i.gyazo.com/023185a551269db49d03978cf78f5739.webp)

## Basics/Typography

### `Letters`

台帳は `blocked` ・ **測らない** — 字を組む。原典はブラウザの、mokume は macOS の書体で字形が違う

![Basics/Typography/Letters](https://i.gyazo.com/1a102d7b9fc626849d2d9608f1a0f983.png)

### `TextRotation`

台帳は `blocked` ・ **測らない** — 字を組む。原典はブラウザの、mokume は macOS の書体で字形が違う

![Basics/Typography/TextRotation](https://i.gyazo.com/48a8fd4a5a3445e08d044ae59a95b6df.png)

![Basics/Typography/TextRotation の動き](https://i.gyazo.com/ad20eeca427c0d216de501d2e1751d24.webp)

### `Words`

台帳は `blocked` ・ **測らない** — 字を組む。原典はブラウザの、mokume は macOS の書体で字形が違う

![Basics/Typography/Words](https://i.gyazo.com/48a7b14a39cb416df3124c7eb46d4612.png)

## Basics/Web

### `EmbeddedLinks`

台帳は `out-of-scope` ・ その場 **99.4%** ・ 半画素 99.4% ・ 形 99.7% ・ 完全 99.4%

![Basics/Web/EmbeddedLinks](https://i.gyazo.com/36db0eb5bb435ac952f4c9ff585cf49f.png)

![Basics/Web/EmbeddedLinks の動き](https://i.gyazo.com/c9394f2fbc11cff69431889b6733c6b1.webp)

### `LoadingImages`

台帳は `out-of-scope` ・ その場 **0.0%** ・ 半画素 0.0% ・ 形 100.0% ・ 完全 0.0% ・ どちらも背景だけ

![Basics/Web/LoadingImages](https://i.gyazo.com/fa13d8f11d475987e1071125767f6f7d.png)

## Topics/Advanced Data

### `ArrayListClass`

台帳は `out-of-scope` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 100.0%

![Topics/Advanced Data/ArrayListClass](https://i.gyazo.com/82211eb9fd188c4a4e6c5a46f9d6ebe4.png)

![Topics/Advanced Data/ArrayListClass の動き](https://i.gyazo.com/dac1fcfe99c56ad22553952242dc036a.webp)

### `IntListLottery`

台帳は `out-of-scope` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Topics/Advanced Data/IntListLottery](https://i.gyazo.com/913df41731d63cd919151c28ad86bf36.png)

![Topics/Advanced Data/IntListLottery の動き](https://i.gyazo.com/af70409cb35f83841838d002179e37d0.webp)

### `LoadSaveJSON`

台帳は `out-of-scope` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Topics/Advanced Data/LoadSaveJSON](https://i.gyazo.com/0dafb7785377019867395c42ab635f5b.png)

![Topics/Advanced Data/LoadSaveJSON の動き](https://i.gyazo.com/c55287c16743912fcb96ec08187a877a.webp)

### `LoadSaveTable`

台帳は `out-of-scope` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Topics/Advanced Data/LoadSaveTable](https://i.gyazo.com/0bb424f2b6527046cb828e156dd1c745.png)

![Topics/Advanced Data/LoadSaveTable の動き](https://i.gyazo.com/870c4447c5847c0c2d27735828d7b007.webp)

## Topics/Animation

### `AnimatedSprite`

台帳は `bend` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 0.0% ・ どちらも背景だけ

![Topics/Animation/AnimatedSprite](https://i.gyazo.com/f6ec919da3ab2ce0783c27e9894cf226.png)

![Topics/Animation/AnimatedSprite の動き](https://i.gyazo.com/0c918d85e4489a68349424fa9703bc36.webp)

### `Sequential`

台帳は `bend` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 100.0%

![Topics/Animation/Sequential](https://i.gyazo.com/02a16c251c6db6872f5e90d4b946ce4a.png)

![Topics/Animation/Sequential の動き](https://i.gyazo.com/cb94d88b0dd1e2d6786ea6eda693ae41.webp)

## Topics/Cellular Automata

### `GameOfLife`

台帳は `blocked` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Topics/Cellular Automata/GameOfLife](https://i.gyazo.com/c3d62397b5dbe930d0bd1d5e69ca6a76.png)

![Topics/Cellular Automata/GameOfLife の動き](https://i.gyazo.com/6a92f39a58a20cdd22979e6dc8d83a9a.webp)

### `Wolfram`

台帳は `clean` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Topics/Cellular Automata/Wolfram](https://i.gyazo.com/f91db95541ab09c0ddca0ba97a6a8f49.png)

![Topics/Cellular Automata/Wolfram の動き](https://i.gyazo.com/64db9da838bb44ecec0b205dcd36cc81.webp)

## Topics/Drawing

### `ContinuousLines`

台帳は `clean` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 100.0% ・ どちらも背景だけ ・ 1 画素も違わない

![Topics/Drawing/ContinuousLines](https://i.gyazo.com/43f8b666348bc84787692376db7652b5.png)

![Topics/Drawing/ContinuousLines の動き](https://i.gyazo.com/ee46509245436a200e19c898016d02f5.webp)

### `Pattern`

台帳は `clean` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 100.0% ・ **mokume は 1 画素も描いていない**

![Topics/Drawing/Pattern](https://i.gyazo.com/903d35f36caa401dfe919eef82e29909.png)

![Topics/Drawing/Pattern の動き](https://i.gyazo.com/2b43f6f10873a1fc4fceaf7ce5512827.webp)

### `Pulses`

台帳は `clean` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 100.0% ・ どちらも背景だけ

![Topics/Drawing/Pulses](https://i.gyazo.com/bcf59205cb8e6f02540df586050a1f02.png)

![Topics/Drawing/Pulses の動き](https://i.gyazo.com/da60491a37115b0bf7ce4bca9221fab3.webp)

## Topics/File IO

### `LoadFile1`

台帳は `out-of-scope` ・ **測らない** — 原典が 2 つある — p5 は座標を整数へ丸めてから掛ける (`int(x) * 6.4`)。原典は `map()` で小数のまま

![Topics/File IO/LoadFile1](https://i.gyazo.com/b64f1bfe98d4488360dc793cb3e2a6e0.png)

![Topics/File IO/LoadFile1 の動き](https://i.gyazo.com/a0d2694b20c981ecd93a9931fed9bdfe.webp)

### `LoadFile2`

台帳は `out-of-scope` ・ **測らない** — 字を組む。原典はブラウザの、mokume は macOS の書体で字形が違う

![Topics/File IO/LoadFile2](https://i.gyazo.com/6f8a2067c014832fcb1be9dbe3f3f65b.png)

![Topics/File IO/LoadFile2 の動き](https://i.gyazo.com/d890ae7224785309f2ca87b6e7fbd9fc.webp)

### `SaveOneImage`

台帳は `out-of-scope` ・ その場 **99.6%** ・ 半画素 99.6% ・ 形 100.0% ・ 完全 99.6%

![Topics/File IO/SaveOneImage](https://i.gyazo.com/d86fcf06a8f2a13480c810b83f19b7ae.png)

![Topics/File IO/SaveOneImage の動き](https://i.gyazo.com/7102f5137e74dcc944d69a0e56eec51c.webp)

## Topics/Fractals and L-Systems

### `Koch`

台帳は `bend` ・ その場 **99.4%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 99.4%

![Topics/Fractals and L-Systems/Koch](https://i.gyazo.com/b80b55036feede07fa1333649ba38654.png)

![Topics/Fractals and L-Systems/Koch の動き](https://i.gyazo.com/f5566873264a3f96f66e39be95bd51c3.webp)

### `Mandelbrot`

台帳は `blocked` ・ その場 **30.4%** ・ 半画素 30.9% ・ 形 92.4% ・ 完全 11.5%

![Topics/Fractals and L-Systems/Mandelbrot](https://i.gyazo.com/bf614eaa4ca2dfe7e106b775cc87f786.png)

### `PenroseSnowflake`

台帳は `clean` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 100.0% ・ **mokume は 1 画素も描いていない**

![Topics/Fractals and L-Systems/PenroseSnowflake](https://i.gyazo.com/d59e4696f64c858273312f28f41e98d8.png)

![Topics/Fractals and L-Systems/PenroseSnowflake の動き](https://i.gyazo.com/5091a762cb50ef454adbff0dcae65acc.webp)

### `PenroseTile`

台帳は `clean` ・ その場 **99.9%** ・ 半画素 99.9% ・ 形 100.0% ・ 完全 99.9%

![Topics/Fractals and L-Systems/PenroseTile](https://i.gyazo.com/87acfb675afffc406cdeb4b1d7fe211c.png)

![Topics/Fractals and L-Systems/PenroseTile の動き](https://i.gyazo.com/1333de6111ed30e10e5341772b111011.webp)

### `Pentigree`

台帳は `clean` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 100.0%

![Topics/Fractals and L-Systems/Pentigree](https://i.gyazo.com/c5750606585593e5ace507d4e3eb49f6.png)

![Topics/Fractals and L-Systems/Pentigree の動き](https://i.gyazo.com/766fd15830ab32a92c7d66aa02b48124.webp)

### `Tree`

台帳は `bend` ・ その場 **99.7%** ・ 半画素 99.8% ・ 形 100.0% ・ 完全 99.7%

![Topics/Fractals and L-Systems/Tree](https://i.gyazo.com/86b8ee6cae1ad2661334df34f4eb2d11.png)

![Topics/Fractals and L-Systems/Tree の動き](https://i.gyazo.com/a3d3563375406a025e08bf423900e852.webp)

## Topics/GUI

### `Button`

台帳は `write-only` ・ その場 **99.4%** ・ 半画素 99.8% ・ 形 100.0% ・ 完全 99.4%

![Topics/GUI/Button](https://i.gyazo.com/aea607aa66103e48897de6fa9382a27a.png)

![Topics/GUI/Button の動き](https://i.gyazo.com/f09e97773708b46a4229e489ddb26efd.webp)

### `Handles`

台帳は `clean` ・ その場 **98.1%** ・ 半画素 99.9% ・ 形 100.0% ・ 完全 98.1%

![Topics/GUI/Handles](https://i.gyazo.com/c0947a26f468cb6e86436a274c2713e0.png)

![Topics/GUI/Handles の動き](https://i.gyazo.com/93117ff1c07040b3fbec67229b1fb4ab.webp)

### `Rollover`

台帳は `write-only` ・ その場 **99.4%** ・ 半画素 99.8% ・ 形 100.0% ・ 完全 99.4%

![Topics/GUI/Rollover](https://i.gyazo.com/9535984ffdc2f1b891bb20853dd6bc8d.png)

![Topics/GUI/Rollover の動き](https://i.gyazo.com/9eb03167ae9a5a612c1144a9534c6243.webp)

### `Scrollbar`

台帳は `clean` ・ その場 **99.4%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 84.7%

![Topics/GUI/Scrollbar](https://i.gyazo.com/aa7d94f306179cfab96b489d46f9878e.png)

![Topics/GUI/Scrollbar の動き](https://i.gyazo.com/e904ec3a3365cabf243b3a8a680b51cd.webp)

## Topics/Image Processing

### `Blur`

台帳は `blocked` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 92.6%

![Topics/Image Processing/Blur](https://i.gyazo.com/1c13e1735ce9825f285ad205a32e53f9.png)

### `BrightnessPixels`

台帳は `blocked` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 99.1%

![Topics/Image Processing/BrightnessPixels](https://i.gyazo.com/21a276134624cd666e8e75e7f2b54a8e.png)

![Topics/Image Processing/BrightnessPixels の動き](https://i.gyazo.com/f9754bd7df869d5f9b9abe23ba34d13a.webp)

### `Convolution`

台帳は `blocked` ・ **測らない** — 字を組む。原典はブラウザの、mokume は macOS の書体で字形が違う

![Topics/Image Processing/Convolution](https://i.gyazo.com/459184944f159dab06fd90ac322276bf.png)

![Topics/Image Processing/Convolution の動き](https://i.gyazo.com/2bc975a9bd4ffa40da30bc3274561a17.webp)

### `EdgeDetection`

台帳は `blocked` ・ **測らない** — 原典が 2 つある — 畳み込みの核が違う (中央 `8` + 下駄 `128` の縁取り出し 対 中央 `9` の縁強調)

![Topics/Image Processing/EdgeDetection](https://i.gyazo.com/3864cfd593be36ca4c716454324d1038.png)

### `Histogram`

台帳は `clean` ・ その場 **79.1%** ・ 半画素 90.6% ・ 形 97.0% ・ 完全 55.5%

![Topics/Image Processing/Histogram](https://i.gyazo.com/91e30441fa7b1e565536a073f42ff2bd.png)

### `PixelArray`

台帳は `bend` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 0.0% ・ どちらも背景だけ

![Topics/Image Processing/PixelArray](https://i.gyazo.com/2241ee6085ae736a5def51134b89c7ec.png)

![Topics/Image Processing/PixelArray の動き](https://i.gyazo.com/8db3c16565d80082410e8eb8b2127bc2.webp)

## Topics/Interaction

### `Follow1`

台帳は `clean` ・ その場 **99.3%** ・ 半画素 99.3% ・ 形 100.0% ・ 完全 99.3%

![Topics/Interaction/Follow1](https://i.gyazo.com/8c3f7c611915c756030c12639d8efa3f.png)

![Topics/Interaction/Follow1 の動き](https://i.gyazo.com/c56d9ab4b4d846ce8578098a4abb69ed.webp)

### `Follow2`

台帳は `clean` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 100.0%

![Topics/Interaction/Follow2](https://i.gyazo.com/acfcdf33b327e8d3ff7a59ad541cc741.png)

![Topics/Interaction/Follow2 の動き](https://i.gyazo.com/1c23ac842335a0f6f6e08fba59e3834a.webp)

### `Follow3`

台帳は `clean` ・ その場 **99.9%** ・ 半画素 99.9% ・ 形 100.0% ・ 完全 99.9%

![Topics/Interaction/Follow3](https://i.gyazo.com/aebaa72b37f93ea04a3806a97fc65525.png)

![Topics/Interaction/Follow3 の動き](https://i.gyazo.com/46a81ccca54dad65b51cbe9b11742f65.webp)

### `Reach1`

台帳は `clean` ・ その場 **98.4%** ・ 半画素 98.4% ・ 形 100.0% ・ 完全 98.4%

![Topics/Interaction/Reach1](https://i.gyazo.com/0086570b205d8817e652daee5e541ff9.png)

![Topics/Interaction/Reach1 の動き](https://i.gyazo.com/97e92f22fd6b49e46d6678bf4105c3b1.webp)

### `Reach2`

台帳は `clean` ・ その場 **99.1%** ・ 半画素 99.1% ・ 形 99.7% ・ 完全 99.1%

![Topics/Interaction/Reach2](https://i.gyazo.com/e20f496da887cf5c756e2c6ca2a67a84.png)

![Topics/Interaction/Reach2 の動き](https://i.gyazo.com/e5131a14ed84f440fcaf8eb049f7eea6.webp)

### `Reach3`

台帳は `clean` ・ その場 **99.0%** ・ 半画素 99.0% ・ 形 100.0% ・ 完全 98.9%

![Topics/Interaction/Reach3](https://i.gyazo.com/e891324b16e79a4bfcf2a20f15814cac.png)

![Topics/Interaction/Reach3 の動き](https://i.gyazo.com/09427affd964bf41644a2498935d0c16.webp)

### `Tickle`

台帳は `blocked` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Topics/Interaction/Tickle](https://i.gyazo.com/90ac909037b677c599a64d58de6e33ef.png)

![Topics/Interaction/Tickle の動き](https://i.gyazo.com/0fa7371415aed79afd22522ca91c4e3a.webp)

## Topics/Motion

### `Bounce`

台帳は `bend` ・ その場 **99.8%** ・ 半画素 99.9% ・ 形 100.0% ・ 完全 99.8%

![Topics/Motion/Bounce](https://i.gyazo.com/89c171b281b9f6490202e0ca5c8a8724.png)

![Topics/Motion/Bounce の動き](https://i.gyazo.com/15411cf3c0e916ce9f24f0ab7d7a5f1d.webp)

### `BouncyBubbles`

台帳は `clean` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Topics/Motion/BouncyBubbles](https://i.gyazo.com/6778d3951b97ea0488fcc4d68f19922f.png)

![Topics/Motion/BouncyBubbles の動き](https://i.gyazo.com/c950ff3767520cc5380041d2d85fdf56.webp)

### `Brownian`

台帳は `bend` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Topics/Motion/Brownian](https://i.gyazo.com/5802c5739930cb186adc573389d380b4.png)

![Topics/Motion/Brownian の動き](https://i.gyazo.com/915ef7f339c8d9f47fe15f07c4d85ade.webp)

### `CircleCollision`

台帳は `bend` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 100.0%

![Topics/Motion/CircleCollision](https://i.gyazo.com/60b331fa05017504957c103945df9a47.png)

![Topics/Motion/CircleCollision の動き](https://i.gyazo.com/ada18987d57a24132fb1044053eb8838.webp)

### `Linear`

台帳は `clean` ・ その場 **99.4%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 99.4%

![Topics/Motion/Linear](https://i.gyazo.com/4dc7af28ac9e912128fab20a1f0e80dc.png)

![Topics/Motion/Linear の動き](https://i.gyazo.com/843df4e968ef659d7a87a74efad19b11.webp)

### `Morph`

台帳は `bend` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 100.0%

![Topics/Motion/Morph](https://i.gyazo.com/ed945b6ab28870bbe98767f84e158183.png)

![Topics/Motion/Morph の動き](https://i.gyazo.com/03dfea02b881128b19c75a7aa27fbd56.webp)

### `MovingOnCurves`

台帳は `clean` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 100.0%

![Topics/Motion/MovingOnCurves](https://i.gyazo.com/b1b0d88f7adc817b1a65a24dd909e9ba.png)

![Topics/Motion/MovingOnCurves の動き](https://i.gyazo.com/87f0fdbec721e9d5c0e300ba2e404968.webp)

### `Reflection1`

台帳は `bend` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Topics/Motion/Reflection1](https://i.gyazo.com/6111121e81acd8f897391d84c3624e2a.png)

![Topics/Motion/Reflection1 の動き](https://i.gyazo.com/28c4be9b83d5dee78ff402e7a990d6d7.webp)

### `Reflection2`

台帳は `bend` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Topics/Motion/Reflection2](https://i.gyazo.com/16d5ad75ca64c0bf01c0b87f0fb08cf4.png)

![Topics/Motion/Reflection2 の動き](https://i.gyazo.com/a0127d88fa63e05545d811e166257c5e.webp)

## Topics/Simulate

### `Flocking`

台帳は `bend` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Topics/Simulate/Flocking](https://i.gyazo.com/41c4af41bfbce52b9167d37641363979.png)

![Topics/Simulate/Flocking の動き](https://i.gyazo.com/08a3519abf4a5e4261a92ce8a7dee1d8.webp)

### `ForcesWithVectors`

台帳は `bend` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Topics/Simulate/ForcesWithVectors](https://i.gyazo.com/404b3da7a734b28935f8304625a85cc8.png)

![Topics/Simulate/ForcesWithVectors の動き](https://i.gyazo.com/03bf64eb54391652bbc9fb79976e2649.webp)

### `MultipleParticleSystems`

台帳は `bend` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Topics/Simulate/MultipleParticleSystems](https://i.gyazo.com/31957217dff78e7f38a67dc8747c1b7a.png)

![Topics/Simulate/MultipleParticleSystems の動き](https://i.gyazo.com/a5c326ceedc07131b9c49b1a9ec7e37e.webp)

### `SimpleParticleSystem`

台帳は `bend` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Topics/Simulate/SimpleParticleSystem](https://i.gyazo.com/08b143dce65ae9efe29bb6edc11166a0.png)

![Topics/Simulate/SimpleParticleSystem の動き](https://i.gyazo.com/e6a3ad34e3ae788d40d41fe1b14bc08d.webp)

### `SmokeParticleSystem`

台帳は `bend` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Topics/Simulate/SmokeParticleSystem](https://i.gyazo.com/bde877f65cc0f6d90d45db16dec5e7fd.png)

![Topics/Simulate/SmokeParticleSystem の動き](https://i.gyazo.com/cf825a75a6f91a877e7fb72d98bc1bdd.webp)

## Topics/Vectors

### `AccelerationWithVectors`

台帳は `bend` ・ その場 **99.8%** ・ 半画素 99.9% ・ 形 100.0% ・ 完全 99.8%

![Topics/Vectors/AccelerationWithVectors](https://i.gyazo.com/5c51cdfd686dc946bcde4e9a4060635f.png)

![Topics/Vectors/AccelerationWithVectors の動き](https://i.gyazo.com/a210cfcf001ecf8a14219b5fe47c4022.webp)

### `BouncingBall`

台帳は `bend` ・ その場 **99.8%** ・ 半画素 99.9% ・ 形 100.0% ・ 完全 99.8%

![Topics/Vectors/BouncingBall](https://i.gyazo.com/258602205f8bf8e0bed29d91fb4c79e6.png)

![Topics/Vectors/BouncingBall の動き](https://i.gyazo.com/9b29fa97ac753120aa5e5af6a193e856.webp)

### `VectorMath`

台帳は `bend` ・ その場 **99.9%** ・ 半画素 99.9% ・ 形 100.0% ・ 完全 99.8%

![Topics/Vectors/VectorMath](https://i.gyazo.com/ddf35d02947f15ae9c6d277463a9b8f5.png)

![Topics/Vectors/VectorMath の動き](https://i.gyazo.com/dab7ed12890e12f6f345ae443cb4766d.webp)

