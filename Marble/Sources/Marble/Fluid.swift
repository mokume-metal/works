import Foundation
import mokume
import simd

/// 水盤の中の流れ。**全部 GPU の計算 (`compute`) で解く。**
///
/// Stam の Stable Fluids をそのまま置いてある。1 フレームは **32 回の計算**で、順に
/// **速度を運ぶ (`carry`) → 押す (`spin` / `swirl`) → 発散を消す (`spread` / `press` ×24 /
/// `settle`) → 顔料を運ぶ (`carryInk` / `carryBack` / `carryFix`)**。3 段目が非圧縮の条件
/// (`∇·v = 0`) で、これがあるから流れは**伸ばして畳むだけ**になり、水が湧いたり消えたり
/// しない。滴を落としたフレームだけ `soak` が 1 つ増える。
///
/// **待ち合わせは 1 行も書いていない。** `compute` へ渡す `reads` / `writes` が束ねる先で
/// あると同時に依存の宣言でもあるので、順序は宣言から導かれる。
///
/// ## 格子は 2 段にしてある
///
/// | 場 | 格子 | 1 マス |
/// | --- | --- | --- |
/// | 速度・圧力・発散・渦度 | 320 × 180 | 画面の 6 × 6 画素 |
/// | 顔料 | 1920 × 1080 | 画面の 1 画素 |
///
/// **圧力を解くのは粗くてよいが、顔料は細かくないと筋が潰れる。** 圧力は場の全体へ
/// 効く滑らかな量で、Jacobi を 24 回回すのに細かい格子は要らない。一方で墨流しの
/// 見どころは**髪の毛ほどの筋**なので、顔料には**画素と同じ細かさ**を与えてある
/// (36 倍のマス数)。渦の芯で灰色に潰れる範囲が目に見えて狭まるのはこの差である。
///
/// ## 顔料は MacCormack で運ぶ
///
/// 素の semi-Lagrangian (1 回汲むだけ) は**数値拡散**でみるみる灰色になる。運んだ先を
/// もう一度戻して (`carryBack`)、ずれたぶんを引いて補正する (`carryFix`) と、同じ格子の
/// ままで筋が数分保つ。**混ざるのに濁らない**のはこの 3 段があるからである。
final class Fluid {
    /// 速度の格子。
    static let flowColumns = 320
    static let flowRows = 180
    /// 顔料の格子。
    static let inkColumns = 1920
    static let inkRows = 1080
    /// 顔料の格子が速度の格子の何倍細かいか。
    static let refine: Float = Float(inkColumns) / Float(flowColumns)
    /// 圧力を解く回数。
    static let sweeps = 24

    /// 速度 (マス毎秒)。**ping-pong するので入れ替わる。**
    private var velocity: Numbers
    private var velocityNext: Numbers
    /// 渦度と発散。どちらも 1 マス 1 つ。
    private let curl: Numbers
    private let divergence: Numbers
    /// 圧力。**前のフレームの答えから解き始める** (暖かい出発点)。
    private var pressure: Numbers
    private var pressureNext: Numbers
    /// 顔料 (4 つの濃度)。`aid` と `back` は MacCormack の途中の場。
    private var ink: Numbers
    private var inkAid: Numbers
    private let inkBack: Numbers
    /// 手の跡と滴。**CPU が毎フレーム書き、計算が読む。**
    private let hand: Numbers
    private let drops: Numbers

    private let carry: Computation
    private let spin: Computation
    private let swirl: Computation
    private let spread: Computation
    private let press: Computation
    private let settle: Computation
    private let carryInk: Computation
    private let carryBack: Computation
    private let carryFix: Computation
    private let soak: Computation
    private let sow: Computation

    /// 次のフレームで同心円を置き直すか。**計算は `draw()` の中でしか効かない**ので、
    /// キーを押した時点では走らせられない。
    private var wantsSeed = true
    /// 凪いでいるか。**止めたら、触るまでは息も吹かない** — 息が残っていると
    /// 「止めた」はずの水がまた動き出し、止まったことを確かめられない。
    private var becalmed = false

    /// 塗りが読む顔料の場。
    var pigment: Numbers { ink }

