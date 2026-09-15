import mokume
import simd

/// 顔料。**持っているのは色ではなく吸収係数である。**
///
/// 絵の具が混ざると暗くなるのは、顔料が光を足すのではなく**引く**からである。濃度 `c` の
/// 顔料を通った光は Lambert–Beer で `exp(-σc)` になり、重なれば指数が足し算になる —
/// **混ぜる計算は掛け算**で、`mix` でも加算でもない。藍と臙脂を重ねると紫になり、
/// どれだけ重ねても白へ飛ばないのはそのためである。
///
/// 係数は「濃度 1 のとき、線形 RGB の各成分をどれだけ吸うか」。実際の顔料の反射率を
/// 測ったものではなく、**濃度 1 で狙いの色が出る**ように置いた 4 組である。
enum Pigment: Int, CaseIterable {
    /// 墨。**わずかに青を残す** — 青墨の冷たい黒はここから出る。
    case sumi = 0
    /// 藍。赤を強く、緑をほどほどに吸う。
    case indigo
    /// 臙脂。緑と青を吸う。
    case crimson
    /// 藤黄。青だけを吸う。
    case gamboge

    /// 濃度 1 あたりの吸収係数 (線形 RGB)。
    var absorption: SIMD3<Float> {
        switch self {
        case .sumi: SIMD3(2.85, 2.90, 2.60)
        case .indigo: SIMD3(3.60, 2.60, 1.00)
        case .crimson: SIMD3(0.90, 3.20, 2.70)
        case .gamboge: SIMD3(0.55, 1.45, 3.10)
        }
    }

    /// 断片へ渡す形。**色ではないので `linear` で渡す** — 表示の色として解釈させない。
    var shaderValue: ShaderValue {
        .color(.linear(red: absorption.x, green: absorption.y, blue: absorption.z))
    }

    /// 観測に出す名前。
    var label: String {
        switch self {
        case .sumi: "sumi"
        case .indigo: "indigo"
        case .crimson: "crimson"
        case .gamboge: "gamboge"
        }
    }

    /// 次の顔料 (キーを押さずに落とし続けたときの順番)。
    var next: Pigment { Pigment(rawValue: (rawValue + 1) % Pigment.allCases.count) ?? .sumi }
}

/// 落とす滴。**顔料の格子のマスで数える。**
struct Drop {
    /// 落とすところ (顔料の格子のマス)。
    var place: SIMD2<Float>
    /// 半径 (顔料の格子のマス)。
    var radius: Float
    /// どの顔料か。
    var pigment: Pigment
    /// 中心での濃度。
    var amount: Float

    /// 計算へ渡す 8 つの数。**1 滴 = 8 つ**で詰める。
    var packed: [Float] {
        [place.x, place.y, radius, Float(pigment.rawValue), amount, 0, 0, 0]
    }

    /// 1 滴ぶんの数の個数。
    static let stride = 8
    /// 1 フレームに置ける滴の数。
    static let capacity = 8
}

/// 水を押す手。**速度の格子のマスで数える。**
///
/// 速度へ足す力で、**顔料には触らない** — 顔料は流れに運ばれるだけである。
struct Push {
    /// 押すところ (速度の格子のマス)。
    var place: SIMD2<Float>
    /// 押す向きと速さ (速度の格子のマス毎秒)。
    var toward: SIMD2<Float>
    /// 効く半径 (速度の格子のマス)。
    var radius: Float
    /// 強さの倍率。
    var strength: Float

    /// 計算へ渡す 8 つの数。
    var packed: [Float] {
        [place.x, place.y, toward.x, toward.y, radius, strength, 0, 0]
    }

    /// 1 押しぶんの数の個数。
    static let stride = 8
    /// 1 フレームに積める押しの数。**擦った跡は線分に沿って何個かに分けて置く**ので、
    /// 1 回の動きで 1 個ではない。
    static let capacity = 16
}

/// 墨流しのつまみ。**数はここに集める** — 断片の中に散らすと、触りながら直せない。
enum Ink {
    /// 起動時の輪の間隔 (顔料の格子のマス)。
    static let ringSpacing: Float = 38
    /// 輪を置く範囲 (同じくマス)。
    static let ringReach: Float = 690
    /// 輪の濃さ。
    static let ringStrength: Float = 1.15

    /// 落とす滴の半径 (顔料の格子のマス)。
    static let dropRadius: Float = 52
    /// 落とす滴の濃さ。
    static let dropAmount: Float = 1.2

    /// 濃度の上限。**これ以上濃くしても、もう光は残っていない。**
    static let ceiling: Float = 4.5

    /// 撫でる手の半径 (速度の格子のマス)。
    static let handRadius: Float = 5.5
    /// 手の速さを、水を押す速さへ写す倍率。
    static let handGain: Float = 7
    /// ドラッグで梳くときの上乗せ。
    static let combGain: Float = 1.7
}
