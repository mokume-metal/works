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
/// 泳ぐ速さから決める** (鯉は尾を 1 回打つごとに体長の 0.45 倍ほど進む) ので、
/// 流しているときはゆっくり、逃げるときは速く打つ。ここは物理ではなく約束である。
///
/// ## 尾を打つたびに水を蹴る
///
/// 速く泳いでいるときだけ、尾の位置から小さな輪を置く。**航跡は描いていない** —
/// 打つたびに置いた輪が後ろへ残るので、結果として V 字に見える。
final class Koi {

    /// 背骨を測る点の数。
    static let samples = 23

    /// 真上から見た体の輪郭。**背骨の節とは別に置いてある。**
    ///
    /// `u` は鼻先 0・尾柄 1、値は最大半幅に対する割合。
    ///
    /// ## 節に合わせて 23 等分すると、鼻が尖る
    ///
    /// はじめは背骨の節 (23 個・4.5% 刻み) と同じ位置で幅を置いていた。鯉の鼻先は
    /// **体長の 1% 足らずで最大半幅の 2 割まで立ち上がる**ので、4.5% 刻みでは
    /// そこを 1 本の斜辺で結ぶことになり、**鼻が楔に尖る。** ここを頭のほうだけ
    /// 細かく刻んであるのは、丸い鼻先を丸いまま描くためである。
    ///
    /// ## 頭は実測した
    ///
    /// 上見の写真 (Wikimedia Commons の
    /// [2 year old Aka Muji](https://commons.wikimedia.org/wiki/File:2_year_old_Aka_Muji.jpg)、
    /// CC BY-SA。青い舟に浮かべた単色の鯉を真上から撮ったもの) の 1 匹を体軸へ
    /// 回してから、軸に垂直な走査線ごとに**紅と青の変わり目**を拾って半幅を測った
    /// (画像の閾値で切り分けると照りで穴が空くので、局所の変わり目で見ている)。
    ///
    /// 分かったこと:
    ///
    /// - **鼻先は丸い。** 鼻から体長の 0.4% で既に最大半幅の 0.21、1.2% で 0.30。
    ///   ここを 0.10 から始めていたのが「顔が尖って見える」の正体だった
    /// - **最大幅は体長の 0.24 倍** (半幅 0.12)。置いてあった 0.236 とほぼ同じで、
    ///   ここは動かさなくてよかった
    /// - **いちばん太いのは頭から 30% 前後。** 27% で 0.98、31% で 1.00
    ///
    /// **後ろ半分は測り直していない。** 舟の鯉はどれも体を曲げていて、直線の軸で
    /// 走査すると斜めに切ることになり幅が過大に出る。尾筒だけは上見の評価軸
    /// (太い尾筒がよいとされる) に合わせて 0.18 → 0.22 へわずかに太らせた
    static let outline: [(u: Float, half: Float)] = [
        (0.000, 0.00), (0.004, 0.21), (0.012, 0.30), (0.022, 0.34), (0.035, 0.41),
        (0.050, 0.49), (0.070, 0.60), (0.090, 0.68), (0.115, 0.75), (0.140, 0.80),
        (0.170, 0.86), (0.200, 0.91), (0.230, 0.95), (0.270, 0.98), (0.310, 1.00),
        (0.360, 0.99), (0.410, 0.96), (0.460, 0.92), (0.520, 0.84), (0.580, 0.76),
        (0.640, 0.66), (0.700, 0.56), (0.760, 0.44), (0.820, 0.36), (0.880, 0.30),
        (0.940, 0.25), (1.000, 0.22),
    ]

    /// その位置の半幅 (最大半幅に対する割合)。**輪郭の表を線形に読む。**
    static func halfWidth(at u: Float) -> Float {
        let t = min(max(u, 0), 1)
        for index in 1..<outline.count where outline[index].u >= t {
            let a = outline[index - 1]
            let b = outline[index]
            let span = b.u - a.u
            return span > 1e-6 ? a.half + (b.half - a.half) * ((t - a.u) / span) : a.half
        }
        return outline[outline.count - 1].half
    }

    let variety: Variety
    /// 個体ごとの種。**同じ品種でも斑の出方が違う。**
    let seed: SIMD2<Float>
    /// 鼻先から尾柄までの長さ (mm)。
    let length: Float
    /// 水面からの深さ (mm)。**濁りの強さと影の広がりに効く。**
    ///
    /// **固定していない。** 池の鯉は上下にも動くもので、沈めば濁りに溶けて影が広がり、
    /// 浮けば色が戻る。長く映していても同じ層の重なりにならないのはこれのため
    private(set) var depth: Float

