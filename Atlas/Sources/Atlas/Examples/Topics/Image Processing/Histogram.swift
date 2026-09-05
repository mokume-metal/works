import mokume

/// Processing の [Histogram](https://processing.org/examples/histogram/) を 1 行ずつ移したもの。
///
/// **台帳は `blocked` と言った。半分だけ — 絵は出る。**判定の根拠は `brightness()` に
/// 口が無いことだが、**成分は `LinearRGBA` から読めるので面の外で書ける** —
/// ただし mokume が持つのは線形の値なので、表示の値へ戻してから明度を取る必要がある
/// (`Support/Processing.swift`)。**同じ名前で違う空間の数を返す**ところが、
/// 名前しか見ない台帳には写らない。原典は静止形。
final class Histogram: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Histogram")

    func setup() {
        guard let img = try? loadImage(asset("Topics/Image Processing/Histogram", "frontier.jpg"))
        else { return }
        image(img, 0, 0)

        var hist = [Int](repeating: 0, count: 256)
        for i in 0..<img.width {
            for j in 0..<img.height {
                // 原典は `brightness(get(i, j))` — 面から引く。ここは絵から引く
                let bright = Int(brightness(img.get(i, j)))
                hist[min(max(bright, 0), 255)] += 1
            }
        }

        let histMax = hist.max() ?? 1
        stroke(gray(255))
        for i in stride(from: 0, to: img.width, by: 2) {
            // i (0〜img.width) を度数の位置 (0〜255) へ移す
            let which = Int(map(Float(i), 0, Float(img.width), 0, 255))
            // 度数を、絵の下端と上端のあいだの位置へ移す
            let y = map(Float(hist[which]), 0, Float(histMax), Float(img.height), 0)
            line(Float(i), Float(img.height), Float(i), y)
        }
    }
}
