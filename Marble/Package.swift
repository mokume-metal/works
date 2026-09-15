// swift-tools-version: 6.2

import PackageDescription

// 1 作品 1 パッケージ。**mokume-cli の単位がこれ** — `run` / `watch` は
// ディレクトリの直下に Package.swift を求め、実行ファイルの名前を products から取る
let package = Package(
    name: "Marble",
    platforms: [.macOS("26.0")],
    products: [.executable(name: "Marble", targets: ["Marble"])],
    dependencies: [
        // **works で 0.8 系を引く 1 本目。** 既存 12 本は 0.7 系で、追随は #49 が追う。
        // どの版で描いたかは Package.resolved が持つので、この作品のコミットへ戻れば
        // 当時の mokume に戻る
        .package(url: "https://github.com/mokume-metal/mokume.git", from: "0.8.1")
    ],
    targets: [
        .executableTarget(
            name: "Marble",
            dependencies: [.product(name: "mokume", package: "mokume")],
            swiftSettings: [
                // mokume と揃える。既定の隔離が main actor でないと、スケッチに
                // 並行性の注釈が要る
                .swiftLanguageMode(.v6), .defaultIsolation(MainActor.self),
            ])
    ]
)