    private(set) var head: SIMD2<Float>
    private(set) var heading: SIMD2<Float>
    private(set) var speed: Float

    /// 口の位置。**背骨の先端がそのまま鼻先**で、餌はここへ届いたときだけ消える。
    var mouth: SIMD2<Float> { pose[0] }

    /// 背骨の節 (引かれる鎖)。0 が鼻先。
    private var chain: [SIMD2<Float>]
    /// 泳ぎの波を足した、描くための背骨。
    private(set) var pose: [SIMD2<Float>]

    private var tailPhase: Float
    private var beats: Float = 0
    private let wanderSeed: Float
    private var lastBeat: Float = -1
    /// 出来事の籤に使う塩。**個体ごとに違う予定表になる。**
    private let stirSalt: UInt64
    /// いま突進しているか。**近くの仲間はこれに驚く。**
    private(set) var dashing = false
    /// 深さの落ち着き先 (mm)。**ここを中心に漂う。**
    private let depthHome: Float

    var maximumHalfWidth: Float { length * 0.118 }

    init(variety: Variety, at place: SIMD2<Float>, heading angle: Float,
         length: Float, depth: Float, seed: SIMD2<Float>, phase: Float) {
        self.variety = variety
        self.seed = seed
        self.length = length
        self.depth = depth
        self.head = place
        self.heading = SIMD2(cos(angle), sin(angle))
        self.speed = length * 0.45
        self.tailPhase = phase
        self.wanderSeed = seed.x * 6.1
        self.stirSalt = UInt64(seed.x * 97 + seed.y * 31) &+ 6_120_713
        self.depthHome = depth
        let link = length / Float(Self.samples - 1)
        chain = (0..<Self.samples).map { place - SIMD2(cos(angle), sin(angle)) * (Float($0) * link) }
        pose = chain
    }


    // MARK: - 出来事

    /// ときどき起きること。
    ///
    /// **ふだんはゆったりでよい。** ただ、巡航に緩い揺れを足し続けるだけだと、
    /// 長く映したときに「同じ絵がずっと続く」ようにしか見えない。**たまに何かが
    /// 起きて、また静かに戻る**という時間の緩急が要る。
    enum Stir {
        /// 突進。
        case dart
        /// 翻る。**突進に大きな転回を重ねたもの。**
        case turn
        /// 漂う。**ほとんど止まる。**
        case hover
        /// 渡る。**さまよわずまっすぐ泳ぐ。**
        case cross
    }

    private struct Event {
        var kind: Stir
        var born: Float
        var life: Float
        /// 目標の速さ (体長 / 秒)。
        var pace: Float
        /// 転回の角 (rad)。`turn` だけが使う。
        var swerve: Float
    }

    /// 出来事の間隔の目安 (秒)。**6 匹なら池全体で 40 秒に 1 つ。**
    static let stirSpacing: Float = 240

    /// 群れの活気 (0.66…1.34)。
    ///
    /// **数分かけて静と動を行き来する。** 周期の噛み合わない 2 つの正弦なので
    /// 繰り返しが読めない (風向きの首振りと同じ作法)。巡航の速さ・さまよいの幅・
    /// 出来事の起きやすさに掛かる
    static func liveliness(now: Float) -> Float {
        1.0 + 0.22 * sin(now * 0.019 + 0.7) + 0.12 * sin(now * 0.0071 + 2.3)
    }

