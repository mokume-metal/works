import Foundation
import mokume
import simd

/// 決まった並びを作る乱数。
///
/// **スケッチの `random()` を使わない。** 石と水草の配置はフレームごとに引き直す
/// ものではなく、はじめに 1 度決めて動かないものなので、引く順に依らない置き場が要る
struct Scatter {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 6_364_136_223_846_793_005 &+ 1 }
    mutating func next() -> Float {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Float(state >> 40) / Float(1 << 24)
    }
    mutating func next(_ low: Float, _ high: Float) -> Float { low + next() * (high - low) }

    /// 番号から引く並び。
    ///
    /// **連番をそのまま種にしない。** 線形合同法は隣り合う種からよく似た並びを返すので、
    /// 「i 番目のもの」を素直に `Scatter(seed: base + i)` で作ると、引いた値が番号と
    /// ともに一定の歩幅で動く — 風の斑でこれをやったときは、**間隔が 37 秒でほとんど
    /// 揃った。** 番号を撹拌してから渡すと並びが独立する (splitmix64 の混ぜ方)
    init(counting index: Int, salt: UInt64) {
        var mixed = UInt64(bitPattern: Int64(index)) &+ salt &+ 0x9E37_79B9_7F4A_7C15
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
        self.init(seed: mixed ^ (mixed >> 31))
    }
}

/// 池の底。
///
/// **半分の解像度で焼く。** 底は水越しに見るもので、屈折でずれ、濁りで沈むので、
/// 画素を面いっぱい持つ意味がない。水面の断片は線形補間で読むので、**足りない解像度が
/// そのまま暈けになる** — 深いものがぼやけて見えるのは、都合ではなく本当にそうである。
///
/// ここに描くのは砂・石・水草と、**鯉の影**である。影が底にあるおかげで、鯉が
/// 「水の中を泳いでいる」のか「水面に貼ってある」のかが一目で分かる。
final class Bed {

    let canvas: Canvas
    /// 場面の寸法 (mm)。面の画素数ではなくこちらで座標を持つ。
    private let span: SIMD2<Float>
    /// 面の画素 ÷ 場面の mm。
    private let shrink: Float

    private var mud: Shader?

    private struct Pebble {
        var place: SIMD2<Float>
        var radius: Float
        var squash: Float
        var angle: Float
        var tone: Float
    }
    private var pebbles: [Pebble] = []

    private struct Weed {
        var root: SIMD2<Float>
        var length: Float
        var lean: Float
        var sway: Float
        var phase: Float
        var tone: Float
    }
    private var weeds: [Weed] = []

    init(canvas: Canvas, span: SIMD2<Float>) {
        self.canvas = canvas
        self.span = span
        self.shrink = canvas.width / span.x
        canvas.noiseSeed(4021)
        canvas.noiseDetail(4, 0.52)
        mud = try? canvas.makeShader(
            Self.sand, name: "bed",
            values: [
                "span": .pair(span.x, span.y),
                "flow": .pair(0.86, 0.51),
                "dark": .color(.display(red: 0.13, green: 0.13, blue: 0.11)),
                "pale": .color(.display(red: 0.60, green: 0.53, blue: 0.39)),
            ])

        var scatter = Scatter(seed: 20_260_912)
        for _ in 0..<240 {
            pebbles.append(
                Pebble(
                    place: SIMD2(scatter.next(-40, span.x + 40), scatter.next(-40, span.y + 40)),
                    radius: pow(scatter.next(), 2.0) * 30 + 6,
                    squash: scatter.next(0.62, 1.0),
                    angle: scatter.next(0, Float.pi),
                    tone: scatter.next(0.55, 1.35)))
        }
        // 水草は縁に寄せる。**真ん中を空けておく** — 鯉が泳ぐ場所が見えなくなる
        for clump in 0..<9 {
            let edge = Float(clump) / 9
            let root = SIMD2(
                scatter.next(0, span.x),
                edge < 0.5
                    ? scatter.next(-30, span.y * 0.17) : scatter.next(span.y * 0.84, span.y + 30))
            for _ in 0..<9 {
                weeds.append(
                    Weed(
                        root: root + SIMD2(scatter.next(-46, 46), scatter.next(-26, 26)),
                        length: scatter.next(110, 260),
                        lean: scatter.next(-1.1, 1.1),
                        sway: scatter.next(0.10, 0.26),
                        phase: scatter.next(0, 6.28),
                        tone: scatter.next(0.6, 1.25)))
            }
        }
    }

