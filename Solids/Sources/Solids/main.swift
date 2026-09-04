import Foundation
import mokume

// 窓を開いて走らせるのが既定。
//
//   Solids                         立体の並びを出す
//   Solids --render <置き場> <数>   <数> フレーム進めてから 1 枚書き出す
//   Solids --frames <置き場> <数>   <数> フレームを連番で書き出す (動きの証跡を作るため)
//
// **これで 3 作品目、同じものを手で写している。** Grain が書いたものを Garden が
// 写し、Garden が書いたものをここが写した。作品ごとに違うのは書き出す名前だけで、
// 残りは 1 文字も変わらない — 所見として README に残してある。
let arguments = Array(CommandLine.arguments.dropFirst())

switch arguments.first {
case "--render", "--frames":
    let isSequence = arguments.first == "--frames"
    let directory = URL(fileURLWithPath: arguments.count > 1 ? arguments[1] : "shots")
    let count = arguments.count > 2 ? Int(arguments[2]) ?? 1 : 1
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let gpu = try RenderDevice()
    let runtime = try SketchRuntime(sketch: Solids(), gpu: gpu)
    if isSequence {
        for frame in 0..<count {
            try runtime.advance()
            let url = directory.appendingPathComponent(String(format: "frame-%04d.png", frame))
            try runtime.target.writePNG(to: url)
        }
        print(directory.path)
    } else {
        for _ in 0..<count { try runtime.advance() }
        let url = directory.appendingPathComponent("solids-\(count).png")
        try runtime.target.writePNG(to: url)
        print(url.path)
    }
default:
    Solids.main()
}
