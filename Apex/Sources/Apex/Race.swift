import Foundation
import simd

/// レースの進み — 待ち、周回、計時、順位。
///
/// ## 周回は「距離の巻き戻り」で数える
///
/// スタートラインに板を置いて交差を見るのではなく、**コース上の距離 `s` が 1 周の
/// 終わりから始まりへ飛んだこと**で数える。1 フレームに進むのは最大 9 単位で、
/// 判定の幅 (1/4 周 = 3,000 単位) よりずっと小さいので取りこぼさない。
///
/// **中間点を踏まないと周回を認めない。** これが無いと、ラインの上で前後に揺するだけで
/// 周回が増える
struct Race {
    /// 周回数。
    static let laps = 3
    /// 始まるまでの待ち (秒)。
    static let countdown: Float = 4.2

    enum Phase {
        case waiting
        case running
        case finished
    }

    /// 1 台ぶんの記録。
    struct Runner {
        var lap = 0
        var halfway = false
        var previousS: Float = 0
        var lapBegan: Float = 0
        var lastLap: Float?
        var best: Float?
        var finishedAt: Float?
        /// 走った総距離。**順位はこれの降順で決まる。**
        var progress: Float = 0
    }

    var phase = Phase.waiting
    /// 始まってからの時計 (秒)。**待っている間は負。**
    var clock: Float = -Race.countdown
    var runners: [Runner]
    /// 着順 (走者の番号)。
    var order: [Int] = []

    init(count: Int) {
        runners = Array(repeating: Runner(), count: count)
    }

    /// 時計を進める。
    mutating func advance(_ dt: Float) {
        clock += dt
        if phase == .waiting, clock >= 0 { phase = .running }
    }

    /// 合図の灯火。**残り秒からそのまま決まる。**
    ///
    /// ## 字ではなく灯で出す
    ///
    /// 以前は `3` → `3` → `2` → `1` → `1` と数字を出していた。`GO` の 2 文字は手元の
    /// 表示のどこにも出ていない字で、ここで初めて使うとその瞬間から GPU が描き切れなく
    /// なる (mokume#1273)。だから数字へ畳んだのだが、**GO の合図が「1 の出し直し」で
    /// しかなくなった**。「1」が消えるのを待ってから踏むと GO から 1.4 秒遅れ、ちょうど
    /// そこへ後ろの車が来た (#88)。
    ///
    /// **灯なら字を 1 つも使わない。** 3 つの丸を 1 秒ごとに赤く灯し、**走り出す瞬間に
    /// 全部を緑へ変える** — 変わる瞬間がそのまま合図になる。
    struct Lamps {
        /// 赤く灯っている数 (0…3)。
        var lit: Int
        /// 緑に変わったか。**ここから走れる。**
        var go: Bool
        /// 濃さ (0…1)。**緑は 1 秒灯してから 0.4 秒で消える。**
        var strength: Float
    }

    /// いまの灯。**走り出して 1.4 秒たったら出さない。**
    var lamps: Lamps? {
        switch clock {
        case ..<(-3): return Lamps(lit: 0, go: false, strength: 1)
        case ..<(-2): return Lamps(lit: 1, go: false, strength: 1)
        case ..<(-1): return Lamps(lit: 2, go: false, strength: 1)
        case ..<0: return Lamps(lit: 3, go: false, strength: 1)
        case ..<1.4: return Lamps(lit: 3, go: true, strength: Math.unit((1.4 - clock) / 0.4))
        default: return nil
        }
    }

    /// 1 台の位置を知らせ、周回とタイムを更新する。
    mutating func note(_ index: Int, s: Float, length: Float) {
        guard phase != .waiting else {
            runners[index].previousS = s
            return
        }
        var runner = runners[index]
        defer { runners[index] = runner }

        let previous = runner.previousS
        runner.previousS = s
        guard runner.finishedAt == nil else { return }

        // 中間点を前向きに越えた
        if previous < length / 2, s >= length / 2 { runner.halfway = true }

        // **前向きの巻き戻り = 1 周。** 後ろ向きなら 1 周戻す (逆走も数える)
        if previous > length * 0.75, s < length * 0.25 {
            if runner.halfway {
                runner.halfway = false
                runner.lap += 1
                let split = clock - runner.lapBegan
                runner.lapBegan = clock
                runner.lastLap = split
                if runner.best == nil || split < runner.best! { runner.best = split }
                if runner.lap >= Race.laps {
                    runner.finishedAt = clock
                    order.append(index)
                }
            }
        } else if previous < length * 0.25, s > length * 0.75 {
            runner.lap -= 1
            runner.halfway = true
        }

        // **線の手前にいる間は、まだ 1 周目に入っていない。** グリッドは線の手前に並ぶ
        // ので、そこを「1 周の終わり」として数えると、線を越えた車の進みが後ろの車より
        // 小さくなり、先頭で線を越えた直後に一瞬 P4 と出た (#88)。中間点を踏む前に
        // 最後の 1/4 周にいるのは、線の手前にいるときだけである
        let behindLine = !runner.halfway && s > length * 0.75
        runner.progress = Float(runner.lap) * length + (behindLine ? s - length : s)
    }

    /// 終わったか。
    ///
    /// **自分がゴールしたら終わりにする。** 全員を待つと、後ろの車が転んでいる間
    /// 結果が出ないままになる (相手はゴールの後も惰性で走り続ける)
    mutating func settle() {
        guard phase == .running else { return }
        if runners[0].finishedAt != nil { phase = .finished }
    }

    /// 順位 (0 が先頭)。**走った総距離の降順、終えた者はその順。**
    func standing(of index: Int) -> Int {
        let mine = runners[index]
        if let done = mine.finishedAt {
            return runners.filter { ($0.finishedAt ?? .greatestFiniteMagnitude) < done }.count
        }
        let ahead = runners.filter { other in
            other.finishedAt != nil || other.progress > mine.progress
        }
        return ahead.count
    }

    /// いま走っている周 (1 から数える。終えたら周回数のまま)。
    func shownLap(of index: Int) -> Int {
        min(runners[index].lap + 1, Race.laps)
    }

    /// 時計の表示。**測っていないものは空の桁で出す** — 0 と区別が付くように。
    static func text(_ seconds: Float?) -> String {
        guard let seconds, seconds >= 0 else { return "--:--.---" }
        let minutes = Int(seconds) / 60
        let rest = seconds - Float(minutes * 60)
        return String(format: "%d:%06.3f", minutes, rest)
    }
}

/// 逆走の見張り。
///
/// **向きではなく動きで見る。** 車の向きがコースと逆でも、壁から下がって抜け出して
/// いるだけなら逆走ではない。**コースに沿って後ろへ 14 km/h より速く進み、それが
/// 0.8 秒続いたら**知らせる — 一瞬のスピンや、止まりかけの切り返しでは出さない
struct WrongWay {
    /// 逆走とみなす、コースに沿って後ろへ進む速さ (単位/s)。
    static let threshold: Float = 40
    /// 知らせるまでに続く時間 (秒)。
    static let delay: Float = 0.8

    /// 後ろへ進み続けている時間 (秒)。
    private(set) var elapsed: Float = 0
    /// 知らせるか。
    var showing: Bool { elapsed >= WrongWay.delay }

    mutating func update(_ car: Car, on track: Track, _ h: Float) {
        let along = simd_dot(car.velocity, Track.forward(track.frame(at: car.s).heading))
        elapsed = along < -WrongWay.threshold ? elapsed + h : 0
    }
}
