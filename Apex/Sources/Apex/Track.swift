import Foundation
import simd

/// 閉じたコース — 中心線・向き・曲率・高低。
///
/// ## 1 単位 = 10 cm
///
/// コース幅 12 m (120)・1 周 1.2 km (12,000)・車の全長 4.3 m (43)。速さは単位/秒で持ち、
/// **× 0.36 で km/h になる** (500 単位/s = 180 km/h)。
///
/// ## 世界は y 上向き
///
/// mokume の縦軸は下向きだが、高さを深さとして持つと読めない。**ここは y 上向きで持ち、
/// 描く直前に符号を反転する** (Quarry・Cast と同じ約束)。
///
/// ## 向き (yaw) の規約
///
/// `heading = 0` で +z を向く。前は `(sin θ, cos θ)`、**横は `(cos θ, −sin θ)` で、
/// これは進行方向から見て右側**である。コース上の位置は「入口からの距離 `s`」と
/// 「中心線からの横ずれ `d`」の 2 つで表し、**`d > 0` が右**。
struct Track {
    /// 1 周の長さ (単位)。**制御点はこの長さになるよう縮尺を合わせられる。**
    static let lapLength: Float = 12_000
    /// 路面の片側の半幅 (単位)。
    static let halfWidth: Float = 60
    /// 壁までの半幅 (単位)。**路面の端から 9 m 外側。**
    static let wallWidth: Float = 150

    /// 弧長で等間隔に並べた 1 点。
    struct Sample {
        var point: SIMD2<Float>
        /// 進む向き (ラジアン)。**0 で +z。**
        var heading: Float
        /// 符号つき曲率 (1/単位)。**正が右カーブ。**
        var curvature: Float
        /// 広い窓で均した曲率。**ライン取りはこちらを見る。**
        var drift: Float
        /// 高さ (単位・y 上向き)。
        var height: Float
        /// 縦の勾配 dy/ds。
        var slope: Float
    }

    let samples: [Sample]
    /// サンプルの間隔 (単位)。**`length / count` で割り切ってある。**
    let ds: Float
    /// 実測した 1 周の長さ (単位)。
    let length: Float

    var count: Int { samples.count }

    // MARK: - 中心線の骨

    /// 制御点 (メートル)。z が北で、**原点がスタート / フィニッシュ線**。
    ///
    /// 主ストレート 150 m → 高速右 → 中速右 → バックストレート → **ヘアピン** →
    /// S 字 → 最終左。**速いコーナーと遅いコーナーを両方持たせる**のは、同じ 1 つの
    /// 式から出る限界速度の差 (54 km/h と 120 km/h) を走って確かめられるようにするため
    private static let control: [SIMD2<Float>] = [
        SIMD2(0, 0),  // スタート / フィニッシュ。**ここは直線の途中**である
        SIMD2(0, 80),
        SIMD2(0, 158),  // 主ストレート
        SIMD2(22, 222),
        SIMD2(84, 262),  // T1 高速右
        SIMD2(158, 268),
        SIMD2(220, 244),
        SIMD2(252, 192),  // T2 中速右
        SIMD2(248, 132),  // バックストレート
        SIMD2(256, 74),
        SIMD2(246, 32),  // T3 ヘアピン
        SIMD2(198, 22),
        SIMD2(154, 52),  // S 字 左
        SIMD2(104, 16),  // S 字 右
        SIMD2(58, -20),
        SIMD2(14, -30),  // 最終左 — **原点の南から入る**ので、スタートラインの
        // 前後が直線になる (グリッドを直線上に並べられる)
    ]

    // MARK: - 組み立てる

    /// コースを組む。
    ///
    /// **縮尺合わせに反復は要らない。** 向心 Catmull-Rom の節点は点の間隔の平方根で
    /// 刻まれ、Barry–Goldman の構成は節点の**比**しか使わない。だから制御点を k 倍すると
    /// 節点はすべて √k 倍になって比が変わらず、**曲線は厳密に k 倍の相似形・弧長も厳密に
    /// k 倍**になる。生の長さを 1 度測って割るだけで、狙いの 1 周に合う
    static func build() -> Track {
        let raw = Track.trace(Track.control)
        let rawLength = raw.last!.run
        let k = Track.lapLength / rawLength
        let dense = Track.trace(Track.control.map { $0 * k })
        return Track(dense: dense)
    }

