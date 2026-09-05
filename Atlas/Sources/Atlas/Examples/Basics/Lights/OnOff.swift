import mokume

/// Processing の [On/Off](https://processing.org/examples/onoff/) を 1 行ずつ移したもの。
///
/// **台帳は `bend` と言った。当たっている** — 原典の `mousePressed` は変数なので
/// `isMousePressed` に名前が変わる ([#723](https://github.com/mokume-metal/mokume/issues/723))。
final class OnOff: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "On/Off")

    private var spin: Float = 0.0

    func setup() {
        noStroke()
    }

    func draw() {
        background(51)

        if !isMousePressed {
            lights()
        }

        spin += 0.01

        pushMatrix()
        translate(width / 2, height / 2, 0)
        rotateX(.pi / 9)
        rotateY(.pi / 5 + spin)
        box(150)
        popMatrix()
    }
}
