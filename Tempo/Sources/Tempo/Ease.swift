import Foundation

/// 動きの付け方。**この 5 本しか使わない。**
///
/// モーショングラフィックスで見分けが付くのは形ではなく**加速の仕方**である。場面ごとに
/// 曲線を足していくと、同じ 1 本の中で動きの訛りが揃わなくなるので、5 本に絞って全部を
/// その合成で書く。どの場面のどの動きも、必ず ``ramp(_:_:_:)`` で 0…1 を作ってから
/// この 5 本のどれかへ通す。
enum Ease {
    /// そのまま。**間を測るためのもの**で、見せる動きには使わない。
    static func linear(_ t: Float) -> Float { clamp(t) }

    /// 速く出て、静かに止まる。**既定の動き。**
    static func cubicOut(_ t: Float) -> Float {
        let t = clamp(t)
        let inverse = 1 - t
        return 1 - inverse * inverse * inverse
    }

    /// 行き過ぎてから戻る。止まる位置を**一度越える**ので、置かれたものに重さが出る。
    static func backOut(_ t: Float, _ overshoot: Float = 1.9) -> Float {
        let t = clamp(t) - 1
        return 1 + (overshoot + 1) * t * t * t + overshoot * t * t
    }

    /// 止まっているところから一気に走って、一気に止まる。**場面の転換に使う。**
    static func expoInOut(_ t: Float) -> Float {
        let t = clamp(t)
        if t <= 0 { return 0 }
        if t >= 1 { return 1 }
        return t < 0.5
            ? pow(2, 20 * t - 10) / 2
            : (2 - pow(2, -20 * t + 10)) / 2
    }

    /// 段で飛ぶ。**間を飛ばして「撮り」を粗くする** — 1 拍を n 等分して、その刻みでしか動かない。
    static func steps(_ t: Float, _ count: Int) -> Float {
        guard count > 0 else { return clamp(t) }
        return (clamp(t) * Float(count)).rounded(.down) / Float(count)
    }

    // MARK: - 0…1 を作る

    /// 拍の窓を 0…1 へ写す。**動きは全部ここから始まる。**
    static func ramp(_ beat: Float, _ from: Float, _ to: Float) -> Float {
        guard to > from else { return beat >= to ? 1 : 0 }
        return clamp((beat - from) / (to - from))
    }

    /// 順にずらして始める。`index` 番目が `spread` 拍ぶん遅れて同じ動きをする。
    static func stagger(
        _ beat: Float, _ from: Float, _ length: Float, index: Int, spread: Float
    ) -> Float {
        let start = from + Float(index) * spread
        return ramp(beat, start, start + length)
    }

    /// 0…1 を a…b へ写す。
    static func mix(_ t: Float, _ a: Float, _ b: Float) -> Float { a + (b - a) * t }

    private static func clamp(_ t: Float) -> Float { max(0, min(1, t)) }
}
