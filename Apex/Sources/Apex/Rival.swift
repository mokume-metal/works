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

    /// コーナーで使う横 G の割合 (腕前に掛ける)。
    private static let cornerMargin: Float = 0.9
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
        // **狙う横ずれは路面の端から 2.5 m 内に収める。** 癖と揺らぎとライン取りを足すと
        // 路面の端を越え、縁石と路肩でタイヤの効きが落ちたところで外へ押し出された。
        // 限界近くでは線から 2 m ほど外へ膨らむので、そのぶんを残しておく
        let room = Track.halfWidth - 25
        let usual = Math.clamp(line(ahead.drift) + drift, -room, room)
        let offset = pass(car, others: others, on: track, around: usual)
        let target = ahead.point + Track.side(ahead.heading) * offset

        // 2. 舵 — 純追従。**先読みが速さに比例するので、これで速度適応になる**
        //
        // 目標点を通る円の曲率を出し、その円を回る舵角に、タイヤがずれるぶん
        // (アンダーステア) を先に足す。**車は舵で直には回らない** (タイヤが回す) ので、
        // 狙いの角速度と実際の角速度の差も返す — これが無いと高速で蛇行する
        let toward = target - car.place
        let sideways = simd_dot(toward, Track.side(car.yaw))
        let bend = 2 * sideways / max(simd_length_squared(toward), 1)
        let feed = atan(Car.wheelbase * bend) + 1.5e-4 * pace * pace * bend
        let wheel = feed + 0.06 * (pace * bend - car.turning)
        var controls = Controls()
        controls.steer = Math.clamp(wheel / Car.lock(at: pace), -1, 1)

        // 3. 速さ。**前の車の後ろで止まれる速さを越えない**
        let goal = min(
            targetSpeed(from: car.s, on: track, skill: nowSkill),
            yield(car, others: others, on: track))
        let error = goal - car.pace
        // **横の力を使い切っているときは踏まない。** 踏むと摩擦円のぶん横が減り、鼻が逃げる
        let usedSide = abs(car.sideForce) / (Car.grip * car.surface.grip)
        controls.throttle = min(Math.clamp(error / 60, 0, 1), Math.unit((1 - usedSide) * 2.5 + 0.2))
        controls.brake = Math.clamp(-error / 45, 0, 1)
        return controls
    }

    /// 均した曲率から取るライン。**コーナーの内側へ寄る。**
    private func line(_ drift: Float) -> Float {
        -Math.clamp(drift * 22000, -1, 1) * 40
    }

    /// そこを回れる速さから、手前の制動を織り込んだ上限を出す。
    private func targetSpeed(from s: Float, on track: Track, skill: Float) -> Float {
        // **横 G の上限いっぱいは狙わない。** タイヤはピークの手前から押し出しが始まるので、
        // 上限ちょうどで回ると線から 2 m 外へ膨らみ、縁石で効きが落ちて流れた
        let grip = Car.grip * skill * Rival.cornerMargin
        // **人より甘い制動を使う。** 限界で踏ませると、わずかな揺らぎで飛び出す。
        // この走査は「制動をまるごと使える」と見込むが、曲がりながら止めると摩擦円の
        // ぶん横が減る — 8 割の見込みでは、ヘアピン手前の折れを横 G の上限で回ったまま
        // 制動に入り、止める余力が無くて壁まで行った。6 割にして折れの手前から緩める
        let braking = Car.braking * 0.6 * skill
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

    /// 前の車の後ろで止まれる速さ。
    ///
    /// **よけるだけでは追突を防げない。** `pass` は横へ逃げるが、止まっている車の
    /// 真後ろから全開で来ると、横へ逃げ切る前に届く — スタートで出遅れた自分の車が
    /// 19 m 後ろの相手に押し出され、壁まで運ばれた (#88)。
    ///
    /// 横に重なっている前の車ごとに、**その車の速さに、残りの隙間で詰められるぶんを
    /// 足したもの**を上限にする。制動は `targetSpeed` と同じ甘めの値を使う。横へ抜けて
    /// 重ならなくなれば上限は外れるので、追い抜きはそのまま起きる。
    ///
    /// **這う速さだけは残す。** ぴたりと止めると舵で横へ逃げられなくなり、止まった車の
    /// 後ろで 3 台とも動かなくなった。這いながら `pass` の横ずれへ回り込めば抜けられる。
    /// 当たっても這う速さなら、押し戻しは車 1 台ぶんも運ばない
    private func yield(_ me: Car, others: [Car], on track: Track) -> Float {
        let braking = Car.braking * 0.8
        var best = Float.greatestFiniteMagnitude
        for other in others {
            let gap = Rival.gap(from: me.s, to: other.s, length: track.length)
            // **少しでも前にいる車は全部見る。** 当たりは中心どうしの距離の円で見るので、
            // 斜め後ろ 3 m・横 3 m でも当たる — 全長ぶん前の車だけに絞ったら、そこから当てた
            guard gap > 0, gap < 400 else { continue }
            guard abs(other.lateral - me.lateral) < Rival.overlap else { continue }
            let room = max(gap - Rival.buffer, 0)
            best = min(best, max(other.pace, 0) + sqrt(2 * braking * room) + Rival.crawl)
        }
        return best
    }

    /// 横に重なっているとみなす中心どうしの隔たり (単位)。**当たりの円 2 つぶん
    /// (4.4 m) に 0.4 m の余裕。** 車幅 (1.9 m) で見ると狭すぎる — 当たりは円で見て
    /// いるので、横に 3.2 m 離れていても斜め後ろから寄れば当たった
    private static let overlap: Float = Car.radius * 2 + 4
    /// 前の車との間に残す隙間 (単位)。**中心どうしで 6 m** — 全長 4.3 m に 1.7 m の余裕
    private static let buffer: Float = 60
    /// 前の車の後ろでも残す速さ (単位/s)。**約 11 km/h。**
    private static let crawl: Float = 30

    /// 前の遅い車を抜く横ずれ。
    ///
    /// **いつもの線を少しずらすだけでは抜けない。** 以前はずれの量を重なりに比例させて
    /// 足していたが、ライン取りの引きに負けた — 右列からスタートした車が中央の線へ寄り、
    /// 左列で止まっている自分の車へ斜め後ろから当て続けた (#88)。
    ///
    /// **遅い車が前で重なっているときは、線を捨ててその車の横 (当たりの円の外) を狙う。**
    /// 近いほど強く寄せ、離れていればいつもの線 (`around`) のまま走る。寄せる側は
    /// 自分がいま居る側で、そちらに路面が残っていなければ反対へ回る
    private func pass(_ me: Car, others: [Car], on track: Track, around: Float) -> Float {
        var offset = around
        var nearest = Float.greatestFiniteMagnitude
        for other in others {
            let gap = Rival.gap(from: me.s, to: other.s, length: track.length)
            guard gap > 0, gap < Rival.passReach, gap < nearest else { continue }
            let apart = other.lateral - me.lateral
            guard abs(apart) < Rival.overlap + 10 else { continue }
            // **離れていく車は抜かなくてよい。**
            guard me.pace - other.pace > -20 else { continue }
            nearest = gap
            var hand: Float = apart > 0 ? -1 : 1
            let room = Track.halfWidth - 12
            if abs(other.lateral + hand * Rival.clearance) > room { hand = -hand }
            let beside = Math.clamp(other.lateral + hand * Rival.clearance, -room, room)
            // **近いほど強く寄せる。** 窓の端で急に線が跳ねないように
            let weight = Math.unit((Rival.passReach - gap) / (Rival.passReach * 0.4))
            offset = Math.mix(around, beside, weight)
        }
        return offset
    }

    /// 前の車を抜きにかかる距離 (単位)。**25 m。**
    private static let passReach: Float = 250
    /// 抜くときに空ける横の隔たり (単位)。**当たりの円 2 つぶんに 1.4 m の余裕。**
    private static let clearance: Float = Car.radius * 2 + 14

    /// 前向きの距離の差。**1 周をまたぐので、−L/2…L/2 へ畳む。**
    static func gap(from: Float, to: Float, length: Float) -> Float {
        var delta = (to - from).truncatingRemainder(dividingBy: length)
        if delta > length / 2 { delta -= length }
        if delta < -length / 2 { delta += length }
        return delta
    }
}
