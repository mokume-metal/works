import mokume
import simd

/// 下に敷く定規。**擦る先と、いま見ている拍が同じ物差しの上にある。**
enum Ruler {
    static let left: Float = 160
    static let right: Float = 1760
    static let line: Float = 1004

    static var width: Float { right - left }

    /// 拍を横の位置へ。
    static func x(of beat: Float) -> Float {
        left + width * Score.wrap(beat) / Score.beatsPerLoop
    }

    /// 横の位置を拍へ。**擦るときはこの逆写像しか使わない** — 定規の見た目と
    /// 擦り先がずれると、掴んでいるものが何なのか分からなくなる
    static func beat(atX x: Float) -> Float {
        let place = max(0, min(1, (x - left) / width))
        return place * Score.beatsPerLoop
    }
}

extension Tempo {
    /// 手引きを敷く。**絵ではなく計器**なので、どの場面でも同じ場所に同じ濃さで出る。
    ///
    /// 拍の番号を出しているのは飾りではない。**絵が時刻の関数であること**は、擦ったときに
    /// 数字と絵が必ず一緒に動くことでしか見えないからで、この数字は絵の出どころを名乗る。
    func dress(at beat: Float) {
        marks()
        plate(at: beat)
        ruler(at: beat)
    }

    /// 四隅のトンボ。
    private func marks() {
        stroke(Palette.fade(Palette.ink, 0.28))
        strokeWeight(1.5)
        let inset: Float = 64
        let arm: Float = 18
        for corner in [
            SIMD2<Float>(inset, inset), SIMD2(span.x - inset, inset),
            SIMD2(inset, span.y - inset), SIMD2(span.x - inset, span.y - inset),
        ] {
            line(corner.x - arm, corner.y, corner.x + arm, corner.y)
            line(corner.x, corner.y - arm, corner.x, corner.y + arm)
        }
        noStroke()
    }

    /// 左上の名乗り。
    private func plate(at beat: Float) {
        fill(Palette.fade(Palette.ink, 0.5))
        textSize(19)
        textAlign(.left, .baseline)
        text("TEMPO", 104, 92)
        fill(Palette.fade(Palette.ink, 0.32))
        textSize(15)
        text("120 BPM / 32 BEATS / 16 s", 104, 118)
    }

    /// 下の定規。刻みと、いまいるところ。
    private func ruler(at beat: Float) {
        let cut = Score.span(at: beat)

        // 刻み。小節の頭だけ長い
        stroke(Palette.fade(Palette.ink, 0.3))
        strokeWeight(1.5)
        for index in 0...Int(Score.beatsPerLoop) {
            let x = Ruler.x(of: Float(index) == Score.beatsPerLoop ? 0 : Float(index))
            let at = index == Int(Score.beatsPerLoop) ? Ruler.right : x
            let tall = index % Int(Score.beatsPerBar) == 0
            line(at, Ruler.line, at, Ruler.line + (tall ? 16 : 8))
        }
        line(Ruler.left, Ruler.line, Ruler.right, Ruler.line)

        // 場面の区切り。**譜面の割り方をそのまま引く**
        strokeWeight(3)
        stroke(Palette.fade(Palette.ink, 0.42))
        for span in Score.spans where span.cut == cut.cut {
            line(Ruler.x(of: span.from), Ruler.line, Ruler.x(of: span.to), Ruler.line)
        }

        // いまいるところ
        let head = Ruler.x(of: beat)
        stroke(Palette.red)
        strokeWeight(2)
        line(head, Ruler.line - 26, head, Ruler.line + 18)
        noStroke()
        fill(Palette.red)
        triangle(head - 7, Ruler.line - 34, head + 7, Ruler.line - 34, head, Ruler.line - 22)

        // 数字と場面の名前
        let number = Score.index(beat) + 1
        fill(Palette.fade(Palette.ink, 0.62))
        textSize(17)
        textAlign(.left, .baseline)
        text(String(format: "%02d / 32", number), Ruler.left, Ruler.line - 22)
        textAlign(.right, .baseline)
        text(cut.cut.name, Ruler.right, Ruler.line - 22)
        textAlign(.left, .baseline)
    }
}
