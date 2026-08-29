import Foundation
import mokume

// 窓を開いて走らせるのが既定。`--render <置き場> [フレーム番号]` を付けると
// 1 枚だけ書き出す。**同じフレーム番号からは同じ絵が出る**ので、証跡を撮るのにも
// 「変えたつもりのないところが変わっていない」の確認にも使う。
let arguments = Array(CommandLine.arguments.dropFirst())

if arguments.first == "--render" {
    let directory = URL(fileURLWithPath: arguments.count > 1 ? arguments[1] : "shots")
    let frames = arguments.count > 2 ? Int(arguments[2]) ?? 1 : 1
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let gpu = try RenderDevice()
    let runtime = try SketchRuntime(sketch: Grain(), gpu: gpu)
    for _ in 0..<frames { try runtime.advance() }
    let url = directory.appendingPathComponent("grain-\(frames).png")
    try runtime.target.writePNG(to: url)
    print(url.path)
} else {
    Grain.main()
}
