import Foundation
import simd

/// 距離の 0 面から、三角形の並びを切り出す。
///
/// **セルの箱を積まない。** 節に並んだ `f` (``Carve``) の符号が変わる辺を見つけ、
/// 変わり目の位置を線で補って結ぶ (surface nets)。セルごとに頂点を 1 つ置き、符号が
/// 変わる辺のまわりの 4 つのセルを四角で結ぶだけなので、表も短い。
///
/// 箱を積むやり方 (Quarry の `Mesher`) と比べて、この作品にとって大事なのは
/// **縁が階段にならない**ことである。塊の階段はそのまま影の階段になり、影が主題の
/// 作品では狙いの図形の輪郭が段々になって出てしまう。
///
/// 法線は `f` の傾きから取る。**面ごとではなく節ごとに向きが決まる**ので、光の当たり方が
/// 連続に変わり、細かい面がモアレにならない。
enum Surface {
    struct Corner {
        var position: SIMD3<Float>
        var normal: SIMD3<Float>
    }

    /// 切り出す。返すのは `三角形 × 3` 個の頂点。
    static func mesh(_ lattice: Lattice, turns: [Float]) -> (corners: [Corner], faces: Int) {
        let columns = lattice.columns
        let layers = lattice.layers
        var vertexOf = [Int](repeating: -1, count: columns * columns * layers)
        var places: [SIMD3<Float>] = []
        var slopes: [SIMD3<Float>] = []
        places.reserveCapacity(1 << 16)
        slopes.reserveCapacity(1 << 16)
        let step = lattice.cell * 0.5

        // セルの中で符号が変わる辺の交わりを平均して、セルに 1 つ頂点を置く
        let edges: [(Int, Int)] = [
            (0, 1), (2, 3), (4, 5), (6, 7),  // z 方向
            (0, 2), (1, 3), (4, 6), (5, 7),  // x 方向
            (0, 4), (1, 5), (2, 6), (3, 7),  // y 方向
        ]
        for j in 0..<layers {
            for i in 0..<columns {
                for k in 0..<columns {
                    // **節の値は 8 つの変数で持つ。** 配列を作ると 370 万セルぶんの
                    // 確保になり、debug では焼きの時間の大半がそこへ消える
                    var values = SIMD8<Float>()
                    var negative = 0
                    for corner in 0..<8 {
                        let di = (corner >> 1) & 1, dj = (corner >> 2) & 1, dk = corner & 1
                        let value = lattice.node(i + di, j + dj, k + dk)
                        values[corner] = value
                        if value <= 0 { negative += 1 }
                    }
                    guard negative > 0, negative < 8 else { continue }

                    var sum = SIMD3<Float>.zero
                    var count: Float = 0
                    for (a, b) in edges {
                        let va = values[a], vb = values[b]
                        guard (va <= 0) != (vb <= 0) else { continue }
                        let t = va / (va - vb)
                        let pa = lattice.position(
                            i + ((a >> 1) & 1), j + ((a >> 2) & 1), k + (a & 1))
                        let pb = lattice.position(
                            i + ((b >> 1) & 1), j + ((b >> 2) & 1), k + (b & 1))
                        sum += pa + (pb - pa) * t
                        count += 1
                    }
                    guard count > 0 else { continue }
                    vertexOf[(j * columns + i) * columns + k] = places.count
                    let place = sum / count
                    places.append(place)
                    // **向きは頂点につき 1 度だけ取る。** 面ごとに取り直すと、同じ点の
                    // 傾きを最大 6 回引くことになる
                    slopes.append(slope(at: place, turns: turns, step: step))
                }
            }
        }

        // 節の辺で符号が変わるところに、まわりの 4 つのセルの頂点で四角を張る
        var corners: [Corner] = []
        corners.reserveCapacity(places.count * 6)
        var faces = 0

        func vertex(_ i: Int, _ j: Int, _ k: Int) -> Int? {
            guard i >= 0, i < columns, j >= 0, j < layers, k >= 0, k < columns else { return nil }
            let index = vertexOf[(j * columns + i) * columns + k]
            return index >= 0 ? index : nil
        }

        func quad(_ a: Int, _ b: Int, _ c: Int, _ d: Int, flip: Bool) {
            let order = flip ? (a, c, b, a, d, c) : (a, b, c, a, c, d)
            for index in [order.0, order.1, order.2, order.3, order.4, order.5] {
                corners.append(Corner(position: places[index], normal: slopes[index]))
            }
            faces += 2
        }

        for j in 0...layers {
            for i in 0...columns {
                for k in 0...columns {
                    let here = lattice.node(i, j, k) <= 0
                    // x 方向の辺
                    if i < columns, j > 0, k > 0, (lattice.node(i + 1, j, k) <= 0) != here,
                        let a = vertex(i, j - 1, k - 1), let b = vertex(i, j - 1, k),
                        let c = vertex(i, j, k), let d = vertex(i, j, k - 1)
                    {
                        quad(a, b, c, d, flip: here)
                    }
                    // y 方向の辺
                    if j < layers, i > 0, k > 0, (lattice.node(i, j + 1, k) <= 0) != here,
                        let a = vertex(i - 1, j, k - 1), let b = vertex(i, j, k - 1),
                        let c = vertex(i, j, k), let d = vertex(i - 1, j, k)
                    {
                        quad(a, b, c, d, flip: here)
                    }
                    // z 方向の辺
                    if k < columns, i > 0, j > 0, (lattice.node(i, j, k + 1) <= 0) != here,
                        let a = vertex(i - 1, j - 1, k), let b = vertex(i - 1, j, k),
                        let c = vertex(i, j, k), let d = vertex(i, j - 1, k)
                    {
                        quad(a, b, c, d, flip: here)
                    }
                }
            }
        }
        return (corners, faces)
    }

    /// `f` の傾き = 面の向き。**中心差分で取る** — `f` は解析的に書けるので、節の値を
    /// 補間するより素直である。
    static func slope(at point: SIMD3<Float>, turns: [Float], step: Float) -> SIMD3<Float> {
        let dx =
            Carve.value(point + SIMD3(step, 0, 0), turns: turns)
            - Carve.value(point - SIMD3(step, 0, 0), turns: turns)
        let dy =
            Carve.value(point + SIMD3(0, step, 0), turns: turns)
            - Carve.value(point - SIMD3(0, step, 0), turns: turns)
        let dz =
            Carve.value(point + SIMD3(0, 0, step), turns: turns)
            - Carve.value(point - SIMD3(0, 0, step), turns: turns)
        let slope = SIMD3<Float>(dx, dy, dz)
        let size = length(slope)
        return size > 0 ? slope / size : SIMD3<Float>(0, 1, 0)
    }
}
