import mokume

/// Processing の [Convolution](https://processing.org/examples/convolution/) を 1 行ずつ移したもの。
///
/// **台帳は `blocked` と言った。半分だけ — 絵は出る。**
/// 止まるのは **`mousePressed()` / `mouseMoved()` / `mouseDragged()` から `redraw()` を
/// 呼ぶところ** ([#723](https://github.com/mokume-metal/mokume/issues/723))。
/// 押して効き目を切り替える主題が落ち、最初の 1 つ (Identity) のまま動かない。
/// 画素の読み書きは `Blur` と同じで、1 次元の並びが無く、色の空間を戻す必要がある。
final class Convolution: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Convolution")

    private var img: Image?
    private var effect = 0
    private let w = 120

    private let kernels: [[[Float]]] = [
        [[0, 0, 0], [0, 1, 0], [0, 0, 0]],                        // そのまま
        [[0, 0, 0], [0, 0.5, 0], [0, 0, 0]],                      // 暗く
        [[0, 0, 0], [0, 2, 0], [0, 0, 0]],                        // 明るく
        [[0, -1, 0], [-1, 5, -1], [0, -1, 0]],                    // 鋭く
        [[-1, -1, -1], [-1, 9, -1], [-1, -1, -1]],                // もっと鋭く
        [[1.0 / 9, 1.0 / 9, 1.0 / 9], [1.0 / 9, 1.0 / 9, 1.0 / 9], [1.0 / 9, 1.0 / 9, 1.0 / 9]],
        [[0, 1, 0], [1, -4, 1], [0, 1, 0]],                       // 縁を出す
        [[-2, -1, 0], [-1, 1, 1], [0, 1, 2]],                     // 浮き出し
    ]
    private let effectNames = [
        "Identity (no change)", "Darken", "Lighten", "Sharpen",
        "Sharpen More", "Box Blur", "Edge Detect", "Emboss",
    ]

    func setup() {
        img = try? loadImage(asset("Topics/Image Processing/Convolution", "moon-wide.jpg"))
        // 原典はここで `noLoop()` を呼ぶ。**書けない**
    }

    // 原典はここに mousePressed / mouseMoved / mouseDragged を持ち、redraw() を呼ぶ。
    // **どの口も無い**ので、効き目の切り替えが落ちる

    func draw() {
        guard let img else { return }
        // 一部分だけを処理するので、まず絵ぜんぶを背景として置く
        image(img, 0, 0)
        let xstart = Int(constrain(mouseX - Float(w) / 2, 0, Float(img.width)))
        let ystart = Int(constrain(mouseY - Float(w) / 2, 0, Float(img.height)))
        let xend = Int(constrain(mouseX + Float(w) / 2, 0, Float(img.width)))
        let yend = Int(constrain(mouseY + Float(w) / 2, 0, Float(img.height)))
        let matrixsize = 3
        loadPixels()
        for x in xstart..<max(xstart, xend) {
            for y in ystart..<max(ystart, yend) {
                pixels[x, y] = convolution(x, y, kernels[effect], matrixsize, img)
            }
        }
        // 原典はここで `updatePixels()` を呼ぶ。**書けない**
        textSize(24)
        text(effectNames[effect], 4, 24)
    }

    private func convolution(_ x: Int, _ y: Int, _ matrix: [[Float]],
                             _ matrixsize: Int, _ img: Image) -> LinearRGBA {
        var rtotal: Float = 0
        var gtotal: Float = 0
        var btotal: Float = 0
        let offset = matrixsize / 2
        for i in 0..<matrixsize {
            for j in 0..<matrixsize {
                let xloc = min(max(x + i - offset, 0), img.width - 1)
                let yloc = min(max(y + j - offset, 0), img.height - 1)
                let pixel = img.get(xloc, yloc)
                rtotal += red(pixel) * matrix[i][j]
                gtotal += green(pixel) * matrix[i][j]
                btotal += blue(pixel) * matrix[i][j]
            }
        }
        return color(constrain(rtotal, 0, 255), constrain(gtotal, 0, 255), constrain(btotal, 0, 255))
    }
}
