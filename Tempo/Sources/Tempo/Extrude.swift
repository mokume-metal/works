import Foundation
import mokume
import simd

/// 押し出す (拍 20–28)。
///
/// **格子が組んだ語を、そのまま引き取って厚みを付ける。** 前の場面の最後の絵 (`TIME` の
/// 形) と、この場面の最初の絵は同じ位置・同じ大きさなので、拍 20 の切り替わりは
/// 「別の場面が始まった」ではなく「同じものが起き上がった」に見える。
///
/// 写し方は**平行投影** (`ortho`)。透視投影だと手前の字が大きくなって、語が 1 つの
/// 板であることが崩れる — 図法のほうを変えると、回っても文字の大きさが変わらない。
///
/// 動きは 2 拍にひと構えで、`expoInOut` で**0.7 拍かけて移り、1.3 拍止まる**。
/// 止まっている時間があることが拍を作る。連続して揺らすと、同じ回転でも拍が消える。
extension Tempo {
    /// 押し出す厚み (単位)。
    static let relief: Float = 176

    /// 構え (向き・傾き)。**2 拍にひとつ。**
    static let poses: [SIMD2<Float>] = [
        SIMD2(-0.46, 0.10), SIMD2(0.40, -0.12), SIMD2(-0.22, 0.24), SIMD2(0.52, 0.05),
        SIMD2(-0.34, -0.16),
    ]

    func drawExtrude(at beat: Float) {
        let slot = max(0, min(Self.poses.count - 2, Int((Score.wrap(beat) - 20) / 2)))
        let start = 20 + Float(slot) * 2
        let moved = Ease.expoInOut(Ease.ramp(beat, start, start + 0.7))
        let pose = SIMD2(
            Ease.mix(moved, Self.poses[slot].x, Self.poses[slot + 1].x),
            Ease.mix(moved, Self.poses[slot].y, Self.poses[slot + 1].y))
        // 厚みは頭で 1 度だけ立ち上がる
        let depth = Ease.backOut(Ease.ramp(beat, 20, 20.8))

        ortho()
        shadow(pose: pose, depth: depth)
        drawSubject(yaw: pose.x, pitch: pose.y, depth: depth)
    }

    /// 床へ落とす影。**剪断 (`shearX`) で寝かせた同じ語**で、光の計算はしていない。
    private func shadow(pose: SIMD2<Float>, depth: Float) {
        let subject = word(Tempo.subject)
        push()
        translate(span.x / 2, Tiles.baseline + 96)
        shearX(-0.62 + pose.x * 0.4)
        scale(1, 0.3)
        fill(Palette.fade(Palette.ink, 0.14 * depth))
        place(subject)
        pop()
    }

    /// 押し出した語を置く。**畳みと共用** — 畳むほうは厚みを 0 へ持っていくだけである。
    func drawSubject(yaw: Float, pitch: Float, depth: Float) {
        guard let reliefShape else { return }
        push()
        translate(span.x / 2, Tiles.baseline, 0)
        rotateX(pitch)
        rotateY(yaw)
        scale(1, 1, max(depth, 0.0001))
        shape(reliefShape, 0, 0)
        pop()
    }

    /// 語を厚みのある形へ焼く。**走り出してから 1 度だけ。**
    ///
    /// 前と後ろは焼いておいた三角形 (``Stitch``)、側面は周の辺ごとに 2 枚。色は面ごとに
    /// 決め打ちで、光は使っていない — **平らな色のほうが図に見える**し、拍で切り替わる
    /// 絵のなかでは陰影より面の色差のほうが速く読める。
    func bakeRelief() -> Shape {
        let subject = word(Tempo.subject)
        let half = Self.relief / 2
        return createShape {
            noStroke()
            beginShape(.triangles)
            for mark in subject.marks {
                let dx = mark.x
                let glyph = mark.glyph

                // 前と後ろ
                var index = 0
                while index + 2 < glyph.triangles.count {
                    let corners = [
                        glyph.triangles[index], glyph.triangles[index + 1],
                        glyph.triangles[index + 2],
                    ]
                    index += 3
                    fill(Palette.ink)
                    normal(0, 0, 1)
                    for corner in corners { vertex(dx + corner.x, corner.y, half) }
                    fill(Palette.blue)
                    normal(0, 0, -1)
                    for corner in corners.reversed() { vertex(dx + corner.x, corner.y, -half) }
                }

                // 側面
                for ring in glyph.rings {
                    for position in ring.indices {
                        let a = ring[position]
                        let b = ring[(position + 1) % ring.count]
                        let edge = b - a
                        guard length_squared(edge) > 0 else { continue }
                        let facing = normalize(SIMD2(edge.y, -edge.x))
                        // **縦に立った面と横に寝た面で色を分ける。** 光ではなく
                        // 面の向きそのものを色にしている
                        fill(abs(facing.x) > abs(facing.y) ? Palette.red : Palette.blue)
                        normal(facing.x, facing.y, 0)
                        vertex(dx + a.x, a.y, half)
                        vertex(dx + b.x, b.y, half)
                        vertex(dx + b.x, b.y, -half)
                        vertex(dx + a.x, a.y, half)
                        vertex(dx + b.x, b.y, -half)
                        vertex(dx + a.x, a.y, -half)
                    }
                }
            }
            endShape()
        }
    }
}
