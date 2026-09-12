import mokume
import simd

/// 畳む (拍 28–32)。
///
/// **終わり方がループの継ぎ目である。** 押し出した語を寝かせて厚みを抜き、9 本の帯に
/// 切って交互に送り出す。最後の 1 拍は地と手引きだけが残る — 拍 0 の数え始めも
/// 同じ状態なので、**ひと回りしても絵が飛ばない**。
///
/// 帯は `clip` で切り取っている。同じ絵を 9 回描いて、**見える範囲だけを変えて**
/// 別々にずらすので、切ったものが同じ 1 枚だったことが分かる。
extension Tempo {
    /// 帯の本数。
    static let bands = 9

    func drawFold(at beat: Float) {
        // 厚みと向きを抜く (拍 28–29)
        let flatten = Ease.cubicOut(Ease.ramp(beat, 28, 29))
        let yaw = Ease.mix(flatten, Tempo.poses[Tempo.poses.count - 1].x, 0)
        let pitch = Ease.mix(flatten, Tempo.poses[Tempo.poses.count - 1].y, 0)
        let depth = Ease.mix(flatten, 1, 0)

        ortho()
        let height = span.y / Float(Self.bands)
        for band in 0..<Self.bands {
            let away = Ease.expoInOut(
                Ease.stagger(beat, 29.1, 0.95, index: band, spread: 0.17))
            let direction: Float = band % 2 == 0 ? 1 : -1
            clip(0, Float(band) * height, span.x, height)
            push()
            translate(direction * away * (span.x + 360), 0)
            drawSubject(yaw: yaw, pitch: pitch, depth: depth)
            pop()
            noClip()
        }

        // 送り出した帯の行き先を名乗る朱の罫。**最後に消える**
        let rule = Ease.cubicOut(Ease.ramp(beat, 29.1, 30.2))
        let gone = Ease.expoInOut(Ease.ramp(beat, 31, 31.7))
        guard rule > 0, gone < 1 else { return }
        stroke(Palette.fade(Palette.red, (1 - gone) * 0.8))
        strokeWeight(3)
        for band in 0..<Self.bands {
            let y = Float(band) * height
            let width = span.x * rule * (1 - gone)
            let direction: Float = band % 2 == 0 ? 1 : -1
            let from = direction > 0 ? span.x - width : 0
            line(from, y, from + width, y)
        }
        noStroke()
    }
}
