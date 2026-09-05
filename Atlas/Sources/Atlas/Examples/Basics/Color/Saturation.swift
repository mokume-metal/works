import mokume

/// Processing の [Saturation](https://processing.org/examples/saturation/) を 1 行ずつ移したもの。
///
/// **台帳は `bend` と言った。当たっている。**`colorMode(HSB, width, height, 100)` が
/// 書けないので、彩度そのものを面の外で作る ([#778](https://github.com/mokume-metal/mokume/issues/778))。
final class Saturation: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Saturation")

    private let barWidth: Float = 20
    private var lastBar: Float = -1

    func setup() {
        // 原典はここで `colorMode(HSB, width, height, 100)` を呼ぶ。**書けない**
        noStroke()
    }

    func draw() {
        let whichBar = (mouseX / barWidth).rounded(.down)
        if whichBar != lastBar {
            let barX = whichBar * barWidth
            fill(hsb(barX, mouseY, 66, max: (width, height, 100)))
            rect(barX, 0, barWidth, height)
            lastBar = whichBar
        }
    }
}
