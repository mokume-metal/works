import Foundation
import mokume

/// テクスチャアトラス — 16×16 texel のタイルを手続きで描いて 1 枚に並べる。
///
/// **絵を読み込まずに作る。** 作品は資産を持たない (`Package.swift` に `resources` の
/// 宣言が要る) ので、タイルはその場で描く。手続きで作れば**どの texel がなぜその色か**を
/// 説明できるし、色を 1 行変えれば世界の印象が変わる。
///
/// ## 粒は乱数ではなくハッシュで撒く
///
/// `random()` を使うと「同じフレーム番号からは同じ絵が出る」(mokume の ADR-0001 原則 2)
/// が、**アトラスを焼く順番が変わると模様が変わる**。ここでは座標と塩から直に値を引く
/// ので、どの順で焼いても同じ絵になる
enum Tiles {
    /// タイル 1 枚の辺 (texel)。**Minecraft と同じ 16。**
    static let size = 16
    /// アトラスの列数。
    static let columns = 4
    /// アトラスの辺 (texel)。
    static let pixels = size * columns

    static let grassTop = 0
    static let grassSide = 1
    static let dirt = 2
    static let stone = 3
    static let sand = 4
    static let water = 5
    static let logSide = 6
    static let logTop = 7
    static let leaves = 8
    static let waterTop = 9

    /// タイルの左上 texel。**`Mesher` が UV をここから組む。**
    static func origin(of tile: Int) -> (x: Float, y: Float) {
        (x: Float((tile % columns) * size), y: Float((tile / columns) * size))
    }

    /// アトラスを描く。
    static func paint(_ atlas: Image) {
        atlas.fill(.display(red: 0, green: 0, blue: 0, alpha: 0))
        grassTopTile(atlas)
        grassSideTile(atlas)
        dirtTile(atlas)
        stoneTile(atlas)
        sandTile(atlas)
        waterTile(atlas)
        waterTopTile(atlas)
        logSideTile(atlas)
        logTopTile(atlas)
        leavesTile(atlas)
    }

    // MARK: - タイル 1 枚ずつ

    /// 草の上面。**濃さの違う草を 3 段に散らす** — 1 色に粒を足しただけでは芝に見えない。
    private static func grassTopTile(_ atlas: Image) {
        paint(atlas, grassTop) { x, y in
            let n = noise(x, y, salt: 11) * 0.6 + noise(x / 2, y / 2, salt: 12) * 0.4
            let tone = 0.33 + n * 0.24
            return .display(red: tone * 0.48, green: tone * 1.44, blue: tone * 0.34)
        }
    }

    /// 草の側面。**境目は真っ直ぐにしない** — 直線で切ると積み木の縁に見える。
    private static func grassSideTile(_ atlas: Image) {
        paint(atlas, grassSide) { x, y in
            // 列ごとに 3〜6 texel の草が垂れ下がる
            let hang = 3 + Int(noise(x, 0, salt: 21) * 3.2)
            if Int(y) < hang {
                let n = noise(x, y, salt: 22)
                let tone = 0.32 + n * 0.22
                return .display(red: tone * 0.48, green: tone * 1.40, blue: tone * 0.34)
            }
            return soil(x, y)
        }
    }

    private static func dirtTile(_ atlas: Image) {
        paint(atlas, dirt) { x, y in soil(x, y) }
    }

    /// 石。**暗い斑を数えられるほどに散らす** — 一様な灰色は面の向きが読めない。
    private static func stoneTile(_ atlas: Image) {
        paint(atlas, stone) { x, y in
            let grain = noise(x, y, salt: 41) * 0.55 + noise(x / 3, y / 3, salt: 42) * 0.45
            var tone = 0.44 + grain * 0.16
            // 斑。3% ほどの texel を落とす
            if noise(x, y, salt: 43) > 0.965 { tone -= 0.13 }
            return .display(red: tone, green: tone * 1.00, blue: tone * 1.02)
        }
    }

    private static func sandTile(_ atlas: Image) {
        paint(atlas, sand) { x, y in
            let grain = noise(x, y, salt: 51)
            let tone = 0.76 + grain * 0.13
            return .display(red: tone, green: tone * 0.93, blue: tone * 0.66)
        }
    }

