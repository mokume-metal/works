import Foundation
import mokume
import simd

/// 水面の高さ場。
///
/// **絵にするのは高さではなく傾きである。** 真上から静かな水を見ても高さは見えない —
/// 見えるのは「傾いた面がどこを映し、どこを透かしているか」だけなので、この型が外へ
/// 渡すのは `h` ではなく `∇h` になる。屈折も焦線も鏡面反射も、全部そこから出る。
///
/// ## 尺度を決めておく
///
/// **1 画素 = 1 mm。** 画面 1920 画素は 1.92 m の池で、この作品の波長・速さ・水深は
/// 全部その尺度の実寸である。尺度を決めたので、波の速さを手で置かずに**重力‐表面張力波の
/// 分散関係**から出せる:
///
/// ```
/// c(λ) = √(g/k + (σ/ρ)·k)    k = 2π/λ
/// ```
///
/// 水の定数 (g = 9810 mm/s²、σ/ρ = 72800 mm³/s²) をそのまま入れると、位相速度は
/// **λ = 17.1 mm で最小の 231 mm/s** を取る。雨粒の輪が広がる速さがどれも同じくらいに
/// 見えるのはこの谷のせいで、置いた数ではなく式から出てくる。
///
/// ## 峰は包絡の後ろから湧いて、前で消える
///
/// 輪の広がる速さは**群速度**、峰の走る速さは**位相速度**で、深水波では後者が前者の
/// 1.7 倍ある。だから波束の中で峰が前へ追い越していき、先頭で消える。輪を 1 つ置いて
/// 見ていると分かる — これは足した細工ではなく、`c` と `c_g` を別々に使った帰結である。
///
/// ## 二重に持たない
///
/// 高さ場は**断片 (Metal) の中にしか無い。** CPU 側へ写せば「水面を読む」ことは
/// できるようになるが、式が 2 か所になって必ず片方が古くなる。真上から見ている限り
/// **浮いているものは波でほとんど動かない** (上下に揺れるだけで、それは真上からは
/// 見えない) ので、写す理由のほうが無い。CPU が持つのは**波源の一覧**だけで、
/// それを `Numbers` に詰めて断片へ渡す。
final class Water {

    // MARK: - 水の定数

    /// 重力加速度 (mm/s²)。
    static let gravity: Float = 9810
    /// 表面張力 ÷ 密度 (mm³/s²)。
    static let tension: Float = 72800

    /// その波長の位相速度 (mm/s)。**峰が走る速さ。**
    static func phaseSpeed(_ wavelength: Float) -> Float {
        let k = 2 * Float.pi / wavelength
        return (gravity / k + tension * k).squareRoot()
    }

    /// その波長の群速度 (mm/s)。**波束が広がる速さ。**
    ///
    /// `ω = k·c` を `k` で微分したもの。重力が効く長い波では `c/2` に、表面張力が
    /// 効く短い波では `3c/2` に寄る
    static func groupSpeed(_ wavelength: Float) -> Float {
        let k = 2 * Float.pi / wavelength
        let c = phaseSpeed(wavelength)
        return (gravity + 3 * tension * k * k) / (2 * k * c)
    }

    // MARK: - Numbers の並び

    // **断片へ渡す数の並びは、ここが正本である。** 位置は Metal の原稿へ文字列として
    // 差し込むので、片方だけ動かすことができない
    static let maxWinds = 6
    static let maxGusts = 2
    static let maxRings = 32
    static let maxKoi = 8

    /// 見出しの語数。輪と鯉と尺度の数のほかに、**風の斑の本数・凪のそよぎ・風向き**
    /// をここへ置く。
    static let headWords = 8
    static let gustSlot = headWords
    static let gustStride = 7
    static let windSlot = gustSlot + maxGusts * gustStride
    static let windStride = 6
    static let ringSlot = windSlot + maxWinds * windStride
    static let ringStride = 8
    static let koiSlot = ringSlot + maxRings * ringStride
    static let koiStride = 6
    static let slotCount = koiSlot + maxKoi * koiStride

    // MARK: - 風波

