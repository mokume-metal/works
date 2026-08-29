// swift-tools-version: 6.2

import PackageDescription

// 作品ごとに実行ファイルを 1 本置く。作品は互いに依存しない。
let package = Package(
    name: "works",
    // mokume が macOS 26 / Apple Silicon 専用なので、こちらもそこに揃う
    platforms: [.macOS("26.0")],
    dependencies: [
        // タグではなく main を指す。v0.1.0 (2026-08-27) は立体と光 (2026-08-28) を
        // 含まないため。0.x のあいだは追随し続ける
        .package(url: "https://github.com/mokume-metal/mokume.git", branch: "main")
    ],
    targets: [
        .executableTarget(
            name: "Grain",
            dependencies: [.product(name: "mokume", package: "mokume")],
            path: "Grain",
            swiftSettings: [
                // mokume と揃える。既定の隔離が main actor でないと、スケッチに
                // 並行性の注釈が要る
                .swiftLanguageMode(.v6), .defaultIsolation(MainActor.self),
            ])
    ]
)
