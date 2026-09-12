import Foundation
import mokume
import simd

/// 水の上にあるもの — 睡蓮の葉、散った花びら、撒いた餌。
///
/// ## 浮いているものは、水面の断片が動かす
///
/// ここに並ぶものは**自分の面へ描くだけ**で、水面の断片がそれを読んで重ねる。
/// 水越しに見ていないので屈折も濁りも掛からないが、代わりに 2 つが効く:
///
/// 1. **横へ流されるぶん** — 深水波の水粒子は円を描く。その横向きの変位は
///    傾きを `−1/k` 倍したものなので (`pond_ride`)、**傾きさえ持っていれば
///    別に数えなくてよい。** 輪も乗るので、落とした餌は自分が立てた輪に揺られる
/// 2. **濡れた葉の照り** — 面の傾きから鏡面反射を出すので、照りが葉の上を
///    細い帯として流れる
///
/// **CPU 側は高さ場を持たない。** 写せば同じ式が 2 か所に住む。
///
/// ## 葉そのものは茎に吊られた振り子である
///
/// 睡蓮は茎で底に繋がっているので流れていかない。風に押されて風下へ寄り、戻って
/// くるだけで、その周期は茎の長さで決まる (`swung`)。
///
/// **はじめはここを「浮いているものは波でほとんど動かない」で済ませていた。**
/// 真上から見る限り上下の揺れは見えず、横の動きは波の振幅 (数 mm) しかない、
/// という理屈は間違っていないのだが、**絵としては貼り紙にしか見えなかった。**
/// 見落としていたのは、照りが傾きで大きく動くことと、その横の動きも断片の側なら
/// 傾きから出せることである。
final class Surface {

    /// 浮いているものの面。**背景は透明**で、水面の断片がここを最後に重ねる。
    let canvas: Canvas

    /// 睡蓮の葉。
    private struct Pad {
        var place: SIMD2<Float>
        var radius: Float
        var angle: Float
        var sway: Float
        var tone: Float
        var flower: Bool
        /// 茎の長さ (mm)。**振り子の半径**で、長いほど大きく振れて周期も遅い。
        var stem: Float
        var phase: Float
    }

    /// 散った花びら。
    private struct Petal {
        var place: SIMD2<Float>
        var angle: Float
        var spin: Float
        var size: Float
    }

    /// 撒いた餌。
    struct Pellet {
        var place: SIMD2<Float>
        var born: Float
    }

    private var pads: [Pad] = []
    /// いまの風の強さ。**振れ幅に効く。**
    var wind: Float = 0.55
    private var petals: [Petal] = []
    private(set) var pellets: [Pellet] = []

    private let span: SIMD2<Float>
    /// 花びらを流す向き。**風と同じ向き**にしてある。
    var flow = SIMD2<Float>(0.91, 0.41)

    init(canvas: Canvas, span: SIMD2<Float>) {
        self.canvas = canvas
        self.span = span
        var scatter = Scatter(seed: 77_020_931)
        // 葉は隅に寄せる。**真ん中は水面のためにあける**
        let anchors: [SIMD2<Float>] = [
            SIMD2(0.07, 0.13), SIMD2(0.19, 0.06), SIMD2(0.04, 0.31),
            SIMD2(0.93, 0.83), SIMD2(0.82, 0.94), SIMD2(0.97, 0.66),
            SIMD2(0.88, 0.11), SIMD2(0.12, 0.92),
        ]
        for (index, anchor) in anchors.enumerated() {
            pads.append(
                Pad(
                    place: SIMD2(anchor.x * span.x, anchor.y * span.y)
                        + SIMD2(scatter.next(-30, 30), scatter.next(-30, 30)),
                    radius: scatter.next(62, 104),
                    angle: scatter.next(0, 6.28),
                    sway: scatter.next(0.09, 0.18),
                    tone: scatter.next(0.84, 1.14),
                    flower: index == 1 || index == 4,
                    stem: scatter.next(180, 420),
                    phase: scatter.next(0, 6.28)))
        }
        for _ in 0..<7 {
            petals.append(
                Petal(
                    place: SIMD2(scatter.next(0, span.x), scatter.next(0, span.y)),
                    angle: scatter.next(0, 6.28),
                    spin: scatter.next(-0.5, 0.5),
                    size: scatter.next(8, 13)))
        }
    }