    /// 風が立てる波の、1 つの尺度。
    private struct Swell {
        /// 波長 (mm)。**速さはここから分散関係で決まる。**
        var wavelength: Float
        /// 位相速度 (mm/s)。
        var speed: Float
        /// 傾きの重み。**高さではなく傾きで置く** — 絵に効くのが傾きだから。
        var weight: Float
        /// 格子の種。尺度ごとに変える。
        var seed: Float
        /// 風向きからのずれ (rad)。**尺度ごとに散らす。**
        var spread: Float
    }

    /// 風波の尺度。
    ///
    /// ## 平面波の重ね合わせをやめた理由
    ///
    /// はじめは**向きと波長の違う進行波を 14 本重ねて**いた。式としては正しいのだが、
    /// 有限個の平面波の和は準周期なので、**焦線が斜めの格子として並び、池の底が
    /// 織物に見えた。** 位相をずらしても向きを散らしても、格子がずれるだけで消えない
    /// (実際の水面は波数が連続で、位相が場所ごとに無関係である)。
    ///
    /// いまは**尺度ごとの格子の揺らぎ**を重ねている。繰り返しが無く、しかも
    /// **尺度ごとに自分の波長が要求する速さで流れる** — 22 mm の細波は 232 mm/s、
    /// 330 mm のうねりは 719 mm/s で、長い波ほど速く走り抜ける。速さは置いた数では
    /// なく、どちらも下の `phaseSpeed` が返したものである。
    ///
    /// **峰は風に直交して伸びる。** 風向きの座標へ回してから、横方向だけ 0.45 倍に
    /// 潰してある
    private var swells: [Swell] = []

    /// 風向きの中心 (rad)。
    private let bearing: Float = -0.42

    /// いまの風向き。
    ///
    /// **向きは止まっていない。** 固定した向きに波を立て続けると、面がいつまでも
    /// 同じ斜めの畝を並べた布に見える。周期の噛み合わない 2 つの正弦を足して、
    /// 繰り返しの読めない ±0.35 rad の首振りにしてある (最も速い成分でも 1 周 200 秒
    /// なので、波の格子が横へ流れて見えるほどの速さにはならない)
    func heading(now: Float) -> SIMD2<Float> {
        let swing = 0.24 * sin(now * 0.031) + 0.11 * sin(now * 0.0117 + 1.9)
        return SIMD2(cos(bearing + swing), sin(bearing + swing))
    }

    /// 浮いているものが従う波長の下限 (mm)。
    ///
    /// **物は自分より短い波には乗らない。** 睡蓮の葉は 200 mm ほどあるので、
    /// 22 mm の細波はその下をすり抜けていく — 葉が寒天のように波打たないのは
    /// このためである
    static let floatFollows: Float = 60

    /// 凪のそよぎ。
    ///
    /// **0 にはしない。** 風の斑が渡っていないあいだの面は、鏡としては 0 が正しい
    /// のだが、絵としては止まって見える。ここを残しておくと、底の砂は歪みなく
    /// 見えたまま、面だけがかすかに生きている
    static let breeze: Float = 0.05

    // MARK: - 風の斑

    /// 水面を渡っていく風の一陣。
    ///
    /// **風は数ではなく斑である。** 凪いだ面に弱い風が当たると、当たったところだけが
    /// 細波で暗くざらつき、その斑が風下へ渡っていく (英語で cat's paw と呼ぶ)。面
    /// いっぱいに同じ強さの波を立ててしまうと、この「渡っていく」が消えて、どこを見ても
    /// 同じ織り目の布になる — 風が吹いていることは分かるが、**風が吹いた瞬間が無い。**
    ///
    /// **斑は風速そのもので渡る。** 猫の足跡が出るのは Beaufort 1 (0.3〜1.5 m/s) の
    /// 弱い風なので、渡る速さは 300〜520 mm/s になる。細波の峰はそれより速い (22 mm の
    /// 波で 232 mm/s、長い波はもっと速い) ので、**斑の中で生まれた波が前縁から抜けて
    /// いく** — 速さを置いたのではなく、分散関係と風速を別々に入れた帰結である
    private struct Gust {
        /// 生まれた場所。**画面の外の風上。**
        var origin: SIMD2<Float>
        var heading: SIMD2<Float>
        /// 渡る速さ (mm/s)。**風速そのもの。**
        var travel: Float
        var born: Float
        var life: Float
        /// 進行方向の半長 (mm)。
        var reach: Float
        /// 風に直交する向きの半幅 (mm)。**帯は横に長い。**
        var width: Float
        /// いちばん強いときの風。
        var peak: Float

