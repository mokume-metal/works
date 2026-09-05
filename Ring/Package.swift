// swift-tools-version: 6.2

import PackageDescription

// 1 作品 1 パッケージ。**mokume-cli の単位がこれ** — `run` / `watch` は
// ディレクトリの直下に Package.swift を求め、実行ファイルの名前を products から取る
let package = Package(
    name: "Ring",
    platforms: [.macOS("26.0")],
    products: [.executable(name: "Ring", targets: ["Ring"])],
    dependencies: [
        // Grain / Garden / Solids と同じ版で固定する。**どの版で描いたかは
        // Package.resolved が持つ**ので、この作品のコミットへ戻れば当時の mokume に戻る
        .package(url: "https://github.com/mokume-metal/mokume.git", from: "0.5.0")
    ],
    targets: [
        .executableTarget(
            name: "Ring",
            dependencies: [.product(name: "mokume", package: "mokume")],
            swiftSettings: [
                // mokume と揃える。既定の隔離が main actor でないと、スケッチに
                // 並行性の注釈が要る
                .swiftLanguageMode(.v6), .defaultIsolation(MainActor.self),
            ])
    ]
)