    /// 密な点列から、弧長で等間隔なサンプルを起こす。
    private init(dense: [(point: SIMD2<Float>, run: Float)]) {
        let total = dense.last!.run
        // **2 m 刻みを目標に、割り切れる数へ丸める。** 刻みを 20 に固定すると最後の
        // 1 区間だけ長さが違い、周回の継ぎ目で曲率が跳ねる
        let count = max(Int((total / 20).rounded()), 16)
        let step = total / Float(count)

        var points: [SIMD2<Float>] = []
        points.reserveCapacity(count)
        // **両方が単調なので、進むだけの添字で追える** (二分探索は要らない)
        var cursor = 0
        for index in 0..<count {
            let goal = Float(index) * step
            while cursor + 1 < dense.count - 1, dense[cursor + 1].run < goal { cursor += 1 }
            let a = dense[cursor]
            let b = dense[cursor + 1]
            let span = max(b.run - a.run, 1e-5)
            let f = min(max((goal - a.run) / span, 0), 1)
            points.append(a.point + (b.point - a.point) * f)
        }

        // 向き。**前後のサンプルの差から取る** — 片側差分だと半サンプルぶん遅れる
        var headings = [Float](repeating: 0, count: count)
        for index in 0..<count {
            let ahead = points[(index + 1) % count]
            let behind = points[(index + count - 1) % count]
            let delta = ahead - behind
            headings[index] = atan2(delta.x, delta.y)
        }

        // 曲率。**生のままだと 2 m 刻みの角が跳ねる**ので 5 タップで均す
        var raw = [Float](repeating: 0, count: count)
        for index in 0..<count {
            let ahead = headings[(index + 1) % count]
            let behind = headings[(index + count - 1) % count]
            raw[index] = Track.wrap(ahead - behind) / (2 * step)
        }
        var curvature = [Float](repeating: 0, count: count)
        var drift = [Float](repeating: 0, count: count)
        for index in 0..<count {
            var near: Float = 0
            for tap in -2...2 { near += raw[(index + tap + count * 2) % count] }
            curvature[index] = near / 5
            // **ライン取りはずっと広い窓で見る。** ±60 m の移動平均にすると、
            // 平均の遅れからコーナーの手前で外へ膨らみ、出口で戻る線が勝手に出る
            var wide: Float = 0
            let span = 30
            for tap in -span...span { wide += raw[(index + tap + count * 2) % count] }
            drift[index] = wide / Float(span * 2 + 1)
        }

        var samples: [Sample] = []
        samples.reserveCapacity(count)
        for index in 0..<count {
            let s = Float(index) * step
            samples.append(
                Sample(
                    point: points[index], heading: headings[index],
                    curvature: curvature[index], drift: drift[index],
                    height: Track.height(at: s, of: total), slope: Track.slope(at: s, of: total)))
        }

        self.samples = samples
        self.ds = step
        self.length = total
    }

    // MARK: - 高低

    /// 高さ。**整数倍の周期だけを重ねる** — そうしないと 1 周して戻ったときに段差ができる。
    ///
    /// 振幅 9 m + 4.5 m、最大勾配 10 %。車には重力の斜面成分として効き、絵では地平線が
    /// 動いて丘の向こうから相手が出てくる
    static func height(at s: Float, of length: Float) -> Float {
        let turn = 2 * Float.pi * s / length
        return 90 * sin(turn) + 45 * sin(2 * turn + 1.1)
    }

    /// 勾配 dy/ds。**高さの式をそのまま微分したもの。**
    static func slope(at s: Float, of length: Float) -> Float {
        let turn = 2 * Float.pi * s / length
        let rate = 2 * Float.pi / length
        return 90 * rate * cos(turn) + 90 * rate * cos(2 * turn + 1.1)
    }

    // MARK: - 引く

    /// 距離 `s` のところのコース。**隣り合う 2 つのサンプルを補間する。**
    func frame(at s: Float) -> Sample {
        let wrapped = s.truncatingRemainder(dividingBy: length)
        let positive = wrapped < 0 ? wrapped + length : wrapped
        let exact = positive / ds
        let index = Int(exact) % count
        let f = exact - Float(Int(exact))
        let a = samples[index]
        let b = samples[(index + 1) % count]
        return Sample(
            point: a.point + (b.point - a.point) * f,
            // **向きは最短の弧で混ぜる。** 素朴に混ぜると ±π をまたぐところで 1 周する
            heading: a.heading + Track.wrap(b.heading - a.heading) * f,
            curvature: a.curvature + (b.curvature - a.curvature) * f,
            drift: a.drift + (b.drift - a.drift) * f,
            height: a.height + (b.height - a.height) * f,
            slope: a.slope + (b.slope - a.slope) * f)
    }

    /// 世界の点を、コースの上の (距離・横ずれ) へ写す。
    ///
    /// **前フレームの添字の近傍だけを見る。** 1 フレームに進むのは最大 8.7 単位で、
    /// サンプルの間隔 20 単位より短い — **1 サンプルも進まない**ので ±8 は過剰に安全である。
    /// 添字を返すので、呼ぶ側はそれを次のフレームの種にする
    func locate(_ p: SIMD2<Float>, near seed: Int) -> (s: Float, d: Float, index: Int) {
        var best = seed
        var bestDistance = Float.greatestFiniteMagnitude
        for tap in -8...8 {
            let index = (seed + tap + count * 2) % count
            let gap = simd_length_squared(p - samples[index].point)
            if gap < bestDistance {
                bestDistance = gap
                best = index
            }
        }
        return project(p, onto: best)
    }

