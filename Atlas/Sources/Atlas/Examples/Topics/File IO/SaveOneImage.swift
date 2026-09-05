import mokume

/// Processing の [Save One Image](https://processing.org/examples/saveoneimage/) を 1 行ずつ移したもの。
///
/// **台帳は `out-of-scope` と言った (ファイル入出力が主題)。絵は出る。**
/// 止まるのは `mousePressed()` の口が無いところ
/// ([#723](https://github.com/mokume-metal/mokume/issues/723))。押して書き出す、という
/// この例の主題そのものが移せない (`save()` は `save(_:)` で当たる)。
final class SaveOneImage: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Save One Image")

    func draw() {
        background(204)
        line(0, 0, mouseX, height)
        line(width, 0, 0, mouseY)
    }

    // 原典はここに `void mousePressed()` を持ち、`save("line.tif")` を呼ぶ。
    // **押した瞬間を受ける口が無い**ので、書き出す機会が来ない
}