    init?(on sketch: some Sketch) {
        let flowCells = Fluid.flowColumns * Fluid.flowRows
        let inkCells = Fluid.inkColumns * Fluid.inkRows
        guard let velocity = try? sketch.makeNumbers(count: flowCells * 2),
            let velocityNext = try? sketch.makeNumbers(count: flowCells * 2),
            let curl = try? sketch.makeNumbers(count: flowCells),
            let divergence = try? sketch.makeNumbers(count: flowCells),
            let pressure = try? sketch.makeNumbers(count: flowCells),
            let pressureNext = try? sketch.makeNumbers(count: flowCells),
            let ink = try? sketch.makeNumbers(count: inkCells * 4),
            let inkAid = try? sketch.makeNumbers(count: inkCells * 4),
            let inkBack = try? sketch.makeNumbers(count: inkCells * 4),
            let hand = try? sketch.makeNumbers(count: Push.capacity * Push.stride),
            let drops = try? sketch.makeNumbers(count: Drop.capacity * Drop.stride)
        else {
            Fluid.complain("場を確保できない")
            return nil
        }
        for field in [velocity, velocityNext, curl, divergence, pressure, pressureNext] {
            field.fill(0)
        }
        for field in [ink, inkAid, inkBack, hand, drops] { field.fill(0) }

        let flow: ShaderValue = .pair(Float(Fluid.flowColumns), Float(Fluid.flowRows))
        let grid: ShaderValue = .pair(Float(Fluid.inkColumns), Float(Fluid.inkRows))

        guard
            let carry = Fluid.build(sketch, "carry", Fluid.carrySource, ["flow": flow, "step": 0]),
            let spin = Fluid.build(sketch, "spin", Fluid.spinSource, ["flow": flow]),
            let swirl = Fluid.build(
                sketch, "swirl", Fluid.swirlSource,
                [
                    "flow": flow, "step": 0, "confine": 0, "drag": 0, "hands": 0, "breath": 0,
                    "clock": 0, "limit": 0,
                ]),
            let spread = Fluid.build(sketch, "spread", Fluid.spreadSource, ["flow": flow]),
            let press = Fluid.build(sketch, "press", Fluid.pressSource, ["flow": flow]),
            let settle = Fluid.build(sketch, "settle", Fluid.settleSource, ["flow": flow]),
            let carryInk = Fluid.build(
                sketch, "carryInk", Fluid.carryInkSource,
                ["flow": flow, "grid": grid, "step": 0, "refine": .number(Fluid.refine)]),
            let carryBack = Fluid.build(
                sketch, "carryBack", Fluid.carryBackSource,
                ["flow": flow, "grid": grid, "step": 0, "refine": .number(Fluid.refine)]),
            let carryFix = Fluid.build(
                sketch, "carryFix", Fluid.carryFixSource,
                ["flow": flow, "grid": grid, "step": 0, "refine": .number(Fluid.refine)]),
            let soak = Fluid.build(
                sketch, "soak", Fluid.soakSource, ["grid": grid, "falling": 0, "ceiling": 0]),
            let sow = Fluid.build(
                sketch, "sow", Fluid.sowSource,
                ["grid": grid, "spacing": 0, "reach": 0, "strength": 0])
        else { return nil }

        self.velocity = velocity
        self.velocityNext = velocityNext
        self.curl = curl
        self.divergence = divergence
        self.pressure = pressure
        self.pressureNext = pressureNext
        self.ink = ink
        self.inkAid = inkAid
        self.inkBack = inkBack
        self.hand = hand
        self.drops = drops
        self.carry = carry
        self.spin = spin
        self.swirl = swirl
        self.spread = spread
        self.press = press
        self.settle = settle
        self.carryInk = carryInk
        self.carryBack = carryBack
        self.carryFix = carryFix
        self.soak = soak
        self.sow = sow
    }

    // MARK: - 進める

