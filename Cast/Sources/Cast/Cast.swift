import Foundation
import mokume
import simd

/// Cast — 1 つの塊が、向きによって別の形の影を落とす。
///
/// ## 形は物の側ではなく、光の側にある
///
/// 画面に置いてある立体は**塊が 1 つと床が 1 枚**だけで、絵になっているのは
/// そのどちらでもなく**影**である。塊は読めない形をしていて、3 つの決まった角度で
/// 止まったときにだけ、床の影が円・三角・四角になる。
///
/// ## 影は「高さに比例した平行移動」でしかない
///
/// 向きを持つ光の下では、点の影は `(X, Z) + κ·Y·e` で決まる (``Shear``)。回すのは
/// 縦軸まわりなので高さ `Y` は動かず、**ずれの項は 3 つの姿勢で共通**である。だから
/// 塊を「高さで切った層」は、同じ 1 つのずれを受けた向きだけ違う 3 枚として効く。
/// 光を真上から差すとずれが 0 になり、**3 つの影は完全に同じ絵になる** — 作り分けは
/// 原理的にできなくなる。この作品が斜めの光でしか成り立たない理由がこれである。
///
/// ## 彫り出しは「3 つとも内側」だけを残す
///
/// 格子のセルを 3 つの姿勢すべてで床へ落とし、3 つとも狙いの内側に入るセルだけを
/// 残す (``Carve``)。セル 1 個の影の大きさぶんの余裕を引いてから判定しているので、
/// **影が狙いの外へ出ることは原理的に起きない**。起こるのは欠けだけで、どれだけ
/// 埋まったかは立ち上げに 1 度数えて名乗る (``Cover``)。
///
/// ## 48 秒を 4 つの幕で渡る
///
/// 影だけの床から始まり (幕 1)、塊が 3 つの姿勢を渡り (幕 2)、粒へ砕けて光の筋に
/// 沿って伸び (幕 3)、最後は塊を止めたまま光のほうが 1 周する (幕 4)。**どの幕も
/// 同じ 1 つの式の別の見え方**で、譜は ``Score`` が持つ。
///
/// ## 状態は再生位置だけ
///
/// 絵は時刻の関数である。時刻を渡すと ``Score/Frame`` が決まり、そこから下は時計を
/// 読まない。乱数も雑音も使わず、`frameCount` も読まない。**同じ時刻からは同じ絵が
/// 出る。**
final class Cast: Sketch {
    var settings = SketchSettings(width: 1920, height: 1080, title: "cast")

    // MARK: - 時計 (ここだけが状態)

    /// 再生位置 (秒)。
    private(set) var playhead: Float = 0
    /// 動いているか。
    private var isPlaying = true
    private var isScrubbing = false

    // MARK: - 焼いたもの

    /// 塊。**走り出してから 1 度だけ彫って焼く。**
    private var mass: Shape?
    /// 粒 1 つぶんの立方体。**1 つ焼いて、置き場所を配る。**
    private var cube: Shape?
    /// 粒の置き場所のもと。
    private var grains: [Grains.Grain] = []
    private var baked = false
    /// 彫りに掛かった時間 (ミリ秒)。
    private var carveMs: Float = 0
    /// 焼きに掛かった時間 (ミリ秒)。
    private var bakeMs: Float = 0
    /// 数えるのに掛かった時間 (ミリ秒)。
    private var coverMs: Float = 0
    /// 格子の節の数。
    private var cells = 0
    private var faces = 0
    /// 3 つの狙いをどれだけ埋めたか。
    private var coverage: [Cover.Result] = []

    /// 姿勢 3 つの角度。
    static let turns: [Float] = (0..<3).map { Float($0) * 2 * .pi / 3 }

    func setup() {
        // 影の濃さをそのまま出す。**肩を丸めると影と床の差が縮む** (`.clip` は 0…1 の内側を 1 ビットも変えない)
        exposure(1.0)
        toneMapping(.clip)
    }

