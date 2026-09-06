import Foundation
import simd

/// 光が通った跡の 1 区間。**線ではなく幅を持つ帯**である。
///
/// 描く側はこれを三角形へ開くだけでよいように、必要なものを全部持たせてある —
/// 幅の向き、半分の幅、そして**両端の色** (進むほど暗くなるので、入口と出口で違う)。
struct Band {
    /// 入口と出口の中心。
    var a: SIMD2<Float>
    var b: SIMD2<Float>
    /// 幅の向き (進む向きに垂直な単位ベクトル)。
    var across: SIMD2<Float>
    /// 半分の幅。**束の伸縮 (`spread`) を掛けたあとの値。**
    var halfWidth: Float
    /// 入口と出口の色。線形 Display P3、強度込み。
    var colorA: SIMD3<Float>
    var colorB: SIMD3<Float>
}

/// 場面と、そこを通る光の追跡。
///
/// **絵の都合で触るのはこちら側**で、屈折の式そのものは `Optics` が持つ。
struct Tracer {

    // MARK: - 打ち切り

    /// 面で分かれた光を何回まで追うか。
    ///
    /// **全反射に捕まった光は強度が減らない** (反射率が 1) ので、深さで止めないと
    /// 三角形の中を回り続ける。しかも捕まるのはいちばん見せたい入射角なので、
    /// そこで費用が最悪になる
    static let maxDepth = 6
    /// これより弱くなった光は追わない。
    static let minimumPower: Float = 0.02
    /// 硝子の中を通ってよい合計の長さ。**深さと別に持つ** — 全反射で往復する光は
    /// 深さを使い切る前にここへ当たる
    static let maxGlassPath: Float = 1520

    // MARK: - 媒質

    /// 空気の減衰の距離 (画素)。1000 画素で 68% が残る。
    static let airFalloff: Float = 2600
    /// 硝子の減衰の距離 (画素)。**空気より短い** — これが全反射に捕まった光を
    /// 最終的に消す仕組みでもある
    static let glassFalloff: Float = 1800
    /// 硝子の中だけ散乱を強める倍率。
    ///
    /// **これは見せるための嘘である。** 硝子の中の扇は 300 画素で数画素しか開かない
    /// ので、外と同じ濃さで描くと白い塊にしか見えない。物理ではなく、中で何が
    /// 起きているかを読ませるための倍率
    static let glassScattering: Float = 1.6

    /// 何にも当たらなかった光をどこまで伸ばすか (画素)。面の対角より長く取る。
    static let escapeDistance: Float = 2600

    /// 受け面に落ちた光の明るさ。
    ///
    /// **空中の帯と桁が違うのは、次元が違うからである。** 帯の明るさは束の断面に
    /// 対する濃さだが、面に落ちた光は**面の上の線密度**になる — 幅 60 画素で入った
    /// 束が 200 画素あまりに広がったところを、2.25 画素の刻みで拾うので、
    /// 1 刻みが受け取るのは全体の 1% ほどしかない。その比から逆に決めた数である
    static let screenGain: Float = 95

    // MARK: - 結果

    private(set) var bands: [Band] = []
    /// 受け面に落ちた色。**添字がそのまま面の上の位置。**
    private(set) var screen: [SIMD3<Float>] = []
    /// 全反射が起きた点。面が光って見える演出に使う。
    private(set) var hotspots: [SIMD2<Float>] = []
    /// 束が最初に硝子へ当たったときの入射角 (ラジアン)。
    ///
    /// **絵には出ないが、観測 (`expose`) へ差し出す。** 全反射の窓 (38.8 度〜45.9 度) の
    /// どこにいるかは絵だけでは読めないので、数で見えるようにしてある
    private(set) var firstIncidence: Float = 0

    private var stack: [Pending] = []