    /// 1 フレームぶん進める。**`draw()` の中からだけ呼ぶ** (計算はそこでしか効かない)。
    func step(
        on sketch: some Sketch, dt: Float, now: Float, pushes: [Push], falling: [Drop]
    ) {
        if wantsSeed {
            wantsSeed = false
            sow.set("spacing", .number(Ink.ringSpacing))
            sow.set("reach", .number(Ink.ringReach))
            sow.set("strength", .number(Ink.ringStrength))
            sketch.compute(sow, over: Fluid.inkColumns, by: Fluid.inkRows, writes: [ink])
        }

        upload(pushes, into: hand, capacity: Push.capacity, stride: Push.stride) { $0.packed }
        upload(falling, into: drops, capacity: Drop.capacity, stride: Drop.stride) { $0.packed }

        // 1. 速度が速度を運ぶ
        carry.set("step", .number(dt))
        sketch.compute(
            carry, over: Fluid.flowColumns, by: Fluid.flowRows,
            reads: [velocity], writes: [velocityNext])
        swap(&velocity, &velocityNext)

        // 2. 渦度を測って、細い渦を保つ。手の跡と息もここで足す
        sketch.compute(
            spin, over: Fluid.flowColumns, by: Fluid.flowRows,
            reads: [velocity], writes: [curl])
        swirl.set("step", .number(dt))
        swirl.set("confine", .number(Fluid.confinement))
        swirl.set("drag", .number(Fluid.drag))
        swirl.set("hands", .number(Float(min(pushes.count, Push.capacity))))
        if !pushes.isEmpty || !falling.isEmpty { becalmed = false }
        swirl.set("breath", .number(becalmed ? 0 : Fluid.breath))
        swirl.set("clock", .number(now))
        swirl.set("limit", .number(Fluid.limit))
        sketch.compute(
            swirl, over: Fluid.flowColumns, by: Fluid.flowRows,
            reads: [curl, hand], writes: [velocity])

        // 3. 発散を消す (非圧縮)。**ここが「水」である**
        sketch.compute(
            spread, over: Fluid.flowColumns, by: Fluid.flowRows,
            reads: [velocity], writes: [divergence])
        for _ in 0..<Fluid.sweeps {
            sketch.compute(
                press, over: Fluid.flowColumns, by: Fluid.flowRows,
                reads: [divergence, pressure], writes: [pressureNext])
            swap(&pressure, &pressureNext)
        }
        sketch.compute(
            settle, over: Fluid.flowColumns, by: Fluid.flowRows,
            reads: [pressure], writes: [velocity])

        // 4. 顔料を運ぶ (MacCormack — 行って・戻って・直す)
        for computation in [carryInk, carryBack, carryFix] { computation.set("step", .number(dt)) }
        sketch.compute(
            carryInk, over: Fluid.inkColumns, by: Fluid.inkRows,
            reads: [velocity, ink], writes: [inkAid])
        sketch.compute(
            carryBack, over: Fluid.inkColumns, by: Fluid.inkRows,
            reads: [velocity, inkAid], writes: [inkBack])
        sketch.compute(
            carryFix, over: Fluid.inkColumns, by: Fluid.inkRows,
            reads: [velocity, ink, inkBack], writes: [inkAid])
        swap(&ink, &inkAid)

        // 5. 落とした滴を置く。**周りを押しのけるので、もう 1 度入れ替える**
        if !falling.isEmpty {
            soak.set("falling", .number(Float(min(falling.count, Drop.capacity))))
            soak.set("ceiling", .number(Ink.ceiling))
            sketch.compute(
                soak, over: Fluid.inkColumns, by: Fluid.inkRows,
                reads: [drops, ink], writes: [inkAid])
            swap(&ink, &inkAid)
        }
    }

    /// 水を止める。**絵は残る** — 速度だけを 0 にする。
    func calm() {
        becalmed = true
        velocity.fill(0)
        velocityNext.fill(0)
        pressure.fill(0)
        pressureNext.fill(0)
    }

    /// 起動時の同心円へ戻す。
    func rewind() {
        calm()
        becalmed = false
        wantsSeed = true
    }

    // MARK: - 渡す

    private func upload<Item>(
        _ items: [Item], into field: Numbers, capacity: Int, stride: Int,
        _ pack: (Item) -> [Float]
    ) {
        var packed = [Float](repeating: 0, count: capacity * stride)
        for (index, item) in items.prefix(capacity).enumerated() {
            let numbers = pack(item)
            for (offset, value) in numbers.enumerated() { packed[index * stride + offset] = value }
        }
        field.set(packed)
    }

