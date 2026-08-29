// swift-tools-version: 6.2

import PackageDescription

// 1 作品 1 パッケージ。**mokume-cli の単位がこれ** — `run` / `watch` は
// ディレクトリの直下に Package.swift を求め、実行ファイルの名前を products から
// 取る。作品を 1 つのパッケージに並べると、最初の product が黙って起動する
let package = Package(
    name: "Grain",
    platforms: [.macOS("26.0")],
    // **宣言が無いと mokume-cli が実行ファイルを解決できない** (RunCommand)
    products: [.executable(name: "Grain", targets: ["Grain"])],
    dependencies: [
        // タグではなく main を指す。v0.1.0 (2026-08-27) は立体と光 (2026-08-28) を
        // 含まないため。**どの版で描いたかは Package.resolved が持つ**ので、
        // この作品のコミットへ戻れば当時の mokume に戻る
        .package(url: "https://github.com/mokume-metal/mokume.git", branch: "main")
    ],
    targets: [
        .executableTarget(
            name: "Grain",
            dependencies: [.product(name: "mokume", package: "mokume")],
            swiftSettings: [
                // mokume と揃える。既定の隔離が main actor でないと、スケッチに
                // 並行性の注釈が要る
                .swiftLanguageMode(.v6), .defaultIsolation(MainActor.self),
            ])
    ]
)
