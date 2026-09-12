import Foundation
import mokume
import simd

/// 品種。**色だけでなく、斑の出し方が違う。**
enum Variety: Int, CaseIterable {
    /// 紅白 — 白地に紅。
    case kohaku = 0
    /// 大正三色 — 紅白の背に墨が乗る。
    case sanke = 1
    /// 昭和三色 — 黒地に紅と白。
    case showa = 2
    /// 黄金 — 単色で、鱗の照りだけが模様になる。
    case ogon = 3
    /// 浅黄 — 背は藍の網目、脇腹が緋。
    case asagi = 4
    /// 白写り — 黒地に白。
    case utsuri = 5

    /// 地の色。
    var skin: LinearRGBA {
        switch self {
        case .kohaku, .sanke: .display(red: 0.94, green: 0.93, blue: 0.90)
        case .showa, .utsuri: .display(red: 0.10, green: 0.10, blue: 0.12)
        case .ogon: .display(red: 0.86, green: 0.62, blue: 0.16)
        case .asagi: .display(red: 0.40, green: 0.50, blue: 0.60)
        }
    }

    /// 紅 (beni)。
    var beni: LinearRGBA {
        switch self {
        case .asagi: .display(red: 0.74, green: 0.26, blue: 0.12)
        case .ogon: .display(red: 0.96, green: 0.78, blue: 0.34)
        default: .display(red: 0.80, green: 0.16, blue: 0.07)
        }
    }

    /// 墨 (sumi) と白。
    var sumi: LinearRGBA {
        switch self {
        case .showa, .utsuri: .display(red: 0.95, green: 0.94, blue: 0.92)
        case .asagi: .display(red: 0.13, green: 0.20, blue: 0.31)
        default: .display(red: 0.08, green: 0.08, blue: 0.10)
        }
    }

    /// 鰭の色。**鰭は薄いので、地の色より水に近い。**
    var fin: LinearRGBA {
        switch self {
        case .ogon: .display(red: 0.82, green: 0.63, blue: 0.26)
        case .showa, .utsuri: .display(red: 0.30, green: 0.30, blue: 0.33)
        case .asagi: .display(red: 0.66, green: 0.42, blue: 0.30)
        default: .display(red: 0.90, green: 0.83, blue: 0.78)
        }
    }

    /// 鱗の照りの強さ。**黄金だけが金属質に光る。**
    var sheen: Float {
        switch self {
        case .ogon: 1.0
        case .asagi: 0.55
        default: 0.30
        }
    }
}

/// 鯉 1 匹。
///
/// ## 背骨は「引かれる鎖」で作る
///
/// 頭だけが自分で進み、後ろの節は前の節から一定の距離で引かれる。曲がれば体が後から
/// 湾曲するので、**旋回の形を手で書かなくてよい。** 首を振る角度に上限を置いて
/// あるのは、急旋回で体が折り返してしまわないようにするためである。
///
/// ## 泳ぎの波は、進んだ結果へ後から足している
///
/// 本当は体をくねらせるから進むのだが、ここではその向きを逆にしてある —
/// 進んだぶんだけ鎖が伸び、その鎖へ頭から尾へ向かう波を重ねる。**打つ速さは
/// 泳ぐ速さから決める** (魚は尾を 1 回打つごとに体長の 0.6 倍ほど進む) ので、
/// 流しているときはゆっくり、逃げるときは速く打つ。ここは物理ではなく約束である。
///
/// ## 尾を打つたびに水を蹴る
///
/// 速く泳いでいるときだけ、尾の位置から小さな輪を置く。**航跡は描いていない** —
/// 打つたびに置いた輪が後ろへ残るので、結果として V 字に見える。
final class Koi {

    /// 背骨を測る点の数。
    static let samples = 23

