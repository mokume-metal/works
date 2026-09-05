import mokume

/// Processing の [Brightness](https://processing.org/examples/brightness/) を 1 行ずつ移したもの。
/// 原典は Rusty Robison 作。
///
/// **台帳は `bend` と言った。当たっている。** `colorMode(HSB, width, 100, height)` の
/// 口が無いので、色相・彩度・明度から色を作る変換と、目盛りの畳み込みを書く側が背負う
/// (`Support/Processing.swift` の `hsb`)。**原典が見せたい「明度だけを動かす」ことは
/// 保てるが、1 行が 1 ファイルになる。**
///
/// マウスで塗る例なので、窓を持たない書き出しでは左端の 1 本だけが出る。
final class Brightness: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Brightness")

    private let barWidth: Float = 20
    private var lastBar: Float = -1

    func setup() {
        // 原典はここで `colorMode(HSB, width, 100, height)` を呼ぶ。**書けない**
        noStroke()
        background(gray(0))
    }

    func draw() {
        let whichBar = (mouseX / barWidth).rounded(.down)
        if whichBar != lastBar {
            let barX = whichBar * barWidth
            fill(hsb(barX, 100, mouseY, max: (width, 100, height)))
            rect(barX, 0, barWidth, height)
            lastBar = whichBar
        }
    }
}
