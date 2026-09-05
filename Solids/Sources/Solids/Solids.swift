import Foundation
import mokume

/// 3D Geometries — p5.js の例を mokume へ移した立体の並び。
///
/// <https://p5js.org/examples/3D-Geometries/>
///
/// **作り替えず、1 行ずつ写している。** Garden と同じ流儀で、これは作品であると同時に
/// 物差しである — Garden が測ったのは 2D の入門語彙だけで、mokume が売りにしている
/// **立体の語彙は 1 つも測られていなかった**。原典は p5 の原形 7 つ (plane / box /
/// cylinder / cone / torus / sphere / ellipsoid) と `model()` を 1 画面に並べ、
/// 全部を毎フレーム 1 度ずつ 3 軸に回すだけなので、対応を測るには理想の形をしている。
///
/// 面 710x400・背景 250・8 つの区画の座標・毎フレーム 1 度、まで原典どおり。
/// 対応表は README にある。原典と違うのは次の 5 つで、どれも mokume 側の事情から出たもの:
///
/// 1. 面の中央を原点にするため、`translate(width / 2, height / 2, 0)` を 1 度置く
///    (p5 の WEBGL は面の中央が原点。mokume に描き方のモードは無く、原点は左上)
/// 2. 角度はラジアン (`angleMode()` が無い。度は `radians()` を通して渡す)
/// 3. `normalMaterial()` の代わりに断片を当てる (``NormalPaint``)
/// 4. `ellipsoid()` が無いので `scale` + `sphere` で作る
/// 5. モデルは自作のもの (原典は NASA の astronaut.obj を読む)
final class Solids: Sketch {
    var settings = SketchSettings(width: 710, height: 400, title: "solids")

    /// 原典の `normalMaterial()` の代わり。**無いので自分で書く** (``NormalPaint``)。
    private var normalPaint: Shader?

    /// 原典の `astronaut`。
    ///
    /// **原典と違うのはここだけ。** 測りたいのは `loadModel()` / `model()` が通るか
    /// であってモデルの形ではないので、NASA の astronaut.obj (523KB) は取り込まず、
    /// 向きの読める小さな矢じりを自分で書いた (`assets/arrowhead.obj`)。
    private var arrowhead: Model?


    func setup() {
        // 原典の `normalMaterial()` に当たるもの
        normalPaint = try? makeShader(NormalPaint.body, name: "normal")

        // 原典の `astronaut = await loadModel('/assets/astronaut.obj')`。
        //
        // **`normalize` の既定が原典と逆である。** p5 は整えないのが既定、mokume は
        // 整えるのが既定 (いちばん長い辺を面の短いほうの半分 = 200 画素へ) なので、
        // 既定のままだと区画 (175 画素おき) からはみ出す。原典に合わせて切る
        arrowhead = try? loadModel("assets/arrowhead.obj", normalize: false)
    }

    func draw() {
        // 原典の `background(250)`
        background(250)

        // 原典の `normalMaterial()` は setup で 1 度呼ぶだけだが、断片は掛け直す
        if let normalPaint { shader(normalPaint) }
        noStroke()
        // 断片は `in.color` を掛けずに使うが、`place()` は塗りが無いと何も置かない
        // (`hasFill`)。白を置いておく
        fill(255)

        // **原典に無い 1 行。** p5 の WEBGL は面の中央が原点だが、mokume に描き方の
        // モードは無く、立体も面と同じ左上の原点に置かれる。以下の区画の座標を
        // 原典のまま書けるように、ここで中央へ寄せる
        push()
        translate(width / 2, height / 2, 0)

        // Plane
        push()
        translate(-250, -100, 0)
        rotateWithFrameCount()
        // 原典は `plane(70)`。mokume に 1 引数の短縮形は無い
        plane(70, 70)
        pop()

        // Box
        push()
        translate(-75, -100, 0)
        rotateWithFrameCount()
        box(70, 70, 70)
        pop()

        // Cylinder
        push()
        translate(100, -100, 0)
        rotateWithFrameCount()
        cylinder(70, 70)
        pop()

        // Cone
        push()
        translate(275, -100, 0)
        rotateWithFrameCount()
        cone(50, 70)
        pop()

        // Torus
        push()
        translate(-250, 100, 0)
        rotateWithFrameCount()
        torus(50, 20)
        pop()

        // Sphere
        push()
        translate(-75, 100, 0)
        rotateWithFrameCount()

        // 原典はここで `stroke(0)` を置き、動きを見せるための黒い線を出す。
        // **組み込みの立体は線を持たない** ので、置いても何も変わらない (README)
        stroke(0)
        sphere(50)
        noStroke()
        pop()

        // Ellipsoid
        push()
        translate(100, 100, 0)
        rotateWithFrameCount()
        // 原典は `ellipsoid(20, 40, 40)`。**`ellipsoid()` が無い**ので、
        // 半径 1 の球を軸ごとに伸ばして作る
        scale(20, 40, 40)
        sphere(1)
        pop()

        // Arrowhead (原典は Astronaut)
        push()
        translate(275, 100, 0)
        rotateWithFrameCount()

        // 原典の「起こすための追加の回転」に当たるもの。**`normalize: false` では
        // 縦軸を裏返さない** (裏返すのは整える側の仕事) ので、OBJ の約束どおり
        // y を上向きに書いたモデルは、この面では逆さに出る
        rotateX(.pi)
        if let arrowhead { model(arrowhead) }
        pop()

        pop()
        resetShader()
    }

    /// 原典の `rotateWithFrameCount()` — 毎フレーム 1 度ずつ 3 軸に回す。
    ///
    /// 原典は `angleMode(DEGREES)` を宣言して `rotateZ(frameCount)` と書く。
    /// **mokume に `angleMode()` は無い** — 単位を切り替える状態を持たない作りなので、
    /// 度で考えた角は `radians()` を通して渡す (`v0.6.0` から面にある)。
    private func rotateWithFrameCount() {
        let degree = radians(Float(frameCount))
        rotateZ(degree)
        rotateX(degree)
        rotateY(degree)
    }
}
