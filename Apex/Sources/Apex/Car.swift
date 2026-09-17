import Foundation
import simd

/// 操作 — 車へ渡せるもの。
///
/// **人間も AI もこれしか渡せない。** 物理は誰が運転しているかを知らないので、
/// 「AI だけが車を余分に曲げられる」ことが構造的に起きない。相手が速いとしたら、
/// それは同じ車をうまく操っているからである
struct Controls {
    var throttle: Float = 0
    var brake: Float = 0
    /// 舵。**−1 が左、+1 が右。**
    var steer: Float = 0
    var handbrake = false
}

/// 足の下。**中心線からの横ずれだけで決まる。**
struct Surface {
    /// タイヤの効き (舗装を 1 とする割合)。
    var grip: Float
    /// 押せる力の割合。
    var power: Float
    /// 余分な抵抗 (単位/s²)。
    var drag: Float
    var name: String

    static func under(_ lateral: Float) -> Surface {
        switch abs(lateral) {
        case ..<Track.halfWidth: return Surface(grip: 1, power: 1, drag: 0, name: "舗装")
        case ..<70: return Surface(grip: 0.82, power: 1, drag: 6, name: "縁石")
        case ..<110: return Surface(grip: 0.55, power: 0.85, drag: 22, name: "路肩")
        // **草では 36 km/h までしか出ない** (下の釣り合いを解いた値)。
        // 落ちたら終わりだが、戻ってはこられる
        default: return Surface(grip: 0.34, power: 0.6, drag: 55, name: "草")
        }
    }
}

/// 1 台の車。
///
/// ## 「全開では曲がれない」は 1 行から出る
///
/// 舵を切ると自転車モデルが角速度を命じるが、**タイヤが出せる横向きの力には上限がある**
/// ので、その角速度は `grip / 速さ` で頭打ちになる。速いほど上限が下がるので、
/// 同じ舵でも曲がらなくなる。
///
/// ```text
/// 命じる角速度 = v·tan(δ) / ホイールベース
/// 出せる角速度 = grip / v                     ← 横 G の上限
/// 実際         = clamp(命じる, ±出せる)
/// ```
///
/// この式だけで、ヘアピン (R = 17 m) を回れるのは 54 km/h・高速コーナー (R = 86 m) は
/// 120 km/h という**コーナーごとの差**が出る。速さの上限をコーナーごとに手で書いた
/// ところは 1 つも無い。
///
/// ## 滑りは「車体を回した後」に生まれる
///
/// 車体の向きを変えても、**速度はその瞬間には変わらない**。新しい車体の軸で速度を
/// 測り直すと、横向きの成分が残る — これが滑りである。タイヤはそれを 1 歩あたり
/// `grip·h` だけ削るので、普段は 0.1 秒ほどで消える。限界では削る速さより生まれる
/// 速さが勝ち、**一定の角度で滑り続ける**
struct Car {
    // MARK: - 寸法 (1 単位 = 10 cm)

    static let length: Float = 43
    static let width: Float = 19
    static let wheelbase: Float = 27
    /// 当たりを見る円の半径。
    static let radius: Float = 22

    // MARK: - 力 (単位/s²)

    /// タイヤが出せる横向きの加速度。**1.3 G。**
    static let grip: Float = 130
    /// 押せる力。
    static let drive: Float = 115
    /// 踏める制動。
    static let braking: Float = 130
    /// 後退で出せる力。
    static let reversing: Float = 70
    /// 駆動が 0 になる速さ (単位/s)。
    static let ceiling: Float = 640
    /// 後退の上限 (単位/s)。
    static let reverseCeiling: Float = 140
    /// 重力。
    static let gravity: Float = 98

    // MARK: - いまの様子

    var place: SIMD2<Float>
    /// 車体の向き。**0 で +z。**
    var yaw: Float
    var velocity = SIMD2<Float>(repeating: 0)
    /// 均した舵 (−1…1)。
    var steer: Float = 0

    /// コースの入口からの距離。
    var s: Float = 0
    /// 中心線からの横ずれ。**正が右。**
    var lateral: Float = 0
    /// 次に近傍を探すときの種。
    var index = 0
    var surface = Surface.under(0)

    /// 進んでいる向きと車体の向きの差 (ラジアン)。**滑りの量。**
    var slip: Float = 0
    /// いまの角速度 (ラジアン/s)。**タイヤの上限で頭打ちにした後の値。**
    var turning: Float = 0
    /// いま描いている円の半径 (単位)。**速いほど大きくなる** — これが
    /// 「全開では曲がれない」の正体で、上限に当たっている間は速さの 2 乗で伸びる
    var turnRadius: Float { abs(turning) < 1e-4 ? 99999 : speed / abs(turning) }
    /// 前の車の後ろに付いているか。**空気抵抗が 4 割減る** (誰にでも等しく効く)。
    var drafting = false
    /// 車輪の回り・傾き・沈み。**どれも見た目だけ。**
    var spin: Float = 0
    var lean: Float = 0
    var dive: Float = 0

    /// 前を向いた速さ (単位/s)。**後退では負。**
    var pace: Float { simd_dot(velocity, Track.forward(yaw)) }
    var speed: Float { simd_length(velocity) }
    /// km/h。**単位/s を 0.36 倍したもの。**
    var kmh: Float { speed * 0.36 }

    init(place: SIMD2<Float>, yaw: Float) {
        self.place = place
        self.yaw = yaw
    }

    /// コースの上へ置き直す (組み立てとやり直しのとき)。
    mutating func settle(on track: Track) {
        let found = track.find(place)
        s = found.s
        lateral = found.d
        index = found.index
        surface = Surface.under(found.d)
    }

    // MARK: - 1 歩

