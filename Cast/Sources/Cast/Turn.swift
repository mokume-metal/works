import Foundation

/// 幕 2 の譜 — **止まりと送りが拍を作る。**
///
/// 12 秒の幕を 4 秒ずつの 3 区間に割り、それぞれ 2.4 秒止まって 1.6 秒で 120 度回る。
/// 3 回で 360 度、つまり**幕の終わりには同じ姿勢へ戻る**ので、次の幕は円から始まる。
///
/// **止まっている時間があることが、この作品の見え方そのもの**である。止まらずに
/// 回し続けると、影が形になる瞬間が通り過ぎてしまい、何を見ればよいのか分からない。
enum Turn {
    /// ひと回りの長さ (秒)。
    static let loop: Float = 12
    /// 姿勢 1 つぶん (秒)。
    static let step: Float = loop / 3
    /// 止まっている時間 (秒)。
    static let hold: Float = 2.4
    /// 送りに掛ける時間 (秒)。
    static let swing: Float = step - hold

    /// 時刻をひと回りへ畳む。
    static func wrap(_ time: Float) -> Float {
        let folded = time.truncatingRemainder(dividingBy: loop)
        return folded < 0 ? folded + loop : folded
    }

    /// その時刻の姿勢 (ラジアン)。**絵はこの角度の関数**である。
    static func angle(at time: Float) -> Float {
        let t = wrap(time)
        let index = Int(t / step)
        let local = t - Float(index) * step
        let progress = local <= hold ? 0 : ease((local - hold) / swing)
        return (Float(index) + progress) * 2 * .pi / 3
    }

    /// 揃い具合 — **角度だけで決まる。**
    ///
    /// いちばん近い姿勢からのずれが `window` を超えると 0 になる。時刻ではなく角度から
    /// 出しているので、**手で回しても譜で回っても同じ角度なら同じ値**が出る。絵を時刻に
    /// 依らせないための決め事でもある。
    static let window: Float = 0.19

    static func settled(at angle: Float) -> Float {
        max(0, 1 - abs(nearest(to: angle).offset) / window)
    }

    /// 止まっている姿勢から見た、いまの角度のずれ (ラジアン)。手で回したときに使う。
    static func offset(from angle: Float, to pose: Int) -> Float {
        let target = Float(pose) * 2 * .pi / 3
        var difference = angle - target
        while difference > .pi { difference -= 2 * .pi }
        while difference < -.pi { difference += 2 * .pi }
        return difference
    }

    /// いちばん近い姿勢と、そこからのずれ。
    static func nearest(to angle: Float) -> (pose: Int, offset: Float) {
        var best = (pose: 0, offset: Float.greatestFiniteMagnitude)
        for pose in 0..<3 {
            let difference = offset(from: angle, to: pose)
            if abs(difference) < abs(best.offset) { best = (pose, difference) }
        }
        return best
    }

    /// 送りのイージング。**速く出て、長く効かせて、静かに着く。**
    static func ease(_ t: Float) -> Float {
        let x = min(max(t, 0), 1)
        if x <= 0 { return 0 }
        if x >= 1 { return 1 }
        return x < 0.5
            ? pow(2, 20 * x - 10) / 2
            : (2 - pow(2, -20 * x + 10)) / 2
    }
}
