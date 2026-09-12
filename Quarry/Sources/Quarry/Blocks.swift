import Foundation

/// ブロックの種類。
///
/// **`UInt8` 1 個で世界を持つ。** 128×128×64 = 100 万個あるので、1 個に構造体を当てると
/// 焼き直しのたびに 100 万回の間接参照になる。種類の番号だけを並べ、見た目も固さも
/// この列挙が引き受ける
enum Block: UInt8 {
    case air = 0
    case grass = 1
    case dirt = 2
    case stone = 3
    case sand = 4
    case water = 5
    case log = 6
    case leaves = 7

    /// 向こう側が透けるか。**面を出すかどうかの判定はこれ 1 つで決まる。**
    ///
    /// 隣が透けるブロックなら、こちら側の面は見えるので焼く。**葉はここに入れない** —
    /// 絵の上では穴が空いているが、隣り合う葉の間の面まで焼くと、外から見えない面が
    /// 木 1 本あたり数百枚増える。Minecraft の「処理を優先」と同じ割り切りである
    var isClear: Bool {
        switch self {
        case .air, .water: true
        default: false
        }
    }

    /// 体がぶつかるか。**水は通り抜ける** — 泳ぎは作らないが、入ると沈む
    var isSolid: Bool {
        switch self {
        case .air, .water: false
        default: true
        }
    }

    /// 光を通すか。**水だけは後から重ねる** ので、面を焼く先が違う
    var isTranslucent: Bool { self == .water }

    /// この面に貼るタイルの番号。
    ///
    /// **上面・側面・下面で違うのは草と原木だけ**である。草は上が緑で横が土との境、
    /// 原木は横が樹皮で上下が年輪
    func tile(on face: Face) -> Int {
        switch self {
        case .air: 0
        case .grass:
            switch face {
            case .up: Tiles.grassTop
            case .down: Tiles.dirt
            default: Tiles.grassSide
            }
        case .dirt: Tiles.dirt
        case .stone: Tiles.stone
        case .sand: Tiles.sand
        case .water: face == .up ? Tiles.waterTop : Tiles.water
        case .log: (face == .up || face == .down) ? Tiles.logTop : Tiles.logSide
        case .leaves: Tiles.leaves
        }
    }

    /// 手に持てる種類。**数字キーの並び順がこれ。**
    static let inHand: [Block] = [.grass, .dirt, .stone, .sand, .log, .leaves, .water]

    /// 手引きに出す名前。
    var label: String {
        switch self {
        case .air: "空気"
        case .grass: "草"
        case .dirt: "土"
        case .stone: "石"
        case .sand: "砂"
        case .water: "水"
        case .log: "原木"
        case .leaves: "葉"
        }
    }
}

/// 立方体の 6 面。
///
/// **並びが法線と隣の向きを兼ねる。** 面を焼くときは `normal` をそのまま出し、
/// 隣のブロックを見るときは `step` をそのまま足す
enum Face: Int, CaseIterable {
    case east = 0  // +x
    case west = 1  // −x
    case up = 2  // +y
    case down = 3  // −y
    case south = 4  // +z
    case north = 5  // −z

    /// 隣を見る向き。
    var step: (x: Int, y: Int, z: Int) {
        switch self {
        case .east: (1, 0, 0)
        case .west: (-1, 0, 0)
        case .up: (0, 1, 0)
        case .down: (0, -1, 0)
        case .south: (0, 0, 1)
        case .north: (0, 0, -1)
        }
    }

    /// 外を向く法線。
    var normal: (x: Float, y: Float, z: Float) {
        let step = step
        return (Float(step.x), Float(step.y), Float(step.z))
    }
}
