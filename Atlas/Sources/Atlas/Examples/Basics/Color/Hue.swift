import mokume

/// Processing の [Hue](https://processing.org/examples/hue/) を 1 行ずつ移したもの。
///
/// **台帳は `bend` と言った。当たっている。**`colorMode(HSB, height, height, height)`
/// が書けないので、色相環そのものを面の外に書くことになる ([#778](https://github.com/mokume-metal/mokume/issues/778))。
final class Hue: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Hue")

    private let barWidth: Float = 20
    private var lastBar: Float = -1

    func setup() {
        // 原典はここで `colorMode(HSB, height, height, height)` を呼ぶ。**書けない**
        noStroke()
        background(gray(0))
    }

    func draw() {
        let whichBar = (mouseX / barWidth).rounded(.down)
        if whichBar != lastBar {
            let barX = whichBar * barWidth
            fill(hsb(mouseY, height, height, max: (height, height, height)))
            rect(barX, 0, barWidth, height)
            lastBar = whichBar
        }
    }
}
