import mokume

/// Processing の [Keyboard Functions](https://processing.org/examples/keyboardfunctions/) を 1 行ずつ移したもの。
/// 原典は Martin Gomez 作。
///
/// **台帳は `bend` と言った。実際にはここで止まっている。**
/// `Keyboard` と同じで**キーの出来事を受ける口が無い** ([#723](https://github.com/mokume-metal/mokume/issues/723))。
/// 加えて `colorMode(HSB, numChars)` — 色相を 0〜26 で数える目盛り — も書けないので、
/// 面の外で畳んでいる。
///
/// 押されないので `newletter` は立たず、面は背景のままになる。
final class KeyboardFunctions: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Keyboard Functions")

    private let maxHeight: Float = 40
    private let minHeight: Float = 20
    private var letterHeight: Float = 40    // 文字の高さ
    private let letterWidth: Float = 20     // 文字の幅
    private var x: Float = -20              // 文字の横の位置
    private var y: Float = 0                // 文字の縦の位置
    private var newletter = false
    private let numChars = 26               // アルファベットは 26 文字
    private var colors: [LinearRGBA] = []

    func setup() {
        noStroke()
        // 原典はここで `colorMode(HSB, numChars)` を呼ぶ。**書けない**ので目盛りを畳む
        background(hsb(Float(numChars) / 2, Float(numChars), Float(numChars),
                       max: (Float(numChars), Float(numChars), Float(numChars))))
        // キーごとに色相を決める
        colors = (0..<numChars).map {
            hsb(Float($0), Float(numChars), Float(numChars),
                max: (Float(numChars), Float(numChars), Float(numChars)))
        }
    }

    func draw() {
        if newletter == true {
            let yPos: Float
            if letterHeight == maxHeight {
                yPos = y
                rect(x, yPos, letterWidth, letterHeight)
            } else {
                yPos = y + minHeight
                rect(x, yPos, letterWidth, letterHeight)
                fill(gray(Float(numChars) / 2))
                rect(x, yPos - minHeight, letterWidth, letterHeight)
            }
            newletter = false
        }
    }

    // 原典はここに `void keyPressed()` を持ち、押された文字の位置と色を決める。
    // **受ける口が無い**ので、この例を動かす側が丸ごと移せない
}
