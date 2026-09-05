import Foundation

/// 動きの証跡を撮るときに、**両側へ同じように流すマウスの道すじ**。
///
/// 静止画は「マウスを動かさない」で条件を揃えていたが、それだと**マウスが要る例は
/// 何も描かれない**。動きを見せるには入力が要り、入力を入れるなら原典と mokume で
/// 寸分違わず同じ道すじでなければ、動きの違いなのか入力の違いなのか分からなくなる。
///
/// **だから式で決める。** ここと `scripts/compare/index.html` の `mousePath` は
/// 同じ式で、片方だけ直すと比較が壊れる。
///
/// - 横は面を 1 往復する (余弦)
/// - 縦は 2 往復する (正弦)。斜めに交差する道すじになり、面の広い範囲を通る
/// - **真ん中の 3 分の 1 だけ押す**。押している間と押していない間の両方が 1 本に入る
func mousePath(_ frame: Int, of count: Int, width: Float, height: Float)
    -> (x: Float, y: Float, pressed: Bool) {
    let t = count > 1 ? Float(frame) / Float(count - 1) : 0
    return (
        x: width * (0.5 - 0.42 * cos(2 * .pi * t)),
        y: height * (0.5 + 0.32 * sin(4 * .pi * t)),
        pressed: t >= 1.0 / 3.0 && t < 2.0 / 3.0)
}