    /// どこにいるか分からないときに、全部のサンプルを見て探す。
    ///
    /// **組み立て・やり直し・復帰のときだけ**呼ぶ (毎フレームは `locate(_:near:)`)
    func find(_ p: SIMD2<Float>) -> (s: Float, d: Float, index: Int) {
        var best = 0
        var bestDistance = Float.greatestFiniteMagnitude
        for index in 0..<count {
            let gap = simd_length_squared(p - samples[index].point)
            if gap < bestDistance {
                bestDistance = gap
                best = index
            }
        }
        return project(p, onto: best)
    }

    /// 最寄りのサンプルの前後 2 本の線分へ落とす。
    private func project(_ p: SIMD2<Float>, onto index: Int) -> (s: Float, d: Float, index: Int) {
        var answer = (s: Float(0), d: Float(0), index: index)
        var bestGap = Float.greatestFiniteMagnitude
        for side in [-1, 0] {
            let a = (index + side + count) % count
            let b = (a + 1) % count
            let from = samples[a].point
            let along = samples[b].point - from
            let span = max(simd_length_squared(along), 1e-5)
            let u = min(max(simd_dot(p - from, along) / span, 0), 1)
            let foot = from + along * u
            let gap = simd_length_squared(p - foot)
            guard gap < bestGap else { continue }
            bestGap = gap
            let heading = samples[a].heading + Track.wrap(samples[b].heading - samples[a].heading) * u
            answer = (
                s: (Float(a) + u) * ds, d: simd_dot(p - foot, Track.side(heading)), index: a
            )
        }
        return answer
    }

    /// コースの上の (距離・横ずれ) を世界の点へ戻す。
    func place(s: Float, d: Float) -> SIMD2<Float> {
        let frame = frame(at: s)
        return frame.point + Track.side(frame.heading) * d
    }

    // MARK: - 向きの道具

    /// 前 (単位ベクトル)。**θ = 0 で +z。**
    static func forward(_ heading: Float) -> SIMD2<Float> { SIMD2(sin(heading), cos(heading)) }

    /// 横 (単位ベクトル)。**進行方向から見て右。**
    static func side(_ heading: Float) -> SIMD2<Float> { SIMD2(cos(heading), -sin(heading)) }

    /// 角を −π…π へ畳む。
    static func wrap(_ radians: Float) -> Float { atan2(sin(radians), cos(radians)) }

    // MARK: - スプライン

    /// 制御点を密な点列へ開き、弦長の累積を添える。
    private static func trace(_ control: [SIMD2<Float>]) -> [(point: SIMD2<Float>, run: Float)] {
        let n = control.count
        // 1 区間を 64 に割る。**弧長を測るための密さ**で、これ自体は絵に出ない
        let slice = 64
        var trail: [(point: SIMD2<Float>, run: Float)] = []
        trail.reserveCapacity(n * slice + 1)
        var run: Float = 0
        var previous = control[0]
        trail.append((previous, 0))
        for index in 0..<n {
            let p0 = control[(index + n - 1) % n]
            let p1 = control[index]
            let p2 = control[(index + 1) % n]
            let p3 = control[(index + 2) % n]
            for step in 1...slice {
                let point = centripetal(p0, p1, p2, p3, Float(step) / Float(slice))
                run += simd_length(point - previous)
                trail.append((point, run))
                previous = point
            }
        }
        return trail
    }

    /// 向心 Catmull-Rom (α = 0.5) の 1 区間。
    ///
    /// **一様版 (α = 0) を採らない。** ヘアピンの前後で制御点の間隔が 58 m から 41 m へ
    /// 急に詰まるので、一様版だと接線が過大になって**路面が自分と交差する**。向心版は
    /// ループも尖りも出ないことが分かっている
    private static func centripetal(
        _ p0: SIMD2<Float>, _ p1: SIMD2<Float>, _ p2: SIMD2<Float>, _ p3: SIMD2<Float>,
        _ u: Float
    ) -> SIMD2<Float> {
        let t0: Float = 0
        let t1 = t0 + knot(p0, p1)
        let t2 = t1 + knot(p1, p2)
        let t3 = t2 + knot(p2, p3)
        let t = t1 + (t2 - t1) * u

        let a1 = (p0 * (t1 - t) + p1 * (t - t0)) / (t1 - t0)
        let a2 = (p1 * (t2 - t) + p2 * (t - t1)) / (t2 - t1)
        let a3 = (p2 * (t3 - t) + p3 * (t - t2)) / (t3 - t2)
        let b1 = (a1 * (t2 - t) + a2 * (t - t0)) / (t2 - t0)
        let b2 = (a2 * (t3 - t) + a3 * (t - t1)) / (t3 - t1)
        return (b1 * (t2 - t) + b2 * (t - t1)) / (t2 - t1)
    }

    /// 節点の刻み。**点の間隔の平方根 (α = 0.5)。**
    private static func knot(_ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Float {
        max(sqrt(simd_length(b - a)), 1e-4)
    }
}
