import Foundation
import simd

/// 一人称の体 — 歩き、落ち、ぶつかる。
///
/// ## 体は 60 × 180 の柱である
///
/// 足元の中心を持ち、そこから幅 60・高さ 180 の箱が立つ。目は 162 の高さ (Minecraft と
/// 同じ 1.62 m)。**箱で持つので、角に斜めから入っても 1 軸ずつ止まる。**
///
/// ## 当たりは軸ごとに解く
///
/// x・y・z を別々に動かし、動かした軸だけを見て、ぶつかっていたら戻す。**まとめて
/// 動かして 1 回で解こうとすると、壁を擦りながら歩けない** — 壁沿いに前へ進もうとした
/// とき、x が止まると z も一緒に止まってしまう。
///
/// ## 段は自分で登る
///
/// 水平に進めなかったとき、60 だけ持ち上げてもう一度試す。**通れば登る** — これが
/// 無いと 1 段の段差のたびに跳ばされ、掘った穴から出られなくなる
final class Walker {
    /// 体の幅 (単位)。
    static let girth: Float = 60
    /// 体の高さ (単位)。
    static let stature: Float = 180
    /// 目の高さ (単位)。
    static let eyeLevel: Float = 162
    /// 自分で登れる段の高さ (単位)。**0.6 ブロック。**
    static let stepUp: Float = 60

    /// 歩く速さ (単位/秒)。**4.3 m/s** — Minecraft の歩きと同じ。
    static let pace: Float = 430
    /// 重力 (単位/秒²)。**32 m/s²** — 地球の 3 倍強。ボクセルの世界はこれくらい急がないと
    /// 跳んでいる時間が長すぎて、掘る手が止まる
    static let gravity: Float = 3200
    /// 跳ぶ初速 (単位/秒)。**1.1 ブロックぶん上がる。**
    static let leap: Float = 840
    /// 水の中の落ちる速さの上限 (単位/秒)。
    static let sinking: Float = 160
    /// 水を掻いて上がる速さ (単位/秒)。
    static let paddle: Float = 260

    /// 足元の中心 (単位・y 上向き)。
    var place: SIMD3<Float>
    /// いまの速さ (単位/秒)。
    var speed = SIMD3<Float>(repeating: 0)
    /// 水平の向き (ラジアン)。**0 で +z を向く。**
    var yaw: Float = 0
    /// 上下の向き (ラジアン)。真上と真下は覗かせない。
    var pitch: Float = 0
    /// 地面に足が付いているか。
    private(set) var grounded = false
    /// 目が水に沈んでいるか。
    private(set) var submerged = false

    init(place: SIMD3<Float>) { self.place = place }

    /// 目の位置。
    var eye: SIMD3<Float> { place + SIMD3(0, Self.eyeLevel, 0) }

    /// 視線の向き (単位ベクトル)。
    var heading: SIMD3<Float> {
        SIMD3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
    }

    /// 水平の前と右。**歩くのは常に水平** — 上を向いても浮き上がらない。
    var footing: (forward: SIMD3<Float>, right: SIMD3<Float>) {
        let forward = SIMD3<Float>(sin(yaw), 0, cos(yaw))
        return (forward, SIMD3(-cos(yaw), 0, sin(yaw)))
    }

    /// 視線を回す。**上下は ±88 度で止める** — 真上を越えると左右が反転して酔う。
    func turn(by delta: SIMD2<Float>) {
        yaw -= delta.x * 0.005
        pitch = min(max(pitch - delta.y * 0.005, -1.535), 1.535)
    }

    /// 1 フレーム進める。
    ///
    /// - Parameters:
    ///   - wish: 行きたい向き (前後・左右、それぞれ −1…1)
    ///   - jump: 跳ぶ (水の中では掻いて上がる)
    func step(dt: Float, wish: SIMD2<Float>, jump: Bool, in world: World) {
        let feet = world.at(place + SIMD3(0, 10, 0))
        let swimming = feet == .water
        submerged = world.at(eye) == .water

        // 行きたい向きへ。**水の中は 6 割の速さ**
        let ground = footing
        var push = ground.forward * wish.x + ground.right * wish.y
        if simd_length(push) > 1 { push = simd_normalize(push) }
        let pace = Self.pace * (swimming ? 0.6 : 1)
        speed.x = push.x * pace
        speed.z = push.z * pace

        // 落ちる
        if swimming {
            speed.y -= Self.gravity * 0.16 * dt
            speed.y = max(speed.y, -Self.sinking)
            if jump { speed.y = Self.paddle }
        } else {
            speed.y -= Self.gravity * dt
            if jump, grounded { speed.y = Self.leap }
        }
        // 落ちる速さの上限。**1 フレームで 1 ブロックを越えさせない** (すり抜ける)
        speed.y = max(speed.y, -4800)

        slide(by: speed * dt, in: world)
    }

    // MARK: - ぶつかる

    /// 軸ごとに動かして押し戻す。
    private func slide(by delta: SIMD3<Float>, in world: World) {
        // 横。**止まったら段を登れないか試す**
        let before = place
        place.x += delta.x
        if blocked(in: world) { place.x = before.x }
        place.z += delta.z
        if blocked(in: world) { place.z = before.z }

        if place.x == before.x || place.z == before.z {
            climb(from: before, by: delta, in: world)
        }

        // 縦
        place.y += delta.y
        if blocked(in: world) {
            place.y = before.y
            // 落ちていたなら着地、昇っていたなら頭を打った
            grounded = delta.y < 0
            speed.y = 0
        } else {
            grounded = false
        }
    }

    /// 段を登る。**持ち上げて通れたときだけ、その高さを採る。**
    private func climb(from before: SIMD3<Float>, by delta: SIMD3<Float>, in world: World) {
        guard grounded else { return }
        let saved = place
        place = SIMD3(before.x + delta.x, before.y + Self.stepUp, before.z + delta.z)
        if blocked(in: world) {
            place = saved
            return
        }
        // 登った先に足場があるか。**空中へ踏み出させない**
        var probe = place
        probe.y -= Self.stepUp * 0.8
        let standing = world.at(probe + SIMD3(0, -6, 0)).isSolid
        if !standing { place = saved }
    }

    /// いまの箱が固いものと重なっているか。
    private func blocked(in world: World) -> Bool {
        let half = Self.girth / 2
        let low = SIMD3(place.x - half, place.y, place.z - half)
        let high = SIMD3(place.x + half, place.y + Self.stature, place.z + half)

        // **端は 1 だけ内側を見る。** ちょうど境に立っているとき、隣のブロックまで
        // 数えると壁が厚くなって隙間を通れない
        let x0 = World.cell(low.x + 1)
        let x1 = World.cell(high.x - 1)
        let y0 = World.cell(low.y + 1)
        let y1 = World.cell(high.y - 1)
        let z0 = World.cell(low.z + 1)
        let z1 = World.cell(high.z - 1)

        for y in y0...y1 {
            for z in z0...z1 {
                for x in x0...x1 where world.at(x, y, z).isSolid { return true }
            }
        }
        return false
    }
}
