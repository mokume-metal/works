import Foundation
import mokume

// 窓を開いて走らせるのが既定。
//
//   Nebula                         星雲を出す
//   Nebula --render <置き場> <数>   <数> フレーム進めてから 1 枚書き出す
//   Nebula --frames <置き場> <数>   <数> フレームを連番で書き出す (動きの証跡を作るため)
//
// **これで 6 作品目、書き出しの口を手で写している。** Grain → Garden → Solids → Ring →
// Helmet → ここ、と写してきて、作品ごとに違うのは書き出す名前だけ。所見は README にある。
//
// **この作品では書き出しがいちばん重い。** 面が 4K で粒が 100 万なので、`--frames` は
// 枚数ぶんの 4K PNG (1 枚 10MB 前後) を書く。置き場は `out/` か `shots/` に落として
// おくこと (どちらもルートの `.gitignore` が落とす)。
let arguments = Array(CommandLine.arguments.dropFirst())

switch arguments.first {
case "--render", "--frames":
    let isSequence = arguments.first == "--frames"
    let directory = URL(fileURLWithPath: arguments.count > 1 ? arguments[1] : "shots")
    let count = arguments.count > 2 ? Int(arguments[2]) ?? 1 : 1
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let gpu = try RenderDevice()
    let runtime = try SketchRuntime(sketch: Nebula(), gpu: gpu)
    if isSequence {
        for frame in 0..<count {
            try runtime.advance()
            let url = directory.appendingPathComponent(String(format: "frame-%04d.png", frame))
            try runtime.target.writePNG(to: url)
        }
        print(directory.path)
    } else {
        for _ in 0..<count { try runtime.advance() }
        let url = directory.appendingPathComponent("nebula-\(count).png")
        try runtime.target.writePNG(to: url)
        print(url.path)
    }
default:
    Nebula.main()
}
