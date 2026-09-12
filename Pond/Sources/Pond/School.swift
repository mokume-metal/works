import Foundation
import mokume
import simd

/// 鯉の群れと、鯉を描く面。
///
/// **体は断片で塗る。** 輪郭の頂点に体の座標 (u = 鼻から尾、v = 左から右) を持たせて
/// あるので、断片は体の上の位置だけを見て模様を決められる — 泳いで曲がれば斑も一緒に
/// 歪み、画面に貼り付かない。立体でこれをやったのが Grain の `shapePosition` で、
/// **2D で同じことをするのが `vertex(x, y, u, v)`** である。
///
/// 影は別の面 (池の底) へ、光の向きへずらして落とす。同じ輪郭を 2 度描いているので、
/// 泳ぎの形と影の形は必ず一致する。
final class School {

    /// 鯉の面。**背景は透明**で、水面の断片がここを合成する。
    let canvas: Canvas
    private var paint: Shader?
    /// **1 画素の白い絵。** 体の座標を頂点に持たせるためだけに束ねる。
    ///
    /// `vertex(x, y, u, v)` が書いた位置は**貼る絵を束ねていないと捨てられる**
    /// (`Canvas.textureUV` が `currentPicture` を見て nil を返す)。読む先の画素数で
    /// 割る決まりなので、1×1 を束ねておけば書いた 0…1 がそのまま断片の `in.uv` へ届く。
    /// **この絵自体は一度も読まない** — 断片は `in.texel` を見ない
    private var unit: Image?
    private(set) var koi: [Koi] = []

    /// 濁って見える色。深いほどここへ寄る。
    var deep: LinearRGBA = .display(red: 0.10, green: 0.20, blue: 0.17)
    /// 太陽の向き (画面の x, y と、上向きの z)。
    var sun = SIMD3<Float>(-0.42, -0.62, 0.66)
    /// 影が横へずれる量 ÷ 深さ。**太陽の高さで決まる** (tan の余角)。
    var shadowSlide: Float = 0.62

    init(canvas: Canvas, bounds: SIMD2<Float>) {
        self.canvas = canvas
        canvas.noiseSeed(9137)
        canvas.noiseDetail(3, 0.55)
        unit = try? canvas.createImage(1, 1)
        unit?.fill(.display(red: 1, green: 1, blue: 1))
        paint = try? canvas.makeShader(Self.body, name: "koi", values: Self.startingValues)

        // 6 匹。**品種は全部違う** — 同じ斑が 2 つ出ると群れが繰り返しに見える
        let places: [(Float, Float, Float, Float, Float)] = [
            (0.24, 0.30, 0.4, 344, 52),
            (0.68, 0.22, 2.6, 300, 96),
            (0.80, 0.62, 3.6, 368, 34),
            (0.34, 0.74, 5.4, 268, 118),
            (0.56, 0.48, 1.4, 232, 140),
            (0.12, 0.56, 0.9, 312, 74),
        ]
        for (index, variety) in Variety.allCases.enumerated() {
            let (x, y, angle, length, depth) = places[index]
            koi.append(
                Koi(
                    variety: variety,
                    at: SIMD2(bounds.x * x, bounds.y * y),
                    heading: angle, length: length, depth: depth,
                    seed: SIMD2(Float(index) * 13.7, Float(index) * 5.3 + 2.1),
                    phase: Float(index) * 0.37))
        }
    }

    /// 群れのいちばん狭い間合い (mm)。**負なら体が重なって見えている。**
    ///
    /// 背骨同士のいちばん近いところから、互いの半幅を引いたもの。深さの違いは
    /// 見ていないので、**上を通り抜けた組も詰まったものとして数える** — 真上から
    /// 見て重なった画素がどれだけ出たか、の目安である
    var clearance: Float {
        var least = Float.greatestFiniteMagnitude
        for (index, fish) in koi.enumerated() {
            for other in koi[(index + 1)...] {
                var near = Float.greatestFiniteMagnitude
                for sample in stride(from: 0, to: Koi.samples, by: 4) {
                    near = min(near, other.nearest(to: fish.pose[sample]).far)
                }
                least = min(least, near - fish.maximumHalfWidth - other.maximumHalfWidth)
            }
        }
        return least
    }

    // MARK: - 描く

