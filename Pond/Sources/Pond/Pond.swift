import Foundation
import mokume
import simd

/// Pond — 池の水面と錦鯉。
///
/// **水っぽく描くのではなく、水面の傾きから絵を導いている。** 面の高さ場 (`Water`) を
/// 微分して傾きを出し、そこから 3 つを導く:
///
/// 1. **屈折** — 空気から水へ入る向きを Snell で曲げ、深さのぶんだけ底と鯉の読み位置を
///    ずらす。深さが違うので**底と鯉のずれ方が違い**、それが奥行きになる
/// 2. **焦線 (caustics)** — 屈折でできる像の面積の伸び縮みそのもの。傾いた面がレンズに
///    なって光を寄せるので、**屈折を止めれば焦線も消える** (同じ写像の行列式である)
/// 3. **鏡面反射** — Schlick のフレネル。真上から見た水の反射率は 2% しかないので、
///    見えるのは**太陽だけ**である。それで十分に光る — 太陽の輝度が桁違いだからで、
///    水面がきらめく理由がそれである
///
/// ## 風を 0 にすると、底が澄む
///
/// スクロールで風波の振幅を 0 まで落とせる。**傾きが無くなるので屈折も焦線も消え**、
/// 底の砂と石が歪みなく見える。残るのは鯉が自分で押し上げているふくらみと、置いた輪
/// だけになる。上げていくと底が崩れ、代わりに面がきらめき始める — 池が「透けて見える
/// もの」から「光を映すもの」へ変わる 1 点を、手で行き来できる。
///
/// ## 3 枚を 1 枚にする
///
/// 池の底 (`Bed`) と鯉 (`School`) は**別々の面へ焼いて**、水面の断片が名前で読む。
/// 深さごとに屈折のずれを変えるのに、1 枚に描いてしまうと分けられないからである。
/// 水の上のもの (`Surface`) だけは水面を塗った後に重ねる — 浮いているものは水越しに
/// 見ていない。
final class Pond: Sketch {
    var settings = SketchSettings(width: 1920, height: 1080, title: "pond")

    // MARK: - 場面

    /// 場面の寸法 (mm)。**1 画素 = 1 mm。**
    private let span = SIMD2<Float>(1920, 1080)
    /// 池の底までの深さ (mm)。
    private let bedDepth: Float = 420
    /// 鯉の層の深さ (mm)。**匹ごとの差は `School` が色で受け持つ。**
    private let fishDepth: Float = 84
    /// 目の高さ (mm)。画面の隅で視線が 30 度ほど傾く。
    private let eyeHeight: Float = 1700
    /// 太陽の向き (画面の x, y と上向き)。
    private let sun = SIMD3<Float>(-0.22, -0.32, 0.92)

    // MARK: - 中身

    private let water = Water()
    private var bed: Bed?
    private var school: School?
    private var pond: Surface?
    private var field: Numbers?
    private var paint: Shader?

    // MARK: - 触る

    private var touch = SIMD2<Float>(960, 540)
    private var touchedAt: Float = -100
    private var wakeAt: Float = -100
    private var wakeFrom = SIMD2<Float>(-4000, -4000)
    /// 手が水面に残す怖さが消えるまでの間 (秒)。
    private let fearFade: Float = 1.6

    func setup() {
        // **画面の性質なのでフレームを越える。** 太陽のきらめきは 1 を大きく超えるので、
        // 飽和させずに出口で肩を丸める
        exposure(0.96)
        toneMapping(.roll)
        textSize(24)
        noiseSeed(5107)
        noiseDetail(4, 0.5)

        guard
            let bedCanvas = try? createGraphics(Int(span.x / 2), Int(span.y / 2)),
            let fishCanvas = try? createGraphics(Int(span.x), Int(span.y)),
            let floatCanvas = try? createGraphics(Int(span.x), Int(span.y))
        else { return }

        bed = Bed(canvas: bedCanvas, span: span)
        school = School(canvas: fishCanvas, bounds: span)
        school?.sun = sun
        pond = Surface(canvas: floatCanvas, span: span)
        field = try? makeNumbers(count: Water.slotCount)
        field?.fill(0)

        paint = try? makeShader(
            Water.field + Self.mirror, name: "water", values: startingValues,
            surfaces: [
                "bed": .graphics(bedCanvas), "fish": .graphics(fishCanvas),
                "afloat": .graphics(floatCanvas),
            ])
    }