    private struct Pending {
        var origin: SIMD2<Float>
        var direction: SIMD2<Float>
        var power: Float
        var spread: Float
        var inside: Bool
        var depth: Int
        var glassPath: Float
        /// 直前に当たった辺。**同じ辺への当たり直しを止める 2 重の仕掛けの片方**で、
        /// もう片方は交差の距離の下限である。片方だけだと、頂点にちょうど当たった
        /// 光が漏れる
        var lastEdge: Int
    }

    /// 受け面を刻む数。
    static let screenBins = 480

    init() {
        bands.reserveCapacity(Spectrum.count * Self.maxDepth * 2)
        stack.reserveCapacity(Self.maxDepth * 2)
        screen = Array(repeating: .zero, count: Self.screenBins)
    }

    // MARK: - 追う

    /// 白色光の束を 1 回ぶん追う。
    ///
    /// - Parameters:
    ///   - prism: 硝子の頂点 (3 つ以上の凸多角形)。
    ///   - screenA / screenB: 受け面の両端。
    ///   - width: 束の幅 (画素)。**帯の幅そのもの。**
    ///   - gain: 白い芯の明るさ。全波長が重なったところがこの値になる
    mutating func run(
        spectrum: Spectrum, from source: SIMD2<Float>, toward aim: SIMD2<Float>,
        prism: [SIMD2<Float>], screenA: SIMD2<Float>, screenB: SIMD2<Float>,
        width: Float, gain: Float
    ) {
        bands.removeAll(keepingCapacity: true)
        hotspots.removeAll(keepingCapacity: true)
        firstIncidence = 0
        for k in 0..<screen.count { screen[k] = .zero }

        let heading = aim - source
        guard simd_length(heading) > 1e-3 else { return }
        let direction = simd_normalize(heading)

        // 外向きの法線を 1 度だけ作る。**中にいるかどうかで裏返す必要は無い** —
        // `Optics.interact` が進む向きから毎回決め直す
        var normals: [SIMD2<Float>] = []
        normals.reserveCapacity(prism.count)
        var centroid = SIMD2<Float>.zero
        for vertex in prism { centroid += vertex }
        centroid /= Float(prism.count)
        for i in 0..<prism.count {
            let edge = prism[(i + 1) % prism.count] - prism[i]
            var normal = simd_normalize(SIMD2(edge.y, -edge.x))
            if simd_dot(normal, prism[i] - centroid) < 0 { normal = -normal }
            normals.append(normal)
        }

        let halfWidth = width / 2
        let screenEdge = prism.count

        for sample in spectrum.samples {
            stack.removeAll(keepingCapacity: true)
            stack.append(
                Pending(
                    origin: source, direction: direction, power: 1, spread: 1,
                    inside: false, depth: 0, glassPath: 0, lastEdge: -1))

            while let ray = stack.popLast() {
                // いちばん近い当たりを探す
                var nearest = Float.greatestFiniteMagnitude
                var hitEdge = -1
                for i in 0..<prism.count where i != ray.lastEdge {
                    if let distance = Optics.intersect(
                        origin: ray.origin, direction: ray.direction,
                        a: prism[i], b: prism[(i + 1) % prism.count], minimumDistance: 1e-3),
                        distance < nearest
                    {
                        nearest = distance
                        hitEdge = i
                    }
                }
                if let distance = Optics.intersect(
                    origin: ray.origin, direction: ray.direction,
                    a: screenA, b: screenB, minimumDistance: 1e-3), distance < nearest
                {
                    nearest = distance
                    hitEdge = screenEdge
                }

                let travelled = hitEdge < 0 ? Self.escapeDistance : nearest
                let end = ray.origin + ray.direction * travelled

                // **区間のあいだに減る。** 硝子の中は減りが速く、散らす量は多い
                let falloff = ray.inside ? Self.glassFalloff : Self.airFalloff
                let scattering = ray.inside ? Self.glassScattering : 1
                let survived = exp(-travelled / falloff)
                let powerEnd = ray.power * survived

                // **広がったぶんだけ薄くなる。** 力は保たれるので、明るさは幅の逆比
                let brightness = gain * scattering / max(ray.spread, 1e-3)
                bands.append(
                    Band(
                        a: ray.origin, b: end,
                        across: SIMD2(-ray.direction.y, ray.direction.x),
                        halfWidth: halfWidth * ray.spread,
                        colorA: sample.color * (ray.power * brightness),
                        colorB: sample.color * (powerEnd * brightness)))

                // 何にも当たらなかった / 受け面に当たった — どちらもここで終わる
                if hitEdge < 0 { continue }
                if hitEdge == screenEdge {
                    deposit(
                        sample.color * (powerEnd * gain * Self.screenGain), at: end,
                        halfWidth: halfWidth * ray.spread, screenA: screenA, screenB: screenB)
                    continue
                }

                let glassPath = ray.glassPath + (ray.inside ? travelled : 0)
                if ray.depth + 1 > Self.maxDepth || glassPath > Self.maxGlassPath { continue }

                if ray.depth == 0 && !ray.inside {
                    firstIncidence = acos(min(abs(simd_dot(ray.direction, normals[hitEdge])), 1))
                }

                let index = sample.index
                let interaction = Optics.interact(
                    direction: ray.direction, normal: normals[hitEdge],
                    indexIn: ray.inside ? index : 1, indexOut: ray.inside ? 1 : index)

                if interaction.transmitted == nil && ray.inside {
                    hotspots.append(end)
                }

                let reflectedPower = powerEnd * interaction.reflectance
                if reflectedPower > Self.minimumPower {
                    stack.append(
                        Pending(
                            origin: end, direction: interaction.reflected, power: reflectedPower,
                            spread: ray.spread, inside: ray.inside, depth: ray.depth + 1,
                            glassPath: glassPath, lastEdge: hitEdge))
                }
                if let transmitted = interaction.transmitted {
                    let transmittedPower = powerEnd * (1 - interaction.reflectance)
                    if transmittedPower > Self.minimumPower {
                        stack.append(
                            Pending(
                                origin: end, direction: transmitted, power: transmittedPower,
                                spread: ray.spread * interaction.spreadRatio,
                                inside: !ray.inside, depth: ray.depth + 1,
                                glassPath: glassPath, lastEdge: hitEdge))
                    }
                }
            }
        }
    }

