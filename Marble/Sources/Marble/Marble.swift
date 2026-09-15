import Foundation
import mokume
import simd

/// Marble — 墨を流して混ぜる水盤。
///
/// **絵は毎フレーム解いた流れの積分結果である。** 図形は全画面の矩形 1 枚しか置いていない。
/// 水面の速度と 4 つの顔料の濃度は GPU の並び (`Numbers`) にあり、`draw()` が 30 回ほど
/// 計算 (`compute`) を頼んで 1 フレーム進める。**状態は GPU の側にしか無い**ので、
/// CPU が持っているのは手の跡と、いま選んでいる顔料だけである。
///
/// ## 混ざるのに濁らない
///
/// 非圧縮の流れ (`∇·v = 0`) は場所を作りも消しもしないので、顔料は**伸ばされて畳まれる
/// だけ**で薄まらない。筋は髪の毛ほどに細くなっても、濃さはそのままである — 絵の具を
/// パレットで練れば灰色になるのに、墨流しが何度かき混ぜても色を保つ理由がこれである。
///
/// 数の上で薄まるのは移流の誤差 (数値拡散) のほうで、そちらは MacCormack で抑えてある
/// (``Fluid``)。
///
/// ## 色は足し算ではなく掛け算で混ざる
///
/// 顔料は光を吸う。濃度 `c` の顔料を通った光は `exp(-σc)` になるので、**重なった顔料の
/// 指数は足し算**になり、透過率は掛け算になる (Lambert–Beer)。藍と臙脂が重なれば紫に
/// 沈み、どれだけ重ねても白へ飛ばない。`mix` でも加算でもこうはならない。
final class Marble: Sketch {
    var settings = SketchSettings(width: 1920, height: 1080, title: "marble")

    /// 顔料の格子 1 マスが画面の何画素か。**顔料は画素と同じ細かさ**なので 1 である。
    private var inkCell: Float { Float(settings.width) / Float(Fluid.inkColumns) }
    /// 速度の格子 1 マスが画面の何画素か。
    private var flowCell: Float { Float(settings.width) / Float(Fluid.flowColumns) }

    private var fluid: Fluid?
    private var paint: Shader?

    /// いま落とす顔料。**落とすたびに次の色へ回る** — 押しっぱなしで同心円を作ると、
    /// 勝手に色が変わっていく
    private var pigment: Pigment = .indigo
    /// 落とすたびに色を回すか。
    private var cycles = true

    /// このフレームぶんの手の跡と滴。**進めたら捨てる。**
    private var pushes: [Push] = []
    private var falling: [Drop] = []
    /// 直前に手があったところ (画面の画素)。
    private var lastTouch: SIMD2<Float>?
    /// 手が離れてから経った時間を測るための時刻。
    private var touchedAt: Float = -100

    func setup() {
        noiseSeed(9173)
        noiseDetail(4, 0.55)
        fluid = Fluid(on: self)
        do {
            paint = try makeShader(Self.surface, name: "marble", values: startingValues)
        } catch {
            FileHandle.standardError.write(Data("marble: 塗りを組み立てられない — \(error)\n".utf8))
        }
    }

    func draw() {
        guard let fluid, let paint else {
            background(236, 231, 219)
            return
        }
        // **飛んだフレームで流れを跳ばさない。** 作り直しの後の 1 フレーム目が長い
        let step = min(deltaTime, 1.0 / 30)
        fluid.step(on: self, dt: step, now: time, pushes: pushes, falling: falling)

        background(236, 231, 219)
        noStroke()
        fill(255, 255, 255)
        place(values: paint)
        numbers(fluid.pigment)
        shader(paint)
        rect(0, 0, width, height)
        resetShader()
        resetNumbers()

        effects([.vignette(amount: 0.20)])

        expose("pigment", pigment.label)
        expose("cycles", cycles)
        expose("pushes", pushes.count)
        expose("drops", falling.count)
        expose("stirring", time - touchedAt < 0.2)
        expose("sweeps", Fluid.sweeps)
        expose("flowCells", Fluid.flowColumns * Fluid.flowRows)
        expose("inkCells", Fluid.inkColumns * Fluid.inkRows)
        expose("step", step)

        pushes.removeAll(keepingCapacity: true)
        falling.removeAll(keepingCapacity: true)
    }