    /// 固定の刻みで 1 歩進める。
    ///
    /// **刻みを固定にするのは、同じ操作から同じ走りが出るようにするため。** フレームの
    /// 長さで刻むと、機械の速さでラップタイムが変わり、AI の追従も揺れる
    mutating func advance(_ h: Float, controls: Controls, on track: Track) {
        let here = track.frame(at: s)
        surface = Surface.under(lateral)
        let gripNow = Car.grip * surface.grip * (controls.handbrake ? 0.45 : 1)

        // 1. いまの車体の軸で測る
        var pace = simd_dot(velocity, Track.forward(yaw))

        // 2. 舵。**戻すほうを速く**する — 切り込みが速いと、直線で少し当てただけで
        // 跳ねるように向きが変わる
        let rate: Float = abs(controls.steer) < abs(steer) ? 6.0 : 3.2
        steer += Math.clamp(controls.steer - steer, -rate * h, rate * h)
        // **速いほど舵角を絞る。** 高速で舵を一杯に切れると、上限に当たるだけの
        // 無駄な操作になり、手応えが消える
        let wheel = steer * Car.lock(at: pace)

        // 3. 自転車モデルが命じる角速度を、タイヤの上限で頭打ちにする
        let wanted = pace * tan(wheel) / Car.wheelbase
        let limit = gripNow / max(abs(pace), 1)
        // **引き手はこの上限を外す。** 尻が出るのは、横のタイヤを諦めたときだけである
        turning = controls.handbrake ? wanted : Math.clamp(wanted, -limit, limit)
        // **向きは −π…π へ畳む。** 回り続けると増え続け、渡す角が際限なく大きくなる
        yaw = Track.wrap(yaw + turning * h)

        // 4. 回した**後**の軸で測り直す。ここで横向きの成分が残る = 滑り
        pace = simd_dot(velocity, Track.forward(yaw))
        var sway = simd_dot(velocity, Track.side(yaw))

        // 5. 前後
        let push = controls.throttle * Car.drive * surface.power
            * (1 - Math.unit(pace / Car.ceiling))
        var along = push
        if controls.brake > 0 {
            if pace > 6 {
                along -= controls.brake * Car.braking * surface.grip
            } else if pace > -Car.reverseCeiling {
                // 止まってからブレーキを踏み続けたら下がる
                along -= controls.brake * Car.reversing
            }
        }
        // 転がりと空気。**止まりかけでは効かせない** (0 のまわりで震えるため)
        if abs(pace) > 1 {
            // **前の車の後ろでは空気が薄い。** 速さの 2 乗に効く項だけが減る
            let air = 0.00012 * pace * abs(pace) * (drafting ? 0.55 : 1)
            let resist = air + 2 + surface.drag
            along -= resist * (pace > 0 ? 1 : -1)
        } else if controls.throttle < 0.01 && controls.brake < 0.01 {
            pace = 0
        }
        // 坂。**上りは減り、下りは増える**
        along -= Car.gravity * here.slope
        pace += along * h

        // 6. 横。**タイヤが 1 歩に削れる量には上限がある**
        sway -= Math.clamp(sway, -gripNow * h, gripNow * h)

        // 7. 組み直して進む
        velocity = Track.forward(yaw) * pace + Track.side(yaw) * sway
        place += velocity * h
        slip = atan2(sway, max(abs(pace), 1))
        // **車輪の回りも畳む。** 畳まないと 1 分で 1,600 ラジアンを超える
        spin = Track.wrap(spin + pace / 16 * h)

        // 見た目の傾き。**横 G で外へ傾き、前後 G で沈む**
        lean += (Math.clamp(turning * pace / Car.grip, -1, 1) * radiansOf(4.5) - lean)
            * Math.chase(h, 0.12)
        dive += (Math.clamp(along / Car.grip, -1, 1) * radiansOf(2.5) - dive)
            * Math.chase(h, 0.14)

        // 8. コースの上のどこにいるか
        let found = track.locate(place, near: index)
        // **周回の継ぎ目で s が飛ぶのを見逃さない** ように、呼ぶ側が前の値を見る
        s = found.s
        lateral = found.d
        index = found.index
    }

    // MARK: - 壁

    /// 路肩の外の壁で押し戻す。
    ///
    /// **(距離・横ずれ) の側で解く。** 世界の座標で壁の形を持たなくて済み、
    /// コースがどれだけ曲がっていても同じ 4 行で済む
    mutating func bounce(on track: Track) {
        guard abs(lateral) > Track.wallWidth else { return }
        let here = track.frame(at: s)
        let outward = Track.side(here.heading) * (lateral > 0 ? 1 : -1)
        lateral = lateral > 0 ? Track.wallWidth : -Track.wallWidth
        place = here.point + Track.side(here.heading) * lateral

        // **壁へ向かう成分だけを消す。** 速度そのものを削ると、擦っている間ずっと
        // 減速がかかって**壁に貼り付いたまま動けなくなる** (実際にそうなった)
        let into = simd_dot(velocity, outward)
        if into > 0 { velocity -= outward * into }
        // 擦っている間の罰は軽く。**1 歩ぶん**なので、強くすると 1 秒で 8 割方削れて
        // 壁から出られなくなる (0.985 にしたら実際にそうなった)
        velocity *= 0.997
        // **壁沿いに向き直らせる。** これが無いと壁を向いたまま空回りする
        yaw += Track.wrap(here.heading - yaw) * 0.2
    }

    /// その速さで切れる舵角の上限 (ラジアン)。**人も AI も同じ口を通る。**
    static func lock(at pace: Float) -> Float {
        Math.mix(Math.radians(34), Math.radians(9), Math.ramp(abs(pace), 0, 420))
    }

    private func radiansOf(_ degrees: Float) -> Float { degrees * Float.pi / 180 }
}
