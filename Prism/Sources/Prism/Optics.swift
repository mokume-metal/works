import simd

/// 幾何光学の式だけを置く。
///
/// **ここは mokume を import しない。** 絵を詰めるたびに触るのは `Trace` と `Beam` の
/// ほうで、この面は一度書けば動かない — 寿命の違うものを分けておくと、色や太さを
/// 直すために屈折の式を読み直さずに済む。
///
/// 縦軸が下向きであることに依存する式は 1 つも無い (法線も向きも与えられたものを
/// そのまま使う) ので、`Trace` が渡す座標系がそのまま通る。
enum Optics {

    // MARK: - 分散

    /// Cauchy の分散式 `n(λ) = A + B/λ²`。**λ はマイクロメートル。**
    ///
    /// 2 項の Cauchy が実測に乗るのは可視域 (400〜700nm) で、それより短いところは
    /// 紫外の吸収端が効いて外れ始める。`Spectrum` が刻む範囲をそこへ切ってあるのは
    /// この式の適用範囲に合わせたためでもある。
    static func refractiveIndex(a: Float, b: Float, wavelength micrometers: Float) -> Float {
        a + b / (micrometers * micrometers)
    }

    // MARK: - 交差

    /// 2 次元の外積 (z 成分だけ)。
    @inline(__always)
    static func cross(_ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Float {
        a.x * b.y - a.y * b.x
    }

    /// 光線 `origin + t * direction` と線分 `a…b` の交差。返すのは進んだ距離 `t`。
    ///
    /// **`t` の下限を呼ぶ側から渡させる。** 面から出発した光線は自分が出た面へ
    /// `t ≈ 0` で当たり直すので、下限が無いと必ずそこで止まる。ただし下限だけでは
    /// 頂点へちょうど当たった光線が漏れるので、`Trace` の側で「直前に当たった辺を
    /// 飛ばす」ことと併せて 2 重に止めている。
    static func intersect(
        origin: SIMD2<Float>, direction: SIMD2<Float>,
        a: SIMD2<Float>, b: SIMD2<Float>, minimumDistance: Float
    ) -> Float? {
        let edge = b - a
        let denominator = cross(direction, edge)
        // 平行 (0 除算)
        if abs(denominator) < 1e-9 { return nil }
        let offset = a - origin
        let distance = cross(offset, edge) / denominator
        if distance <= minimumDistance { return nil }
        // 線分の内側に落ちているか
        let along = cross(offset, direction) / denominator
        if along < 0 || along > 1 { return nil }
        return distance
    }

    // MARK: - 面での分岐

    /// 面に当たった光がどう分かれるか。
    ///
    /// **すべて「進む向き `direction` に対して手前を向く法線」で書いてある。**
    /// 内と外を真偽値で持ち回らないのは、全反射のあとに必ずずれるからである
    /// (中にいるつもりのまま外向きの式を当ててしまう)。向きは毎回 `direction` と
    /// 法線の内積の符号から決め直す。
    struct Interaction {
        /// 反射した向き。**全反射でもここに入る**ので、呼ぶ側は常に使える。
        var reflected: SIMD2<Float>
        /// 屈折した向き。全反射なら `nil`。
        var transmitted: SIMD2<Float>?
        /// 反射率 0…1 (非偏光)。全反射なら 1。
        var reflectance: Float
        /// 入る前と出た後の束の幅の比 `cos θ_out / cos θ_in`。
        ///
        /// **屈折すると束は伸び縮みする。** 幅がこの比で変わり、明るさは逆比で変わる
        /// (力は保たれるので、広がったぶんだけ薄くなる)。全反射では 1。
        var spreadRatio: Float
    }

    /// Snell とフレネルをまとめて解く。
    ///
    /// - Parameters:
    ///   - direction: 正規化された進む向き。
    ///   - normal: 面の法線 (向きは問わない — 中で `direction` の手前側へ揃える)。
    ///   - indexIn: いま進んでいる媒質の屈折率。
    ///   - indexOut: 面の向こう側の屈折率。
    static func interact(
        direction: SIMD2<Float>, normal: SIMD2<Float>,
        indexIn: Float, indexOut: Float
    ) -> Interaction {
        // **手前を向く法線へ揃える。** 内積が正なら法線は進む先を向いているので裏返す
        var facing = normal
        if simd_dot(direction, facing) > 0 { facing = -facing }

        let cosIncidence = -simd_dot(direction, facing)
        let reflected = direction + 2 * cosIncidence * facing

        let eta = indexIn / indexOut
        let k = 1 - eta * eta * (1 - cosIncidence * cosIncidence)
        // 全反射。**反射率は 1 なので、強度の閾値ではこの光は永久に刈れない** —
        // 打ち切りは `Trace` が硝子の吸収と光路長で行う
        if k < 0 {
            return Interaction(
                reflected: reflected, transmitted: nil, reflectance: 1, spreadRatio: 1)
        }

        let cosTransmission = k.squareRoot()
        let transmitted = eta * direction + (eta * cosIncidence - cosTransmission) * facing

        // **フレネルは余弦形で書く。** 正弦・正接の形 (`sin(i−r)/sin(i+r)` など) は
        // 垂直入射で 0/0 になる — ここは光がまっすぐ入る場面なので必ず踏む
        let rs =
            (indexIn * cosIncidence - indexOut * cosTransmission)
            / (indexIn * cosIncidence + indexOut * cosTransmission)
        let rp =
            (indexOut * cosIncidence - indexIn * cosTransmission)
            / (indexOut * cosIncidence + indexIn * cosTransmission)
        let reflectance = (rs * rs + rp * rp) / 2

        return Interaction(
            reflected: reflected, transmitted: simd_normalize(transmitted),
            reflectance: min(max(reflectance, 0), 1),
            spreadRatio: cosTransmission / max(cosIncidence, 1e-4))
    }

    // MARK: - 検算

    /// 頂点角 `apex` の三角プリズムの最小偏角。
    ///
    /// **トレーサの答え合わせに使う。** 光線を追った結果として出てくる曲がり角が、
    /// 独立に立てたこの式と合うなら、交差・法線の向き・Snell のどれもずれていない。
    /// 正三角形 (60 度) で `n = 1.6408` なら 50.3 度になる。
    static func minimumDeviation(apex: Float, index: Float) -> Float {
        2 * asin(index * sin(apex / 2)) - apex
    }
}
