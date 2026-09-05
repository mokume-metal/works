import mokume

/// Processing の [No Loop](https://processing.org/examples/noloop/) を移そうとしたもの。
///
/// **台帳は `blocked` と言った。当たっている。ここで止まっている。**
///
/// 原典は `setup()` で `noLoop()` を呼び、`draw()` を 1 度だけ走らせて 1 本の線を引く。
/// mokume に進行を止める口が無いので `draw()` は毎フレーム呼ばれ、**原典が見せようと
/// している「1 度だけ描く」がそのまま消える** — 線は上へ流れ、`y` が 0 を切ると下へ戻る。
///
/// 動かないものを動くように書き替えていない。ADR-0022 決定 4 の言うとおり、
/// **作ろうとして止まったこと自体が実需**なので、止まった形のまま残す。
/// 台帳によれば `noLoop` を要求する例は 18 本ある。
final class NoLoop: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "No Loop")

    /// 原典の `background(0)`
    private static let ground = LinearRGBA.display(red: 0, green: 0, blue: 0)

    /// 原典の `stroke(255)`
    private static let ink = LinearRGBA.display(red: 1, green: 1, blue: 1)

    private var y: Float = 180

    func setup() {
        stroke(Self.ink)
        // 原典はここで noLoop() を呼ぶ。**書けない**
    }

    func draw() {
        background(Self.ground)
        line(0, y, width, y)
        y -= 1
        if y < 0 { y = height }
    }
}
