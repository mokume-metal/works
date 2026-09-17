import Foundation
import mokume
import simd

/// Apex — 3 周を走って順位を競う。
///
/// **works で勝ち負けのある 1 本目。** 13 本の作品はどれも終わらない眺めで、触れる
/// Prism・Quarry・Marble にも目的や終わりは無かった。ここには始まりと終わりがあり、
/// 相手がいる。
final class Apex: Sketch {
    var settings = SketchSettings(width: 1280, height: 720, title: "apex")

    // MARK: - 世界

    var track = Track.build()
    var road: Shape = .empty
    var ground: Shape = .empty
    var tree: Shape = .empty
    private var grove: [Placement] = []
    var shell: Shape = .empty
    var trim: Shape = .empty
    var wheel: Shape = .empty
    private var raised = false

    // MARK: - 走るもの

    /// 走っている車。**0 番が自分。**
    var cars: [Car] = []
    /// 相手の運転。
    let rivals = Rival.field
    var race = Race(count: 1 + Rival.field.count)

    /// 自分の車。
    var car: Car { cars.first ?? Car(place: .zero, yaw: 0) }
    private var chase = Chase()

    /// 地図に描く中心線 (間引いたもの) と、その外接と縮尺。
    var mapLine: [SIMD2<Float>] = []
    var mapLow = SIMD2<Float>(repeating: 0)
    var mapHigh = SIMD2<Float>(repeating: 0)
    var mapScale: Float = 0
    /// 何か触ったか。**触ったら手引きを引っ込める。**
    var touched = false

    /// 物理の刻み (秒)。**フレームの長さではなく固定**にするのは、同じ操作から
    /// 同じ走りが出るようにするため
    private static let tick: Float = 1.0 / 120
    /// 1 フレームに進める歩数の上限。**追いつけないときは時間を捨てる** —
    /// 捨てないと「遅れているから多く歩く → もっと遅れる」の螺旋に入る
    private static let maxSteps = 8
    /// 影を焼く四角の一辺 (単位)。**140 m** — 車のまわりと、前の車の影が入る広さ。
    private static let shadowSpan: Float = 1400
    private var pending: Float = 0

    // MARK: - 数えるもの

    private var verts = 0
    /// コースを組んで焼くのにかかった時間 (ミリ秒)。
    private var bakeMs: Float = 0
    private var steps = 0

    func setup() {
        // **画面の性質なのでフレームを越える。** `setup()` で積んだ描画のスタイルは
        // 捨てられるが、露出と丸め方はここから効く (Prism・Pond・Cast と同じ)
        exposure(1.0)
        toneMapping(.roll)
        noiseSeed(4021)
    }

    func draw() {
        if !raised { raise() }

        background(Scenery.sky)

        drive()
        chase.follow(car, on: track, dt: deltaTime, jitter: 0)
        look()

        ambientLight(96, 104, 118)
        // **光の向きも y を反転して渡す。** 世界の上から差す光が、絵でも上から差すように。
        // **影を落とすのは向きを持つ光の 1 本目だけ**なので、これがその 1 本になる。
        // 真上に近いと影が車の真下に潰れるので、**太陽は低く置く** (仰角 33 度)
        directionalLight(255, 244, 228, -0.58, -0.54, 0.61)

        // **影の切り取りは、いまの注視点を中心に取られる。** 追うカメラでは注視点が
        // 車の少し先にあるので、車のまわりだけを高い細かさで焼ける。範囲が足りないと
        // 暗くなるのではなく**四角く切れる**
        shadows(true)
        shadowDetail(1024)
        shadowRange(Apex.shadowSpan)
        // **世界での太さは bias × 2 × range。** 範囲が広いほど同じ値が太く効くので、
        // 0.0016 (= 45 cm) では車の影が消えた。0.0005 は 1.4 単位 (14 cm)
        shadowBias(0.0005)

        noStroke()
        // **地面と路面は受けるだけ。** 落とす側に入れると自分の影で暗くなる
        castShadow(false)
        receiveShadow(true)
        shape(ground)
        shape(road)

        // **木は影を落とさない。** 109 本ぶんを焼き付けに入れると、観測が絵を
        // 書き出すフレームで GPU が間に合わなくなった。落ちるのが見たいのは車の影である
        castShadow(false)
        receiveShadow(false)
        // **木は 1 回の描画で全部置く。** 置き場所ごとに向きと大きさが効く
        shape(tree, at: grove)

        // **車だけが影を落とす。** 受ける側に入れると、凸な立体でも縞 (シャドウアクネ) が出る
        castShadow(true)
        for (index, car) in cars.enumerated() {
            put(car, colour: Palette.cars[index % Palette.cars.count], on: track)
        }
        dash()

        // **描き終わりに 1 回。** 昼の屋外なので光の滲みは控えめにし、
        // 四隅を落として画面の中央へ目を寄せる
        effects([.bloom(amount: 0.32, threshold: 0.74, radius: 16), .vignette(amount: 0.22)])

        expose("kmh", car.kmh)
        expose("slip", car.slip * 180 / Float.pi)
        expose("radiusM", car.turnRadius / 10)
        expose("surface", car.surface.name)
        expose("s", car.s / 10)
        expose("d", car.lateral / 10)
        expose("steps", steps)
        expose("lapMeters", track.length / 10)
        expose("verts", verts)
        expose("trees", grove.count)
        expose("lap", race.shownLap(of: 0))
        expose("pos", race.standing(of: 0) + 1)
        expose("drafting", car.drafting)
        // 相手の走り。**外から見て、AI がちゃんと回っているかを確かめるため**
        expose("leadLap", race.runners.map(\.lap).max() ?? 0)
        expose("leadBest", race.runners.compactMap(\.best).min() ?? -1)
        expose("clock", race.clock)
        expose("phase", "\(race.phase)")
        expose("best", race.runners[0].best ?? -1)
        expose("bakeMs", bakeMs)
    }