        /// いまの中心。**寿命のあいだ、まっすぐ風下へ渡る。**
        func centre(now: Float) -> SIMD2<Float> {
            origin + heading * (travel * (now - born))
        }

        /// いまの頂点の強さ。**吹き寄せて、衰えて消える。**
        func crest(now: Float) -> Float {
            let phase = min(max((now - born) / life, 0), 1)
            return peak * pow(sin(.pi * phase), 0.55)
        }

        /// その場所へ届いている強さ。
        ///
        /// **前縁は狭く、後縁は長い。** 風が当たった面はすぐざらつくが、風が抜けた
        /// 後の細波は減衰に時間がかかるので、斑は後ろへ尾を引く (輪の包絡 `pond_ring`
        /// が前後で幅を変えているのと同じ理由である)。
        ///
        /// **同じ式が断片の `pond_wind` にもある。** 高さ場と違って、形を決めるのは
        /// この構造体の値だけで、それは CPU が正本のまま断片へ渡っている — 浮いて
        /// いるものは Swift のこれを、水面は断片のあれを読む
        func strength(at place: SIMD2<Float>, now: Float) -> Float {
            let side = SIMD2(-heading.y, heading.x)
            let rel = place - centre(now: now)
            let along = simd_dot(rel, heading)
            let across = simd_dot(rel, side)
            let span = along > 0 ? reach * 0.55 : reach * 1.6
            return crest(now: now)
                * exp(-0.5 * (along * along / (span * span) + across * across / (width * width)))
        }
    }

    /// いま生きている斑。**毎フレーム組み直す** (下記のとおり、持ち越す状態が無い)。
    private var gusts: [Gust] = []
    var gustCount: Int { gusts.count }

    /// 斑が生まれる間隔の目安 (秒)。**この中のどこかで 1 つ生まれる。**
    static let gustSpacing: Float = 35

    /// 風の時計の原点 (秒)。**R で押し戻す。**
    private var epoch: Float = 0

    /// 何番目かの斑。**時刻だけから決まる。**
    ///
    /// **賽を振って溜めない。** 「たまたま引いた乱数を状態として持ち越す」形にすると、
    /// いつ引くかがフレームの刻みで変わり、**同じ時刻からいつも同じ絵が出る**という
    /// この作品の前提 (砂利も睡蓮も種を持った `Scatter` が決めている) が風にだけ
    /// 通らなくなる。番号で種を作れば、風は時刻の関数のままでいられる
    private func gust(_ index: Int, over span: SIMD2<Float>) -> Gust? {
        guard index >= 0 else { return nil }
        var draw = Scatter(counting: index, salt: 3_150_927)
        // **間隔そのものが散る。** 番の中のどこで生まれるかを引くので、続けて 2 つ
        // 来ることも 1 分空くこともある — 次にいつ来るかが読めないのが風である
        let born = epoch + Float(index) * Self.gustSpacing + draw.next(0, Self.gustSpacing * 0.92)
        let course = heading(now: born)
        let angle = atan2(course.y, course.x) + draw.next(-0.5, 0.5)
        let forward = SIMD2(cos(angle), sin(angle))
        let side = SIMD2(-forward.y, forward.x)
        let reach = draw.next(380, 780)
        let travel = draw.next(300, 520)
        // **画面の外で生まれ、外で消える。** 池の対角の半分だけ風上へ下がったところを
        // 起点にして、渡り切るまでを寿命にする
        let far = simd_length(span) * 0.5 + reach + 240
        return Gust(
            origin: span * 0.5 - forward * far + side * draw.next(-far * 0.5, far * 0.5),
            heading: forward, travel: travel, born: born, life: 2 * far / travel,
            reach: reach, width: draw.next(480, 1050), peak: draw.next(0.50, 1.00))
    }

