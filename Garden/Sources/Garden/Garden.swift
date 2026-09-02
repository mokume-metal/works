import Foundation
import mokume

/// Data Structure Garden — p5.js のチュートリアルを mokume へ移した庭。
///
/// <https://p5js.org/tutorials/data-structure-garden/>
///
/// **作り替えず、1 行ずつ写している。** これは作品であると同時に物差しで、
/// 「p5 の語彙のどこに mokume の対応物が無いか」を測るために原典の見た目・数値・
/// 振る舞いを保っている (面 400x400・lightblue の背景・初期 20 本・クリックで 1 本・
/// 毎フレーム `size *= 0.99` と `lifespan -= 1`)。対応表は README にある。
///
/// 原典との違いは 3 つだけで、どれも mokume 側の事情から出たもの:
///
/// 1. 押下の立ち上がりを自分で持つ (`mousePressed()` に当たる口が無い)
/// 2. 抜くのは描き終えてからまとめて (反復しながら配列を縮められない)
/// 3. 咲いている数を出す 1 行を足した (配列が伸び縮みしていることを絵の上で見るため)
final class Garden: Sketch {
    var settings = SketchSettings(width: 400, height: 400, title: "garden")

    /// 咲いている花。原典の `let flowers = [];` に当たる。
    ///
    /// 原典はこれをファイル先頭の global に置く。mokume では**スケッチの持ち物**に
    /// なる — 描画 API がスケッチのメソッドとして生えているので、状態も同じ所へ
    /// 置くのが自然な形になる。
    private var flowers: [Flower] = []

    /// 前のフレームで押されていたか。
    ///
    /// **原典の `mousePressed()` に当たる口が mokume に無い。** 読めるのは
    /// 「いま押されているか」(`isMousePressed`) だけなので、押した瞬間は
    /// 前のフレームとの差から自分で作る。持たずに `isMousePressed` だけで足すと、
    /// 押しっぱなしの間じゅう毎フレーム 1 本ずつ増える。
    private var wasMousePressed = false

    /// 原典の `background("lightblue")`。
    ///
    /// **mokume に名前で引ける色が無い**ので、CSS の lightblue (#ADD8E6) を書き下す。
    private static let lightBlue = LinearRGBA.display(
        red: 173 / 255, green: 216 / 255, blue: 230 / 255)

    /// 花の中心。原典の `fill(255, 204, 0)`。
    private static let heart = LinearRGBA.display(red: 1, green: 204 / 255, blue: 0)

    func setup() {
        flowerPower()
    }

    func draw() {
        background(Self.lightBlue)
        plantOnPress()
        // 数を先に取る。`updateAndDrawFlowers()` は描き終えてから散ったものを抜くので、
        // 抜いた後の数を出すと**絵に写っている本数と札が食い違う**
        let showing = flowers.count
        updateAndDrawFlowers()
        drawCount(showing)
    }

    // MARK: - 原典の関数

    /// 原典の `createFlower()` — でたらめな 1 本を作って返す。
    ///
    /// 原典が `random(20, 380)` と書いているところを面の大きさから出しているのは、
    /// 面を広げたときに花が縁へ寄らないようにするため。数値としては同じである。
    private func createFlower() -> Flower {
        Flower(
            x: random(20, width - 20),
            y: random(20, height - 20),
            size: random(20, 75),
            lifespan: random(255, 300),
            // 原典は `color(random(255), random(255), random(255))`。
            // mokume の色は 0…1 なので 255 で割る
            color: .display(
                red: random(255) / 255,
                green: random(255) / 255,
                blue: random(255) / 255))
    }

    /// 原典の `flowerPower()` — 20 本を配列へ入れる。
    private func flowerPower() {
        for _ in 0..<20 {
            let flower = createFlower()
            flowers.append(flower)
        }
    }

    /// 原典の `drawFlower(flower)` — 直交する 2 つの楕円が花びら、真ん中に丸。
    ///
    /// `ellipseMode` の既定は mokume も p5 も中心なので、座標の読み方は変わらない。
    private func drawFlower(_ flower: Flower) {
        noStroke()
        fill(flower.color)
        ellipse(flower.x, flower.y, flower.size / 2, flower.size)
        ellipse(flower.x, flower.y, flower.size, flower.size / 2)
        fill(Self.heart)
        circle(flower.x, flower.y, flower.size / 2)
    }

    /// 原典の `updateAndDrawFlowers()` — 描いて、縮めて、寿命が尽きたものを抜く。
    ///
    /// **抜くのは描き終えてからまとめて行う。** 原典は反復しながら `splice` するが、
    /// Swift の配列は反復の最中に縮められない。`removeAll(where:)` は 1 度の走査で
    /// 済むので、原典の `indexOf` + `splice` (毎回の探索) より速くもある。
    private func updateAndDrawFlowers() {
        for index in flowers.indices {
            drawFlower(flowers[index])
            flowers[index].size *= 0.99
            flowers[index].lifespan -= 1
        }
        flowers.removeAll { $0.lifespan <= 0 }
    }

    /// 原典の `mousePressed()` — 押した場所へ 1 本足す。
    ///
    /// 出来事として呼ばれる口が無いので、`draw()` の頭で立ち上がりを見る。
    private func plantOnPress() {
        let isDown = isMousePressed
        defer { wasMousePressed = isDown }
        guard isDown, !wasMousePressed else { return }

        var flower = createFlower()
        flower.x = mouseX
        flower.y = mouseY
        flowers.append(flower)
    }

    // MARK: - 原典に無いもの

    /// 咲いている数。
    ///
    /// 配列が伸びて縮んでいることは、絵だけを見ていても分からない。原典も途中の段では
    /// `text()` で中身を出しているので、その最後の 1 行を残した格好になる。
    private func drawCount(_ showing: Int) {
        noStroke()
        fill(.display(red: 0.13, green: 0.24, blue: 0.33))
        textSize(15)
        text("flowers \(showing) — click to plant", 12, 26)
    }
}
