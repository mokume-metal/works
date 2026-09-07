import Foundation
import mokume
import simd

// 追った結果を絵にする面。**幾何はここで作らない** — `Tracer` が返したものを開くだけ。
extension Prism {

    /// 束の断面を刻む数。**両端を含む。**
    ///
    /// 7 点で 6 区画。端の重みが 0 に落ちるので、帯の縁は描いた図形の輪郭ではなく
    /// **明るさの勾配**として消える — これが「レーザーの線が並んでいる」ようには
    /// 見えないことの実体である。
    ///
    /// **5 点では足りなかった。** 刻みのあいだは直線で結ばれるので、芯のまわりが
    /// 平らな高原になり、束が板に見えていた
    static let across = 7

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

                // **端は面に沿って切る** (`Band.capA` / `capB`)。垂直に切ると、
                // 折れているのが面の上だと読めなくなる
                let a0 = band.a + band.capA * o0
                let a1 = band.a + band.capA * o1
                let b0 = band.b + band.capB * o0
                let b1 = band.b + band.capB * o1

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

    // MARK: - 面に落ちた足跡

    /// 足跡の塊を何角形で開くか。
    static let rim = 6
    /// 足跡の面から浮く厚み (画素)。
    static let spotThickness: Float = 7

    /// 光が面を横切った跡。
    ///
    /// **これが「四角が 2 つ並んでいる」ように見えないことの実体である。** 区間の
    /// 端どうしが宙で突き合わさっているだけだと、折れているのが面の上だと読めない。
    /// 足跡を面に貼ると、帯が面に刺さって向きを変えたように見える。
    ///
    /// 足跡は**波長ごと**に置くので、入口では全波長が重なって白い筋になり、
    /// **出口では 8〜13 画素ずれて小さな虹の筋になる** — 硝子の中で分かれていたことが、
    /// 出た瞬間ではなく面の上で読める
    func drawSpots(_ spots: [Spot]) {
        guard !spots.isEmpty else { return }
        noStroke()
        beginShape(.triangles)
        for spot in spots {
            blob(
                at: spot.point, along: spot.along, halfLength: spot.halfLength,
                thickness: Self.spotThickness, color: spot.color)
        }
        endShape()
    }

    /// 面に貼り付いた小さな塊の頂点を積む。
    ///
    /// **呼ぶ側が `beginShape(.triangles)` を開いている前提。** 足跡は 1 フレームに
    /// 数百個できるので、1 個ずつ図形を開くと描画の呼び出しがそのぶん増える
    private func blob(
        at center: SIMD2<Float>, along: SIMD2<Float>, halfLength: Float, thickness: Float,
        color: SIMD3<Float>
    ) {
        let normal = SIMD2(-along.y, along.x)
        for i in 0..<Self.rim {
            let a0 = Float(i) / Float(Self.rim) * 2 * .pi
            let a1 = Float(i + 1) / Float(Self.rim) * 2 * .pi
            place(center, color)
            place(center + along * (cos(a0) * halfLength) + normal * (sin(a0) * thickness), .zero)
            place(center + along * (cos(a1) * halfLength) + normal * (sin(a1) * thickness), .zero)
        }
    }

    // MARK: - 硝子

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
            // **青くしない。** 硝子を青く塗ると、いちばん見せたい紫の縁が地の色に
            // 紛れて読めなくなる (実測で内側の r−b は地が −33、紫の縁が −38 だった)。
            // わずかに冷たい灰なら、赤の縁も紫の縁も両方が地から離れる
            fill(LinearRGBA.display(red: 0.50, green: 0.53, blue: 0.585, alpha: alpha))
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

    // MARK: - 光源

