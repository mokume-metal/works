import Foundation
import mokume

// 窓を開いて走らせる。
//
//   Atlas            台帳が並べた最初の例を出す
//   Atlas --list     移した例を並べる
//   Atlas <例名>      その 1 本を出す (Mouse2D でも Basics/Input/Mouse2D でも引ける)
//
// **書き出しの口は畳んだ。** `--render` / `--frames` / `--render-all` / `--motion` は
// 絵のハッシュ台帳と原典との比較ビューアを支えるためのもので、その 3 つをまとめて
// やめた (理由は README の「測るのをやめたもの」)。
//
// **移した例の一覧 (`catalogue`) は Catalogue.swift にあり、置き場から組み直される**
// (`python3 scripts/catalogue.py`)。150 本を手で並べると、足したのに書き忘れた 1 本が
// 「まだ移していない例」と見分けが付かなくなる。
//
// **`mokume run` / `watch` / `mcp` は引数を通さない**ので、窓の経路は既定の 1 本に
// 固定される。いま見たい例を先頭へ動かすか、`swift run Atlas <例名>` を使う。


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

let arguments = Array(CommandLine.arguments.dropFirst())

switch arguments.first {
case "--list":
    for entry in catalogue { print(entry.name) }

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
