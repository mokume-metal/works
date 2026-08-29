# Grain — 挽いた板を並べた面

制作トラックの最初の 1 本 ([mokume ADR-0022](https://github.com/mokume-metal/mokume/blob/main/docs/decisions/0022-production-track.md))。板 6 枚を別々の種から作り、年輪・節・繊維を手続き的に置く。

![挽いた板を並べた面](https://i.gyazo.com/51a4afb31890f9cfb0232b107295662a.png)

## 走らせる

開発は CLI から。この作品は 1 つの SwiftPM パッケージで、`mokume-cli` の単位そのものになっている。

```bash
mokume-cli run .      # 作って走らせる
mokume-cli watch .    # 保存したら作り直して差し替える
mokume-cli mcp .      # 走っているスケッチを外から観測する
```

書き出しは実行ファイルへ直に渡す (CLI は引数を通さないため)。

```bash
swift run Grain slab                       # 板を立体にして回す (未完成 — 下記)
swift run Grain --render <置き場> <番号>     # 1 枚だけ書き出す
swift run Grain --frames <置き場> <数> slab  # 連番で書き出す
```

## 検証する

**同じフレーム番号からは同じ絵が出る** (mokume の [ADR-0001](https://github.com/mokume-metal/mokume/blob/main/docs/decisions/0001-founding-principles.md) 原則 2)。上の絵と下の記録が食い違ったら、変えたつもりのないところが変わっている。

| | |
| --- | --- |
| works (スケッチを最後に触ったコミット) | `ad5d2252d01a7d7130f485d3a799ffdee36008c4` |
| mokume | `a919d8fff77d3b62f95ef63accea0754bb173d0f` (`Package.resolved` が固定している) |

```bash
swift run Grain --render out 312 && shasum -a 256 out/grain-312.png
# 383ca101ebef273667a64cef096f72fc1070308fb32664d1291f8b0f7d95ac1c

swift run Grain --frames out-slab 60 slab && shasum -a 256 out-slab/frame-0055.png
# a0a1d3e1c7ccca4b00add68b4e47e73442b27cc10fd8e9f448b7c2b3a918b989
```

**`Package.resolved` はコミットしてある**ので、上の works のコミットを checkout すれば mokume も当時の版に戻る。別の作品が新しい mokume を要求してピンが動いても、この作品の再現は壊れない。

## 作り

- **年輪** — 板の下にある芯からの距離を歪ませて縞にする。晩材は輪の 1 割ほどの細い濃い帯
- **節** — 距離場を持ち上げて輪を巻き込ませ、芯を濃く、そのすぐ外を明るい輪にする
- **繊維とむら** — 長手に緩く・幅方向に細かい揺らぎを 2 段で重ねる

木目は 1 度だけ焼いて `Image` に持ち、継ぎ目と光は描画の側で置く。

### 作りながら直したこと

- **年輪の弧が出ず、水平な縞になっていた。** 芯を板の下 `d` に置くとき、長手方向の係数 `s` が `d` と同じ桁に無いと山形にならない (持ち上がりは `d - sqrt(d² - (s/2)²)`)
- **節のまわりが細かい網に割れていた。** 輪を強く引き寄せすぎて 1 画素に複数の輪が入っていた
- **艶の帯が白く飛んでいた。** 足し込みは飽和する

## 止まったところ

[`Slab.swift`](Slab.swift) は**未完成のまま残してある**。板を立体にして回すと、輪郭は変わるのに木目が画面に貼り付いたまま動かない。

![板は回るのに木目が動かない](https://i.gyazo.com/d487ccc553c11889b8258b24e8c87119.webp)

## mokume へ戻したもの

| 踏んだもの | |
| --- | --- |
| シードから同じ値が出る乱数とノイズが無い | [mokume#366](https://github.com/mokume-metal/mokume/issues/366) |
| 断片が立体の表面の位置も向きも受け取れない | [mokume#367](https://github.com/mokume-metal/mokume/issues/367) |
| 焼いた画像を立体の面に貼る口が無い | [mokume#368](https://github.com/mokume-metal/mokume/issues/368) |

経過は [works#1](https://github.com/mokume-metal/works/issues/1)。

**戻さなかったもの**も 1 つ — 断片で塗った立体が平坦に見えたが、`mokume_fragmentMain` は光を当ててから `in.color` へ入れて `paint` を呼んでいた。こちらの書き方の誤りで、mokume の欠けではない。
