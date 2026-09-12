import Foundation
import mokume
import simd

/// 空と光 — 1 日を 4 分で回す。
///
/// **太陽の高さ 1 つが、空の 3 色も光の色も向きも決める。** 別々に持つと、夕焼けの空に
/// 真昼の白い光が当たるような食い違いが出る。ここでは高さから全部を引く。
///
/// ## 夜は短くしてある
///
/// 高さを `sin` そのものにすると昼と夜が半々になり、2 分の暗闇を待つことになる。
/// **0.32 だけ持ち上げて**、夜を 1 日の 3 割強に詰めてある — 夜が来ることは分かり、
/// 待つには長すぎない
enum Sky {
    /// 1 日の長さ (秒)。
    static let day: Float = 240

    struct Weather {
        let around: Surroundings
        /// 光が進む向き (世界座標・y 上向き)。
        let toward: SIMD3<Float>
        let sun: (Float, Float, Float)
        let ambient: (Float, Float, Float)
        /// 太陽の高さ。−1…1。**0 未満が夜。**
        let elevation: Float
    }

    static func weather(at time: Float) -> Weather {
        let angle = 2 * Float.pi * (time / day)
        let elevation = sin(angle) * 0.8 + 0.32

        // 太陽の居場所 → 光はそこから下りてくる
        let place = simd_normalize(SIMD3<Float>(cos(angle) * 0.75, max(elevation, -1), 0.42))

        // **昼を早く立ち上げる。** 夕焼けの重みを高さに比例させると、太陽が中天に
        // あるあいだも橙が 4 割残り、空がいつまでも紫のままだった
        let night = clamp((-elevation) / 0.26)
        let noon = clamp((elevation - 0.18) / 0.32)
        let dusk = max(0, 1 - night - noon)

        let top = mix(
            [(0.020, 0.035, 0.105), (0.215, 0.255, 0.520), (0.285, 0.520, 0.920)],
            night, dusk, noon)
        let horizon = mix(
            [(0.060, 0.090, 0.200), (0.960, 0.520, 0.255), (0.700, 0.830, 0.960)],
            night, dusk, noon)
        let ground = mix(
            [(0.020, 0.025, 0.055), (0.160, 0.135, 0.150), (0.300, 0.335, 0.315)],
            night, dusk, noon)

        let sun = mix(
            [(96, 118, 178), (255, 158, 88), (255, 250, 232)], night, dusk, noon)
        // **環境光は低めに。** 上げると面の向きの差が消えて、立方体が板に見える。
        // ただし夜は別で、**真っ暗にすると掘る手が止まる** — 月明かりの青を残す
        let ambient = mix(
            [(52, 62, 94), (60, 56, 70), (66, 72, 86)], night, dusk, noon)

        return Weather(
            around: Surroundings(
                top: .display(red: top.0, green: top.1, blue: top.2),
                horizon: .display(red: horizon.0, green: horizon.1, blue: horizon.2),
                bottom: .display(red: ground.0, green: ground.1, blue: ground.2)),
            toward: -place, sun: sun, ambient: ambient, elevation: elevation)
    }

    private static func clamp(_ value: Float) -> Float { min(max(value, 0), 1) }

    /// 夜・夕・昼の 3 色を重みで混ぜる。
    private static func mix(
        _ colors: [(Float, Float, Float)], _ night: Float, _ dusk: Float, _ noon: Float
    ) -> (Float, Float, Float) {
        let total = max(night + dusk + noon, 1e-4)
        return (
            (colors[0].0 * night + colors[1].0 * dusk + colors[2].0 * noon) / total,
            (colors[0].1 * night + colors[1].1 * dusk + colors[2].1 * noon) / total,
            (colors[0].2 * night + colors[1].2 * dusk + colors[2].2 * noon) / total
        )
    }
}
