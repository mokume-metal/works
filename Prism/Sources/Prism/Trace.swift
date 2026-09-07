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

/// 光が面を横切った跡。
///
/// **面の上での footprint そのもの**で、長さは束の幅を入射角の余弦で割ったものである
/// (斜めに当たれば足跡は伸びる)。波長ごとに 1 つできるので、出口の面では 8〜13 画素
/// ずれて並び、**面の上に小さな虹の筋**になる。
struct Spot {
    /// 面に当たった点。
    var point: SIMD2<Float>
    /// 面に沿う単位ベクトル。
    var along: SIMD2<Float>
    /// 面の上での足跡の半分の長さ。
    var halfLength: Float
    /// 線形 Display P3、強度込み。
    var color: SIMD3<Float>
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

    /// 空気の減衰の距離 (画素)。1000 画素で 49% が残る。
    ///
    /// **短く取ってあるのは、束を棒に見せないためである。** 2600 画素にすると、
    /// 光路が 250 画素しかない区間では端から端まで濃さが変わらず、平らな板が
    /// 置いてあるようにしか見えない。塵の濃い空気だと言っているのと同じこと
    static let airFalloff: Float = 1400
    /// 硝子の減衰の距離 (画素)。**空気より短い** — これが全反射に捕まった光を
    /// 最終的に消す仕組みでもある
    static let glassFalloff: Float = 1200
    /// 硝子の中だけ散乱を強める倍率。
    ///
    /// **これは見せるための嘘である。** 硝子の中の扇は 300 画素で数画素しか開かない
    /// ので、外と同じ濃さで描くと白い塊にしか見えない。物理ではなく、中で何が
    /// 起きているかを読ませるための倍率
    static let glassScattering: Float = 1.1

    /// 何にも当たらなかった光をどこまで伸ばすか (画素)。面の対角より長く取る。
    static let escapeDistance: Float = 2600

    /// 面に落ちた足跡の明るさ。
    ///
    /// **帯より濃い** — 面に貼り付いた光は横から見た散乱ではなく、面そのものが
    /// 照らされたものなので、同じ力でも明るく見える。
    ///
    /// **1.5 では出口の足跡が白く飛んだ。** 波長ごとに 8〜13 画素ずれて並ぶのが
    /// 見せ場なので、飽和させると筋が 1 つの白い塊になる
    static let spotGain: Float = 1.15

    /// 受け面に落ちた光の明るさ。
    ///
    /// **空中の帯と桁が違うのは、次元が違うからである。** 帯の明るさは束の断面に
    /// 対する濃さだが、面に落ちた光は**面の上の線密度**になる — 幅 26 画素で入った
    /// 束が 200 画素あまりに広がったところを、2.25 画素の刻みで拾うので、
    /// 1 刻みが受け取るのは全体の 1% ほどしかない。その比から逆に決めた数である。
    ///
    /// **減衰距離を詰めたぶんも入っている** — 受け面へ届く力が 0.71 倍になったので、
    /// 95 から上げてある
    static let screenGain: Float = 134

    // MARK: - 結果

