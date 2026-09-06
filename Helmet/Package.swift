// swift-tools-version: 6.2

import PackageDescription

// 1 作品 1 パッケージ。**mokume-cli の単位がこれ** — `run` / `watch` は
// ディレクトリの直下に Package.swift を求め、実行ファイルの名前を products から取る
let package = Package(
    name: "Helmet",
    platforms: [.macOS("26.0")],
    products: [.executable(name: "Helmet", targets: ["Helmet"])],
    dependencies: [
        // 既存 4 作品と同じ版で固定する。**どの版で描いたかは Package.resolved が
        // 持つ**ので、この作品のコミットへ戻れば当時の mokume に戻る
        .package(url: "https://github.com/mokume-metal/mokume.git", from: "0.7.0")
    ],
    targets: [
        .executableTarget(
            name: "Helmet",
            dependencies: [.product(name: "mokume", package: "mokume")],
            // **resources を宣言しない。** 読む資産は第三者のもの (Khronos / Poly Haven) で
            // works へコミットしないので、包みに入れる中身が無い。`scripts/fetch.py` が
            // `upstream/` (gitignore 済み) へ置き、作業ディレクトリからの相対で読む —
            // `loadImage` が探すのは作業ディレクトリと実行ファイルの隣の `*.bundle` の
            // 両方なので、前者だけで届く
            swiftSettings: [
                // mokume と揃える。既定の隔離が main actor でないと、スケッチに
                // 並行性の注釈が要る
                .swiftLanguageMode(.v6), .defaultIsolation(MainActor.self),
            ])
    ]
)
