import Foundation

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

    /// 待っている間に出る合図 (3 / 2 / 1 / GO)。**残り秒からそのまま決まる。**
    var light: (text: String, age: Float)? {
        switch clock {
        case ..<(-3): return ("3", -3 - clock)
        case ..<(-2): return ("3", -2 - clock)
        case ..<(-1): return ("2", -1 - clock)
        case ..<0: return ("1", -clock)
        case ..<1.4: return ("GO", 1.4 - clock)
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

        runner.progress = Float(runner.lap) * length + s
    }

    /// 全員が終わったか。
    mutating func settle() {
        guard phase == .running else { return }
        if runners.allSatisfy({ $0.finishedAt != nil }) { phase = .finished }
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