    /// 真上から見た体の幅 (最大の半幅に対する割合)。
    ///
    /// 鼻先が 0、いちばん太いのが頭から 27%、尾の付け根 (尾柄) で 0.10 まで細る
    private static let profile: [Float] = [
        0.10, 0.44, 0.66, 0.81, 0.92, 0.98, 1.00, 1.00, 0.99, 0.96, 0.92,
        0.87, 0.81, 0.74, 0.67, 0.59, 0.51, 0.43, 0.36, 0.30, 0.25, 0.21, 0.18,
    ]

    let variety: Variety
    /// 個体ごとの種。**同じ品種でも斑の出方が違う。**
    let seed: SIMD2<Float>
    /// 鼻先から尾柄までの長さ (mm)。
    let length: Float
    /// 水面からの深さ (mm)。**濁りの強さと大きさに効く。**
    let depth: Float

    private(set) var head: SIMD2<Float>
    private(set) var heading: SIMD2<Float>
    private(set) var speed: Float

    /// 背骨の節 (引かれる鎖)。0 が鼻先。
    private var chain: [SIMD2<Float>]
    /// 泳ぎの波を足した、描くための背骨。
    private(set) var pose: [SIMD2<Float>]

    private var tailPhase: Float
    private var beats: Float = 0
    private let wanderSeed: Float
    private var lastBeat: Float = -1

    var maximumHalfWidth: Float { length * 0.118 }

    init(variety: Variety, at place: SIMD2<Float>, heading angle: Float,
         length: Float, depth: Float, seed: SIMD2<Float>, phase: Float) {
        self.variety = variety
        self.seed = seed
        self.length = length
        self.depth = depth
        self.head = place
        self.heading = SIMD2(cos(angle), sin(angle))
        self.speed = 70
        self.tailPhase = phase
        self.wanderSeed = seed.x * 6.1
        let link = length / Float(Self.samples - 1)
        chain = (0..<Self.samples).map { place - SIMD2(cos(angle), sin(angle)) * (Float($0) * link) }
        pose = chain
    }

    // MARK: - 泳ぐ

    /// 1 フレーム進める。
    ///
    /// 向きは「行きたい向き」を足し合わせてから、**首を振れる速さの上限**で追い込む。
    /// 上限があるので、餌が真後ろに落ちても瞬時に振り向かず、弧を描いて戻ってくる
    func swim(
        dt: Float, now: Float, bounds: SIMD2<Float>, school: [Koi],
        food: SIMD2<Float>?, scare: (place: SIMD2<Float>, strength: Float)?,
        water: Water
    ) {
        let side = SIMD2(-heading.y, heading.x)
        var want = heading * 1.4
        var target: Float = 70

        // さまよい。**向きの揺れは 2 つの周期を重ねる** — 1 つだと振り子に見える
        let slow: Float = sin(now * 0.23 + wanderSeed)
        let quick: Float = sin(now * 0.61 + wanderSeed * 2.3)
        want += side * (slow * 0.22 + quick * 0.09)

        // 縁を避ける。**押し返しは距離の 2 乗で効かせる** — 縁ぎりぎりで急に曲がる。
        // 曲がれる速さに上限があるので、**体 1 つぶん以上手前から効かせる**
        let margin: Float = 430
        if head.x < margin { want.x += pow(1 - head.x / margin, 2) * 2.2 }
        if head.x > bounds.x - margin { want.x -= pow(1 - (bounds.x - head.x) / margin, 2) * 2.2 }
        if head.y < margin { want.y += pow(1 - head.y / margin, 2) * 2.2 }
        if head.y > bounds.y - margin { want.y -= pow(1 - (bounds.y - head.y) / margin, 2) * 2.2 }

        // 仲間を避ける。**深さが近いときだけ強く効く** — すれ違う深さが違えば重なってよい
        for other in school where other !== self {
            let gap = head - other.head
            let far = simd_length(gap)
            let reach = (length + other.length) * 0.42
            if far < reach && far > 1 {
                let layered = 1 - min(abs(depth - other.depth) / 60, 1) * 0.7
                want += gap / far * ((1 - far / reach) * 2.6 * layered)
            }
        }

        // 餌へ向かう。**近づいたら速さを落とす** — 曲がれる半径は速さに比例するので、
        // 全速のまま寄ると口が届く前に行き過ぎ、**餌の周りを回り続ける**
        // (実際にそうなった: 6.7 秒回して 1 粒も食べなかった)
        if let food {
            let toward = food - head
            let far = simd_length(toward)
            if far > 1 {
                want += toward / far * 3.2
                target = min(210, 52 + far * 0.62)
            }
        }

        // 指から逃げる。**餌より強い** — 寄っていても手が来れば散る
        if let scare {
            let away = head - scare.place
            let far = simd_length(away)
            if far > 1 {
                want += away / far * (5.5 * scare.strength)
                target = max(target, 150 + 180 * scare.strength)
            }
        }

        // 向きを追い込む
        let wantLength = simd_length(want)
        if wantLength > 1e-4 {
            let desired = want / wantLength
            var turn = atan2(
                heading.x * desired.y - heading.y * desired.x, simd_dot(heading, desired))
            // **曲がれる速さは体の長さで決まる。** 魚の最小旋回半径は体長の
            // 1 倍ほどで、それより速く首を振らせると体が輪になって折り返す
            // (ここを速さだけで決めていたときは、6 匹とも巻き貝になった)
            let limit = min(max(speed / (length * 0.85), 0.30), 0.9) * dt
            turn = min(max(turn, -limit), limit)
            heading = SIMD2(
                heading.x * cos(turn) - heading.y * sin(turn),
                heading.x * sin(turn) + heading.y * cos(turn))
        }

        // 速さは急に変えない。**逃げるほうが戻るより速い**
        let rate: Float = target > speed ? 2.6 : 0.9
        speed += (target - speed) * min(dt * rate, 1)
        head += heading * (speed * dt)
        head = simd_clamp(head, SIMD2(-160, -160), bounds + SIMD2(160, 160))

        follow()
        beat(dt: dt, now: now, water: water)
        shapeBody()
    }