    /// 鯉を面へ描く。
    func draw() {
        canvas.beginDraw()
        canvas.background(.transparent)
        canvas.noStroke()
        // **奥から描く。** 深い鯉が浅い鯉の下になる
        for fish in koi.sorted(by: { $0.depth > $1.depth }) {
            fins(of: fish)
            body(of: fish)
            // **背鰭は体の後。** 背中の上に立っているものなので、体の下へ回すと消える
            ridge(
                of: fish, tint: fish.variety.fin, alpha: 0.34 * (1 - murk(of: fish)),
                on: canvas)
        }
        canvas.endDraw()
    }

    /// 池の底へ影を落とす。
    ///
    /// **暈けは深さで決まる。** 同じ輪郭を少しずつずらして 4 枚重ねるので、深い鯉ほど
    /// 影の縁が広がる (太陽は点ではないので、実際の半影も深さに比例して広がる)
    func castShadows(onto bed: Canvas) {
        bed.noStroke()
        // **影は太陽の反対側へ落ちる**
        let slide = -SIMD2(sun.x, sun.y)
        for fish in koi {
            let offset = slide * (fish.depth * shadowSlide)
            let blur = 2.5 + fish.depth * 0.075
            for step in 0..<4 {
                let angle = Float(step) * Float.pi / 2 + 0.4
                let jitter = SIMD2(cos(angle), sin(angle)) * blur
                bed.fill(.display(red: 0.0, green: 0.02, blue: 0.02, alpha: 0.19))
                strip(of: fish, on: bed, shift: offset + jitter)
                let tail = fish.caudal
                blade(
                    base: tail.base + offset + jitter, direction: tail.direction,
                    length: fish.length * 0.29,
                    width: fish.maximumHalfWidth * 0.20 * (1 + 1.6 * abs(tail.cup)),
                    cup: tail.cup, tint: .display(red: 0, green: 0.02, blue: 0.02),
                    alpha: 0.13, on: bed)
            }
        }
    }

    // MARK: - 部分

    private func body(of fish: Koi) {
        guard let paint else { return }
        canvas.shader(paint)
        // **値は毎フレーム置き直す。** 前のフレームの値が残ると、先頭の 1 匹の斑で
        // 群れ全部が塗られる
        paint.set("seed", .pair(fish.seed.x, fish.seed.y))
        paint.set("kind", .number(Float(fish.variety.rawValue)))
        paint.set("skin", .color(fish.variety.skin))
        paint.set("beni", .color(fish.variety.beni))
        paint.set("sumi", .color(fish.variety.sumi))
        paint.set("deep", .color(deep))
        paint.set("sheen", .number(fish.variety.sheen))
        paint.set("murk", .number(murk(of: fish)))
        paint.set("light", .pair(lightAcross(fish), sun.z))
        canvas.fill(255, 255, 255)
        if let unit { canvas.texture(unit) }
        strip(of: fish, on: canvas, shift: SIMD2(0, 0))
        canvas.noTexture()
        canvas.resetShader()
    }