    func draw() {
        guard let bed, let school, let pond, let field, let paint else {
            background(8, 14, 16)
            return
        }
        let now = time
        // **飛んだフレームで鯉を跳ばさない。** 作り直しの後の 1 フレーム目が長い
        let step = min(deltaTime, 1.0 / 20)

        stir(now: now)
        water.fade(now: now)
        pond.soak(now: now)
        pond.wind = water.wind
        pond.drift(dt: step, wind: water.wind)
        move(school: school, pond: pond, now: now, step: step)

        // 池の底 — 砂と石と水草を敷き、その上へ影を落とす
        bed.draw(time: now)
        school.castShadows(onto: bed.canvas)
        pond.castShadows(
            onto: bed.canvas, slide: -SIMD2(sun.x, sun.y), depth: bedDepth * 0.62, time: now)
        bed.finish()

        // 鯉と、水の上のもの
        school.draw()
        pond.draw(time: now)

        // 水面。**3 枚がここで 1 枚になる**
        field.set(water.pack(now: now, koi: school.koi))
        background(4, 9, 11)
        noStroke()
        fill(255, 255, 255)
        place(values: paint, now: now)
        numbers(field)
        shader(paint)
        rect(0, 0, span.x, span.y)
        resetShader()
        resetNumbers()

        guide()

        effects([.bloom(amount: 0.46, threshold: 0.66, radius: 20), .vignette(amount: 0.24)])

        expose("wind", water.wind)
        expose("rings", water.rings.count)
        expose("pellets", pond.pellets.count)
        expose("koi", school.koi.count)
        expose("touched", now - touchedAt < fearFade)
    }

    // MARK: - 進める

    /// 群れを 1 フレーム進め、餌を食べさせる。
    private func move(school: School, pond: Surface, now: Float, step: Float) {
        let fear = max(0, 1 - (now - touchedAt) / fearFade)
        let scare: (place: SIMD2<Float>, strength: Float)? =
            fear > 0.01 ? (touch, fear) : nil

        for fish in school.koi {
            // **餌は毎回引き直す。** 前の鯉が食べた餌を指したままにしない
            let bait = pond.nearest(to: fish.head, within: 660)
            fish.swim(
                dt: step, now: now, bounds: span, school: school.koi,
                food: bait?.place, scare: scare, water: water)
            guard let bait else { continue }
            // **口へ届いたときだけ食べる。** 体の中心から半径 90 画素で消していた
            // ときは、鯉が近づいただけで餌が消え、口に入るところが見えなかった。
            // いま見ているのは**鼻先から体長の 5.5%** (340 mm の鯉で 19 mm) で、
            // しかも鼻先より前にあることを求める
            let toward = bait.place - fish.mouth
            let reach = fish.length * 0.055
            if simd_length(toward) < reach, simd_dot(toward, fish.heading) > -reach * 0.4 {
                if let eaten = pond.take(bait.index) {
                    water.ripple(at: eaten, now: now, amplitude: 1.8, wavelength: 36, life: 1.1)
                }
            }
        }
    }

    /// 指で撫でた跡に輪を置く。
    ///
    /// **動いた距離で刻む。** 時間で刻むと、止めている間も輪が湧き続けて 1 か所が
    /// 泡立ってしまう
    private func stir(now: Float) {
        guard now - touchedAt < 0.10 else { return }
        guard simd_length(touch - wakeFrom) > 26, now - wakeAt > 0.05 else { return }
        wakeFrom = touch
        wakeAt = now
        water.ripple(at: touch, now: now, amplitude: 1.3, wavelength: 46, life: 1.8)
    }

    // MARK: - 触る