    /// 何番目かの出来事。**時刻だけから決まる** (風の斑と同じ作法)。
    ///
    /// 賽を毎フレーム振ると、引く回数がフレームの刻みで変わって速い機械ほど
    /// 忙しい池になる。番号で種を作れば予定表は時刻の関数のままでいられる
    private func event(_ index: Int) -> Event? {
        guard index >= 0 else { return nil }
        var draw = Scatter(counting: index, salt: stirSalt)
        let born = Float(index) * Self.stirSpacing + draw.next(0, Self.stirSpacing * 0.92)
        // **静かなときは、起きるはずだった出来事が流れる。** 活気が低い数分は
        // 池全体が本当に静かになる
        guard draw.next(0, 1) < 0.30 + 0.62 * Self.liveliness(now: born) else { return nil }
        switch Int(draw.next(0, 4)) {
        case 0:
            return Event(kind: .dart, born: born, life: draw.next(0.6, 1.1),
                         pace: draw.next(2.6, 3.2), swerve: 0)
        case 1:
            // **C スタートの転回角そのもの** (実測で約 150 度)
            return Event(kind: .turn, born: born, life: draw.next(0.7, 1.2),
                         pace: draw.next(2.4, 3.0),
                         swerve: draw.next(1.7, 2.6) * (draw.next(0, 1) < 0.5 ? -1 : 1))
        case 2:
            return Event(kind: .hover, born: born, life: draw.next(3.0, 6.0),
                         pace: 0.10, swerve: 0)
        default:
            return Event(kind: .cross, born: born, life: draw.next(4.0, 8.0),
                         pace: draw.next(0.8, 1.0), swerve: 0)
        }
    }

