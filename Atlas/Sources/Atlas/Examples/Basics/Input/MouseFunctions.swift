import mokume

/// Processing の [Mouse Functions](https://processing.org/examples/mousefunctions/) を 1 行ずつ移したもの。
///
/// **台帳は `bend` と言った。当たっている。ここで止まっている。**
/// 原典の主題は `mousePressed()` / `mouseDragged()` / `mouseReleased()` の 3 つで箱を
/// 掴んで動かすことで、**mokume には出来事を受ける口が 1 つも無い**
/// ([#723](https://github.com/mokume-metal/mokume/issues/723))。触れているかどうかを
/// 見る `draw()` の側だけが移り、掴む側が丸ごと落ちる。
final class MouseFunctions: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Mouse Functions")

    private var bx: Float = 0
    private var by: Float = 0
    private let boxSize: Float = 75
    private var overBox = false
    private var locked = false

    func setup() {
        bx = width / 2.0
        by = height / 2.0
        rectMode(.radius)
    }

    func draw() {
        background(0)

        // 箱の上に来ているか
        if mouseX > bx - boxSize && mouseX < bx + boxSize
            && mouseY > by - boxSize && mouseY < by + boxSize {
            overBox = true
            if !locked {
                stroke(255)
                fill(153)
            }
        } else {
            stroke(153)
            fill(153)
            overBox = false
        }

        rect(bx, by, boxSize, boxSize)
    }

    // 原典はここに mousePressed / mouseDragged / mouseReleased を持つ。**どれも書けない**
}