    func mouseMoved() {
        touch = SIMD2(mouseX, mouseY)
        touchedAt = time
    }

    func mouseDragged(deltaX: Float, deltaY: Float) {
        touch = SIMD2(mouseX, mouseY)
        touchedAt = time
    }

    /// 押すと餌が落ちる。**落ちた衝撃がいちばん強い輪**になる。
    func mousePressed() {
        let place = SIMD2(mouseX, mouseY)
        pond?.drop(at: place, now: time)
        water.ripple(at: place, now: time, amplitude: 4.0, wavelength: 58, life: 3.4)
        touchedAt = -100
    }

    /// スクロールは**風の強さ**。0 で波が止まる。
    func mouseWheel(deltaX: Float, deltaY: Float) {
        water.wind = min(max(water.wind + deltaY * 0.012, 0), 1.6)
    }

    func keyPressed() {
        if keyCode == .space { pond?.clear() }
        if keyCode == .r {
            pond?.clear()
            water.clearRings()
            water.wind = 0.55
            touchedAt = -100
        }
    }

    // MARK: - 手引き

    private func guide() {
        noStroke()
        fill(.display(red: 0.80, green: 0.86, blue: 0.84, alpha: 0.72))
        let baseline = span.y - 152
        text("クリック — 餌を落とす", 56, baseline)
        text("動かす — 水面を撫でる (鯉は逃げる)", 56, baseline + 33)
        text("スクロール — 風 \(String(format: "%.2f", water.wind))", 56, baseline + 66)
        text("スペース — 餌を片付ける", 56, baseline + 99)
        text("R — はじめへ戻す", 56, baseline + 132)
    }

    // MARK: - 断片へ渡すもの

    private var startingValues: [String: ShaderValue] {
        [
            "clock": 0,
            "probe": 5.0,
            "deepBed": .number(bedDepth),
            "deepFish": .number(fishDepth),
            "high": .number(eyeHeight),
            "sunUp": .number(sun.z),
            "glare": 0.85,
            "caustic": 0.82,
            "eye": .pair(span.x / 2, span.y / 2),
            "sun": .pair(sun.x, sun.y),
            // 減衰の係数 (1 mm あたり)。**赤から先に失われる**ので、深いほど緑へ寄る
            "murk": .color(.linear(red: 0.00150, green: 0.00055, blue: 0.00105)),
            "silt": .color(.display(red: 0.090, green: 0.165, blue: 0.140)),
            "zenith": .color(.display(red: 0.42, green: 0.64, blue: 1.00)),
            "horizon": .color(.display(red: 0.78, green: 0.86, blue: 0.95)),
            "canopy": .color(.display(red: 0.06, green: 0.12, blue: 0.05)),
            "sunlight": .color(.display(red: 1.00, green: 0.95, blue: 0.86)),
        ]
    }

    /// **値は毎フレーム置き直す。** 前のフレームの値が残ると、1 か所を触っただけで
    /// 面の全部が前の設定で描かれる。
    private func place(values paint: Shader, now: Float) {
        paint.set("clock", .number(now))
        paint.set("probe", .number(5.0))
        paint.set("deepBed", .number(bedDepth))
        paint.set("deepFish", .number(fishDepth))
        paint.set("high", .number(eyeHeight))
        paint.set("sunUp", .number(sun.z))
        paint.set("glare", .number(0.85))
        paint.set("caustic", .number(0.82))
        paint.set("eye", .pair(span.x / 2, span.y / 2))
        paint.set("sun", .pair(sun.x, sun.y))
    }

