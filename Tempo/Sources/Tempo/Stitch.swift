import simd

/// 穴のある多角形を三角形へ畳む。
///
/// **辺の上に載った点を「含む」と数える。** ここだけが mokume の畳み方と違い、そして
/// 文字の輪郭ではここだけが効く — T の横棒の下辺には縦棒の角が載っていて、載った点を
/// 「含まない」と数えると、外へはみ出す三角形が耳として通ってしまう
/// ([mokume#1148](https://github.com/mokume-metal/mokume/issues/1148))。
///
/// **止まらないことを優先する。** 自己交差した周では正しい畳み方が存在しないので、
/// 耳が 1 つも見つからなければ、いちばん潰れた角を落として先へ進む。絵が少し欠けても
/// 描き続けるほうが、走っている作品では正しい。
enum Stitch {
    /// 潰れた角とみなす閾値 (面積の 2 倍)。
    private static let flat: Float = 1e-5

    /// 外周と穴から、塗るための三角形を作る。返るのは 3 つずつ 1 枚の頂点。
    static func triangulate(outer: [SIMD2<Float>], holes: [[SIMD2<Float>]]) -> [SIMD2<Float>] {
        guard outer.count >= 3 else { return [] }
        var ring = wound(outer, positive: true)
        for hole in holes where hole.count >= 3 {
            // **穴は外周と逆向きに回す。** 橋を架けて 1 周へ畳むと、向きが揃っていない
            // 穴は外周を裏返してしまう
            ring = bridge(ring: ring, hole: wound(hole, positive: false))
        }
        return earClip(ring)
    }

    /// 回る向きを揃える。
    private static func wound(_ points: [SIMD2<Float>], positive: Bool) -> [SIMD2<Float>] {
        (area(points) < 0) == positive ? Array(points.reversed()) : points
    }

    /// 符号付きの面積 (2 倍のまま)。
    private static func area(_ points: [SIMD2<Float>]) -> Float {
        var sum: Float = 0
        for index in points.indices {
            let a = points[index]
            let b = points[(index + 1) % points.count]
            sum += a.x * b.y - b.x * a.y
        }
        return sum
    }

    // MARK: - 穴を畳む

    /// 穴を外周へ橋で継いで、1 本の周にする。
    ///
    /// 穴のいちばん右の点から、**架けた線がどの辺も跨がない**外周の点を選んで継ぐ。
    /// 継いだ点は 2 度現れる — それが橋である。
    private static func bridge(ring: [SIMD2<Float>], hole: [SIMD2<Float>]) -> [SIMD2<Float>] {
        guard let entry = hole.indices.max(by: { hole[$0].x < hole[$1].x }) else { return ring }
        let from = hole[entry]

        var best: (index: Int, distance: Float)?
        for index in ring.indices {
            let candidate = ring[index]
            let delta = candidate - from
            let distance = dot(delta, delta)
            if let current = best, current.distance <= distance { continue }
            if crosses(ring: ring, hole: hole, from: from, to: candidate, skipping: index, entry: entry) {
                continue
            }
            best = (index, distance)
        }
        // 継げる点が無ければ穴を諦める。**外周は無傷のまま返す**
        guard let target = best?.index else { return ring }

        var joined = Array(ring[0...target])
        for step in 0...hole.count {
            joined.append(hole[(entry + step) % hole.count])
        }
        joined.append(ring[target])
        joined += ring[(target + 1)...]
        return joined
    }

    /// 架けた線が、外周か穴の辺を跨ぐか。
    private static func crosses(
        ring: [SIMD2<Float>], hole: [SIMD2<Float>], from: SIMD2<Float>, to: SIMD2<Float>,
        skipping target: Int, entry: Int
    ) -> Bool {
        for index in ring.indices {
            let next = (index + 1) % ring.count
            if index == target || next == target { continue }
            if intersects(from, to, ring[index], ring[next]) { return true }
        }
        for index in hole.indices {
            let next = (index + 1) % hole.count
            if index == entry || next == entry { continue }
            if intersects(from, to, hole[index], hole[next]) { return true }
        }
        return false
    }

    private static func intersects(
        _ a: SIMD2<Float>, _ b: SIMD2<Float>, _ c: SIMD2<Float>, _ d: SIMD2<Float>
    ) -> Bool {
        let d1 = cross(b - a, c - a)
        let d2 = cross(b - a, d - a)
        let d3 = cross(d - c, a - c)
        let d4 = cross(d - c, b - c)
        return ((d1 > 0) != (d2 > 0)) && ((d3 > 0) != (d4 > 0))
    }

    // MARK: - 耳を切る

    /// 1 本になった周を三角形へ切る。
    private static func earClip(_ points: [SIMD2<Float>]) -> [SIMD2<Float>] {
        guard points.count >= 3 else { return [] }
        var ring = Array(points.indices)
        var out: [SIMD2<Float>] = []

        while ring.count > 3 {
            var clipped = false
            for position in ring.indices where isEar(points, ring, position) {
                let previous = ring[(position + ring.count - 1) % ring.count]
                let current = ring[position]
                let next = ring[(position + 1) % ring.count]
                out += [points[previous], points[current], points[next]]
                ring.remove(at: position)
                clipped = true
                break
            }
            if clipped { continue }

            // 耳が 1 つも無い。**潰れた角から先に捨てる** — 橋の継ぎ目と、書体が
            // 持っている重なった点がここに来る
            let flattest = ring.indices.min { left, right in
                abs(turn(points, ring, left)) < abs(turn(points, ring, right))
            }
            guard let drop = flattest else { break }
            ring.remove(at: drop)
        }

        if ring.count == 3 {
            out += [points[ring[0]], points[ring[1]], points[ring[2]]]
        }
        return out
    }

    /// その角の曲がり (正なら出っ張り)。
    private static func turn(_ points: [SIMD2<Float>], _ ring: [Int], _ position: Int) -> Float {
        let a = points[ring[(position + ring.count - 1) % ring.count]]
        let b = points[ring[position]]
        let c = points[ring[(position + 1) % ring.count]]
        return cross(b - a, c - b)
    }

    /// 切ってよい角か。
    private static func isEar(_ points: [SIMD2<Float>], _ ring: [Int], _ position: Int) -> Bool {
        guard turn(points, ring, position) > flat else { return false }
        let a = points[ring[(position + ring.count - 1) % ring.count]]
        let b = points[ring[position]]
        let c = points[ring[(position + 1) % ring.count]]
        for (offset, index) in ring.enumerated() {
            let isCorner =
                offset == position || offset == (position + 1) % ring.count
                || offset == (position + ring.count - 1) % ring.count
            if isCorner { continue }
            let p = points[index]
            // **角と同じ場所にある点は見ない。** 橋の継ぎ目は同じ点が 2 度現れるので、
            // 見てしまうと永久に耳が見つからない
            if same(p, a) || same(p, b) || same(p, c) { continue }
            if inside(p, a, b, c) { return false }
        }
        return true
    }

    /// 三角形の中か。**辺の上も「中」とする。**
    private static func inside(
        _ p: SIMD2<Float>, _ a: SIMD2<Float>, _ b: SIMD2<Float>, _ c: SIMD2<Float>
    ) -> Bool {
        cross(b - a, p - a) >= -flat && cross(c - b, p - b) >= -flat
            && cross(a - c, p - c) >= -flat
    }

    private static func same(_ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Bool {
        let d = a - b
        return dot(d, d) < 1e-6
    }

    private static func cross(_ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Float {
        a.x * b.y - a.y * b.x
    }
}
