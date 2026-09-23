import Foundation
import mokume
import simd

/// 車の形と、その置き方。
///
/// ## 置くのに `shape(_:at:)` を使わない
///
/// `Placement` の変換は **T·Rx·Ry·Rz·S** の順に積まれるので、点にはロール → ヨー →
/// ピッチの順で効く。**ヨーが 90° の車にピッチを与えると、車体はロールする** —
/// コースの向きによって車が横に傾くという、見つけにくい壊れ方をする。
/// `Canvas` の `rotateY/X/Z` は後ろから積まれるので、呼んだ順が点への効き順の逆になり、
/// ロール → ピッチ → ヨーという車として正しい順序になる。
///
/// **ただし色を掛けるためだけの `Placement` は使う** (Tempo・Cast と同じ手口)。
/// 車体を白で焼いておけば、`Placement.fill` がそのまま 1 台ごとの色になる
extension Apex {
    /// 車輪の取り付け位置 (横・前後)。**前が +z。**
    static let axles: [(x: Float, z: Float, front: Bool)] = [
        (-9.4, 14, true), (9.4, 14, true), (-9.4, -13, false), (9.4, -13, false),
    ]

    /// 車体 — 1 台ごとの色が掛かるところ。**白で焼く。**
    func bakeShell() -> Shape {
        var corners: [Corner] = []
        let white = SIMD3<Float>(repeating: 255)
        // 胴・鼻・屋根。**y は上向きで組み、`form` が渡す直前に反転する** (路面と同じ)
        Solid.box(at: SIMD3(0, 7.6, -1), size: SIMD3(19, 7, 38), colour: white, into: &corners)
        Solid.box(at: SIMD3(0, 6.4, 17), size: SIMD3(15, 4.4, 10), colour: white, into: &corners)
        Solid.box(
            at: SIMD3(0, 13.6, -3), size: SIMD3(14.6, 5.4, 17), colour: white, into: &corners)
        return form(corners)
    }

    /// 窓・翼・灯 — 色を掛けない暗いところ。
    func bakeTrim() -> Shape {
        var corners: [Corner] = []
        let ink = SIMD3<Float>(26, 28, 34)
        // 風防。**屋根よりわずかに外へ出す** — 同じ高さに置くと z が競って散る
        Solid.box(at: SIMD3(0, 16.5, -3), size: SIMD3(13.2, 0.8, 15.4), colour: ink, into: &corners)
        // 後ろの翼と支柱
        Solid.box(at: SIMD3(0, 19, -19), size: SIMD3(17, 1.4, 5), colour: ink, into: &corners)
        for side in [Float(-5.6), 5.6] {
            Solid.box(
                at: SIMD3(side, 15.6, -19), size: SIMD3(1.4, 7, 3), colour: ink, into: &corners)
        }
        // 尾灯
        for side in [Float(-5.5), 5.5] {
            Solid.box(
                at: SIMD3(side, 9, -19.8), size: SIMD3(4, 2, 1), colour: SIMD3(198, 52, 44),
                into: &corners)
        }
        return form(corners)
    }

    /// 車輪 1 つ。**軸は x 方向。**
    func bakeWheel() -> Shape {
        var corners: [Corner] = []
        Solid.wheel(
            at: .zero, radius: 5.2, width: 4.6, detail: 18, tread: SIMD3(24, 24, 28),
            mark: SIMD3(126, 128, 136), into: &corners)
        return form(corners)
    }

    /// 1 台を置く。
    func put(_ car: Car, colour: SIMD3<Float>, on track: Track) {
        let here = track.frame(at: car.s)
        // 坂に沿って鼻先が上がり、加減速でさらに沈む / 起きる
        let pitch = atan(here.slope) + car.dive

        push()
        // **世界の回転を写し (``Apex/screen(_:_:_:)``) で挟み直す。** 写しは z 軸まわりの
        // 180° の回転なので、Y と X の回転は向きが逆になり、Z はそのまま残る。
        //
        // 世界では、ヨー θ は +z を (sin θ, 0, cos θ) へ回す Ry(θ)・鼻上げは Rx(−pitch)・
        // 右旋回で外 (左) へ傾くのは Rz(+lean) である。挟むと Ry(−θ)・Rx(+pitch)・Rz(+lean)
        let spot = Apex.screen(car.place.x, here.height, car.place.y)
        translate(spot.x, spot.y, spot.z)
        rotateY(-car.yaw)
        rotateX(pitch)
        rotateZ(car.lean)

        shape(shell, at: [Placement(fill: Palette.linear(colour))])
        shape(trim)

        for axle in Apex.axles {
            push()
            let hub = Apex.screen(axle.x, 5.2, axle.z)
            translate(hub.x, hub.y, hub.z)
            // **舵は前輪だけ。** 実際に効く舵角より大きく振る (見て分かるように)。
            // 世界の Ry(+舵)・Rx(+回り) を挟んだもの
            if axle.front { rotateY(-car.steer * Math.radians(24)) }
            rotateX(-car.spin)
            shape(wheel)
            pop()
        }
        pop()
    }
}
