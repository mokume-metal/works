import mokume

/// Processing の [Embedded Links](https://processing.org/examples/embeddedlinks/) を 1 行ずつ移したもの。
///
/// **台帳は `out-of-scope` と言った (ブラウザ向けの出力が主題)。絵は出る。**
/// 止まるのは 2 つ — **`link()` でページを開く口が無い**のと、
/// `mousePressed()` / `mouseMoved()` / `mouseDragged()` の**出来事を受ける口が無い**
/// ([#723](https://github.com/mokume-metal/mokume/issues/723))。
/// 触れているかどうかを見る側は `draw()` の中でポーリングに書き直せるが、
/// **押して開くという例の主題そのものが移せない。**
final class EmbeddedLinks: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Embedded Links")

    private var overButton = false

    func draw() {
        background(gray(204))
        // 原典は `mouseMoved()` / `mouseDragged()` から `checkButtons()` を呼ぶ。
        // **出来事の口が無い**のでここで見る
        overButton = mouseX > 105 && mouseX < 180 && mouseY > 60 && mouseY < 135

        if overButton == true {
            fill(gray(255))
        } else {
            noFill()
        }
        rect(105, 60, 75, 75)
        line(135, 105, 155, 85)
        line(140, 85, 155, 85)
        line(155, 85, 155, 100)
    }

    // 原典はここに `void mousePressed()` を持ち、`link("http://www.processing.org")` を
    // 呼ぶ。**どちらの口も無い**
}