    // MARK: - つまみ

    /// 渦度確信の強さ。**細い渦が潰れないように足し戻す量**である。
    static let confinement: Float = 0.9
    /// 抵抗 (毎秒)。手を止めればゆっくり凪ぐ。
    static let drag: Float = 0.5
    /// 息。**手を触れなくても水は完全には止まっていない。**
    static let breath: Float = 0.35
    /// 速さの上限 (マス毎秒)。速すぎる流れは絵が飛ぶ。
    static let limit: Float = 110

    // MARK: - 組み立て

    private static func build(
        _ sketch: some Sketch, _ name: String, _ body: String, _ values: [String: ShaderValue]
    ) -> Computation? {
        do {
            return try sketch.makeComputation(common + body, name: name, values: values)
        } catch {
            complain("\(name) を組み立てられない — \(error)")
            return nil
        }
    }

    private static func complain(_ message: String) {
        FileHandle.standardError.write(Data("marble: \(message)\n".utf8))
    }

    /// どの計算にも前置きする部分。**マスの中心は (i+0.5, j+0.5)** で、塗りの側と揃えてある。
    private static let common = """
        static inline uint mk_cell(int2 cell, int2 size) {
            int2 held = clamp(cell, int2(0), size - 1);
            return uint(held.y) * uint(size.x) + uint(held.x);
        }

        /// 速度を双一次で汲む (位置は速度の格子のマス)。
        static inline float2 mk_speed(device const float *vel, int2 size, float2 p) {
            float2 q = clamp(p - 0.5, float2(0.0), float2(size) - 1.0);
            int2 base = int2(floor(q));
            float2 t = q - float2(base);
            uint a = mk_cell(base, size) * 2u;
            uint b = mk_cell(base + int2(1, 0), size) * 2u;
            uint c = mk_cell(base + int2(0, 1), size) * 2u;
            uint d = mk_cell(base + int2(1, 1), size) * 2u;
            float2 top = mix(float2(vel[a], vel[a + 1u]), float2(vel[b], vel[b + 1u]), t.x);
            float2 low = mix(float2(vel[c], vel[c + 1u]), float2(vel[d], vel[d + 1u]), t.x);
            return mix(top, low, t.y);
        }

        static inline float4 mk_load(device const float *ink, uint at) {
            return float4(ink[at], ink[at + 1u], ink[at + 2u], ink[at + 3u]);
        }

        static inline void mk_store(device float *ink, uint at, float4 value) {
            ink[at] = value.x; ink[at + 1u] = value.y;
            ink[at + 2u] = value.z; ink[at + 3u] = value.w;
        }

        /// 顔料を双一次で汲む (位置は顔料の格子のマス)。
        static inline float4 mk_ink(device const float *ink, int2 size, float2 p) {
            float2 q = clamp(p - 0.5, float2(0.0), float2(size) - 1.0);
            int2 base = int2(floor(q));
            float2 t = q - float2(base);
            float4 a = mk_load(ink, mk_cell(base, size) * 4u);
            float4 b = mk_load(ink, mk_cell(base + int2(1, 0), size) * 4u);
            float4 c = mk_load(ink, mk_cell(base + int2(0, 1), size) * 4u);
            float4 d = mk_load(ink, mk_cell(base + int2(1, 1), size) * 4u);
            return mix(mix(a, b, t.x), mix(c, d, t.x), t.y);
        }

        /// 汲んだ 4 マスの上下限。**補正がはみ出さないための箍**である。
        static inline void mk_range(
            device const float *ink, int2 size, float2 p,
            thread float4 &low, thread float4 &high)
        {
            float2 q = clamp(p - 0.5, float2(0.0), float2(size) - 1.0);
            int2 base = int2(floor(q));
            float4 a = mk_load(ink, mk_cell(base, size) * 4u);
            float4 b = mk_load(ink, mk_cell(base + int2(1, 0), size) * 4u);
            float4 c = mk_load(ink, mk_cell(base + int2(0, 1), size) * 4u);
            float4 d = mk_load(ink, mk_cell(base + int2(1, 1), size) * 4u);
            low = min(min(a, b), min(c, d));
            high = max(max(a, b), max(c, d));
        }

        /// 顔料の位置から、1 フレーム前にそれが居たところ。
        ///
        /// **速度の格子は 3 倍粗い**ので、汲むときに割り、進むときに掛ける。
        static inline float2 mk_trace(
            device const float *vel, int2 flow, float2 p, float refine, float step, float way)
        {
            float2 v = mk_speed(vel, flow, p / refine);
            return p + way * v * refine * step;
        }

        """

