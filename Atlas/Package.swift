// swift-tools-version: 6.2

import PackageDescription

// 1 作品 1 パッケージ。**mokume-cli の単位がこれ** — `run` / `watch` は
// ディレクトリの直下に Package.swift を求め、実行ファイルの名前を products から取る。
//
// Atlas は 1 product の中に**移した例を何本も持つ**。既存 4 つと違うのはそこだけで、
// 単位は変えていない (Grain が `Grain slab` で 2 本持っていたのを N 本へ広げたもの)。
let package = Package(
    name: "Atlas",
    platforms: [.macOS("26.0")],
    products: [.executable(name: "Atlas", targets: ["Atlas"])],
    dependencies: [
        // Grain / Garden / Solids / Ring と同じ版で固定する。**どの版で描いたかは
        // Package.resolved が持つ**ので、この作品のコミットへ戻れば当時の mokume に戻る。
        // 台帳もこの版に対して組んである (ledger/sources.json が刻んでいる)
        .package(url: "https://github.com/mokume-metal/mokume.git", from: "0.7.0")
    ],
    targets: [
        .executableTarget(
            name: "Atlas",
            dependencies: [.product(name: "mokume", package: "mokume")],
            swiftSettings: [
                // mokume と揃える。既定の隔離が main actor でないと、スケッチに
                // 並行性の注釈が要る
                .swiftLanguageMode(.v6), .defaultIsolation(MainActor.self),
            ])
    ]
)
