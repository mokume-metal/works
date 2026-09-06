import Foundation
import mokume
import simd

/// 波長を色にする面。
///
/// **ここが持つのは「白色光を何本の単色に割るか」と「その 1 本が何色か」だけ**で、
/// 幾何は一切知らない。刻み方と重みは焼き付けてあるので、毎フレーム作り直すのは
/// 屈折率だけである (分散の強さが手で動くため)。
struct Spectrum {

    /// 1 本の単色光。
    struct Sample {
        /// 波長 (マイクロメートル)。
        var wavelength: Float
        /// この 1 本の色。**線形 Display P3 で、全サンプルの和がちょうど白 (1,1,1)** に
        /// なるよう正規化してある。強度は描く側が掛ける
        var color: SIMD3<Float>
        /// いまの分散でのこの波長の屈折率。
        var index: Float
    }

    /// 刻む本数。**分散が連続に見えるかはここで決まる。**
    ///
    /// 必要な本数は「扇の広がり ÷ 帯の幅」で決まる。この作品は幅 60 画素の帯が
    /// 900 画素先で 200 画素あまりに開くので、隣り合う波長の帯が重なる条件は
    /// おおむね 3 本もあれば足りる — にもかかわらず 160 本にしてあるのは、
    /// **重なりの段が色の段として見えないところまで**寄せるためである。
    static let count = 160

    /// 刻む範囲。**2 項の Cauchy が実測に乗る範囲**であり、かつこの外側は等色関数が
    /// ほぼ 0 なので、広げても色に効かないまま本数を食う。
    static let shortest: Float = 0.400
    static let longest: Float = 0.700

    /// 光源の色温度 (K)。**白色光の中身を表で持たず、Planck 則で作る。**
    static let temperature: Float = 6000

    private(set) var samples: [Sample] = []

    init() {
        samples.reserveCapacity(Self.count)

        // **刻むのは λ ではなく 1/λ²。**
        //
        // 偏角は屈折率にほぼ比例し、屈折率は Cauchy の式そのままで 1/λ² に厳密に
        // 比例する。だから λ を等間隔に刻むと**扇の中では等間隔にならない** —
        // `dn/dλ = −2B/λ³` は 400nm で 700nm の 5.3 倍あるので、赤い側だけ隙間が
        // 開いて縞になる。1/λ² を等間隔に刻めば、扇の中の角度がほぼ等間隔に並ぶ
        let lowest = 1 / (Self.longest * Self.longest)
        let highest = 1 / (Self.shortest * Self.shortest)

        var raw: [SIMD3<Float>] = []
        var total = SIMD3<Float>(repeating: 0)

        for k in 0..<Self.count {
            let t = Float(k) / Float(Self.count - 1)
            let inverseSquare = lowest + (highest - lowest) * t
            let wavelength = 1 / inverseSquare.squareRoot()

            // **帯域の重み (ヤコビアン) を掛ける。** `dλ/du = −λ³/2` なので、
            // 1/λ² で等間隔に取った標本 1 本が代表する波長の幅は λ³ に比例する。
            // 落とすと青が過剰に重くなる
            let bandwidth = wavelength * wavelength * wavelength
            let power = Self.planck(wavelength: wavelength, temperature: Self.temperature)
            let energy = power * bandwidth

            let color = Self.displayP3(fromWavelength: wavelength * 1000) * energy
            raw.append(color)
            total += color
            samples.append(Sample(wavelength: wavelength, color: .zero, index: 1))
        }

        // **正規化は成分ごとに行う。** XYZ から Display P3 への行列は行和が
        // 1.159 / 0.957 / 0.917 と揃っていないので、スカラー 1 つで割ると
        // 分かれていない束がピンクがかった白になる
        for k in 0..<samples.count {
            samples[k].color = raw[k] / simd_max(total, SIMD3(repeating: 1e-6))
        }
    }

    /// 分散の強さを変えて屈折率を焼き直す。
    ///
    /// **色と刻みは動かない。** 動くのは屈折率だけなので、手で分散をいじっても
    /// 割り算 160 回で済む。
    mutating func refresh(cauchyA: Float, cauchyB: Float) {
        for k in 0..<samples.count {
            samples[k].index = Optics.refractiveIndex(
                a: cauchyA, b: cauchyB, wavelength: samples[k].wavelength)
        }
    }

