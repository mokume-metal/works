import Foundation

/// 世界 — ブロックの並びと、焼き直しの予約。
///
/// ## 尺度を決めてある — 1 ブロック = 100 単位 = 1 m
///
/// 人の目は地面から 162 単位の高さにあり (Minecraft と同じ 1.62 m)、体は 60 × 180 の柱で
/// ある。**単位を 1 ではなく 100 にしたのは、カメラの `near` を 10 に置けるから**で、
/// 1 ブロック = 1 単位だと近くの面が near に切られる。
///
/// ## y は上向き。**描くときだけ反転する**
///
/// mokume の縦軸は下向きである (`+y` が画面の下)。ボクセルの世界を下向きで持つと
/// 「高さ」と「深さ」が入れ替わって読めなくなるので、**ここでは y を上向きに持ち、
/// 頂点とカメラを渡す直前に符号を反転する** (`Mesher` と `Quarry.look`)。反転は鏡映なので
/// 三角形の巻きが裏返る — `Mesher` の 2 枚は**反転後に表を向く順**で並べてある。
///
/// ## 並べ方は x が連続
///
/// 添字は `(y * span + z) * span + x`。**面を焼くときの走査が x の内回り**なので、
/// この向きだと隣のブロックが同じキャッシュ行に乗る
final class World {
    /// チャンクの辺 (ブロック)。
    static let chunkSpan = 16
    /// チャンクの数 (x・z のそれぞれ)。
    static let chunksAcross = 8
    /// 世界の高さ (ブロック)。
    static let height = 64
    /// 世界の辺 (ブロック)。
    static let span = chunkSpan * chunksAcross
    /// 1 ブロックの辺 (単位)。
    static let scale: Float = 100

    private var cells: [UInt8]

    /// 焼き直しを待っているチャンク。**壊す・置くで積まれ、焼いたら降ろす。**
    private(set) var stale: Set<Int> = []

    init() {
        cells = [UInt8](repeating: 0, count: Self.span * Self.span * Self.height)
    }

    // MARK: - 読む

    /// 世界の中か。**外はすべて空気として読む** — 端で面が湧かないようにするためではなく、
    /// 逆に**端の面は焼きたい**ので、`at` は外を `.air` で返す
    @inline(__always)
    static func inside(_ x: Int, _ y: Int, _ z: Int) -> Bool {
        x >= 0 && x < span && z >= 0 && z < span && y >= 0 && y < height
    }

    @inline(__always)
    func at(_ x: Int, _ y: Int, _ z: Int) -> Block {
        guard Self.inside(x, y, z) else { return .air }
        return Block(rawValue: cells[(y * Self.span + z) * Self.span + x]) ?? .air
    }

    /// 単位の座標にあるブロック。**体と目はこちらで世界を読む。**
    @inline(__always)
    func at(_ place: SIMD3<Float>) -> Block {
        at(Self.cell(place.x), Self.cell(place.y), Self.cell(place.z))
    }

    /// 単位 → ブロックの添字。**負の側で 0 へ丸めない** (`Int()` は 0 方向へ切るので、
    /// −0.5 が 0 になって世界の外が中に見える)
    @inline(__always)
    static func cell(_ value: Float) -> Int { Int(floor(value / scale)) }

    // MARK: - 書く

    /// 置き換える。**触ったチャンクを焼き直しへ積む。**
    ///
    /// 面はチャンクの境で切れているので、**端のブロックを触ったら隣のチャンクも積む** —
    /// 積まないと、壊した穴の向こう側の面が焼かれないまま残って世界が透ける
    func set(_ x: Int, _ y: Int, _ z: Int, _ block: Block) {
        guard Self.inside(x, y, z) else { return }
        cells[(y * Self.span + z) * Self.span + x] = block.rawValue

        let cx = x / Self.chunkSpan
        let cz = z / Self.chunkSpan
        stale.insert(Self.chunk(cx, cz))
        if x % Self.chunkSpan == 0 { markChunk(cx - 1, cz) }
        if x % Self.chunkSpan == Self.chunkSpan - 1 { markChunk(cx + 1, cz) }
        if z % Self.chunkSpan == 0 { markChunk(cx, cz - 1) }
        if z % Self.chunkSpan == Self.chunkSpan - 1 { markChunk(cx, cz + 1) }
    }

    /// 地形を作るときの置き方。**焼き直しには積まない** — 最初に全部焼くので要らない。
    @inline(__always)
    func plant(_ x: Int, _ y: Int, _ z: Int, _ block: Block) {
        guard Self.inside(x, y, z) else { return }
        cells[(y * Self.span + z) * Self.span + x] = block.rawValue
    }

    private func markChunk(_ cx: Int, _ cz: Int) {
        guard cx >= 0, cx < Self.chunksAcross, cz >= 0, cz < Self.chunksAcross else { return }
        stale.insert(Self.chunk(cx, cz))
    }

    /// 焼き直しを 1 つ取り出す。**1 フレームに何枚焼くかは呼ぶ側が決める。**
    func takeStale() -> Int? {
        guard let first = stale.first else { return nil }
        stale.remove(first)
        return first
    }

    // MARK: - チャンク

    static func chunk(_ cx: Int, _ cz: Int) -> Int { cz * chunksAcross + cx }
    static func chunkOrigin(_ chunk: Int) -> (x: Int, z: Int) {
        (x: (chunk % chunksAcross) * chunkSpan, z: (chunk / chunksAcross) * chunkSpan)
    }
    static var chunkCount: Int { chunksAcross * chunksAcross }

    /// いちばん上の固いブロックの段。**人を地面へ降ろすときに使う。**
    func surface(x: Int, z: Int) -> Int {
        for y in stride(from: Self.height - 1, through: 0, by: -1) where at(x, y, z).isSolid {
            return y
        }
        return 0
    }
}
