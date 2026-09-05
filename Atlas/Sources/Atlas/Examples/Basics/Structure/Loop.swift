import mokume

/// Processing の [Loop](https://processing.org/examples/loop/) を 1 行ずつ移したもの。
///
/// **台帳は `blocked` と言った。当たっている。ここで止まっている。**
/// 原典の主題は「`noLoop()` で止め、押したら `loop()` で動かす」ことそのもので、
/// mokume には**止める口も動かす口も無い**。止まらないので、押す前から線が流れる。
///
/// **動くように書き替えていない** — 作ろうとして止まったこと自体が実需である
/// (ADR-0022 決定 4)。`NoLoop` と同じ場所で 2 本目。
final class Loop: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Loop")

    private var y: Float = 180

    func setup() {
        stroke(gray(255))
        // 原典はここで `noLoop()` を呼ぶ。**書けない**
    }

    func draw() {
        background(gray(0))
        line(0, y, width, y)
        y = y - 1
        if y < 0 { y = height }
    }

    // 原典は `void mousePressed() { loop(); }` を持つ。**どちらも書けない** —
    // 押した瞬間を受ける口が無く ([#723](https://github.com/mokume-metal/mokume/issues/723))、
    // 動かす口も無い
}
