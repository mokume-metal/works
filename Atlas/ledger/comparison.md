# 原典と並べた全数

<!-- scripts/compare/publish.py が書く。手で直さない -->

移した 157 本を、原典と並べて突き合わせたもの。**左が原典・右が mokume。** 原典は processing-website が例ごとに配る `liveSketch.js` (Processing 版と 1 行ずつ対応した p5.js) を走らせたもので、**条件を 3 つ揃えてある** — マウスを動かさない・決めた枚数で止める・等倍。

画素で測れたのが 117 本、原典が静止画しか無くて参考値なのが 1 本、測らないと決めたのが 39 本 (乱数・時計・書体を使う例は、原典と mokume で列が違うので一致率に意味が無い)。

数は 4 つ出す。**どれが「同じ絵」かは決めていない** — 見て決めるのは人である。

| | 何を見るか |
| --- | --- |
| その場 | そのままの位置で、色が差 8 以内 (目で見て同じ色) |
| 半画素 | mokume を半画素動かしてよいとしたとき。**ずらすと合うなら、正体は線の載せ方** |
| 形 | 明るさの縁だけを取り出し、1 画素の幅を許して比べたもの |
| 完全 | 1 画素も違わない |

道具は mokume v0.5.0 / p5.js 1.9.4。

| 群 | 本数 | 測った | その場で一致の中央値 |
| --- | ---: | ---: | ---: |
| [Basics/Arrays](#basicsarrays) | 3 | 1 | 74.1% |
| [Basics/Camera](#basicscamera) | 3 | 2 | 98.0% |
| [Basics/Color](#basicscolor) | 7 | 6 | 100.0% |
| [Basics/Control](#basicscontrol) | 5 | 5 | 86.5% |
| [Basics/Data](#basicsdata) | 6 | 4 | 99.8% |
| [Basics/Form](#basicsform) | 8 | 8 | 98.9% |
| [Basics/Image](#basicsimage) | 7 | 6 | 98.7% |
| [Basics/Input](#basicsinput) | 12 | 9 | 99.9% |
| [Basics/Lights](#basicslights) | 6 | 6 | 83.2% |
| [Basics/Math](#basicsmath) | 20 | 12 | 100.0% |
| [Basics/Objects](#basicsobjects) | 4 | 4 | 99.3% |
| [Basics/Shape](#basicsshape) | 1 | 1 | 90.8% |
| [Basics/Structure](#basicsstructure) | 10 | 10 | 99.2% |
| [Basics/Transform](#basicstransform) | 6 | 5 | 97.1% |
| [Basics/Typography](#basicstypography) | 3 | 0 | — |
| [Basics/Web](#basicsweb) | 2 | 2 | 100.0% |
| [Topics/Advanced Data](#topicsadvanced-data) | 4 | 1 | 100.0% |
| [Topics/Animation](#topicsanimation) | 2 | 2 | 100.0% |
| [Topics/Cellular Automata](#topicscellular-automata) | 2 | 0 | — |
| [Topics/Drawing](#topicsdrawing) | 3 | 3 | 100.0% |
| [Topics/File IO](#topicsfile-io) | 3 | 2 | 100.0% |
| [Topics/Fractals and L-Systems](#topicsfractals-and-l-systems) | 6 | 6 | 100.0% |
| [Topics/GUI](#topicsgui) | 4 | 4 | 99.5% |
| [Topics/Image Processing](#topicsimage-processing) | 6 | 5 | 100.0% |
| [Topics/Interaction](#topicsinteraction) | 7 | 6 | 99.3% |
| [Topics/Motion](#topicsmotion) | 9 | 5 | 100.0% |
| [Topics/Simulate](#topicssimulate) | 5 | 0 | — |
| [Topics/Vectors](#topicsvectors) | 3 | 3 | 99.9% |

## Basics/Arrays

### `Array`

台帳は `blocked` ・ **測らない** — 原典が 2 つある — site の p5 は線を 1 本おきに引く (i += 2)。移植は Processing の .pde に従っている

![Basics/Arrays/Array](https://i.gyazo.com/de1eef549a05299ed0b1a7dfdfb7ec98.png)

### `Array2D`

台帳は `blocked` ・ その場 **74.1%** ・ 半画素 74.1% ・ 形 84.5% ・ 完全 74.0%

![Basics/Arrays/Array2D](https://i.gyazo.com/7a2e54430961d15377980f7e975361ae.png)

### `ArrayObjects`

台帳は `clean` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Basics/Arrays/ArrayObjects](https://i.gyazo.com/07ae696a513c08833e20f22d8c02a436.png)

## Basics/Camera

### `MoveEye`

台帳は `clean` ・ その場 **36.9%** ・ 半画素 36.9% ・ 形 98.5% ・ 完全 36.9%

![Basics/Camera/MoveEye](https://i.gyazo.com/f80f5442ee9764cde56f6aeed5357e8c.png)

### `Orthographic`

台帳は `bend` ・ **測らない** — 面の大きさが違う (原典 640x360 / mokume 600x360)

![Basics/Camera/Orthographic](https://i.gyazo.com/4118c33a6163975a5e55114396d9f977.png)

### `Perspective`

台帳は `clean` ・ その場 **98.0%** ・ 半画素 98.0% ・ 形 99.8% ・ 完全 98.0%

![Basics/Camera/Perspective](https://i.gyazo.com/fee42201d3c9dba48f5b500d32a57552.png)

## Basics/Color

### `Brightness`

台帳は `bend` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 100.0%

![Basics/Color/Brightness](https://i.gyazo.com/392a24f2b31dfc9a294358ce2c8f0246.png)

### `ColorVariables`

台帳は `clean` ・ その場 **65.3%** ・ 半画素 65.3% ・ 形 100.0% ・ 完全 0.0%

![Basics/Color/ColorVariables](https://i.gyazo.com/d7d7f87b58baae3d367d54f5d08ef692.png)

### `Hue`

台帳は `bend` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 100.0%

![Basics/Color/Hue](https://i.gyazo.com/1134d788a2a7959f485d79f986166fb5.png)

### `LinearGradient`

台帳は `blocked` ・ その場 **6.3%** ・ 半画素 6.7% ・ 形 99.7% ・ 完全 0.8%

![Basics/Color/LinearGradient](https://i.gyazo.com/977592bb70b4069e302322630ad36420.png)

### `RadialGradient`

台帳は `bend` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Basics/Color/RadialGradient](https://i.gyazo.com/0b3ccfd716d7c816c08f4ee2dca171eb.png)

### `Relativity`

台帳は `blocked` ・ その場 **39.5%** ・ 半画素 39.5% ・ 形 100.0% ・ 完全 0.0%

![Basics/Color/Relativity](https://i.gyazo.com/6c434c8117436b250f63bd1e137740b7.png)

### `Saturation`

台帳は `bend` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 100.0%

![Basics/Color/Saturation](https://i.gyazo.com/bb30dfa18ff401d2f65db98b1f3f738b.png)

## Basics/Control

### `Conditionals1`

台帳は `clean` ・ その場 **92.8%** ・ 半画素 99.9% ・ 形 100.0% ・ 完全 92.8%

![Basics/Control/Conditionals1](https://i.gyazo.com/99cca3ac8e171ad48a8ba0963882d448.png)

### `Conditionals2`

台帳は `clean` ・ その場 **56.9%** ・ 半画素 99.9% ・ 形 78.3% ・ 完全 56.9% ・ 縦線が半画素ずれる。ずらすと 99.9% 合う

![Basics/Control/Conditionals2](https://i.gyazo.com/981cd557502f05458a2be728afd94150.png)

### `EmbeddedIteration`

台帳は `clean` ・ その場 **86.5%** ・ 半画素 86.5% ・ 形 100.0% ・ 完全 85.3%

![Basics/Control/EmbeddedIteration](https://i.gyazo.com/ef972dca3709132496fdf5f066522d4f.png)

### `Iteration`

台帳は `clean` ・ その場 **98.1%** ・ 半画素 98.1% ・ 形 99.6% ・ 完全 98.1%

![Basics/Control/Iteration](https://i.gyazo.com/a14519e7fc53b5ad258c96be83329e64.png)

### `LogicalOperators`

台帳は `clean` ・ その場 **81.7%** ・ 半画素 99.8% ・ 形 99.9% ・ 完全 81.7%

![Basics/Control/LogicalOperators](https://i.gyazo.com/08ad3d9813fb976e4d6fc2a756adb049.png)

## Basics/Data

### `CharactersStrings`

台帳は `blocked` ・ **測らない** — 字を組む。原典はブラウザの、mokume は macOS の書体で字形が違う

![Basics/Data/CharactersStrings](https://i.gyazo.com/4c6bc5ecff3dae9d2de6f085d12e399f.png)

### `DatatypeConversion`

台帳は `blocked` ・ **測らない** — 字を組む。原典はブラウザの、mokume は macOS の書体で字形が違う

![Basics/Data/DatatypeConversion](https://i.gyazo.com/06b92bc0d0acfd7fdd30537acb75b31a.png)

### `IntegersFloats`

台帳は `clean` ・ その場 **99.8%** ・ 半画素 99.9% ・ 形 100.0% ・ 完全 99.8%

![Basics/Data/IntegersFloats](https://i.gyazo.com/1591ba1b8e8b44eb3868ab504312262c.png)

### `TrueFalse`

台帳は `clean` ・ その場 **91.4%** ・ 半画素 99.9% ・ 形 100.0% ・ 完全 91.4%

![Basics/Data/TrueFalse](https://i.gyazo.com/a4da7787bc9d679fb25f225e548568f6.png)

### `VariableScope`

台帳は `blocked` ・ その場 **86.4%** ・ 半画素 99.8% ・ 形 88.0% ・ 完全 86.4%

![Basics/Data/VariableScope](https://i.gyazo.com/061980b747a0c8799b6d94fe6f5e1093.png)

### `Variables`

台帳は `clean` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 100.0%

![Basics/Data/Variables](https://i.gyazo.com/2305d324287849ab6dc9b8f1f838c510.png)

## Basics/Form

### `Bezier`

台帳は `bend` ・ その場 **96.1%** ・ 半画素 97.2% ・ 形 99.9% ・ 完全 96.1% ・ 曲線の輪郭のアンチエイリアス

![Basics/Form/Bezier](https://i.gyazo.com/6ff2bfe81e2ad2ff547000e2a668fe74.png)

### `PieChart`

台帳は `blocked` ・ その場 **99.4%** ・ 半画素 99.8% ・ 形 100.0% ・ 完全 94.3%

![Basics/Form/PieChart](https://i.gyazo.com/722593716d37b44d8d33a7bb1b29a2be.png)

### `PointsLines`

台帳は `clean` ・ その場 **99.7%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 99.7%

![Basics/Form/PointsLines](https://i.gyazo.com/b7d2953af479cd30a4a882c538636eee.png)

### `Primitives3D`

台帳は `clean` ・ その場 **66.4%** ・ 半画素 66.4% ・ 形 67.3% ・ 完全 66.4%

![Basics/Form/Primitives3D](https://i.gyazo.com/6c232a862640edc0b905a90b9b2c2abf.png)

### `RegularPolygon`

台帳は `clean` ・ その場 **98.9%** ・ 半画素 98.9% ・ 形 99.9% ・ 完全 98.9%

![Basics/Form/RegularPolygon](https://i.gyazo.com/233c8a54f602d4da259f3a306faf9410.png)

### `ShapePrimitives`

台帳は `clean` ・ その場 **99.4%** ・ 半画素 99.6% ・ 形 100.0% ・ 完全 99.4%

![Basics/Form/ShapePrimitives](https://i.gyazo.com/2b09a094394fea7b9b305bed1d6a1ec3.png)

### `Star`

台帳は `clean` ・ その場 **97.6%** ・ 半画素 97.6% ・ 形 99.2% ・ 完全 97.6%

![Basics/Form/Star](https://i.gyazo.com/03f2d13ecfe10a55aaad89638ac65afd.png)

### `TriangleStrip`

台帳は `bend` ・ その場 **98.2%** ・ 半画素 98.2% ・ 形 98.8% ・ 完全 98.2%

![Basics/Form/TriangleStrip](https://i.gyazo.com/72f39cc6388b8b26f19e340a80b74a79.png)

## Basics/Image

### `Alphamask`

台帳は `blocked` ・ その場 **1.3%** ・ 半画素 1.4% ・ 形 83.7% ・ 完全 0.0%

![Basics/Image/Alphamask](https://i.gyazo.com/eb47a8e2e4cf4d2dd2c08247e1003be7.png)

### `BackgroundImage`

台帳は `clean` ・ その場 **99.7%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 55.5%

![Basics/Image/BackgroundImage](https://i.gyazo.com/baf9de9304ea84e8a3ff2d6fc0120f56.png)

### `CreateImage`

台帳は `write-only` ・ その場 **72.6%** ・ 半画素 72.8% ・ 形 100.0% ・ 完全 71.7%

![Basics/Image/CreateImage](https://i.gyazo.com/80e1e1e5fb09e234945c7f1957d8bef2.png)

### `LoadDisplayImage`

台帳は `clean` ・ その場 **98.7%** ・ 半画素 98.8% ・ 形 100.0% ・ 完全 45.7%

![Basics/Image/LoadDisplayImage](https://i.gyazo.com/a71672ca91a65aa6622ecb330cc196da.png)

### `Pointillism`

台帳は `write-only` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Basics/Image/Pointillism](https://i.gyazo.com/1aed65163fa6e58eff9371555aafd24b.png)

### `RequestImage`

台帳は `clean` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 100.0%

![Basics/Image/RequestImage](https://i.gyazo.com/aa52707419405ba259411982fa4dd0c2.png)

### `Transparency`

台帳は `clean` ・ その場 **78.7%** ・ 半画素 81.5% ・ 形 99.7% ・ 完全 13.5%

![Basics/Image/Transparency](https://i.gyazo.com/fca829bf4b99e7631db5817aae6d86bc.png)

## Basics/Input

### `Clock`

台帳は `blocked` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Basics/Input/Clock](https://i.gyazo.com/003aebbae89e797aca9cb4a5e8628678.png)

### `Constrain`

台帳は `write-only` ・ その場 **99.9%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 99.9%

![Basics/Input/Constrain](https://i.gyazo.com/8fa56fc0a73cb3ae488ba3e58cbdf7ef.png)

### `Easing`

台帳は `clean` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 100.0%

![Basics/Input/Easing](https://i.gyazo.com/0b4215e3aced54840d238b28c683b0f2.png)

### `Keyboard`

台帳は `blocked` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Basics/Input/Keyboard](https://i.gyazo.com/3df7fe5b08860222c3cb39ad7d330a21.png)

### `KeyboardFunctions`

台帳は `bend` ・ その場 **0.0%** ・ 半画素 0.0% ・ 形 100.0% ・ 完全 0.0%

![Basics/Input/KeyboardFunctions](https://i.gyazo.com/ed869d94f2d5139a8955be6e55cf41c6.png)

### `Milliseconds`

台帳は `blocked` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Basics/Input/Milliseconds](https://i.gyazo.com/03c158b715acde4d8413767020b334b2.png)

### `Mouse1D`

台帳は `bend` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 100.0%

![Basics/Input/Mouse1D](https://i.gyazo.com/f339ca3d0fc0fd8f99db3b003ab6ea49.png)

### `Mouse2D`

台帳は `clean` ・ その場 **92.1%** ・ 半画素 92.1% ・ 形 100.0% ・ 完全 92.1% ・ 半透明の合成 (線形空間で混ぜるので 214 ではなく 232)

![Basics/Input/Mouse2D](https://i.gyazo.com/b0043f7a48c18cfe0199553b20dd3a8f.png)

### `MouseFunctions`

台帳は `bend` ・ その場 **99.7%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 99.7%

![Basics/Input/MouseFunctions](https://i.gyazo.com/1d5702fca6283ae762bdefd246d3745f.png)

### `MousePress`

台帳は `clean` ・ その場 **99.9%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 99.9%

![Basics/Input/MousePress](https://i.gyazo.com/3affe41ebf6f7d65d635496d6889e857.png)

### `MouseSignals`

台帳は `write-only` ・ その場 **99.1%** ・ 半画素 99.1% ・ 形 100.0% ・ 完全 99.1%

![Basics/Input/MouseSignals](https://i.gyazo.com/2c0cdd521499745b94d1e8f600b2eae2.png)

### `StoringInput`

台帳は `clean` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 99.9%

![Basics/Input/StoringInput](https://i.gyazo.com/da68d98c5a012c178fd0ff06382c4af9.png)

## Basics/Lights

### `Directional`

台帳は `clean` ・ その場 **83.6%** ・ 半画素 83.7% ・ 形 99.4% ・ 完全 83.3%

![Basics/Lights/Directional](https://i.gyazo.com/e8f2719331fdf89f066b362749c46c6a.png)

### `Mixture`

台帳は `write-only` ・ その場 **83.2%** ・ 半画素 83.2% ・ 形 99.2% ・ 完全 83.2%

![Basics/Lights/Mixture](https://i.gyazo.com/688af6dbde49d23fa09d730f0ad0deb5.png)

### `MixtureGrid`

台帳は `write-only` ・ その場 **20.0%** ・ 半画素 20.1% ・ 形 100.0% ・ 完全 0.9%

![Basics/Lights/MixtureGrid](https://i.gyazo.com/2e735070e91c012443448d8cd9cb4a30.png)

### `OnOff`

台帳は `clean` ・ その場 **88.8%** ・ 半画素 88.8% ・ 形 99.0% ・ 完全 84.0%

![Basics/Lights/OnOff](https://i.gyazo.com/66e5997a798f07acbe9ee795d6350311.png)

### `Reflection`

台帳は `bend` ・ その場 **77.8%** ・ 半画素 77.8% ・ 形 99.5% ・ 完全 77.4%

![Basics/Lights/Reflection](https://i.gyazo.com/a474267e10947c391866210a73d7d17e.png)

### `Spot`

台帳は `clean` ・ その場 **77.0%** ・ 半画素 77.0% ・ 形 99.4% ・ 完全 77.0%

![Basics/Lights/Spot](https://i.gyazo.com/c3130de446d2d45fd2a179954dae7c22.png)

## Basics/Math

### `AdditiveWave`

台帳は `bend` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Basics/Math/AdditiveWave](https://i.gyazo.com/7635805434c6e34bc3bdd2a583e036e7.png)

### `Arctangent`

台帳は `clean` ・ その場 **93.9%** ・ 半画素 94.1% ・ 形 100.0% ・ 完全 93.9%

![Basics/Math/Arctangent](https://i.gyazo.com/31ba2c6f316a815ddc9a4f807f6c5d5b.png)

### `Distance1D`

台帳は `clean` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 100.0%

![Basics/Math/Distance1D](https://i.gyazo.com/14ef6768271f5abecd394d473a0eae77.png)

### `Distance2D`

台帳は `write-only` ・ その場 **97.8%** ・ 半画素 98.7% ・ 形 100.0% ・ 完全 97.8%

![Basics/Math/Distance2D](https://i.gyazo.com/44dd34688e4cfe483befab1ba4c24775.png)

### `DoubleRandom`

台帳は `bend` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Basics/Math/DoubleRandom](https://i.gyazo.com/60c746ee5cbc88cbc167e7d8240cca57.png)

### `Graphing2DEquation`

台帳は `blocked` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 98.9%

![Basics/Math/Graphing2DEquation](https://i.gyazo.com/366cdaf35d265e4121828c0221c92266.png)

### `IncrementDecrement`

台帳は `bend` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 100.0%

![Basics/Math/IncrementDecrement](https://i.gyazo.com/fc5fde10f1a489abf04294abe40985c7.png)

### `Interpolate`

台帳は `write-only` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 100.0%

![Basics/Math/Interpolate](https://i.gyazo.com/a2100aa129b5b97d85a72b0994bdd7c6.png)

### `Map`

台帳は `write-only` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 100.0% ・ 円の輪郭のアンチエイリアス

![Basics/Math/Map](https://i.gyazo.com/1d8fd4d45af7acad364580d7cd14ec2a.png)

### `Noise1D`

台帳は `clean` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Basics/Math/Noise1D](https://i.gyazo.com/66e17c9601ab09a20b74ad43c3313634.png)

### `Noise2D`

台帳は `blocked` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Basics/Math/Noise2D](https://i.gyazo.com/7625e79e3d23acda6f3401c40de6e7dc.png)

### `Noise3D`

台帳は `blocked` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Basics/Math/Noise3D](https://i.gyazo.com/0b063b7b92edcf2b5ab1458445556edc.png)

### `NoiseWave`

台帳は `write-only` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Basics/Math/NoiseWave](https://i.gyazo.com/719f4b1cbfe6b964181ab4539dbb98b6.png)

### `OperatorPrecedence`

台帳は `clean` ・ その場 **43.6%** ・ 半画素 99.5% ・ 形 52.0% ・ 完全 43.6% ・ 同上。線でできた例はここが効く

![Basics/Math/OperatorPrecedence](https://i.gyazo.com/41fd34f96bf659d4d6ec529ca4d72f2f.png)

### `PolarToCartesian`

台帳は `clean` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 100.0%

![Basics/Math/PolarToCartesian](https://i.gyazo.com/f3db7e15cd9f0b5ebcdae31c1939cf13.png)

### `Random`

台帳は `bend` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Basics/Math/Random](https://i.gyazo.com/815fffe12da1aae9cfc65a3a3fe0a587.png)

### `RandomGaussian`

台帳は `write-only` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Basics/Math/RandomGaussian](https://i.gyazo.com/79ab46fe36e4b3ad5a77f234d67b095e.png)

### `Sine`

台帳は `clean` ・ その場 **99.4%** ・ 半画素 99.6% ・ 形 100.0% ・ 完全 43.9%

![Basics/Math/Sine](https://i.gyazo.com/ed5b37ada9113af9524d9640aa73525b.png)

### `SineCosine`

台帳は `write-only` ・ その場 **99.7%** ・ 半画素 99.8% ・ 形 100.0% ・ 完全 93.2%

![Basics/Math/SineCosine](https://i.gyazo.com/e58011f59782aca1df86f0a3ffdfc618.png)

### `SineWave`

台帳は `clean` ・ その場 **99.2%** ・ 半画素 99.6% ・ 形 100.0% ・ 完全 99.2%

![Basics/Math/SineWave](https://i.gyazo.com/44a1f011488d4cb7fcb09d0db15e9d7c.png)

## Basics/Objects

### `CompositeObjects`

台帳は `clean` ・ その場 **97.2%** ・ 半画素 97.3% ・ 形 99.5% ・ 完全 97.2%

![Basics/Objects/CompositeObjects](https://i.gyazo.com/98697f827466458d045b8363da6f531d.png)

### `Inheritance`

台帳は `clean` ・ その場 **99.7%** ・ 半画素 99.8% ・ 形 100.0% ・ 完全 99.7%

![Basics/Objects/Inheritance](https://i.gyazo.com/1c96fec66dd8053d64deb71a369c4b55.png)

### `MultipleConstructors`

台帳は `blocked` ・ その場 **99.3%** ・ 半画素 99.3% ・ 形 99.9% ・ 完全 99.3%

![Basics/Objects/MultipleConstructors](https://i.gyazo.com/93e12afc3ae2feba1f49567ec6d3cb7d.png)

### `Objects`

台帳は `clean` ・ その場 **90.7%** ・ 半画素 90.7% ・ 形 100.0% ・ 完全 90.2%

![Basics/Objects/Objects](https://i.gyazo.com/e5e7ae01e616831e488b6d0854b016f6.png)

## Basics/Shape

### `LoadDisplayOBJ`

台帳は `blocked` ・ その場 **90.8%** ・ 半画素 90.8% ・ 形 98.7% ・ 完全 90.8%

![Basics/Shape/LoadDisplayOBJ](https://i.gyazo.com/a9ea8c8aa5cdaa56d79aaa93407881ca.png)

## Basics/Structure

### `Coordinates`

台帳は `clean` ・ その場 **98.1%** ・ 半画素 99.2% ・ 形 99.7% ・ 完全 98.1%

![Basics/Structure/Coordinates](https://i.gyazo.com/a12d6b3631f4be5ababe9e85f1bc7852.png)

### `CreateGraphics`

台帳は `clean` ・ その場 **99.6%** ・ 半画素 99.6% ・ 形 99.6% ・ 完全 99.6%

![Basics/Structure/CreateGraphics](https://i.gyazo.com/e3696d2bf27f0546d405d95319c6d05d.png)

### `Functions`

台帳は `blocked` ・ その場 **97.7%** ・ 半画素 99.1% ・ 形 100.0% ・ 完全 66.3%

![Basics/Structure/Functions](https://i.gyazo.com/7848fe08390a6fa1bfc62153a0c38d75.png)

### `Loop`

台帳は `blocked` ・ その場 **99.4%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 99.4%

![Basics/Structure/Loop](https://i.gyazo.com/ad85028b34242961979c6f7e61f7e03e.png)

### `NoLoop`

台帳は `blocked` ・ その場 **99.2%** ・ 半画素 99.4% ・ 形 99.7% ・ 完全 99.2% ・ 1px の線の置き方 (p5 は 2 行に 128、mokume は 1 行に 255)

![Basics/Structure/NoLoop](https://i.gyazo.com/a57a486bad51f567042a317a4f0adcdf.png)

### `Recursion`

台帳は `blocked` ・ その場 **96.8%** ・ 半画素 98.7% ・ 形 99.9% ・ 完全 61.4%

![Basics/Structure/Recursion](https://i.gyazo.com/caca61179c6a64736235f9ed995360d2.png)

### `Redraw`

台帳は `blocked` ・ その場 **99.4%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 99.4%

![Basics/Structure/Redraw](https://i.gyazo.com/212b1bb0fdf3b9a2718208e6ddcd26ee.png)

### `SetupDraw`

台帳は `clean` ・ その場 **99.2%** ・ 半画素 99.2% ・ 形 98.9% ・ 完全 99.2%

![Basics/Structure/SetupDraw](https://i.gyazo.com/2252844d4dd9a1f28c2141e735b195fd.png)

### `StatementsComments`

台帳は `clean` ・ その場 **0.0%** ・ 半画素 0.0% ・ 形 100.0% ・ 完全 0.0% ・ 面ぜんぶが 9 ずれる。書き出しが Display P3 で刻まれるため

![Basics/Structure/StatementsComments](https://i.gyazo.com/ceb34e9673b0ea3b92c5bdf068e845ce.png)

### `WidthHeight`

台帳は `clean` ・ その場 **57.4%** ・ 半画素 57.4% ・ 形 100.0% ・ 完全 57.4% ・ 色の帯が 28 ずれる (129,206,15 → 101,208,0)。灰色と白は一致

![Basics/Structure/WidthHeight](https://i.gyazo.com/7653a6633dab7b25179100ea855c0015.png)

## Basics/Transform

### `Arm`

台帳は `clean` ・ その場 **97.1%** ・ 半画素 97.1% ・ 形 99.9% ・ 完全 97.1%

![Basics/Transform/Arm](https://i.gyazo.com/83ef8c6862e27f59264ee96f0c0d1437.png)

### `Rotate`

台帳は `blocked` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Basics/Transform/Rotate](https://i.gyazo.com/0f272a67aeda15a63f1c1d830571620c.png)

### `RotatePushPop`

台帳は `write-only` ・ その場 **57.3%** ・ 半画素 57.5% ・ 形 93.2% ・ 完全 0.3%

![Basics/Transform/RotatePushPop](https://i.gyazo.com/a46b0925b21d63fc86d6fd6a21e6a495.png)

### `RotateXY`

台帳は `clean` ・ その場 **89.9%** ・ 半画素 89.9% ・ 形 99.8% ・ 完全 89.9%

![Basics/Transform/RotateXY](https://i.gyazo.com/396721625a7672486ab2b9da01297f47.png)

### `Scale`

台帳は `bend` ・ その場 **99.6%** ・ 半画素 99.6% ・ 形 100.0% ・ 完全 99.5%

![Basics/Transform/Scale](https://i.gyazo.com/1d98f52d051cd051c23934d295fde365.png)

### `Translate`

台帳は `clean` ・ その場 **99.9%** ・ 半画素 99.9% ・ 形 100.0% ・ 完全 99.9%

![Basics/Transform/Translate](https://i.gyazo.com/c0b0851d7fcba0185ccbf1c52d795dee.png)

## Basics/Typography

### `Letters`

台帳は `blocked` ・ **測らない** — 字を組む。原典はブラウザの、mokume は macOS の書体で字形が違う

![Basics/Typography/Letters](https://i.gyazo.com/1a102d7b9fc626849d2d9608f1a0f983.png)

### `TextRotation`

台帳は `blocked` ・ **測らない** — 字を組む。原典はブラウザの、mokume は macOS の書体で字形が違う

![Basics/Typography/TextRotation](https://i.gyazo.com/f0cd0452787c7500024c1c80c89da7c9.png)

### `Words`

台帳は `blocked` ・ **測らない** — 字を組む。原典はブラウザの、mokume は macOS の書体で字形が違う

![Basics/Typography/Words](https://i.gyazo.com/48a7b14a39cb416df3124c7eb46d4612.png)

## Basics/Web

### `EmbeddedLinks`

台帳は `out-of-scope` ・ その場 **99.4%** ・ 半画素 99.4% ・ 形 99.7% ・ 完全 99.4%

![Basics/Web/EmbeddedLinks](https://i.gyazo.com/05b11dfce2c6a9c88605d06dee88778e.png)

### `LoadingImages`

台帳は `out-of-scope` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 100.0%

![Basics/Web/LoadingImages](https://i.gyazo.com/9e34ddbd683d1fa1f297ee4fe8597411.png)

## Topics/Advanced Data

### `ArrayListClass`

台帳は `out-of-scope` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 100.0%

![Topics/Advanced Data/ArrayListClass](https://i.gyazo.com/247f78fe783541a93c6635a6bb4d7f4e.png)

### `IntListLottery`

台帳は `out-of-scope` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Topics/Advanced Data/IntListLottery](https://i.gyazo.com/eb7c7d9525154d5ff100a0903355a67e.png)

### `LoadSaveJSON`

台帳は `out-of-scope` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Topics/Advanced Data/LoadSaveJSON](https://i.gyazo.com/f6a8f5f3ea2ad364b7873fe4551684ac.png)

### `LoadSaveTable`

台帳は `out-of-scope` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Topics/Advanced Data/LoadSaveTable](https://i.gyazo.com/c02b2720359f5cd6e48ecd9880b6099c.png)

## Topics/Animation

### `AnimatedSprite`

台帳は `bend` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 0.0%

![Topics/Animation/AnimatedSprite](https://i.gyazo.com/6300271c404eb47b374d604d7ff831cf.png)

### `Sequential`

台帳は `bend` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 100.0%

![Topics/Animation/Sequential](https://i.gyazo.com/02a16c251c6db6872f5e90d4b946ce4a.png)

## Topics/Cellular Automata

### `GameOfLife`

台帳は `blocked` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Topics/Cellular Automata/GameOfLife](https://i.gyazo.com/dfad46d62f4a7bc6752dff014baae554.png)

### `Wolfram`

台帳は `bend` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Topics/Cellular Automata/Wolfram](https://i.gyazo.com/f91db95541ab09c0ddca0ba97a6a8f49.png)

## Topics/Drawing

### `ContinuousLines`

台帳は `clean` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 100.0% ・ 1 画素も違わない

![Topics/Drawing/ContinuousLines](https://i.gyazo.com/bf6e690209c3979939765b4c8b422662.png)

### `Pattern`

台帳は `clean` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 100.0%

![Topics/Drawing/Pattern](https://i.gyazo.com/00a4ba7fc82c81c6c6b16ebafa201fdd.png)

### `Pulses`

台帳は `write-only` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 100.0%

![Topics/Drawing/Pulses](https://i.gyazo.com/c5f499cf25cdcf1d2c4cc034922ab32a.png)

## Topics/File IO

### `LoadFile1`

台帳は `out-of-scope` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 100.0%

![Topics/File IO/LoadFile1](https://i.gyazo.com/2cb70dd9ea06e230f8bf91242a54c6fb.png)

### `LoadFile2`

台帳は `out-of-scope` ・ **測らない** — 字を組む。原典はブラウザの、mokume は macOS の書体で字形が違う

![Topics/File IO/LoadFile2](https://i.gyazo.com/6f8a2067c014832fcb1be9dbe3f3f65b.png)

### `SaveOneImage`

台帳は `out-of-scope` ・ その場 **99.6%** ・ 半画素 99.6% ・ 形 100.0% ・ 完全 99.6%

![Topics/File IO/SaveOneImage](https://i.gyazo.com/d86fcf06a8f2a13480c810b83f19b7ae.png)

## Topics/Fractals and L-Systems

### `Koch`

台帳は `bend` ・ その場 **99.4%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 99.4%

![Topics/Fractals and L-Systems/Koch](https://i.gyazo.com/b80b55036feede07fa1333649ba38654.png)

### `Mandelbrot`

台帳は `blocked` ・ その場 **30.4%** ・ 半画素 30.9% ・ 形 92.4% ・ 完全 11.5%

![Topics/Fractals and L-Systems/Mandelbrot](https://i.gyazo.com/bf614eaa4ca2dfe7e106b775cc87f786.png)

### `PenroseSnowflake`

台帳は `write-only` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 100.0%

![Topics/Fractals and L-Systems/PenroseSnowflake](https://i.gyazo.com/34504e4e767521b10c92a6057907e2bb.png)

### `PenroseTile`

台帳は `write-only` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 99.9%

![Topics/Fractals and L-Systems/PenroseTile](https://i.gyazo.com/9fb55fa95b8b9246faa6c1346bb84c3c.png)

### `Pentigree`

台帳は `write-only` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 100.0%

![Topics/Fractals and L-Systems/Pentigree](https://i.gyazo.com/7f8fa226c7e30f1ca8c5cf8c86bdf4eb.png)

### `Tree`

台帳は `bend` ・ その場 **99.7%** ・ 半画素 99.8% ・ 形 100.0% ・ 完全 99.7%

![Topics/Fractals and L-Systems/Tree](https://i.gyazo.com/ed9c70a707136a475ab0f43af7b75d18.png)

## Topics/GUI

### `Button`

台帳は `bend` ・ その場 **99.5%** ・ 半画素 99.9% ・ 形 100.0% ・ 完全 99.5%

![Topics/GUI/Button](https://i.gyazo.com/6c47909fbbe0aed7aef7de99e02e8217.png)

### `Handles`

台帳は `bend` ・ その場 **98.1%** ・ 半画素 99.9% ・ 形 100.0% ・ 完全 98.1%

![Topics/GUI/Handles](https://i.gyazo.com/c0947a26f468cb6e86436a274c2713e0.png)

### `Rollover`

台帳は `write-only` ・ その場 **99.5%** ・ 半画素 99.9% ・ 形 100.0% ・ 完全 99.5%

![Topics/GUI/Rollover](https://i.gyazo.com/fc69ac0ca4ef40c3d84f4e76d32e9322.png)

### `Scrollbar`

台帳は `bend` ・ その場 **99.4%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 84.7%

![Topics/GUI/Scrollbar](https://i.gyazo.com/aa7d94f306179cfab96b489d46f9878e.png)

## Topics/Image Processing

### `Blur`

台帳は `blocked` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 92.6%

![Topics/Image Processing/Blur](https://i.gyazo.com/1c13e1735ce9825f285ad205a32e53f9.png)

### `BrightnessPixels`

台帳は `blocked` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 99.1%

![Topics/Image Processing/BrightnessPixels](https://i.gyazo.com/21a276134624cd666e8e75e7f2b54a8e.png)

### `Convolution`

台帳は `blocked` ・ **測らない** — 字を組む。原典はブラウザの、mokume は macOS の書体で字形が違う

![Topics/Image Processing/Convolution](https://i.gyazo.com/459184944f159dab06fd90ac322276bf.png)

### `EdgeDetection`

台帳は `blocked` ・ その場 **63.0%** ・ 半画素 64.2% ・ 形 99.7% ・ 完全 58.2%

![Topics/Image Processing/EdgeDetection](https://i.gyazo.com/6ca865ff20bbaf19bac8b38a213568a5.png)

### `Histogram`

台帳は `blocked` ・ その場 **79.1%** ・ 半画素 90.8% ・ 形 97.0% ・ 完全 55.5%

![Topics/Image Processing/Histogram](https://i.gyazo.com/b3eb891db98e3dc0409091fc83c5491a.png)

### `PixelArray`

台帳は `bend` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 0.0%

![Topics/Image Processing/PixelArray](https://i.gyazo.com/13df204b2785ce30b4ca4d5af1066a96.png)

## Topics/Interaction

### `Follow1`

台帳は `clean` ・ その場 **99.3%** ・ 半画素 99.3% ・ 形 99.9% ・ 完全 99.3%

![Topics/Interaction/Follow1](https://i.gyazo.com/7bc9ab77600b418c180a8c7245e8e8af.png)

### `Follow2`

台帳は `clean` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 100.0%

![Topics/Interaction/Follow2](https://i.gyazo.com/04a0c7f94509be285521f1a252897f08.png)

### `Follow3`

台帳は `clean` ・ その場 **99.9%** ・ 半画素 99.9% ・ 形 100.0% ・ 完全 99.9%

![Topics/Interaction/Follow3](https://i.gyazo.com/61e7c0834f567295c4533435dd9d3b5e.png)

### `Reach1`

台帳は `clean` ・ その場 **98.4%** ・ 半画素 98.4% ・ 形 100.0% ・ 完全 98.4%

![Topics/Interaction/Reach1](https://i.gyazo.com/71cebb3c5dd670ef49a0da6d4b8a4b15.png)

### `Reach2`

台帳は `clean` ・ その場 **99.1%** ・ 半画素 99.1% ・ 形 99.7% ・ 完全 99.1%

![Topics/Interaction/Reach2](https://i.gyazo.com/e5999de1b48e4712e570a6ee73f33d17.png)

### `Reach3`

台帳は `clean` ・ その場 **98.9%** ・ 半画素 98.9% ・ 形 99.9% ・ 完全 98.8%

![Topics/Interaction/Reach3](https://i.gyazo.com/b31dd45584e71dd96590571eef9cc321.png)

### `Tickle`

台帳は `blocked` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Topics/Interaction/Tickle](https://i.gyazo.com/90ac909037b677c599a64d58de6e33ef.png)

## Topics/Motion

### `Bounce`

台帳は `bend` ・ その場 **99.9%** ・ 半画素 99.9% ・ 形 100.0% ・ 完全 99.9%

![Topics/Motion/Bounce](https://i.gyazo.com/68bb8149176c6ee11267abaec5874a29.png)

### `BouncyBubbles`

台帳は `clean` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Topics/Motion/BouncyBubbles](https://i.gyazo.com/88529c49e1f654307addd776e4e91556.png)

### `Brownian`

台帳は `bend` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Topics/Motion/Brownian](https://i.gyazo.com/cc324d8358046a87339ab53bf013d661.png)

### `CircleCollision`

台帳は `bend` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 100.0%

![Topics/Motion/CircleCollision](https://i.gyazo.com/2fa1646eaa9ab20cbddee4f4a1c8a936.png)

### `Linear`

台帳は `clean` ・ その場 **99.4%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 99.4%

![Topics/Motion/Linear](https://i.gyazo.com/4dc7af28ac9e912128fab20a1f0e80dc.png)

### `Morph`

台帳は `bend` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 100.0%

![Topics/Motion/Morph](https://i.gyazo.com/ed945b6ab28870bbe98767f84e158183.png)

### `MovingOnCurves`

台帳は `bend` ・ その場 **100.0%** ・ 半画素 100.0% ・ 形 100.0% ・ 完全 100.0%

![Topics/Motion/MovingOnCurves](https://i.gyazo.com/4f04884d4ae65aa7b2d552ff6d4bd46f.png)

### `Reflection1`

台帳は `bend` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Topics/Motion/Reflection1](https://i.gyazo.com/92425e42b3fe29b257b7d82d76ef9cdc.png)

### `Reflection2`

台帳は `bend` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Topics/Motion/Reflection2](https://i.gyazo.com/5b8679b6b491ccb1e1de82c189a29007.png)

## Topics/Simulate

### `Flocking`

台帳は `bend` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Topics/Simulate/Flocking](https://i.gyazo.com/19587a41b47c708d1247828ec6810300.png)

### `ForcesWithVectors`

台帳は `bend` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Topics/Simulate/ForcesWithVectors](https://i.gyazo.com/719e659b7ac6770de242b6ae8b96a4fb.png)

### `MultipleParticleSystems`

台帳は `bend` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Topics/Simulate/MultipleParticleSystems](https://i.gyazo.com/31957217dff78e7f38a67dc8747c1b7a.png)

### `SimpleParticleSystem`

台帳は `bend` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Topics/Simulate/SimpleParticleSystem](https://i.gyazo.com/45b74108377e3b99a3ab98eaa0affa6f.png)

### `SmokeParticleSystem`

台帳は `bend` ・ **測らない** — 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い

![Topics/Simulate/SmokeParticleSystem](https://i.gyazo.com/d269ef55c922f27fa19c5773808354a1.png)

## Topics/Vectors

### `AccelerationWithVectors`

台帳は `bend` ・ その場 **99.9%** ・ 半画素 99.9% ・ 形 100.0% ・ 完全 99.9%

![Topics/Vectors/AccelerationWithVectors](https://i.gyazo.com/c4485f62ca3f6230bff15854cc7b3130.png)

### `BouncingBall`

台帳は `bend` ・ その場 **99.9%** ・ 半画素 99.9% ・ 形 100.0% ・ 完全 99.9%

![Topics/Vectors/BouncingBall](https://i.gyazo.com/633b74aafc6759a16b4d7a6fdd11de6a.png)

### `VectorMath`

台帳は `bend` ・ その場 **99.9%** ・ 半画素 99.9% ・ 形 100.0% ・ 完全 99.9%

![Topics/Vectors/VectorMath](https://i.gyazo.com/32f0ecf364ba3084d861b5acea73746e.png)

