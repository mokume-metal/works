import Foundation
import mokume
import simd

/// Quarry — 掘って積むボクセル世界。
///
/// **世界は形として焼いてある。** 128 × 128 × 64 = 100 万個のブロックを立方体として
/// 置くのではなく、チャンク (16 × 16 × 64) ごとに**隣が空いている面だけ**を集めて
/// `createShape` で 1 つの形へ焼き、毎フレームその形を置く。掘ったらそのチャンクだけ
/// 焼き直す — **走っている最中に形を作り直す**のは、works ではここが初めてである。
///
/// ## 世界は y 上向き、描くときだけ反転する
///
/// mokume の縦軸は下向きなので、世界をそのまま渡すと天地が逆になる。かといって世界を
/// 下向きで持つと「高さ」が「深さ」になって読めない。**`World` は y 上向きで持ち、
/// 頂点・法線・カメラを渡す直前に符号を反転する。** 反転は鏡映なので巻きが裏返るが、
/// mokume の投影も縦を反転するので、`Mesher` の並べた順のまま表を向く。
///
/// ## 触ると世界そのものが変わる
///
/// Prism は場面を動かせたが、動くのは光源と硝子の向きだけで、形は最初から最後まで
/// 同じだった。ここでは**掘った穴も積んだ塔も世界に残る**ので、フレームをまたいで
/// 状態が積み上がる。同じフレーム番号から同じ絵が出るのは**触っていない限り**である
final class Quarry: Sketch {
    var settings = SketchSettings(width: 1280, height: 720, title: "quarry")

    // MARK: - 世界

    private let world = World()
    private var walker = Walker(place: .zero)
    private var atlas: Image?

    /// チャンクごとに焼いた形。**固いものと水は別** — 水は後から重ねる。
    private var ground: [Shape] = []
    private var pools: [Shape] = []
    private var raised = false

    // MARK: - 触る

    /// 押されているキー。**`keyPressed` / `keyReleased` で自前に持つ。**
    private var held: Set<Int> = []
    /// 目で選んでいるブロック。
    private var aim: Hit?
    /// 手に持っている種類の番号。
    private var holding = 0
    /// 押してから離すまでに動いた量 (画素)。**クリックとドラッグはこれで分ける。**
    private var swept: Float = 0
    /// 何か触ったか。**触ったら手引きを引っ込める。**
    private var touched = false

    // MARK: - 数えるもの

    private var bakes = 0
    private var faces = 0
    /// 世界を立てるのにかかった時間 (ミリ秒)。
    private var raiseMs: Float = 0
    /// チャンクごとの面の数。**`Shape.vertexCount` は焼き直しても動かなかった**ので、
    /// 焼いた並びの長さを自分で覚えている
    private var faceCount = [Int](repeating: 0, count: World.chunkCount)
    private var drawn = 0


    func draw() {
        if !raised { raise() }

        let weather = Sky.weather(at: time)
        background(weather.around)

        // **焼き直しは 1 フレームに 2 枚まで。** 掘るたびに数千の面を組み直すので、
        // まとめて焼くとその 1 フレームだけ伸びる
        for _ in 0..<2 {
            guard let chunk = world.takeStale() else { break }
            rebake(chunk)
        }

        walk()
        look()

        ambientLight(weather.ambient.0, weather.ambient.1, weather.ambient.2)
        // **光の向きも反転して渡す。** 世界の上から差す光が、絵でも上から差すように
        directionalLight(
            weather.sun.0, weather.sun.1, weather.sun.2,
            weather.toward.x, -weather.toward.y, weather.toward.z)

        noStroke()
        drawn = 0
        for chunk in 0..<World.chunkCount where inSight(chunk) {
            shape(ground[chunk])
            drawn += 1
        }
        // 水は固いものの後。**半透明は後ろから前へ重ねる約束**なので、地形を先に置く
        for chunk in 0..<World.chunkCount where inSight(chunk) {
            shape(pools[chunk])
        }

        aim = Pick.trace(from: walker.eye, along: walker.heading, in: world)
        drawAim()
        drawPanel(weather)

        expose("x", walker.place.x / World.scale)
        expose("y", walker.place.y / World.scale)
        expose("z", walker.place.z / World.scale)
        expose("faces", faces)
        expose("bakes", bakes)
        expose("chunks", drawn)
        expose("sun", weather.elevation)
        expose("aim", aim != nil)
        expose("raiseMs", raiseMs)
    }

