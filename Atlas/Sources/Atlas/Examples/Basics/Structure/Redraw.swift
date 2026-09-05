import mokume

/// Processing の [Redraw](https://processing.org/examples/redraw/) を 1 行ずつ移したもの。
///
/// **台帳は `blocked` と言った。当たっている。ここで止まっている。**
/// 原典の主題は「止めておいて、押すたびに 1 枚だけ描き直す」ことで、mokume には
/// `noLoop()` も `redraw()` も無い。止まらないので線が流れ続ける。
///
/// `Loop` / `NoLoop` と合わせて、**進行を握る 3 本がすべて同じ場所で止まる**。
final class Redraw: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Redraw")

    private var y: Float = 0

    func setup() {
        stroke(gray(255))
        // 原典はここで `noLoop()` を呼ぶ。**書けない**
        y = height * 0.5
    }

    func draw() {
        background(gray(0))
        y = y - 4
        if y < 0 { y = height }
        line(0, y, width, y)
    }

    // 原典は `void mousePressed() { redraw(); }` を持つ。**どちらも書けない**
}
