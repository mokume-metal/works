import mokume
import Support

/// Processing の [Convolution](https://processing.org/examples/convolution/) を 1 行ずつ移したもの。
///
/// **台帳は `blocked` と言い、`v0.5.0` では主題が落ちていた。`v0.6.0` で動く。**
/// `mousePressed()` / `mouseMoved()` / `mouseDragged()` の口が入ったので
/// ([#723](https://github.com/mokume-metal/mokume/issues/723) — 閉じた)、押して効き目を
/// 切り替えられる。
///
/// **`redraw()` はまだ無い** ([#900](https://github.com/mokume-metal/mokume/issues/900))。
/// 原典は `noLoop()` で止めておいて出来事のたびに `redraw()` するが、こちらは止まらないので
/// 毎フレーム描き直している — **結果は同じで、無駄が多い形になる。**
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

    /// 原典の `void mousePressed()` — 押すたびに次の効き目へ送る。
    func mousePressed() {
        effect += 1
        if effect >= effectNames.count { effect = 0 }
        // 原典はここで `redraw()` を呼ぶ。**書けない**が、止まっていないので次の
        // フレームで描き直される
    }

    // 原典は `mouseMoved()` / `mouseDragged()` も持つが、どちらも `redraw()` を呼ぶだけ。
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