    // MARK: - 立てる

    /// 世界を立てて、全部のチャンクを焼く。
    ///
    /// **`setup()` ではなく最初のフレームでやる。** `setup()` の中で `createShape` を
    /// 呼ぶと、中の `fill` / `noStroke` が「どのフレームにも属さないスタイル」として
    /// 捨てられる (mokume が警告を出す)
    private func raise() {
        raised = true
        let began = Date()

        if let picture = try? createImage(Tiles.pixels, Tiles.pixels) {
            Tiles.paint(picture)
            atlas = picture
        }

        Terrain.raise(world) { x, z in self.noise(x, z) }

        ground = Array(repeating: .empty, count: World.chunkCount)
        pools = Array(repeating: .empty, count: World.chunkCount)
        for chunk in 0..<World.chunkCount { rebake(chunk) }

        raiseMs = Float(Date().timeIntervalSince(began) * 1000)
        let start = clearing()
        walker = Walker(place: start)
        // **太陽を背にして始める。** 逆光だと最初の絵で面の向きが読めない
        walker.yaw = 0.7 + .pi
        walker.pitch = -0.12
    }

    /// 立つ場所を探す。
    ///
    /// **真ん中に降ろすだけでは木の中に立つ。** 最初に見える絵が葉の裏側だと、
    /// 何の世界なのかが分からない。真ん中から渦を巻いて広げ、**草の上で、頭の上が
    /// 3 段空いている**ところを探す
    private func clearing() -> SIMD3<Float> {
        let middle = World.span / 2
        for radius in 0..<28 {
            for step in 0...(radius * 8) {
                let ring = max(radius * 8, 1)
                let angle = Float(step) / Float(ring) * 2 * Float.pi
                let x = middle + Int(cos(angle) * Float(radius))
                let z = middle + Int(sin(angle) * Float(radius))
                guard World.inside(x, 0, z) else { continue }
                let top = world.surface(x: x, z: z)
                guard world.at(x, top, z) == .grass else { continue }
                guard (1...3).allSatisfy({ world.at(x, top + $0, z) == .air }) else { continue }
                // **木の真横は開けていない。** 頭の上が空いていても、幹が目の前に
                // 立っていると最初の絵が樹皮で埋まる
                guard open(around: x, z, top: top) else { continue }
                return SIMD3(
                    (Float(x) + 0.5) * World.scale, Float(top + 1) * World.scale,
                    (Float(z) + 0.5) * World.scale)
            }
        }
        let top = world.surface(x: middle, z: middle)
        return SIMD3(
            (Float(middle) + 0.5) * World.scale, Float(top + 1) * World.scale,
            (Float(middle) + 0.5) * World.scale)
    }

    /// まわり 3 ブロックに木が無いか。
    private func open(around x: Int, _ z: Int, top: Int) -> Bool {
        for dz in -3...3 {
            for dx in -3...3 {
                for dy in 1...4 {
                    let block = world.at(x + dx, top + dy, z + dz)
                    if block == .log || block == .leaves { return false }
                }
            }
        }
        return true
    }

    /// チャンクを 1 枚焼き直す。
    private func rebake(_ chunk: Int) {
        let mesh = Mesher.bake(chunk: chunk, of: world)
        ground[chunk] = form(mesh.solid)
        pools[chunk] = form(mesh.water)
        bakes += 1
        faceCount[chunk] = (mesh.solid.count + mesh.water.count) / 6
        faces = faceCount.reduce(0, +)

    }

    /// 頂点の並びを 1 つの形へ焼く。
    ///
    /// **`texture()` は `beginShape` より前。** 後に置くと uv が黙って捨てられ、
    /// 面はアトラスの左上の 1 点を読む
    private func form(_ corners: [Corner]) -> Shape {
        guard !corners.isEmpty else { return .empty }
        return createShape {
            noStroke()
            // 貼る絵は塗りに掛かるので白。**塗りを明示しないと 1 枚も置かれない**
            fill(255, 255, 255)
            if let atlas { texture(atlas) }
            beginShape(.triangles)
            for corner in corners {
                normal(corner.nx, -corner.ny, corner.nz)
                vertex(corner.x, -corner.y, corner.z, corner.u, corner.v)
            }
            endShape()
        }
    }

