import Foundation
import mokume
import simd

/// 粒 — 塊を埋める立方体の群れ。
///
/// **立方体は 1 つだけ焼いて、置き場所を配る。** `shape(_:at:)` は置き場所をいくつ
/// 渡しても描画が 1 回で済むので、千を超える粒でも塊 1 つより軽い。
///
/// ## 粒でもはみ出しは出ない
///
/// 残すのは「**立方体の 8 隅がすべて `f ≤ 0`**」のセルだけである。塊は凸なので、
/// 8 隅が内側なら立方体まるごとが内側にあり、`f ≤ 0` の点の影は狙いの内側にしか
/// 落ちない (``Carve``)。細かさが落ちるぶん影の縁は粒の大きさだけ内へ入るが、
/// **狙いの外へ出ることは粒でも起きない**。
///
/// ## 動かし方は 2 つだけ
///
/// - **光の筋に沿って伸ばす** (`spread`)。影は 1 ミリも動かない
/// - **光の筋に沿って波打たせる** (`wave`)。これも影は動かない
///
/// どちらも ``Shear`` の式から出る動きで、**影がどう振る舞うかを先に知ったうえで
/// 選んだ動き**である。粒を勝手な向きへ飛ばすと影はただ散らかる。
///
/// ## 光の軸のまわりに回す案は落とした
///
/// 「軸のまわりに回せば影も同じ角だけ回るはず」と考えて 2 枚重ねの星を作ろうとしたが、
/// **回らない**。影への写像は光に直交する面から床への線形写像で、床が傾いているぶん
/// 一方向に伸びる — 相似ではないので、回転を挟むと `A R A⁻¹` になり、円が楕円へ潰れた
/// ような「傾いた回転」になる。実際に出たのは星ではなく角の丸い斑だった。
///
/// **影が素直に従うのは、光の向きに沿った平行移動と、水平な平行移動だけ**である。
enum Grains {
    struct Grain {
        /// 塊の中での位置 (物体の座標)。
        var place: SIMD3<Float>
        /// 光の筋に沿った順番 (0…1)。**手前の粒ほど遠くへ飛ぶ。**
        var rank: Float

    }

    /// 粒を拾う。
    static func pick(_ lattice: Lattice, turns: [Float]) -> [Grain] {
        let size = Field.grain
        let half = size / 2
        let columns = Int((2 * Field.extent / size).rounded(.down))
        let layers = Int((Field.height / size).rounded(.down))
        var grains: [Grain] = []
        grains.reserveCapacity(2048)

        // 光の筋に沿った深さを測る軸 (設計時の向き・y 上向き)
        let travel = Shear.travel(Shear.design)

        var lowest = Float.greatestFiniteMagnitude
        var highest = -Float.greatestFiniteMagnitude

        for iy in 0..<layers {
            let u = -Field.height / 2 + (Float(iy) + 0.5) * size
            for ix in 0..<columns {
                let x = -Field.extent + (Float(ix) + 0.5) * size
                for iz in 0..<columns {
                    let z = -Field.extent + (Float(iz) + 0.5) * size
                    // **8 隅が全部内側のときだけ残す。** 中心だけで見ると、
                    // 立方体の角が狙いの外へ出る
                    var inside = true
                    for corner in 0..<8 {
                        let dx = (corner & 1) == 0 ? -half : half
                        let dy = (corner & 2) == 0 ? -half : half
                        let dz = (corner & 4) == 0 ? -half : half
                        let point = SIMD3<Float>(x + dx, u + dy, z + dz)
                        if Carve.value(point, turns: turns) > 0 {
                            inside = false
                            break
                        }
                    }
                    guard inside else { continue }
                    let place = SIMD3<Float>(x, u, z)
                    let depth = dot(place, travel)
                    lowest = min(lowest, depth)
                    highest = max(highest, depth)
                    grains.append(Grain(place: place, rank: depth))
                }
            }
        }

        // 順番を 0…1 へ均す
        let depthSpan = max(highest - lowest, 1)
        for index in grains.indices {
            grains[index].rank = (grains[index].rank - lowest) / depthSpan
        }
        return grains
    }

    /// その瞬間の置き場所を作る。
    ///
    /// **塊の座標のまま渡す** — 呼ぶ側が塊と同じ `translate` / `rotateY` の中で置くので、
    /// ここでは塊の中での動きだけを書けばよい。
    static func placements(_ grains: [Grain], frame: Score.Frame, tint: LinearRGBA) -> [Placement] {
        // **光の向きを塊の座標へ戻す。** 置き場所は `rotateY(turn)` の中で効くので、
        // 世界の向きのまま使うと、塊が回っているぶんだけ筋がずれて**影が動いてしまう**
        let world = Shear.travel(Shear.design)
        let c = cos(frame.turn), s = sin(frame.turn)
        let travel = SIMD3<Float>(world.x * c - world.z * s, world.y, world.x * s + world.z * c)
        let reach = Field.height * 1.7
        // 波。**筋に沿った動きなので、いくら暴れても影は動かない**
        let swell = frame.wave * Field.height * 0.55
        let phase = frame.local * 1.1

        return grains.map { grain in
            var place = grain.place
            // **光の筋に沿って伸ばす。** 影は動かない
            place -= travel * (frame.spread * reach * grain.rank)
            // **光の筋に沿って波打たせる。** これも影は動かない
            if swell > 0.0001 {
                place -= travel * (swell * sin((phase + grain.rank * 2.2) * 2 * Float.pi))
            }
            return Placement(
                x: place.x, y: -place.y, z: place.z, scale: 1, rotation: .zero, fill: tint)
        }
    }

}
