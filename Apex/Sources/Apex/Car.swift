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
        // **草では 60 km/h までしか出ない** (踏み続けたときの釣り合いを解いた値)。
        // 落ちたら損をするが、戻ってはこられる。36 km/h (抵抗 55) にしていたころは、
        // 押し出されたあと戻るまでが長すぎて「全然進まない」になった (#88)
        default: return Surface(grip: 0.34, power: 0.6, drag: 48, name: "草")
        }
    }
}

/// 1 台の車。
///
/// ## タイヤが横へ押す力で曲がる
///
/// 舵を切ると前輪の向きと進む向きがずれ (**滑り角**)、タイヤはそのずれに応じて横へ
/// 押し返す。押し返す力には**上限がある** — 滑り角が小さいうちは比例して増え、
/// ピーク (前 8°・後 7°) を越えると頭打ちになり、後輪はそこから少し落ちる。
/// 車体はこの前後 2 つの力で**回される**ので、向きには慣性がある。
///
/// ```text
/// 前の横力 Ff = −capF · tyre(αf / αf,peak)
/// 後の横力 Fr = −capR · tyre(αr / αr,peak)
/// 横の加速 = Ff·cos δ + Fr
/// 回りの加速 = (a·Ff·cos δ − b·Fr) / k²
/// ```
///
/// **限界は前輪で決まる** (弱いアンダーステア)。前が出せる横 G の上限は `grip` そのもの
/// なので、回れる速さはこれまでと同じ `√(grip / κ)` で決まる — ヘアピン (R = 17 m) は
/// 54 km/h、高速コーナー (R = 86 m) は 120 km/h。**上限を手で書いたコーナーは 1 つも無い。**
///
/// ## 荷重が前後へ移る
///
/// 止めると前へ、踏むと後ろへ荷重が移り、**移った側のタイヤが余分に効く**。ブレーキを
/// 残したまま切り込むと鼻が入り、踏みながら曲がると鼻が逃げる。ただしキーボードで
/// 扱えるよう、前後の力が横の力を奪う割合 (摩擦円) は甘くしてある
///
/// ## キーで運転するための助け
///
/// - **舵角の上限は速さで絞る。** キーを一杯に押したとき、前輪がちょうどピークを少し
///   越えるところに来る (``lock(at:)``)。押しっぱなしでも押し出しは浅い
/// - **逆舵を足す。** 後輪がピークを越えて滑り出したら、越えたぶんだけ前輪を進む向きへ
///   返す。キーは 0 か 1 しか渡せないので、人の手の細かい当て舵をここで補う
/// - **持てない回転だけを削り、出た尻を戻す** (簡易の横滑り防止)。引き手を握っている
///   間は切るので、尻は出せるし、離せば戻る
///
/// ## 遅いときは幾何で曲がる
///
/// 滑り角の式は速さで割るので、止まりかけでは硬くなりすぎる。**11〜29 km/h で、前輪の
/// 向きだけで決まる曲がり方 (自転車の幾何) へ混ぜる。** 後退は常に幾何で曲がる
struct Car {
    // MARK: - 寸法 (1 単位 = 10 cm)

    static let length: Float = 43
    static let width: Float = 19
    static let wheelbase: Float = 27
    /// 重心から前軸・後軸まで。**重心はわずかに前寄り** — 前が荷重の 52% を持つ。
    static let front: Float = 13
    static let rear: Float = 14
    /// 回りにくさ (慣性モーメント ÷ 質量。単位²)。**回転半径 1.3 m。**
    static let inertia: Float = 170
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

    // MARK: - タイヤ