    /// 水。**半透明で、濃さがゆるく揺れる。**
    ///
    /// **薄くすると水に見えない。** 0.62 まで透かしたときは、浅瀬で水底の砂が勝って
    /// しまい、階段状の砂丘が濡れているようにしか見えなかった。0.78 なら深いところは
    /// 面として読め、浅いところだけ底が透ける
    private static func waterTile(_ atlas: Image) {
        paint(atlas, water) { x, y in
            let swell = noise(x / 4, y / 4, salt: 61)
            return .display(
                red: 0.10 + swell * 0.07, green: 0.40 + swell * 0.13,
                blue: 0.70 + swell * 0.14, alpha: 0.78)
        }
    }

    /// 水面。**横から見る水とは別のタイルにしてある。**
    ///
    /// 水を 1 色で貼ると、浅瀬では**水底の砂が勝って水面がどこにあるか読めない**。
    /// 上を向いた面だけ明るくして細い筋を入れると、同じ透け方のままで面の位置が出る
    private static func waterTopTile(_ atlas: Image) {
        paint(atlas, waterTop) { x, y in
            let swell = noise(x / 4, y / 4, salt: 63)
            // さざ波 — 斜めに流れる細い筋
            let ripple = sin((x + y * 0.6) * 1.1) * 0.5 + 0.5
            let lift = ripple * 0.10 + swell * 0.06
            return .display(
                red: 0.16 + lift, green: 0.52 + lift, blue: 0.80 + lift * 0.6, alpha: 0.80)
        }
    }

    /// 原木の側面。**縦の筋だけで樹皮に見える。**
    private static func logSideTile(_ atlas: Image) {
        paint(atlas, logSide) { x, y in
            let ridge = noise(x, 0, salt: 71) * 0.7 + noise(x, y / 6, salt: 72) * 0.3
            let tone = 0.26 + ridge * 0.16
            return .display(red: tone * 1.30, green: tone * 0.95, blue: tone * 0.60)
        }
    }

    /// 原木の断面。**年輪は中心からの距離の周期。**
    private static func logTopTile(_ atlas: Image) {
        paint(atlas, logTop) { x, y in
            let dx = x - 7.5
            let dy = y - 7.5
            let radius = (dx * dx + dy * dy).squareRoot()
            let ring = (sin(radius * 2.4) + 1) / 2
            let tone = 0.40 + ring * 0.13 + noise(x, y, salt: 81) * 0.05
            return .display(red: tone * 1.32, green: tone * 1.06, blue: tone * 0.68)
        }
    }

    /// 葉。**穴は開けずに、暗い粒で葉の重なりを出す。**
    ///
    /// 半透明にすると重なった葉が前後に並び、描く順で色が変わる。**不透明のまま
    /// 密に見せる**ほうが、木としては正しく読める
    private static func leavesTile(_ atlas: Image) {
        paint(atlas, leaves) { x, y in
            let clump = noise(x / 2, y / 2, salt: 91) * 0.6 + noise(x, y, salt: 92) * 0.4
            var tone = 0.20 + clump * 0.16
            // 葉と葉の隙間。暗く落として重なりに見せる
            if noise(x, y, salt: 93) > 0.82 { tone *= 0.55 }
            return .display(red: tone * 0.72, green: tone * 1.30, blue: tone * 0.52)
        }
    }

    // MARK: - 下ごしらえ

    /// 土の色。**草の側面と土のタイルで同じものを使う** — 境目で色が跳ねないため。
    private static func soil(_ x: Float, _ y: Float) -> LinearRGBA {
        let grain = noise(x, y, salt: 31) * 0.6 + noise(x / 2, y / 2, salt: 32) * 0.4
        let tone = 0.32 + grain * 0.16
        return .display(red: tone * 1.42, green: tone * 1.02, blue: tone * 0.70)
    }

    /// タイル 1 枚を塗る。`body` はタイルの中の座標 (0…15) を受ける。
    private static func paint(
        _ atlas: Image, _ tile: Int, _ body: (Float, Float) -> LinearRGBA
    ) {
        let origin = origin(of: tile)
        for y in 0..<size {
            for x in 0..<size {
                atlas.set(
                    Int(origin.x) + x, Int(origin.y) + y, body(Float(x), Float(y)))
            }
        }
    }

    /// 座標から直に引く 0…1 の値。**並べる順に依らない。**
    private static func noise(_ x: Float, _ y: Float, salt: Int) -> Float {
        var h = UInt32(truncatingIfNeeded: Int(x * 37) &* 374_761_393)
        h &+= UInt32(truncatingIfNeeded: Int(y * 37) &* 668_265_263)
        h &+= UInt32(truncatingIfNeeded: salt &* 1_274_126_177)
        h ^= h >> 13
        h = h &* 1_274_126_177
        h ^= h >> 16
        return Float(h % 65536) / 65535
    }
}