    private static let carrySource = """
        kernel void carry(device const float *vel [[buffer(0)]],
                          device float *next [[buffer(1)]],
                          constant Values &values [[buffer(MOKUME_VALUES)]],
                          uint2 at [[thread_position_in_grid]])
        {
            int2 size = int2(values.flow);
            if (int(at.x) >= size.x || int(at.y) >= size.y) { return; }
            float2 p = float2(at) + 0.5;
            float2 v = mk_speed(vel, size, p);
            float2 came = mk_speed(vel, size, p - v * values.step);
            uint i = mk_cell(int2(at), size) * 2u;
            next[i] = came.x;
            next[i + 1u] = came.y;
        }
        """

    private static let spinSource = """
        kernel void spin(device const float *vel [[buffer(0)]],
                         device float *curl [[buffer(1)]],
                         constant Values &values [[buffer(MOKUME_VALUES)]],
                         uint2 at [[thread_position_in_grid]])
        {
            int2 size = int2(values.flow);
            if (int(at.x) >= size.x || int(at.y) >= size.y) { return; }
            int2 c = int2(at);
            uint r = mk_cell(c + int2(1, 0), size) * 2u;
            uint l = mk_cell(c - int2(1, 0), size) * 2u;
            uint u = mk_cell(c + int2(0, 1), size) * 2u;
            uint d = mk_cell(c - int2(0, 1), size) * 2u;
            // 渦度 ω = ∂v/∂x − ∂u/∂y
            curl[mk_cell(c, size)] = 0.5 * ((vel[r + 1u] - vel[l + 1u]) - (vel[u] - vel[d]));
        }
        """

    private static let swirlSource = """
        kernel void swirl(device const float *curl [[buffer(0)]],
                          device const float *hand [[buffer(1)]],
                          device float *vel [[buffer(2)]],
                          constant Values &values [[buffer(MOKUME_VALUES)]],
                          uint2 at [[thread_position_in_grid]])
        {
            int2 size = int2(values.flow);
            if (int(at.x) >= size.x || int(at.y) >= size.y) { return; }
            int2 c = int2(at);
            uint i = mk_cell(c, size);
            float2 v = float2(vel[i * 2u], vel[i * 2u + 1u]);
            float2 p = float2(c) + 0.5;
            float step = values.step;

            // 渦度確信 — 渦の強いほうへ向けて、渦を巻く向きに足し戻す。
            // **格子が粗いと渦は数フレームで潰れる**ので、潰れたぶんを返している
            float2 lean = 0.5 * float2(
                abs(curl[mk_cell(c + int2(1, 0), size)]) - abs(curl[mk_cell(c - int2(1, 0), size)]),
                abs(curl[mk_cell(c + int2(0, 1), size)]) - abs(curl[mk_cell(c - int2(0, 1), size)]));
            float slope = length(lean);
            if (slope > 1e-5) {
                float2 n = lean / slope;
                v += values.confine * float2(n.y, -n.x) * curl[i] * step;
            }

            // 息 — 流れ関数 ψ の回転として足すので、**足しても発散しない**
            if (values.breath > 0.0) {
                float2 q = p / float2(size);
                float t = values.clock;
                float sx = sin(q.x * 2.1 + t * 0.045);
                float cx = cos(q.x * 2.1 + t * 0.045);
                float sy = sin(q.y * 1.7 - t * 0.037);
                float cy = cos(q.y * 1.7 - t * 0.037);
                float diagonal = cos((q.x + q.y) * 2.9 + t * 0.021);
                float2 turn = float2(-1.7 * sx * sy + 1.45 * diagonal,
                                     -(2.1 * cx * cy + 1.45 * diagonal));
                v += values.breath * turn * step;
            }

            // 手。**動いた向きへ、動いた速さで押す**
            int hands = int(values.hands);
            for (int k = 0; k < hands; ++k) {
                int b = k * 8;
                float2 place = float2(hand[b], hand[b + 1]);
                float2 toward = float2(hand[b + 2], hand[b + 3]);
                float radius = max(hand[b + 4], 1e-3);
                float strength = hand[b + 5];
                float2 away = p - place;
                float reach = dot(away, away) / (radius * radius);
                if (reach > 7.0) { continue; }
                v += toward * strength * exp(-reach);
            }

            v *= exp(-values.drag * step);
            float speed = length(v);
            if (speed > values.limit) { v *= values.limit / speed; }

            // 水盤の縁。**通り抜けない** (滑りはする)
            if (c.x == 0 || c.x == size.x - 1) { v.x = 0.0; }
            if (c.y == 0 || c.y == size.y - 1) { v.y = 0.0; }

            vel[i * 2u] = v.x;
            vel[i * 2u + 1u] = v.y;
        }
        """

