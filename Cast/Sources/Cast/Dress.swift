import Foundation
import mokume
import simd

/// 角度の定規。**擦る先と、いま向いている角度が同じ物差しの上にある。**
enum Ruler {
    static let left: Float = 160
    static let right: Float = 1760
    static let line: Float = 1006

    static var width: Float { right - left }

    /// 角度 (ラジアン) を横の位置へ。
    static func x(of angle: Float) -> Float {
        left + width * wrap(angle) / (2 * .pi)
    }

    /// 横の位置を角度へ。**掴むときはこの逆写像しか使わない。**
    static func angle(atX x: Float) -> Float {
        let place = max(0, min(1, (x - left) / width))
        return place * 2 * .pi
    }

    static func wrap(_ angle: Float) -> Float {
        let folded = angle.truncatingRemainder(dividingBy: 2 * .pi)
        return folded < 0 ? folded + 2 * .pi : folded
    }
}

extension Cast {
    /// 床へ狙いの輪郭を引く。
    ///
    /// **揃ったときにだけ濃くなる。** 影が形になっている瞬間を名乗るためのもので、
    /// 送りの間は消える — 出しっぱなしにすると、影ではなく輪郭のほうを見てしまう。
    func trace(turn: Float) {
        let nearest = Turn.nearest(to: turn)
        // 角度のずれで薄くする。**揃っていないのに輪郭が出ると答えを先に見せてしまう**
        let amount = Turn.settled(at: turn)
        guard amount > 0.01 else { return }

        let kind = Targets.order[nearest.pose]
        let points = Targets.outline(kind)
        // 床のすぐ上へ置く (同じ高さだと z が競り合ってちらつく)
        let lift: Float = -2.5
        stroke(Palette.fade(Palette.red, amount * 0.85))
        strokeWeight(2.5)
        beginShape(.lines)
        for index in points.indices {
            let a = points[index]
            let b = points[(index + 1) % points.count]
            vertex(a.x, lift, a.y)
            vertex(b.x, lift, b.y)
        }
        endShape()
        noStroke()
    }

    /// 手元の計器。**絵ではなく物差し**なので、いつも同じ場所に同じ濃さで出る。
    ///
    /// 角度の数字を出しているのは飾りではない。**絵が角度の関数であること**は、擦った
    /// ときに数字と影が必ず一緒に動くことでしか見えないからで、この数字は絵の出どころを
    /// 名乗っている。
    func dress(turn: Float) {
        // **手元の表示は既定のカメラで描く。** 描き終えたら舞台のカメラへ戻す。
        //
        // 影の焼き付けはフレームの終わりに 1 度だけ走り、**そのときの光**を読む —
        // 手元の表示のために `noLights()` を呼んで (Quarry の手元表示はそうしている)
        // そのまま終えると、**そのフレームの影が黙って消える**ことを実測した。ここでは
        // 光を消さずに描いている。視点のほうは戻さなくても絵は変わらなかったが、
        // 同じ理由で戻してある
        camera()
        perspective()
        blendMode(.blend)
        noStroke()

        let degrees = Ruler.wrap(turn) * 180 / .pi
        let nearest = Turn.nearest(to: turn)
        let kind = Targets.order[nearest.pose]
        let aim = Turn.settled(at: turn)

        // 名乗り
        fill(Palette.fade(Palette.ink, 0.72))
        textSize(21)
        textAlign(.left)
        text("CAST", 160, 96)
        fill(Palette.fade(Palette.ink, 0.42))
        textSize(15)
        text("ONE MASS · THREE SHADOWS", 160, 124)

        // いまの角度
        fill(Palette.fade(Palette.ink, 0.72))
        textSize(34)
        text(String(format: "%5.1f°", degrees), 160, 962)

        // 揃った形の名乗り。**揃っていないときは出さない**
        if aim > 0.01 {
            textAlign(.right)
            fill(Palette.fade(Palette.red, aim))
            textSize(34)
            text("\(kind.mark)  \(kind.name)", 1760, 962)
            textAlign(.left)
        }

        // 定規
        stroke(Palette.fade(Palette.ink, 0.28))
        strokeWeight(1)
        line(Ruler.left, Ruler.line, Ruler.right, Ruler.line)

        // 揃う 3 か所
        for pose in 0..<3 {
            let x = Ruler.x(of: Float(pose) * 2 * .pi / 3)
            stroke(Palette.fade(Palette.ink, 0.34))
            strokeWeight(1)
            line(x, Ruler.line - 12, x, Ruler.line + 12)
            noStroke()
            fill(Palette.fade(Palette.ink, 0.45))
            textSize(15)
            textAlign(.center)
            text(Targets.order[pose].mark, x, Ruler.line + 34)
            textAlign(.left)
        }

        // いまの角度。**揃っているときだけ朱になる**
        let x = Ruler.x(of: turn)
        stroke(aim > 0.01 ? Palette.fade(Palette.red, max(0.35, aim)) : Palette.fade(Palette.ink, 0.6))
        strokeWeight(2.5)
        line(x, Ruler.line - 20, x, Ruler.line + 20)
        noStroke()

        // 舞台のカメラへ戻す (上記の但し書き)
        camera(
            Stage.eye.x, -Stage.eye.y, Stage.eye.z,
            Stage.target.x, -Stage.target.y, Stage.target.z,
            0, 1, 0)
        perspective(Stage.fieldOfView * .pi / 180, width / height, 20, 9000)
    }
}
