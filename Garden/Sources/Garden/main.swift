import Foundation
import mokume

// 窓を開いて走らせるのが既定。
//
//   Garden                         庭を出す
//   Garden --render <置き場> <数>   <数> フレーム進めてから 1 枚書き出す
//   Garden --frames <置き場> <数>   <数> フレームを連番で書き出す (動きの証跡を作るため)
//
// **書き出しの口は Grain から写した。** 作品ごとに同じものを手で書いていることは、
// それ自体が所見として README に残してある。
let arguments = Array(CommandLine.arguments.dropFirst())

switch arguments.first {
case "--render", "--frames":
    let isSequence = arguments.first == "--frames"
    let directory = URL(fileURLWithPath: arguments.count > 1 ? arguments[1] : "shots")
    let count = arguments.count > 2 ? Int(arguments[2]) ?? 1 : 1
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let gpu = try RenderDevice()
    let runtime = try SketchRuntime(sketch: Garden(), gpu: gpu)
    if isSequence {
        for frame in 0..<count {
            try runtime.advance()
            let url = directory.appendingPathComponent(String(format: "frame-%04d.png", frame))
            try runtime.target.writePNG(to: url)
        }
        print(directory.path)
    } else {
        for _ in 0..<count { try runtime.advance() }
        let url = directory.appendingPathComponent("garden-\(count).png")
        try runtime.target.writePNG(to: url)
        print(url.path)
    }
default:
    Garden.main()
}
