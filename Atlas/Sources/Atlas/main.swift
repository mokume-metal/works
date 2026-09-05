import Foundation
import mokume

// 窓を開いて走らせるのが既定。
//
//   Atlas                                台帳が並べた最初の例を出す
//   Atlas --list                         移した例を並べる
//   Atlas <例名>                          その 1 本を出す (Mouse2D でも Basics/Input/Mouse2D でも引ける)
//   Atlas --render <置き場> <数> [例名]     1 枚だけ書き出す
//   Atlas --frames <置き場> <数> [例名]     連番で書き出す (動きの証跡を作るため)
//   Atlas --render-all <置き場> [数]       移した全部を 1 枚ずつ書き出す
//
// **`--render-all` があるのは、版を上げたときに全部のハッシュを一度に取り直すため。**
// 既存 4 作品は 1 本ずつ手で確かめており、版上げのたびに同じ手順を作品の数だけ踏む。
// Atlas は移した例が増え続けるので、その手順が本数に比例しては回らない。
//
// **`mokume run` / `watch` / `mcp` は引数を通さない**ので、窓の経路は既定の 1 本に
// 固定される。いま見たい例を先頭へ動かすか、`swift run Atlas <例名>` を使う。

/// 移した例。**並びは台帳の例名の順**で、足したらここに 1 行足す。
///
/// `Sketch.main()` は `@MainActor static func main()` なので `any Sketch` から呼べず、
/// Grain は `if arguments.first == "slab"` と分岐していた。例が増えると分岐も増えるので、
/// ここでは `SketchApplication(sketch:gpu:)` を使う — **あちらは `any Sketch` を取る**ので、
/// カタログの戻り値をそのまま渡せる (`Sketch.main()` の中身と同じ経路)。
let catalogue: [(name: String, make: () -> any Sketch)] = [
    ("Basics/Form/Bezier", { Bezier() }),
    ("Basics/Input/Mouse2D", { Mouse2D() }),
    ("Basics/Math/Map", { Map() }),
    ("Basics/Structure/NoLoop", { NoLoop() }),
    ("Topics/Drawing/ContinuousLines", { ContinuousLines() }),
]

/// 例名から作る。完全名 (`Basics/Input/Mouse2D`) でも末尾だけ (`Mouse2D`) でも引ける。
func makeSketch(_ name: String?) -> (name: String, sketch: any Sketch)? {
    guard let name else {
        let first = catalogue[0]
        return (first.name, first.make())
    }
    let found = catalogue.first {
        $0.name == name || $0.name.split(separator: "/").last.map(String.init) == name
    }
    return found.map { ($0.name, $0.make()) }
}

/// 書き出しのファイル名。例名の末尾を小文字にしたもの (`Basics/Input/Mouse2D` → `mouse2d`)。
func slug(_ name: String) -> String {
    (name.split(separator: "/").last.map(String.init) ?? name).lowercased()
}

let arguments = Array(CommandLine.arguments.dropFirst())

switch arguments.first {
case "--list":
    for entry in catalogue { print(entry.name) }

case "--render", "--frames":
    let isSequence = arguments.first == "--frames"
    let directory = URL(fileURLWithPath: arguments.count > 1 ? arguments[1] : "shots")
    let count = arguments.count > 2 ? Int(arguments[2]) ?? 1 : 1
    guard let (name, sketch) = makeSketch(arguments.count > 3 ? arguments[3] : nil) else {
        FileHandle.standardError.write(Data("知らない例です。--list で並べられます\n".utf8))
        exit(1)
    }
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
        let url = directory.appendingPathComponent("\(slug(name))-\(count).png")
        try runtime.target.writePNG(to: url)
        print(url.path)
    }

case "--render-all":
    let directory = URL(fileURLWithPath: arguments.count > 1 ? arguments[1] : "shots")
    let count = arguments.count > 2 ? Int(arguments[2]) ?? 1 : 1
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    // **面は 1 つで足りる。** 例ごとに作り直すのは走らせる側 (`SketchRuntime`) だけ
    let gpu = try RenderDevice()
    for entry in catalogue {
        let runtime = try SketchRuntime(sketch: entry.make(), gpu: gpu)
        for _ in 0..<count { try runtime.advance() }
        let url = directory.appendingPathComponent("\(slug(entry.name))-\(count).png")
        try runtime.target.writePNG(to: url)
        print(url.path)
    }

default:
    guard let (_, sketch) = makeSketch(arguments.first) else {
        FileHandle.standardError.write(Data("知らない例です。--list で並べられます\n".utf8))
        exit(1)
    }
    do {
        let gpu = try RenderDevice()
        let application = try SketchApplication(sketch: sketch, gpu: gpu)
        application.run()
    } catch {
        // **`Sketch.main()` と同じ文面が出せない。** あちらは `RenderFailure.message` を
        // 読んで「起動できませんでした」+ 中身の 2 行を書くが、`message` は internal な
        // ので外からは呼べない。`SketchApplication` は公開されているのに、それが投げる
        // 失敗を人に見せる手段だけが閉じている
        FileHandle.standardError.write(Data("スケッチを起動できませんでした。\n\(error)\n".utf8))
        exit(1)
    }
}