    /// 発散を測る。
    ///
    /// **前向きの差分で測る。** 中央差分 (`(u[i+1] − u[i−1]) / 2`) と 5 点の Laplacian を
    /// 組み合わせると、**偶数マスと奇数マスが互いに相手を見なくなる** — 発散と勾配が
    /// 2 マス幅の飛び石で組まれるのに、圧力だけ 1 マス幅で解かれるからである。分かれた
    /// 2 枚の格子はそれぞれ勝手な圧力を持てるので、市松の圧力が消えずに残り、絵には
    /// **筋に沿った山形のギザギザ**として出る (最初の版が実際にそうなった)。
    ///
    /// 発散を前向き・勾配を後ろ向きに取ると、合成した作用素がちょうど 5 点の Laplacian に
    /// 一致する。**速度を半マスずらして置いたのと同じ**ことで、市松は起きない。
    private static let spreadSource = """
        kernel void spread(device const float *vel [[buffer(0)]],
                           device float *out [[buffer(1)]],
                           constant Values &values [[buffer(MOKUME_VALUES)]],
                           uint2 at [[thread_position_in_grid]])
        {
            int2 size = int2(values.flow);
            if (int(at.x) >= size.x || int(at.y) >= size.y) { return; }
            int2 c = int2(at);
            uint here = mk_cell(c, size) * 2u;
            uint r = mk_cell(c + int2(1, 0), size) * 2u;
            uint u = mk_cell(c + int2(0, 1), size) * 2u;
            out[mk_cell(c, size)] = (vel[r] - vel[here]) + (vel[u + 1u] - vel[here + 1u]);
        }
        """

    private static let pressSource = """
        kernel void press(device const float *divergence [[buffer(0)]],
                          device const float *pressure [[buffer(1)]],
                          device float *next [[buffer(2)]],
                          constant Values &values [[buffer(MOKUME_VALUES)]],
                          uint2 at [[thread_position_in_grid]])
        {
            int2 size = int2(values.flow);
            if (int(at.x) >= size.x || int(at.y) >= size.y) { return; }
            int2 c = int2(at);
            // 縁は Neumann (∂p/∂n = 0)。mk_cell が外を内へ畳むので、そのまま効く
            float sum = pressure[mk_cell(c + int2(1, 0), size)]
                      + pressure[mk_cell(c - int2(1, 0), size)]
                      + pressure[mk_cell(c + int2(0, 1), size)]
                      + pressure[mk_cell(c - int2(0, 1), size)];
            uint i = mk_cell(c, size);
            next[i] = (sum - divergence[i]) * 0.25;
        }
        """

    private static let settleSource = """
        kernel void settle(device const float *pressure [[buffer(0)]],
                           device float *vel [[buffer(1)]],
                           constant Values &values [[buffer(MOKUME_VALUES)]],
                           uint2 at [[thread_position_in_grid]])
        {
            int2 size = int2(values.flow);
            if (int(at.x) >= size.x || int(at.y) >= size.y) { return; }
            int2 c = int2(at);
            uint i = mk_cell(c, size);
            float2 v = float2(vel[i * 2u], vel[i * 2u + 1u]);
            // **後ろ向きの差分で引く。** 発散を前向きに測っているので、こちらを
            // 後ろ向きにして初めて 5 点の Laplacian と噛み合う (``spreadSource``)
            float here = pressure[i];
            v -= float2(
                here - pressure[mk_cell(c - int2(1, 0), size)],
                here - pressure[mk_cell(c - int2(0, 1), size)]);
            if (c.x == 0 || c.x == size.x - 1) { v.x = 0.0; }
            if (c.y == 0 || c.y == size.y - 1) { v.y = 0.0; }
            vel[i * 2u] = v.x;
            vel[i * 2u + 1u] = v.y;
        }
        """

