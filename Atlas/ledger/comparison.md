# 原典と並べた全数

<!-- scripts/compare/publish.py が書く。手で直さない -->

移した 5 本を、原典と並べて突き合わせたもの。原典は processing-website が例ごとに配る `liveSketch.js` (Processing 版と 1 行ずつ対応した p5.js) を走らせたもので、**条件を 3 つ揃えてある** — マウスを動かさない・決めた枚数で止める・等倍。

画素で測れたのが 5 本、原典が静止画しか無くて参考値なのが 0 本、測らないと決めたのが 0 本 (乱数・時計・書体を使う例は、原典と mokume で列が違うので一致率に意味が無い)。

道具は mokume v0.5.0 / p5.js 1.9.4。

| 群 | 本数 | 画素で測れた | 一致率の中央値 |
| --- | ---: | ---: | ---: |
| [Basics/Form](#basicsform) | 1 | 1 | 96.1% |
| [Basics/Input](#basicsinput) | 1 | 1 | 92.1% |
| [Basics/Math](#basicsmath) | 1 | 1 | 100.0% |
| [Basics/Structure](#basicsstructure) | 1 | 1 | 99.2% |
| [Topics/Drawing](#topicsdrawing) | 1 | 1 | 100.0% |

## Basics/Form

| 例 | 台帳 | 一致 | 平均差 | 最大差 | 見た目 | 並べた 1 枚 |
| --- | --- | ---: | ---: | ---: | --- | --- |
| `Bezier` | `bend` | 96.1% | 6.11 | 255 | 曲線の輪郭のアンチエイリアス | [見る](https://i.gyazo.com/0427e8bc7a34a5f71f851cadec0511c7.png) |

## Basics/Input

| 例 | 台帳 | 一致 | 平均差 | 最大差 | 見た目 | 並べた 1 枚 |
| --- | --- | ---: | ---: | ---: | --- | --- |
| `Mouse2D` | `clean` | 92.1% | 1.41 | 18 | 半透明の合成 (線形空間で混ぜるので 214 ではなく 232) | [見る](https://i.gyazo.com/2e896bfdb06b5ff5d3c6c47c9112c322.png) |

## Basics/Math

| 例 | 台帳 | 一致 | 平均差 | 最大差 | 見た目 | 並べた 1 枚 |
| --- | --- | ---: | ---: | ---: | --- | --- |
| `Map` | `write-only` | 100.0% | 0.07 | 255 | 円の輪郭のアンチエイリアス | [見る](https://i.gyazo.com/c113efc229aac3b6bfc57564bc387e54.png) |

## Basics/Structure

| 例 | 台帳 | 一致 | 平均差 | 最大差 | 見た目 | 並べた 1 枚 |
| --- | --- | ---: | ---: | ---: | --- | --- |
| `NoLoop` | `blocked` | 99.2% | 1.42 | 255 | 1px の線の置き方 (p5 は 2 行に 128、mokume は 1 行に 255) | [見る](https://i.gyazo.com/c870511ab9f5ef344873076f4052cef4.png) |

## Topics/Drawing

| 例 | 台帳 | 一致 | 平均差 | 最大差 | 見た目 | 並べた 1 枚 |
| --- | --- | ---: | ---: | ---: | --- | --- |
| `ContinuousLines` | `clean` | 100.0% | 0.00 | 0 | 1 画素も違わない | [見る](https://i.gyazo.com/b7df21fb981181f80893522962ab6756.png) |