    /// 横力がピークになる滑り角。**後ろのほうが早く頭打ちになる。**
    static let frontPeak = Math.radians(8)
    static let rearPeak = Math.radians(7)
    /// ピークを越えたあとの落ち込み。**前はほぼ平ら** (押し出すだけ)、**後ろは少し
    /// 落ちる** (滑り出すと少し戻りにくい)。後ろを 0.15 まで落とすと、引き手を放した
    /// あとも尻が 35° 出たまま 2 秒以上流れ続けた
    static let frontDrop: Float = 0.06
    static let rearDrop: Float = 0.08
    /// 後輪がピークを越えたぶんに比例して回りを戻す強さ (1/s²)。**引き手を握っている
    /// 間は効かない。**
    static let recovery: Float = 5
    /// 後輪の余裕。**1 より大きいので、限界は前輪で決まる** (弱いアンダーステア)。
    ///
    /// 1.06 では、ブレーキを残したまま切り込むと荷重が前へ移ったぶんで後輪が先に
    /// 頭打ちになり、相手が T1 で尻を出して壁まで回った。1.15 は、半分の制動を残しても
    /// 後輪が前輪より先に音を上げない値である
    static let rearMargin: Float = 1.15
    /// 1 G あたりに前後へ移る荷重の割合。**控えめにしてある** — 実車に近い 0.067 では、
    /// 止めながら曲がったときの尻の出方がキーの 0 / 1 で扱える幅を越えた
    static let transferPerG: Float = 0.05
    /// 引き手を引いたときに残る後輪の横の効き。
    static let handbrakeGrip: Float = 0.35
    /// 引き手で後輪を止める減速。
    static let handbrakeDrag: Float = 35
    /// 滑り角を測るときの速さの下限 (単位/s)。**タイヤの硬さの上限** — 下限が無いと、
    /// 止まりかけで滑り角の式が硬くなりすぎて刻みが追いつかない
    static let slipFloor: Float = 50
    /// 幾何から動力学へ移る速さの範囲 (単位/s)。**11〜29 km/h。**
    static let dynamicFrom: Float = 30
    static let dynamicTo: Float = 80
    /// 入力が無く遅いときに足す抵抗 (単位/s²)。**止まり、坂でも転がり出さない。**
    static let hold: Float = 25
    /// 遅いとみなす速さ (単位/s)。
    static let holdBelow: Float = 20

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
    /// いまの角速度 (ラジアン/s)。**正が右回り。** 前後のタイヤが車体を回した結果で、
    /// 舵から直に決まるものではない
    var turning: Float = 0
    /// いま描いている円の半径 (単位)。**速いほど大きくなる** — 横 G の上限があるので、
    /// 速さの 2 乗で伸びる
    var turnRadius: Float { abs(turning) < 1e-4 ? 99999 : speed / abs(turning) }
    /// 前の車の後ろに付いているか。**空気抵抗が 4 割減る** (誰にでも等しく効く)。
    var drafting = false
    /// 前後の荷重の移り (割合)。**正で後ろへ** (踏んだとき)。
    var transfer: Float = 0
    /// 前輪の実際の舵角 (ラジアン)。**逆舵の助けを足した後の値。**
    var wheelAngle: Float = 0
    /// タイヤが車体を横へ押している加速度 (単位/s²)。**正が右。**
    var sideForce: Float = 0
    /// 後輪の滑り角 (ラジアン)。
    var rearSlip: Float = 0
    /// 壁に当たって付いた回り (ラジアン/s)。**タイヤが回す `turning` とは別に持つ** —
    /// 遅いときは幾何の曲がりへ混ぜるので、`turning` へ足すと次の 1 歩で舵どおりの回りへ
    /// 引き戻され、鼻を壁へ向けたまま擦り続けた
    var knock: Float = 0
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
        step(h, controls: controls, slope: here.slope)

