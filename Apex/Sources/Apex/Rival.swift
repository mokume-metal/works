import Foundation
import simd

/// AI の運転。
///
/// ## 人と同じ車しか運転できない
///
/// ここが返すのは `Controls` だけである。物理は誰が運転しているかを知らないので、
/// **「AI だけが余分に曲がれる」ことが構造的に起きない**。相手が速いとしたら、
/// それは同じ車をうまく操っているからである。
///
/// ## 速さを決めるのは「制動距離を織り込んだ後ろ向きの走査」
///
/// 先の曲率から「そこを回れる速さ」を出し、**そこまでに詰められる距離ぶん足して**
/// 今の上限にする。
///
/// ```text
/// 目標速度 = min over Δ ( √( v_corner(κ(s+Δ))² + 2·a·Δ ) )
/// ```
///
/// これが無いと、コーナーの入口で急に止まるか、突っ込んで飛び出すかのどちらかになる。
/// **見て「うまい」と感じるかは、ほぼこの 3 行で決まる。**
///
/// ## ライン取りは手で引かない
///
/// 広い窓で均した曲率 (`Track.Sample.drift`) を横ずれに写すだけで、コーナーの手前で
/// 外へ膨らみ、出口で戻る線が出る — **平均の遅れがそのままアウト・イン・アウトになる**
struct Rival {
    /// 使えるグリップの割合。**1 に近いほど速い。**
    var skill: Float
    /// 先読みの伸び (速さ 1 単位あたり)。
    var reach: Float
    /// ライン取りの癖 (単位)。
    var bias: Float
    /// 出せる速さの割合。
    var topFraction: Float
    /// 揺らぎの種。**台ごとに違う癖を出すため。**
    var seed: Float

    /// 4 台ぶんの個性。**「1 台には勝てる、1 台とは競る、1 台は速い」**の並びにしてある。
    static let field: [Rival] = [
        Rival(skill: 0.96, reach: 0.50, bias: -12, topFraction: 1.00, seed: 3),
        Rival(skill: 0.91, reach: 0.55, bias: 6, topFraction: 0.97, seed: 41),
        Rival(skill: 0.86, reach: 0.62, bias: 14, topFraction: 0.94, seed: 77),
    ]

    /// どれだけ先を見て、どれだけ手前から緩めるか。
    private static let horizon: Float = 700

    /// 1 歩ぶんの操作を決める。
    ///
    /// - Parameter wobble: −0.5…0.5 の揺らぎ。**完璧に走らせないため**に混ぜる
    func drive(_ car: Car, on track: Track, others: [Car], at time: Float, wobble: (Float) -> Float)
        -> Controls
    {
        let pace = abs(car.pace)
        // **腕前も置き場所も、ゆっくり揺れる。** 同じ周回を寸分違わず繰り返されると
        // 相手が機械であることが見えてしまう
        let nowSkill = skill * (1 + 0.04 * (wobble(time * 0.11 + seed) - 0.5) * 2)
        let drift = bias + 18 * (wobble(time * 0.07 + seed + 50) - 0.5) * 2

        // 1. 目標点 — 速いほど遠くを見る
        let look = Math.clamp(60 + reach * pace, 80, 420)
        let ahead = track.frame(at: car.s + look)
        let offset = line(ahead.drift) + drift + dodge(car, others: others, on: track)
        let target = ahead.point + Track.side(ahead.heading) * offset

        // 2. 舵 — 純追従。**先読みが速さに比例するので、これで速度適応になる**
        let toward = target - car.place
        let sideways = simd_dot(toward, Track.side(car.yaw))
        let forward = max(simd_dot(toward, Track.forward(car.yaw)), 1)
        let want = atan2(sideways, forward)
        // 角速度の項を引いて、高速での蛇行を抑える
        let damp = 0.25 * car.turning * look / max(pace, 1)
        var controls = Controls()
        controls.steer = Math.clamp(want / Car.lock(at: pace) - damp, -1, 1)

        // 3. 速さ
        let goal = targetSpeed(from: car.s, on: track, skill: nowSkill)
        let error = goal - car.pace
        controls.throttle = Math.clamp(error / 60, 0, 1)
        controls.brake = Math.clamp(-error / 45, 0, 1)
        return controls
    }

    /// 均した曲率から取るライン。**コーナーの内側へ寄る。**
    private func line(_ drift: Float) -> Float {
        -Math.clamp(drift * 22000, -1, 1) * 40
    }

    /// そこを回れる速さから、手前の制動を織り込んだ上限を出す。
    private func targetSpeed(from s: Float, on track: Track, skill: Float) -> Float {
        let grip = Car.grip * skill
        // **人より甘い制動を使う。** 限界で踏ませると、わずかな揺らぎで飛び出す
        let braking = Car.braking * 0.8 * skill
        var best = Car.ceiling * topFraction
        var ahead: Float = 0
        while ahead <= Rival.horizon {
            let bend = abs(track.frame(at: s + ahead).curvature)
            let corner = sqrt(grip / max(bend, 1e-5))
            // そこまでに詰められるぶんを足す
            best = min(best, sqrt(corner * corner + 2 * braking * ahead))
            ahead += track.ds
        }
        return best
    }

    /// 前の車をよける横ずれ。**追突しそうなら速さも落とす** — それは呼ぶ側が見る。
    private func dodge(_ me: Car, others: [Car], on track: Track) -> Float {
        var push: Float = 0
        for other in others {
            let gap = Rival.gap(from: me.s, to: other.s, length: track.length)
            guard gap > 0, gap < 250 else { continue }
            let apart = other.lateral - me.lateral
            guard abs(apart) < 45 else { continue }
            // **自分がいま居る側へ逃げる。** 重なっているなら外側へ
            let hand: Float = apart == 0 ? 1 : (apart > 0 ? -1 : 1)
            push += hand * (45 - abs(apart)) * 0.9 * (1 - gap / 250)
        }
        return Math.clamp(push, -60, 60)
    }

    /// 前向きの距離の差。**1 周をまたぐので、−L/2…L/2 へ畳む。**
    static func gap(from: Float, to: Float, length: Float) -> Float {
        var delta = (to - from).truncatingRemainder(dividingBy: length)
        if delta > length / 2 { delta -= length }
        if delta < -length / 2 { delta += length }
        return delta
    }
}