    // MARK: - 餌

    func drop(at place: SIMD2<Float>, now: Float) {
        guard pellets.count < 40 else { return }
        pellets.append(Pellet(place: place, born: now))
    }

    func clear() { pellets.removeAll() }

    /// いちばん近い餌。**届く範囲の外なら返さない** — 鯉は池の反対側の餌を見ない。
    func nearest(to place: SIMD2<Float>, within reach: Float) -> (index: Int, place: SIMD2<Float>)? {
        var best: (index: Int, place: SIMD2<Float>)?
        var nearest = reach
        for (index, pellet) in pellets.enumerated() {
            let far = simd_length(pellet.place - place)
            if far < nearest {
                nearest = far
                best = (index, pellet.place)
            }
        }
        return best
    }

    func take(_ index: Int) -> SIMD2<Float>? {
        guard pellets.indices.contains(index) else { return nil }
        return pellets.remove(at: index).place
    }

    /// ふやけて沈む。**放っておけば池は元へ戻る。**
    func soak(now: Float) {
        pellets.removeAll { now - $0.born > 26 }
    }

    // MARK: - 動かす

    func drift(dt: Float, wind: Float) {
        for index in petals.indices {
            petals[index].place += flow * (6 + 26 * wind) * dt
            petals[index].angle += petals[index].spin * dt * (0.3 + wind)
            if petals[index].place.x > span.x + 40 { petals[index].place.x = -40 }
            if petals[index].place.y > span.y + 40 { petals[index].place.y = -40 }
        }
        // 餌もわずかに流される
        for index in pellets.indices {
            pellets[index].place += flow * (3 + 9 * wind) * dt
        }
    }

    // MARK: - 描く

    /// 葉が底へ落とす影。**水面の断片より前** (池の底) へ描く。
    func castShadows(onto bed: Canvas, slide: SIMD2<Float>, depth: Float, time: Float) {
        bed.noStroke()
        bed.fill(.display(red: 0.0, green: 0.015, blue: 0.02, alpha: 0.42))
        for pad in pads {
            let place = swung(pad, time: time).place + slide * depth
            bed.ellipse(place.x, place.y, pad.radius * 2.05, pad.radius * 2.05)
        }
    }

    /// 振れた後の葉の置き方。**影も同じ場所へ落とす**ので 1 か所に置く。
    ///
    /// **葉は茎で底に繋がった振り子である。** 風に押されて風下へ寄り、戻ってくる。
    /// 角振動数は振り子の式 `√(g/L)` そのままで、長い茎ほどゆっくり大きく振れる —
    /// ただし水中では浮力が重力を打ち消すので、`g` は 6 分の 1 にしてある。
    ///
    /// **波の 1 つ 1 つが与える捻りは、ここでは数えていない。** 高さ場は断片の中に
    /// しかなく、CPU 側へ写せば式が 2 か所に住む。波に乗って流されるぶん
    /// (`pond_ride`) と、傾いて照りが動くぶんは、どちらも水面の断片が受け持つ
    private func swung(_ pad: Pad, time: Float) -> (place: SIMD2<Float>, turn: Float) {
        let beat = (Water.gravity / 6 / pad.stem).squareRoot()
        let swing = sin(time * beat + pad.phase)
        let cross = sin(time * beat * 0.61 + pad.phase * 1.7)
        let reach = (14 + 26 * wind) * (pad.stem / 300)
        let place =
            pad.place + flow * (swing * reach)
            + SIMD2(-flow.y, flow.x) * (cross * reach * 0.45)
        // 向きは振れの遅れとして出る
        return (place, pad.angle + (swing * 0.62 + cross * 0.38) * pad.sway)
    }

