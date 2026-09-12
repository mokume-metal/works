import mokume

/// この作品で使ってよい色。**4 色しかない。**
///
/// 16 秒のあいだに 5 つの場面を渡り歩くので、色まで場面ごとに変えると「同じ 1 本」に
/// 見えなくなる。地・墨・朱・藍だけで全部を描き、場面の違いは**動きと間**で出す。
enum Palette {
    /// 地。紙のような生成り。
    static let paper = LinearRGBA.display(red: 0.937, green: 0.922, blue: 0.882)
    /// 墨。文字と罫の色。
    static let ink = LinearRGBA.display(red: 0.086, green: 0.086, blue: 0.102)
    /// 朱。**拍を名乗る色** — 打点・再生位置・いま動いているものに使う。
    static let red = LinearRGBA.display(red: 0.886, green: 0.278, blue: 0.165)
    /// 藍。墨の相手。奥行きと裏面に使う。
    static let blue = LinearRGBA.display(red: 0.169, green: 0.298, blue: 0.494)

    /// 同じ色を、薄さだけ変えて使う。**別の色を足さずに階調を作る**ための口。
    ///
    /// 作業空間の色はアルファを掛けた形で持っているので、4 つとも同じ率で縮めれば
    /// そのまま薄くなる (色みは動かない)。
    static func fade(_ color: LinearRGBA, _ amount: some ScalarConvertible) -> LinearRGBA {
        let a = max(0, min(1, amount.asFloat))
        return LinearRGBA(
            premultipliedRed: color.red * a, green: color.green * a, blue: color.blue * a,
            alpha: color.alpha * a)
    }
}