    /// 光源そのもの — 胴・唇・口・にじみ。
    ///
    /// **どこから来ているかが分かると、入射角をいじる手が止まらなくなる。** 束の
    /// 出どころに何も無いと、光が宙で唐突に始まって切り口が見える。ここでは絞った
    /// 口を持つ灯りとして描き、**胴で束の切り口を覆う**。
    ///
    /// - Parameters:
    ///   - toward: 狙っている向き (単位ベクトル)。灯りはこれに合わせて向きを変える。
    ///   - halfWidth: 束の半分の幅。**口の大きさがそのまま束の幅になる。**
    func drawLamp(at source: SIMD2<Float>, toward: SIMD2<Float>, halfWidth: Float) {
        let across = SIMD2(-toward.y, toward.x)

        // にじみ — **入れ子の扇を 4 枚重ねる。** 扇 1 枚は中心から縁まで直線に落ちるので、
        // 大きく取るとただの灰色の円錐になる。細い山を積むと灯りの滲みの形になる
        blendMode(.add)
        noStroke()
        let eye = source + toward * 2
        halo(at: eye, radius: 20, tone: 0.42)
        halo(at: eye, radius: 38, tone: 0.20)
        halo(at: eye, radius: 66, tone: 0.085)
        halo(at: eye, radius: 108, tone: 0.030)
        // いちばん外は薄く広く。**縁が円として見えないところまで伸ばす**
        halo(at: eye, radius: 168, tone: 0.011)

        // 胴 — **`.blend` の暗い胴で自分の滲みを遮る。** 灯りが自分の光を隠すので、
        // 口の前だけが明るくなり、絞った灯りに見える (加算だと胴が透けて灰色の斑になる)
        blendMode(.blend)
        // (口からの距離, 半分の幅, 明るさ)
        let body: [(Float, Float, Float)] = [
            (-2, halfWidth + 17, 0.085),
            (-30, halfWidth + 21, 0.055),
            (-80, halfWidth + 11, 0.032),
            (-99, halfWidth + 3, 0.022),
        ]
        beginShape(.polygon)
        for (along, half, tone) in body { bodyVertex(source, toward, across, along, half, tone) }
        for (along, half, tone) in body.reversed() {
            bodyVertex(source, toward, across, along, -half, tone)
        }
        endShape(.close)

        // 唇 — 胴の前面。口の際で金属が光る。**進む向きへ倒さない** (光を遮って見える)
        stroke(LinearRGBA.display(red: 0.56, green: 0.58, blue: 0.63, alpha: 1))
        strokeWeight(6)
        strokeCap(.round)
        for side in [Float(1), Float(-1)] {
            let root = source + across * (halfWidth * side) - toward * 3
            let tip = source + across * ((halfWidth + 16) * side) - toward * 5
            line(root.x, root.y, tip.x, tip.y)
        }

        // 口 — 束の幅ぶんの白熱した芯。ここから帯が出ていく
        blendMode(.add)
        noStroke()
        beginShape(.triangles)
        blob(
            at: source, along: across, halfLength: halfWidth, thickness: 11,
            color: SIMD3(0.90, 0.88, 0.84))
        endShape()
    }

    /// 胴の頂点を 1 つ置く。
    private func bodyVertex(
        _ source: SIMD2<Float>, _ toward: SIMD2<Float>, _ across: SIMD2<Float>,
        _ along: Float, _ half: Float, _ tone: Float
    ) {
        // わずかに青を足すと、黒い胴でも金属に見える
        fill(LinearRGBA.display(red: tone, green: tone * 1.03, blue: tone * 1.16, alpha: 1))
        let point = source + toward * along + across * half
        vertex(point.x, point.y)
    }

    /// 灯りのまわりの滲み。**中心が明るく、縁で 0 に落ちる扇。**
    private func halo(at center: SIMD2<Float>, radius: Float, tone: Float) {
        let steps = 28
        beginShape(.triangleFan)
        place(center, SIMD3(tone, tone * 0.99, tone * 0.96))
        for i in 0...steps {
            let a = Float(i) / Float(steps) * 2 * .pi
            place(center + SIMD2(cos(a), sin(a)) * radius, .zero)
        }
        endShape()
    }

    // MARK: - 受け面

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
