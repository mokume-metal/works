import mokume

/// Processing の [Characters Strings](https://processing.org/examples/charactersstrings/) を 1 行ずつ移したもの。
///
/// **台帳は `blocked` と言った。当たっている。ここで半分止まっている。**
/// `createFont` の口が無いのでシステムの書体へ置き換えるところまでは書けるが、
/// **原典の主題である「打った文字が文字列に足されていく」ところが移せない** —
/// `keyTyped()` に当たる出来事の口が無い ([#723](https://github.com/mokume-metal/mokume/issues/723))。
/// 面には最初の "Begin..." が出たまま動かない。
///
/// **字形は環境で変わる**ので、原典と画素では比べられない。
final class CharactersStrings: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Characters Strings")

    private var letter = ""
    private var words = "Begin..."

    func setup() {
        // 原典は `textFont(createFont("SourceCodePro-Regular.ttf", 36))`。**書体を読めない**
        textFont("Menlo")
    }

    func draw() {
        background(0)
        textSize(14)
        text("Click on the program, then type to add to the String", 50, 50)
        text("Current key: \(letter)", 50, 70)
        text("The String is \(words.count) characters long", 50, 90)

        textSize(36)
        text(words, 50, 120, 540, 300)
    }

    // 原典はここに `void keyTyped()` を持ち、打たれた文字を words へ足す。
    // **受ける口が無い**ので、この例が見せたい動きが移せない
}
