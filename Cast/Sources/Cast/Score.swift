import Foundation

/// 譜 — **時刻を渡すと、その瞬間の全部が決まる。**
///
/// 48 秒でひと回りする 4 つの幕。`frame(at:)` が返す ``Score/Frame`` に、塊の姿勢も
/// 光の方位も粒の散り方もカメラの引きも入っている。**絵はこの構造体だけの関数**で、
/// ここから下は時計を読まない。
///
/// ## 4 つの幕は 4 つの作品ではない
///
/// 出来事は違うが、どれも**同じ 1 つの式**の見え方である — 影は
/// `(X, Z) + κ·Y·e` という「高さに比例した平行移動」でしかない (``Shear``)。
///
/// | 幕 | 秒 | 何が起きるか | 式のどこを見ているか |
/// | --- | --- | --- | --- |
/// | 影 | 0–6 | 空の床に影だけがあり、塊が透けて現れる | **影は物の不透明さを見ない** (焼き付けは深さだけを見る) |
/// | 姿勢 | 6–18 | 塊が 3 つの姿勢を渡る | `R_θ` を動かす |
/// | 粒 | 18–32 | 塊が立方体の群れへ砕け、光の筋に沿って伸び、ねじれ、また集まる | **`e` に沿って動かしても影は動かない**。光の軸のまわりに回せば、影も同じ角だけ回る |
/// | 光 | 32–48 | 塊は止まったまま、光の方位が 1 周する | `e` を動かす。**`e` を α 回すことは塊を −α 回すことと同じ** |
///
/// **幕 4 が落ちである。** 幕 2 では塊を回して 3 つの形を出したが、幕 4 では塊を
/// 1 度も動かさずに同じ 3 つが出る。作品が最初から「光の側の話」だったことが、
/// そこで分かる。
enum Score {
    enum Act: Int, CaseIterable {
        case shadow, turn, grains, sun

        var name: String {
            switch self {
            case .shadow: "SHADOW"
            case .turn: "TURN"
            case .grains: "GRAINS"
            case .sun: "SUN"
            }
        }

        /// その幕が始まる時刻と終わる時刻。
        var span: (from: Float, to: Float) {
            switch self {
            case .shadow: (0, 6)
            case .turn: (6, 18)
            case .grains: (18, 32)
            case .sun: (32, 48)
            }
        }
    }

    /// ひと回りの長さ (秒)。
    static let loop: Float = 48

    /// その瞬間の全部。**絵はこれだけの関数**である。
    struct Frame {
        var time: Float
        var act: Act
        /// 幕の頭からの秒。
        var local: Float
        /// 塊の姿勢 (ラジアン)。
        var turn: Float
        /// 光の方位 (ラジアン)。
        var azimuth: Float
        /// 塊の濃さ (0…1)。**0 でも影は落ちる** (``Frame/present``)。
        var mass: Float
        /// 塊がそこに在るか。**透けていても影は落とす**ので、濃さとは別に持つ。
        var present: Bool
        /// 粒の濃さ (0…1)。
        var grains: Float
        /// 光の筋に沿って伸びる量 (0…1)。
        var spread: Float
        /// 光の筋に沿って波打つ量 (0…1)。**影は 1 ミリも動かない。**
        var wave: Float
        /// カメラの引き (0…1)。
        var pull: Float
    }

    static func wrap(_ time: Float) -> Float {
        let folded = time.truncatingRemainder(dividingBy: loop)
        return folded < 0 ? folded + loop : folded
    }

    static func act(at time: Float) -> Act {
        let t = wrap(time)
        for act in Act.allCases where t >= act.span.from && t < act.span.to { return act }
        return .sun
    }

    /// 時刻から、その瞬間の全部を導く。
    static func frame(at time: Float) -> Frame {
        let t = wrap(time)
        let act = act(at: t)
        let local = t - act.span.from

        var turn: Float = 0
        var azimuth: Float = 0
        var mass: Float = 1
        var grains: Float = 0
        var spread: Float = 0
        var wave: Float = 0
        var pull: Float = 0

        switch act {
        case .shadow:
            // **影が先にあって、物が後から来る。** 2.4 秒は影だけ
            mass = smooth(window(local, 2.4, 5.4))

        case .turn:
            turn = Turn.angle(at: local)

        case .grains:
            // 砕ける → 光の筋に沿って伸びる → ねじれる → 戻る → 塊へ。
            // **姿勢は三角へ振る** — 円は回しても円のままなので、ねじった影が
            // 回っていることが見えない
            turn = 2 * Float.pi / 3
                * smooth(window(local, 0.4, 2.2))
                * (1 - smooth(window(local, 12.2, 13.8)))
            let broken = smooth(window(local, 0.4, 1.6))
            let mended = smooth(window(local, 12.2, 13.4))
            grains = broken * (1 - mended)
            mass = 1 - grains
            spread = smooth(window(local, 1.6, 4.6)) * (1 - smooth(window(local, 10.6, 12.2)))
            // **光の筋に沿って波打たせる。** 動く向きが筋と同じなので、これだけ暴れても
            // 床の絵は 1 ミリも動かない
            wave = smooth(window(local, 5.0, 6.2)) * (1 - smooth(window(local, 9.0, 10.2)))
            // 粒が伸びるぶんだけ引く。**引かないと粒が画面の外へ出る**
            pull = 0.55 * spread

        case .sun:
            azimuth = sweep(local)
            // 幕の終わりで塊を透明へ戻す。**継ぎ目は「影だけ」の絵**である
            mass = 1 - smooth(window(local, 14.2, 15.8))
            pull = smooth(window(local, 0.6, 3.0)) * (1 - smooth(window(local, 13.0, 15.4)))
        }

        // **粒へ砕けきった間だけ、塊は在ることをやめる。** それ以外は透けていても
        // 在り続け、影を落とす — 幕 1 の「影だけの床」はこれで出る
        let present = act == .grains ? mass > 0.004 : true

        return Frame(
            time: t, act: act, local: local, turn: turn, azimuth: azimuth, mass: mass,
            present: present, grains: grains, spread: spread, wave: wave, pull: pull)
    }

    /// 光の方位の譜。**止まりを 3 つ挟んで 1 周する** — 揃ったところで止まらないと、
    /// 形になる瞬間が通り過ぎる (幕 2 と同じ理由)。
    private static func sweep(_ local: Float) -> Float {
        let third = 2 * Float.pi / 3
        let legs: [(from: Float, to: Float)] = [(1.0, 4.6), (6.4, 10.0), (11.8, 15.0)]
        // **足し合わせる。** 区間ごとの到達角を `max` で取ると、まだ始まっていない
        // 区間の基準角が先に効いてしまう (方位が最初から 240 度になる)
        var angle: Float = 0
        for leg in legs {
            angle += Turn.ease(window(local, leg.from, leg.to)) * third
        }
        return angle
    }

    /// 窓を 0…1 へ写す。
    static func window(_ time: Float, _ from: Float, _ to: Float) -> Float {
        guard to > from else { return time >= to ? 1 : 0 }
        return min(max((time - from) / (to - from), 0), 1)
    }

    /// 端で速さが 0 になる滑らか。
    static func smooth(_ x: Float) -> Float {
        let t = min(max(x, 0), 1)
        return t * t * (3 - 2 * t)
    }

    /// 幕の頭の時刻。
    static func start(of act: Act) -> Float { act.span.from }
}
