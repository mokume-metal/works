import Foundation

/// 決定論的な揺らぎ。
///
/// **mokume の公開面に乱数もノイズも無いので、ここで書いている。** シードから同じ
/// 値が出ることだけは必ず守る — 木目は毎フレーム作り直さないが、作り直したときに
/// 別の板になっては困る。
enum Noise {
    /// 整数 3 つを混ぜて 0…1 を返す。
    ///
    /// 掛ける定数は奇数の大きな素数で、上位ビットへ繰り上がりを送ってから
    /// 折り返している。値の質より**同じ入力から同じ値が出ること**を優先する。
    static func hash(_ x: Int32, _ y: Int32, _ seed: Int32) -> Float {
        var h = UInt32(bitPattern: x) &* 0x8da6_b343
        h = h &+ UInt32(bitPattern: y) &* 0xd8163_841 % 0xffff_ffff
        h = h &+ UInt32(bitPattern: seed) &* 0xcb1a_b31f
        h ^= h >> 15
        h = h &* 0x2c1b_3c6d
        h ^= h >> 12
        h = h &* 0x297a_2d39
        h ^= h >> 15
        return Float(h & 0x00ff_ffff) / Float(0x0100_0000)
    }

    /// 格子の値を滑らかに繋いだ揺らぎ。
    static func value(_ x: Float, _ y: Float, seed: Int32) -> Float {
        let xi = floorf(x)
        let yi = floorf(y)
        let xf = x - xi
        let yf = y - yi
        // 端で傾きが 0 になる繋ぎ方。折れ目が縞に乗ると木目に見えなくなる
        let u = xf * xf * (3 - 2 * xf)
        let v = yf * yf * (3 - 2 * yf)

        let x0 = Int32(xi)
        let y0 = Int32(yi)
        let a = hash(x0, y0, seed)
        let b = hash(x0 &+ 1, y0, seed)
        let c = hash(x0, y0 &+ 1, seed)
        let d = hash(x0 &+ 1, y0 &+ 1, seed)

        let top = a + (b - a) * u
        let bottom = c + (d - c) * u
        return top + (bottom - top) * v
    }

    /// 倍率を変えて重ねた揺らぎ。木目の歪みはこれ 1 つで作る。
    static func layered(
        _ x: Float, _ y: Float, seed: Int32, octaves: Int = 5, gain: Float = 0.5
    ) -> Float {
        var sum: Float = 0
        var amplitude: Float = 1
        var total: Float = 0
        var frequency: Float = 1
        for octave in 0..<octaves {
            sum += value(x * frequency, y * frequency, seed: seed &+ Int32(octave) &* 101)
                * amplitude
            total += amplitude
            amplitude *= gain
            frequency *= 2
        }
        return sum / total
    }
}
