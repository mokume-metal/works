import mokume

/// Processing の [Edge Detection](https://processing.org/examples/edgedetection/) を 1 行ずつ移したもの。
///
/// **台帳は `blocked` と言った。半分だけ — 絵は出る。** 止まるのは 3 つ:
/// `img.copy()` (絵を複製する口が無い)、`filter(GRAY)` (組み込みの効き目が無い)、
/// `updatePixels()`。**灰色にするところは自分で書けば済む**ので、絵は出る。
final class EdgeDetection: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Edge Detection")

    private let kernel: [[Float]] = [[-1, -1, -1], [-1, 8, -1], [-1, -1, -1]]
    private var img: Image?

    func setup() {
        img = try? loadImage(asset("Topics/Image Processing/EdgeDetection", "moon.jpg"))
        // 原典はここで `noLoop()` を呼ぶ。**書けない**
    }

    func draw() {
        guard let img else { return }
        image(img, 0, 0)

        // 縁の検出は灰色の絵に対して行う。原典は `img.copy()` と `filter(GRAY)` の
        // 2 行だが、**複製する口も組み込みの効き目も無い**ので自分で書く
        guard let grayImg = try? createImage(img.width, img.height) else { return }
        for y in 0..<img.height {
            for x in 0..<img.width {
                grayImg.set(x, y, gray(brightness(img.get(x, y))))
            }
        }

        guard let edgeImg = try? createImage(grayImg.width, grayImg.height) else { return }
        for y in 1..<(grayImg.height - 1) {
            for x in 1..<(grayImg.width - 1) {
                // 出力は 50% の灰色からのずれとして見せる (暗→明の移り変わりを残すため)
                var sum: Float = 128
                for ky in -1...1 {
                    for kx in -1...1 {
                        // 灰色なので赤も緑も青も同じ値
                        sum += kernel[ky + 1][kx + 1] * blue(grayImg.get(x + kx, y + ky))
                    }
                }
                edgeImg.set(x, y, gray(sum))
            }
        }
        // 原典はここで `edgeImg.updatePixels()` を呼ぶ。**書けない**
        image(edgeImg, width / 2, 0)
    }
}
