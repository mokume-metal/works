import Foundation
import simd

/// 目で選んだ 1 ブロック。
struct Hit {
    let x: Int
    let y: Int
    let z: Int
    /// どの面から入ったか。**置くときはこの向きの隣へ置く。**
    let face: Face

    /// 隣 — 置く先。
    var beside: (x: Int, y: Int, z: Int) {
        let step = face.step
        return (x + step.x, y + step.y, z + step.z)
    }
}

/// 目の前のブロックを選ぶ。
///
/// **格子を 1 マスずつ渡る** (Amanatides–Woo)。一定の刻みで進んで中身を見る素朴なやり方
/// だと、刻みが粗ければブロックの角を飛び越し、細かければ 1 回の選択で数百回世界を読む。
/// 3 つの軸の「次に境を跨ぐまでの距離」を持ち回って**いちばん近い境だけを跨ぐ**なら、
/// 通ったマスを 1 つも飛ばさずに、跨いだ回数ぶんの仕事で済む。
///
/// **どの面から入ったかが同時に分かる**のが効く — 置く先はその面の隣なので、
/// 当たり判定とは別に面を探し直さなくてよい
enum Pick {
    /// 手の届く距離 (単位)。**5 ブロック** — Minecraft と同じ。
    static let reach: Float = 500

    static func trace(
        from origin: SIMD3<Float>, along direction: SIMD3<Float>, in world: World
    ) -> Hit? {
        let scale = World.scale
        var cell = SIMD3<Int>(World.cell(origin.x), World.cell(origin.y), World.cell(origin.z))

        var step = SIMD3<Int>(repeating: 0)
        var nextBoundary = SIMD3<Float>(repeating: .infinity)
        var span = SIMD3<Float>(repeating: .infinity)

        for axis in 0..<3 {
            let d = direction[axis]
            guard abs(d) > 1e-6 else { continue }
            step[axis] = d > 0 ? 1 : -1
            let edge = Float(d > 0 ? cell[axis] + 1 : cell[axis]) * scale
            nextBoundary[axis] = (edge - origin[axis]) / d
            span[axis] = scale / abs(d)
        }

        var travelled: Float = 0
        // **跨ぐ回数に上限を置く。** 軸に沿った視線では 5 ブロックで 5 回だが、
        // 斜めなら 15 回になる。届く距離で切るので上限は保険である
        for _ in 0..<64 {
            // いちばん近い境を跨ぐ
            var axis = 0
            if nextBoundary[1] < nextBoundary[axis] { axis = 1 }
            if nextBoundary[2] < nextBoundary[axis] { axis = 2 }

            travelled = nextBoundary[axis]
            guard travelled <= reach else { return nil }

            cell[axis] += step[axis]
            nextBoundary[axis] += span[axis]

            guard World.inside(cell.x, cell.y, cell.z) else {
                // 上へ抜けたら終わり。横へ抜けただけなら戻ってくることがある
                if cell.y >= World.height || cell.y < 0 { return nil }
                continue
            }
            guard world.at(cell.x, cell.y, cell.z).isSolid else { continue }

            // 跨いだ軸の逆向きが、入った面
            let face: Face =
                switch (axis, step[axis]) {
                case (0, 1): .west
                case (0, _): .east
                case (1, 1): .down
                case (1, _): .up
                case (2, 1): .north
                default: .south
                }
            return Hit(x: cell.x, y: cell.y, z: cell.z, face: face)
        }
        return nil
    }
}
