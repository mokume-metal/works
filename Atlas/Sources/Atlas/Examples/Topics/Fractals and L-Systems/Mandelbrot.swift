import mokume

/// Processing の [Mandelbrot](https://processing.org/examples/mandelbrot/) を 1 行ずつ移したもの。
///
/// **台帳は `blocked` と言った。半分だけ — 絵は出る。**`noLoop()` と `updatePixels()`
/// が無く、面の `pixels` は 2 次元の添字を取る (原典は `pixels[i+j*width]`)。
/// `map()` も無いので面の外に書く。原典は静止形。
final class Mandelbrot: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Mandelbrot")

    func setup() {
        // 原典はここで `noLoop()` を呼ぶ。**書けない**
        background(gray(255))
        let w: Float = 4
        let h = (w * height) / width
        let xmin = -w / 2
        let ymin = -h / 2
        loadPixels()
        let maxiterations = 100
        let xmax = xmin + w
        let ymax = ymin + h
        let dx = (xmax - xmin) / width
        let dy = (ymax - ymin) / height
        var y = ymin
        for j in 0..<Int(height) {
            var x = xmin
            for i in 0..<Int(width) {
                // z = z^2 + c を繰り返して、無限へ向かうかどうかを見る
                var a = x
                var b = y
                var n = 0
                let maxValue: Float = 4.0   // ここでの無限は 4 とする
                var absOld: Float = 0.0
                var convergeNumber = Float(maxiterations)
                while n < maxiterations {
                    let aa = a * a
                    let bb = b * b
                    let abs = (aa + bb).squareRoot()
                    if abs > maxValue {
                        // どれだけ越えたかを測る
                        let diffToLast = abs - absOld
                        let diffToMax = maxValue - absOld
                        convergeNumber = Float(n) + diffToMax / diffToLast
                        break
                    }
                    let twoab = 2.0 * a * b
                    a = aa - bb + x
                    b = twoab + y
                    n += 1
                    absOld = abs
                }
                // 無限へ届くまでの長さで色を決める。届かなかったら黒
                if n == maxiterations {
                    pixels[i, j] = gray(0)
                } else {
                    let norm = map(convergeNumber, 0, Float(maxiterations), 0, 1)
                    pixels[i, j] = gray(map(norm.squareRoot(), 0, 1, 0, 255))
                }
                x += dx
            }
            y += dy
        }
        // 原典はここで `updatePixels()` を呼ぶ。**書けない**
    }
}
