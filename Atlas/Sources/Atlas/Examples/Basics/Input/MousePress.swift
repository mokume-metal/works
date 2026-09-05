import mokume

/// Processing の [Mouse Press](https://processing.org/examples/mousepress/) を 1 行ずつ移したもの。
///
/// **台帳は `bend` と言った。当たっている。歪みが 2 つ。**
/// 原典の `mousePressed` は**変数**なので `isMousePressed` に名前が変わり
/// ([#723](https://github.com/mokume-metal/mokume/issues/723))、`noSmooth()` は書けない。
final class MousePress: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Mouse Press")

    func setup() {
        // 原典はここで `noSmooth()` を呼ぶ。**書けない**
        fill(126)
        background(102)
    }

    func draw() {
        if isMousePressed {
            stroke(255)
        } else {
            stroke(0)
        }
        line(mouseX - 66, mouseY, mouseX + 66, mouseY)
        line(mouseX, mouseY - 66, mouseX, mouseY + 66)
    }
}
