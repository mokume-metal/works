# 原典と並べた全数

<!-- scripts/compare/publish.py が書く。手で直さない -->

移した 45 本を、原典と並べて突き合わせたもの。原典は processing-website が例ごとに配る `liveSketch.js` (Processing 版と 1 行ずつ対応した p5.js) を走らせたもので、**条件を 3 つ揃えてある** — マウスを動かさない・決めた枚数で止める・等倍。

画素で測れたのが 35 本、原典が静止画しか無くて参考値なのが 0 本、測らないと決めたのが 10 本 (乱数・時計・書体を使う例は、原典と mokume で列が違うので一致率に意味が無い)。

道具は mokume v0.5.0 / p5.js 1.9.4。

| 群 | 本数 | 測った | その場で一致の中央値 |
| --- | ---: | ---: | ---: |
| [Basics/Arrays](#basicsarrays) | 3 | 1 | 74.1% |
| [Basics/Control](#basicscontrol) | 5 | 5 | 86.5% |
| [Basics/Data](#basicsdata) | 4 | 4 | 99.8% |
| [Basics/Form](#basicsform) | 1 | 1 | 96.1% |
| [Basics/Input](#basicsinput) | 1 | 1 | 92.1% |
| [Basics/Math](#basicsmath) | 20 | 12 | 100.0% |
| [Basics/Structure](#basicsstructure) | 10 | 10 | 99.2% |
| [Topics/Drawing](#topicsdrawing) | 1 | 1 | 100.0% |

## Basics/Arrays

| 例 | 台帳 | その場で一致 | 半画素ずらして | 形が一致 | 完全一致 | 差はどこから | 並べた 1 枚 |
| --- | --- | ---: | ---: | ---: | ---: | --- | --- |
| `Array` | `blocked` | — | — | — | — | 原典が 2 つある — site の p5 は線を 1 本おきに引く (i += 2)。移植は Processing の .pde に従っている | [見る](https://i.gyazo.com/de1eef549a05299ed0b1a7dfdfb7ec98.png) |
| `Array2D` | `blocked` | 74.1% | 74.1% | 84.5% | 74.0% |  | [見る](https://i.gyazo.com/7a2e54430961d15377980f7e975361ae.png) |
| `ArrayObjects` | `clean` | — | — | — | — | 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い | [見る](https://i.gyazo.com/07ae696a513c08833e20f22d8c02a436.png) |

## Basics/Control

| 例 | 台帳 | その場で一致 | 半画素ずらして | 形が一致 | 完全一致 | 差はどこから | 並べた 1 枚 |
| --- | --- | ---: | ---: | ---: | ---: | --- | --- |
| `Conditionals1` | `clean` | 92.8% | 99.9% | 100.0% | 92.8% |  | [見る](https://i.gyazo.com/99cca3ac8e171ad48a8ba0963882d448.png) |
| `Conditionals2` | `clean` | 56.9% | 99.9% | 78.3% | 56.9% |  | [見る](https://i.gyazo.com/981cd557502f05458a2be728afd94150.png) |
| `EmbeddedIteration` | `clean` | 86.5% | 86.5% | 100.0% | 85.3% |  | [見る](https://i.gyazo.com/ef972dca3709132496fdf5f066522d4f.png) |
| `Iteration` | `clean` | 98.1% | 98.1% | 99.6% | 98.1% |  | [見る](https://i.gyazo.com/a14519e7fc53b5ad258c96be83329e64.png) |
| `LogicalOperators` | `clean` | 81.7% | 99.8% | 99.9% | 81.7% |  | [見る](https://i.gyazo.com/08ad3d9813fb976e4d6fc2a756adb049.png) |

## Basics/Data

| 例 | 台帳 | その場で一致 | 半画素ずらして | 形が一致 | 完全一致 | 差はどこから | 並べた 1 枚 |
| --- | --- | ---: | ---: | ---: | ---: | --- | --- |
| `IntegersFloats` | `clean` | 99.8% | 99.9% | 100.0% | 99.8% |  | [見る](https://i.gyazo.com/1591ba1b8e8b44eb3868ab504312262c.png) |
| `TrueFalse` | `clean` | 91.4% | 99.9% | 100.0% | 91.4% |  | [見る](https://i.gyazo.com/a4da7787bc9d679fb25f225e548568f6.png) |
| `VariableScope` | `blocked` | 86.4% | 99.8% | 88.0% | 86.4% |  | [見る](https://i.gyazo.com/061980b747a0c8799b6d94fe6f5e1093.png) |
| `Variables` | `clean` | 100.0% | 100.0% | 100.0% | 100.0% |  | [見る](https://i.gyazo.com/2305d324287849ab6dc9b8f1f838c510.png) |

## Basics/Form

| 例 | 台帳 | その場で一致 | 半画素ずらして | 形が一致 | 完全一致 | 差はどこから | 並べた 1 枚 |
| --- | --- | ---: | ---: | ---: | ---: | --- | --- |
| `Bezier` | `bend` | 96.1% | 97.2% | 99.9% | 96.1% | 曲線の輪郭のアンチエイリアス | [見る](https://i.gyazo.com/6ff2bfe81e2ad2ff547000e2a668fe74.png) |

## Basics/Input

| 例 | 台帳 | その場で一致 | 半画素ずらして | 形が一致 | 完全一致 | 差はどこから | 並べた 1 枚 |
| --- | --- | ---: | ---: | ---: | ---: | --- | --- |
| `Mouse2D` | `clean` | 92.1% | 92.1% | 100.0% | 92.1% | 半透明の合成 (線形空間で混ぜるので 214 ではなく 232) | [見る](https://i.gyazo.com/b0043f7a48c18cfe0199553b20dd3a8f.png) |

## Basics/Math

| 例 | 台帳 | その場で一致 | 半画素ずらして | 形が一致 | 完全一致 | 差はどこから | 並べた 1 枚 |
| --- | --- | ---: | ---: | ---: | ---: | --- | --- |
| `AdditiveWave` | `bend` | — | — | — | — | 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い | [見る](https://i.gyazo.com/7635805434c6e34bc3bdd2a583e036e7.png) |
| `Arctangent` | `clean` | 93.9% | 94.1% | 100.0% | 93.9% |  | [見る](https://i.gyazo.com/31ba2c6f316a815ddc9a4f807f6c5d5b.png) |
| `Distance1D` | `clean` | 100.0% | 100.0% | 100.0% | 100.0% |  | [見る](https://i.gyazo.com/14ef6768271f5abecd394d473a0eae77.png) |
| `Distance2D` | `write-only` | 97.8% | 98.7% | 100.0% | 97.8% |  | [見る](https://i.gyazo.com/44dd34688e4cfe483befab1ba4c24775.png) |
| `DoubleRandom` | `bend` | — | — | — | — | 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い | [見る](https://i.gyazo.com/60c746ee5cbc88cbc167e7d8240cca57.png) |
| `Graphing2DEquation` | `blocked` | 100.0% | 100.0% | 100.0% | 98.9% |  | [見る](https://i.gyazo.com/366cdaf35d265e4121828c0221c92266.png) |
| `IncrementDecrement` | `bend` | 100.0% | 100.0% | 100.0% | 100.0% |  | [見る](https://i.gyazo.com/fc5fde10f1a489abf04294abe40985c7.png) |
| `Interpolate` | `write-only` | 100.0% | 100.0% | 100.0% | 100.0% |  | [見る](https://i.gyazo.com/a2100aa129b5b97d85a72b0994bdd7c6.png) |
| `Map` | `write-only` | 100.0% | 100.0% | 100.0% | 100.0% | 円の輪郭のアンチエイリアス | [見る](https://i.gyazo.com/1d8fd4d45af7acad364580d7cd14ec2a.png) |
| `Noise1D` | `clean` | — | — | — | — | 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い | [見る](https://i.gyazo.com/66e17c9601ab09a20b74ad43c3313634.png) |
| `Noise2D` | `blocked` | — | — | — | — | 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い | [見る](https://i.gyazo.com/7625e79e3d23acda6f3401c40de6e7dc.png) |
| `Noise3D` | `blocked` | — | — | — | — | 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い | [見る](https://i.gyazo.com/0b063b7b92edcf2b5ab1458445556edc.png) |
| `NoiseWave` | `write-only` | — | — | — | — | 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い | [見る](https://i.gyazo.com/719f4b1cbfe6b964181ab4539dbb98b6.png) |
| `OperatorPrecedence` | `clean` | 43.6% | 99.5% | 52.0% | 43.6% |  | [見る](https://i.gyazo.com/41fd34f96bf659d4d6ec529ca4d72f2f.png) |
| `PolarToCartesian` | `clean` | 100.0% | 100.0% | 100.0% | 100.0% |  | [見る](https://i.gyazo.com/f3db7e15cd9f0b5ebcdae31c1939cf13.png) |
| `Random` | `bend` | — | — | — | — | 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い | [見る](https://i.gyazo.com/815fffe12da1aae9cfc65a3a3fe0a587.png) |
| `RandomGaussian` | `write-only` | — | — | — | — | 乱数・雑音・時計を使う。原典と列が違うので一致率に意味が無い | [見る](https://i.gyazo.com/79ab46fe36e4b3ad5a77f234d67b095e.png) |
| `Sine` | `clean` | 99.4% | 99.6% | 100.0% | 43.9% |  | [見る](https://i.gyazo.com/ed5b37ada9113af9524d9640aa73525b.png) |
| `SineCosine` | `write-only` | 99.7% | 99.8% | 100.0% | 93.2% |  | [見る](https://i.gyazo.com/e58011f59782aca1df86f0a3ffdfc618.png) |
| `SineWave` | `clean` | 99.2% | 99.6% | 100.0% | 99.2% |  | [見る](https://i.gyazo.com/44a1f011488d4cb7fcb09d0db15e9d7c.png) |

## Basics/Structure

| 例 | 台帳 | その場で一致 | 半画素ずらして | 形が一致 | 完全一致 | 差はどこから | 並べた 1 枚 |
| --- | --- | ---: | ---: | ---: | ---: | --- | --- |
| `Coordinates` | `clean` | 98.1% | 99.2% | 99.7% | 98.1% |  | [見る](https://i.gyazo.com/a12d6b3631f4be5ababe9e85f1bc7852.png) |
| `CreateGraphics` | `clean` | 99.6% | 99.6% | 99.6% | 99.6% |  | [見る](https://i.gyazo.com/e3696d2bf27f0546d405d95319c6d05d.png) |
| `Functions` | `blocked` | 97.7% | 99.1% | 100.0% | 66.3% |  | [見る](https://i.gyazo.com/7848fe08390a6fa1bfc62153a0c38d75.png) |
| `Loop` | `blocked` | 99.4% | 100.0% | 100.0% | 99.4% |  | [見る](https://i.gyazo.com/ad85028b34242961979c6f7e61f7e03e.png) |
| `NoLoop` | `blocked` | 99.2% | 99.4% | 99.7% | 99.2% | 1px の線の置き方 (p5 は 2 行に 128、mokume は 1 行に 255) | [見る](https://i.gyazo.com/a57a486bad51f567042a317a4f0adcdf.png) |
| `Recursion` | `blocked` | 96.8% | 98.7% | 99.9% | 61.4% |  | [見る](https://i.gyazo.com/caca61179c6a64736235f9ed995360d2.png) |
| `Redraw` | `blocked` | 99.4% | 100.0% | 100.0% | 99.4% |  | [見る](https://i.gyazo.com/212b1bb0fdf3b9a2718208e6ddcd26ee.png) |
| `SetupDraw` | `clean` | 99.2% | 99.2% | 98.9% | 99.2% |  | [見る](https://i.gyazo.com/2252844d4dd9a1f28c2141e735b195fd.png) |
| `StatementsComments` | `clean` | 0.0% | 0.0% | 100.0% | 0.0% |  | [見る](https://i.gyazo.com/ceb34e9673b0ea3b92c5bdf068e845ce.png) |
| `WidthHeight` | `clean` | 57.4% | 57.4% | 100.0% | 57.4% |  | [見る](https://i.gyazo.com/7653a6633dab7b25179100ea855c0015.png) |

## Topics/Drawing

| 例 | 台帳 | その場で一致 | 半画素ずらして | 形が一致 | 完全一致 | 差はどこから | 並べた 1 枚 |
| --- | --- | ---: | ---: | ---: | ---: | --- | --- |
| `ContinuousLines` | `clean` | 100.0% | 100.0% | 100.0% | 100.0% | 1 画素も違わない | [見る](https://i.gyazo.com/bf6e690209c3979939765b4c8b422662.png) |