    /// いま起きている出来事。**隣り合う 2 番だけを見れば足りる** (寿命 < 間隔)。
    private func stirring(now: Float) -> Event? {
        let turn = Int((now / Self.stirSpacing).rounded(.down))
        for index in [turn - 1, turn] {
            guard let event = event(index) else { continue }
            if now >= event.born, now - event.born <= event.life { return event }
        }
        return nil
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
        // **巡航は体長の 0.45 倍 / 秒。** 速さを画素で置いていたときは、
        // 体長 300 mm の鯉が 0.23 体長 / 秒でしか進まず、尾を 2.6 秒に 1 回しか
        // 打たなかった — 体がくねっているようには見えなかった。
        // **群れの活気で伸び縮みする** — 静かな数分と活気づく数分が交互に来る
        let mood = Self.liveliness(now: now)
        var target = length * 0.45 * mood

        // さまよい。**向きの揺れは 2 つの周期を重ねる** — 1 つだと振り子に見える
        let slow: Float = sin(now * 0.23 + wanderSeed)
        let quick: Float = sin(now * 0.61 + wanderSeed * 2.3)
        var wander = (slow * 0.15 + quick * 0.06) * mood

        // 縁を避ける。**押し返しは距離の 2 乗で効かせる** — 縁ぎりぎりで急に曲がる。
        // 曲がれる速さに上限があるので、**体 1 つぶん以上手前から効かせる**
        let margin: Float = 430
        if head.x < margin { want.x += pow(1 - head.x / margin, 2) * 2.2 }
        if head.x > bounds.x - margin { want.x -= pow(1 - (bounds.x - head.x) / margin, 2) * 2.2 }
        if head.y < margin { want.y += pow(1 - head.y / margin, 2) * 2.2 }
        if head.y > bounds.y - margin { want.y -= pow(1 - (bounds.y - head.y) / margin, 2) * 2.2 }

        // 仲間との間合い。**Boids の 3 則と、すれ違いの先読み** (`shoal`)
        let flock = shoal(school)
        want += flock.steer

        // **仲間の突進に驚く。** 逃避は群れに伝わるもので、これがあると
        // 「1 匹の出来事」が「群れの出来事」になる
        if flock.alarm > 0 {
            want += flock.away * (2.6 * flock.alarm)
            target = max(target, length * (0.9 + 0.9 * flock.alarm))
        }

        // ときどき起きること。**予定は時刻だけから決まる** (`event`)
        var rush: Float = 0
        dashing = false
        if let stir = stirring(now: now) {
            let age = now - stir.born
            switch stir.kind {
            case .dart, .turn:
                dashing = true
                // **立ち上がりを潰さない。** 尾を打った瞬間から速い
                target = max(target, length * stir.pace)
                rush = 1
                if case .turn = stir.kind, age < 0.22 {
                    // **C スタート。** 体を折って向きを変える 0.22 秒だけ、
                    // 首を振れる速さの縛りを外す (実測の転回角は約 150 度)
                    want = Self.turn(heading, by: stir.swerve) * 4.0
                    rush = 2
                }
            case .hover:
                // **漂う。** 尾はほとんど止まり、胸鰭だけが漕ぐ
                target = min(target, length * stir.pace)
                wander *= 0.3
            case .cross:
                // **渡る。** さまよいを抑えてまっすぐ泳ぐ
                target = max(target, length * stir.pace)
                wander *= 0.15
            }
        }
        want += side * wander

        // 餌へ向かう。**近づいたら速さを落とす** — 曲がれる半径は速さに比例するので、
        // 全速のまま寄ると口が届く前に行き過ぎ、**餌の周りを回り続ける**
        // (実際にそうなった: 6.7 秒回して 1 粒も食べなかった)
        var reaching = false
        if let food {
            let toward = food - head
            let far = simd_length(toward)
            if far > 1 {
                let aim = toward / far
                want += aim * 3.2
                target = min(length * 0.72, length * 0.2 + far * 0.62)
                reaching = far < length * 0.9
                // **食いつく瞬間だけ跳ねる。** 近づくほど落とす減速はそのままで、
                // 口が届く手前で狙いが付いているときにだけ一息に詰める — 魚が
                // 実際にそうするし、狙いが付いてからなので餌の周りを回る挙動
                // (旋回半径を体長に縛った副作用) には戻らない
                if far < length * 0.30, simd_dot(aim, heading) > 0.90 {
                    target = length * 1.6
                    rush = max(rush, 1)
                }
            }
        }

        // **前が塞がっていたら速さを落とす。** 曲がれる半径は体長の 1.3 倍に
        // 縛られているので、向きを変えるだけでは擦れ違えない場面が残る。魚が
        // 実際にそうするように、詰まったら鰭を立てて減速する
        target *= flock.room

        // 指から逃げる。**餌より強い** — 寄っていても手が来れば散る
        if let scare {
            let away = head - scare.place
            let far = simd_length(away)
            if far > 1 {
                want += away / far * (5.5 * scare.strength)
                target = max(target, length * (0.5 + 0.55 * scare.strength))
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
            // (ここを速さだけで決めていたときは、6 匹とも巻き貝になった)。
            //
            // **1.3 倍まで緩めてある。** 0.85 倍では旋回中の体が常に弓なりで、
            // 「曲がったまま滑っている」ようにしか見えなかった — 泳ぎの波より
            // 旋回の曲がりのほうが大きいと、くねりがその中に埋もれる。
            //
            // **餌が目の前にあるときだけ、その場で向きを変えられる。** 魚は遅い
            // ところでは体ではなく鰭で向きを変えるので、口を餌へ持っていくときは
            // 旋回半径の縛りが外れる — これが無いと、口の当たり判定を実寸まで
            // 絞ったとたんに餌の周りを回り続ける
            // **仲間と擦れ違う間際も、少しだけ緩める。** 魚は差し迫ると体を
            // C 字に折って向きを変える。ここを巡航のままにしておくと、先読みで
            // 早めに逸れ始めても最後の詰めが足りずに触れる
            let pivot: Float = reaching ? 0.95 : 0.22 + flock.urgency * 0.75
            // **翻る一瞬だけ、縛りを外す。** 150 度を 0.22 秒で回るので 12 rad/s
            let ceiling: Float = rush > 1 ? 12 : 1.1
            let limit = min(max(speed / (length * 1.3), pivot), ceiling) * dt
            turn = min(max(turn, -limit), limit)
            heading = SIMD2(
                heading.x * cos(turn) - heading.y * sin(turn),
                heading.x * sin(turn) + heading.y * cos(turn))
        }

        // 速さは急に変えない。**逃げるほうが戻るより速い**。
        // **突進と食いつきだけは別格** — 加速は 9000 mm/s² ほどで、C スタートの
        // 実測 (54000 mm/s²) の 6 分の 1。抜けた後は普通の減速でゆっくり惰行する
        let rate: Float = rush > 0 ? 12 : (target > speed ? 2.6 : 0.9)
        speed += (target - speed) * min(dt * rate, 1)
        head += heading * (speed * dt)
        head = simd_clamp(head, SIMD2(-160, -160), bounds + SIMD2(160, 160))

        sink(dt: dt, now: now, reaching: reaching)
        follow()
        beat(dt: dt, now: now, water: water)
        shapeBody()
    }

    // MARK: - 群れ

    /// 先読みする長さ (秒)。**巡航なら体長 1 つぶん先**まで見ている。
    private static let lookahead: Float = 2.6

    /// 仲間との間合い。**Boids の 3 則に、すれ違いの先読みを足したもの。**
    ///
    /// 1. **離れる** — 近すぎる仲間から押し返される
    /// 2. **揃える** — 近くの仲間と向きを合わせる
    /// 3. **寄る** — 離れすぎたときだけ、群れの真ん中へ弱く引かれる
    /// 4. **先読み** — 相対速度から最接近の時刻を出し、**そのとき擦れ違えないなら
    ///    いまのうちに逸れる**
    ///
    /// ## 押し返すだけでは、重なってから離れることになる
    ///
    /// 4 を足してあるのは、曲がれる速さに上限があるからである。1 だけで組むと、
    /// 反応が始まるのは触れる直前になる — 体長 344 mm の鯉は旋回半径 450 mm で
    /// しか曲がれないので、そこから避け始めても間に合わない。**最接近まで 2.6 秒を
    /// 見ておけば 50 度ぶんの猶予がある**ので、ゆっくり逸れるだけで擦れ違える。
    /// 避けているように見えるかどうかは、力の強さではなく**いつ始めるか**で決まる。
    ///
    /// ## 鯉は点ではない
    ///
    /// 間合いを頭同士で測っていたときは、頭が 270 mm 離れていれば何も起きなかった。
    /// **体長 344 mm の鯉の横腹は、その距離で平気で重なる。** いま測っているのは
    /// 自分の頭と**相手の背骨のいちばん近いところ**で、横切られたぶんも拾う。
    ///
    /// ## 深さが離れていれば、上を通ってよい
    ///
    /// 鯉の体の厚みは体長の 2 割ほどなので、それより深さが離れていれば重なって
    /// 見えても構わない — 実際に池の鯉はそうやって擦れ違う。**ここを 60 mm で
    /// 切っていたときは、6 匹中ほとんどの組が「別の層」と見なされ**、避ける力が
    /// 7 割も削がれていた。それが重なって見えた元である。
    ///
    /// ## 突進は伝わる
    ///
    /// 5 つ目として、**近くの仲間が突進していたら驚く**を足してある。魚群の逃避は
    /// 隣へ伝わるもので、これがあると「1 匹の出来事」が「群れの出来事」になる
    private func shoal(_ school: [Koi]) -> (
        steer: SIMD2<Float>, room: Float, urgency: Float, alarm: Float, away: SIMD2<Float>
    ) {
        var steer = SIMD2<Float>.zero
        var align = SIMD2<Float>.zero
        var centre = SIMD2<Float>.zero
        var seen: Float = 0
        var room: Float = 1
        var urgency: Float = 0
        var alarm: Float = 0
        var flee = SIMD2<Float>.zero
        var closest = Float.greatestFiniteMagnitude

        // 見える範囲。**体長の 2.4 倍。** 魚は側線で近くの仲間だけを感じている
        let vision = length * 2.4
        let side = SIMD2(-heading.y, heading.x)

        for other in school where other !== self {
            let gap = other.head - head
            let far = simd_length(gap)
            guard far < vision + other.length else { continue }

            // 体の厚みぶん深さが離れていれば、上を通り抜けられる
            let thickness = (length + other.length) * 0.11
            let apart = min(abs(depth - other.depth) / thickness, 1)
            let solid = 1 - apart * 0.30

            // 1. 離れる — **相手の背骨のいちばん近いところ**から押し返される
            let touch = other.nearest(to: head)
            closest = min(closest, touch.far)
            let skin = (maximumHalfWidth + other.maximumHalfWidth) * 4.0
            if touch.far < skin, touch.far > 1e-3 {
                let away = (head - touch.place) / touch.far
                let press = 1 - touch.far / skin
                steer += away * (press * press * 6.5 * solid)
                // 触れそうなときは**首を振れる速さも緩める** (下の 4 と同じ扱い)
                urgency = max(urgency, press * press * solid)
            }

            // 5. 驚く — **突進している仲間の近くにいたら、そこから逸れる**
            if other.dashing {
                let startle = 1 - min(far / (length * 2.2), 1)
                if startle > alarm, far > 1e-3 {
                    alarm = startle
                    flee = -gap / far
                }
            }

            // 2 と 3 は**同じ層の仲間とだけ**。深さの違う鯉と向きを揃えても、
            // 絵の上では関わりのない 2 匹が並んで泳ぐだけになる
            if far < vision {
                let together = 1 - apart
                align += other.heading * together
                centre += other.head * together
                seen += together
            }

            // 4. 先読み — 相対速度が変わらないとして、最接近の時刻と隔たりを出す
            let drift = heading * speed - other.heading * other.speed
            let closing = simd_length_squared(drift)
            guard closing > 1e-3 else { continue }
            let when = simd_dot(gap, drift) / closing
            guard when > 0, when < Self.lookahead else { continue }
            let miss = gap - drift * when
            let missFar = simd_length(miss)
            let lane = (maximumHalfWidth + other.maximumHalfWidth) * 5.0
            guard missFar < lane else { continue }
            // 真正面から来たときは隔たりが 0 に潰れて避ける側が決まらない。
            // **どちらも自分の左へ逸れる**ことにしておくと、2 匹とも同じ答えを
            // 出しても擦れ違える
            let dodge = missFar > 1e-3 ? -miss / missFar : side
            // **時刻の重みは浅くしてある。** 差し迫ってからの強い力より、
            // 早くから掛かる弱い力のほうが効く — 首を振れる速さに上限がある
            // 体では、向きの差は力ではなく**掛かっている時間**で埋まる
            let closeness: Float = 1 - missFar / lane
            let soon: Float = 0.45 + 0.55 * (1 - when / Self.lookahead)
            let press = closeness * soon * solid
            steer += dodge * (press * 5.0)
            urgency = max(urgency, press)
            // 正面を塞がれているぶんだけ減速する
            room = min(room, 1 - press * 0.65)
        }

        if seen > 0 {
            // 2. 揃える。**弱くしてある** — 鯉は鰯ではないので隊列は作らない
            let mean = align / seen
            let straight = simd_length(mean)
            if straight > 1e-3 { steer += mean / straight * 0.42 }

            // 3. 寄る。**独りになったときだけ。** 仲間がすぐ横にいるうちから
            // 群れの真ん中へ引かせると、離れる力と綱引きになって**団子のまま
            // 固まる** — 池が狭いので、寄る力はほとんどの時間で害にしかならない
            if closest > length * 1.6 {
                let toCentre = centre / seen - head
                let far = simd_length(toCentre)
                if far > length * 2.0 { steer += toCentre / far * 0.24 }
            }
        }

        return (steer, room, urgency, alarm, flee)
    }

    /// 背骨のうち、その点にいちばん近いところ。**間合いを測るのに要る。**
    ///
    /// 3 節ごとに区切った線分へ落とすので、節と節の間を突かれても拾える
    func nearest(to place: SIMD2<Float>) -> (place: SIMD2<Float>, far: Float) {
        var best = pose[0]
        var least = simd_length_squared(place - pose[0])
        var index = 0
        let step = 3
        while index + 1 < Self.samples {
            let from = pose[index]
            let to = pose[min(index + step, Self.samples - 1)]
            let along = to - from
            let extent = simd_length_squared(along)
            var point = from
            if extent > 1e-6 {
                let t = min(max(simd_dot(place - from, along) / extent, 0), 1)
                point = from + along * t
            }
            let far = simd_length_squared(place - point)
            if far < least {
                least = far
                best = point
            }
            index += step
        }
        return (best, least.squareRoot())
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

    /// 深さを漂わせる。
    ///
    /// **鯉は上下にも動く。** 沈めば濁りに溶けて底へ落とす影が広がり、浮けば色が
    /// 戻って影が締まる — 真上から見ている絵でも、深さは濁りと影として出る。
    ///
    /// 落ち着き先を中心に、周期の噛み合わない 2 つの正弦でゆっくり漂う。**餌へ
    /// 向かうときは浮き、漂う (`hover`) ときは沈む。** 変化は毎秒 22 mm までに
    /// 抑えてあるので、層の入れ替わりは数秒かけて起きる
    private func sink(dt: Float, now: Float, reaching: Bool) {
        let sway =
            48 * sin(now * 0.041 + wanderSeed * 1.7) + 32 * sin(now * 0.017 + wanderSeed * 0.6)
        var wanted = depthHome + sway
        if reaching { wanted -= 55 }
        if !dashing, speed < length * 0.2 { wanted += 45 }
        wanted = min(max(wanted, 30), 240)
        let step = min(abs(wanted - depth), 22 * dt)
        depth += wanted > depth ? step : -step
    }

    /// 尾を打つ。**1 打ちで体長の 0.45 倍だけ進む**ので、速さから打つ回数が決まる。
    private func beat(dt: Float, now: Float, water: Water) {
        // **1 打ちで体長の 0.45 倍だけ進む。** 鯉は効率のよい泳ぎ手ではない
        let rate = max(0.42, speed / (0.45 * length))
        tailPhase += rate * dt
        beats += rate * dt
        // 速く泳いでいるときだけ水を蹴る。流しているときの尾は水を置いていかない
        if speed > length * 0.38, floor(beats) != lastBeat {
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
        // 止まっていてもわずかにくねる。速さで 1.0 まで開く
        let swing = min(0.45 + speed / (length * 1.4), 1.15)
        for index in 0..<Self.samples {
            let u = Float(index) / Float(Self.samples - 1)
            let tangent = tangentOfChain(at: index)
            let normal = SIMD2(-tangent.y, tangent.x)
            // **尾の振れ幅は体長の 5〜6%** (片振幅)。実物の巡航がその程度で、
            // 0.9% しか振っていなかったときは体が動いて見えなかった。
            // 頭にも小さく残すのは**反動**で、これがあると体が 1 本に繋がって見える
            // **u の 1.6 乗で増やす。** 2 乗にすると振れるのが後ろ 3 分の 1 だけに
            // なり、胴が板のまま尾だけが動いて見える
            let amplitude = length * (0.009 + 0.058 * pow(u, 1.6)) * swing
            let wave = sin(2 * Float.pi * (u * 0.95 - tailPhase))
            pose[index] = chain[index] + normal * (amplitude * wave)
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

    /// 背骨の途中の位置と、そこでの体の横向き。
    ///
    /// **輪郭は節より細かく刻む**ので (`outline`)、節と節のあいだを読める必要がある。
    /// 向きも隣の接線どうしを混ぜる — 位置だけ補間して向きを節のものにすると、
    /// 鼻先の数点が同じ向きを向いて丸みが平たく潰れる
    func rib(atFraction u: Float) -> (place: SIMD2<Float>, side: SIMD2<Float>) {
        let scaled = min(max(u, 0), 1) * Float(Self.samples - 1)
        let index = min(Int(scaled), Self.samples - 2)
        let t = scaled - Float(index)
        let place = pose[index] + (pose[index + 1] - pose[index]) * t
        let first = tangent(at: index)
        let second = tangent(at: index + 1)
        var forward = first + (second - first) * t
        let far = simd_length(forward)
        forward = far > 1e-5 ? forward / far : heading
        return (place, SIMD2(-forward.y, forward.x))
    }

    /// 体の輪郭の片側。**節ではなく `outline` の刻みで返す。**
    func flank(_ sign: Float) -> [SIMD2<Float>] {
        Self.outline.map { station in
            let rib = rib(atFraction: station.u)
            return rib.place + rib.side * (station.half * maximumHalfWidth * sign)
        }
    }

    /// 髭 2 対。**鯉と金魚を分けているのはここである。**
    ///
    /// 上顎の左右に、短い吻髭と長い上顎髭が 1 本ずつ生えている。真上からは口角から
    /// 後ろへ流れる細い線として見える。長さは目径 (体長の 2.6%) を基準に、吻髭が
    /// その 0.8 倍、上顎髭が 1.6 倍
    func whiskers(_ sign: Float) -> [(base: SIMD2<Float>, direction: SIMD2<Float>, reach: Float)] {
        let corner = rib(atFraction: 0.022)
        let base = corner.place + corner.side * (Self.halfWidth(at: 0.022) * maximumHalfWidth * sign)
        // **後ろへ流れる。** 泳いでいる鯉の髭は前へ突き出さず、頬に沿って寝ている
        let backward = SIMD2(-corner.side.y, corner.side.x)
        return [
            (base, Self.turn(backward, by: 0.62 * sign), length * 0.020),
            (base, Self.turn(backward, by: 0.24 * sign), length * 0.040),
        ]
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
        // **鰓蓋のすぐ後ろ。** 実際の鯉の鰓蓋の後端は頭から 4 分の 1 のあたりで、
        // 胸鰭はその真後ろに付く。体のいちばん太いところ (30%) まで下げると、
        // 腹から翼が生えているように見える
        let u: Float = 0.24
        let rib = rib(atFraction: u)
        let tangent = SIMD2(rib.side.y, -rib.side.x)
        let base = rib.place + rib.side * (Self.halfWidth(at: u) * maximumHalfWidth * sign * 0.85)
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
