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

    var car = Car(place: .zero, yaw: 0)
    var race = Race(count: 1)
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
    private var pending: Float = 0

    // MARK: - 数えるもの

    private var verts = 0
    /// コースを組んで焼くのにかかった時間 (ミリ秒)。
    private var bakeMs: Float = 0
    private var steps = 0
    private var restarts = 0
    /// 最後に届いたキー。**入力が届いているかを外から見るため。**
    private var lastKey = -1

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
        chase.follow(car, on: track, dt: deltaTime, jitter: noise(time * 23) - 0.5)
        look()

        ambientLight(96, 104, 118)
        // **光の向きも y を反転して渡す。** 世界の上から差す光が、絵でも上から差すように
        directionalLight(255, 246, 232, -0.42, -0.78, 0.46)

        noStroke()
        shape(ground)
        shape(road)
        // **木は 1 回の描画で全部置く。** 置き場所ごとに向きと大きさが効く
        shape(tree, at: grove)
        put(car, colour: Palette.cars[0], on: track)
        dash()

        expose("kmh", car.kmh)
        expose("slip", car.slip * 180 / Float.pi)
        expose("radiusM", car.turnRadius / 10)
        expose("surface", car.surface.name)
        expose("s", car.s / 10)
        expose("d", car.lateral / 10)
        expose("steps", steps)
        expose("restarts", restarts)
        expose("lastKey", lastKey)
        expose("lapMeters", track.length / 10)
        expose("verts", verts)
        expose("trees", grove.count)
        expose("lap", race.shownLap(of: 0))
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

    /// スタートラインの手前へ置き直す。
    func restart() {
        // **いまは直線の途中から始める。** グリッドに並べるのは計時を入れてから
        let grid = track.frame(at: 200)
        restarts += 1
        car = Car(place: grid.point, yaw: grid.heading)
        car.settle(on: track)
        chase.snap(to: car, on: track)
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
            let wish = race.phase == .running ? pedals : Controls()
            car.advance(Apex.tick, controls: wish, on: track)
            car.bounce(on: track)
            race.note(0, s: car.s, length: track.length)
            pending -= Apex.tick
            steps += 1
        }
        if steps == Apex.maxSteps { pending = 0 }
        race.settle()
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
        lastKey = keyCode?.rawValue ?? -1
        if lastKey == Key.r.rawValue { restart() }
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