    /// 底を描き直す。**影を落とすのは呼ぶ側**で、その前にここが土台を敷く。
    func draw(time: Float) {
        canvas.beginDraw()
        canvas.push()
        canvas.scale(shrink, shrink)
        canvas.noStroke()

        if let mud {
            canvas.shader(mud)
            canvas.fill(255, 255, 255)
            canvas.rect(0, 0, span.x, span.y)
            canvas.resetShader()
        } else {
            canvas.background(.display(red: 0.20, green: 0.19, blue: 0.13))
        }

        for stone in pebbles {
            // 石は上から見た丸。**光の側に明るい縁、反対に影**を置くだけで丸く見える
            canvas.push()
            canvas.translate(stone.place.x, stone.place.y)
            canvas.rotate(stone.angle)
            // 影は太陽の反対側へ小さく。**大きく暈かすと泡に見える**
            canvas.fill(.display(red: 0.05, green: 0.06, blue: 0.05, alpha: 0.62))
            canvas.ellipse(
                stone.radius * 0.30, stone.radius * 0.34, stone.radius * 2.0,
                stone.radius * 2.0 * stone.squash)
            canvas.fill(
                .display(
                    red: 0.40 * stone.tone, green: 0.37 * stone.tone, blue: 0.31 * stone.tone))
            canvas.ellipse(0, 0, stone.radius * 2, stone.radius * 2 * stone.squash)
            canvas.fill(
                .display(
                    red: 0.56 * stone.tone, green: 0.52 * stone.tone, blue: 0.44 * stone.tone))
            canvas.ellipse(
                -stone.radius * 0.20, -stone.radius * 0.22, stone.radius * 1.34,
                stone.radius * 1.34 * stone.squash)
            canvas.pop()
        }

        for leaf in weeds { ribbon(leaf, time: time) }
        // **ここで閉じない。** 場面の座標のまま呼ぶ側へ返し、鯉の影を落としてもらう
    }

    /// 影まで落とし終わったら閉じる。
    func finish() {
        canvas.pop()
        canvas.endDraw()
    }

    /// 水草の葉 1 枚。根から先へ細る帯で、**先ほど大きく揺れる**。
    private func ribbon(_ leaf: Weed, time: Float) {
        let steps = 9
        canvas.beginShape(.triangleStrip)
        for step in 0...steps {
            let t = Float(step) / Float(steps)
            let bend = leaf.lean * t * t + sin(time * 0.55 + leaf.phase + t * 2.2) * leaf.sway * t * t
            let along = leaf.length * t
            let place = leaf.root + SIMD2(sin(bend) * along, -cos(bend) * along * 0.55 + along * 0.18)
            let half = (1 - t) * 9 + 1.5
            let side = SIMD2(cos(bend), sin(bend)) * half
            let shade = 0.35 + 0.65 * t
            canvas.fill(
                .display(
                    red: 0.05 * leaf.tone * shade, green: 0.20 * leaf.tone * shade,
                    blue: 0.10 * leaf.tone * shade, alpha: 0.88))
            canvas.vertex(place.x - side.x, place.y - side.y)
            canvas.vertex(place.x + side.x, place.y + side.y)
        }
        canvas.endShape()
    }

    /// 砂を塗る断片。
    ///
    /// **漣痕 (ripple marks) を入れてある。** 水が一方向へ行き来した底には、その向きに
    /// 直交する縞が残る。縞の位相を大きな揺らぎでずらすと、定規で引いた縞ではなく
    /// 砂が寄った跡になる
    private static let sand = """
        float4 paint(Fragment in, Values values) {
            float2 p = in.place * values.span;

            float grain = mokume_noise(in, float3(p * 0.052, 3.0));
            float dust = mokume_noise(in, float3(p * 0.31, 11.0));
            float drift = mokume_noise(in, float3(p * 0.0055, 1.0));
            float ridge = sin(dot(p, values.flow) * 0.088 + drift * 9.0);

            // **漣痕は控えめに混ぜる。** 縞を強く出すと底が芝生に見える — 実際の
            // 砂の跡は数 mm しか高低差が無く、絵では粒の濃淡のほうが目立つ
            float sand = grain * 0.66 + dust * 0.27 + (0.5 + 0.5 * ridge) * 0.07;
            float3 mud = mix(values.dark.rgb, values.pale.rgb, sand);
            // 底の起伏。**深いところが暗い**のは、そこを通る水が厚いからである
            float bowl = mokume_noise(in, float3(p * 0.0013, 7.0));
            mud *= 0.68 + 0.56 * bowl;
            return float4(mud, 1.0);
        }
        """
}