    /// いま渡っている斑を数え直す。**平均 35 秒に 1 度、1 つが池を横切る。**
    ///
    /// 寿命は長くても 15 秒ほどで間隔より短いので、**重なりうるのは隣り合う 2 番**
    /// だけである
    func breathe(now: Float, over span: SIMD2<Float>) {
        let turn = Int(((now - epoch) / Self.gustSpacing).rounded(.down))
        gusts = [turn - 1, turn].compactMap { gust($0, over: span) }
            .filter { now >= $0.born && now - $0.born <= $0.life }
    }

    /// その場所の風。**浮いているものが読む。**
    ///
    /// 水面の波は断片が持つが、花びらや葉を押すのは波ではなく空気そのものなので、
    /// こちらは CPU 側に要る。**向きは斑ごとに違う** — 強さで加重して混ぜる
    func airflow(at place: SIMD2<Float>, now: Float) -> (flow: SIMD2<Float>, strength: Float) {
        let course = heading(now: now)
        var strength = Self.breeze
        var flow = course * Self.breeze
        for gust in gusts {
            let gain = gust.strength(at: place, now: now)
            strength += gain
            flow += gust.heading * gain
        }
        let length = simd_length(flow)
        return (length > 1e-5 ? flow / length : course, strength)
    }

    /// 風を凪へ戻す。**時計の原点をいまへ動かす**ので、起動したときと同じ順で
    /// 風が来るようになる。
    func calm(now: Float) {
        epoch = now
        gusts.removeAll(keepingCapacity: true)
    }

    // MARK: - 輪

    /// 水面を叩いたものが出す輪。
    struct Ring {
        var center: SIMD2<Float>
        var birth: Float
        /// 高さの振幅 (mm)。
        var amplitude: Float
        /// 波長 (mm)。速さはここから分散関係で決まる。
        var wavelength: Float
        /// 減衰の時定数 (秒)。
        var life: Float
    }

    private(set) var rings: [Ring] = []

    /// 輪を置く。**満杯なら、いま一番弱いものと入れ替える。**
    ///
    /// 古い順に捨てると、鯉の尾が出す小さな輪が餌の輪を押し出してしまう。残す価値は
    /// 「いまの振幅」なので、`amplitude · exp(−age/life)` で比べる
    func ripple(at center: SIMD2<Float>, now: Float, amplitude: Float, wavelength: Float, life: Float) {
        let ring = Ring(
            center: center, birth: now, amplitude: amplitude, wavelength: wavelength, life: life)
        guard rings.count >= Self.maxRings else {
            rings.append(ring)
            return
        }
        var weakest = 0
        var weakestPower = Float.greatestFiniteMagnitude
        for (index, other) in rings.enumerated() {
            let power = other.amplitude * exp(-(now - other.birth) / other.life)
            if power < weakestPower {
                weakestPower = power
                weakest = index
            }
        }
        if weakestPower < amplitude { rings[weakest] = ring }
    }

    /// 弱りきった輪を落とす。**`2.6·life` で振幅は 7% を切る。**
    ///
    /// 3.4 倍まで抱えていたときは、鯉 6 匹の尾が出す輪だけで上限 32 本を埋め切り、
    /// **餌を落としても輪が置けなかった**
    func fade(now: Float) {
        rings.removeAll { now - $0.birth > $0.life * 2.6 }
    }

    func clearRings() { rings.removeAll(keepingCapacity: true) }

    // MARK: - 組み立て

