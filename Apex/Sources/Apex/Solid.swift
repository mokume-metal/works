import Foundation
import simd

/// 焼いた頂点 1 つ。**路面も車体も同じ形式で持つ。**
struct Corner {
    var x: Float
    var y: Float
    var z: Float
    var nx: Float
    var ny: Float
    var nz: Float
    var r: Float
    var g: Float
    var b: Float
}

/// 箱と輪を頂点の並びへ開く。
///
/// **`createShape` の中では `push` / `translate` / `rotate` が効かない。** 組み込みの
/// 立体 (`box` / `cylinder`) を変換して焼こうとすると、全部が原点に積み上がる。
/// だから車体も路面と同じで、頂点を自分で並べる。
///
/// ## 巻きの向きは路面に揃える
///
/// 世界の側では、**外向きの法線とは逆に巻く**のを表とする (路面がそうなっている)。
/// 渡すときに `form` が三角形ごとに巻きを裏返すので、写した先ではこれが表になる
/// (理由は ``Apex/form(_:)``)。ここでは 4 隅を渡す順を気にせずに済むよう、巻きを見て
/// 揃え直している
enum Solid {
    /// 四角 1 枚。`outward` はその面が向いている先。
    static func face(
        _ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>, _ d: SIMD3<Float>,
        outward: SIMD3<Float>, colour: SIMD3<Float>, into corners: inout [Corner]
    ) {
        let wind = simd_cross(b - a, c - a)
        let order: [SIMD3<Float>] =
            simd_dot(wind, outward) > 0 ? [d, c, b, a] : [a, b, c, d]
        let n = simd_normalize(outward)
        for point in [order[0], order[1], order[2], order[0], order[2], order[3]] {
            corners.append(
                Corner(
                    x: point.x, y: point.y, z: point.z, nx: n.x, ny: n.y, nz: n.z,
                    r: colour.x, g: colour.y, b: colour.z))
        }
    }

    /// 箱 1 つ。**中心と大きさで置く。**
    static func box(
        at centre: SIMD3<Float>, size: SIMD3<Float>, colour: SIMD3<Float>,
        into corners: inout [Corner]
    ) {
        let h = size / 2
        func corner(_ sx: Float, _ sy: Float, _ sz: Float) -> SIMD3<Float> {
            centre + SIMD3(h.x * sx, h.y * sy, h.z * sz)
        }
        let faces:
            [(SIMD3<Float>, [(Float, Float, Float)])] = [
                (SIMD3(0, 1, 0), [(-1, 1, -1), (1, 1, -1), (1, 1, 1), (-1, 1, 1)]),
                (SIMD3(0, -1, 0), [(-1, -1, 1), (1, -1, 1), (1, -1, -1), (-1, -1, -1)]),
                (SIMD3(0, 0, 1), [(-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)]),
                (SIMD3(0, 0, -1), [(1, -1, -1), (-1, -1, -1), (-1, 1, -1), (1, 1, -1)]),
                (SIMD3(1, 0, 0), [(1, -1, 1), (1, -1, -1), (1, 1, -1), (1, 1, 1)]),
                (SIMD3(-1, 0, 0), [(-1, -1, -1), (-1, -1, 1), (-1, 1, 1), (-1, 1, -1)]),
            ]
        for (outward, quad) in faces {
            face(
                corner(quad[0].0, quad[0].1, quad[0].2), corner(quad[1].0, quad[1].1, quad[1].2),
                corner(quad[2].0, quad[2].1, quad[2].2), corner(quad[3].0, quad[3].1, quad[3].2),
                outward: outward, colour: colour, into: &corners)
        }
    }

    /// 輪 (車輪)。**軸は x 方向**なので、置く側は `rotateX` で回せる。
    static func wheel(
        at centre: SIMD3<Float>, radius: Float, width: Float, detail: Int,
        tread: SIMD3<Float>, mark: SIMD3<Float>, into corners: inout [Corner]
    ) {
        let half = width / 2
        for step in 0..<detail {
            let a = Float(step) / Float(detail) * 2 * Float.pi
            let b = Float(step + 1) / Float(detail) * 2 * Float.pi
            let ringA = SIMD3<Float>(0, cos(a), sin(a))
            let ringB = SIMD3<Float>(0, cos(b), sin(b))
            // **1 か所だけ色を変える。** 回っていることが目で分かるように
            let colour = step % detail == 0 ? mark : tread
            let outward = simd_normalize((ringA + ringB) / 2)
            face(
                centre + ringA * radius - SIMD3(half, 0, 0),
                centre + ringB * radius - SIMD3(half, 0, 0),
                centre + ringB * radius + SIMD3(half, 0, 0),
                centre + ringA * radius + SIMD3(half, 0, 0),
                outward: outward, colour: colour, into: &corners)
            // 側面は三角形で埋める (中心へ畳む)
            for side in [Float(-1), 1] {
                let lid = centre + SIMD3(half * side, 0, 0)
                face(
                    lid, lid + ringA * radius, lid + ringB * radius, lid,
                    outward: SIMD3(side, 0, 0), colour: colour, into: &corners)
            }
        }
    }
}