    // MARK: - 分光

    /// Planck の放射則 (相対値)。λ はマイクロメートル。
    ///
    /// `hc/k = 14387.769 µm·K` を使う。**紫の端が自然に暗くなる**ので、標準光の表を
    /// 持たなくても「白色光」が説明のつくものになる。
    private static func planck(wavelength: Float, temperature: Float) -> Float {
        let c2: Float = 14387.769
        let exponent = c2 / (wavelength * temperature)
        return 1 / (pow(wavelength, 5) * (exp(exponent) - 1))
    }

    // MARK: - 等色関数と色空間

    /// 左右で幅の違うガウシアン。等色関数の当てはめに使う形。
    private static func lobe(_ x: Float, _ center: Float, _ left: Float, _ right: Float) -> Float {
        let t = (x - center) / (x < center ? left : right)
        return exp(-0.5 * t * t)
    }

    /// 波長 (ナノメートル) を CIE 1931 の XYZ にする。
    ///
    /// Wyman・Sloan・Shirley "Simple Analytic Approximations to the CIE XYZ Color
    /// Matching Functions" (JCGT 2013) の多ローブ当てはめ。**表を持たずに済む**ので、
    /// 刻む本数を変えても補間の心配が無い。
    private static func colorMatching(_ nanometers: Float) -> SIMD3<Float> {
        let x =
            1.056 * lobe(nanometers, 599.8, 37.9, 31.0)
            + 0.362 * lobe(nanometers, 442.0, 16.0, 26.7)
            - 0.065 * lobe(nanometers, 501.1, 20.4, 26.2)
        let y =
            0.821 * lobe(nanometers, 568.8, 46.9, 40.5)
            + 0.286 * lobe(nanometers, 530.9, 16.3, 31.1)
        let z =
            1.217 * lobe(nanometers, 437.0, 11.8, 36.0)
            + 0.681 * lobe(nanometers, 459.0, 26.0, 13.8)
        return SIMD3(x, y, z)
    }

    /// 波長 (ナノメートル) を線形 Display P3 にする。
    ///
    /// **sRGB ではない。** mokume の作業空間は extended linear Display P3 なので
    /// (`LinearRGBA` / `SketchSurface`)、sRGB の行列で作った値をそのまま渡すと
    /// 広い原色で再生されて過飽和し、色相もずれる。P3 は sRGB よりスペクトル軌跡を
    /// 広く覆うので、**単色光を扱うこの作品では色域の外へ出る量そのものも小さい**。
    private static func displayP3(fromWavelength nanometers: Float) -> SIMD3<Float> {
        let xyz = colorMatching(nanometers)

        // D65 の XYZ → 線形 Display P3
        let r = 2.4934969 * xyz.x - 0.9313836 * xyz.y - 0.4027108 * xyz.z
        let g = -0.8294890 * xyz.x + 1.7626641 * xyz.y + 0.0236247 * xyz.z
        let b = 0.0358458 * xyz.x - 0.0761724 * xyz.y + 0.9568845 * xyz.z
        var rgb = SIMD3<Float>(r, g, b)

        // **色域の外は成分ごとに切らず、中性軸へ寄せる。**
        //
        // 単色光は必ずどれかの成分が負になる (特に 480〜510nm と 400〜430nm)。
        // そこを 0 で切ると色相と明るさの両方が動くが、負のぶんを 3 成分すべてへ
        // 足せば動くのは彩度だけで済む
        let lowest = min(rgb.x, min(rgb.y, rgb.z))
        if lowest < 0 { rgb -= SIMD3(repeating: lowest) }

        // 寄せたぶん明るくなっているので、輝度を元へ戻す。
        // 係数は線形 Display P3 → Y の行
        let luminance = 0.2289746 * rgb.x + 0.6917385 * rgb.y + 0.0792869 * rgb.z
        if luminance > 1e-6 { rgb *= xyz.y / luminance }

        return simd_max(rgb, .zero)
    }
}
