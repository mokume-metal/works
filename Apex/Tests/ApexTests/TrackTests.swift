import Foundation
import Testing
import simd

@testable import Apex

/// コースの形が約束していること。
@MainActor
@Suite struct TrackTests {
    /// グリッドの範囲 (線の手前 6〜37 m)。**`Apex.restart` が並べる 4 台ぶん。**
    static let grid: ClosedRange<Float> = 60...370

    @Test("グリッドの範囲は直線 — 向きの変化が 1° 以下")
    func gridIsStraight() {
        let track = Track.build()
        let headings = stride(from: Self.grid.lowerBound, through: Self.grid.upperBound, by: 10)
            .map { track.frame(at: track.length - $0).heading }
        let spread = (headings.max() ?? 0) - (headings.min() ?? 0)
        #expect(spread < Math.radians(1), "向きの変化が \(spread * 180 / .pi)°")
    }

    @Test("グリッドの先頭から舵を当てずに踏んでも、線の先 60 m まで舗装から出ない")
    func straightAfterGrid() {
        let track = Track.build()
        let start = track.frame(at: track.length - 70)
        var car = Car(place: start.point + Track.side(start.heading) * -28, yaw: start.heading)
        car.settle(on: track)
        var widest: Float = 0
        var crossed = false
        for _ in 0..<Int(10 * 120) {
            car.advance(1.0 / 120, controls: Controls(throttle: 1), on: track)
            if car.s < track.length / 2 { crossed = true }
            if crossed, car.s > 600 { break }
            widest = max(widest, abs(car.lateral))
        }
        #expect(crossed)
        #expect(widest < Track.halfWidth, "横ずれの最大が \(widest / 10) m")
    }

    @Test("コースは 1 周 1.2 km に合わせてある")
    func lapLength() {
        let track = Track.build()
        #expect(abs(track.length - Track.lapLength) < 1)
    }
}