    private static let carryInkSource = """
        kernel void carryInk(device const float *vel [[buffer(0)]],
                             device const float *ink [[buffer(1)]],
                             device float *next [[buffer(2)]],
                             constant Values &values [[buffer(MOKUME_VALUES)]],
                             uint2 at [[thread_position_in_grid]])
        {
            int2 size = int2(values.grid);
            if (int(at.x) >= size.x || int(at.y) >= size.y) { return; }
            float2 p = float2(at) + 0.5;
            float2 came = mk_trace(vel, int2(values.flow), p, values.refine, values.step, -1.0);
            mk_store(next, mk_cell(int2(at), size) * 4u, mk_ink(ink, size, came));
        }
        """

    private static let carryBackSource = """
        kernel void carryBack(device const float *vel [[buffer(0)]],
                              device const float *ink [[buffer(1)]],
                              device float *next [[buffer(2)]],
                              constant Values &values [[buffer(MOKUME_VALUES)]],
                              uint2 at [[thread_position_in_grid]])
        {
            int2 size = int2(values.grid);
            if (int(at.x) >= size.x || int(at.y) >= size.y) { return; }
            float2 p = float2(at) + 0.5;
            // **時間を逆へ回す。** 行って戻れば元の場に重なるはずで、重ならない差が誤差である
            float2 gone = mk_trace(vel, int2(values.flow), p, values.refine, values.step, 1.0);
            mk_store(next, mk_cell(int2(at), size) * 4u, mk_ink(ink, size, gone));
        }
        """

    private static let carryFixSource = """
        kernel void carryFix(device const float *vel [[buffer(0)]],
                             device const float *ink [[buffer(1)]],
                             device const float *back [[buffer(2)]],
                             device float *next [[buffer(3)]],
                             constant Values &values [[buffer(MOKUME_VALUES)]],
                             uint2 at [[thread_position_in_grid]])
        {
            int2 size = int2(values.grid);
            if (int(at.x) >= size.x || int(at.y) >= size.y) { return; }
            float2 p = float2(at) + 0.5;
            float2 came = mk_trace(vel, int2(values.flow), p, values.refine, values.step, -1.0);
            float4 here = mk_ink(ink, size, came);
            float4 returned = mk_ink(back, size, came);
            // 行って戻ったときの誤差の半分を、先回りして引いておく
            float4 fixed = here + 0.5 * (here - returned);
            // **汲んだ 4 マスの外へは出さない。** 箍が無いと、筋の縁に負の濃度と
            // 白い縁取りが出る
            float4 low; float4 high;
            mk_range(ink, size, came, low, high);
            fixed = clamp(fixed, low, high);
            mk_store(next, mk_cell(int2(at), size) * 4u, max(fixed, float4(0.0)));
        }
        """

