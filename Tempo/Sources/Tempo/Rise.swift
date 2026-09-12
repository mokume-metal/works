import mokume
import simd

/// 文字が起きる (拍 4–12)。
///
/// **字は絵ではなく形である。** `textOutline` で取った輪郭を自分で三角形へ畳んであるので
/// (``Glyphs`` / ``Stitch``)、字ごとに別の時刻で動かせる。ここでは 2 拍にひと語ずつ、
/// 左から順に 0.06 拍ずつ遅れて起き上がり、**行き過ぎてから**収まる (`backOut`)。
///
/// 帯で切り取ってあるので、字は下から湧くのではなく**罫の向こうから起きてくる**。
/// 切り取りをやめると、同じ動きが「下から飛んでくる」に見える — 動きは同じで、
/// 見えている範囲だけが違う。
extension Tempo {
    /// 語が乗る基準線。
    static let riseBaseline: Float = 640

    func drawRise(at beat: Float) {
        let slot = min(Tempo.lines.count - 1, max(0, Int((Score.wrap(beat) - 4) / 2)))
        let start = 4 + Float(slot) * 2
        let line = word(Tempo.lines[slot])
        let baseline = Tempo.riseBaseline
        let top = baseline - line.capHeight - 30

        // 罫が先に走って、語の幅を名乗る
        let drawn = Ease.expoInOut(Ease.ramp(beat, start, start + 0.46))
        let leaving = Ease.expoInOut(Ease.ramp(beat, start + 1.7, start + 2))
        let half = (line.width / 2 + 26) * drawn
        stroke(Palette.red)
        strokeWeight(4)
        strokeCap(.square)
        self.line(
            span.x / 2 - half, baseline + 34, span.x / 2 - half + half * 2 * (1 - leaving),
            baseline + 34)
        noStroke()

        // 帯の向こうから起きる
        clip(0, top, span.x, baseline - top + 30)
        fill(Palette.ink)
        for (index, mark) in line.marks.enumerated() {
            let up = Ease.backOut(
                Ease.stagger(beat, start + 0.1, 0.66, index: index, spread: 0.055))
            // **次の語の頭までに、必ず帯の外へ出し切る。** 出切らないと拍の頭で
            // 前の語の尻が残り、切り替わりが濁る
            let out = Ease.expoInOut(
                Ease.stagger(beat, start + 1.45, 0.4, index: index, spread: 0.02))
            let travel = line.capHeight + 80
            push()
            translate(span.x / 2 + mark.x, baseline + (1 - up) * travel - out * travel * 1.7)
            place(mark.glyph)
            pop()
        }
        noClip()

        // 何語目か。**譜面を読むための目印**で、絵の一部ではない
        fill(Palette.fade(Palette.ink, 0.3))
        textSize(17)
        text("\(slot + 1) / \(Tempo.lines.count)", span.x / 2 - line.width / 2 - 26, baseline + 78)
    }
}