    /// 鎖を引く。**前の節から一定距離**に置き直すだけ。
    private func follow() {
        let link = length / Float(Self.samples - 1)
        chain[0] = head
        var previous = -heading
        for index in 1..<Self.samples {
            var gap = chain[index] - chain[index - 1]
            var far = simd_length(gap)
            if far < 1e-4 {
                gap = previous
                far = 1
            }
            var direction = gap / far
            // 折れすぎない。隣り合う節の角度差に上限を置く
            let bend = atan2(
                previous.x * direction.y - previous.y * direction.x,
                simd_dot(previous, direction))
            let limit: Float = 0.30
            if abs(bend) > limit {
                let turn = bend > 0 ? limit : -limit
                direction = SIMD2(
                    previous.x * cos(turn) - previous.y * sin(turn),
                    previous.x * sin(turn) + previous.y * cos(turn))
            }
            chain[index] = chain[index - 1] + direction * link
            previous = direction
        }
    }

    /// 尾を打つ。**1 打ちで体長の 0.6 倍だけ進む**ので、速さから打つ回数が決まる。
    private func beat(dt: Float, now: Float, water: Water) {
        let rate = max(0.34, speed / (0.60 * length))
        tailPhase += rate * dt
        beats += rate * dt
        // 速く泳いでいるときだけ水を蹴る。流しているときの尾は水を置いていかない
        if speed > 66, floor(beats) != lastBeat {
            lastBeat = floor(beats)
            water.ripple(
                at: pose[Self.samples - 1], now: now,
                amplitude: 0.75 + speed * 0.0045, wavelength: 78, life: 0.85)
        }
    }

    /// 鎖へ泳ぎの波を足して、描くための背骨にする。
    ///
    /// 振幅は尾へ向かって 2 乗で増やす (carangiform — 前半はほとんど動かず、
    /// 後ろ 3 分の 1 で振れる)。**流しているときは振らない**ので、速さで縮める
    private func shapeBody() {
        let swing = min(0.25 + speed / 260, 1.25)
        for index in 0..<Self.samples {
            let u = Float(index) / Float(Self.samples - 1)
            let tangent = tangentOfChain(at: index)
            let normal = SIMD2(-tangent.y, tangent.x)
            let amplitude = length * (0.004 + 0.055 * u * u) * swing
            pose[index] = chain[index] + normal * (amplitude * sin(2 * Float.pi * (u * 0.85 - tailPhase)))
        }
    }

