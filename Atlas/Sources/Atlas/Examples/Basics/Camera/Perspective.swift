import Foundation
import mokume

/// Processing の [Perspective](https://processing.org/examples/perspective/) を 1 行ずつ移したもの。
///
/// **台帳は `bend` と言った。当たっている** — 原典の `mousePressed` は**変数**で、
/// mokume では `isMousePressed` に名前が変わる (出来事ではなくポーリング。
/// [#723](https://github.com/mokume-metal/mokume/issues/723))。それ以外は名前どおり届く。
final class Perspective: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Perspective")

    func setup() {
        noStroke()
    }

    func draw() {
        lights()
        background(gray(0))
        let cameraY = height / 2.0
        let fov = mouseX / width * .pi / 2
        let cameraZ = cameraY / tan(fov / 2.0)
        var aspect = width / height
        if isMousePressed {
            aspect = aspect / 2.0
        }
        perspective(fov, aspect, cameraZ / 10.0, cameraZ * 10.0)

        translate(width / 2 + 30, height / 2, 0)
        rotateX(-.pi / 6)
        rotateY(.pi / 3 + mouseY / height * .pi)
        box(45)
        translate(0, 0, -50)
        box(30)
    }
}
