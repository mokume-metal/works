import Foundation
import mokume
import simd

/// 数え上げ (拍 0–4)。
///
/// **まず時計を見せる。** これから 28 拍ぶん何が起きるかを説明する代わりに、1 拍が
/// どれだけの長さで、どこが拍頭なのかを 4 回見せる。輪は 1 拍にひと切れずつ閉じ、
/// 針はその上を等速で回り、数字は拍頭で行き過ぎてから収まる — **等速・加速・打点**の
/// 3 つが同じ画面に並ぶので、以降の場面で何が「拍どおり」なのかが分かる。
///
/// 拍 0 では反転を出さない。**ここがループの継ぎ目**で、畳み終わりと地続きに見える
/// 必要があるからである。
extension Tempo {
    func drawCount(at beat: Float) {
        let centre = SIMD2<Float>(span.x / 2, 520)
        let radius: Float = 236

        ring(at: beat, centre: centre, radius: radius)
        hand(at: beat, centre: centre, radius: radius)
        digit(at: beat, centre: centre)
        flash(at: beat)
    }

    /// 1 拍にひと切れずつ閉じていく輪。
    private func ring(at beat: Float, centre: SIMD2<Float>, radius: Float) {
        noFill()
        strokeWeight(11)
        strokeCap(.square)
        for quarter in 0..<4 {
            let grown = Ease.cubicOut(Ease.ramp(beat, Float(quarter), Float(quarter) + 0.58))
            guard grown > 0 else { continue }
            let from = -Float.pi / 2 + Float(quarter) * Float.pi / 2
            stroke(quarter == Score.index(beat) ? Palette.red : Palette.ink)
            arc(
                centre.x, centre.y, radius * 2, radius * 2, from,
                from + grown * Float.pi / 2)
        }
        noStroke()
    }

    /// 等速で回る針。**輪と違って溜めも行き過ぎも無い** — 比べるために置いてある。
    private func hand(at beat: Float, centre: SIMD2<Float>, radius: Float) {
        let angle = -Float.pi / 2 + 2 * Float.pi * Ease.linear(beat / 4)
        stroke(Palette.fade(Palette.ink, 0.45))
        strokeWeight(2.5)
        line(
            centre.x, centre.y, centre.x + cos(angle) * radius * 0.86,
            centre.y + sin(angle) * radius * 0.86)
        noStroke()
        fill(Palette.ink)
        circle(centre.x, centre.y, 13)
    }

    /// 拍頭で行き過ぎてから収まる数字。
    private func digit(at beat: Float, centre: SIMD2<Float>) {
        let index = Score.index(beat)
        let glyphs = word(String(index + 1))
        let landed = Ease.backOut(Ease.ramp(beat, Float(index), Float(index) + 0.46))
        let sink = Ease.cubicOut(Ease.ramp(beat, Float(index) + 0.72, Float(index) + 1))

        push()
        translate(centre.x, centre.y + glyphs.capHeight / 2)
        scale(Ease.mix(landed, 0.55, 1), Ease.mix(landed, 0.55, 1))
        fill(Palette.fade(Palette.ink, 1 - sink * 0.75))
        place(glyphs)
        pop()
    }

    /// 拍頭の反転。
    ///
    /// **半端に混ぜない。** 白を薄く重ねると、差をとった絵は灰色に寄るだけで「反転」に
    /// 見えない。出すか出さないかの 2 段 (`steps`) にして、出すときは全部反転させる。
    /// 長さは 2 コマ (33 ミリ秒) — 1 コマだと撮った絵にも目にも残らず、3 コマを超えると
    /// 点滅として目に付きはじめる。
    ///
    /// 拍 0 では出さない。**そこがループの継ぎ目**で、畳み終わりと地続きに見える必要がある。
    private func flash(at beat: Float) {
        guard Score.index(beat) > 0 else { return }
        // 打点の強さを 2 段に量子化して、上の段でだけ出す (= 拍頭から 0.06 拍)
        let hit = Ease.steps(Score.attack(beat, decay: 0.12), 2)
        guard hit >= 0.5 else { return }
        blendMode(.difference)
        fill(LinearRGBA.display(red: 1, green: 1, blue: 1))
        rect(0, 0, span.x, span.y)
        blendMode(.blend)
    }
}
