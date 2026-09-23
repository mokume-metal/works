import Foundation
import mokume
import simd

/// 空・遠景の地面・コース脇のもの。
///
/// **速さは、そばを流れるもので読む。** 路面に絵を貼らない作りなので (遠くで必ず
/// 滲む)、速度感は縁石の縞と、この木立と、視野角の広がりが担う
enum Scenery {
    /// 空。**上・地平・下の 3 色**だけで決まる。
    static let sky = Surroundings(
        top: LinearRGBA.display(red: 0.26, green: 0.44, blue: 0.76),
        horizon: LinearRGBA.display(red: 0.76, green: 0.84, blue: 0.92),
        bottom: LinearRGBA.display(red: 0.30, green: 0.36, blue: 0.30))

    /// 木を撒く間隔 (単位)。
    static let spacing: Float = 170
    /// 木を置ける横ずれの範囲 (単位)。**裾の内側に収める。**
    static let inner: Float = 190
    static let outer: Float = 420

    /// 遠景の地面。**1 枚の大きな四角**で、裾の外端と同じ高さに敷く。
    static func ground(centre: SIMD2<Float>, reach: Float) -> [Corner] {
        var corners: [Corner] = []
        let y = Road.groundLevel
        let colour = Palette.field * 0.82
        Solid.face(
            SIMD3(centre.x - reach, y, centre.y - reach),
            SIMD3(centre.x + reach, y, centre.y - reach),
            SIMD3(centre.x + reach, y, centre.y + reach),
            SIMD3(centre.x - reach, y, centre.y + reach),
            outward: SIMD3(0, 1, 0), colour: colour, into: &corners)
        return corners
    }

    /// 木 1 本。**幹と、上ほど小さい 3 段の葉。**
    static func tree() -> [Corner] {
        var corners: [Corner] = []
        Solid.box(
            at: SIMD3(0, 10, 0), size: SIMD3(5, 20, 5), colour: SIMD3(74, 56, 38),
            into: &corners)
        Solid.box(
            at: SIMD3(0, 28, 0), size: SIMD3(28, 18, 28), colour: SIMD3(44, 86, 42),
            into: &corners)
        Solid.box(
            at: SIMD3(0, 42, 0), size: SIMD3(21, 14, 21), colour: SIMD3(52, 96, 48),
            into: &corners)
        Solid.box(
            at: SIMD3(0, 53, 0), size: SIMD3(13, 10, 13), colour: SIMD3(60, 104, 54),
            into: &corners)
        return corners
    }

    /// 木の置き場所。
    ///
    /// **1 回の描画で全部置ける** (`shape(_:at:)`)。散らし方は雑音から引くので、
    /// 走るたびに同じ林になる
    ///
    /// - Parameter jitter: 0…1 の揺らぎ (雑音はスケッチの口なので外から渡す)
    static func trees(along track: Track, jitter: (Float, Float) -> Float) -> [Placement] {
        var places: [Placement] = []
        var s: Float = 0
        while s < track.length {
            let frame = track.frame(at: s)
            for (index, hand) in [Float(-1), 1].enumerated() {
                let seed = Float(index) * 37
                // **間引く。** 全部の場所に立てると壁のように見えて、かえって
                // 速さが読めなくなる
                guard jitter(s * 0.013 + seed, 11) > 0.38 else { continue }
                let across = hand * (inner + (outer - inner) * jitter(s * 0.021 + seed, 3))
                // 裾は外へ向かって下がるので、その傾きに乗せる
                let lift = -30 * Math.unit((abs(across) - 110) / 340)
                let ground = frame.point + Track.side(frame.heading) * across
                // **渡す座標なので写しを通す** (``Apex/screen(_:_:_:)``)
                let spot = Apex.screen(ground.x, frame.height + lift, ground.y)
                places.append(
                    Placement(
                        x: spot.x, y: spot.y, z: spot.z,
                        scale: 0.7 + 0.9 * jitter(s * 0.017 + seed, 7),
                        rotation: SIMD3(0, -jitter(s * 0.031 + seed, 5) * 2 * Float.pi, 0)))
            }
            s += spacing
        }
        return places
    }
}
