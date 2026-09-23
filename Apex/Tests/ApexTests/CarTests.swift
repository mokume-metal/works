import Foundation
import Testing
import simd

@testable import Apex

/// 車の運動が約束している振る舞い。
///
/// **どれもコースを使わず `Car.step` を直に回す** (相手の周回だけはコースの上で回す)。
/// 刻みは作品と同じ 1/120 秒で、乱数は使わないので、同じ機械なら毎回同じ値になる
@MainActor
@Suite struct CarTests {
    static let h: Float = 1.0 / 120

    /// 平らな舗装の上を、+z へ `speed` で進んでいる車。
    func rolling(at speed: Float) -> Car {
        var car = Car(place: .zero, yaw: 0)
        car.velocity = Track.forward(0) * speed
        return car
    }

    /// `seconds` 秒ぶん同じ操作で進める。**速さを保つなら `hold` を渡す** (踏み加減だけを
    /// 決める比例の足)。1 歩ごとに `watch` を呼ぶ
    func run(
        _ car: inout Car, seconds: Float, controls: Controls = Controls(), slope: Float = 0,
        hold: Float? = nil, watch: (Car) -> Void = { _ in }
    ) {
        for _ in 0..<Int((seconds / Self.h).rounded()) {
            var input = controls
            if let hold { input.throttle = Math.clamp((hold - car.pace) / 30, 0, 1) }
            car.step(Self.h, controls: input, slope: slope)
            watch(car)
        }
    }

    @Test("右へ切れば右へ曲がる — 角速度も向きも正で、車は side の向きへ寄る")
    func steerRightTurnsRight() {
        var car = rolling(at: 250)
        run(&car, seconds: 0.5, controls: Controls(steer: 1))
        #expect(car.turning > 0.1)
        #expect(car.yaw > 0.02)
        // **side(0) = (1, 0)** が右
        #expect(car.place.x > 1)
    }

    @Test("舵を一杯に切り続けても、横 G は前輪の上限 (1.3 G) を越えない", arguments: [150, 250, 350] as [Float])
    func lateralLimit(speed: Float) {
        var car = rolling(at: speed)
        var samples: [Float] = []
        var sides: [Float] = []
        run(&car, seconds: 4, controls: Controls(steer: 1), hold: speed) { car in
            samples.append(car.speed * abs(car.turning))
            sides.append(abs(car.sideForce))
        }
        // **最後の 1 秒の平均を定常とみなす**
        let tail = samples.suffix(120)
        let lateral = tail.reduce(0, +) / Float(tail.count)
        #expect(lateral > 110, "速さ \(speed) の定常の横 G が \(lateral)")
        #expect(lateral < 135, "速さ \(speed) の定常の横 G が \(lateral)")
        #expect((sides.max() ?? 0) < 140)
    }

    @Test("舵を放せばまっすぐに戻る — 回りも滑りも残らない")
    func releaseSteerSettles() {
        var car = rolling(at: 300)
        run(&car, seconds: 1, controls: Controls(steer: 1), hold: 300)
        #expect(car.turning > 0.2)
        run(&car, seconds: 1.5, hold: 300)
        #expect(abs(car.turning) < 0.02)
        #expect(abs(car.slip) < Math.radians(0.5))
    }

    @Test("引き手で尻が出て、放せば回らずに立て直す")
    func handbrakeSlidesAndRecovers() {
        var car = rolling(at: 300)
        var widest: Float = 0
        run(&car, seconds: 0.6, controls: Controls(steer: 1, handbrake: true)) { car in
            widest = max(widest, abs(car.slip))
        }
        #expect(widest > Math.radians(6), "引き手で出た滑りが \(widest * 180 / .pi)°")
        // **放してから収まるまでの時間を見る。** 立て直しの助けが無いと 1.8 秒かかる
        var settled: Float? = nil
        var elapsed: Float = 0
        run(&car, seconds: 2.5) { car in
            elapsed += Self.h
            if settled == nil, abs(car.slip) < Math.radians(2) { settled = elapsed }
        }
        #expect((settled ?? 99) < 1.3, "滑りが 2° を切るまで \(settled ?? -1) 秒")
        #expect(abs(car.slip) < Math.radians(2))
        #expect(car.speed > 150, "立て直したあとの速さが \(car.speed)")
    }

    @Test("何も押さずに止まっていれば、坂の上でも少しも動かない", arguments: [0, 0.1] as [Float])
    func restStaysAtRest(slope: Float) {
        var car = Car(place: SIMD2(12, 34), yaw: 0.7)
        run(&car, seconds: 10, slope: slope)
        #expect(car.place == SIMD2(12, 34))
        #expect(car.velocity == .zero)
        #expect(car.turning == 0)
    }

    @Test("止まるときに震えない — 放したらちょうど 0 で止まり、そのまま動かない")
    func stopDoesNotJitter() {
        var car = rolling(at: 100)
        for _ in 0..<2000 where car.pace > 6 {
            car.step(Self.h, controls: Controls(brake: 1), slope: 0)
        }
        run(&car, seconds: 1)
        #expect(car.velocity == .zero)
        var moved = false
        run(&car, seconds: 2) { car in if car.velocity != .zero { moved = true } }
        #expect(!moved)
    }

