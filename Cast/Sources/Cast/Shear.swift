import Foundation
import simd

/// 床へ落とす写像。**この作品の芯の式が数行だけここにある。**
///
/// 向きを持つ光の下では、点の影は「高さに比例した平行移動」でしかない。仰角 φ・
/// 方位 α の光が進む向きを `w = (cos φ·e(α), −sin φ)` と書くと、高さ `Y` の点が床
/// (`Y = 0`) へ着くまでの道のりは `Y / sin φ` で、
///
/// ```text
/// 影 = (X, Z) + κ·Y·e(α)        κ = cot φ
/// ```
///
/// ここから、この作品の出来事が全部出る。
///
/// - **κ·Y の項は、塊を縦軸まわりに回しても変わらない** → 3 つの姿勢が同じ場所で
///   入れ替わる (幕 2)
/// - **`w` に沿って点を動かしても影は動かない** → 粒が光の筋に沿って空へ伸びても、
///   床の絵は 1 ミリも動かない (幕 3 前半)
/// - **水平に動かすと、影は同じだけ動く** → 群れごと横へ寄せれば影も同じだけ寄る
///
/// 逆に、**`w` のまわりに回しても影はきれいに回らない**。影への写像は光に直交する面から
/// 床への線形写像で、床が傾いているぶん一方向に伸びる — 相似ではないので、回転を挟むと
/// `A R A⁻¹` という「傾いた回転」になり、円は楕円へ潰れる。作ろうとした星の模様が
/// 角の丸い斑になって初めて気付いた (幕 3 でこの動きを使うのはやめた)。
/// - **`e` を α 回すことは、塊を α 回してから床の絵を α 回すことと同じ** →
///   塊を止めたまま光を回しても、3 つの形が出る (幕 4)
///
/// 最後の 1 つは式で書くとこうなる (影の中心 `c(α)` のまわりの回転):
///
/// ```text
/// 影(姿勢 θ, 方位 α) = c(α) + R_α[ 影(姿勢 θ+α, 方位 0) − c(0) ]
/// ```
///
/// **符号を間違えると、3 つのうち円だけが合って残り 2 つがずれる** (円は回しても
/// 円のままなので、方位 0 では気付けない)。手引きの輪郭が影とぴったり重なるかどうかが、
/// この式の検算になっている。
///
/// 真上から差す光 (φ = 90°) では κ = 0 になり、**どの姿勢でも影が同じになる** —
/// 作り分けは原理的にできない。この作品が斜めの光でしか成り立たない理由である。
enum Shear {
    /// **彫り出しの方位。** 塊はこの向きで焼いてあるので、ここは動かさない。
    static let design: Float = 0

    /// 方位 α の、影がずれていく向き (床の上の単位ベクトル)。
    static func heading(_ azimuth: Float) -> SIMD2<Float> {
        SIMD2<Float>(cos(azimuth), sin(azimuth))
    }

    /// 光が進む向き (世界・y は上向き)。
    static func travel(_ azimuth: Float) -> SIMD3<Float> {
        let phi = Field.elevation * .pi / 180
        let e = heading(azimuth)
        return SIMD3<Float>(cos(phi) * e.x, -sin(phi), cos(phi) * e.y)
    }

    /// mokume へ渡す光の向き。
    ///
    /// **縦軸は下向き**なので、上から差す光の y は正である
    /// (mokume の参照スケッチ `SolidsAndLight` と同じ約束)。
    static func lightDirection(_ azimuth: Float) -> SIMD3<Float> {
        let w = travel(azimuth)
        return SIMD3<Float>(w.x, -w.y, w.z)
    }

    /// 影の中心が床のどこへ来るか。**方位を回すと、塊の真下のまわりを円を描いて回る。**
    static func shadowCenter(_ azimuth: Float) -> SIMD2<Float> {
        Field.axis + Field.kappa * Field.centerHeight * heading(azimuth)
    }

    /// 世界の点 (y は上向き) を、光に沿って床へ落とす。
    static func drop(_ point: SIMD3<Float>, azimuth: Float = design) -> SIMD2<Float> {
        SIMD2<Float>(point.x, point.z) + Field.kappa * point.y * heading(azimuth)
    }

    /// 塊の中の点 (物体の座標) を、姿勢 `turn` で回してから床へ落とす。
    ///
    /// `u` は**塊の中心からの高さ**なので、`κ·u` がそのまま「中心の影からのずれ」に
    /// なる。**彫り出しと測りはこの口しか使わない** (方位は設計時のまま)。
    static func drop(_ x: Float, _ u: Float, _ z: Float, turn: Float) -> SIMD2<Float> {
        let c = cos(turn), s = sin(turn)
        let e = heading(design)
        return SIMD2<Float>(x * c + z * s, -x * s + z * c) + Field.kappa * u * e
    }
}
