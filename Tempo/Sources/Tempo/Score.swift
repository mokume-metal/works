import Foundation

/// 譜面。**時刻とカットの対応表**で、絵はここから導く。
///
/// 1 拍 = 0.5 秒 (120 BPM)、8 小節 = 32 拍 = 16 秒でひと回り。時刻の単位は秒ではなく
/// **拍**である — 秒で書くと「4 拍目で切り替わる」が 2.0 という無名の数になり、
/// 譜面を読み替えるたびに全部の定数を掛け直すことになる。
enum Score {
    /// 1 分あたりの拍数。
    static let bpm: Float = 120
    /// 1 拍の長さ (秒)。
    static let secondsPerBeat: Float = 60 / bpm
    /// ひと回りの拍数。
    static let beatsPerLoop: Float = 32
    /// 1 小節の拍数。
    static let beatsPerBar: Float = 4
    /// ひと回りの長さ (秒)。
    static let loopSeconds: Float = beatsPerLoop * secondsPerBeat

    /// 場面。**5 つで 1 回り。**
    enum Cut: Int, CaseIterable {
        case count, rise, tiles, extrude, fold

        /// 観測と手引きに出す名前。
        var name: String {
            switch self {
            case .count: "COUNT"
            case .rise: "RISE"
            case .tiles: "TILES"
            case .extrude: "EXTRUDE"
            case .fold: "FOLD"
            }
        }
    }

    /// 場面ひとつの持ち時間。
    struct Span {
        let cut: Cut
        /// 始まる拍。
        let from: Float
        /// 終わる拍 (次の場面が始まる拍と同じ)。
        let to: Float

        var length: Float { to - from }
    }

    /// 譜面そのもの。**隙間も重なりも作らない** — 前の `to` が次の `from` である。
    static let spans: [Span] = [
        Span(cut: .count, from: 0, to: 4),
        Span(cut: .rise, from: 4, to: 12),
        Span(cut: .tiles, from: 12, to: 20),
        Span(cut: .extrude, from: 20, to: 28),
        Span(cut: .fold, from: 28, to: 32),
    ]

    /// ひと回りの中へ畳む。**負の拍も畳む** (擦って頭より前へ出たとき)。
    static func wrap(_ beat: Float) -> Float {
        let folded = beat.truncatingRemainder(dividingBy: beatsPerLoop)
        return folded < 0 ? folded + beatsPerLoop : folded
    }

    /// その拍が属する場面。
    static func span(at beat: Float) -> Span {
        let beat = wrap(beat)
        for span in spans where beat >= span.from && beat < span.to { return span }
        return spans[spans.count - 1]
    }

    /// 場面の中の進み (0…1)。
    static func local(_ beat: Float, in span: Span) -> Float {
        guard span.length > 0 else { return 0 }
        return max(0, min(1, (wrap(beat) - span.from) / span.length))
    }

    /// 拍の中の位相 (0…1)。0 が拍頭。
    static func phase(_ beat: Float) -> Float {
        let beat = wrap(beat)
        return beat - beat.rounded(.down)
    }

    /// 何拍目か (0 から数える)。
    static func index(_ beat: Float) -> Int { Int(wrap(beat).rounded(.down)) }

    /// 打点の強さ。拍頭で 1、`decay` 拍かけて 0 へ落ちる。
    ///
    /// **拍そのものではなく、拍からの距離で作る。** こうしておくと擦って時間を戻しても
    /// 同じ拍では同じ強さになる — 「叩いたことを覚えている」形にすると、そこで純関数で
    /// なくなる。
    static func attack(_ beat: Float, decay: Float = 0.34) -> Float {
        guard decay > 0 else { return 0 }
        return max(0, 1 - phase(beat) / decay)
    }
}
