import Foundation
import mokume
import simd

/// Apex — 3 周を走って順位を競う。
///
/// **works で勝ち負けのある 1 本目。** 12 本の作品はどれも終わらない眺めで、触れる
/// Prism と Quarry にも目的は無かった。ここには始まりと終わりがあり、相手がいる。
final class Apex: Sketch {
    var settings = SketchSettings(width: 1280, height: 720, title: "apex")

    // MARK: - 世界

    private var track = Track.build()
    private var road: Shape = .empty
    private var raised = false

    // MARK: - 数えるもの

    private var verts = 0
    /// コースを組んで焼くのにかかった時間 (ミリ秒)。
    private var bakeMs: Float = 0

    func setup() {
        // **画面の性質なのでフレームを越える。** `setup()` で積んだ描画のスタイルは
        // 捨てられるが、露出と丸め方はここから効く (Prism・Pond・Cast と同じ)
        exposure(1.0)
        toneMapping(.roll)
        noiseSeed(4021)
    }

    func draw() {
        if !raised { raise() }

        background(Surroundings.sky)
        look()

        ambientLight(96, 104, 118)
        // **光の向きも y を反転して渡す。** 世界の上から差す光が、絵でも上から差すように
        directionalLight(255, 246, 232, -0.42, -0.78, 0.46)

        noStroke()
        shape(road)

        expose("lapMeters", track.length / 10)
        expose("samples", track.count)
        expose("verts", verts)
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
        bakeMs = Float(Date().timeIntervalSince(began) * 1000)
    }

    /// 頂点の並びを 1 つの形へ焼く。
    ///
    /// **y はここで反転する。** 世界は上向きで持ち、渡す直前に符号を変える
    private func form(_ corners: [Road.Corner]) -> Shape {
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

    // MARK: - 見る

    /// いまは真上から俯瞰する。**コースが閉じているかを見るための足場。**
    private func look() {
        var low = SIMD2<Float>(repeating: .greatestFiniteMagnitude)
        var high = SIMD2<Float>(repeating: -.greatestFiniteMagnitude)
        for sample in track.samples {
            low = simd_min(low, sample.point)
            high = simd_max(high, sample.point)
        }
        let middle = (low + high) / 2
        let span = simd_reduce_max(high - low)
        let eye = SIMD3(middle.x, span * 1.9, middle.y - span * 0.6)
        camera(eye.x, -eye.y, eye.z, middle.x, 0, middle.y, 0, 1, 0)
        perspective(radians(62), width / height, 6, 26000)
    }
}
