import Foundation
import mokume
import simd

/// Tempo — 譜面から導く 16 秒のループ。
///
/// ## 動かすのではなく、時刻から導く
///
/// **絵は拍の関数である。** `render(at:)` から下はどこにも状態を持たず、拍を渡せば
/// 絵が決まる。アニメーションを「進める」コードが 1 行も無いので、時間を戻しても
/// 飛ばしても、同じ拍からは同じ絵が出る。
///
/// スケッチが持つ状態は**再生位置 (`playhead`) と、動かしているかどうか**だけで、
/// これは時計であって絵ではない。ドラッグで擦れるのはその帰結で、**擦れること自体が
/// 「状態を持っていない」ことの実演**になっている。
///
/// ## 5 つの場面は 5 つの作品ではない
///
/// 32 拍を 5 つに割ってあるが、色は 4 色 (``Palette``)、動きは 5 本のイージング
/// (``Ease``) しか使わない。場面の変わり目では**前の場面の最後の形が次の場面の最初の
/// 形**になるように渡す — 格子が組んだ語をそのまま押し出し、押し出した語をそのまま
/// 畳む (``Extrude/drawSubject(yaw:pitch:depth:)`` は押し出しと畳みが共用している)。
///
/// ## ループの継ぎ目
///
/// 拍 32 は拍 0 と同じ時刻なので、**継ぎ目は定義から閉じている**。閉じていることを
/// 絵の側でも守るために、畳み終わり (拍 32 の直前) と数え始め (拍 0 の直後) は
/// どちらも「地と手引きだけ」に着く — 打点の反転も拍 0 では出さない。
final class Tempo: Sketch {
    var settings = SketchSettings(width: 1920, height: 1080, title: "tempo")

    // MARK: - 時計 (ここだけが状態)

    /// 再生位置 (拍)。**絵ではなく時計である。**
    private(set) var playhead: Float = 0
    /// 動いているか。
    private var isPlaying = true
    /// いま擦っているか。
    private var isScrubbing = false

    // MARK: - 焼いたもの

    /// 語ごとの形。**走り出してから 1 度だけ焼く** — `textOutline` は面の設定を読むので、
    /// フレームの外では取れない
    private var words: [String: Glyphs.Word] = [:]
    /// 格子の目 1 枚。**1 枚焼いて 1,296 か所へ置く。**
    private var tile: Shape?
    /// 厚みを付けた語。
    private var relief: Shape?
    /// 自作の後処理。
    private var smear: EffectShader?
    private var baked = false
    /// 焼くのに掛かった時間 (ミリ秒)。**最初の 1 フレームだけが払う。**
    private var bakeMs: Float = 0
    /// 格子の目が語の内側に入るか。**焼くときに 1 度だけ調べる** (``Tiles``)。
    private(set) var tileMask: [Bool] = []

    /// 場面の寸法。
    let span = SIMD2<Float>(1920, 1080)

    /// 起こす語。**この 1 文が作品の主題そのもの**である。
    static let lines = ["EVERY", "FRAME", "IS A", "FUNCTION OF"]
    /// 押し出す語。
    static let subject = "TIME"

    func setup() {
        // 打点の反転で 1 を超えるので、出口で肩を丸める
        exposure(1.0)
        toneMapping(.roll)
        noiseSeed(1201)
    }

    func draw() {
        bakeIfNeeded()

        // **飛んだフレームで拍を飛ばさない。** 作り直しの後の 1 フレーム目が長い
        if isPlaying, !isScrubbing {
            playhead += min(deltaTime, 1.0 / 20) / Score.secondsPerBeat
        }
        let beat = Score.wrap(playhead)

        render(at: beat)
        dress(at: beat)
        trail(at: beat)

        let span = Score.span(at: beat)
        expose("beat", beat)
        expose("bar", Score.index(beat) / Int(Score.beatsPerBar) + 1)
        expose("cut", span.cut.name)
        expose("local", Score.local(beat, in: span))
        expose("playing", isPlaying)
        // **効果が組めなかったことを黙って飲まない。** 組めなければ絵から尾が消えるだけで、
        // 見ている側には「そういう作品」に見えてしまう
        expose("smear", smear == nil ? "組めなかった" : (smear?.failure ?? "ok"))
        expose("bakeMs", bakeMs)
        expose("tileDraws", tile?.drawCallCount ?? 0)
        expose("reliefVertices", relief?.vertexCount ?? 0)
        expose("glyphTriangles", words.values.reduce(0) { total, word in
            total + word.marks.reduce(0) { $0 + $1.glyph.triangles.count / 3 }
        })
        expose("scrubbing", isScrubbing)
    }

