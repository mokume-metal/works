import mokume

// 板の面が既定で、`slab` を渡すと板を立体にして回す (未完成 — Slab.swift を読む)。
//
//   mokume run Grain        板の面を出す
//   swift run Grain slab    2 本目を出す
//
// **`mokume run` / `watch` / `mcp` は引数を通さない**ので、窓の経路は既定の 1 本に
// 固定される。2 本目を見るときは実行ファイルへ直に渡す。
if CommandLine.arguments.dropFirst().first == "slab" {
    Slab.main()
} else {
    Grain.main()
}
