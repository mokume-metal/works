import Foundation
import mokume

/// Processing の [Load Save JSON](https://processing.org/examples/loadsavejson/) を 1 行ずつ移したもの。
///
/// **台帳は `out-of-scope` と言った (データ構造が主題)。絵は出る。**
/// `JSONObject` の一式は Foundation の `JSONSerialization` で当たる (`host`)。
/// 止まるのは `mousePressed()` の口が無いところ
/// ([#723](https://github.com/mokume-metal/mokume/issues/723))。押して足して
/// 書き戻す、という往復が移せないので、読んだところで止まる。
final class LoadSaveJSON: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Load Save JSON")

    final class Bubble {
        let x: Float, y: Float, diameter: Float, name: String
        var over = false

        init(_ x: Float, _ y: Float, _ diameter: Float, _ s: String) {
            self.x = x; self.y = y; self.diameter = diameter; name = s
        }

        func rollover(_ px: Float, _ py: Float) {
            over = dist(px, py, x, y) < diameter / 2
        }

        func display(on sketch: any Sketch) {
            sketch.stroke(0)
            sketch.strokeWeight(2)
            sketch.noFill()
            sketch.ellipse(x, y, diameter, diameter)
            if over {
                sketch.fill(0)
                sketch.textAlign(.center)
                sketch.text(name, x, y + diameter / 2 + 20)
            }
        }
    }

    private var bubbles: [Bubble] = []

    func setup() {
        loadData()
    }

    func draw() {
        background(255)
        for b in bubbles {
            b.display(on: self)
            b.rollover(mouseX, mouseY)
        }
        textAlign(.left)
        fill(0)
        text("Click to add bubbles.", 10, height - 10)
    }

    private func loadData() {
        // 原典は `loadJSONObject("data.json")`。**読む口は無いが Foundation で書ける**
        let path = asset("Topics/Advanced Data/LoadSaveJSON", "data.json")
        guard let data = FileManager.default.contents(atPath: path),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let bubbleData = json["bubbles"] as? [[String: Any]]
        else { return }
        bubbles = bubbleData.compactMap { bubble in
            guard let position = bubble["position"] as? [String: Any],
                  let x = position["x"] as? NSNumber, let y = position["y"] as? NSNumber,
                  let diameter = bubble["diameter"] as? NSNumber,
                  let label = bubble["label"] as? String
            else { return nil }
            return Bubble(x.floatValue, y.floatValue, diameter.floatValue, label)
        }
    }

    // 原典はここに `void mousePressed()` を持ち、押した場所を JSON へ足して書き戻す。
    // **受ける口が無い**
}