    /// 鰭を描く。
    ///
    /// ## 縦に立った鰭と、水平に開いた鰭は、真上からの見え方が違う
    ///
    /// 魚の**尾鰭・背鰭は体の正中面に立っている**ので、真上から見ると板ではなく
    /// **細い刃**になる。扇が開いて見えるのはイルカやクジラで、あちらの尾は水平だから
    /// である。**胸鰭だけが水平に近い**ので、こちらは真上から開いた形で見える。
    ///
    /// はじめは尾鰭も扇で描いていて、**鯉ではなくイルカの尾に見えた。**
    private func fins(of fish: Koi) {
        let tint = fish.variety.fin
        let fade = 1 - murk(of: fish)
        let width = fish.maximumHalfWidth

        // 胸鰭。水平に近いので、真上からは開いて見える
        canvas.fill(
            .display(red: tint.red, green: tint.green, blue: tint.blue, alpha: 0.58 * fade))
        for sign in [Float(1), Float(-1)] {
            let fin = fish.pectoral(sign)
            paddle(
                base: fin.base, direction: fin.direction, length: fish.length * 0.165,
                spread: 0.46, on: canvas)
        }

        // 尾鰭。正中面に立っているので、真上からは撓んだ刃に見える。
        // **撓んでいるときほど太く見える** — 鰭が反って面が斜めを向くので、
        // 真上から見える切り口が広がる (打ち返す瞬間がいちばん細い)
        let tail = fish.caudal
        blade(
            base: tail.base, direction: tail.direction, length: fish.length * 0.29,
            width: width * 0.20 * (1 + 1.6 * abs(tail.cup)), cup: tail.cup,
            tint: tint, alpha: 0.46 * fade, on: canvas)

        // 髭 2 対。**鯉と金魚を分けているのはここ。**
        //
        // 太くすると牙に見えるので、**幅は 1 画素前後・濃さも控えめ**にしてある。
        // 色は鰭ではなく頭の地の色を落としたもの (髭は膜ではなく肉である)
        let skin = fish.variety.skin
        for sign in [Float(1), Float(-1)] {
            for whisker in fish.whiskers(sign) {
                blade(
                    base: whisker.base, direction: whisker.direction, length: whisker.reach,
                    width: max(width * 0.030, 0.6), cup: 0.7 * sign,
                    tint: .display(red: skin.red * 0.72, green: skin.green * 0.62,
                                   blue: skin.blue * 0.58),
                    alpha: 0.38 * fade, on: canvas)
            }
        }

        // **鰭条は引かない。** 縦に立った尾鰭の筋は真上からは同じ線へ潰れて見えず、
        // 胸鰭のほうは 40 画素ほどしかないので、筋を引くと膜ではなく櫛に見える
    }

    /// 体の輪郭を三角形の帯で描く。**閉じた多角形にしない** — 帯なら分割の仕方が
    /// 一意に決まるので、細い尾柄で潰れない。
    private func strip(of fish: Koi, on target: Canvas, shift: SIMD2<Float>) {
        let left = fish.flank(1)
        let right = fish.flank(-1)
        target.beginShape(.triangleStrip)
        for (index, station) in Koi.outline.enumerated() {
            let a = left[index] + shift
            let b = right[index] + shift
            // **体の座標は輪郭の刻みがそのまま持つ。** 節で割った値ではない
            target.vertex(a.x, a.y, station.u, 0)
            target.vertex(b.x, b.y, station.u, 1)
        }
        target.endShape()
    }

    /// 胸鰭の縁の 1 点。**又は入れない** — 尾鰭と違って先が丸い。
    private func paddleRim(
        base: SIMD2<Float>, direction: SIMD2<Float>, length: Float, spread: Float, at s: Float
    ) -> SIMD2<Float> {
        // 真ん中がいちばん長く、両端へなだらかに短くなる。前縁 (s > 0) をわずかに長く
        let reach = length * (0.44 + 0.56 * cos(s * 1.25)) * (1 + 0.20 * s)
        return base + Koi.turn(direction, by: s * spread) * reach
    }

    /// 水平に開いた鰭 (胸鰭) を扇で描く。
    private func paddle(
        base: SIMD2<Float>, direction: SIMD2<Float>, length: Float, spread: Float, on target: Canvas
    ) {
        target.beginShape(.triangleFan)
        target.vertex(base.x, base.y)
        for step in 0...16 {
            let s = Float(step) / 8 - 1
            let rim = paddleRim(
                base: base, direction: direction, length: length, spread: spread, at: s)
            target.vertex(rim.x, rim.y)
        }
        target.endShape()
    }

    /// 尾鰭の切り口の幅 (根元の幅に対する割合)。
    ///
    /// 途中でいったん締まってから上下の葉のぶんだけ膨らみ、**先で 0 近くまで細る。**
    /// 一定の幅で引くと板が刺さっているようにしか見えない
    private static let bladeProfile: [Float] = [
        1.00, 0.92, 0.84, 0.79, 0.78, 0.82, 0.88, 0.94, 0.96, 0.90, 0.72, 0.44, 0.16,
    ]

