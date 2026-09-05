import mokume

/// 原典の `colorMode(HSB)` + `fill(angle, 255, 255)` の代わり。
///
/// **v0.5.0 に色相で色を作る口が無い。** `LinearRGBA` が受けるのは表示値の 3 つ
/// (`display(red:green:blue:)`) だけなので、色相から表示値を作る式をここに置く。
///
/// **これは Issue にしていない。** mokume の `main` には既に
/// [#778](https://github.com/mokume-metal/mokume/issues/778) で色相・彩度・明度から
/// 色を作る口が入っており、リリースに乗るのを待っている状態だからである。
enum Hue {
    /// 色相 (度) から色を作る。彩度と明度は原典と同じく最大 (原典の `255` は
    /// p5 の HSB の上限 100 に丸められるので、実際に効いているのは色相だけ)。
    ///
    /// 原典の角度は最後の数点で 360 度を越える。**越えた先は巻き戻す** — p5 は上限で
    /// 止めるが、色相 360 度と 0 度はどちらも赤なので、出る絵は変わらない。
    static func color(_ degrees: Float) -> LinearRGBA {
        let turns = degrees.truncatingRemainder(dividingBy: 360)
        let sector = (turns < 0 ? turns + 360 : turns) / 60
        let rise = 1 - abs(sector.truncatingRemainder(dividingBy: 2) - 1)

        switch Int(sector) {
        case 0: return .display(red: 1, green: rise, blue: 0)
        case 1: return .display(red: rise, green: 1, blue: 0)
        case 2: return .display(red: 0, green: 1, blue: rise)
        case 3: return .display(red: 0, green: rise, blue: 1)
        case 4: return .display(red: rise, green: 0, blue: 1)
        default: return .display(red: 1, green: 0, blue: rise)
        }
    }
}