    init() {
        // 22 mm から 330 mm まで。**下は表面張力が効く谷 (17 mm) のすぐ上**、
        // 上は画面の 6 分の 1 で、それより長い波は池に立たない
        let lengths: [Float] = [22, 38, 66, 112, 190, 330]
        // 中ほどの尺度をいちばん急にする。細かい側だけだと面が砂嵐になり、
        // 粗い側だけだとうねって池に見えない
        // **長い側を重くしてある。** はじめは中ほどを頂点にした山にしていたが、
        // それだと長い波の振幅が 3 mm ほどしかなく、浮いているものがほとんど
        // 動かなかった (水粒子が描く円の半径は波の振幅そのものである)
        let weights: [Float] = [0.62, 0.80, 0.95, 1.12, 1.18, 1.10]
        // **尺度ごとに向きをずらす。** 実際の風波は向きに広がりを持っていて、
        // 全部が風向きにきっちり揃っているのは、絵としては畝の並んだ布である
        let spreads: [Float] = [0.34, -0.21, 0.13, -0.37, 0.08, -0.16]
        for index in 0..<Self.maxWinds {
            swells.append(
                Swell(
                    wavelength: lengths[index],
                    speed: Self.phaseSpeed(lengths[index]),
                    weight: weights[index] * 0.30,
                    seed: Float(index) * 37.19 + 4.7,
                    spread: spreads[index]))
        }
    }

    // MARK: - 詰める

    /// 断片へ渡す数を組む。**毎フレーム全部書き直す** — 残った欄が前のフレームの
    /// 波源を指していると、消したはずの輪が出続ける。
    func pack(now: Float, koi: [Koi]) -> [Float] {
        var slots = [Float](repeating: 0, count: Self.slotCount)
        slots[0] = Float(min(rings.count, Self.maxRings))
        slots[1] = Float(min(koi.count, Self.maxKoi))
        slots[2] = Float(swells.count)

        // **浮いているものが従う波の下限。** 自分より短い波は、下をすり抜ける
        slots[3] = Float(swells.firstIndex { $0.wavelength >= Self.floatFollows } ?? 0)

        slots[4] = Float(min(gusts.count, Self.maxGusts))
        slots[5] = Self.breeze
        let course = heading(now: now)
        slots[6] = course.x
        slots[7] = course.y

        // 斑は**中心も強さの頂点も CPU 側で進めてある。** 断片が読むのは「いま
        // どこに、どれだけの強さで在るか」だけで、生まれた時刻を渡さない
        for (index, gust) in gusts.prefix(Self.maxGusts).enumerated() {
            let base = Self.gustSlot + index * Self.gustStride
            let centre = gust.centre(now: now)
            slots[base + 0] = centre.x
            slots[base + 1] = centre.y
            slots[base + 2] = gust.heading.x
            slots[base + 3] = gust.heading.y
            slots[base + 4] = gust.reach
            slots[base + 5] = gust.width
            slots[base + 6] = gust.crest(now: now)
        }

        // **風の強さはここでは掛けない。** 振幅は場所ごとに違うので、断片が
        // `pond_wind` を読んでから掛ける
        let bearing = atan2(course.y, course.x)
        for (index, swell) in swells.enumerated() {
            let base = Self.windSlot + index * Self.windStride
            slots[base + 0] = cos(bearing + swell.spread)
            slots[base + 1] = sin(bearing + swell.spread)
            slots[base + 2] = swell.wavelength
            slots[base + 3] = swell.weight
            slots[base + 4] = swell.speed
            slots[base + 5] = swell.seed
        }

        for (index, ring) in rings.prefix(Self.maxRings).enumerated() {
            let base = Self.ringSlot + index * Self.ringStride
            slots[base + 0] = ring.center.x
            slots[base + 1] = ring.center.y
            slots[base + 2] = ring.birth
            slots[base + 3] = ring.amplitude
            slots[base + 4] = 2 * Float.pi / ring.wavelength
            slots[base + 5] = Self.phaseSpeed(ring.wavelength)
            slots[base + 6] = Self.groupSpeed(ring.wavelength)
            slots[base + 7] = ring.life
        }

        for (index, fish) in koi.prefix(Self.maxKoi).enumerated() {
            let base = Self.koiSlot + index * Self.koiStride
            let head = fish.head
            slots[base + 0] = head.x
            slots[base + 1] = head.y
            slots[base + 2] = fish.heading.x
            slots[base + 3] = fish.heading.y
            slots[base + 4] = fish.length * 0.52
            // **速いほど盛り上がる。** 止まっている鯉の上の水は平らである
            slots[base + 5] = 0.34 + fish.speed * 0.016
        }
        return slots
    }

    // MARK: - 断片

