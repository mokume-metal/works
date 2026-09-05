import Foundation
import mokume

// Processing にあって mokume の面に無い語彙のうち、**面の外に書けば済むもの**。
// 台帳 (`ledger/vocabulary.jsonl`) が `write` と判定しているものがここに来る。
//
// **1 箇所にまとめたのは、数えるため。** 例ごとに書き下すと、同じ 1 行が 156 回
// 書かれるだけで「何本の例がこれを要求したか」が消える。ここに集めておけば、
// **この 1 ファイルの長さがそのまま「Processing の例を書くのに mokume の外へ
// どれだけ書き足す必要があるか」の答え**になる。
//
// **面に足りないものを面へ足しているわけではない。** ここにあるのは書く側で書ける
// ものだけで、書けないもの (`noLoop` / `colorMode` / キーの出来事) は入れない。
// それらは移植の中に「書けない」と書いて止まった形で残す。

// MARK: - 色

/// 原典の `fill(128)` / `background(0)` — **数値 1 つの灰色**。
///
/// mokume の `fill` / `stroke` / `background` は `LinearRGBA` しか取らないので、
/// 原典の 1 行が `LinearRGBA.display(red:green:blue:)` の書き下しになる。
/// 公式ページの 162 本のうち大半がこの形を使う。
func gray(_ value: Float, _ alpha: Float = 255) -> LinearRGBA {
    .display(red: value / 255, green: value / 255, blue: value / 255, alpha: alpha / 255)
}

/// 原典の `fill(255, 204, 0)` — **0〜255 の 3 つ組**。
///
/// mokume は 0〜1 の `Float` を取るので、原典の数をそのまま渡せない。
func rgb(_ red: Float, _ green: Float, _ blue: Float, _ alpha: Float = 255) -> LinearRGBA {
    .display(red: red / 255, green: green / 255, blue: blue / 255, alpha: alpha / 255)
}

/// 原典の `color(#RRGGBB)` — 16 進の色。
func hex(_ value: UInt32, _ alpha: Float = 255) -> LinearRGBA {
    rgb(Float((value >> 16) & 0xFF), Float((value >> 8) & 0xFF), Float(value & 0xFF), alpha)
}

/// 原典の `lerpColor(a, b, t)`。**混ぜる空間が違う** — mokume は線形の空間で持つので、
/// 原典 (表示値のまま混ぜる) とは中間の色が変わる。
func lerpColor(_ from: LinearRGBA, _ to: LinearRGBA, _ amount: Float) -> LinearRGBA {
    LinearRGBA(
        straightRed: from.red + (to.red - from.red) * amount,
        green: from.green + (to.green - from.green) * amount,
        blue: from.blue + (to.blue - from.blue) * amount,
        alpha: from.alpha + (to.alpha - from.alpha) * amount)
}

// MARK: - 数

/// 原典の `map(value, low1, high1, low2, high2)`。
/// **33 本の例がこれを要求する** — 台帳がいちばん重い欠けとして数えたもの
/// ([mokume#883](https://github.com/mokume-metal/mokume/issues/883))。
func map(_ value: Float, _ start1: Float, _ stop1: Float, _ start2: Float, _ stop2: Float) -> Float {
    start2 + (stop2 - start2) * ((value - start1) / (stop1 - start1))
}

/// 原典の `radians(degrees)`。**23 本の例が要求する** ([#883](https://github.com/mokume-metal/mokume/issues/883))。
func radians(_ degrees: Float) -> Float { degrees * .pi / 180 }

/// 原典の `degrees(radians)`。
func degrees(_ radians: Float) -> Float { radians * 180 / .pi }

/// 原典の `constrain(value, low, high)`。
func constrain(_ value: Float, _ low: Float, _ high: Float) -> Float { min(max(value, low), high) }

/// 原典の `dist(x1, y1, x2, y2)`。
func dist(_ x1: Float, _ y1: Float, _ x2: Float, _ y2: Float) -> Float {
    ((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1)).squareRoot()
}