    // MARK: - 立てる

    /// コースを組んで焼く。
    ///
    /// **`setup()` ではなく最初のフレームでやる。** `setup()` の中で `createShape` を
    /// 呼ぶと、中の `fill` / `noStroke` が「どのフレームにも属さないスタイル」として
    /// 捨てられる (mokume が警告を出す)
    private func raise() {
        raised = true
        let began = Date()
        track = Track.build()
        // 舗装の陰をリングごとに揺らす。**同じ絵の繰り返しにしないため**で、
        // 走ると路面のむらが流れて速さが読める
        let corners = Road.bake(track) { s in 0.94 + 0.12 * self.noise(s * 0.004) }
        road = form(corners)
        verts = corners.count

        var middle = SIMD2<Float>(repeating: 0)
        for sample in track.samples { middle += sample.point }
        middle /= Float(track.count)
        ground = form(Scenery.ground(centre: middle, reach: 9000))
        tree = form(Scenery.tree())
        drawChart()
        grove = Scenery.trees(along: track) { a, b in self.noise(a, b) }
        shell = bakeShell()
        trim = bakeTrim()
        wheel = bakeWheel()
        bakeMs = Float(Date().timeIntervalSince(began) * 1000)
        restart()
    }

    /// スタートラインの手前へ並べ直す。
    func restart() {
        race = Race(count: 1 + rivals.count)
        // **ラインの手前の直線に並べる。** 制御点を組み直して、スタートラインの
        // 前後が直線になるようにしてある。左右へ振り分けるのは実際のグリッドと同じ
        cars = (0...rivals.count).map { index in
            let grid = track.frame(at: track.length - (70 + Float(index) * 95))
            let hand: Float = index % 2 == 0 ? -28 : 28
            var car = Car(place: grid.point + Track.side(grid.heading) * hand, yaw: grid.heading)
            car.settle(on: track)
            return car
        }
        // **並べた場所を先に知らせておく。** 周回は距離の巻き戻りで数えるので、
        // 始まりの距離が入っていないと 1 歩目で誤って数える
        for index in cars.indices {
            race.note(index, s: cars[index].s, length: track.length)
        }
        chase.snap(to: cars[0], on: track)
        pending = 0
    }

    /// 頂点の並びを 1 つの形へ焼く。
    ///
    /// **y はここで反転する。** 世界は上向きで持ち、渡す直前に符号を変える
    func form(_ corners: [Corner]) -> Shape {
        guard !corners.isEmpty else { return .empty }
        return createShape {
            noStroke()
            beginShape(.triangles)
            for corner in corners {
                // **塗りは頂点ごとに置く。** 明示しないと 1 枚も置かれない
                fill(corner.r, corner.g, corner.b)
                normal(corner.nx, -corner.ny, corner.nz)
                vertex(corner.x, -corner.y, corner.z)
            }
            endShape()
        }
    }

    // MARK: - 走る

