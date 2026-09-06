import Foundation
import mokume
import simd

// 追った結果を絵にする面。**幾何はここで作らない** — `Tracer` が返したものを開くだけ。
extension Prism {

    /// 束の断面を刻む数。**両端を含む。**
    ///
    /// 5 点 (端・中間・芯・中間・端) で 4 区画。端の重みが 0 に落ちるので、帯の縁は
    /// 描いた図形の輪郭ではなく**明るさの勾配**として消える — これが「レーザーの線が
    /// 並んでいる」ようには見えないことの実体である
    static let across = 5

    /// 断面の重み `(1 − u²)^1.5`。
    ///
    /// 等強度 (矩形の断面) だと束が板に見える。端を落とすと、隣り合う波長の帯どうしが
    /// 裾で混ざるので、扇が連続した grading になる
    static func crossSection(_ index: Int) -> Float {
        let u = Float(index) / Float(across - 1) * 2 - 1
        return pow(max(1 - u * u, 0), 1.5)
    }

    /// 帯を三角形に開いて積む。
    ///
    /// **`beginShape(.triangles)` 1 本にまとめる。** 頂点ごとに `fill()` を変えられるので
    /// (Ring と同じ手)、幅方向のフェードも進むほど暗くなる勾配も頂点の色だけで出る。
    func drawBands(_ bands: [Band]) {
        noStroke()
        beginShape(.triangles)
        for band in bands {
            // 幅が 0 に潰れた帯は描かない (束が極端に圧縮された場面)
            guard band.halfWidth > 0.01 else { continue }
            for j in 0..<(Self.across - 1) {
                let w0 = Self.crossSection(j)
                let w1 = Self.crossSection(j + 1)
                let o0 = Self.offset(j) * band.halfWidth
                let o1 = Self.offset(j + 1) * band.halfWidth

                let a0 = band.a + band.across * o0
                let a1 = band.a + band.across * o1
                let b0 = band.b + band.across * o0
                let b1 = band.b + band.across * o1

                place(a0, band.colorA * w0)
                place(a1, band.colorA * w1)
                place(b1, band.colorB * w1)

                place(a0, band.colorA * w0)
                place(b1, band.colorB * w1)
                place(b0, band.colorB * w0)
            }
        }
        endShape()
    }

    /// 断面の位置 (−1…1)。
    private static func offset(_ index: Int) -> Float {
        Float(index) / Float(across - 1) * 2 - 1
    }

    /// 頂点を 1 つ置く。**色は成分に強度を入れて渡す** — `.add` の α は倍率ではなく
    /// 混ぜる重みなので、α で明るさを作ると重なりが積まれない。
    private func place(_ point: SIMD2<Float>, _ color: SIMD3<Float>) {
        fill(LinearRGBA.linear(red: color.x, green: color.y, blue: color.z))
        vertex(point.x, point.y)
    }

    /// 硝子そのもの。
    ///
    /// **加算ではなく `.blend` で置く。** 加算で薄く塗ると三角形の内側の黒が一様に
    ///持ち上がり、滲みの閾値が全面で発火して「光る三角形」になってしまう。
    /// 頂点ごとに濃さを変えて厚みの勾配を作ると、平らな三角形が硝子に見える
    func drawGlass(_ prism: [SIMD2<Float>]) {
        blendMode(.blend)
        noStroke()
        beginShape(.polygon)
        for (i, vertexPoint) in prism.enumerated() {
            // 先端は薄く、底の 2 点は濃く
            let alpha: Float = i == 0 ? 0.05 : 0.13
            fill(LinearRGBA.display(red: 0.42, green: 0.55, blue: 0.72, alpha: alpha))
            vertex(vertexPoint.x, vertexPoint.y)
        }
        endShape(.close)
    }

    /// 稜線。**加算で置く** — 背景を隠さず、光の帯とも喧嘩しない。
    func drawEdges(_ prism: [SIMD2<Float>]) {
        blendMode(.add)
        noFill()
        stroke(LinearRGBA.linear(red: 0.10, green: 0.13, blue: 0.18))
        strokeWeight(2)
        beginShape(.polygon)
        for vertexPoint in prism { vertex(vertexPoint.x, vertexPoint.y) }
        endShape(.close)
    }

    /// 全反射が起きた点。面の上で光っているように見せる。
    func drawHotspots(_ points: [SIMD2<Float>]) {
        guard !points.isEmpty else { return }
        // **1 波長ぶんの重みで置く。** 160 本ぶん重なるので、1 点あたりは薄くてよい
        stroke(LinearRGBA.linear(red: 0.020, green: 0.016, blue: 0.030))
        strokeWeight(9)
        strokeCap(.round)
        for spot in points { point(spot.x, spot.y) }
    }

    /// 受け面と、そこに落ちた虹。
    ///
    /// **真空の光は横から見えない。** 分かれたことが読めるのは面に落ちたときなので、
    /// この 1 枚が「プリズムを通した」ことを成立させている
    func drawScreen(_ bins: [SIMD3<Float>], a: SIMD2<Float>, b: SIMD2<Float>) {
        let span = b - a
        // 光は左から来るので、滲ませるのは面の手前側 (左) だけ
        let across = simd_normalize(SIMD2(-span.y, span.x)) * 34

        // **面そのものを先に置く。** 無いと虹が宙で終わって見え、何に落ちているのか
        // 読めない。加算では背景を持ち上げてしまうので `.blend` で暗く敷く
        blendMode(.blend)
        noStroke()
        fill(LinearRGBA.display(red: 0.10, green: 0.11, blue: 0.135, alpha: 1))
        quad(
            a.x, a.y, a.x - across.x * 0.34, a.y - across.y * 0.34,
            b.x - across.x * 0.34, b.y - across.y * 0.34, b.x, b.y)

        blendMode(.add)
        noStroke()
        beginShape(.triangleStrip)
        for (i, color) in bins.enumerated() {
            let t = Float(i) / Float(bins.count - 1)
            let point = a + span * t
            fill(LinearRGBA.linear(red: color.x, green: color.y, blue: color.z))
            vertex(point.x, point.y)
            // 面の向こう側は光らない。**片側だけ滲ませる**と壁に落ちた光に見える
            fill(LinearRGBA.linear(red: 0, green: 0, blue: 0))
            vertex(point.x + across.x, point.y + across.y)
        }
        endShape()
    }
}