    private(set) var bands: [Band] = []
    /// 受け面に落ちた色。**添字がそのまま面の上の位置。**
    private(set) var screen: [SIMD3<Float>] = []
    /// 光が面を横切った跡。**入口・出口・全反射をひとつも区別しない** — どれも
    /// 「面を光が横切った」ことで、明るさは運んでいた力がそのまま決める
    private(set) var spots: [Spot] = []
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
        /// **この区間の帯と足跡はもう置いてある。**
        ///
        /// 光源から硝子までは波長がまだ分かれていないので、160 本ぶんの同じ三角形を
        /// 積む意味が無い (`run` が 1 本の白い帯として先に置く)。追跡そのものは
        /// 波長ごとに要るので、辿りはするが描かない
        var merged: Bool = false
    }

    /// 受け面を刻む数。
    static let screenBins = 480

    init() {
        bands.reserveCapacity(Spectrum.count * Self.maxDepth * 2)
        spots.reserveCapacity(Spectrum.count * Self.maxDepth)
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
        spots.removeAll(keepingCapacity: true)
        firstIncidence = 0
        for k in 0..<screen.count { screen[k] = .zero }

        let heading = aim - source
        guard simd_length(heading) > 1e-3 else { return }
        let direction = simd_normalize(heading)

        // 外向きの法線を 1 度だけ作る。**中にいるかどうかで裏返す必要は無い** —
        // `Optics.interact` が進む向きから毎回決め直す
        var normals: [SIMD2<Float>] = []
        var alongs: [SIMD2<Float>] = []
        normals.reserveCapacity(prism.count)
        alongs.reserveCapacity(prism.count)
        var centroid = SIMD2<Float>.zero
        for vertex in prism { centroid += vertex }
        centroid /= Float(prism.count)
        for i in 0..<prism.count {
            let edge = prism[(i + 1) % prism.count] - prism[i]
            var normal = simd_normalize(SIMD2(edge.y, -edge.x))
            if simd_dot(normal, prism[i] - centroid) < 0 { normal = -normal }
            normals.append(normal)
            alongs.append(simd_normalize(edge))
        }

        let halfWidth = width / 2
        let screenEdge = prism.count

        // **光源から硝子までは、まだ 1 本の白い光である。**
        //
        // 波長ごとの色を全部足すと白になる (`Spectrum` が成分ごとに正規化してある) ので、
        // この区間だけは 1 本の帯として置ける — 同じ三角形を 160 回積むのをやめられるし、
        // **分かれるのは面に当たってからだ**という筋書きが絵とも一致する
        let entry = nearestHit(
            origin: source, direction: direction, prism: prism,
            screenA: screenA, screenB: screenB, skip: -1)
        let entryTravel = entry.edge < 0 ? Self.escapeDistance : entry.distance
        let entryEnd = source + direction * entryTravel
        let entrySurvived = exp(-entryTravel / Self.airFalloff)
        bands.append(
            Band(
                a: source, b: entryEnd,
                across: SIMD2(-direction.y, direction.x), halfWidth: halfWidth,
                colorA: SIMD3(repeating: gain),
                colorB: SIMD3(repeating: gain * entrySurvived)))

        if entry.edge == screenEdge {
            // 硝子を外して受け面へ届いた — 分かれていないので白い筋が落ちる
            deposit(
                SIMD3(repeating: gain * entrySurvived * Self.screenGain), at: entryEnd,
                halfWidth: halfWidth, screenA: screenA, screenB: screenB)
        }
        guard entry.edge >= 0, entry.edge < screenEdge else { return }

        let entrySlant = max(abs(simd_dot(direction, normals[entry.edge])), 0.16)
        spots.append(
            Spot(
                point: entryEnd, along: alongs[entry.edge],
                halfLength: halfWidth / entrySlant,
                color: SIMD3(repeating: gain * entrySurvived * Self.spotGain)))

        for sample in spectrum.samples {
            stack.removeAll(keepingCapacity: true)
            stack.append(
                Pending(
                    origin: source, direction: direction, power: 1, spread: 1,
                    inside: false, depth: 0, glassPath: 0, lastEdge: -1, merged: true))

            while let ray = stack.popLast() {
                let hit = nearestHit(
                    origin: ray.origin, direction: ray.direction, prism: prism,
                    screenA: screenA, screenB: screenB, skip: ray.lastEdge)
                let hitEdge = hit.edge
                let travelled = hitEdge < 0 ? Self.escapeDistance : hit.distance
                let end = ray.origin + ray.direction * travelled

                // **区間のあいだに減る。** 硝子の中は減りが速く、散らす量は多い
                let falloff = ray.inside ? Self.glassFalloff : Self.airFalloff
                let scattering = ray.inside ? Self.glassScattering : 1
                let survived = exp(-travelled / falloff)
                let powerEnd = ray.power * survived

                // **広がったぶんだけ薄くなる。** 力は保たれるので、明るさは幅の逆比
                let brightness = gain * scattering / max(ray.spread, 1e-3)
                if !ray.merged {
                    bands.append(
                        Band(
                            a: ray.origin, b: end,
                            across: SIMD2(-ray.direction.y, ray.direction.x),
                            halfWidth: halfWidth * ray.spread,
                            colorA: sample.color * (ray.power * brightness),
                            colorB: sample.color * (powerEnd * brightness)))
                }

                // 何にも当たらなかった / 受け面に当たった — どちらもここで終わる
                if hitEdge < 0 { continue }
                if hitEdge == screenEdge {
                    if !ray.merged {
                        deposit(
                            sample.color * (powerEnd * gain * Self.screenGain), at: end,
                            halfWidth: halfWidth * ray.spread, screenA: screenA, screenB: screenB)
                    }
                    continue
                }

                // **面での足跡。** 斜めに当たれば足跡は伸びるので、束の幅を入射角の
                // 余弦で割る。かすめる角では割り算が暴れるので下限で止める
                let slant = max(abs(simd_dot(ray.direction, normals[hitEdge])), 0.16)
                if !ray.merged {
                    spots.append(
                        Spot(
                            point: end, along: alongs[hitEdge],
                            halfLength: halfWidth * ray.spread / slant,
                            color: sample.color * (powerEnd * gain * Self.spotGain)))
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

    /// いちばん近い当たりを探す。
    ///
    /// 返す辺の番号は、多角形の辺なら 0 から、受け面なら `prism.count`、何にも
    /// 当たらなければ −1。**`skip` で直前に当たった辺を外す** — 交差の距離の下限と
    /// 合わせて 2 重に自己交差を止めている
    private func nearestHit(
        origin: SIMD2<Float>, direction: SIMD2<Float>, prism: [SIMD2<Float>],
        screenA: SIMD2<Float>, screenB: SIMD2<Float>, skip: Int
    ) -> (distance: Float, edge: Int) {
        var nearest = Float.greatestFiniteMagnitude
        var edge = -1
        for i in 0..<prism.count where i != skip {
            if let distance = Optics.intersect(
                origin: origin, direction: direction,
                a: prism[i], b: prism[(i + 1) % prism.count], minimumDistance: 1e-3),
                distance < nearest
            {
                nearest = distance
                edge = i
            }
        }
        if let distance = Optics.intersect(
            origin: origin, direction: direction, a: screenA, b: screenB,
            minimumDistance: 1e-3), distance < nearest
        {
            nearest = distance
            edge = prism.count
        }
        return (nearest, edge)
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