    /// 正中面に立った鰭 (尾鰭) を、真上から見た形で描く。
    ///
    /// **見えているのは膜の板ではなく、その切り口である。** 幅は膜の厚みと、鰭が
    /// 水を掴んで反り返るぶんしかない。反りは根元で 0、先へ向かって効かせる
    /// (`t²`) ので、刃は根元から滑らかに曲がる。
    ///
    /// **濃さも先へ向かって抜く。** 鰭は先へ行くほど薄い膜なので、水が透ける
    private func blade(
        base: SIMD2<Float>, direction: SIMD2<Float>, length: Float,
        width: Float, cup: Float, tint: LinearRGBA, alpha: Float, on target: Canvas
    ) {
        let steps = Self.bladeProfile.count - 1
        var place = base
        var ribs: [(place: SIMD2<Float>, side: SIMD2<Float>, half: Float)] = []
        ribs.reserveCapacity(steps + 1)
        for step in 0...steps {
            let t = Float(step) / Float(steps)
            let heading = Koi.turn(direction, by: cup * t * t)
            ribs.append((place, SIMD2(-heading.y, heading.x), width * Self.bladeProfile[step]))
            place += heading * (length / Float(steps))
        }
        target.beginShape(.triangleStrip)
        for (step, rib) in ribs.enumerated() {
            let t = Float(step) / Float(steps)
            target.fill(
                .display(
                    red: tint.red, green: tint.green, blue: tint.blue,
                    alpha: alpha * (1 - 0.55 * t * t)))
            let offset = rib.side * rib.half
            target.vertex(rib.place.x - offset.x, rib.place.y - offset.y)
            target.vertex(rib.place.x + offset.x, rib.place.y + offset.y)
        }
        target.endShape()
    }

    /// 背鰭。**背の上に乗る細い筋**で、真ん中がいちばん高く、前後の端で消える。
    private func ridge(of fish: Koi, tint: LinearRGBA, alpha: Float, on target: Canvas) {
        let first = 7
        let last = 16
        target.beginShape(.triangleStrip)
        for index in first...last {
            let t = Float(index - first) / Float(last - first)
            let rib = fish.rib(at: index)
            let hump = sin(t * Float.pi)
            target.fill(
                .display(
                    red: tint.red, green: tint.green, blue: tint.blue, alpha: alpha * hump))
            let offset = rib.side * max(fish.maximumHalfWidth * 0.13 * hump, 0.4)
            target.vertex(rib.place.x - offset.x, rib.place.y - offset.y)
            target.vertex(rib.place.x + offset.x, rib.place.y + offset.y)
        }
        target.endShape()
    }

    /// その深さで、どれだけ水の色へ寄るか。
    ///
    /// **水面の断片が掛ける濁りとは役目が違う。** あちらは「鯉の層より上の水」を
    /// 一様に掛けるもので、こちらは**匹ごとの深さの差**を受け持つ
    private func murk(of fish: Koi) -> Float {
        min(max((fish.depth - 34) / 190, 0), 0.62)
    }

    /// 太陽の、その鯉の体の横向き成分。**背の照りが左右どちらへ寄るかを決める。**
    private func lightAcross(_ fish: Koi) -> Float {
        let side = SIMD2(-fish.heading.y, fish.heading.x)
        return simd_dot(SIMD2(sun.x, sun.y), side)
    }

    // MARK: - 断片

    private static let startingValues: [String: ShaderValue] = [
        "seed": .pair(0, 0),
        "light": .pair(0, 1),
        "kind": 0,
        "sheen": 0.3,
        "murk": 0,
        "skin": .color(.display(red: 1, green: 1, blue: 1)),
        "beni": .color(.display(red: 1, green: 0, blue: 0)),
        "sumi": .color(.display(red: 0, green: 0, blue: 0)),
        "deep": .color(.display(red: 0, green: 0.2, blue: 0.2)),
    ]