    // MARK: - 見る

    /// カメラを目に合わせる。
    private func look() {
        let eye = walker.eye
        let at = eye + walker.heading * 100
        camera(eye.x, -eye.y, eye.z, at.x, -at.y, at.z, 0, 1, 0)
        // **視野は 74 度。** Minecraft の既定より少し広い — 掘っている手元と、
        // 掘っている場所の周りが同時に入る
        perspective(radians(74), width / height, 8, 16000)
    }

    /// そのチャンクを描くか。**後ろのチャンクは置かない。**
    private func inSight(_ chunk: Int) -> Bool {
        let origin = World.chunkOrigin(chunk)
        let middle = SIMD3<Float>(
            (Float(origin.x) + 8) * World.scale, walker.eye.y,
            (Float(origin.z) + 8) * World.scale)
        let toward = middle - walker.eye
        let distance = simd_length(toward)
        guard distance > 1200 else { return true }
        let facing = walker.heading
        return simd_dot(simd_normalize(toward), SIMD3(facing.x, 0, facing.z)) > -0.35
    }

    // MARK: - 歩く

    private func walk() {
        let step = min(deltaTime, 1.0 / 20)

        var wish = SIMD2<Float>(0, 0)
        if isHeld(.w) { wish.x += 1 }
        if isHeld(.s) { wish.x -= 1 }
        if isHeld(.a) { wish.y -= 1 }
        if isHeld(.d) { wish.y += 1 }

        walker.step(dt: step, wish: wish, jump: isHeld(.space), in: world)

        // 世界の外へ出さない
        let edge = Float(World.span) * World.scale
        walker.place.x = min(max(walker.place.x, 60), edge - 60)
        walker.place.z = min(max(walker.place.z, 60), edge - 60)
        if walker.place.y < -400 {
            let middle = World.span / 2
            walker.place = SIMD3(
                (Float(middle) + 0.5) * World.scale,
                Float(world.surface(x: middle, z: middle) + 2) * World.scale,
                (Float(middle) + 0.5) * World.scale)
            walker.speed = .zero
        }
    }

    private func isHeld(_ key: Key) -> Bool { held.contains(key.rawValue) }

    // MARK: - 描き足すもの

    /// 選んでいるブロックの輪郭。**12 本の線で囲う。**
    ///
    /// 面を塗って重ねると z が競って散らつくので、**外へ 2 単位ふくらませた枠**にしてある
    private func drawAim() {
        guard let aim else { return }
        let scale = World.scale
        let low = SIMD3<Float>(Float(aim.x), Float(aim.y), Float(aim.z)) * scale
            - SIMD3(repeating: 2)
        let high = low + SIMD3(repeating: scale + 4)

        stroke(20, 20, 24, 190)
        strokeWeight(2.5)
        noFill()
        beginShape(.lines)
        for (a, b) in Self.edges {
            let p = SIMD3(a.0 == 0 ? low.x : high.x, a.1 == 0 ? low.y : high.y, a.2 == 0 ? low.z : high.z)
            let q = SIMD3(b.0 == 0 ? low.x : high.x, b.1 == 0 ? low.y : high.y, b.2 == 0 ? low.z : high.z)
            vertex(p.x, -p.y, p.z)
            vertex(q.x, -q.y, q.z)
        }
        endShape()
        noStroke()
    }

    /// 立方体の 12 辺。
    private static let edges: [((Int, Int, Int), (Int, Int, Int))] = [
        ((0, 0, 0), (1, 0, 0)), ((1, 0, 0), (1, 0, 1)), ((1, 0, 1), (0, 0, 1)),
        ((0, 0, 1), (0, 0, 0)), ((0, 1, 0), (1, 1, 0)), ((1, 1, 0), (1, 1, 1)),
        ((1, 1, 1), (0, 1, 1)), ((0, 1, 1), (0, 1, 0)), ((0, 0, 0), (0, 1, 0)),
        ((1, 0, 0), (1, 1, 0)), ((1, 0, 1), (1, 1, 1)), ((0, 0, 1), (0, 1, 1)),
    ]

