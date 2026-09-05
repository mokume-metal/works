import Foundation
import mokume

/// Processing の [Load File 2](https://processing.org/examples/loadfile2/) を 1 行ずつ移したもの。
///
/// **台帳は `out-of-scope` と言った (ファイル入出力が主題)。絵は出る。**
/// 止まるのは 3 つ — `loadFont("...vlw")` (**書体ファイルを読む口が無い**)、
/// `noLoop()` / `redraw()`、`mousePressed()`
/// ([#723](https://github.com/mokume-metal/mokume/issues/723))。押して次の 9 件へ
/// 送る、という主題が移せないので、最初の 9 件が出たまま止まる。
///
/// **字形は環境で変わる**ので、原典と画素では比べられない。
final class LoadFile2: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Load File 2")

    /// 原典の `class Record`。
    struct Record {
        let name: String
        let mpg: Float, displacement: Float, horsepower: Float
        let weight: Float, acceleration: Float, origin: Float
        let cylinders: Int, year: Int

        init(_ pieces: [String]) {
            name = pieces[0]
            mpg = Float(pieces[1]) ?? 0
            cylinders = Int(pieces[2]) ?? 0
            displacement = Float(pieces[3]) ?? 0
            horsepower = Float(pieces[4]) ?? 0
            weight = Float(pieces[5]) ?? 0
            acceleration = Float(pieces[6]) ?? 0
            year = Int(pieces[7]) ?? 0
            origin = Float(pieces[8]) ?? 0
        }
    }

    private var records: [Record] = []
    private let num = 9          // 1 画面に出す件数
    private var startingEntry = 0

    func setup() {
        fill(gray(255))
        // 原典はここで `noLoop()` を呼ぶ。**書けない**
        // 原典は `loadFont("TheSans-Plain-12.vlw")`。**書体ファイルを読む口が無い**
        textFont("Menlo")
        textSize(20)
        let path = asset("Topics/File IO/LoadFile2", "cars2.tsv")
        let lines = ((try? String(contentsOfFile: path, encoding: .utf8)) ?? "")
            .split(separator: "\n", omittingEmptySubsequences: false)
        records = lines.compactMap {
            let pieces = $0.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            return pieces.count == 9 ? Record(pieces) : nil
        }
    }

    func draw() {
        background(gray(0))
        for i in 0..<num {
            let thisEntry = startingEntry + i
            if thisEntry < records.count {
                text("\(thisEntry) > \(records[thisEntry].name)", 20, 20 + Float(i) * 20)
            }
        }
    }

    // 原典はここに `void mousePressed()` を持ち、次の 9 件へ送って `redraw()` する。
    // **どちらの口も無い**
}