    /// 受け面へ色を溜める。
    ///
    /// **束は幅を持ったまま面へ落ちる。** 中心の 1 点へ入れると、広がって薄くなった
    /// はずの光が刻み 1 つぶんに凝縮されて、面の上だけ縞になる。断面の重みで
    /// 配り、合計で割り戻すので**広く落ちたぶんは薄くなる** (力は保たれる)
    private mutating func deposit(
        _ color: SIMD3<Float>, at point: SIMD2<Float>, halfWidth: Float,
        screenA: SIMD2<Float>, screenB: SIMD2<Float>
    ) {
        let span = screenB - screenA
        let length = simd_length_squared(span)
        guard length > 1e-6 else { return }
        let along = simd_dot(point - screenA, span) / length
        guard along >= 0, along <= 1 else { return }

        let last = Float(screen.count - 1)
        let center = along * last
        // 刻み 1 つぶんの長さで、束の半幅が何刻みに当たるかを測る
        let reach = max(halfWidth / (simd_length(span) / last), 0.5)

        let lowest = max(Int((center - reach).rounded(.down)), 0)
        let highest = min(Int((center + reach).rounded(.up)), screen.count - 1)
        guard lowest <= highest else { return }

        var total: Float = 0
        for k in lowest...highest {
            let u = (Float(k) - center) / reach
            total += pow(max(1 - u * u, 0), 1.5)
        }
        guard total > 1e-6 else { return }
        for k in lowest...highest {
            let u = (Float(k) - center) / reach
            screen[k] += color * (pow(max(1 - u * u, 0), 1.5) / total)
        }
    }
}
