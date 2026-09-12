import Foundation

/// 面を 1 枚ぶん。**位置は世界の座標 (単位・y 上向き)、uv はアトラスの texel。**
struct Corner {
    var x: Float
    var y: Float
    var z: Float
    var u: Float
    var v: Float
    var nx: Float
    var ny: Float
    var nz: Float
}

/// チャンク 1 つを頂点の並びへ焼く。
///
/// **描かない。** `createShape` はスケッチの口なので、ここで呼ぶと面の組み立てが描画へ
/// 結び付く。頂点の並びを返すだけにしておくと、**焼いた枚数と頂点の数をそのまま数えられる**
/// し、掘った後に焼き直す経路も呼ぶ側が決められる。
///
/// ## 見えない面は焼かない
///
/// 16 × 16 × 64 = 16,384 個のブロックを素直に立方体で置くと 98,304 枚の面になるが、
/// **隣が詰まっている面は誰にも見えない**。隣が空気 (か水) のときだけ 1 枚出す —
/// これで地表のチャンクは 2,000 枚前後に落ちる。
///
/// ## uv は 0.5 texel 内側へ寄せてある
///
/// タイルの縁を素直に 0 と 16 で切ると、拡大したとき**隣のタイルの色が滲んで出る**
/// (アトラスは 1 枚の絵なので、縁の補間は隣の枠を読む)。半 texel 内側へ寄せると、
/// 補間がタイルの中だけで閉じる
enum Mesher {
    /// 隅のオフセット。**外から見て反時計回り**に並べてある。
    ///
    /// 世界は y 上向き・描くときに反転する。反転は鏡映なので巻きが裏返るが、mokume の
    /// 投影も縦を反転するので、**この順のまま渡すと画面では表を向く**
    private static let corners: [Face: [(Int, Int, Int)]] = [
        .east: [(1, 0, 1), (1, 0, 0), (1, 1, 0), (1, 1, 1)],
        .west: [(0, 0, 0), (0, 0, 1), (0, 1, 1), (0, 1, 0)],
        .up: [(0, 1, 0), (0, 1, 1), (1, 1, 1), (1, 1, 0)],
        .down: [(0, 0, 0), (1, 0, 0), (1, 0, 1), (0, 0, 1)],
        .south: [(0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1)],
        .north: [(1, 0, 0), (0, 0, 0), (0, 1, 0), (1, 1, 0)],
    ]

    /// 隅ごとの uv (タイルの左上からの texel)。**下の 2 つが絵の下、上の 2 つが絵の上。**
    private static let patch: [(Float, Float)] = [
        (0.5, 15.5), (15.5, 15.5), (15.5, 0.5), (0.5, 0.5),
    ]

    /// チャンクを焼く。固いものと水は**別の並びへ** — 水は後から重ねる。
    static func bake(chunk: Int, of world: World) -> (solid: [Corner], water: [Corner]) {
        let origin = World.chunkOrigin(chunk)
        let span = World.chunkSpan
        let scale = World.scale

        var solid: [Corner] = []
        var water: [Corner] = []
        solid.reserveCapacity(4096)

        for y in 0..<World.height {
            for z in origin.z..<(origin.z + span) {
                for x in origin.x..<(origin.x + span) {
                    let here = world.at(x, y, z)
                    guard here != .air else { continue }

                    for face in Face.allCases {
                        let step = face.step
                        let there = world.at(x + step.x, y + step.y, z + step.z)
                        // **水は空気に接する面だけ。** 水どうしの境に面を出すと、
                        // 重なった半透明が濃くなって水底が読めなくなる
                        let shows = here.isTranslucent ? there == .air : there.isClear
                        guard shows else { continue }

                        let tile = Tiles.origin(of: here.tile(on: face))
                        let normal = face.normal
                        guard let offsets = corners[face] else { continue }

                        var quad: [Corner] = []
                        quad.reserveCapacity(4)
                        for (index, offset) in offsets.enumerated() {
                            let uv = patch[index]
                            quad.append(
                                Corner(
                                    x: Float(x + offset.0) * scale,
                                    y: Float(y + offset.1) * scale,
                                    z: Float(z + offset.2) * scale,
                                    u: tile.x + uv.0, v: tile.y + uv.1,
                                    nx: normal.x, ny: normal.y, nz: normal.z))
                        }

                        // 四角を三角 2 枚へ
                        let triangles = [quad[0], quad[1], quad[2], quad[0], quad[2], quad[3]]
                        if here.isTranslucent {
                            water.append(contentsOf: triangles)
                        } else {
                            solid.append(contentsOf: triangles)
                        }
                    }
                }
            }
        }
        return (solid, water)
    }
}
