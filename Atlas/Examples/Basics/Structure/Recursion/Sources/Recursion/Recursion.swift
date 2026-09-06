import mokume

/// Processing の [Recursion](https://processing.org/examples/recursion/) を 1 行ずつ移したもの。
///
/// **台帳は `blocked` と言った。当たっている** — `noLoop()` が無い。絵は変わらない。
final class Recursion: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Recursion")

    func setup() {
        noStroke()
        // 原典はここで `noLoop()` を呼ぶ。**書けない**
    }

    func draw() {
        drawCircle(Int(width) / 2, 280, 6)
    }

    private func drawCircle(_ x: Int, _ radius: Int, _ level: Int) {
        let tt = 126 * Float(level) / 4.0
        fill(tt)
        ellipse(Float(x), height / 2, Float(radius * 2), Float(radius * 2))
        if level > 1 {
            let level = level - 1
            drawCircle(x - radius / 2, radius / 2, level)
            drawCircle(x + radius / 2, radius / 2, level)
        }
    }
}