    /// 体を塗る断片。**読むのは体の座標だけ**である。
    private static let body = """
        float4 paint(Fragment in, Values values) {
            float2 b = in.uv;
            float along = clamp(b.x, 0.0, 1.0);
            float across = clamp(b.y, 0.0, 1.0);
            float kind = values.kind;

            // 体の座標で引く揺らぎ。**体に貼り付いている**ので、泳ぎで斑が歪む
            float3 q = float3(along * 3.6 + values.seed.x, across * 1.5 + values.seed.y, 0.0);
            float blotch = mokume_noise(in, q * 1.7);
            float second = mokume_noise(in, q * 2.3 + float3(17.0, 5.0, 2.0));
            float third = mokume_noise(in, q * 3.1 + float3(41.0, 23.0, 7.0));

            float3 skin = values.skin.rgb;
            float3 beni = values.beni.rgb;
            float3 sumi = values.sumi.rgb;

            // **斑の縁は鋭い。** にじませると鯉に見えない (錦鯉の評価軸が「キワ」で
            // あるのはそのため)
            float hi = smoothstep(0.505, 0.545, blotch);
            float back = smoothstep(0.20, 0.55, 1.0 - abs(across - 0.5) * 2.0);

            float3 body = skin;
            if (kind < 0.5) {                       // 紅白
                body = mix(skin, beni, hi);
            } else if (kind < 1.5) {                // 大正三色
                body = mix(skin, beni, hi);
                body = mix(body, sumi, smoothstep(0.585, 0.625, second) * back);
            } else if (kind < 2.5) {                // 昭和三色
                body = mix(skin, beni, smoothstep(0.435, 0.475, blotch));
                body = mix(body, sumi, smoothstep(0.575, 0.615, third));
            } else if (kind < 3.5) {                // 黄金
                body = mix(skin, beni, 0.22 + 0.26 * blotch);
            } else if (kind < 4.5) {                // 浅黄
                body = mix(beni, skin, back);
                body = mix(body, sumi, smoothstep(0.52, 0.72, second) * back * 0.55);
            } else {                                // 白写り
                body = mix(skin, sumi, smoothstep(0.445, 0.485, blotch));
            }

            // 鱗。**千鳥に並べる** — 格子に並べると織物に見える
            float2 cell = float2(along * 40.0, across * 10.0);
            cell.x += fmod(floor(cell.y), 2.0) * 0.5;
            float2 f = fract(cell) - 0.5;
            float d = length(f * float2(1.0, 1.6));
            body *= 1.0 - smoothstep(0.26, 0.46, d) * 0.17;
            body += smoothstep(0.30, 0.04, d) * values.sheen * 0.09;

            // 真上から見た体の丸み。背 (v = 0.5) が正面を向き、脇腹が逃げる。
            // **頭は平たい。** 鯉の頭は上から見ると幅の割に薄く、胴のような丸い
            // 円柱ではない — 全長に同じ丸みを掛けると、顔だけが樽のように見える
            float round = mix(0.45, 1.0, smoothstep(0.05, 0.30, along));
            float theta = (across - 0.5) * 3.14159265 * round;
            float lam = max(values.light.x * sin(theta) + values.light.y * cos(theta), 0.0);
            body *= 0.44 + 0.68 * lam;
            body += values.sheen * pow(lam, 16.0) * 0.5;

            // 鰓蓋の後端。**肩がどこで終わるか**がここで読める (頭から 4 分の 1)
            float gill = 1.0 - smoothstep(0.0, 0.022, abs(along - 0.255));
            body *= 1.0 - gill * 0.13 * smoothstep(0.10, 0.30, abs(across - 0.5));

            // 口。突き出た上唇のぶん、鼻先は前へ丸い
            float lip = 1.0 - smoothstep(0.006, 0.020, abs(along - 0.013));
            body *= 1.0 - lip * 0.30 * (1.0 - smoothstep(0.18, 0.40, abs(across - 0.5)));

            // 縁は水へ溶ける
            body *= 0.55 + 0.45 * smoothstep(0.0, 0.055, min(across, 1.0 - across));

            // 目。
            //
            // **位置も大きさも上見の写真から取った** — 鼻先から体長の 9%、頭の側面
            // (中心から縁へ 7 割の位置)、径は体長の 2.6%。`across` は体の幅で割った
            // 座標なので、そこが体長の 16% しかないこの位置では、**丸い目は across
            // 方向へ 6 倍に伸ばして置く**ことになる (置いてあった値は along 方向に
            // 長い薄片で、真上から見ると細い線に見えていた)
            float2 radius = float2(0.0132, 0.083);
            float eye = min(
                length((b - float2(0.090, 0.170)) / radius),
                length((b - float2(0.090, 0.830)) / radius));
            body = mix(body, float3(0.020, 0.018, 0.016), 1.0 - smoothstep(0.86, 1.02, eye));
            body += (1.0 - smoothstep(0.22, 0.42, eye)) * 0.30;

            // 深さのぶん、水の色へ寄る
            body = mix(body, values.deep.rgb, values.murk);
            return float4(body * in.color.a, in.color.a);
        }
        """
}