    /// 水面を塗る断片。**`Water.field` が前に付く。**
    private static let mirror = """

        /// 屈折で読み位置がどれだけずれるか。
        ///
        /// **平らな水面での見え方を基準にして、波のぶんだけを取る。** 傾いていない
        /// 面でも、隅では視線が斜めなので底は外へずれる — それは 2D で組んだ場面の
        /// 座標そのものなので、引いておかないと波が無くても絵が歪む
        static inline float2 pond_bend(float2 p, float2 g, float depth, float2 eye, float high) {
            float3 n = normalize(float3(-g, 1.0));
            float3 v = normalize(float3(p - eye, -high));
            // 空気 → 水。1 / 1.333
            float3 bent = refract(v, n, 0.75019);
            float3 flat = refract(v, float3(0.0, 0.0, 1.0), 0.75019);
            if (bent.z > -1e-3 || flat.z > -1e-3) { return float2(0.0); }
            return depth * (bent.xy / -bent.z - flat.xy / -flat.z);
        }

        /// 空。**映る向きだけで決まる。**
        ///
        /// 池の縁には木が立っていることにしてある。反射の向きが低いほど樹冠が濃く
        /// なるので、**面が大きく傾いたところにだけ緑が差す**
        static inline float3 pond_sky(Fragment in, float3 dir, Values values) {
            float up = clamp(dir.z, 0.0, 1.0);
            float3 sky = mix(values.horizon.rgb, values.zenith.rgb, pow(up, 0.6));

            float2 aim = dir.xy / max(dir.z, 0.15);
            float leaves = mokume_noise(in, float3(aim * 2.3, values.clock * 0.03));
            float low = 1.0 - smoothstep(0.62, 0.90, up);
            sky = mix(sky, values.canopy.rgb * (0.4 + 1.4 * leaves), low * 0.85);

            // 太陽。**桁が違う。** 反射率が 2% しかなくても、これだけは水面で光る。
            //
            // **玉の大きさは実際の視直径 (0.53 度) に合わせてある。** `pow` で作ると
            // 指数を上げても裾が広く、鏡のように凪いだ面で太陽が空の 4 分の 1 を
            // 占める白い雲になった。離れ角の 2 乗で落とすと縁が締まる
            float3 star = normalize(float3(values.sun, values.sunUp));
            float apart = 1.0 - max(dot(normalize(dir), star), 0.0);
            sky += values.sunlight.rgb * values.glare * exp(-apart * 26000.0) * 620.0;
            sky += values.sunlight.rgb * values.glare * exp(-apart * 90.0) * 0.30;
            return sky;
        }

        float4 paint(Fragment in, Values values, Surfaces surfaces) {
            float2 p = in.position;
            float t = values.clock;
            float eps = values.probe;
            float2 eye = values.eye;
            float high = values.high;

            // **絵に効くのはここだけ。** 高さは一度も使わない
            // **焦線を見る幅は 1 画素ではない。** 細かい波が作る焦点は底より手前で
            // 結んでまた散るので、底へ届くのはその辺りで均したもの — 12 画素ぶんの
            // 差分で見ると、長い波の網目が残って細かい波の織り目が消える
            float2 g0 = pond_slope(in, p, t);
            float2 gx = pond_slope(in, p + float2(eps, 0.0), t);
            float2 gy = pond_slope(in, p + float2(0.0, eps), t);

            float2 toBed = pond_bend(p, g0, values.deepBed, eye, high);
            float2 toFish = pond_bend(p, g0, values.deepFish, eye, high);

            // 焦線は**屈折と同じ写像の面積変化**である。像が縮んだところが明るい。
            // 底へ落ちる像の面積比は写像のヤコビ行列式そのもので、明るさはその逆数
            float2 bx = pond_bend(p + float2(eps, 0.0), gx, values.deepBed, eye, high);
            float2 by = pond_bend(p + float2(0.0, eps), gy, values.deepBed, eye, high);
            float2 dx = (bx - toBed) / eps;
            float2 dy = (by - toBed) / eps;
            float area = (1.0 + dx.x) * (1.0 + dy.y) - dx.y * dy.x;
            // **浅いところほど焦線はぼやける。** ずれは深さに比例するので、行列式の
            // 「1 からの離れ」も深さに比例する — 鯉の層の焦線は底の 5 分の 1 になる
            float shallow = values.deepFish / values.deepBed;
            float focusBed = clamp(1.0 / max(area, 0.22), 0.2, 3.4);
            float focusFish = clamp(1.0 / max(1.0 + (area - 1.0) * shallow, 0.42), 0.4, 2.0);

            // 木洩れ日。**日向と日陰がゆっくり流れる**ので、焦線の出る場所が偏る
            float dapple =
                0.52 + 0.66 * mokume_noise(in, float3(p * 0.0013 + float2(t * 0.007, 0.0), 5.0));
            float3 sunlit = values.sunlight.rgb * dapple;
            float3 litBed = sunlit * mix(1.0, pow(focusBed, 0.9), values.caustic);
            float3 litFish = sunlit * mix(1.0, pow(focusFish, 0.9), values.caustic);

            float2 size = in.resolution;
            float4 floorHere = mokume_sample(surfaces.bed, (p + toBed) / size);
            float4 fishHere = mokume_sample(surfaces.fish, (p + toFish) / size);

            // 濁り。**行きと帰りで 2 倍の道のり**を通る
            float3 sigma = values.murk.rgb;
            float3 keepBed = exp(-sigma * 2.0 * values.deepBed);
            float3 keepFish = exp(-sigma * 2.0 * values.deepFish);

            float3 under = floorHere.rgb * litBed * keepBed + values.silt.rgb * (1.0 - keepBed);
            float3 fishLit =
                fishHere.rgb * litFish * keepFish + values.silt.rgb * (1.0 - keepFish) * fishHere.a;
            under = under * (1.0 - fishHere.a) + fishLit;

            // 映り込み。**真上から見た水の反射率は 2%** しかない
            float3 n = normalize(float3(-g0, 1.0));
            float3 toEye = normalize(float3(eye - p, high));
            float cosine = clamp(dot(n, toEye), 0.0, 1.0);
            float fresnel = 0.02 + 0.98 * pow(1.0 - cosine, 5.0);
            float3 mirror = pond_sky(in, reflect(-toEye, n), values);
            float3 colour = mix(under, mirror, fresnel);

            // 浮いているもの。**水越しに見ていない**ので屈折も濁りも掛からない。
            // 代わりに**長い波にだけ乗る** — 横へ流されるぶんだけずれ、面の傾きで
            // 濡れた葉の照りが動く
            float4 ride = pond_ride(in, p, t);
            float4 afloat = mokume_sample(surfaces.afloat, (p + ride.zw) / size);
            if (afloat.a > 0.001) {
                float3 leaf = normalize(float3(-ride.xy, 1.0));
                float3 star = normalize(float3(values.sun, values.sunUp));
                float lambert = max(dot(leaf, star), 0.0);
                // **日陰でも真っ黒にはならない。** 木洩れ日の影へ入った葉にも空からの
                // 光は届くので、天頂の色を底上げとして足す (足さずに掛け算だけで
                // 作っていたときは、隅の葉が穴のように黒く沈んだ)
                float3 wet =
                    values.zenith.rgb * 0.12 + values.sunlight.rgb * (dapple * lambert * 0.88);
                colour = colour * (1.0 - afloat.a) + afloat.rgb * wet;

                // 濡れた葉の照り。**足し算で乗せる** — 鏡面反射は下の色に染まらない
                // ので、掛け算にすると葉が明るい緑になるだけで艶に見えない。
                // **傾くと外れる**ので、照りが葉の上を流れていく
                float3 between = normalize(star + toEye);
                float aligned = max(dot(leaf, between), 0.0);
                // **鋭い山を小さく乗せる。** 濡れた葉でも鏡面反射は数 % しかないので、
                // 大きく足すと葉が白く飛ぶ (0.9 にしていたときは睡蓮が白い塊になった)
                // **山を鋭くして小さく乗せる。** 広い山を大きく乗せると葉が一枚まるごと
                // 灰色に飛ぶ — 濡れた葉の艶は、葉の上を流れる細い帯として出る
                float gloss = pow(aligned, 260.0) * 0.16 + pow(aligned, 16.0) * 0.006;
                colour += values.sunlight.rgb * (gloss * dapple * afloat.a);
            }

            return float4(colour, 1.0);
        }
        """
}
