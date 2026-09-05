import Foundation
import mokume

// 窓を開いて走らせるのが既定。
//
//   Helmet                         兜を出す
//   Helmet --render <置き場> <数>   <数> フレーム進めてから 1 枚書き出す
//   Helmet --frames <置き場> <数>   <数> フレームを連番で書き出す (動きの証跡を作るため)
//   Helmet --measure               組み立ての時間を、頂点の渡し方ごとに測る (README の段 0)
//
// **これで 5 作品目、書き出しの口を手で写している。** Grain → Garden → Solids → Ring →
// ここ、と写してきて、作品ごとに違うのは書き出す名前だけ。所見は README に残してある。
let arguments = Array(CommandLine.arguments.dropFirst())

switch arguments.first {
case "--measure":
    // **段 0 の測定。** 回避策 (chunked) と素直な書き方 (whole) を並べる。
    // 窓は開かない — 測るのは `setup()` の中だけである。
    //
    // whole は終わらないかもしれないので**後に置く**。前に置くと、chunked の数字が
    // 一度も出ないまま待たされる
    let gpu = try RenderDevice()
    // **渡し方を名指しできる。** 両方を 1 度に測ると、whole が終わらないときに
    // chunked の数字まで見えなくなる (出力はパイプへ溜まるので、殺すと消える)
    let only = arguments.count > 1 ? Helmet.Build(rawValue: arguments[1]) : nil
    // **塊の大きさを振れる。** 費用が塊の大きさに比例して増えるなら二次、
    // 変わらないなら線形 — 起票に要るのはこの形の数字である
    if arguments.count > 2, let size = Int(arguments[2]) { Helmet.chunk = max(1, size) }
    for build in only.map({ [$0] }) ?? [.chunked, .whole] {
        Helmet.build = build
        print("### \(build.rawValue)" + (build == .chunked ? " (塊 \(Helmet.chunk) 枚)" : ""))
        let runtime = try SketchRuntime(sketch: Helmet(), gpu: gpu)
        try runtime.advance()
        print()
    }

case "--render", "--frames":
    let isSequence = arguments.first == "--frames"
    let directory = URL(fileURLWithPath: arguments.count > 1 ? arguments[1] : "shots")
    let count = arguments.count > 2 ? Int(arguments[2]) ?? 1 : 1
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let gpu = try RenderDevice()
    let runtime = try SketchRuntime(sketch: Helmet(), gpu: gpu)
    if isSequence {
        for frame in 0..<count {
            try runtime.advance()
            let url = directory.appendingPathComponent(String(format: "frame-%04d.png", frame))
            try runtime.target.writePNG(to: url)
        }
        print(directory.path)
    } else {
        for _ in 0..<count { try runtime.advance() }
        let url = directory.appendingPathComponent("helmet-\(count).png")
        try runtime.target.writePNG(to: url)
        print(url.path)

        // **絵を数で名乗る。** 「形が出たか」を目で見る前に判定できるようにする —
        // 画像を読むのは高い操作なので、まず数で切り分ける
        let image = try runtime.target.encodeForDisplay()
        // **明るさの分布で名乗る。** 「塗られたか」を閾値で決めると、背景より暗く
        // 描かれたときに「何も無い」と読み違える
        var histogram = [Int](repeating: 0, count: 256)
        for index in stride(from: 0, to: image.bytes.count, by: 4) {
            histogram[
                max(
                    Int(image.bytes[index]),
                    max(Int(image.bytes[index + 1]), Int(image.bytes[index + 2])))] += 1
        }
        let common = histogram.enumerated().filter { $0.element > 0 }
            .sorted { $0.element > $1.element }.prefix(6)
        print("  画素 \(image.width)x\(image.height) / 明るさの種類 \(histogram.filter { $0 > 0 }.count)")
        print(
            "  多い順: "
                + common.map { "\($0.offset)→\($0.element)" }.joined(separator: "  "))
    }

default:
    Helmet.main()
}
