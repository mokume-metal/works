import Foundation
import simd

/// 狙いの図形 — 円・正三角形・正方形。
///
/// **3 つとも面積をそろえてある。** そろえないと、いちばん小さい図形が他の 2 つを
/// 削り落として被覆率を下げる。面積を `π r²` にそろえると寸法はこうなる:
///
/// | 図形 | 寸法 | 外接半径 | 内接半径 |
/// | --- | --- | --- | --- |
/// | 円 | `r` | `1.00 r` | `1.00 r` |
/// | 正三角形 | 一辺 `2.694 r` | `1.555 r` | `0.778 r` |
/// | 正方形 | 一辺 `1.772 r` | `1.253 r` | `0.886 r` |
///
/// **三角形の角は円より 1.55 倍遠い** — ここが欠けの主な出どころで、被覆率の上限を
/// 決めている。
///
/// 内外は**符号付きの距離**で返す。多角形の距離は角の外側では真の距離より小さく出るが、
/// 符号は厳密なので内外の判定には足り、余裕 (``Carve/margin``) を引く使い方でも
/// 安全側にしか外れない。**絵を持たない** — ラスタの型紙を持つと、刻みを変えるたびに
/// 型紙を焼き直すことになる。
enum Targets {
    enum Kind: Int, CaseIterable {
        case circle, triangle, square

        /// 名乗り。
        var name: String {
            switch self {
            case .circle: "CIRCLE"
            case .triangle: "TRIANGLE"
            case .square: "SQUARE"
            }
        }

        /// 記号。
        var mark: String {
            switch self {
            case .circle: "○"
            case .triangle: "△"
            case .square: "□"
            }
        }

        /// 床の上での向き (ラジアン)。
        var angle: Float {
            switch self {
            case .circle: 0
            case .triangle: Field.triangleAngle * .pi / 180
            case .square: Field.squareAngle * .pi / 180
            }
        }
    }

    /// 姿勢 0 / 1 / 2 に配る図形。
    static let order: [Kind] = [.circle, .triangle, .square]

    /// 符号付きの距離。内側が負。
    static func distance(_ kind: Kind, _ q: SIMD2<Float>) -> Float {
        let r = Field.unit
        switch kind {
        case .circle:
            return length(q) - r
        case .square:
            // 一辺 `r√π`。半辺は `r√π / 2`
            let half = r * (Float.pi).squareRoot() / 2
            let a = -kind.angle
            let u = SIMD2<Float>(q.x * cos(a) - q.y * sin(a), q.x * sin(a) + q.y * cos(a))
            return max(abs(u.x), abs(u.y)) - half
        case .triangle:
            // 面積 `π r²` の正三角形の内接半径
            let inradius = r * (Float.pi / (3 * (3 as Float).squareRoot() / 4)).squareRoot() / 2
            var far = -Float.greatestFiniteMagnitude
            for side in 0..<3 {
                let a = kind.angle + Float(side) * 2 * .pi / 3
                far = max(far, q.x * cos(a) + q.y * sin(a))
            }
            return far - inradius
        }
    }

    /// 輪郭の点の並び (床へ引く手引きに使う)。
    static func outline(_ kind: Kind, steps: Int = 96) -> [SIMD2<Float>] {
        let r = Field.unit
        switch kind {
        case .circle:
            return (0..<steps).map { step in
                let a = Float(step) / Float(steps) * 2 * .pi
                return SIMD2<Float>(cos(a) * r, sin(a) * r)
            }
        case .square:
            let half = r * (Float.pi).squareRoot() / 2
            let corners = [
                SIMD2<Float>(-half, -half), SIMD2(half, -half), SIMD2(half, half),
                SIMD2(-half, half),
            ]
            return corners.map { corner in
                let a = kind.angle
                return SIMD2<Float>(
                    corner.x * cos(a) - corner.y * sin(a), corner.x * sin(a) + corner.y * cos(a))
            }
        case .triangle:
            let inradius = r * (Float.pi / (3 * (3 as Float).squareRoot() / 4)).squareRoot() / 2
            let circumradius = inradius * 2
            return (0..<3).map { corner in
                // 外接半径の向きは、辺の法線から 60 度ずれる
                let a = kind.angle + Float(corner) * 2 * .pi / 3 + .pi / 3
                return SIMD2<Float>(cos(a) * circumradius, sin(a) * circumradius)
            }
        }
    }
}
