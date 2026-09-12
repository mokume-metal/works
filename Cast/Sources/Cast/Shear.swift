import Foundation
import simd

/// 床へ落とす写像。**この作品の芯の式が 3 行だけここにある。**
///
/// 向きを持つ光の下では、点の影は「高さに比例した平行移動」でしかない。仰角 φ・
/// 方位 e の光が進む向きを `w = (cos φ·e, −sin φ)` と書くと、高さ `Y` の点が床
/// (`Y = 0`) へ着くまでの道のりは `Y / sin φ` で、
///
/// ```text
/// 影 = (X, Z) + κ·Y·e        κ = cot φ
/// ```
///
/// **κ·Y の項は、塊をどれだけ回しても変わらない** — 回すのは縦軸まわりなので高さが
/// 動かないからである。だから 3 つの姿勢の影は「同じ 1 つのずれを受けた、向きだけ
/// 違う 3 枚」になる。ずれが 0 なら 3 枚は完全に同じ絵になり、**円と三角と四角を
/// 作り分けることが原理的にできない** (``Field/shear``)。
enum Shear {
    /// 影がずれていく向き (床の上の単位ベクトル)。光は +x へ進む。
    static let heading = SIMD2<Float>(1, 0)

    /// 世界の点 (y は上向き) を、光に沿って床へ落とす。
    static func drop(_ point: SIMD3<Float>) -> SIMD2<Float> {
        SIMD2<Float>(point.x, point.z) + Field.kappa * point.y * heading
    }

    /// 塊の中の点 (物体の座標) を、姿勢 `turn` で回してから床へ落とす。
    ///
    /// `u` は**塊の中心からの高さ**なので、`κ·u` がそのまま「中心の影からのずれ」に
    /// なる。中心の影は床の原点に置いてある (``Field/axis``)。
    static func drop(_ x: Float, _ u: Float, _ z: Float, turn: Float) -> SIMD2<Float> {
        let c = cos(turn), s = sin(turn)
        return SIMD2<Float>(x * c + z * s, -x * s + z * c) + Field.kappa * u * heading
    }

    /// mokume へ渡す光の向き。
    ///
    /// **縦軸は下向き**なので、上から差す光の y は正である
    /// (mokume の参照スケッチ `SolidsAndLight` と同じ約束)。
    static var lightDirection: SIMD3<Float> {
        let phi = Field.elevation * .pi / 180
        return SIMD3<Float>(cos(phi) * heading.x, sin(phi), cos(phi) * heading.y)
    }
}
