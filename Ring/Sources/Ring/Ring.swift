import mokume

/// Triangle Strip — p5.js の例を mokume へ移した虹の輪。
///
/// <https://p5js.org/examples/Angles-And-Motion-Triangle-Strip/>
///
/// **作り替えず、1 行ずつ写している。** Garden・Solids と同じ流儀で、これは作品で
/// あると同時に物差しである — Garden が測ったのは 2D の入門語彙、Solids が測ったのは
/// 立体の語彙で、**頂点を自分で並べて形を作る経路は 1 度も通っていなかった**。原典は
/// 二重の円の上に頂点を交互に置いて帯にし、頂点ごとに色を変えるだけなので、
/// 頂点列の対応を測るには理想の形をしている。
///
/// 面 720x400・背景 0・内半径 100 / 外半径 150・頂点数は `map(mouseX, 0, width, 6, 60)` を
/// 丸めたもの・角度の刻みは `180 / pointCount` 度、まで原典どおり。
///
/// **`v0.6.0` で、原典と違うところが 4 つから 1 つになった。** 帯 (`.triangleStrip`)・
/// 色相で作る色 (`color(hue:saturation:brightness:)`)・`map` / `radians` がまとめて
/// 面に入ったためで、書く側で埋めていた 3 つはこの版で畳んだ (詳細は README)。
/// 残る 1 つは、原典の `translate(-centerX, -centerY)` を**置かない**こと — あれは
/// WEBGL の中央原点を左上へ戻す 1 行で、mokume の原点は初めから左上である
/// (Solids では逆に 1 行増えた)。
final class Ring: Sketch {
    var settings = SketchSettings(width: 720, height: 400, title: "ring")

    /// 原典の `insideRadius` / `outsideRadius`。
    private static let insideRadius: Float = 100
    private static let outsideRadius: Float = 150

    func draw() {
        // 原典の `background(0)`
        background(0)

        let centerX = width / 2
        let centerY = height / 2

        // 原典の `let pointCount = round(map(mouseX, 0, width, 6, 60))`。
        // 原典と同じく範囲は締めない (mokume の `map` も締めない)
        let pointCount = Int(map(mouseX, 0, width, 6, 60).rounded())

        // 原典の `label.html(...)`。**DOM を持たないので観測へ差し出す** —
        // 撮った絵と同じ応答に載るので、絵とこの数字が食い違わない
        expose("pointCount", pointCount)

        // 原典の `beginShape(TRIANGLE_STRIP)` … `endShape()`。
        //
        // **塗りは頂点ごとに残る。** `fill()` を `vertex()` の間で切り替えると、
        // 置いた時点の色がその頂点に持たれる (`BuildingVertex.fill`)。原典の虹は
        // これがそのまま当たった。
        //
        // 色は原典の `colorMode(HSB)` + `fill(angle, 255, 255)` に当たる。
        // **彩度と明度は 255 ではなく 100 を渡す** — p5 は `colorMode(HSB)` の上限を
        // 100 に採るので原典の `255` は丸められるが、**mokume は丸めず、上へ
        // 突き抜けたぶんを色域の外の色として保つ**。同じ数を渡すと違う絵が出るので、
        // 原典で実際に効いている値のほうを書く。
        // **色相は巻き戻る**ので、角度が最後の数点で 360 度を越えても書き足すことは無い
        beginShape(.triangleStrip)
        var angle: Float = 0
        let angleStep = 180 / Float(pointCount)

        for _ in 0...pointCount {
            // 外側の円の上に 1 点
            fill(color(hue: angle, saturation: 100, brightness: 100))
            vertex(
                centerX + cos(radians(angle)) * Self.outsideRadius,
                centerY + sin(radians(angle)) * Self.outsideRadius)
            angle += angleStep

            // 内側の円の上に 1 点
            fill(color(hue: angle, saturation: 100, brightness: 100))
            vertex(
                centerX + cos(radians(angle)) * Self.insideRadius,
                centerY + sin(radians(angle)) * Self.insideRadius)
            angle += angleStep
        }
        endShape()
    }
}
