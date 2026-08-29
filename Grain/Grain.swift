import Foundation
import mokume

/// 木目 — 挽いた板を並べた面。
///
/// 板は 1 枚ずつ別の木から挽いたものとして作る (種が違えば芯の位置も節も違う)。
/// 木目そのものは焼いた絵として持ち、継ぎ目と光は描画の側で置く。
final class Grain: Sketch {
    var settings = SketchSettings(width: 1280, height: 720, title: "grain")

    /// 板の枚数。
    private let plankCount = 6
    /// 焼いた木目。**毎フレーム作らない** — 板は動かないので 1 度でよい
    private var surface: Image?

    func setup() {
        surface = bakeSurface()
    }

    func draw() {
        background(.display(red: 0.05, green: 0.045, blue: 0.04))

        guard let surface else { return }
        imageMode(.corner)
        image(surface, 0, 0)

        drawSeams()
        drawSheen()
    }

    // MARK: - 木目を焼く

    /// 面ぜんぶを 1 枚の絵にする。
    ///
    /// 板の境目は絵の中では跨がない — 板ごとに座標を 0…1 へ畳んでから色を出すので、
    /// 隣り合う板で模様が続いてしまうことがない。
    private func bakeSurface() -> Image? {
        guard let image = try? createImage(Int(width), Int(height)) else { return nil }
        let planks = (0..<plankCount).map { Plank.make(seed: Int32($0) &* 977 &+ 13) }
        let plankHeight = height / Float(plankCount)

        for y in 0..<image.height {
            let fy = Float(y)
            let index = min(Int(fy / plankHeight), plankCount - 1)
            // 板の中での縦位置 (0…1)
            let localY = (fy - Float(index) * plankHeight) / plankHeight
            let plank = planks[index]
            for x in 0..<image.width {
                let localX = Float(x) / width
                image.set(x, y, plank.colour(atX: localX, y: localY))
            }
        }
        return image
    }

    // MARK: - 継ぎ目

    /// 板と板のあいだ。溝の影と、縁に当たる細い光。
    private func drawSeams() {
        let plankHeight = height / Float(plankCount)
        noFill()
        for index in 1..<plankCount {
            let y = Float(index) * plankHeight

            // 溝そのもの — 下地を暗くする
            blendMode(.multiply)
            stroke(.display(red: 0.35, green: 0.30, blue: 0.26))
            strokeWeight(3)
            line(0, y, width, y)

            // 溝の下の縁が光を拾う
            blendMode(.add)
            stroke(.display(red: 0.16, green: 0.13, blue: 0.10, alpha: 0.9))
            strokeWeight(1)
            line(0, y + 2, width, y + 2)
        }
        blendMode(.blend)
    }

    // MARK: - 光

    /// 上から差す定常の光。これが無いと、板の面が平らな見本のままになる。
    private func drawDaylight() {
        blendMode(.multiply)
        noStroke()
        rectMode(.corner)
        let bands = 64
        for band in 0..<bands {
            let t = Float(band) / Float(bands - 1)
            // 上が明るく、下へ向かって落ちる
            let level = 1 - t * 0.34
            fill(.display(red: level, green: level * 0.995, blue: level * 0.985))
            rect(0, t * height, width, height / Float(bands) + 1)
        }
        blendMode(.blend)
    }

    /// 斜めに横切る淡い光の帯。時間で位置が動く。
    ///
    /// フレーム番号から位相を作るので、同じフレームなら同じ位置に来る。
    private func drawSheen() {
        drawDaylight()

        let phase = Float(frameCount) * 0.0016
        let travel = (phase - floorf(phase)) * (width * 2.2) - width * 0.6

        push()
        blendMode(.add)
        noStroke()
        translate(travel, height * 0.5)
        rotate(-0.42)
        // 中心が明るく、縁へ向かって細く暗い帯を重ねる
        for step in 0..<22 {
            let t = Float(step) / 21
            let bandWidth = 40 + t * 640
            // **足し込みは飽和する。** 強くすると木目ごと白く飛んで、
            // 艶ではなく光の筋が乗っているように見える
            let strength = (1 - t) * (1 - t) * 0.014
            fill(.display(red: 1.0, green: 0.94, blue: 0.80, alpha: strength))
            rectMode(.center)
            rect(0, 0, bandWidth, height * 2.6)
        }
        pop()
        blendMode(.blend)

        // 四隅を落として面を締める。**枠を重ねる** — 塗り潰しを重ねると
        // 内側ほど多く掛かって、中央が暗い逆の絵になる
        blendMode(.multiply)
        noFill()
        let steps = 44
        for step in 0..<steps {
            let t = Float(step) / Float(steps - 1)
            let inset = t * 200
            // 縁がいちばん濃く、内へ向かって効かなくなる
            let darkness = 1 - (1 - t) * (1 - t) * 0.05
            stroke(.display(red: darkness, green: darkness, blue: darkness))
            strokeWeight(200 / Float(steps) + 1.5)
            rectMode(.corner)
            rect(inset, inset, width - inset * 2, height - inset * 2)
        }
        blendMode(.blend)
    }
}
