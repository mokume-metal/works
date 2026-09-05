import mokume

/// Processing の [Loop](https://processing.org/examples/loop/) を 1 行ずつ移したもの。
///
/// **台帳は `blocked` と言った。`v0.6.0` で半分だけ埋まった。**
/// 原典の主題は「`noLoop()` で止め、押したら `loop()` で動かす」ことそのものである。
/// 押す側の口は入ったが ([#723](https://github.com/mokume-metal/mokume/issues/723) — 閉じた)、
/// **止める口も動かす口もまだ無い** ([#900](https://github.com/mokume-metal/mokume/issues/900))。
/// 止まらないので、押す前から線が流れる。
///
/// **これが「段階の違い」の見本である** — 同じ `blocked` でも、口が 1 つ増えれば動く例と、
/// 2 つ揃わないと動かない例がある。押す側だけ書けても、この例の主題は移らない。
///
/// **動くように書き替えていない** — 作ろうとして止まったこと自体が実需である
/// (ADR-0022 決定 4)。`NoLoop` と同じ場所で 2 本目。
final class Loop: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Loop")

    private var y: Float = 180

    func setup() {
        stroke(255)
        // 原典はここで `noLoop()` を呼ぶ。**書けない**
    }

    func draw() {
        background(0)
        line(0, y, width, y)
        y = y - 1
        if y < 0 { y = height }
    }

    /// 原典の `void mousePressed() { loop(); }`。
    ///
    /// **押される側は書けるようになったが、中身が書けない** — 進行を動かす `loop()` が
    /// 無いので、呼ばれても打つ手が 1 つも無い ([#900](https://github.com/mokume-metal/mokume/issues/900))。
    /// 空のまま置いて、口が半分だけ埋まっていることを残す。
    func mousePressed() {
        // 原典はここで `loop()` を呼ぶ。**書けない**
    }
}
