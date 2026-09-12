import mokume
import simd

/// この作品で使ってよい色。
///
/// **濃さを作るのは光であって、色ではない。** 影は塗った色ではなく、向きを持つ光が
/// 遮られた結果として出る — だから色数は要らない。地・床・塊・朱の 4 つだけ持つ。
enum Palette {
    /// 地。床の外側に見える色。
    static let paper = LinearRGBA.display(red: 0.953, green: 0.945, blue: 0.925)
    /// 床。**光を受ける面**なので、塗りは明るく、暗さは影が作る。
    static let ground = LinearRGBA.display(red: 0.988, green: 0.984, blue: 0.976)
    /// 塊。**地に沈める** — 読めるのは影であって、塊ではない。
    ///
    /// 塗りは頂点ごとに置くので、0…255 の並びで持つ (``Cast/form(_:)``)。
    static let mass = SIMD3<Float>(222, 220, 216)
    /// 朱。**揃ったことを名乗る色**。手引きと計器にだけ使う。
    static let red = LinearRGBA.display(red: 0.886, green: 0.278, blue: 0.165)
    /// 墨。計器の字と線。
    static let ink = LinearRGBA.display(red: 0.114, green: 0.110, blue: 0.118)

    /// 置き場所へ渡す「濃さ」。**焼いた形の色はそのまま、薄さだけを掛ける。**
    ///
    /// 作業空間の色はアルファを掛けた形で持っているので、4 つとも同じ率で縮めれば
    /// そのまま薄くなる。**透けていても影は落ちる**ので、これで塊を現したり消したり
    /// しても床の影は動かない。
    static func veil(_ amount: Float) -> LinearRGBA {
        let a = max(0, min(1, amount))
        return LinearRGBA(premultipliedRed: a, green: a, blue: a, alpha: a)
    }

    /// 同じ色を、薄さだけ変えて使う。**別の色を足さずに階調を作る**ための口。
    static func fade(_ color: LinearRGBA, _ amount: some ScalarConvertible) -> LinearRGBA {
        let a = max(0, min(1, amount.asFloat))
        return LinearRGBA(
            premultipliedRed: color.red * a, green: color.green * a, blue: color.blue * a,
            alpha: color.alpha * a)
    }
}
