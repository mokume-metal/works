| 区分 | 例数 | |
| --- | ---: | --- |
| `clean` | 64 | そのまま届く |
| `write-only` | 23 | 書けば届く |
| `bend` | 63 | 書けるが歪む |
| `blocked` | 53 | 口が無くて止まる |
| `out-of-scope` | 51 | 測らないと決めた |
| **合計** | **254** | |

公式ページに載る 162 本を、**原典と並べられるか**で分けたもの。

| 並べられるか | 例数 | |
| --- | ---: | --- |
| `draws` | 121 | そのまま絵が出る |
| `bent` | 35 | 歪めれば絵は出る |
| `none` | 6 | 絵が出せない |
| **合計** | **162** | |

原典は 156 本が p5 (`liveSketch.js`)、6 本は site が置く静止画だけ。

| 何本の例を止めるか | 語彙 | 判定 | mokume では |
| ---: | --- | --- | --- |
| 33 | `map` | `write` ([#883](https://github.com/mokume-metal/mokume/issues/883)) | — |
| 25 | `PVector` | `bend` | SIMD2<Float> / SIMD3<Float> |
| 23 | `radians` | `write` ([#883](https://github.com/mokume-metal/mokume/issues/883)) | — |
| 20 | `frameRate` | `bend` | SketchSettings.frameRate |
| 18 | `mousePressed` | `bend` ([#723](https://github.com/mokume-metal/mokume/issues/723)) | isMousePressed |
| 18 | `noLoop` | `none` | — |
| 12 | `colorMode` | `bend` ([#778](https://github.com/mokume-metal/mokume/issues/778)) | — |
| 11 | `keyPressed` | `bend` ([#723](https://github.com/mokume-metal/mokume/issues/723)) | isKeyDown(code:) |
| 10 | `dist` | `write` | — |
| 10 | `updatePixels` | `none` | — |
| 9 | `constrain` | `write` | — |
| 8 | `QUADS` | `bend` ([#882](https://github.com/mokume-metal/mokume/issues/882)) | — |
| 7 | `mag` | `write` | — |
| 6 | `HSB` | `bend` ([#778](https://github.com/mokume-metal/mokume/issues/778)) | — |
| 6 | `QUAD_STRIP` | `bend` ([#882](https://github.com/mokume-metal/mokume/issues/882)) | — |
| 6 | `createFont` | `none` | — |
| 6 | `getChild` | `none` | — |
| 6 | `loadShape` | `none` | — |
| 6 | `mouseDragged` | `bend` ([#723](https://github.com/mokume-metal/mokume/issues/723)) | isMousePressed と mouseX/mouseY |
| 5 | `GROUP` | `none` | — |
