import mokume
import simd

/// 文字を「描くもの」ではなく「形」として持つ。
///
/// ## なぜ自分で三角形へ畳むのか
///
/// `textOutline` が返すのは**閉じた周の点の並び**で、そのまま `beginShape` /
/// `vertex` へ渡せば塗れる — はずだった。実際には **T のような形で塗りが外へはみ出す**
/// ([mokume#1148](https://github.com/mokume-metal/mokume/issues/1148))。横棒の下辺の
/// 途中に縦棒の角が載る形 (字の輪郭ではごく普通の T 字路) で、耳切りが「他の点を含まない」
/// と誤って判定するためである。線でなぞると正しい T が出るので、崩れているのは
/// **点の並びではなく塗りの畳み方**である。
///
/// そこでここでは**焼くときに 1 度だけ自分で三角形へ畳み**、描くときは三角形を並べて
/// 置くだけにしてある。辺の上に載った点を「含む」と数える耳切りなので、T 字路で
/// はみ出さない。
///
/// ## 書体は名指しする
///
/// **既定の書体では穴が取れない。** 既定 (システムの書体) の `A` は 3 つの重なった
/// 周として返り、`isHole` はどれも `false` になる — 重ねて塗れば絵は合うが、字を
/// 1 つの形として扱えない。名前で指した書体 (Futura・Helvetica・Avenir Next) は
/// 外周 1 つと穴という素直な形で返るので、こちらを使う
/// ([mokume#1149](https://github.com/mokume-metal/mokume/issues/1149))。
enum Glyphs {
    /// 使う書体。**幾何学的な書体を選ぶ** — 円と三角形でできているので、
    /// 拡大しても点が増えず、押し出したときの側面も素直になる。
    static let face = "Futura"

    /// 1 文字ぶんの形。座標は**字の基準点 (左端・基準線) を原点**として持つ。
    struct Glyph {
        let character: Character
        /// 塗るための三角形。3 つずつ 1 枚。
        let triangles: [SIMD2<Float>]
        /// 閉じた周。線でなぞるときに使う。
        let rings: [[SIMD2<Float>]]
        /// 次の字までの送り。
        let advance: Float
        /// 字の左端・右端 (基準点から測る)。
        let left: Float
        let right: Float
        /// 字の上端 (基準線から上へ測った正の数)。
        let top: Float

        var isBlank: Bool { triangles.isEmpty }
    }

    /// 語ひとつぶんの形。**語の中心が原点**、基準線が y = 0。
    struct Word {
        let text: String
        /// 字ごとの形と、語の中での置き場所。
        let glyphs: [(glyph: Glyph, x: Float)]
        /// 語の幅。
        let width: Float
        /// 大文字の高さ。
        let capHeight: Float

        /// 空白でない字だけ (順番は保つ)。
        var marks: [(glyph: Glyph, x: Float)] { glyphs.filter { !$0.glyph.isBlank } }
    }

    /// 語を焼く。**走らせている間に 1 度だけ呼ぶ。**
    static func bake(_ text: String, size: Float, in sketch: any Sketch) -> Word {
        sketch.textFont(face)
        sketch.textSize(size)

        var glyphs: [(Glyph, Float)] = []
        var cursor: Float = 0
        var capHeight: Float = 0
        for character in text {
            let piece = String(character)
            let advance = sketch.textWidth(piece)
            // **基準点を原点にして焼く。** 置き場所は語の側が持つので、字は
            // どこへでも置ける
            let rings = sketch.textOutline(piece, 0, 0)
            let glyph = make(character: character, rings: rings, advance: advance)
            capHeight = max(capHeight, glyph.top)
            glyphs.append((glyph, cursor))
            cursor += advance
        }

        // **中心は送り幅ではなく、墨の載る範囲で取る。** 送り幅で寄せると、字の左右に
        // 付いている余白のぶんだけ語が片寄って見える (数字の 1 で顕著に出た)
        let inked = glyphs.filter { !$0.0.isBlank }
        let left = inked.map { $0.1 + $0.0.left }.min() ?? 0
        let right = inked.map { $0.1 + $0.0.right }.max() ?? cursor
        let middle = (left + right) / 2
        let centred = glyphs.map { (glyph: $0.0, x: $0.1 - middle) }
        return Word(text: text, glyphs: centred, width: right - left, capHeight: capHeight)
    }

    /// 点が字の内側に入るか。**焼いた三角形をそのまま使う** — 輪郭を数え直すより、
    /// 既に畳んである三角形に当てるほうが穴も自然に効く。
    static func contains(_ glyph: Glyph, _ point: SIMD2<Float>) -> Bool {
        var index = 0
        while index + 2 < glyph.triangles.count {
            let a = glyph.triangles[index]
            let b = glyph.triangles[index + 1]
            let c = glyph.triangles[index + 2]
            index += 3
            let d1 = cross(b - a, point - a)
            let d2 = cross(c - b, point - b)
            let d3 = cross(a - c, point - c)
            let negative = d1 < 0 || d2 < 0 || d3 < 0
            let positive = d1 > 0 || d2 > 0 || d3 > 0
            if !(negative && positive) { return true }
        }
        return false
    }

    private static func cross(_ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Float {
        a.x * b.y - a.y * b.x
    }

    /// 周の並びから 1 文字を組む。
    private static func make(character: Character, rings: [TextContour], advance: Float) -> Glyph {
        var triangles: [SIMD2<Float>] = []
        var outlines: [[SIMD2<Float>]] = []
        var index = 0
        while index < rings.count {
            guard !rings[index].isHole else {
                // 外周に先立つ穴は行き場が無い。落とさずに周としては残す
                outlines.append(rings[index].points)
                index += 1
                continue
            }
            let outer = rings[index].points
            var holes: [[SIMD2<Float>]] = []
            var next = index + 1
            while next < rings.count, rings[next].isHole {
                holes.append(rings[next].points)
                next += 1
            }
            triangles += Stitch.triangulate(outer: outer, holes: holes)
            outlines.append(outer)
            outlines += holes
            index = next
        }

        let points = outlines.flatMap { $0 }
        let left = points.map(\.x).min() ?? 0
        let right = points.map(\.x).max() ?? advance
        let top = -(points.map(\.y).min() ?? 0)
        return Glyph(
            character: character, triangles: triangles, rings: outlines, advance: advance,
            left: left, right: right, top: max(top, 0))
    }
}
