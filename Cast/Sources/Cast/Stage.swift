import Foundation
import mokume
import simd

/// 見る場所・光・影の設定。
///
/// ## 影を落とせる光は 1 本しかない
///
/// mokume で影を落とすのは**向きを持つ光 (`directionalLight`) の 1 本目だけ**である。
/// 点光源もスポットも、置けば明るくはなるが影は落とさない。この作品は影が主題なので、
/// **光は 1 本しか置かない** — 2 本目を足すと、影を落とさない光が絵を持ち上げて
/// 影の濃さだけが薄くなる。
///
/// ## 影の焼き付けは注視点のまわりを切り取る
///
/// 焼き付けは「光から見た平行投影」で、中心は**いまのカメラの注視点**、一辺は
/// ``range``。切り取った外は「遮られていない」として返るので、**足りないと影が
/// 四角く切れる**。逆に広げると 1 画素あたりの世界が広がって縁が階段になる。
/// ここでは塊と影の両方が入る最小の箱を、寸法から計算して渡している。
///
/// ## 余裕 (`shadowBias`) は範囲に比例する
///
/// 余裕は焼いた奥行き (0…1) に対して引かれるので、**世界での大きさは
/// `bias × 2 × range`** になる。範囲が広いほど同じ `bias` が太く効き、影が形から
/// 離れて浮く。既定の 0.0025 はこの場面では太すぎたので下げてある。
enum Stage {
    /// 目の位置 (世界・y は上向き)。
    /// 目の位置 (世界・y は上向き)。
    ///
    /// **見下ろす角度は影の読みやすさそのもの**である。床の円は、見下ろす角度 θ の
    /// 楕円 (短軸 / 長軸 = sin θ) になる — 45 度だと 0.71 で、円と四角の見分けが
    /// 「潰れ方の違い」になってしまう。67 度なら 0.92 で、円は円に見える。
    /// 真上から見れば歪みは消えるが、そのときは塊が板にしか見えない。
    static let eye = SIMD3<Float>(-150, 2500, 1100)
    /// 注視点。**塊と影の間**に置く — どちらも画面の中ほどに入る。
    static let target = SIMD3<Float>(-360, 300, 0)
    /// 視野 (度)。
    static let fieldOfView: Float = 44

    /// 焼き付けの細かさ。
    static let detail = 4096
    /// 焼き付けの余裕。
    static let bias: Float = 0.0006

    /// 焼き付ける箱の一辺。**塊と床の狙いが両方入る最小**を寸法から出す。
    static var range: Float {
        let mass = SIMD3<Float>(
            Field.axis.x, Field.centerHeight, Field.axis.y)
        let corner = SIMD3<Float>(Field.extent, Field.height / 2, Field.extent)
        var far: Float = 0
        for sx in [-1, 1] as [Float] {
            for sy in [-1, 1] as [Float] {
                for sz in [-1, 1] as [Float] {
                    let point = mass + SIMD3(corner.x * sx, corner.y * sy, corner.z * sz)
                    far = max(far, length(point - target))
                }
            }
        }
        // 床の狙い (原点まわり) も入れる
        far = max(far, length(SIMD3<Float>(Field.unit * 1.6, 0, Field.unit * 1.6) - target))
        return far * 2 * 1.04
    }
}

extension Cast {
    /// 見る場所と光を置き、床を敷く。**毎フレーム全部書く** — 影の設定は
    /// フレームを越えないので、1 度書いて済ませることができない。
    func stage() {
        background(Palette.paper)

        // **縦軸は下向き**なので、世界の y を負にして渡す (Quarry と同じ約束)
        camera(
            Stage.eye.x, -Stage.eye.y, Stage.eye.z,
            Stage.target.x, -Stage.target.y, Stage.target.z,
            0, 1, 0)
        perspective(Stage.fieldOfView * .pi / 180, width / height, 20, 9000)

        // 光は 1 本だけ。底上げの光は**影の濃さそのもの**を決める
        // **光の強さは 0…1 の割合で渡す** (`LinearRGBA`)。塗りと同じ 0…255 のつもりで
        // 書くと、0.5 が「255 分の 0.5」になって画面が真っ黒になる
        ambientLight(.linear(red: 0.52, green: 0.52, blue: 0.53))
        let direction = Shear.lightDirection
        directionalLight(
            .linear(red: 0.86, green: 0.85, blue: 0.81), direction.x, direction.y, direction.z)

        shadows(true)
        shadowDetail(Stage.detail)
        shadowRange(Stage.range)
        shadowBias(Stage.bias)

        noStroke()
        shininess(0)

        // 床。**受けるだけで落とさない** — 落とす側に入れると自分の影で暗くなる
        castShadow(false)
        // 材質の受け止め方は塗りと同じ 0…255。**床の底上げを抑えるほど影が濃くなる** —
        // 影が薄くするのは向きを持つ光のぶんだけなので、底上げの光がそのまま影の明るさになる
        ambient(104, 104, 108)
        fill(Palette.ground)
        push()
        rotateX(Float.pi / 2)
        plane(Field.floorSpan, Field.floorSpan)
        pop()
    }

    /// 塊を置く。
    func place(_ mass: Shape, turn: Float) {
        castShadow(true)
        // **塊は影を受けない。** 凸な塊なので自分に落ちる影は無いはずだが、光と平行に
        // 近い面には焼いた 1 画素の中の奥行きの差が縞 (アクネ) として出る。受け取りを
        // 切ると消え、絵は何も失わない
        receiveShadow(false)
        // **塊は底上げの光をよく返す。** 影が主題なので、塊そのものは地に沈めたい
        ambient(228, 228, 232)
        fill(Palette.mass.x, Palette.mass.y, Palette.mass.z)
        push()
        translate(Field.axis.x, -Field.centerHeight, Field.axis.y)
        rotateY(turn)
        shape(mass)
        pop()
        castShadow(false)
        receiveShadow(true)
    }
}
