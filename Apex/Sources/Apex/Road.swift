import Foundation
import simd

/// 路面を頂点の並びへ焼く。
///
/// **描かない。** Quarry の `Mesher` と同じで、ここは頂点の列を返すだけで、
/// `createShape` へ流すのはスケッチの側である (焼く場所を 1 か所に集めるため)。
///
/// ## 帯を並べるだけ
///
/// コースの断面は「中心線からの横ずれ `d`」の表でしかない。リングごとにこの表を
/// 並べ、隣り合うリングの間を四角で埋める。**縁石だけが少し持ち上がっていて**、
/// 路面と同じ高さに重ねていないので z が競らない
///
/// ## 絵を貼らない
///
/// 舗装に絵を繰り返し貼ると、**寝た面なので遠方で必ず滲んで踊る** (mokume の `Image` は
/// 縮小の段を持たない)。ここは頂点の色だけで組み、速度感は**縁石の縞** (2 m 周期)・
/// リングごとの陰の揺らぎ・視野角の広がりで出している
enum Road {
    /// 断面の帯の種類。
    enum Kind {
        case skirt  // 遠くの地面へ繋ぐ裾
        case grass
        case apron  // 路肩
        case kerb  // 縁石 — 縞になる
        case tarmac
    }

    /// 断面の帯 1 本。
    struct Band {
        /// 内側と外側の横ずれ・高さ足し。**左から右へ並べる。**
        var d0: Float
        var y0: Float
        var d1: Float
        var y1: Float
        var kind: Kind
        /// 外端をコースの高さに追従させず、**一定の高さへ落とす**か。
        ///
        /// 遠景の地面は平らなので、ここで繋がないと**丘のところだけ地面と裾の間に
        /// 隙間が開いて空が見える**
        var flatOuter = false
    }

    /// 断面 (内側の横ずれ・高さ足し → 外側の横ずれ・高さ足し)。**左から右へ並べる。**
    ///
    /// 縁石は路面の端 (±60) と路肩 (±70) の間を埋め、**外側が 3 単位高い**。
    /// 実車の縁石より高くしてあるのは、踏んだことが画面で分かるようにするため
    private static let bands: [Band] = [
        Band(d0: -1500, y0: 0, d1: -450, y1: -30, kind: .skirt, flatOuter: true),
        Band(d0: -450, y0: -30, d1: -110, y1: 0, kind: .skirt),
        Band(d0: -110, y0: 0, d1: -70, y1: 0, kind: .apron),
        Band(d0: -70, y0: 1.8, d1: -60, y1: 0.4, kind: .kerb),
        Band(d0: -60, y0: 0, d1: 60, y1: 0, kind: .tarmac),
        Band(d0: 60, y0: 0.4, d1: 70, y1: 1.8, kind: .kerb),
        Band(d0: 70, y0: 0, d1: 110, y1: 0, kind: .apron),
        Band(d0: 110, y0: 0, d1: 450, y1: -30, kind: .skirt),
        Band(d0: 450, y0: -30, d1: 1500, y1: 0, kind: .skirt, flatOuter: true),
    ]

    /// 遠景の地面の高さ (単位)。**平らな面なので、裾の外端をここへ落として繋ぐ。**
    static let groundLevel: Float = -220

    /// スタートラインの市松の目 (横 × 縦)。
    private static let checkers = (across: 12, along: 2)

    /// コース 1 周ぶんを焼く。
    ///
    /// - Parameter shade: リングごとの陰の揺らぎ。**雑音はスケッチの口なので外から渡す**
    static func bake(_ track: Track, shade: (Float) -> Float) -> [Corner] {
        var corners: [Corner] = []
        corners.reserveCapacity(track.count * bands.count * 6)

        for ring in 0..<track.count {
            let s0 = Float(ring) * track.ds
            let s1 = Float(ring + 1) * track.ds
            let near = track.frame(at: s0)
            let far = track.frame(at: s1)
            let dim = shade(s0)

            for band in bands {
                // **スタートラインだけは 1 枚の四角では出せない。** 別の板を重ねると
                // z が競るので、リング 0 の路面そのものを市松に割る
                if ring == 0, band.kind == .tarmac {
                    startLine(track, into: &corners)
                    continue
                }
                let colour = tint(band.kind, ring: ring, dim: dim, bend: near.curvature)
                quad(near: near, far: far, band: band, colour: colour, into: &corners)
            }
        }
        return corners
    }

    // MARK: - 1 枚ずつ