    /// 手元の表示 — 狙い、持っているもの、はじめの手引き。
    private func drawPanel(_ weather: Sky.Weather) {
        camera()
        perspective()
        noLights()
        blendMode(.blend)

        // 水に沈んだら青くかぶせる
        if walker.submerged {
            noStroke()
            fill(30, 90, 165, 90)
            rect(0, 0, width, height)
        }

        // 狙い — 中央の十字
        stroke(245, 245, 245, 180)
        strokeWeight(2)
        let mid = SIMD2<Float>(width / 2, height / 2)
        line(mid.x - 9, mid.y, mid.x + 9, mid.y)
        line(mid.x, mid.y - 9, mid.x, mid.y + 9)
        noStroke()

        // 持っているもの
        let slot: Float = 52
        let gap: Float = 6
        let total = Float(Block.inHand.count) * (slot + gap) - gap
        var x = (width - total) / 2
        let y = height - slot - 24
        for (index, block) in Block.inHand.enumerated() {
            let chosen = index == holding
            fill(18, 18, 22, chosen ? 210 : 120)
            rect(x - 3, y - 3, slot + 6, slot + 6)
            if let atlas {
                let tile = Tiles.origin(of: block.tile(on: .south))
                image(
                    atlas, x, y, slot, slot, tile.x, tile.y, Float(Tiles.size),
                    Float(Tiles.size))
            }
            if chosen {
                stroke(250, 250, 250, 230)
                strokeWeight(2)
                noFill()
                rect(x - 4, y - 4, slot + 8, slot + 8)
                noStroke()
            }
            x += slot + gap
        }

        // はじめの手引き。**触ったら引っ込む。**
        let fade = touched ? 0 : min(max((14 - time) / 3, 0), 1)
        if fade > 0.01 {
            fill(250, 250, 252, 200 * fade)
            textSize(20)
            let lines = [
                "W A S D — 歩く / Space — 跳ぶ",
                "ドラッグ — 見まわす",
                "クリック — 掘る / 右クリック — 積む",
                "1…7 — 持ちかえる",
            ]
            for (index, line) in lines.enumerated() {
                text(line, 40, 52 + Float(index) * 30)
            }
        }
    }

    // MARK: - 触る

    func mousePressed() {
        swept = 0
        touched = true
    }

    func mouseDragged(deltaX: Float, deltaY: Float) {
        walker.turn(by: SIMD2(deltaX, deltaY))
        swept += abs(deltaX) + abs(deltaY)
        touched = true
    }

    /// 離したところで決める。
    ///
    /// **ドラッグとクリックを分けるため。** 見まわすのも掘るのも同じボタンなので、
    /// 押した瞬間に掘ると、振り向こうとしただけで足元に穴が開く
    func mouseReleased() {
        guard swept < 6 else { return }
        guard let aim else { return }
        if mouseButton == 0 {
            world.set(aim.x, aim.y, aim.z, .air)
        } else {
            let place = aim.beside
            // 自分の体に重ねて置かせない
            guard !overlapsBody(place) else { return }
            world.set(place.x, place.y, place.z, Block.inHand[holding])
        }
    }

    /// 置こうとしている場所が自分と重なるか。
    private func overlapsBody(_ cell: (x: Int, y: Int, z: Int)) -> Bool {
        let half = Walker.girth / 2
        let low = SIMD3(walker.place.x - half, walker.place.y, walker.place.z - half)
        let high = SIMD3(
            walker.place.x + half, walker.place.y + Walker.stature, walker.place.z + half)
        let cellLow = SIMD3(Float(cell.x), Float(cell.y), Float(cell.z)) * World.scale
        let cellHigh = cellLow + SIMD3(repeating: World.scale)
        return low.x < cellHigh.x && high.x > cellLow.x && low.y < cellHigh.y
            && high.y > cellLow.y && low.z < cellHigh.z && high.z > cellLow.z
    }

    func keyPressed() {
        touched = true
        guard let code = keyCode else { return }
        held.insert(code.rawValue)

        let digits: [Key] = [.digit1, .digit2, .digit3, .digit4, .digit5, .digit6, .digit7]
        for (index, digit) in digits.enumerated() where code.rawValue == digit.rawValue {
            holding = min(index, Block.inHand.count - 1)
        }
    }

    func keyReleased() {
        if let code = keyCode { held.remove(code.rawValue) }
    }
}
