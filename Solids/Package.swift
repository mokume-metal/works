// swift-tools-version: 6.2

import PackageDescription

// 1 作品 1 パッケージ。**mokume-cli の単位がこれ** — `run` / `watch` は
// ディレクトリの直下に Package.swift を求め、実行ファイルの名前を products から取る
let package = Package(
    name: "Solids",
    platforms: [.macOS("26.0")],
    products: [.executable(name: "Solids", targets: ["Solids"])],
    dependencies: [
        // Grain / Garden と同じ版で固定する。**どの版で描いたかは Package.resolved が
        // 持つ**ので、この作品のコミットへ戻れば当時の mokume に戻る
        .package(url: "https://github.com/mokume-metal/mokume.git", from: "0.6.0")
    ],
    targets: [
        .executableTarget(
            name: "Solids",
            dependencies: [.product(name: "mokume", package: "mokume")],
            // **モデルは宣言しないと見つからない。** `loadModel()` が探すのは作業
            // ディレクトリと、実行ファイルの隣に並ぶ `*.bundle` の中である
            // (mokume の `ImageFile.candidates`)。宣言を落とすと包みが作られず、
            // 窓からは読めて `swift run` からは読めない、が起きる
            resources: [.copy("assets")],
            swiftSettings: [
                // mokume と揃える。既定の隔離が main actor でないと、スケッチに
                // 並行性の注釈が要る
                .swiftLanguageMode(.v6), .defaultIsolation(MainActor.self),
            ])
    ]
)