    func draw() {
        bakeIfNeeded()

        // **飛んだフレームで時間を飛ばさない。** 作り直しの後の 1 フレーム目が長い
        if isPlaying, !isScrubbing {
            playhead += min(deltaTime, 1.0 / 20)
        }
        // **ここから下は時計を読まない。** 絵はこの 1 つの構造体の関数である
        let frame = Score.frame(at: playhead)

        stage(frame)
        rule()
        if let mass { place(mass, frame: frame) }
        if let cube { scatter(cube, grains: grains, frame: frame) }
        trace(frame)
        dress(frame)

        let (kind, settled) = aim(frame)
        expose("time", frame.time)
        expose("act", frame.act.name)
        expose("turn", frame.turn * 180 / .pi)
        expose("azimuth", frame.azimuth * 180 / .pi)
        expose("aim", kind.name)
        expose("settled", settled)
        expose("massVeil", frame.mass)
        expose("grainVeil", frame.grains)
        expose("spread", frame.spread)
        expose("wave", frame.wave)
        expose("pull", frame.pull)
        expose("grains", grains.count)
        expose("playing", isPlaying)
        expose("nodes", cells)
        expose("faces", faces)
        expose("vertices", mass?.vertexCount ?? 0)
        expose("draws", mass?.drawCallCount ?? 0)
        expose("carveMs", carveMs)
        expose("bakeMs", bakeMs)
        expose("coverMs", coverMs)
        expose("shadowRange", Stage.range(for: frame))
        for result in coverage {
            expose("covered:\(result.kind.name)", result.covered * 100)
            // **はみ出しは 0 のはず。** 0 でなければ彫り出しの式が間違っている
            expose("spill:\(result.kind.name)", result.spill * 100)
        }
    }

    // MARK: - 彫って焼く

    /// 走り出してから 1 度だけ彫り、焼き、数える。
    ///
    /// **`setup()` ではなく最初のフレームでやる。** `setup()` の中で `createShape` を
    /// 呼ぶと、中の `fill` / `noStroke` が「どのフレームにも属さないスタイル」として
    /// 捨てられる (mokume が警告を出す)。
    private func bakeIfNeeded() {
        guard !baked else { return }
        baked = true

        var began = Date()
        let lattice = Carve.lattice(turns: Cast.turns)
        carveMs = Float(Date().timeIntervalSince(began) * 1000)
        cells = lattice.values.count

        began = Date()
        let surface = Surface.mesh(lattice, turns: Cast.turns)
        faces = surface.faces
        mass = form(surface.corners)
        grains = Grains.pick(lattice, turns: Cast.turns)
        cube = block()
        bakeMs = Float(Date().timeIntervalSince(began) * 1000)

        began = Date()
        coverage = Cover.measure(lattice, turns: Cast.turns)
        coverMs = Float(Date().timeIntervalSince(began) * 1000)
    }

    /// 頂点の並びを 1 つの形へ焼く。
    ///
    /// 塗りは 1 色だけ。**明るさは光が作る** — 面の向きは節ごとに連続に変わるので
    /// (``Surface/slope(at:turns:step:)``)、塗りで明暗を足す必要がない。
    private func form(_ corners: [Surface.Corner]) -> Shape {
        createShape {
            noStroke()
            fill(Palette.mass.x, Palette.mass.y, Palette.mass.z)
            beginShape(.triangles)
            for corner in corners {
                // **縦軸は下向き**なので、位置も法線も y を裏返して渡す
                normal(corner.normal.x, -corner.normal.y, corner.normal.z)
                vertex(corner.position.x, -corner.position.y, corner.position.z)
            }
            endShape()
        }
    }

    /// 粒 1 つぶんの立方体を焼く。
    private func block() -> Shape {
        createShape {
            noStroke()
            fill(Palette.mass.x, Palette.mass.y, Palette.mass.z)
            box(Field.grain)
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

    /// 横の位置を時刻へ写す。**下に敷いた定規と同じ物差しを使う** (``Ruler``)。
    private func scrub() {
        playhead = Ruler.time(atX: mouseX)
    }

    func keyPressed() {
        switch keyCode {
        case Key.space:
            isPlaying.toggle()
        case Key.arrowLeft, Key.arrowRight:
            playhead = Score.wrap(playhead + (keyCode == Key.arrowRight ? 0.25 : -0.25))
        case Key.digit1, Key.digit2, Key.digit3, Key.digit4:
            let keys: [Key] = [.digit1, .digit2, .digit3, .digit4]
            if let index = keys.firstIndex(where: { $0 == keyCode }),
                index < Score.Act.allCases.count
            {
                playhead = Score.start(of: Score.Act.allCases[index])
            }
        default:
            break
        }
    }
}
