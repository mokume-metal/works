import mokume

/// Processing の [Handles](https://processing.org/examples/handles/) を 1 行ずつ移したもの。
///
/// **台帳は `bend` と言った。当たっている。ここで止まっている。**
/// 原典は `firstMousePress` — **押した最初の 1 フレームだけを真にする印**を
/// `mousePressed()` で立て、`mouseReleased()` で掴みを解く。mokume には出来事の口が
/// 無い ([#723](https://github.com/mokume-metal/mokume/issues/723))。
/// `isMousePressed` のポーリングから「押した瞬間」を作るには、**前のフレームの値を
/// 自分で覚えておく**しかない。原典が 1 行で言っていることを、こちらは状態で持つ。
final class Handles: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Handles")

    private var handles: [Handle] = []
    private var firstMousePress = false
    private var wasPressed = false

    final class Handle {
        let x: Float
        let y: Float
        var boxx: Float = 0
        var boxy: Float = 0
        var stretch: Float
        let size: Float
        var over = false
        var press = false
        var locked = false
        var otherslocked = false
        var others: [Handle] = []

        init(_ ix: Float, _ iy: Float, _ il: Float, _ isize: Float) {
            x = ix
            y = iy
            stretch = il
            size = isize
            boxx = x + stretch - size / 2
            boxy = y - size / 2
        }

        func update(on sketch: any Sketch, firstMousePress: Bool) {
            boxx = x + stretch
            boxy = y - size / 2
            otherslocked = others.contains { $0.locked }
            if otherslocked == false {
                over = overRect(on: sketch, boxx, boxy, size, size)
                if over && firstMousePress || locked {
                    press = true
                    locked = true
                } else {
                    press = false
                }
            }
            if press {
                stretch = min(max(sketch.mouseX - sketch.width / 2 - size / 2, 0),
                              sketch.width / 2 - size - 1)
            }
        }

        func releaseEvent() { locked = false }

        func display(on sketch: any Sketch) {
            sketch.line(x, y, x + stretch, y)
            sketch.fill(255)
            sketch.stroke(0)
            sketch.rect(boxx, boxy, size, size)
            if over || press {
                sketch.line(boxx, boxy, boxx + size, boxy + size)
                sketch.line(boxx, boxy + size, boxx + size, boxy)
            }
        }

        private func overRect(on sketch: any Sketch, _ x: Float, _ y: Float,
                              _ w: Float, _ h: Float) -> Bool {
            sketch.mouseX >= x && sketch.mouseX <= x + w
                && sketch.mouseY >= y && sketch.mouseY <= y + h
        }
    }

    func setup() {
        let num = Int(height) / 15
        let hsize: Float = 10
        handles = (0..<num).map {
            Handle(width / 2, 10 + Float($0) * 15, 50 - hsize / 2, 10)
        }
        for handle in handles { handle.others = handles }
    }

    func draw() {
        // 原典は `mousePressed()` / `mouseReleased()` で立てる印。**出来事の口が無い**ので、
        // 前のフレームの値と見比べて「押した瞬間」を自分で作る
        firstMousePress = isMousePressed && !wasPressed
        if !isMousePressed {
            for handle in handles { handle.releaseEvent() }
        }
        wasPressed = isMousePressed

        background(153)
        for handle in handles {
            handle.update(on: self, firstMousePress: firstMousePress)
            handle.display(on: self)
        }
        fill(0)
        rect(0, 0, width / 2, height)
    }
}
