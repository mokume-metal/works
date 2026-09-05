import Foundation
import mokume

/// Processing の [Multiple Particle Systems](https://processing.org/examples/multipleparticlesystems/) を 1 行ずつ移したもの。
/// 原典は 4 つのタブに分かれている。
///
/// **台帳は `bend` と言った。当たっている。ここで半分止まっている。**
/// 原典は**押した場所に新しい系を足す**例で、`mousePressed()` の口が無い
/// ([#723](https://github.com/mokume-metal/mokume/issues/723))。押せないので系が
/// 1 つも生まれず、面には案内の字だけが残る。
///
/// **動くように書き替えていない** — 押せないという事実がそのまま絵に出る。
final class MultipleParticleSystems: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Multiple Particle Systems")

    /// 原典の `class Particle`。
    class Particle {
        var position: SIMD2<Float>
        var velocity: SIMD2<Float>
        let acceleration = SIMD2<Float>(0, 0.05)
        var lifespan: Float = 255.0

        init(_ l: SIMD2<Float>, velocity: SIMD2<Float>) {
            position = l
            self.velocity = velocity
        }

        func run(on sketch: any Sketch) {
            update()
            display(on: sketch)
        }

        func update() {
            velocity += acceleration
            position += velocity
            lifespan -= 2.0
        }

        func display(on sketch: any Sketch) {
            sketch.stroke(255, lifespan)
            sketch.fill(255, lifespan)
            sketch.ellipse(position.x, position.y, 8, 8)
        }

        var isDead: Bool { lifespan < 0.0 }
    }

    /// 原典の `class CrazyParticle extends Particle`。変数を 1 つ足すだけ。
    final class CrazyParticle: Particle {
        var theta: Float = 0.0

        override func update() {
            super.update()
            // 横の速さで回す量を決める
            theta += (velocity.x * mag(velocity.x, velocity.y)) / 10.0
        }

        override func display(on sketch: any Sketch) {
            super.display(on: sketch)
            sketch.pushMatrix()
            sketch.translate(position.x, position.y)
            sketch.rotate(theta)
            sketch.stroke(255, lifespan)
            sketch.line(0, 0, 25, 0)
            sketch.popMatrix()
        }
    }

    /// 原典の `class ParticleSystem`。
    final class ParticleSystem {
        var particles: [Particle] = []
        let origin: SIMD2<Float>

        init(_ num: Int, _ v: SIMD2<Float>, velocity: () -> SIMD2<Float>) {
            origin = v
            for _ in 0..<num { particles.append(Particle(origin, velocity: velocity())) }
        }

        func run(on sketch: any Sketch) {
            for i in stride(from: particles.count - 1, through: 0, by: -1) {
                particles[i].run(on: sketch)
                if particles[i].isDead { particles.remove(at: i) }
            }
        }

        func addParticle(velocity: SIMD2<Float>, crazy: Bool) {
            particles.append(crazy ? CrazyParticle(origin, velocity: velocity)
                                   : Particle(origin, velocity: velocity))
        }
    }

    private var systems: [ParticleSystem] = []

    func draw() {
        background(0)
        for ps in systems {
            ps.run(on: self)
            ps.addParticle(velocity: SIMD2(random(-1, 1), random(-2, 0)),
                           crazy: Int(random(0, 2)) != 0)
        }
        if systems.isEmpty {
            fill(255)
            textAlign(.center)
            text("click mouse to add particle systems", width / 2, height / 2)
        }
    }

    // 原典はここに `void mousePressed()` を持ち、押した場所に系を足す。**受ける口が無い**
}
