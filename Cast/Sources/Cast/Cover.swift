import Foundation
import simd

/// 影が狙いをどれだけ埋めたかを、立ち上げに 1 度だけ数える。
///
/// ## 塗らずに、逆から引く
///
/// 影を描いて重ねるのではなく、**狙いの上の点から光を逆にたどる**。床の点 `q` が
/// 姿勢 `j` で影になるのは、
///
/// ```text
/// ∃u :  f( R_j⁻¹(q − κu·e),  u,  ⋯ ) ≤ 0
/// ```
///
/// を満たすとき。`u` を細かく刻んで `f` (``Carve/value(_:turns:)``) を引くだけなので、
/// **測る側は塊の網 (``Surface``) を通らない**。網は 0 面の近似で、誤差はセルの半分より
/// 小さい — つまりここで出る数は**理想の塊の数**で、絵に出ている塊はその近似である。
///
/// ## はみ出しは 0 でなければならない
///
/// `f ≤ 0` は「3 つの姿勢のどれで落としても狙いの内側」なので、狙いの外の点が影に
/// なることは定義から起きない。**0 でなければ写像か距離の式が間違っている** —
/// これは被覆の測りであると同時に、彫り出しの検算である。
enum Cover {
    struct Result {
        var kind: Targets.Kind
        var covered: Float
        var spill: Float
    }

    /// 床へ敷く格子は 256 × 256 (1 画素 2.6 単位)。**細かくしても数は 0.2% しか動かず**、
    /// debug の立ち上げだけが伸びる。
    static func measure(_ lattice: Lattice, turns: [Float], grid: Int = 256) -> [Result] {
        let span = 2.6 * Field.unit
        let pixel = span / Float(grid)
        var results: [Result] = []

        for pose in 0..<3 {
            let kind = Targets.order[pose]
            let c = cos(turns[pose]), s = sin(turns[pose])
            var inside = 0, hit = 0, spill = 0

            for gy in 0..<grid {
                let qy = -span / 2 + (Float(gy) + 0.5) * pixel
                for gx in 0..<grid {
                    let qx = -span / 2 + (Float(gx) + 0.5) * pixel
                    let distance = Targets.distance(kind, SIMD2(qx, qy))
                    // 狙いの近くだけ引く (遠くは当たらないと分かっている)
                    if distance > Field.unit / 2 { continue }

                    // **線に沿った `f` は下に凸**なので、刻んで舐めずに谷を挟み撃ちにする
                    // (塊は凸な柱 3 本と板の共通部分で、`f` は凸な関数の最大値である)。
                    // 舐めると刻みの数だけ距離を引くことになり、debug では立ち上げが
                    // 分単位になる
                    func depth(_ u: Float) -> Float {
                        let vx = qx - Field.kappa * u
                        return Carve.value(
                            SIMD3<Float>(vx * c - qy * s, u, vx * s + qy * c), turns: turns)
                    }
                    var low = -Field.height / 2, high = Field.height / 2
                    var shadowed = depth(low) <= 0 || depth(high) <= 0
                    if !shadowed {
                        for _ in 0..<34 {
                            let a = low + (high - low) / 3, b = high - (high - low) / 3
                            let fa = depth(a), fb = depth(b)
                            if min(fa, fb) <= 0 {
                                shadowed = true
                                break
                            }
                            if fa < fb { high = b } else { low = a }
                        }
                    }

                    if distance <= 0 {
                        inside += 1
                        if shadowed { hit += 1 }
                    } else {
                        // **縁の 1 画素は量子化の誤差として見逃す。** 狙いの境目に
                        // 載った画素は、中心が外でも塊の側から見れば内側でありうる
                        if shadowed, distance > pixel { spill += 1 }
                    }
                }
            }
            results.append(
                Result(
                    kind: kind,
                    covered: Float(hit) / Float(max(inside, 1)),
                    spill: Float(spill) / Float(max(inside, 1))))
        }
        return results
    }
}
