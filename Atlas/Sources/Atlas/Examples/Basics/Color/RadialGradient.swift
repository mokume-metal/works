import mokume

/// Processing の [Radial Gradient](https://processing.org/examples/radialgradient/) を 1 行ずつ移したもの。
///
/// **台帳は `bend` と言った。当たっている。歪みが 3 つ重なる。**
/// `colorMode(HSB, 360, 100, 100)` が書けず、`frameRate(1)` は走り出す前にしか決められず、
/// `ellipseMode(RADIUS)` は `ShapeMode.radius` へ名前が変わる。
///
/// 乱数で色相を選ぶので **画素では比べられない。**
final class RadialGradient: Sketch {
    var settings = SketchSettings(width: 640, height: 360, frameRate: 1, title: "Radial Gradient")

    private var dim: Float = 0

    func setup() {
        dim = width / 2
        background(gray(0))
        // 原典はここで `colorMode(HSB, 360, 100, 100)` を呼ぶ。**書けない**
        noStroke()
        ellipseMode(.radius)
        // 原典はここで `frameRate(1)` を呼ぶ。settings へ移した
    }

    func draw() {
        background(gray(0))
        for x in stride(from: Float(0), through: width, by: dim) {
            drawGradient(x, height / 2)
        }
    }

    private func drawGradient(_ x: Float, _ y: Float) {
        let radius = Int(dim / 2)
        var h = random(0, 360)
        for r in stride(from: radius, to: 0, by: -1) {
            fill(hsb(h, 90, 90, max: (360, 100, 100)))
            ellipse(x, y, Float(r), Float(r))
            h = (h + 1).truncatingRemainder(dividingBy: 360)
        }
    }
}