    private func tangentOfChain(at index: Int) -> SIMD2<Float> {
        let a = chain[max(index - 1, 0)]
        let b = chain[min(index + 1, Self.samples - 1)]
        let gap = a - b
        let far = simd_length(gap)
        return far > 1e-4 ? gap / far : heading
    }

    /// 描くための背骨の接線。
    private func tangent(at index: Int) -> SIMD2<Float> {
        let a = pose[max(index - 1, 0)]
        let b = pose[min(index + 1, Self.samples - 1)]
        let gap = a - b
        let far = simd_length(gap)
        return far > 1e-4 ? gap / far : heading
    }

    // MARK: - 形

    /// 体の輪郭の片側。
    func flank(_ sign: Float) -> [SIMD2<Float>] {
        (0..<Self.samples).map { index in
            let tangent = tangent(at: index)
            let normal = SIMD2(-tangent.y, tangent.x)
            return pose[index] + normal * (Self.profile[index] * maximumHalfWidth * sign)
        }
    }

    /// 尾柄の位置・体の後ろへ伸びる向き・尾鰭が撓む角 (ラジアン)。
    ///
    /// **尾鰭は体より遅れて撓む。** 打った波が尾鰭へ届くまでの遅れであり、鰭が水を
    /// 掴んで反り返るぶんでもある。位相を 0.22 周期ぶん遅らせてある。
    ///
    /// **向きそのものは回さず、撓む角を別に返す。** 真上から見た尾鰭は板ではなく
    /// 刃なので (`School.blade`)、絵になるのは「どちらへどれだけ反っているか」であって
    /// 「どちらを向いた扇か」ではない
    var caudal: (base: SIMD2<Float>, direction: SIMD2<Float>, cup: Float) {
        let base = pose[Self.samples - 1]
        let backward = -tangent(at: Self.samples - 1)
        let swing = min(0.3 + speed / 240, 1.2)
        let cup = sin(2 * Float.pi * (0.85 - tailPhase - 0.22)) * 0.66 * swing
        return (base, backward, cup)
    }

    /// 背骨のその節の、位置と体の横向き。**背鰭を立てるのに要る。**
    func rib(at index: Int) -> (place: SIMD2<Float>, side: SIMD2<Float>) {
        let forward = tangent(at: index)
        return (pose[index], SIMD2(-forward.y, forward.x))
    }

    /// 胸鰭の付け根と、鰭が伸びる向き。**ゆっくり漕ぐ。**
    func pectoral(_ sign: Float) -> (base: SIMD2<Float>, direction: SIMD2<Float>) {
        // **鰓蓋のすぐ後ろ。** 体のいちばん太いところ (index 6) に置くと、
        // 腹から翼が生えているように見える
        let index = 4
        let tangent = tangent(at: index)
        let normal = SIMD2(-tangent.y, tangent.x)
        let base = pose[index] + normal * (Self.profile[index] * maximumHalfWidth * sign * 0.85)
        let paddle = sin(2 * Float.pi * tailPhase * 0.55 + (sign > 0 ? 0 : 0.5)) * 0.30
        // **回す向きは法線と逆符号。** 揃えると鰭が体の下へ潜り、
        // どの鯉にも胸鰭が見えなくなる (実際にそうなっていた)
        return (base, Self.turn(-tangent, by: -(0.52 + paddle) * sign))
    }

    /// 向きを回す。
    static func turn(_ direction: SIMD2<Float>, by angle: Float) -> SIMD2<Float> {
        SIMD2(
            direction.x * cos(angle) - direction.y * sin(angle),
            direction.x * sin(angle) + direction.y * cos(angle))
    }
}