    /// **拍を渡すと絵が決まる。** ここから下は時計を読まない。
    private func render(at beat: Float) {
        background(Palette.paper)
        noStroke()
        switch Score.span(at: beat).cut {
        case .count: drawCount(at: beat)
        case .rise: drawRise(at: beat)
        case .tiles: drawTiles(at: beat)
        case .extrude: drawExtrude(at: beat)
        case .fold: drawFold(at: beat)
        }
    }

    /// 打点で尾を引く。**引きずる向きは場面ごとに違う** — 動いている向きの後ろへ引く
    private func trail(at beat: Float) {
        guard let smear else { return }
        let cut = Score.span(at: beat).cut
        let drag: SIMD2<Float>
        switch cut {
        case .count: drag = SIMD2(0, 0)
        case .rise: drag = SIMD2(0, 26)
        case .tiles: drag = SIMD2(14, 6)
        case .extrude: drag = SIMD2(18, 0)
        case .fold: drag = SIMD2(34, 0)
        }
        // **格子では弱める。** 目の間隔 (40 画素) より長く引くと、隙間と目が混ざって
        // 画面ごと灰色に寄る — 速い動きに見えるのではなく、色が濁る
        let reach: Float = cut == .tiles ? 0.34 : 0.5
        let hit = cut == .count ? 0 : Score.attack(beat, decay: 0.18) * reach
        smear.set("drag", .pair(drag.x, drag.y))
        smear.set("amount", .number(hit))
        effects([.custom(smear)])
    }

    // MARK: - 焼く

    private func bakeIfNeeded() {
        guard !baked else { return }
        baked = true
        let began = Date()
        defer { bakeMs = Float(Date().timeIntervalSince(began) * 1000) }

        for line in Self.lines {
            words[line] = Glyphs.bake(line, size: 230, in: self)
        }
        words[Self.subject] = Glyphs.bake(Self.subject, size: 560, in: self)
        for digit in ["1", "2", "3", "4"] {
            words[digit] = Glyphs.bake(digit, size: 330, in: self)
        }

        tileMask = Tempo.mask(
            of: word(Self.subject), origin: SIMD2(span.x / 2, Tiles.baseline))

        // 格子の目。**中心を原点にして焼く**ので、置き場所と回転がそのまま効く。
        // 塗りを白で焼くのは、置き場所ごとの色を掛けるため
        let side = Tiles.face
        tile = createShape {
            noStroke()
            fill(LinearRGBA.display(red: 1, green: 1, blue: 1))
            beginShape()
            vertex(-side / 2, -side / 2)
            vertex(side / 2, -side / 2)
            vertex(side / 2, side / 2)
            vertex(-side / 2, side / 2)
            endShape(.close)
        }

        relief = bakeRelief()
        smear = try? makeEffect(Smear.body, name: "smear", values: Smear.starting)
    }

    /// 焼いた語を引く。**焼けていなければ空の語**を返す (絵は出ないが落ちない)。
    func word(_ text: String) -> Glyphs.Word {
        words[text] ?? Glyphs.Word(text: text, glyphs: [], width: 0, capHeight: 0)
    }

    var tileShape: Shape? { tile }
    var reliefShape: Shape? { relief }

    // MARK: - 形を置く

    /// 字 1 つを塗る。**焼いておいた三角形を並べるだけ** (``Stitch``)。
    func place(_ glyph: Glyphs.Glyph) {
        guard !glyph.triangles.isEmpty else { return }
        beginShape(.triangles)
        for point in glyph.triangles { vertex(point.x, point.y) }
        endShape(.close)
    }

    /// 語を塗る。字は語の中での位置へ置く。
    func place(_ word: Glyphs.Word) {
        for mark in word.glyphs {
            push()
            translate(mark.x, 0)
            place(mark.glyph)
            pop()
        }
    }

    // MARK: - 触る

    func mousePressed() {
        isScrubbing = true
        scrub()
    }

    func mouseDragged(deltaX: Float, deltaY: Float) {
        guard isScrubbing else { return }
        scrub()
    }

    func mouseReleased() {
        isScrubbing = false
    }

    /// 横の位置をひと回りへ写す。**下に敷いた定規と同じ物差しを使う** (``Ruler``)。
    private func scrub() {
        playhead = Ruler.beat(atX: mouseX)
    }

    func keyPressed() {
        switch keyCode {
        case Key.space:
            isPlaying.toggle()
        case Key.arrowLeft:
            playhead = Score.wrap((Score.wrap(playhead) - 0.001).rounded(.down))
        case Key.arrowRight:
            playhead = Score.wrap(Score.wrap(playhead).rounded(.down) + 1)
        case Key.digit1, Key.digit2, Key.digit3, Key.digit4, Key.digit5:
            let cuts: [Key] = [.digit1, .digit2, .digit3, .digit4, .digit5]
            if let index = cuts.firstIndex(where: { $0 == keyCode }),
                index < Score.spans.count
            {
                playhead = Score.spans[index].from
            }
        default:
            break
        }
    }
}
