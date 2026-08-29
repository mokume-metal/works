import Foundation
import mokume

/// 板 1 枚ぶんの木目。
///
/// 芯は板の**下**、遠くにある。輪は芯を中心とした同心の楕円で、板の長手方向へ
/// 強く引き伸ばされている — 板をその接線に近い角度で挽くと、輪は山形の連なり
/// (板目) になって現れる。
struct Plank {
    /// 板ごとの種。ここから芯の位置も節も決まる。
    var seed: Int32
    /// 芯の位置。板の座標系 (長手 0…1・幅 0…1) で、`y` は板の下 = 1 より大きい。
    var pith: SIMD2<Float>
    /// 長手方向の縮み。小さいほど輪が長く伸びる。
    var stretch: Float
    /// 板を横切る輪の数。
    var ringCount: Float
    /// 節の位置と半径。多くの板には無い。
    var knots: [(centre: SIMD2<Float>, radius: Float)]
    /// 1 枚ずつの色の差。同じ木から挽いても板ごとに違う
    var tone: Float
    /// 木目の傾き。挽く角度のわずかなずれ
    var slant: Float

    static func make(seed: Int32) -> Plank {
        // 芯は板の下。近づけすぎると板の縁で輪が同心円に潰れて、
        // 節のような渦になる
        let pithY = 1.6 + Noise.hash(seed, 1, 7) * 1.4
        let pithX = 0.15 + Noise.hash(seed, 2, 7) * 0.7
        // 長手方向の係数。**山形が出るかはここで決まる。**
        // 芯が板から `d` だけ下にあるとき、幅の半分ぶん離れた place での輪の
        // 持ち上がりは `d - sqrt(d² - (s/2)²)` で、`s` が `d` と同じ桁に
        // ないと山にならない (小さくすると、ただの水平な縞になる)
        let stretch = 1.8 + Noise.hash(seed, 3, 7) * 1.6
        let ringCount = 6 + Noise.hash(seed, 4, 7) * 7

        // 節は 3 枚に 1 枚くらい。1 枚に 1 つまで
        var knots: [(centre: SIMD2<Float>, radius: Float)] = []
        if Noise.hash(seed, 5, 7) < 0.38 {
            knots.append(
                (
                    centre: SIMD2(
                        0.12 + Noise.hash(seed, 6, 7) * 0.76,
                        0.3 + Noise.hash(seed, 7, 7) * 0.4),
                    radius: 0.065 + Noise.hash(seed, 8, 7) * 0.055
                ))
        }

        return Plank(
            seed: seed,
            pith: SIMD2(pithX, pithY),
            stretch: stretch,
            ringCount: ringCount,
            knots: knots,
            tone: 0.80 + Noise.hash(seed, 9, 7) * 0.36,
            slant: (Noise.hash(seed, 10, 7) - 0.5) * 0.16)
    }

    /// 板の中の位置 (長手・幅ともに 0…1) から色を出す。
    func colour(atX x: Float, y: Float) -> LinearRGBA {
        let sy = y + (x - 0.5) * slant

        // 輪をわずかに崩す。木は真円には育たない。
        // **縦の縮尺を横よりずっと細かくする** — 繊維は長手に沿って走るので、
        // 揺らぎも長手には緩く、幅方向には細かく効く
        let drift = (Noise.layered(x * 2.2, sy * 3.4, seed: seed) - 0.5) * 0.11

        var offset = SIMD2((x - pith.x) * stretch, sy - pith.y)

        // 節は輪を持ち上げて巻き込む。効くのは節のまわりだけ
        var knotDarkness: Float = 0
        var knotHalo: Float = 0
        for knot in knots {
            let to = SIMD2(x - knot.centre.x, (sy - knot.centre.y) * 0.55)
            let distance = sqrtf(to.x * to.x + to.y * to.y)
            let falloff = expf(-(distance * distance) / (knot.radius * knot.radius * 3.4))
            // **強く引くと輪が詰まりすぎて縞が割れる。** 節のまわりが
            // 細かい網に見えたら引きすぎている
            offset.y -= falloff * 0.26
            // 節そのもの。芯は小さく濃く、縁でひと息に薄れる —
            // 広く薄い染みにすると、節ではなく汚れに見える
            let core = 1 - smoothStep(knot.radius * 0.30, knot.radius * 0.62, distance)
            knotDarkness = max(knotDarkness, core)
            // 芯のすぐ外は明るい輪になる。**これが無いと節が汚れに見える**
            knotHalo = max(
                knotHalo,
                smoothStep(knot.radius * 0.55, knot.radius * 0.92, distance)
                    * (1 - smoothStep(knot.radius * 0.92, knot.radius * 1.6, distance)))
        }

        let radius = sqrtf(offset.x * offset.x + offset.y * offset.y) + drift
        let phase = radius * ringCount
        let inRing = phase - floorf(phase)

        // **晩材は細い。** 1 年ぶんの終わりに詰まって育つ部分で、輪の 1 割ほど。
        // 立ち上がりを急に、戻りを緩くすると年輪の向きが見える
        let late =
            smoothStep(0.78, 0.92, inRing) * (1 - smoothStep(0.94, 1.0, inRing))
            + smoothStep(0.0, 0.04, inRing) * 0

        // 繊維の筋。板の高さは画素で 100 台なので、これ以上細かくすると縞が割れる
        let fibre = (Noise.layered(x * 3, sy * 26, seed: seed &+ 31, octaves: 3) - 0.5) * 0.075
        // 大きなむら。同じ板の中の濃淡
        let blotch = (Noise.layered(x * 1.6, sy * 1.2, seed: seed &+ 71, octaves: 3) - 0.5) * 0.07

        let early = SIMD3<Float>(0.815, 0.635, 0.435)
        let lateWood = SIMD3<Float>(0.455, 0.300, 0.180)
        let knotWood = SIMD3<Float>(0.30, 0.185, 0.105)

        var colour = early + (lateWood - early) * late
        colour = colour + (knotWood - colour) * knotDarkness
        colour += SIMD3(repeating: knotHalo * 0.055)
        colour += SIMD3(repeating: fibre + blotch)
        colour *= tone

        return .display(
            red: min(max(colour.x, 0), 1),
            green: min(max(colour.y, 0), 1),
            blue: min(max(colour.z, 0), 1))
    }

    private func smoothStep(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
        let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }
}
