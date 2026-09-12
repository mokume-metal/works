import Foundation
import mokume
import simd

/// 時刻の定規。**擦る先と、いま見ている時刻が同じ物差しの上にある。**
enum Ruler {
    static let left: Float = 160
    static let right: Float = 1760
    static let line: Float = 1006

    static var width: Float { right - left }

    /// 時刻を横の位置へ。
    static func x(of time: Float) -> Float {
        left + width * Score.wrap(time) / Score.loop
    }

    /// 横の位置を時刻へ。**掴むときはこの逆写像しか使わない。**
    static func time(atX x: Float) -> Float {
        let place = max(0, min(1, (x - left) / width))
        return place * Score.loop
    }
}

extension Cast {
    /// 床へ方眼を引く。
    ///
    /// **影がどこを掃いたかを読むための下敷き**である。幕 4 で影は塊の真下のまわりを
    /// 1 周するので、目盛りが無いと「動いている」以上のことが分からない。薄い墨で
    /// 引いてあるので、影の中では沈んで見えなくなる。
    func rule() {
        let step: Float = 300
        let reach: Float = 2700
        let lift: Float = -1.5
        stroke(Palette.fade(Palette.ink, 0.085))
        strokeWeight(1)
        beginShape(.lines)
        var at = -reach
        while at <= reach {
            vertex(at, lift, -reach)
            vertex(at, lift, reach)
            vertex(-reach, lift, at)
            vertex(reach, lift, at)
            at += step
        }
        endShape()
        noStroke()
    }

    /// いま影が形になっているか。
    ///
    /// **塊の姿勢と光の方位の和だけで決まる。** 光を α 回すと、影は「塊を α 回した絵」を
    /// 床の上で α 回したものになる (``Shear`` の最後の式) — 幕 2 (塊が回る) と
    /// 幕 4 (光が回る) を同じ式で見られる。
    func aim(_ frame: Score.Frame) -> (kind: Targets.Kind, settled: Float) {
        let effective = frame.turn + frame.azimuth
        let nearest = Turn.nearest(to: effective)
        return (Targets.order[nearest.pose], Turn.settled(at: effective))
    }

    /// 床へ狙いの輪郭を引く。
    ///
    /// **揃ったときにだけ濃くなる。** 影が形になっている瞬間を名乗るためのもので、
    /// 外れている間は消える — 出しっぱなしにすると、影ではなく輪郭のほうを見てしまう。
    func trace(_ frame: Score.Frame) {
        let (kind, settled) = aim(frame)
        let amount = settled * max(frame.mass, frame.grains)
        guard amount > 0.01 else { return }

        // 影の中心は方位で回る。形も同じ角だけ回る (``Shear`` の最後の式)
        let center = Shear.shadowCenter(frame.azimuth)
        let spin = frame.azimuth
        let points = Targets.outline(kind).map { point -> SIMD2<Float> in
            let x = point.x * cos(spin) - point.y * sin(spin)
            let y = point.x * sin(spin) + point.y * cos(spin)
            return SIMD2<Float>(x + center.x, y + center.y)
        }
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
    /// 時刻と幕の名前を出しているのは飾りではない。**絵が時刻の関数であること**は、
    /// 擦ったときに数字と絵が必ず一緒に動くことでしか見えないからで、この数字は絵の
    /// 出どころを名乗っている。
    func dress(_ frame: Score.Frame) {
        // **手元の表示は既定のカメラで描く。** 描き終えたら舞台のカメラへ戻す。
        //
        // 影の焼き付けはフレームの終わりに 1 度だけ走り、**そのときの光**を読む —
        // 手元の表示のために `noLights()` を呼んで (mokume の参照スケッチや Quarry の
        // 手元表示はそうしている) そのまま終えると、**そのフレームの影が黙って消える**
        // ことを実測した。ここでは光を消さずに描いている
        camera()
        perspective()
        blendMode(.blend)
        noStroke()

        let (kind, settled) = aim(frame)

        // 名乗り
        fill(Palette.fade(Palette.ink, 0.72))
        textSize(21)
        textAlign(.left)
        text("CAST", 160, 96)
        fill(Palette.fade(Palette.ink, 0.42))
        textSize(15)
        text("ONE MASS · THREE SHADOWS", 160, 124)

        // いまの時刻と幕
        fill(Palette.fade(Palette.ink, 0.72))
        textSize(34)
        text(String(format: "%05.2fs", frame.time), 160, 962)
        fill(Palette.fade(Palette.ink, 0.5))
        textSize(17)
        text(frame.act.name, 300, 962)

        // 揃った形の名乗り。**揃っていないときは出さない**
        if settled > 0.01 {
            textAlign(.right)
            fill(Palette.fade(Palette.red, settled))
            textSize(34)
            text("\(kind.mark)  \(kind.name)", 1760, 962)
            textAlign(.left)
        }

        // 定規
        stroke(Palette.fade(Palette.ink, 0.28))
        strokeWeight(1)
        line(Ruler.left, Ruler.line, Ruler.right, Ruler.line)

        // 幕の変わり目
        for act in Score.Act.allCases {
            let x = Ruler.x(of: act.span.from)
            stroke(Palette.fade(Palette.ink, act == frame.act ? 0.45 : 0.22))
            strokeWeight(1)
            line(x, Ruler.line - 12, x, Ruler.line + 12)
            noStroke()
            fill(Palette.fade(Palette.ink, act == frame.act ? 0.55 : 0.28))
            textSize(13)
            text(act.name, x + 8, Ruler.line + 30)
        }

        // いまの時刻。**揃っているときだけ朱になる**
        let x = Ruler.x(of: frame.time)
        stroke(settled > 0.01 ? Palette.fade(Palette.red, max(0.35, settled)) : Palette.fade(Palette.ink, 0.6))
        strokeWeight(2.5)
        line(x, Ruler.line - 20, x, Ruler.line + 20)
        noStroke()

        // 舞台のカメラへ戻す (上記の但し書き)
        let eye = Stage.eye(frame.pull)
        let look = Stage.target(frame.pull)
        camera(eye.x, -eye.y, eye.z, look.x, -look.y, look.z, 0, 1, 0)
        perspective(Stage.fieldOfView * .pi / 180, width / height, 20, 16000)
    }
}
