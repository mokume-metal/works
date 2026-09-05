import mokume

/// Processing の [Width Height](https://processing.org/examples/widthheight/) を 1 行ずつ移したもの。
///
/// **台帳は `clean` と言った。当たっている** (色の書き下しを除く)。
/// `width` / `height` は mokume も同じ名前で持つ (型は `Float`)。
final class WidthHeight: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Width Height")

    func draw() {
        background(gray(127))
        noStroke()
        for i in stride(from: 0, to: Int(height), by: 20) {
            fill(rgb(129, 206, 15))
            rect(0, Float(i), width, 10)
            fill(gray(255))
            rect(Float(i), 0, 10, height)
        }
    }
}