    /// 滴を落とす。
    ///
    /// **滴は水を押しのける。** 落ちた滴は水面に場所を作り、そのぶん周りの膜を外へ
    /// 押し出す — 同じところへ続けて落とすと同心円になるのは、前の滴が押し出されて
    /// 輪になるからである。墨流しの輪は「輪を描いたもの」ではなく**押しのけの跡**である。
    ///
    /// 押しのけは `r → √(r² + R²)` の逆写像で作る。**この写像は面積を保つ**
    /// (`d(r'²)/d(r²) = 1`) ので、膜が伸び縮みせずに外へずれるだけになる。
    ///
    /// **速度へ外向きの力を足す形ではできない。** 放射状の速度は発散そのもので、
    /// 非圧縮の射影 (`press` / `settle`) が次の段で丸ごと消してしまう。滴が押しのける
    /// のは 2 次元の膜の中の場所であって、水の湧き出しではない。
    private static let soakSource = """
        kernel void soak(device const float *drops [[buffer(0)]],
                         device const float *ink [[buffer(1)]],
                         device float *next [[buffer(2)]],
                         constant Values &values [[buffer(MOKUME_VALUES)]],
                         uint2 at [[thread_position_in_grid]])
        {
            int2 size = int2(values.grid);
            if (int(at.x) >= size.x || int(at.y) >= size.y) { return; }
            float2 p = float2(at) + 0.5;
            int falling = int(values.falling);

            // 押しのけを後の滴から順に解いて、この画素の顔料が**元はどこに居たか**を辿る
            float2 q = p;
            for (int k = falling - 1; k >= 0; --k) {
                int b = k * 8;
                float2 place = float2(drops[b], drops[b + 1]);
                float radius = max(drops[b + 2], 1e-3);
                float2 away = q - place;
                float r = length(away);
                if (r < 1e-4) { continue; }
                float came = sqrt(max(r * r - radius * radius, 0.0));
                q = place + away * (came / r);
            }
            float4 c = mk_ink(ink, size, q);

            // 滴そのもの。**下にあったものは押し出されているので残らない**
            for (int k = 0; k < falling; ++k) {
                int b = k * 8;
                float2 place = float2(drops[b], drops[b + 1]);
                float radius = max(drops[b + 2], 1e-3);
                int which = int(drops[b + 3]);
                float amount = drops[b + 4];
                float inside = 1.0 - smoothstep(0.86, 1.0, length(p - place) / radius);
                if (inside <= 0.0) { continue; }
                c *= 1.0 - inside;
                float fall = amount * inside;
                c += float4(which == 0 ? fall : 0.0, which == 1 ? fall : 0.0,
                            which == 2 ? fall : 0.0, which == 3 ? fall : 0.0);
            }
            mk_store(next, mk_cell(int2(at), size) * 4u, min(c, float4(values.ceiling)));
        }
        """

    private static let sowSource = """
        kernel void sow(device float *ink [[buffer(0)]],
                        constant Values &values [[buffer(MOKUME_VALUES)]],
                        uint2 at [[thread_position_in_grid]])
        {
            int2 size = int2(values.grid);
            if (int(at.x) >= size.x || int(at.y) >= size.y) { return; }
            float2 p = float2(at) + 0.5;
            float2 away = p - float2(size) * 0.5;
            float r = length(away);
            float a = atan2(away.y, away.x);
            // **輪は真円ではない。** 落ちた滴が押しのけ合った跡なので、少しいびつになる。
            // 位相を半径でゆっくり回してあるので、**隣の輪とは違う形に歪む** — 位相を
            // 揃えると全部が同じ形の相似形になり、手で落としたものに見えない
            float twist = r * 0.009;
            float wobble = 1.0 + 0.050 * sin(a * 5.0 + 1.3 + twist)
                         + 0.032 * sin(a * 9.0 - 0.7 - twist * 1.7)
                         + 0.020 * sin(a * 2.0 + 2.1 + twist * 0.6);
            float held = r / wobble;
            float band = held / values.spacing;
            int ring = int(floor(band));
            float inside = fract(band);
            // 太さも輪ごとに変える。**濃い輪と細い輪が混ざる**と、手で落としたものに近づく
            float weight = 0.62 + 0.38 * sin(float(ring) * 2.399 + 0.8);
            float edge = smoothstep(0.0, 0.07, inside)
                       * (1.0 - smoothstep(0.16 + 0.10 * weight, 0.26 + 0.12 * weight, inside));
            float fade = 1.0 - smoothstep(values.reach * 0.72, values.reach, held);
            float amount = values.strength * edge * fade * (0.70 + 0.45 * weight);
            // 墨を 1 本おきに挟む。**濃い筋の間に色が来る**ので、混ざったときに色が濁らない
            int turn = ring % 6;
            int which = (turn % 2 == 0) ? 0 : (turn / 2 + 1);
            mk_store(ink, mk_cell(int2(at), size) * 4u,
                     float4(which == 0 ? amount : 0.0, which == 1 ? amount : 0.0,
                            which == 2 ? amount : 0.0, which == 3 ? amount : 0.0));
        }
        """
}
