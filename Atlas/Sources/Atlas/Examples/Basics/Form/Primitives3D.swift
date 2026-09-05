import mokume

/// Processing の [Primitives 3D](https://processing.org/examples/primitives3d/) を 1 行ずつ移したもの。
///
/// **台帳は `clean` と言った。当たっている** (色の書き下しを除く)。原典は静止形。
///
/// **原典を p5 で走らせられない 6 本のうちの 1 本。** site は代わりに 1280x720 の
/// 静止画を置いているので、比べるときはそれを縮めて使う (一致率は参考値になる)。
final class Primitives3D: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Primitives 3D")

    func setup() {
        background(gray(0))
        lights()
        noStroke()
        pushMatrix()
        translate(130, height / 2, 0)
        rotateY(1.25)
        rotateX(-0.4)
        box(100)
        popMatrix()
        noFill()
        stroke(gray(255))
        pushMatrix()
        translate(500, height * 0.35, -200)
        sphere(280)
        popMatrix()
    }
}