/// 原典の `dist(x1, y1, z1, x2, y2, z2)` — 立体の側。
func dist(_ x1: Float, _ y1: Float, _ z1: Float, _ x2: Float, _ y2: Float, _ z2: Float) -> Float {
    ((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1) + (z2 - z1) * (z2 - z1)).squareRoot()
}

/// 原典の `mag(x, y)` — 原点からの長さ。
func mag(_ x: Float, _ y: Float) -> Float { (x * x + y * y).squareRoot() }

/// 原典の `lerp(start, stop, amount)`。
func lerp(_ start: Float, _ stop: Float, _ amount: Float) -> Float { start + (stop - start) * amount }

/// 原典の `norm(value, start, stop)` — `map` の 0〜1 版。
func norm(_ value: Float, _ start: Float, _ stop: Float) -> Float { (value - start) / (stop - start) }

/// 原典の `sq(n)`。
func sq(_ value: Float) -> Float { value * value }

/// 原典の `colorMode(HSB, …)` のもとでの `fill(h, s, b)`。
///
/// **mokume に色空間を切り替える口が無い** ([#778](https://github.com/mokume-metal/mokume/issues/778))。
/// `colorMode` は 12 本の例が使い、そのうち 4 本は**目盛りごと張り替える**
/// (`colorMode(HSB, width, 100, height)` — 色相を 0〜640 で数える)。原典は 1 行だが、
/// 移すと「変換を書く」と「目盛りを畳む」の 2 つを書く側が背負う。
func hsb(_ hue: Float, _ saturation: Float, _ brightness: Float,
         max maxima: (Float, Float, Float) = (255, 255, 255), alpha: Float = 255) -> LinearRGBA {
    let h = (hue / maxima.0).truncatingRemainder(dividingBy: 1) * 6
    let s = min(max(saturation / maxima.1, 0), 1)
    let v = min(max(brightness / maxima.2, 0), 1)
    let i = Int(h.rounded(.down))
    let f = h - Float(i)
    let p = v * (1 - s), q = v * (1 - s * f), t = v * (1 - s * (1 - f))
    let (r, g, b): (Float, Float, Float) = switch i % 6 {
    case 0: (v, t, p)
    case 1: (q, v, p)
    case 2: (p, v, t)
    case 3: (p, q, v)
    case 4: (t, p, v)
    default: (v, p, q)
    }
    return .display(red: r, green: g, blue: b, alpha: alpha / 255)
}

// MARK: - 時計

// **mokume に壁時計が無い。** あるのは起動からの秒 (`time`) と `frameCount` と
// `deltaTime` だけで、`millis` / `second` / `hour` は台帳でも `none` に落ちている。
// ただし壁時計そのものは Foundation が持っているので、面の外でなら書ける — 面に
// 無いのは「読む口」であって、値そのものが取れないわけではない。

/// 原典の `second()`。
func second() -> Float { Float(Calendar.current.component(.second, from: Date())) }

/// 原典の `minute()`。
func minute() -> Float { Float(Calendar.current.component(.minute, from: Date())) }

/// 原典の `hour()`。
func hour() -> Float { Float(Calendar.current.component(.hour, from: Date())) }

/// 原典の `millis()` — 走り出してからのミリ秒。**mokume の `time` (秒) と同じものだが、
/// あちらは `Sketch` の上にあるので、面の外からは読めない。** ここでは起動時刻からの
/// 経過で組む。
private let started = Date()
func millis() -> Float { Float(Date().timeIntervalSince(started) * 1000) }

// MARK: - 資材

/// 例が読む資材の道。
///
/// **資材はリポジトリに置けない。** 19 本の例が読む絵・書体・立体にはライセンス表記が
/// 無く、works が再配布する理由もない (`scripts/fetch.py` と同じ判断)。SwiftPM の
/// resource として宣言すると `Sources/` の下へコミットすることになるので、束の外 —
/// `scripts/fetch.py` が置いた `upstream/examples/<例>/data/` — を読む。
///
/// mokume の `loadImage` は**作業ディレクトリからの相対パスを探し先に入れる**ので、
/// これで届く (`ImageFile.candidates`)。
func asset(_ example: String, _ file: String) -> String {
    "upstream/examples/\(example)/data/\(file)"
}
