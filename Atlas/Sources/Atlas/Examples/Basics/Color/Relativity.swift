import mokume

/// Processing の [Relativity](https://processing.org/examples/relativity/) を 1 行ずつ移したもの。
///
/// **台帳は `blocked` と言った。当たっている** — `noLoop()` が無い。絵は変わらない。
final class Relativity: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Relativity")

    private var a = LinearRGBA.transparent
    private var b = LinearRGBA.transparent
    private var c = LinearRGBA.transparent
    private var d = LinearRGBA.transparent
    private var e = LinearRGBA.transparent

    func setup() {
        noStroke()
        a = rgb(165, 167, 20)
        b = rgb(77, 86, 59)
        c = rgb(42, 106, 105)
        d = rgb(165, 89, 20)
        e = rgb(146, 150, 127)
        // 原典はここで `noLoop()` を呼ぶ (「1 度だけ描く」)。**書けない**
    }

    func draw() {
        drawBand(a, b, c, d, e, 0, Int(width) / 128)
        drawBand(c, a, d, b, e, Int(height) / 2, Int(width) / 128)
    }

    private func drawBand(_ v: LinearRGBA, _ w: LinearRGBA, _ x: LinearRGBA,
                          _ y: LinearRGBA, _ z: LinearRGBA, _ ypos: Int, _ barWidth: Int) {
        let num = 5
        let colorOrder = [v, w, x, y, z]
        for i in stride(from: 0, to: Int(width), by: barWidth * num) {
            for j in 0..<num {
                fill(colorOrder[j])
                rect(Float(i + j * barWidth), Float(ypos), Float(barWidth), height / 2)
            }
        }
    }
}
