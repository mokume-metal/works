// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Garden",
    platforms: [.macOS("26.0")],
    // **実行ファイルを宣言する。** 宣言が無くても走らせる方法はあるが、道具が
    // 実行ファイルの場所を解決できなくなり、起動のたびに遠回りを払うことになる
    products: [.executable(name: "Garden", targets: ["Garden"])],
    dependencies: [.package(
    url: "https://github.com/mokume-metal/mokume.git",
    from: "0.5.0")],
    targets: [
        .executableTarget(
            name: "Garden",
            dependencies: [.product(name: "mokume", package: "mokume")],
            swiftSettings: [.swiftLanguageMode(.v6), .defaultIsolation(MainActor.self)])
    ]
)
