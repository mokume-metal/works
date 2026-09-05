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
/// 原典との違いは 2 つだけ:
///
/// 1. 抜くのは描き終えてからまとめて (Swift では反復しながら配列を縮められない)
/// 2. 咲いている数を出す 1 行を足した (配列が伸び縮みしていることを絵の上で見るため)
///
/// **`v0.6.0` で 1 つ減った。** 押下を出来事として受ける口
/// ([mokume#723](https://github.com/mokume-metal/mokume/issues/723)) が入ったので、
/// 立ち上がりを自分で持つ必要が無くなり、原典と同じ `mousePressed()` が書ける。
final class Garden: Sketch {
    var settings = SketchSettings(width: 400, height: 400, title: "garden")

    /// 咲いている花。原典の `let flowers = [];` に当たる。
    ///
    /// 原典はこれをファイル先頭の global に置く。mokume では**スケッチの持ち物**に
    /// なる — 描画 API がスケッチのメソッドとして生えているので、状態も同じ所へ
    /// 置くのが自然な形になる。
    private var flowers: [Flower] = []

    func setup() {
        flowerPower()
    }

    func draw() {
        // 原典の `background("lightblue")`。**名前で引ける色は無い**ので、
        // CSS の lightblue (#ADD8E6) を数で書き下す
        background(173, 216, 230)
        // 数を先に取る。`updateAndDrawFlowers()` は描き終えてから散ったものを抜くので、
        // 抜いた後の数を出すと**絵に写っている本数と札が食い違う**
        let showing = flowers.count
        updateAndDrawFlowers()
        drawCount(showing)
        // 札と同じ数を観測へも差し出す。**撮った絵と同じ応答に載る**ので、
        // 外からクリックを送って何本植わったかを、絵を読まずに数えられる
        expose("flowers", showing)
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
            // 原典の `color(random(255), random(255), random(255))` がそのまま書ける
            color: color(random(255), random(255), random(255)))
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
        // 原典の `fill(255, 204, 0)`
        fill(255, 204, 0)
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

    /// 原典の `mousePressed()` — 押した場所へ 1 本足す。**綴りも中身も原典と同じ。**
    ///
    /// `Sketch` の要件に既定実装が付いているので、書けばそのまま呼ばれる
    /// (`override` は要らない)。中で読む `mouseX` / `mouseY` は、その押下を
    /// 当てた直後の値になる。
    func mousePressed() {
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