    // MARK: - 触る

    func mouseMoved() { stir(to: SIMD2(mouseX, mouseY), gain: Ink.handGain) }

    func mouseDragged(deltaX: Float, deltaY: Float) {
        stir(to: SIMD2(mouseX, mouseY), gain: Ink.handGain * Ink.combGain)
    }

    /// 押すと滴が落ちる。**同じところへ続けて落とすと同心円になる** — 前の滴が
    /// 押しのけられて輪になるからで、輪を描いているわけではない。
    func mousePressed() {
        let place = SIMD2(mouseX, mouseY)
        guard falling.count < Drop.capacity else { return }
        falling.append(
            Drop(
                place: place / inkCell, radius: Ink.dropRadius, pigment: pigment,
                amount: Ink.dropAmount))
        if cycles { pigment = pigment.next }
        // **落とした瞬間は撫でない。** 押した拍子の 1 画素ぶんの動きで水が乱れる
        lastTouch = place
    }

    func keyPressed() {
        switch keyCode {
        case Key.digit1: pigment = .sumi
        case Key.digit2: pigment = .indigo
        case Key.digit3: pigment = .crimson
        case Key.digit4: pigment = .gamboge
        case Key.c: cycles.toggle()
        case Key.space: fluid?.calm()
        case Key.r: fluid?.rewind()
        default: break
        }
    }

    /// 手の跡を水へ写す。
    ///
    /// **動いた線分に沿って何個かに分ける。** 1 回の報せにつき 1 個だけ置くと、手を
    /// 速く動かしたときに点々としか押されず、水が梳かれた跡にならない。
    private func stir(to place: SIMD2<Float>, gain: Float) {
        defer {
            lastTouch = place
            touchedAt = time
        }
        guard let from = lastTouch else { return }
        let a = from / flowCell
        let b = place / flowCell
        let move = b - a
        let far = simd_length(move)
        guard far > 0.03 else { return }

        let steps = min(Int(far / (Ink.handRadius * 0.7)) + 1, 6)
        for k in 0..<steps {
            guard pushes.count < Push.capacity else { return }
            let t = Float(k + 1) / Float(steps)
            pushes.append(
                Push(
                    place: a + move * t, toward: move, radius: Ink.handRadius,
                    strength: gain))
        }
    }

    // MARK: - 断片へ渡すもの

    private var startingValues: [String: ShaderValue] {
        [
            "grid": .pair(Float(Fluid.inkColumns), Float(Fluid.inkRows)),
            "sumi": Pigment.sumi.shaderValue,
            "indigo": Pigment.indigo.shaderValue,
            "crimson": Pigment.crimson.shaderValue,
            "gamboge": Pigment.gamboge.shaderValue,
            // 生成りの楮紙。**白ではない**ので、濃い墨との間に温かさが残る
            "paper": .color(.display(red: 0.925, green: 0.906, blue: 0.867)),
            "fiber": 0.055,
            "edge": 0.42,
            "sheen": 0.15,
            "bump": 1.5,
        ]
    }

    /// **値は毎フレーム置き直す。** 前のフレームの値が残ると、1 か所を触っただけで
    /// 面の全部が前の設定で描かれる。
    private func place(values paint: Shader) {
        paint.set("grid", .pair(Float(Fluid.inkColumns), Float(Fluid.inkRows)))
        paint.set("fiber", .number(0.055))
        paint.set("edge", .number(0.42))
        paint.set("sheen", .number(0.15))
        paint.set("bump", .number(1.5))
    }

