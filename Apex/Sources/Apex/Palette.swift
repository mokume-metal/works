import mokume
import simd

/// 色。**0…255 で持つ** — `fill` / `ambientLight(数値の口)` と同じ尺度である。
///
/// **光の強さを `LinearRGBA` で渡す口だけは 0…1** なので、そちらは使う場所で書く
/// (取り違えると画面が真っ黒になる。mokume#1152)
enum Palette {
    static let tarmac = SIMD3<Float>(88, 90, 97)
    static let kerbWarm = SIMD3<Float>(198, 66, 54)
    static let kerbPale = SIMD3<Float>(236, 232, 222)
    static let apron = SIMD3<Float>(148, 136, 114)
    static let grass = SIMD3<Float>(76, 108, 58)
    static let field = SIMD3<Float>(88, 118, 66)
    static let line = SIMD3<Float>(238, 238, 236)
    static let asphaltDark = SIMD3<Float>(30, 31, 35)

    /// 4 台の色。**自分が 0 番。**
    static let cars: [SIMD3<Float>] = [
        SIMD3(226, 232, 238),  // 自分 — 白
        SIMD3(214, 66, 52),  // 1 号車 — 朱
        SIMD3(64, 126, 204),  // 2 号車 — 青
        SIMD3(226, 176, 50),  // 3 号車 — 黄
    ]

    /// 手元の表示の色。
    static let ink = SIMD3<Float>(244, 246, 248)
    static let shade = SIMD3<Float>(16, 17, 20)
}

extension Palette {
    /// 0…255 の色を、置き場所へ掛ける色 (`LinearRGBA`) へ直す。
    ///
    /// **`Placement.fill` は 0…1 の表示値で受ける。** 塗りと同じ 0…255 のつもりで
    /// 渡すと、色が飽和して真っ白になる
    static func linear(_ colour: SIMD3<Float>) -> LinearRGBA {
        LinearRGBA.display(red: colour.x / 255, green: colour.y / 255, blue: colour.z / 255)
    }
}
