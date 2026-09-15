import Foundation

/// 数の細工。**mokume にはまだ `lerp` も `constrain` も無い**ので自分で持つ。
enum Math {
    static func mix(_ a: Float, _ b: Float, _ f: Float) -> Float { a + (b - a) * f }

    static func clamp(_ value: Float, _ low: Float, _ high: Float) -> Float {
        min(max(value, low), high)
    }

    /// 0…1 へ収める。
    static func unit(_ value: Float) -> Float { clamp(value, 0, 1) }

    /// `low`…`high` を 0…1 へ写す。
    static func ramp(_ value: Float, _ low: Float, _ high: Float) -> Float {
        unit((value - low) / max(high - low, 1e-5))
    }

    /// 時定数 τ の追従。**フレームの長さによらず同じ硬さで追う** —
    /// `mix(a, b, 0.1)` と書くと、速さの違う機械でカメラの硬さが変わる
    static func chase(_ dt: Float, _ tau: Float) -> Float { 1 - exp(-dt / max(tau, 1e-4)) }
}
