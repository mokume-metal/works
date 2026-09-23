import Foundation
import Testing
import simd

@testable import Apex

/// レースの進みと逆走の見張り。
@MainActor
@Suite struct RaceTests {
    static let h: Float = 1.0 / 120

    @Test("グリッドの先頭から線を越えても、先頭のまま数えられる")
    func leaderStaysFirstAcrossTheLine() {
        let length: Float = 12_000
        // **`Apex.restart` と同じ並び** — 線の手前 7 m から 9.5 m おき
        var s: [Float] = (0..<4).map { length - (70 + Float($0) * 95) }
        var race = Race(count: 4)
        for index in s.indices { race.note(index, s: s[index], length: length) }
        race.advance(Race.countdown + 0.1)
        #expect(race.phase == .running)

        var worst = 0
        for _ in 0..<300 {
            for index in s.indices {
                s[index] = (s[index] + 5).truncatingRemainder(dividingBy: length)
                race.note(index, s: s[index], length: length)
            }
            worst = max(worst, race.standing(of: 0))
        }
        #expect(worst == 0, "先頭の車が P\(worst + 1) と数えられた")
        #expect(race.shownLap(of: 0) == 1)
    }

    /// コースの上 (s = 100 m) に置いた、コースの向きから `turned` だけ回した車。
    func placed(on track: Track, turned: Float, pace: Float) -> Car {
        let here = track.frame(at: 1000)
        var car = Car(place: here.point, yaw: here.heading + turned)
        car.velocity = Track.forward(car.yaw) * pace
        car.settle(on: track)
        return car
    }

    func watch(_ car: Car, on track: Track, seconds: Float) -> Bool {
        var watch = WrongWay()
        for _ in 0..<Int((seconds / Self.h).rounded()) { watch.update(car, on: track, Self.h) }
        return watch.showing
    }

    @Test("逆向きに走り続けたら、0.8 秒で逆走を知らせる")
    func wrongWayShows() {
        let track = Track.build()
        let car = placed(on: track, turned: .pi, pace: 150)
        #expect(!watch(car, on: track, seconds: 0.5))
        #expect(watch(car, on: track, seconds: 1))
    }

    @Test("前へ走っているときと、ゆっくり下がっているときは知らせない")
    func wrongWayStaysQuiet() {
        let track = Track.build()
        #expect(!watch(placed(on: track, turned: 0, pace: 300), on: track, seconds: 2))
        // **壁から下がって抜け出す**のは逆走ではない (約 11 km/h で後ろへ)
        #expect(!watch(placed(on: track, turned: 0, pace: -30), on: track, seconds: 2))
    }
}
