import Foundation
import mokume

/// Processing の [Scrollbar](https://processing.org/examples/scrollbar/) を 1 行ずつ移したもの。
///
/// **台帳は `bend` と言った。当たっている。** `Handles` と同じで、押した瞬間の印を
/// 自分で作る必要がある ([#723](https://github.com/mokume-metal/mokume/issues/723))。
/// `constrain()` は原典が自前で持っているので、そのまま写している。
final class Scrollbar: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Scrollbar")

    private var firstMousePress = false
    private var wasPressed = false
    private var hs1: HScrollbar?
    private var hs2: HScrollbar?
    private var img1: Image?
    private var img2: Image?

    final class HScrollbar {
        let swidth: Float
        let sheight: Float
        let xpos: Float
        let ypos: Float
        var spos: Float
        var newspos: Float
        let sposMin: Float
        let sposMax: Float
        let loose: Float
        var over = false
        var locked = false
        let ratio: Float

        init(_ xp: Float, _ yp: Float, _ sw: Float, _ sh: Float, _ l: Float) {
            swidth = sw
            sheight = sh
            let widthtoheight = sw - sh
            ratio = sw / widthtoheight
            xpos = xp
            ypos = yp - sh / 2
            spos = xp + sw / 2 - sh / 2
            newspos = spos
            sposMin = xp
            sposMax = xp + sw - sh
            loose = l
        }

        func update(on sketch: any Sketch, firstMousePress: Bool) {
            over = overEvent(on: sketch)
            if firstMousePress && over { locked = true }
            if !sketch.isMousePressed { locked = false }
            if locked {
                newspos = min(max(sketch.mouseX - sheight / 2, sposMin), sposMax)
            }
            if abs(newspos - spos) > 1 {
                spos = spos + (newspos - spos) / loose
            }
        }

        private func overEvent(on sketch: any Sketch) -> Bool {
            sketch.mouseX > xpos && sketch.mouseX < xpos + swidth
                && sketch.mouseY > ypos && sketch.mouseY < ypos + sheight
        }

        func display(on sketch: any Sketch) {
            sketch.noStroke()
            sketch.fill(204)
            sketch.rect(xpos, ypos, swidth, sheight)
            sketch.fill(over || locked ? color(0, 0, 0) : color(102, 102, 102))
            sketch.rect(spos, ypos, sheight, sheight)
        }

        /// spos を 0 から帯の幅までの値へ直す
        func getPos() -> Float { spos * ratio }
    }

    func setup() {
        noStroke()
        hs1 = HScrollbar(0, height / 2 - 8, width, 16, 16)
        hs2 = HScrollbar(0, height / 2 + 8, width, 16, 16)
        img1 = try? loadImage(asset("Topics/GUI/Scrollbar", "seedTop.jpg"))
        img2 = try? loadImage(asset("Topics/GUI/Scrollbar", "seedBottom.jpg"))
    }

    func draw() {
        // 原典は `mousePressed()` で立てる印。**出来事の口が無い**ので自分で作る
        firstMousePress = isMousePressed && !wasPressed
        wasPressed = isMousePressed

        background(255)
        guard let hs1, let hs2 else { return }
        let img1Pos = hs1.getPos() - width / 2
        fill(255)
        if let img1 { image(img1, width / 2 - Float(img1.width) / 2 + img1Pos * 1.5, 0) }
        let img2Pos = hs2.getPos() - width / 2
        fill(255)
        if let img2 { image(img2, width / 2 - Float(img2.width) / 2 + img2Pos * 1.5, height / 2) }
        hs1.update(on: self, firstMousePress: firstMousePress)
        hs2.update(on: self, firstMousePress: firstMousePress)
        hs1.display(on: self)
        hs2.display(on: self)
        stroke(0)
        line(0, height / 2, width, height / 2)
    }
}