        // コースの上のどこにいるか
        let found = track.locate(place, near: index)
        // **周回の継ぎ目で s が飛ぶのを見逃さない** ように、呼ぶ側が前の値を見る
        s = found.s
        lateral = found.d
        index = found.index
    }

    /// 運動だけを 1 歩進める。**コースを見ない** (足の下と坂は呼ぶ側が決める)。
    mutating func step(_ h: Float, controls: Controls, slope: Float) {
        let sg = surface.grip
        var ahead = Track.forward(yaw)
        var right = Track.side(yaw)
        let u = simd_dot(velocity, ahead)
        let v = simd_dot(velocity, right)
        let r = turning

        // 1. 舵。**戻すほう (切り返しを含む) を速く**する。切り込みは速いほど遅く —
        // 高速で一気に切れると、直線で少し当てただけで跳ねるように向きが変わる
        let returning = controls.steer == 0 || steer * (controls.steer - steer) < 0
        let rate: Float = returning ? 6.0 : Math.mix(4.0, 2.4, Math.ramp(abs(u), 100, 450))
        steer += Math.clamp(controls.steer - steer, -rate * h, rate * h)
        // 動力学の効き (0 = 幾何だけ、1 = 動力学だけ)。**後退は常に 0**
        let dynamic = Math.ramp(u, Car.dynamicFrom, Car.dynamicTo)
        let lock = Car.lock(at: u)

        // 2. 前後。駆動と坂は向きを持ち、抵抗は動きに逆らう (`passive`)
        let push = controls.throttle * Car.drive * surface.power * (1 - Math.unit(u / Car.ceiling))
        var active = push - Car.gravity * slope
        // **前の車の後ろでは空気が薄い。** 速さの 2 乗に効く項だけが減る
        var passive = 2 + surface.drag + 0.00012 * u * u * (drafting ? 0.55 : 1)
        // タイヤが路面へ伝える前後の力。**荷重の移りと摩擦円はこれで決まる**
        var tyreX = push
        if controls.brake > 0 {
            if u > 6 {
                let stopping = controls.brake * Car.braking * sg
                passive += stopping
                tyreX -= stopping
            } else if u > -Car.reverseCeiling {
                // 止まってからブレーキを踏み続けたら下がる
                active -= controls.brake * Car.reversing
            }
        }
        if controls.handbrake {
            passive += Car.handbrakeDrag
            tyreX -= Car.handbrakeDrag
        }
        // **何も押さずに遅いときは止める。** 坂の上でも転がり出さない
        if controls.throttle < 0.01, controls.brake < 0.01, abs(u) < Car.holdBelow {
            passive += Car.hold
        }

        // 3. 荷重と、タイヤが出せる横の力
        let shift = Math.clamp(Car.transferPerG * tyreX / Car.gravity, -0.15, 0.15)
        transfer += (shift - transfer) * Math.chase(h, 0.08)
        let used = min(abs(tyreX) / (Car.grip * sg), 1)
        // **甘い摩擦円。** 全制動でも横の 7 割が残る
        let circle = (1 - 0.5 * used * used).squareRoot()
        let frontLoad = Car.rear / Car.wheelbase - transfer
        let rearLoad = Car.front / Car.wheelbase + transfer
        let capFront = Car.grip * frontLoad * sg * circle
        let capRear = Car.grip * Car.rearMargin * rearLoad * sg * circle
            * (controls.handbrake ? Car.handbrakeGrip : 1)

        // 4. 前輪の向き。**後輪がピークを越えたぶんだけ、進む向きへ返す** (逆舵の助け)
        let rearAngle = atan2(v - Car.rear * r, max(abs(u), Car.slipFloor))
        let beyond = rearAngle - Math.clamp(rearAngle, -Car.rearPeak, Car.rearPeak)
        let counter = Math.clamp((controls.handbrake ? 0.3 : 0.6) * beyond, -0.35, 0.35)
        let delta = steer * lock + dynamic * counter

        // 5. タイヤの横力。前輪は**車輪の向きで**速度を測る
        let frontSide = v + Car.front * r
        let alongWheel = u * cos(delta) + frontSide * sin(delta)
        let acrossWheel = frontSide * cos(delta) - u * sin(delta)
        let frontAngle = atan2(acrossWheel, max(abs(alongWheel), Car.slipFloor))
        let frontForce = -capFront * Car.tyre(frontAngle / Car.frontPeak, drop: Car.frontDrop)
        let rearForce = -capRear * Car.tyre(rearAngle / Car.rearPeak, drop: Car.rearDrop)
        let side = frontForce * cos(delta) + rearForce
        // 切った前輪は前へ進むのにも逆らう
        let scrub = -frontForce * sin(delta)
        var spinUp = (Car.front * frontForce * cos(delta) - Car.rear * rearForce) / Car.inertia

        // 6. **持てない回転だけを削る。** 横 G の上限の 1.15 倍を越えた角速度だけ。
        // あわせて、**後輪がピークを越えたぶんだけ回りを戻す** — 越えた向きへ回し続けると
        // 尻がさらに出るので、その逆へ。どちらも引き手を握っている間は切る
        if !controls.handbrake {
            let spinCap = 1.15 * Car.grip * sg / max(abs(u), 1)
            if abs(r) > spinCap {
                spinUp -= dynamic * 6 * (abs(r) - spinCap) * (r > 0 ? 1 : -1)
            }
            spinUp += dynamic * Car.recovery * beyond
        }

        // 7. 進める。**力は世界の向きで足し、向きを回してから測り直す** — 回した後の
        // 軸で見ると、横向きの成分が残る (これが滑りである)
        var nextTurning = r + spinUp * h
        velocity += (ahead * (active + scrub) + right * side) * h
        yaw = Track.wrap(yaw + (nextTurning + knock) * h)
        knock -= knock * Math.chase(h, 0.25)
        ahead = Track.forward(yaw)
        right = Track.side(yaw)
        var forward = simd_dot(velocity, ahead)
        var sideways = simd_dot(velocity, right)
        // **抵抗は動きを 0 で止め、逆向きへは押さない**
        forward -= (forward > 0 ? 1 : -1) * min(abs(forward), passive * h)

        // 8. 遅いときは幾何へ混ぜる。**前輪の向きだけで決まる角速度**と、後軸が横へ
        // 滑らないときの重心の横の速さ
        let reach = Car.grip * sg / max(abs(forward), 1)
        let geometric = Math.clamp(forward * tan(steer * lock) / Car.wheelbase, -reach, reach)
        let settled = sideways
            + Math.clamp(Car.rear * geometric - sideways, -Car.grip * sg * h, Car.grip * sg * h)
        nextTurning = Math.mix(geometric, nextTurning, dynamic)
        sideways = Math.mix(settled, sideways, dynamic)

        turning = nextTurning
        velocity = ahead * forward + right * sideways
        place += velocity * h
        slip = atan2(sideways, max(abs(forward), 1))
        wheelAngle = delta
        sideForce = side
        rearSlip = rearAngle
        // **車輪の回りも畳む。** 畳まないと 1 分で 1,600 ラジアンを超える
        spin = Track.wrap(spin + forward / 16 * h)

        // 見た目の傾き。**横 G で外へ傾き、前後 G で沈む**
        lean += (Math.clamp(side / Car.grip, -1, 1) * Math.radians(4.5) - lean) * Math.chase(h, 0.12)
        dive += (Math.clamp(tyreX / Car.grip, -1, 1) * Math.radians(2.5) - dive) * Math.chase(h, 0.14)
    }

    /// タイヤの横力の形 (0…1 の割合)。**`x` は滑り角をピークの角で割ったもの。**
    ///
    /// 原点の傾きは 2 で、ピーク (x = 1) で 1 に滑らかにつながる。越えると `drop` の
    /// ぶんだけ 1.5 倍の幅をかけて落ち、そこからは平ら
    static func tyre(_ x: Float, drop: Float) -> Float {
        let m = abs(x)
        let y = m <= 1 ? m * (2 - m) : 1 - drop * min((m - 1) / 1.5, 1)
        return x < 0 ? -y : y
    }

    // MARK: - 壁

    /// 路肩の外の壁で押し戻す。
    ///
    /// **(距離・横ずれ) の側で解く。** 世界の座標で壁の形を持たなくて済み、
    /// コースがどれだけ曲がっていても同じ形で済む。
    ///
    /// ## 当たった強さだけ返す
    ///
    /// 壁へ向かう速さに反発を掛けて返し、**接線にはその強さに比例した摩擦だけ**を掛ける。
    /// 当たった角から車体を回すので、鼻から当たれば壁に沿う向きへ回される。
    ///
    /// 以前は擦っている間ずっと速度に 0.997 を掛け、向きを 1 歩ごとに 2 割ずつ壁沿いへ
    /// 寄せていた。これが**壁に貼り付く**原因だった — 押し出された先の草で踏み続けても
    /// 12 km/h しか出ず、舵を切らない限り壁から離れなかった (#88)。いまは擦っているだけ
    /// (壁へ向かう速さがほぼ 0) なら、ほとんど何も失わない
    mutating func bounce(on track: Track) {
        guard abs(lateral) > Track.wallWidth else { return }
        let here = track.frame(at: s)
        let outward = Track.side(here.heading) * (lateral > 0 ? 1 : -1)
        lateral = lateral > 0 ? Track.wallWidth : -Track.wallWidth
        place = here.point + Track.side(here.heading) * lateral

        let into = simd_dot(velocity, outward)
        guard into > 0 else { return }
        let along = velocity - outward * into
        let slide = simd_length(along)
        let normal = (1 + Car.wallBounce) * into
        let rub = min(Car.wallFriction * normal, slide)
        let impulse = -outward * normal - (slide > 1e-3 ? along / slide : .zero) * rub
        velocity += impulse

        // **当たった角から回す。** 壁の側にある鼻か尻の角に撃力が掛かったとして、その
        // 回りの向きの成分だけを `knock` へ足す (右回りが正)
        let ahead = Track.forward(yaw)
        let corner = ahead * (simd_dot(ahead, outward) >= 0 ? 17 : -17) + outward * 9.5
        let twist = corner.y * impulse.x - corner.x * impulse.y
        knock = Math.clamp(knock + 0.3 * twist / Car.inertia, -1.5, 1.5)

        // **押し付けた強さのぶんだけ、壁沿いへ向きを寄せる。** 遅いときは車が横へ
        // 滑らないので、鼻を壁へ向けたまま踏むと壁に沿って動けず、そこで止まった
        // (30 単位/s・45° で当たると 0.1 km/h)。以前のように 1 歩ごとに決まった割合で
        // 寄せると、擦っているだけで貼り付く — だから当たった強さに比例させる
        let wall = simd_dot(ahead, Track.forward(here.heading)) >= 0 ? here.heading : here.heading + .pi
        yaw = Track.wrap(yaw + Track.wrap(wall - yaw) * min(Car.wallTurn * normal, 0.1))
        // **鼻か尻が壁を向いている間は、押し付けているだけでも回す。** 止まっていると
        // 当たった強さがごく小さいので、上の寄せだけでは直角に突っ込んだ車が壁沿いを
        // 向くまで 3 秒以上かかった。ほぼ平行 (10° 未満) なら回さない — 擦るだけで
        // 貼り付かないように
        if abs(simd_dot(ahead, outward)) > sin(Math.radians(10)) {
            let gap = Track.wrap(wall - yaw)
            yaw = Track.wrap(yaw + Math.clamp(gap, -Car.wallCreep / 120, Car.wallCreep / 120))
        }
    }

    /// 壁の反発係数。
    static let wallBounce: Float = 0.25
    /// 壁の摩擦 (当たった強さに対する割合)。
    static let wallFriction: Float = 0.3
    /// 押し付けた強さ (単位/s) あたりに壁沿いへ寄せる割合。
    static let wallTurn: Float = 0.04
    /// 鼻か尻が壁を向いている間に、壁沿いへ回す速さ (ラジアン/s)。**1 歩は 1/120 秒。**
    static let wallCreep: Float = 1.5

    /// その速さで切れる舵角の上限 (ラジアン)。**人も AI も同じ口を通る。**
    ///
    /// **キーを一杯に押したとき、前輪がちょうどピークを少し越える角にする。** その速さで
    /// 横 G の上限いっぱいに回る円の舵角 (`atan(L·grip/u²)`) に、前輪の滑り角のぶんを
    /// 足したもの。遅いときは 34° で頭打ちになる
    static func lock(at pace: Float) -> Float {
        let u = max(abs(pace), 1)
        return min(Math.radians(34), atan(Car.wheelbase * Car.grip / (u * u)) + Math.radians(4))
    }
}