    @Test("止まってから止めるを踏み続けると下がり、下がるときは舵が逆に効く")
    func reverseSteers() {
        var car = Car(place: .zero, yaw: 0)
        run(&car, seconds: 2, controls: Controls(brake: 1))
        #expect(car.pace < -50)
        run(&car, seconds: 0.5, controls: Controls(brake: 1, steer: 1))
        // **後ろへ進みながら右へ切ると、鼻は左へ振れる** (実車と同じ)
        #expect(car.turning < 0)
    }

    /// コースの上で、左の壁際 (草) に置いた車。**直線の途中** (s = 100 m) で、壁へ
    /// `into` だけ向けて `speed` で進んでいる
    func atWall(on track: Track, speed: Float, into: Float) -> Car {
        let here = track.frame(at: 1000)
        let lateral = -(Track.wallWidth - 5)
        var car = Car(place: here.point + Track.side(here.heading) * lateral, yaw: here.heading - into)
        car.velocity = Track.forward(car.yaw) * speed
        car.settle(on: track)
        return car
    }

    /// コースの上で `seconds` 秒進める (壁も効かせる)。
    func drive(_ car: inout Car, on track: Track, seconds: Float, controls: Controls) {
        for _ in 0..<Int((seconds / Self.h).rounded()) {
            car.advance(Self.h, controls: controls, on: track)
            car.bounce(on: track)
        }
    }

    @Test("壁際の草から、内へ切って踏めば 3 秒で路肩の内へ戻れる")
    func wallDoesNotTrap() {
        let track = Track.build()
        var car = atWall(on: track, speed: 100, into: Math.radians(10))
        drive(&car, on: track, seconds: 3, controls: Controls(throttle: 1, steer: 1))
        #expect(abs(car.lateral) < 110, "3 秒後の横ずれが \(car.lateral / 10) m")
    }

    @Test("速く浅く壁を擦っても、壁に触れない車と比べて 1 割も失わない")
    func scrapingKeepsPace() {
        let track = Track.build()
        var scraping = atWall(on: track, speed: 250, into: Math.radians(3))
        var free = atWall(on: track, speed: 250, into: 0)
        drive(&scraping, on: track, seconds: 4, controls: Controls(throttle: 1))
        drive(&free, on: track, seconds: 4, controls: Controls(throttle: 1))
        // **以前は擦っている間ずっと速度に 0.997 を掛けていた** (1 秒で 3 割)。いまは
        // 擦るだけなら、壁へ向かう速さのぶんしか失わない
        #expect(
            scraping.speed > free.speed * 0.9,
            "擦った車 \(scraping.kmh) km/h・触れない車 \(free.kmh) km/h")
    }

    @Test("鼻から壁に当たっても、壁に向いたまま止まらない", arguments: [45, 85] as [Float])
    func noseInDoesNotStall(angle: Float) {
        let track = Track.build()
        var car = atWall(on: track, speed: 30, into: Math.radians(angle))
        drive(&car, on: track, seconds: 4, controls: Controls(throttle: 1))
        #expect(car.kmh > 10, "\(angle)° で当たって 4 秒後の速さが \(car.kmh) km/h")
    }

    // **番号は定数で渡す。** 引数は隔離の外で組まれるので、`Rival.field` (main actor) を読めない
    @Test("相手は 1 台ずつ走らせても 3 周を走り切り、壁に 1 度も触れない", arguments: [0, 1, 2])
    func rivalsFinishThreeLaps(index: Int) {
        let track = Track.build()
        #expect(Rival.field.count == 3)
        let rival = Rival.field[index]
        let grid = track.frame(at: track.length - 70)
        var car = Car(place: grid.point + Track.side(grid.heading) * -28, yaw: grid.heading)
        car.settle(on: track)
        var race = Race(count: 1)
        race.note(0, s: car.s, length: track.length)

        var touches = 0
        var widest: Float = 0
        var slipped: Float = 0
        var clock: Float = 0
        while race.runners[0].lap < Race.laps, clock < 170 {
            race.advance(Self.h)
            if race.phase != .waiting {
                let wish = rival.drive(car, on: track, others: [car], at: clock) { _ in 0.5 }
                car.advance(Self.h, controls: wish, on: track)
                if abs(car.lateral) > Track.wallWidth { touches += 1 }
                car.bounce(on: track)
                widest = max(widest, abs(car.lateral))
                slipped = max(slipped, abs(car.slip))
            }
            race.note(0, s: car.s, length: track.length)
            clock += Self.h
        }
        #expect(race.runners[0].lap == Race.laps, "\(clock) 秒で \(race.runners[0].lap) 周")
        let best = race.runners[0].best ?? 999
        #expect(best > 36 && best < 46, "ベストが \(best) 秒")
        #expect(touches == 0)
        // **路肩 (11 m) より外へ出ない**
        #expect(widest < 110, "横ずれの最大が \(widest / 10) m")
        #expect(slipped < Math.radians(15), "滑りの最大が \(slipped * 180 / .pi)°")
    }
}
