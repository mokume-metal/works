import Foundation
import mokume

// 窓を開いて走らせるのが既定。
//
//   Grain                         板の面を出す
//   Grain slab                    板を立体にして回す (未完成 — Slab.swift を読む)
//   Grain --render <置き場> <数>   1 枚だけ書き出す
//   Grain --frames <置き場> <数>   連番で書き出す (動きの証跡を作るため)
//
// **同じフレーム番号からは同じ絵が出る**ので、書き出しは証跡にも
// 「変えたつもりのないところが変わっていない」の確認にも使う。
let arguments = Array(CommandLine.arguments.dropFirst())

func makeSketch(_ name: String?) -> any Sketch {
    name == "slab" ? Slab() : Grain()
}

switch arguments.first {
case "--render", "--frames":
    let isSequence = arguments.first == "--frames"
    let directory = URL(fileURLWithPath: arguments.count > 1 ? arguments[1] : "shots")
    let count = arguments.count > 2 ? Int(arguments[2]) ?? 1 : 1
    let sketch = makeSketch(arguments.count > 3 ? arguments[3] : nil)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let gpu = try RenderDevice()
    let runtime = try SketchRuntime(sketch: sketch, gpu: gpu)
    if isSequence {
        for frame in 0..<count {
            try runtime.advance()
            let url = directory.appendingPathComponent(String(format: "frame-%04d.png", frame))
            try runtime.target.writePNG(to: url)
        }
        print(directory.path)
    } else {
        for _ in 0..<count { try runtime.advance() }
        let url = directory.appendingPathComponent("grain-\(count).png")
        try runtime.target.writePNG(to: url)
        print(url.path)
    }
default:
    if arguments.first == "slab" {
        Slab.main()
    } else {
        Grain.main()
    }
}
