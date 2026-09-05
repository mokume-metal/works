import mokume

/// Processing の [Keyboard](https://processing.org/examples/keyboard/) を 1 行ずつ移したもの。
///
/// **台帳は `bend` と言った。実際にはここで止まっている。**
/// 原典は `draw()` を空にしておき、**中身をすべて `keyPressed()` に書く**例である。
/// mokume にキーの出来事を受ける口が無く ([#723](https://github.com/mokume-metal/mokume/issues/723))、
/// あるのは `isKeyDown(_ code: Int)` のポーリングだけなので、
/// 「押した瞬間に 1 度描く」が「押している間ずっと描く」に変わってしまう。
///
/// **動くように書き替えていない** — 原典の形のまま、`draw()` は空で置く。
/// 面は背景の黒のままになる。それが「止まった」ということである。
final class Keyboard: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Keyboard")

    private var rectWidth: Float = 0

    func setup() {
        noStroke()
        background(gray(0))
        rectWidth = width / 4
    }

    func draw() {
        // 原典もここは空。キーを待つあいだ回し続けるためだけに置かれている
    }

    // 原典はここに `void keyPressed()` を持ち、押された文字で矩形を塗る。
    // **受ける口が無い**ので、この例の中身そのものが移せない。
    // `millis() % 255` で色を決める行も、面に壁時計が無い
}
