import Foundation
import mokume
import simd

/// 格子の目。**1 枚焼いて 1,296 か所へ置く。**
enum Tiles {
    /// 目の間隔。
    static let side: Float = 40
    /// 目そのものの大きさ。**間隔より小さい** — 隙間から地が見えないと、めくれても
    /// 「色が変わった」にしか見えない
    static let face: Float = 33
    static let columns = 48
    static let rows = 27
    static var count: Int { columns * rows }

    /// 組み上がる語が乗る基準線。**押し出し (拍 20) がそのまま引き取る。**
    static let baseline: Float = 742

    /// 目の中心 (画面の座標)。
    static func centre(of index: Int) -> SIMD2<Float> {
        let column = index % columns
        let row = index / columns
        return SIMD2((Float(column) + 0.5) * side, (Float(row) + 0.5) * side)
    }

    /// 斜めに走る波の中での、その目の位置 (0…1)。
    static func diagonal(of index: Int) -> Float {
        let column = Float(index % columns) / Float(columns - 1)
        let row = Float(index / columns) / Float(rows - 1)
        return (column * 0.72 + row * 0.28)
    }
}

/// 格子がめくれる (拍 12–20)。
///
/// **1 枚の形を 1,296 か所へ置いている** (`shape(_:at:)`)。置き場所ごとに向きと色を持てるので、
/// 目を 1,296 回描くのではなく、置き場所を 1,296 個渡して 1 回で描く。
///
/// 波は 2 拍にひと筋、斜めに走る。通った目は半回転して**裏の色**を見せるので、色が
/// 変わるのではなく**面が入れ替わる** — 途中の斜めになった目が見えることが、それが
/// 回転であることを名乗っている。
///
/// 拍 16 から先は、めくれた先の色を**語の形で分ける**。`TIME` の内側に入る目だけが
/// 墨で、外は地に近い薄さになるので、波が通り過ぎたところから語が組み上がる。
/// 押し出し (拍 20) はこの語をそのまま引き取る。
extension Tempo {
    func drawTiles(at beat: Float) {
        guard let tileShape else { return }

        // 4 筋の波。2 拍にひと筋
        let waves: [Float] = [12, 14, 16, 18]
        // 面の色。**最初は地に近い薄さ**にしてある — 拍 12 で画面がいきなり黒く
        // なると、前の場面から切り離された別の絵に見える
        let pale = Palette.fade(Palette.ink, 0.12)
        let faces: [LinearRGBA] = [pale, Palette.ink, Palette.red, pale]

        var placements: [Placement] = []
        placements.reserveCapacity(Tiles.count)
        for index in 0..<Tiles.count {
            let diagonal = Tiles.diagonal(of: index)
            var turns: Float = 0
            var face = 0
            for (order, start) in waves.enumerated() {
                let from = start + diagonal * 1.15
                let turn = Ease.cubicOut(Ease.ramp(beat, from, from + 0.52))
                turns += turn
                if turn > 0.5 { face = order + 1 }
            }

            // 表と裏。**回り切る前は前の色のまま**なので、色は面の数で決まる
            let colour: LinearRGBA
            if face >= faces.count {
                // 最後の波だけ、めくれた先の色を**語の形で分ける**
                colour = tileMask[index] ? Palette.ink : pale
            } else {
                colour = faces[face]
            }

            // 波の腹では少しだけ持ち上げる。**回転だけだと平らに見える**
            let lift = sin(Float.pi * min(1, turns - turns.rounded(.down))) * 14
            placements.append(
                Placement(
                    x: Tiles.centre(of: index).x, y: Tiles.centre(of: index).y, z: lift,
                    scale: 1, rotation: SIMD3(0, turns * Float.pi, 0), fill: colour))
        }

        noStroke()
        fill(LinearRGBA.display(red: 1, green: 1, blue: 1))
        shape(tileShape, at: placements)
    }

    /// 目の中心が語の内側に入るか。**焼くときに 1 度だけ調べる。**
    static func mask(of word: Glyphs.Word, origin: SIMD2<Float>) -> [Bool] {
        (0..<Tiles.count).map { index in
            let point = Tiles.centre(of: index)
            for mark in word.marks {
                let local = point - SIMD2(origin.x + mark.x, origin.y)
                if Glyphs.contains(mark.glyph, local) { return true }
            }
            return false
        }
    }
}