    /// 水の上のものを自分の面へ描く。**重ねるのは水面の断片。**
    func draw(time: Float) {
        canvas.beginDraw()
        canvas.background(.transparent)
        canvas.noStroke()
        for pad in pads { lily(pad, on: canvas, time: time) }
        for petal in petals {
            canvas.fill(.display(red: 0.88, green: 0.68, blue: 0.70, alpha: 0.85))
            canvas.push()
            canvas.translate(petal.place.x, petal.place.y)
            canvas.rotate(petal.angle)
            canvas.ellipse(0, 0, petal.size * 2.1, petal.size)
            canvas.pop()
        }
        for pellet in pellets {
            // 水を押しのけた縁が光る。**半分沈んでいるもの**の見え方
            canvas.fill(.display(red: 0.72, green: 0.80, blue: 0.74, alpha: 0.34))
            canvas.circle(pellet.place.x, pellet.place.y, 22)
            canvas.fill(.display(red: 0.66, green: 0.48, blue: 0.22))
            canvas.circle(pellet.place.x, pellet.place.y, 13)
        }
        canvas.endDraw()
    }

    /// 睡蓮の葉 1 枚。**切れ込みが 1 本入る**ので、丸ではなく葉に見える。
    private func lily(_ pad: Pad, on target: Canvas, time: Float) {
        let ride = swung(pad, time: time)
        target.push()
        target.translate(ride.place.x, ride.place.y)
        target.rotate(ride.turn)

        let notch: Float = 0.42
        let steps = 34
        // 縁。**葉は内側より縁が明るい** (立ち上がって光を受ける)
        for (inset, colour) in [
            (Float(1.0), LinearRGBA.display(red: 0.38, green: 0.56, blue: 0.25)),
            (Float(0.93), LinearRGBA.display(red: 0.27, green: 0.45, blue: 0.19)),
        ] {
            target.fill(
                .display(
                    red: colour.red * pad.tone, green: colour.green * pad.tone,
                    blue: colour.blue * pad.tone))
            target.beginShape(.triangleFan)
            target.vertex(0, 0)
            for step in 0...steps {
                let t = Float(step) / Float(steps)
                let angle = notch / 2 + t * (2 * Float.pi - notch)
                let wobble = 1 + sin(angle * 7 + pad.angle) * 0.018
                let reach = pad.radius * inset * wobble
                target.vertex(cos(angle) * reach, sin(angle) * reach)
            }
            target.endShape()
        }

        // 葉脈
        target.stroke(.display(red: 0.38, green: 0.50, blue: 0.28, alpha: 0.22))
        target.strokeWeight(1.8)
        for step in 0...9 {
            let angle = notch / 2 + Float(step) / 9 * (2 * Float.pi - notch)
            target.line(0, 0, cos(angle) * pad.radius * 0.9, sin(angle) * pad.radius * 0.9)
        }
        target.noStroke()

        if pad.flower { bloom(on: target, radius: pad.radius) }
        target.pop()
    }

    /// 睡蓮の花。細い花弁を 3 重に回して置く。
    private func bloom(on canvas: Canvas, radius: Float) {
        let centre = SIMD2<Float>(radius * 0.24, -radius * 0.18)
        canvas.push()
        canvas.translate(centre.x, centre.y)
        for (ring, count) in [(Float(1.0), 11), (Float(0.68), 9), (Float(0.38), 7)] {
            for index in 0..<count {
                let angle = Float(index) / Float(count) * 2 * Float.pi + ring * 1.1
                canvas.push()
                canvas.rotate(angle)
                canvas.fill(
                    .display(
                        red: 1.0, green: 0.72 + 0.2 * (1 - ring), blue: 0.80 + 0.15 * (1 - ring),
                        alpha: 0.95))
                canvas.ellipse(radius * 0.20 * ring, 0, radius * 0.42 * ring, radius * 0.15 * ring)
                canvas.pop()
            }
        }
        canvas.fill(.display(red: 1.0, green: 0.88, blue: 0.42))
        canvas.circle(0, 0, radius * 0.14)
        canvas.pop()
    }
}
