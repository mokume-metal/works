import Foundation
import simd

/// 彫り出し — **塊は距離の関数で決まる。**
///
/// ```text
/// f(p) = max_j  d_j( σ_j(p) )          j = 0, 1, 2
/// 塊 = { p : f(p) ≤ 0 }
/// ```
///
/// `d_j` は姿勢 `j` で狙う図形の符号付きの距離 (``Targets``)、`σ_j` は姿勢 `j` で
/// 回してから床へ落とす写像 (``Shear``)。**3 つとも内側**という条件をそのまま
/// 「3 つの距離のうちいちばん大きいもの」として書いただけである。
///
/// ## はみ出しが構造上ゼロなのはここから出る
///
/// 塊の点はすべて `f ≤ 0` を満たす。`f ≤ 0` は「3 つの姿勢のどれで落としても狙いの
/// 内側」という意味なので、**影が狙いの外へ出ることは定義から起きない**。起こるのは
/// 欠けだけである。
///
/// ## 格子は形ではなく、標本の置き場
///
/// 格子の節に `f` を並べるが、面を切り出すのは ``Surface`` で、そこでは節と節の間を
/// 補間する。**セルの箱をそのまま積まない**ので、塊の縁も影の縁も階段にならない。
/// 刻みは「縁がどれだけ滑らかか」を決めるだけで、**被覆率には効かない** (被覆は
/// `f` そのもので測る・``Cover``)。
struct Lattice {
    /// 節に並べた `f` の値。
    var values: [Float]
    /// 水平・縦のセル数 (節はそれぞれ +1)。
    let columns: Int
    let layers: Int
    /// セルの一辺 (水平) と高さ。
    let cell: Float
    let cellHeight: Float
    /// 節が並ぶ範囲 (片側・中心から)。
    let extent: Float
    let half: Float

    func node(_ i: Int, _ j: Int, _ k: Int) -> Float {
        values[(j * (columns + 1) + i) * (columns + 1) + k]
    }

    /// 節の位置 (物体の座標・`y` は塊の中心からの高さ)。
    func position(_ i: Int, _ j: Int, _ k: Int) -> SIMD3<Float> {
        SIMD3<Float>(
            -extent + Float(i) * cell,
            -half + Float(j) * cellHeight,
            -extent + Float(k) * cell)
    }
}

enum Carve {
    /// 格子の外へ出る余白 (セル数)。**縁で面が閉じるように節を余らせる。**
    static let padding = 2

    /// 塊を決める距離。
    ///
    /// 縦は ``Field/height`` の板で切ってある — 切らないと塊が縦に伸び、`T = κ·h` で
    /// 決めた寸法の意味が崩れる。
    static func value(_ point: SIMD3<Float>, turns: [Float]) -> Float {
        var far = abs(point.y) - Field.height / 2
        for pose in 0..<3 {
            let q = Shear.drop(point.x, point.y, point.z, turn: turns[pose])
            far = max(far, Targets.distance(Targets.order[pose], q))
        }
        return far
    }

    /// 節へ `f` を並べる。
    static func lattice(turns: [Float]) -> Lattice {
        let columns = Field.grid + padding * 2
        let cell = 2 * Field.extent / Float(Field.grid)
        let layers = max(4, Int((Field.height / cell).rounded())) + padding * 2
        let cellHeight = cell
        let extent = Float(columns) * cell / 2
        let half = Float(layers) * cellHeight / 2

        var values = [Float](repeating: 0, count: (columns + 1) * (columns + 1) * (layers + 1))
        let spin = turns.map { (cos($0), sin($0)) }
        let kinds = Targets.order
        let limit = Field.height / 2

        for j in 0...layers {
            let u = -half + Float(j) * cellHeight
            let shift = Field.kappa * u
            let slab = abs(u) - limit
            for i in 0...columns {
                let x = -extent + Float(i) * cell
                for k in 0...columns {
                    let z = -extent + Float(k) * cell
                    var far = slab
                    for pose in 0..<3 {
                        let (c, s) = spin[pose]
                        let q = SIMD2<Float>(x * c + z * s + shift, -x * s + z * c)
                        far = max(far, Targets.distance(kinds[pose], q))
                    }
                    values[(j * (columns + 1) + i) * (columns + 1) + k] = far
                }
            }
        }

        return Lattice(
            values: values, columns: columns, layers: layers, cell: cell, cellHeight: cellHeight,
            extent: extent, half: half)
    }
}
