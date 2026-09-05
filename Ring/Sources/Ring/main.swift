import Foundation
import mokume

// 窓を開いて走らせるのが既定。
//
//   Ring                         虹の輪を出す
//   Ring --render <置き場> <数>   <数> フレーム進めてから 1 枚書き出す
//   Ring --frames <置き場> <数>   <数> フレームを連番で書き出す (動きの証跡を作るため)
//
// **これで 4 作品目、同じものを手で写している。** Grain → Garden → Solids → ここ、と
// 写してきて、作品ごとに違うのは書き出す名前だけ。所見として README に残してある。
//
// **この作品では、書き出した絵はどれも同じになる** — 頂点数はマウスの位置から決まり、
// 窓を持たない書き出しでは `mouseX` が 0 のまま動かないためである。動きの証跡は
// 走らせたスケッチを窓口から撮って作る (README の「検証する」)。
let arguments = Array(CommandLine.arguments.dropFirst())

switch arguments.first {
case "--render", "--frames":
    let isSequence = arguments.first == "--frames"
    let directory = URL(fileURLWithPath: arguments.count > 1 ? arguments[1] : "shots")
    let count = arguments.count > 2 ? Int(arguments[2]) ?? 1 : 1
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let gpu = try RenderDevice()
    let runtime = try SketchRuntime(sketch: Ring(), gpu: gpu)
    if isSequence {
        for frame in 0..<count {
            try runtime.advance()
            let url = directory.appendingPathComponent(String(format: "frame-%04d.png", frame))
            try runtime.target.writePNG(to: url)
        }
        print(directory.path)
    } else {
        for _ in 0..<count { try runtime.advance() }
        let url = directory.appendingPathComponent("ring-\(count).png")
        try runtime.target.writePNG(to: url)
        print(url.path)
    }
default:
    Ring.main()
}