    /// 高さ場を読む断片の共通部分。
    ///
    /// **勾配は解析微分で出す。** 有限差分にすると、隣り合う画素で傾きが階段になり、
    /// 鏡面反射がその折れを拾って面じゅうがギラつく (太陽の玉が点ではなく格子に映る)。
    /// ここに並ぶ項は全部 `sin` / `cos` / `exp` なので、微分は閉じた形で書ける
    static var field: String {
        """
        // 波源の並び。位置は Swift の `Water` が正本で、ここへ差し込まれている
        #define POND_GUST_SLOT   \(gustSlot)
        #define POND_GUST_STRIDE \(gustStride)
        #define POND_WIND_SLOT   \(windSlot)
        #define POND_WIND_STRIDE \(windStride)
        #define POND_RING_SLOT   \(ringSlot)
        #define POND_RING_STRIDE \(ringStride)
        #define POND_KOI_SLOT    \(koiSlot)
        #define POND_KOI_STRIDE  \(koiStride)

        /// 格子の値を混ぜる種。
        static inline float pond_hash(float2 at, float seed) {
            float3 q = fract(float3(at.x, at.y, at.x) * float3(0.1031, 0.1030, 0.0973) + seed);
            q += dot(q, q.yzx + 33.33);
            return fract((q.x + q.y) * q.z);
        }

        /// 格子の揺らぎを、**値と傾きの両方**で返す (x が値、yz が傾き)。
        ///
        /// **`mokume_noise` を使えないのはここである** — あちらは値しか返さないので、
        /// 傾きを取るには隣を引いて差を取ることになり、その差分が階段になって
        /// 鏡面反射がギラつく。混ぜ方 (3t² − 2t³) の微分は閉じた形で書ける
        static inline float3 pond_swell(float2 p, float seed) {
            float2 i = floor(p);
            float2 f = p - i;
            float2 u = f * f * (3.0 - 2.0 * f);
            float2 du = 6.0 * f * (1.0 - f);
            float a = pond_hash(i, seed);
            float b = pond_hash(i + float2(1.0, 0.0), seed);
            float c = pond_hash(i + float2(0.0, 1.0), seed);
            float d = pond_hash(i + float2(1.0, 1.0), seed);
            float k1 = b - a;
            float k2 = c - a;
            float k3 = a - b - c + d;
            return float3(
                a + k1 * u.x + k2 * u.y + k3 * u.x * u.y,
                du.x * (k1 + k3 * u.y),
                du.y * (k2 + k3 * u.x));
        }

        /// その場所の風の強さ。**風波の振幅はこれに比例する。**
        ///
        /// 凪のそよぎに、渡っていく斑を足したもの。斑の形の元は Swift の `Gust` で、
        /// 中心も強さの頂点も CPU 側で進めてあるので、ここは「いまどこに在るか」から
        /// 包絡を引くだけになる。**前縁は狭く、後縁は長い。**
        ///
        /// **向きは返さない。** 波の向きまで斑ごとに変えると、位相の掃引に使う長い
        /// ベクトル (速さ × 時間) が画素ごとに違う向きへ回り、格子が砕けて砂嵐になる。
        /// 風の向きが場所で違うことは、空気に押される浮いているもの (`airflow`) の
        /// 側で受け持つ — 波は吹いた先の面が生むもので、斑と一緒に向きを変えない
        static inline float pond_wind(device const float *n, float2 p, float t) {
            float2 course = float2(n[6], n[7]);
            float w = n[5];

            int gusts = int(n[4]);
            for (int i = 0; i < gusts; ++i) {
                int b = POND_GUST_SLOT + i * POND_GUST_STRIDE;
                float2 d = float2(n[b + 2], n[b + 3]);
                float2 side = float2(-d.y, d.x);
                float2 rel = p - float2(n[b], n[b + 1]);
                float along = dot(rel, d);
                float across = dot(rel, side);
                float la = (along > 0.0) ? n[b + 4] * 0.55 : n[b + 4] * 1.6;
                float lb = n[b + 5];
                w += n[b + 6]
                    * exp(-0.5 * (along * along / (la * la) + across * across / (lb * lb)));
            }

            // **斑の中はむらである。** 一様に強い帯は縁が定規で引いたように見える
            // ので、ゆっくり流れる長い格子 (620 mm) で削る。凪のそよぎにも掛かるから、
            // 鏡のような面にも「わずかにざらついたところ」が漂う
            float3 mottle = pond_swell((p - course * (46.0 * t)) / 620.0, 91.3);
            return w * (0.52 + 0.96 * mottle.x);
        }

        /// 輪 1 本の傾き。
        ///
        /// 包絡は群速度 `cg` で広がり、峰は位相速度 `cp` で走る。**その差が
        /// 「峰が波束の後ろから湧いて前で消える」動き**になる。
        ///
        /// 前後で包絡の幅を変えてある — 実際の輪は先頭が立っていて、後ろへ長く
        /// 尾を引く。幅は波長に比例させるので、長い波の輪ほど幅の広い束になる
        static inline float2 pond_ring(float2 p, float2 centre, float age,
                                       float amp, float k, float cp, float cg, float life) {
            float2 rel = p - centre;
            float r = max(length(rel), 1.0);
            float lambda = 6.2831853 / k;
            float front = lambda * 1.15;
            float back = lambda * 3.10;
            float d = r - cg * age;
            float w = (d > 0.0) ? front : back;

            // 円く広がるぶん、同じ力が長い周に薄まる。**1/√r** が面の上の輪の減り方
            float spread = rsqrt(1.0 + r / 240.0);
            float packet = exp(-0.5 * d * d / (w * w));
            float A = amp * exp(-age / life) * spread * packet;
            // 振幅の r 微分。薄まるぶんと、包絡から外れるぶんの 2 つ
            float dA = A * (-0.5 / (240.0 * (1.0 + r / 240.0)) - d / (w * w));

            float phase = k * r - k * cp * age;
            float dh = dA * cos(phase) - A * k * sin(phase);
            return rel * (dh / r);
        }

        /// 鯉 1 匹が真上へ押し上げる水。
        ///
        /// 体の形に沿って細長いふくらみを置く。**輪と違って走らない** — 鯉と一緒に
        /// 動くだけなので、位相を持たない
        static inline float2 pond_bulge(float2 p, float2 centre, float2 dir,
                                        float reach, float amp) {
            float2 side = float2(-dir.y, dir.x);
            float2 rel = p - centre;
            float a = dot(rel, dir);
            float b = dot(rel, side);
            float la = reach;
            float lb = reach * 0.38;
            float e = amp * exp(-0.5 * (a * a / (la * la) + b * b / (lb * lb)));
            return dir * (-a / (la * la) * e) + side * (-b / (lb * lb) * e);
        }

        /// 浮いているものが乗る動き。**xy が傾き、zw が横へ流される量** (mm)。
        ///
        /// ## 横の動きは高さの 90 度ずれである
        ///
        /// 深水波の水粒子は円を描く。高さが `a·cos(kx − ωt)` なら横の変位は
        /// `a·sin(kx − ωt)` で、**傾き `∂h/∂x = −a·k·sin` を `−1/k` 倍すると
        /// ちょうどそれになる。** だから傾きさえ持っていれば、横の動きは別に
        /// 数えなくてよい (Gerstner 波が使うのと同じ関係である)。
        ///
        /// **短い波は外す。** 浮いているものは自分より短い波には乗らないので、
        /// 下限より短い尺度は飛ばす (下限は Swift の `Water.floatFollows`)
        static inline float4 pond_ride(Fragment in, float2 p, float t) {
            device const float *n = in.numbers;
            float2 slope = float2(0.0);
            float2 slide = float2(0.0);

            float air = pond_wind(n, p, t);
            int winds = int(n[2]);
            for (int i = int(n[3]); i < winds; ++i) {
                int b = POND_WIND_SLOT + i * POND_WIND_STRIDE;
                float gain = n[b + 3] * air;
                if (gain < 1e-5) { continue; }
                float2 d = float2(n[b], n[b + 1]);
                float2 side = float2(-d.y, d.x);
                float lambda = n[b + 2];
                float2 r = float2(dot(p, d), dot(p, side) * 0.62) / lambda;
                r.x -= n[b + 4] * t / lambda;
                float3 s = pond_swell(r, n[b + 5]);
                float2 g = (d * s.y + side * (s.z * 0.62)) * (gain * 0.62);
                slope += g;
                slide -= g * (lambda / 6.2831853);
            }

            // 輪も乗せる。**餌の粒が自分の立てた輪に揺られる**のがこれである。
            // 葉は輪より大きいので均してしまうぶん、寄与を 0.7 倍にしてある
            int count = int(n[0]);
            for (int i = 0; i < count; ++i) {
                int b = POND_RING_SLOT + i * POND_RING_STRIDE;
                float2 centre = float2(n[b], n[b + 1]);
                float age = t - n[b + 2];
                if (age < 0.0) { continue; }
                float k = n[b + 4];
                float cg = n[b + 6];
                float lambda = 6.2831853 / k;
                float outer = cg * age + lambda * 3.7;
                float inner = max(cg * age - lambda * 9.9, 0.0);
                float2 rel = p - centre;
                float rr = dot(rel, rel);
                if (rr > outer * outer || rr < inner * inner) { continue; }
                float2 g = pond_ring(p, centre, age, n[b + 3], k, n[b + 5], cg, n[b + 7]) * 0.7;
                slope += g;
                slide -= g / k;
            }
            return float4(slope, slide);
        }

        /// その場所の水面の傾き。**この関数の戻り値だけが絵に効く。**
        static inline float2 pond_slope(Fragment in, float2 p, float t) {
            device const float *n = in.numbers;
            float2 g = float2(0.0);

            // **振幅はその場所の風で決まる。** 斑の中だけが荒れる
            float air = pond_wind(n, p, t);
            int winds = int(n[2]);
            for (int i = 0; i < winds; ++i) {
                int b = POND_WIND_SLOT + i * POND_WIND_STRIDE;
                float gain = n[b + 3] * air;
                if (gain < 1e-5) { continue; }
                float2 d = float2(n[b], n[b + 1]);
                float2 side = float2(-d.y, d.x);
                float lambda = n[b + 2];
                // 風向きへ回し、峰を風に直交して伸ばす
                float2 r = float2(dot(p, d), dot(p, side) * 0.62) / lambda;
                // **その尺度の波長が要求する速さで流れる。** 長い波ほど速い。
                // 掃引を軸に沿ったスカラーとして引くのは、**風向きが時間で振れても
                // 格子が横へ飛ばないため** — `p - d·(速さ·t)` の形だと、向きが少し
                // 回っただけで長いベクトルの先が大きく振られる
                r.x -= n[b + 4] * t / lambda;
                float3 s = pond_swell(r, n[b + 5]);
                g += (d * s.y + side * (s.z * 0.62)) * (gain * 0.62);
            }

            int count = int(n[0]);
            for (int i = 0; i < count; ++i) {
                int b = POND_RING_SLOT + i * POND_RING_STRIDE;
                float2 centre = float2(n[b], n[b + 1]);
                float age = t - n[b + 2];
                if (age < 0.0) { continue; }
                float k = n[b + 4];
                float cg = n[b + 6];
                float lambda = 6.2831853 / k;
                // **包絡の外は、平方根を取る前に捨てる。** 32 本のうち届くのは
                // どの画素でも 1〜3 本なので、ここで落ちるかどうかが速さを決める
                float outer = cg * age + lambda * 3.7;
                float inner = max(cg * age - lambda * 9.9, 0.0);
                float2 rel = p - centre;
                float rr = dot(rel, rel);
                if (rr > outer * outer || rr < inner * inner) { continue; }
                g += pond_ring(p, centre, age, n[b + 3], k, n[b + 5], cg, n[b + 7]);
            }

            int fish = int(n[1]);
            for (int i = 0; i < fish; ++i) {
                int b = POND_KOI_SLOT + i * POND_KOI_STRIDE;
                float2 centre = float2(n[b], n[b + 1]);
                float reach = n[b + 4];
                float2 rel = p - centre;
                if (dot(rel, rel) > reach * reach * 9.0) { continue; }
                g += pond_bulge(p, centre, float2(n[b + 2], n[b + 3]), reach, n[b + 5]);
            }
            return g;
        }
        """
    }
}
