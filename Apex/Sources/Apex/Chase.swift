import Foundation
import simd

/// 追いかけるカメラ。
///
/// ## 車に付く
///
/// 目は車の後ろ、注視点は**車の鼻先のさらに前**に置く。舵を切れば視界が一緒に回り、
/// 画面の奥がいつも車の進む先になる。
///
/// 以前は注視点を**コースの先**へ 6 割寄せていた。コーナーでは視線が勝手に内へ回り
/// 込んで見栄えはよかったが、**舵を切っても視界が回らず、車だけが画面の中で回った** —
/// 自分が向けた先が画面の奥に来ないので、どれだけ切ればよいかが読めなかった (#88)。
///
/// ## 滑ったときに何が見えるか
///
/// カメラが居るのは「車の向き」と「進んでいる向き」の**間**である。車の真後ろ (0) だと
/// 滑るたびに世界が振り回されて酔い、経路の真後ろ (1) だと車が画面を横切って滑る。
/// **0.3 は車の向きに寄せた中間**で、尻が出れば車の横腹が少し見え、向けた先は画面の
/// 奥に残る。
///
/// ## 硬さは時定数で決める
///
/// `mix(いま, 狙い, 0.1)` と書くと、**速い機械ほどカメラが硬くなる**。
/// `1 − exp(−dt/τ)` で追えば、フレームの長さによらず同じ追い方になる。目が少し遅れて
/// 付いてくるので、曲がり始めに車の向きが画面の中で先に変わり、回っていることが読める
struct Chase {
    /// 車の向きと進む向きのどちらへ寄るか。
    static let blend: Float = 0.3
    /// 目と注視点の時定数 (秒)。**注視点のほうを速く追わせる** — 遅いと、
    /// コーナーで視線が外側に取り残される
    static let eyeTau: Float = 0.16
    static let lookTau: Float = 0.10

    var eye = SIMD3<Float>(repeating: 0)
    var look = SIMD3<Float>(repeating: 0)
    /// 視野角 (ラジアン)。
    var lens = Math.radians(62)

    /// いきなり狙いの場所へ置く (始まりとやり直しのとき)。
    mutating func snap(to car: Car, on track: Track) {
        let wanted = frame(for: car, on: track)
        eye = wanted.eye
        look = wanted.look
        lens = wanted.lens
    }

    /// 1 フレーム追う。
    ///
    /// - Parameter jitter: −0.5…0.5 の揺らぎ。**路面の粗さを手に見せる**ために使う
    mutating func follow(_ car: Car, on track: Track, dt: Float, jitter: Float) {
        let wanted = frame(for: car, on: track)
        eye += (wanted.eye - eye) * Math.chase(dt, Chase.eyeTau)
        look += (wanted.look - look) * Math.chase(dt, Chase.lookTau)
        lens += (wanted.lens - lens) * Math.chase(dt, 0.25)

        // 揺れ。**舗装では静かで、外へ出るほど荒れる**
        let amp: Float
        switch car.surface.grip {
        case 0.9...: amp = 1.2
        case 0.7..<0.9: amp = 3.5
        default: amp = 5.0
        }
        let sway = Track.side(car.yaw) * (jitter * amp * Math.ramp(abs(car.pace), 0, 500))
        eye.x += sway.x
        eye.z += sway.y

        // **地面へ潜らせない。** 丘を下るとき、目だけが坂の中へ入ることがある
        let under = track.frame(at: car.s - 90).height
        eye.y = max(eye.y, under + 14)
    }

    /// いまの狙い。
    private func frame(for car: Car, on track: Track) -> (eye: SIMD3<Float>, look: SIMD3<Float>, lens: Float) {
        let pace = abs(car.pace)
        let fast = Math.ramp(pace, 0, 500)

        // 進んでいる向き。**止まっているときは車の向き** (速度が 0 だと角が決まらない)
        let course = car.speed > 30 ? atan2(car.velocity.x, car.velocity.y) : car.yaw
        let aim = Math.mixAngle(car.yaw, course, Chase.blend)

        let ground = track.frame(at: car.s).height
        let behind = Track.forward(aim) * (78 + 26 * fast)
        let eye = SIMD3(
            car.place.x - behind.x, ground + 30 + 6 * fast, car.place.y - behind.y)

        // **注視点は鼻先の前。** 速いほど遠くを見る
        let target = car.place + Track.forward(aim) * (120 + 0.3 * pace)
        let look = SIMD3(target.x, ground + 12, target.y)

        // **視野角は速さで広がる。** 速度計を見なくても速さが分かる、いちばん効く仕掛け
        let lens = Math.radians(62 + 12 * Math.ramp(pace, 180, 500))
        return (eye, look, lens)
    }
}
