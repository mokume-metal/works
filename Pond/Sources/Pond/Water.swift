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
    static let maxRings = 32
    static let maxKoi = 8

    static let windSlot = 4
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

    /// 風の向き。
    private let heading = SIMD2<Float>(cos(-0.42), sin(-0.42))

    /// 風の強さ (0…1)。スクロールで動く。**0 なら面は完全な鏡になる。**
    var wind: Float = 0.55

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
        let weights: [Float] = [0.62, 0.86, 1.00, 0.96, 0.78, 0.55]
        for index in 0..<Self.maxWinds {
            swells.append(
                Swell(
                    wavelength: lengths[index],
                    speed: Self.phaseSpeed(lengths[index]),
                    weight: weights[index] * 0.30,
                    seed: Float(index) * 37.19 + 4.7))
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

        for (index, swell) in swells.enumerated() {
            let base = Self.windSlot + index * Self.windStride
            slots[base + 0] = heading.x
            slots[base + 1] = heading.y
            slots[base + 2] = swell.wavelength
            slots[base + 3] = swell.weight * wind
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

        /// その場所の水面の傾き。**この関数の戻り値だけが絵に効く。**
        static inline float2 pond_slope(Fragment in, float2 p, float t) {
            device const float *n = in.numbers;
            float2 g = float2(0.0);

            int winds = int(n[2]);
            for (int i = 0; i < winds; ++i) {
                int b = POND_WIND_SLOT + i * POND_WIND_STRIDE;
                float2 d = float2(n[b], n[b + 1]);
                float2 side = float2(-d.y, d.x);
                float lambda = n[b + 2];
                float gain = n[b + 3];
                if (gain < 1e-5) { continue; }
                // **その尺度の波長が要求する速さで流れる。** 長い波ほど速い
                float2 q = p - d * (n[b + 4] * t);
                // 風向きへ回し、峰を風に直交して伸ばす
                float2 r = float2(dot(q, d), dot(q, side) * 0.62) / lambda;
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
