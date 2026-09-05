import mokume

/// Processing の [Game of Life](https://processing.org/examples/gameoflife/) を 1 行ずつ移したもの。
///
/// **台帳は `blocked` と言った。半分だけ — 絵は出る。** 止まるのは 2 つ:
/// `noSmooth()` (均しを切る口が無い) と `keyPressed()`
/// ([#723](https://github.com/mokume-metal/mokume/issues/723))。
/// キーで「やり直す・止める・消す」の 3 つを操るところが丸ごと落ちる。
///
/// 乱数で初期の生死を決めるので **画素では比べられない。**
final class GameOfLife: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Game of Life")

    private let cellSize = 5
    private let probabilityOfAliveAtStart: Float = 15
    private var alive = LinearRGBA.transparent
    private var dead = LinearRGBA.transparent
    private var cells: [[Int]] = []
    private var cellsBuffer: [[Int]] = []

    private var cols: Int { Int(width) / cellSize }
    private var rows: Int { Int(height) / cellSize }

    func setup() {
        alive = color(0, 200, 0)
        dead = color(0)
        // 背景の格子を描く線
        stroke(48)
        // 原典はここで `noSmooth()` を呼ぶ。**書けない**

        cells = (0..<cols).map { _ in
            (0..<rows).map { _ in random(100) > probabilityOfAliveAtStart ? 0 : 1 }
        }
        cellsBuffer = cells

        // 升目が面を覆いきらないときのために黒で埋める
        background(0)
    }

    func draw() {
        // 格子を描く
        for x in 0..<cols {
            for y in 0..<rows {
                fill(cells[x][y] == 1 ? alive : dead)
                rect(Float(x * cellSize), Float(y * cellSize), Float(cellSize), Float(cellSize))
            }
        }

        cellsBuffer = cells

        // 升目ごとに、まわりの 8 つを数える
        for x in 0..<cols {
            for y in 0..<rows {
                var neighbours = 0
                for xx in (x - 1)...(x + 1) {
                    for yy in (y - 1)...(y + 1) {
                        guard xx >= 0, xx < cols, yy >= 0, yy < rows else { continue }
                        guard !(xx == x && yy == y) else { continue }
                        if cellsBuffer[xx][yy] == 1 { neighbours += 1 }
                    }
                }
                if cellsBuffer[x][y] == 1 {
                    // 生きている升目。2 つか 3 つでなければ死ぬ
                    if neighbours < 2 || neighbours > 3 { cells[x][y] = 0 }
                } else {
                    // 死んでいる升目。3 つのときだけ生まれる
                    if neighbours == 3 { cells[x][y] = 1 }
                }
            }
        }
    }

    // 原典はここに `void keyPressed()` を持ち、r で作り直し・空白で止め・c で消す。
    // **受ける口が無い**
}