    /// 固定の刻みで物理を進める。
    private func drive() {
        let pedals = wheelAndPedals()
        // **窓を掴んで離したときの巨大な間隔を捨てる。** `mokume watch` の作り直しの
        // 直後も 1 フレームが長い
        pending += min(deltaTime, 0.25)
        steps = 0
        while pending >= Apex.tick, steps < Apex.maxSteps {
            race.advance(Apex.tick)
            // **待っている間は踏んでも進まない。** 合図より前に踏み始められると、
            // 計時の始まりが人によって変わってしまう
            var wishes = [Controls](repeating: Controls(), count: cars.count)
            if race.phase == .running {
                wishes[0] = pedals
                for index in 1..<cars.count {
                    wishes[index] = rivals[index - 1].drive(
                        cars[index], on: track, others: cars, at: time) { self.noise($0) }
                }
            }
            // **待っている間は動かさない。** 物理を進めると、グリッドが坂にかかって
            // いるだけで転がり出す (合図の前に 15 km/h まで出た)
            if race.phase != .waiting {
                // **後ろに付くと空気が薄くなる。** 誰にでも等しく効くので、相手の性能を
                // 順位で上下させる (いわゆるラバーバンド) を持たずに追い抜きが起きる
                for index in cars.indices { cars[index].drafting = drafting(index) }
                for index in cars.indices {
                    cars[index].advance(Apex.tick, controls: wishes[index], on: track)
                    cars[index].bounce(on: track)
                }
                bump()
            }
            // **待っている間も位置は知らせる。** 知らせないと「前のフレームの距離」が
            // 0 のまま走り出し、最初の 1 歩が「1 周ぶん戻った」と数えられる
            for index in cars.indices {
                race.note(index, s: cars[index].s, length: track.length)
            }
            pending -= Apex.tick
            steps += 1
        }
        if steps == Apex.maxSteps { pending = 0 }
        race.settle()
    }

    /// 前の車の後ろに付いているか。
    private func drafting(_ index: Int) -> Bool {
        let me = cars[index]
        for (other, car) in cars.enumerated() where other != index {
            let gap = Rival.gap(from: me.s, to: car.s, length: track.length)
            if gap > 14, gap < 200, abs(car.lateral - me.lateral) < 30 { return true }
        }
        return false
    }

    /// 車同士の当たり。**半径 2.2 m の円で見て、重なりを押し戻す。**
    ///
    /// 後ろから当たれば前後の、並走で当たれば横の運動量が移る — どちらも
    /// 押し戻す向き 1 つから出る
    private func bump() {
        for a in cars.indices {
            for b in (a + 1)..<cars.count {
                let apart = cars[b].place - cars[a].place
                let distance = simd_length(apart)
                let overlap = Car.radius * 2 - distance
                guard overlap > 0, distance > 0.01 else { continue }
                let axis = apart / distance
                cars[a].place -= axis * (overlap / 2)
                cars[b].place += axis * (overlap / 2)
                let closing = simd_dot(cars[b].velocity - cars[a].velocity, axis)
                guard closing < 0 else { continue }
                let shove = -closing * 0.35
                cars[a].velocity -= axis * shove
                cars[b].velocity += axis * shove
            }
        }
    }

    /// いま押されているものを操作へ直す。
    ///
    /// **押しっぱなしは `isKeyDown` で見る。** `keyPressed()` は押しっぱなしで
    /// 連射されるので、状態の判定には向かない
    private func wheelAndPedals() -> Controls {
        var wish = Controls()
        if isKeyDown(.w) || isKeyDown(.arrowUp) { wish.throttle = 1 }
        if isKeyDown(.s) || isKeyDown(.arrowDown) { wish.brake = 1 }
        if isKeyDown(.a) || isKeyDown(.arrowLeft) { wish.steer -= 1 }
        if isKeyDown(.d) || isKeyDown(.arrowRight) { wish.steer += 1 }
        wish.handbrake = isKeyDown(.space)
        return wish
    }

    func keyPressed() {
        touched = true
        if keyCode?.rawValue == Key.r.rawValue { restart() }
    }

    // MARK: - 見る

    /// 地図に描く中心線を間引いて持つ。**毎フレーム 600 点を引くのは重いので。**
    private func drawChart() {
        mapLine = []
        var low = SIMD2<Float>(repeating: .greatestFiniteMagnitude)
        var high = SIMD2<Float>(repeating: -.greatestFiniteMagnitude)
        let step = max(track.count / 180, 1)
        for index in stride(from: 0, to: track.count, by: step) {
            let point = track.samples[index].point
            mapLine.append(point)
            low = simd_min(low, point)
            high = simd_max(high, point)
        }
        mapLow = low
        mapHigh = high
        let span = high - low
        // **地図の枠に収める。** 縦横のきつい方に合わせる
        mapScale = min(168 / max(span.x, 1), 168 / max(span.y, 1)) * 0.92
    }

    func look() {
        // **世界は y 上向き、渡すのは下向き。**
        camera(
            chase.eye.x, -chase.eye.y, chase.eye.z,
            chase.look.x, -chase.look.y, chase.look.z, 0, 1, 0)
        perspective(chase.lens, width / height, 6, 26000)
    }
}