    /// 水面を塗る断片。**読むのは顔料の濃度だけ**で、速度も圧力も絵には出てこない。
    private static let surface = """
        /// 顔料の濃度を双一次で汲む (位置は顔料の格子のマス)。
        static inline float4 mb_ink(Fragment in, float2 grid, float2 p) {
            float2 q = clamp(p - 0.5, float2(0.0), grid - 1.0);
            float2 base = floor(q);
            float2 t = q - base;
            float2 far = min(base + 1.0, grid - 1.0);
            uint columns = uint(grid.x);
            uint a = (uint(base.y) * columns + uint(base.x)) * 4u;
            uint b = (uint(base.y) * columns + uint(far.x)) * 4u;
            uint c = (uint(far.y) * columns + uint(base.x)) * 4u;
            uint d = (uint(far.y) * columns + uint(far.x)) * 4u;
            float4 top = mix(
                float4(in.numbers[a], in.numbers[a + 1u], in.numbers[a + 2u], in.numbers[a + 3u]),
                float4(in.numbers[b], in.numbers[b + 1u], in.numbers[b + 2u], in.numbers[b + 3u]),
                t.x);
            float4 low = mix(
                float4(in.numbers[c], in.numbers[c + 1u], in.numbers[c + 2u], in.numbers[c + 3u]),
                float4(in.numbers[d], in.numbers[d + 1u], in.numbers[d + 2u], in.numbers[d + 3u]),
                t.x);
            return mix(top, low, t.y);
        }

        /// 濃度 4 つを、光をどれだけ吸うかへ写す。
        static inline float3 mb_absorb(float4 c, Values values) {
            return values.sumi.rgb * c.x + values.indigo.rgb * c.y
                 + values.crimson.rgb * c.z + values.gamboge.rgb * c.w;
        }

        float4 paint(Fragment in, Values values) {
            float2 grid = values.grid;
            float2 spot = in.place * grid;

            float4 here = mb_ink(in, grid, spot);
            // 膜の厚み。**縁と照りはここの傾きから出る**
            float4 right = mb_ink(in, grid, spot + float2(1.0, 0.0));
            float4 left = mb_ink(in, grid, spot - float2(1.0, 0.0));
            float4 down = mb_ink(in, grid, spot + float2(0.0, 1.0));
            float4 up = mb_ink(in, grid, spot - float2(0.0, 1.0));
            float thick = dot(here, float4(1.0));
            float2 slope = 0.5 * float2(
                dot(right - left, float4(1.0)), dot(down - up, float4(1.0)));

            // 紙。**楮の繊維が縦横に走る** — 細長い揺らぎを 2 方向重ねる
            float lengthwise = mokume_noise(in, float3(in.place * float2(7.0, 260.0), 3.0));
            float crosswise = mokume_noise(in, float3(in.place * float2(240.0, 9.0), 17.0));
            float speck = mokume_noise(in, float3(in.place * 520.0, 41.0));
            float grain = (lengthwise + crosswise) * 0.5 + (speck - 0.5) * 0.35;
            float3 paper = values.paper.rgb * (1.0 + values.fiber * (grain - 0.5) * 2.0);

            // 縁の濃まり。**墨の縁は濃い** — 溜まったところで乾くからで、
            // 厚みの傾きが大きいほど濃く見える
            float rim = values.edge * clamp(length(slope) * 1.6, 0.0, 1.4);
            float3 sigma = mb_absorb(here, values) * (1.0 + rim);

            // Lambert–Beer。**ここが混色の全部である**
            float3 colour = paper * exp(-sigma);

            // まだ水に浮いている。膜の傾きを法線にして、弱く光らせる
            float3 normal = normalize(float3(-slope * values.bump, 1.0));
            float3 sun = normalize(float3(-0.42, -0.58, 0.70));
            float3 eye = float3(0.0, 0.0, 1.0);
            float3 between = normalize(sun + eye);
            float gloss = pow(max(dot(normal, between), 0.0), 42.0);
            // **顔料のあるところだけ光る。** 水そのものは映さない
            float wet = clamp(thick * 2.4, 0.0, 1.0);
            colour += values.sheen * gloss * wet;

            return float4(colour, 1.0);
        }
        """
}
