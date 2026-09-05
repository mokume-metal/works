import mokume

/// Processing の [Forces With Vectors](https://processing.org/examples/forceswithvectors/) を 1 行ずつ移したもの。
/// 原典は 3 つのタブ (`ForcesWithVectors` / `Liquid` / `Mover`) に分かれている。
///
/// **台帳は `bend` と言った。当たっている。** 歪みは 2 つ — `PVector` の
/// `div` / `add` / `mult` / `mag` / `copy` / `setMag` に当たるものが無いことと、
/// `mousePressed()` の出来事の口が無いこと ([#723](https://github.com/mokume-metal/mokume/issues/723))。
/// 押して並べ直せないので、1 度落ちきったら止まったままになる。
///
/// 乱数で重さを決めるので **画素では比べられない。**
final class ForcesWithVectors: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Forces With Vectors")

    /// 原典の `class Mover`。位置・速さ・加速と、大きさに結びついた重さを持つ。
    final class Mover {
        var position: SIMD2<Float>
        var velocity = SIMD2<Float>(0, 0)
        var acceleration = SIMD2<Float>(0, 0)
        let mass: Float

        init(_ m: Float, _ x: Float, _ y: Float) {
            mass = m
            position = SIMD2(x, y)
        }

        /// ニュートンの第 2 法則 (F = M * A、つまり A = F / M)
        func applyForce(_ force: SIMD2<Float>) {
            acceleration += force / mass
        }

        func update() {
            velocity += acceleration
            position += velocity
            acceleration = .zero   // 毎フレーム加速を消す
        }

        func display(on sketch: any Sketch) {
            sketch.stroke(gray(255))
            sketch.strokeWeight(2)
            sketch.fill(gray(255, 200))
            sketch.ellipse(position.x, position.y, mass * 16, mass * 16)
        }

        func checkEdges(height: Float) {
            if position.y > height {
                velocity.y *= -0.9   // 底に当たったところで少し落とす
                position.y = height
            }
        }
    }

    /// 原典の `class Liquid`。水は矩形で、抵抗の係数を持つ。
    struct Liquid {
        let x: Float, y: Float, w: Float, h: Float
        let c: Float

        func contains(_ m: Mover) -> Bool {
            m.position.x > x && m.position.x < x + w && m.position.y > y && m.position.y < y + h
        }

        func drag(_ m: Mover) -> SIMD2<Float> {
            // 大きさは 係数 × 速さの 2 乗
            let speed = mag(m.velocity.x, m.velocity.y)
            let dragMagnitude = c * speed * speed
            // 向きは速さの逆。原典は `copy()` / `mult(-1)` / `setMag(...)` の 3 行
            guard speed > 0 else { return .zero }
            return (m.velocity * -1) / speed * dragMagnitude
        }

        func display(on sketch: any Sketch) {
            sketch.noStroke()
            sketch.fill(gray(127))
            sketch.rect(x, y, w, h)
        }
    }

    private var movers: [Mover] = []
    private var liquid: Liquid?

    func setup() {
        reset()
        liquid = Liquid(x: 0, y: height / 2, w: width, h: height / 2, c: 0.1)
    }

    func draw() {
        background(gray(0))
        guard let liquid else { return }
        liquid.display(on: self)
        for mover in movers {
            if liquid.contains(mover) {
                mover.applyForce(liquid.drag(mover))
            }
            // 重さで大きさが変わる重力
            mover.applyForce(SIMD2(0, 0.1 * mover.mass))
            mover.update()
            mover.display(on: self)
            mover.checkEdges(height: height)
        }
        fill(gray(255))
        text("click mouse to reset", 10, 30)
    }

    // 原典はここに `void mousePressed()` を持ち、押すたびに並べ直す。**受ける口が無い**

    private func reset() {
        movers = (0..<10).map { Mover(random(0.5, 3), 40 + Float($0) * 70, 0) }
    }
}
