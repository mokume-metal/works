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
/// 対応表は README にある。原典と違うのは次の 4 つで、どれも mokume 側の事情から出たもの:
///
/// 1. 帯 (`TRIANGLE_STRIP`) の並べ方が無いので、書く側で三角形へ畳む (``fold``)
/// 2. 色相で色を作れないので、色相から表示値を作る式を自分で書く (``Hue``)
/// 3. 角度はラジアン (`angleMode()` が無い)。度で持って渡すときに直す
/// 4. 原典の `translate(-centerX, -centerY)` を**置かない**。あれは WEBGL の中央原点を
///    左上へ戻す 1 行で、mokume の原点は初めから左上である (Solids では逆に 1 行増えた)
final class Ring: Sketch {
    var settings = SketchSettings(width: 720, height: 400, title: "ring")

    /// 原典の `insideRadius` / `outsideRadius`。
    private static let insideRadius: Float = 100
    private static let outsideRadius: Float = 150

    /// 原典の `background(0)`。**数値 1 つの黒は書けない**ので 3 つ書き下す。
    private static let ink = LinearRGBA.display(red: 0, green: 0, blue: 0)

    /// 帯の上に置く頂点 1 つぶん。
    ///
    /// **原典は置くそばから `vertex()` を呼ぶが、こちらは一度溜める。** 帯を三角形へ
    /// 畳むとき、同じ頂点が最大 3 つの三角形に現れるためで、そのたびに位置と色を
    /// 作り直さないための控えである (``fold``)。
    private struct Point {
        var x: Float
        var y: Float
        var fill: LinearRGBA
    }

    func draw() {
        // 原典の `background(0)`
        background(Self.ink)

        let centerX = width / 2
        let centerY = height / 2

        // 原典の `let pointCount = round(map(mouseX, 0, width, 6, 60))`。
        // **`map()` が無い**ので割って掛ける。原典と同じく範囲は締めない
        let pointCount = Int((6 + (mouseX / width) * (60 - 6)).rounded())

        // 原典の `label.html(...)`。**DOM を持たないので観測へ差し出す** —
        // 撮った絵と同じ応答に載るので、絵とこの数字が食い違わない
        expose("pointCount", pointCount)

        // 原典の `beginShape(TRIANGLE_STRIP)` … `endShape()`。
        // 帯の並べ方が無いので、頂点を溜めてから三角形へ畳む
        var strip: [Point] = []
        var angle: Float = 0
        let angleStep = 180 / Float(pointCount)

        for _ in 0...pointCount {
            // 外側の円の上に 1 点
            strip.append(
                Point(
                    x: centerX + cos(Self.radians(angle)) * Self.outsideRadius,
                    y: centerY + sin(Self.radians(angle)) * Self.outsideRadius,
                    fill: Hue.color(angle)))
            angle += angleStep

            // 内側の円の上に 1 点
            strip.append(
                Point(
                    x: centerX + cos(Self.radians(angle)) * Self.insideRadius,
                    y: centerY + sin(Self.radians(angle)) * Self.insideRadius,
                    fill: Hue.color(angle)))
            angle += angleStep
        }

        fold(strip)
    }

    /// 帯を三角形へ畳んで置く。
    ///
    /// 帯は「3 つ目からは 1 つ前の 2 点を使い回す」約束なので、`i` 番目の三角形は
    /// `(i, i+1, i+2)` になる。mokume の ``VertexKind`` に帯が無い以上、この
    /// 使い回しは書く側が行う — **頂点は 2n から 3(n-2) へ増える** (60 点なら 118 → 174)。
    private func fold(_ strip: [Point]) {
        guard strip.count >= 3 else { return }

        // **塗りは頂点ごとに残る。** `fill()` を `vertex()` の間で切り替えると、
        // 置いた時点の色がその頂点に持たれる (`BuildingVertex.fill`)。原典の虹は
        // これがそのまま当たった
        beginShape(.triangles)
        for i in 0..<(strip.count - 2) {
            for point in [strip[i], strip[i + 1], strip[i + 2]] {
                fill(point.fill)
                vertex(point.x, point.y)
            }
        }
        endShape()
    }

    /// 原典の `angleMode(DEGREES)` の代わり。**単位を直す口が無い**ので自分で書く。
    private static func radians(_ degrees: Float) -> Float { degrees * .pi / 180 }
}
