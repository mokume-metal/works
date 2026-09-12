import Foundation

/// 地形 — ノイズから高さ場を作り、層に分けて木を生やす。
///
/// **ノイズは外から渡す。** mokume の `noise()` はスケッチの口なので、ここで呼ぶと
/// 地形が描画へ結び付いてしまう。高さ場を作る規則だけをここに置き、値の出どころは
/// `Quarry` が渡す — おかげで**同じ種からは必ず同じ世界が立つ**。
///
/// ## 層は 4 つしかない
///
/// 地表の 1 段が草 (または砂・石)、その下 3 段が土、それより下が石。**穴を掘ると
/// 断面にこの順が出る**ので、掘った深さが色で分かる。
///
/// ## 水は「足りないところを埋める」
///
/// 水位より低い空気を後から水で埋める。高さ場に谷があれば勝手に湖になり、**掘って
/// 水位より下へ抜けば、そこは水にならない** (掘るのは地形を作った後なので) — 穴は
/// 乾いたままで、水の縁だけが残る
enum Terrain {
    /// 水位 (段)。
    static let seaLevel = 24
    /// 地表のいちばん低いところ。
    static let floor = 12
    /// 高さの振れ幅 (段)。
    static let swing = 38
    /// ここより高い地表は草を載せず石が出る (段)。
    static let bareAbove = 42

    /// 世界を立てる。
    static func raise(_ world: World, noise: (Float, Float) -> Float) {
        let span = World.span
        var heights = [Int](repeating: 0, count: span * span)

        // 1. 高さ場。**4 オクターブ** — 1 枚だとなだらかすぎて、掘る手応えの出る崖が出ない
        for z in 0..<span {
            for x in 0..<span {
                var sum: Float = 0
                var amplitude: Float = 1
                var frequency: Float = 0.014
                var total: Float = 0
                for _ in 0..<4 {
                    sum += noise(Float(x) * frequency, Float(z) * frequency) * amplitude
                    total += amplitude
                    frequency *= 2.1
                    amplitude *= 0.5
                }
                // **ノイズの山を広げてから均す。**
                //
                // Perlin を 4 枚重ねると値が真ん中へ寄る (0.4…0.6 にほとんどが入る)。
                // そのまま高さへ写すと**世界じゅうが水位の前後**になり、最初に立てた
                // ときは地表の半分が砂浜だった。2.4 倍に開いてから smoothstep で均すと、
                // 湖のある低地・歩ける平地・掘り甲斐のある岩山が同じ世界に並ぶ
                let spread = min(max((sum / total - 0.5) * 2.4 + 0.5, 0), 1)
                let shaped = spread * spread * (3 - 2 * spread)
                heights[z * span + x] = floor + Int(shaped * Float(swing))
            }
        }

        // 2. 層に分ける
        for z in 0..<span {
            for x in 0..<span {
                let top = heights[z * span + x]
                for y in 0...top {
                    let depth = top - y
                    let block: Block =
                        if depth == 0 { crown(at: top) } else if depth <= 3 { .dirt } else { .stone }
                    world.plant(x, y, z, block)
                }
                // 3. 水位まで埋める
                if top < seaLevel {
                    for y in (top + 1)...seaLevel { world.plant(x, y, z, .water) }
                }
            }
        }

        // 4. 木。**8 × 8 ブロックに 1 本まで** — 間隔を決めずに確率だけで撒くと束になる
        let cell = 8
        for cz in 0..<(span / cell) {
            for cx in 0..<(span / cell) {
                guard chance(cx, cz, salt: 7) > 0.70 else { continue }
                let x = cx * cell + Int(chance(cx, cz, salt: 11) * Float(cell - 2)) + 1
                let z = cz * cell + Int(chance(cx, cz, salt: 13) * Float(cell - 2)) + 1
                let top = heights[z * span + x]
                guard top > seaLevel, top < bareAbove else { continue }
                grow(world, x: x, y: top + 1, z: z, seed: cx * 31 + cz)
            }
        }
    }

    /// 地表の 1 段に何を載せるか。
    private static func crown(at top: Int) -> Block {
        if top <= seaLevel + 1 { return .sand }
        if top >= bareAbove { return .stone }
        return .grass
    }

    /// 木を 1 本。**幹 4〜6 段、葉は上から 4 段。**
    ///
    /// 角を欠くのは Minecraft と同じ理由で、欠かないと葉が立方体に見える
    private static func grow(_ world: World, x: Int, y: Int, z: Int, seed: Int) {
        let trunk = 4 + Int(chance(seed, 0, salt: 17) * 3)
        let crown = y + trunk - 1

        for step in 0..<trunk { world.plant(x, y + step, z, .log) }

        for level in -2...1 {
            let radius = level >= 0 ? 1 : 2
            for dz in -radius...radius {
                for dx in -radius...radius {
                    // 角は落とす。いちばん外の角は必ず、内側の角はたまに
                    let corner = abs(dx) == radius && abs(dz) == radius
                    if corner, radius == 2 { continue }
                    if corner, chance(x + dx, z + dz, salt: 19) > 0.5 { continue }
                    if dx == 0, dz == 0, level < 1 { continue }  // 幹の場所
                    world.plant(x + dx, crown + level, z + dz, .leaves)
                }
            }
        }
    }

    /// 座標から直に引く 0…1。**撒く順に依らない。**
    private static func chance(_ a: Int, _ b: Int, salt: Int) -> Float {
        var h = UInt32(truncatingIfNeeded: a &* 374_761_393)
        h &+= UInt32(truncatingIfNeeded: b &* 668_265_263)
        h &+= UInt32(truncatingIfNeeded: salt &* 1_274_126_177)
        h ^= h >> 13
        h = h &* 1_274_126_177
        h ^= h >> 16
        return Float(h % 65536) / 65535
    }
}
