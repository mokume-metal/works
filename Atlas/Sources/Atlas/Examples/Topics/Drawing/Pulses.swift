import Foundation
import mokume

/// Processing の [Pulses](https://processing.org/examples/pulses/) を 1 行ずつ移したもの。
///
/// **台帳は `write-only` と言った。半分だけ。** `radians()` が無いのはそのとおりだが、
/// 原典の `mousePressed` は**変数**なので `isMousePressed` へ名前が変わる
/// ([#723](https://github.com/mokume-metal/mokume/issues/723))。押さないと描かれない。
final class Pulses: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Pulses")

    private var angle: Float = 0

    func setup() {
        background(102)
        noStroke()
        fill(0, 102)
    }

    func draw() {
        // 押しているあいだだけ描く
        if isMousePressed == true {
            angle += 5
            let val = cos(radians(angle)) * 12.0
            for a in stride(from: 0, to: 360, by: 75) {
                let xoff = cos(radians(Float(a))) * val
                let yoff = sin(radians(Float(a))) * val
                fill(0)
                ellipse(mouseX + xoff, mouseY + yoff, val, val)
            }
            fill(255)
            ellipse(mouseX, mouseY, 2, 2)
        }
    }
}