    /// 帯 1 枚を四角として置く。
    private static func quad(
        near: Track.Sample, far: Track.Sample, band: Band, colour: SIMD3<Float>,
        into corners: inout [Corner]
    ) {
        // **どちらの端が「外」かは符号で決まる。** 左右どちらの裾でも、
        // 中心から遠いほうを地面の高さへ落とす
        let flatA = band.flatOuter && abs(band.d0) > abs(band.d1)
        let flatB = band.flatOuter && abs(band.d1) > abs(band.d0)
        let a = point(near, d: band.d0, lift: band.y0, flat: flatA)
        let b = point(near, d: band.d1, lift: band.y1, flat: flatB)
        let c = point(far, d: band.d1, lift: band.y1, flat: flatB)
        let d = point(far, d: band.d0, lift: band.y0, flat: flatA)
        let normal = face(near: near, d0: band.d0, y0: band.y0, d1: band.d1, y1: band.y1)
        emit(a, b, c, d, normal: normal, colour: colour, into: &corners)
    }

    /// リング 0 の路面を市松に割る。**別の板を重ねないので z が競らない。**
    private static func startLine(_ track: Track, into corners: inout [Corner]) {
        let width = Track.halfWidth * 2
        for row in 0..<checkers.along {
            let s0 = (Float(row) / Float(checkers.along)) * track.ds
            let s1 = (Float(row + 1) / Float(checkers.along)) * track.ds
            let near = track.frame(at: s0)
            let far = track.frame(at: s1)
            for column in 0..<checkers.across {
                let d0 = -Track.halfWidth + width * Float(column) / Float(checkers.across)
                let d1 = -Track.halfWidth + width * Float(column + 1) / Float(checkers.across)
                let pale = (column + row) % 2 == 0
                let colour = pale ? Palette.line : Palette.asphaltDark
                let a = point(near, d: d0, lift: 0, flat: false)
                let b = point(near, d: d1, lift: 0, flat: false)
                let c = point(far, d: d1, lift: 0, flat: false)
                let e = point(far, d: d0, lift: 0, flat: false)
                let normal = face(near: near, d0: d0, y0: 0, d1: d1, y1: 0)
                emit(a, b, c, e, normal: normal, colour: colour, into: &corners)
            }
        }
    }

    /// 四角を三角形 2 枚として積む。**並べた順のまま表を向く。**
    private static func emit(
        _ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>, _ d: SIMD3<Float>,
        normal: SIMD3<Float>, colour: SIMD3<Float>, into corners: inout [Corner]
    ) {
        for point in [a, b, c, a, c, d] {
            corners.append(
                Corner(
                    x: point.x, y: point.y, z: point.z, nx: normal.x, ny: normal.y, nz: normal.z,
                    r: colour.x, g: colour.y, b: colour.z))
        }
    }

    /// 断面の 1 点を世界の点へ。
    private static func point(_ frame: Track.Sample, d: Float, lift: Float, flat: Bool)
        -> SIMD3<Float>
    {
        let across = frame.point + Track.side(frame.heading) * d
        return SIMD3(across.x, flat ? groundLevel : frame.height + lift, across.y)
    }

    /// 帯の法線。**横の傾きと縦の勾配の両方から起こす。**
    private static func face(near: Track.Sample, d0: Float, y0: Float, d1: Float, y1: Float)
        -> SIMD3<Float>
    {
        let side = Track.side(near.heading)
        let ahead = Track.forward(near.heading)
        let forward = simd_normalize(SIMD3(ahead.x, near.slope, ahead.y))
        let across = simd_normalize(SIMD3(side.x, (y1 - y0) / max(d1 - d0, 1e-4), side.y))
        return simd_normalize(simd_cross(forward, across))
    }

    /// 曲率がこれより小さいところは「直線」として扱う (半径 167 m)。
    private static let straight: Float = 0.0006

    /// 帯の色。
    private static func tint(_ kind: Kind, ring: Int, dim: Float, bend: Float) -> SIMD3<Float> {
        switch kind {
        case .tarmac: return Palette.tarmac * dim
        case .kerb:
            // **縞になるのは曲がっているところだけ。** 直線の両脇までずっと縞だと、
            // どこが曲がっているのかが遠目に読めなくなる
            guard abs(bend) > straight else { return Palette.line * 0.92 }
            // 2 m 周期。実車の縁石より粗いが、180 km/h ではこれくらいが読める
            return ring % 2 == 0 ? Palette.kerbWarm : Palette.kerbPale
        case .apron: return Palette.apron * dim
        case .grass: return Palette.grass * dim
        case .skirt: return Palette.field * dim
        }
    }
}
