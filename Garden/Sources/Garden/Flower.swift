import mokume

/// 花 1 本。
///
/// 原典 (p5.js の Data Structure Garden) が最初に置くオブジェクトをそのまま写す:
///
/// ```javascript
/// let flower = {
///   x: random(20, 380),
///   y: random(20, 380),
///   size: random(20, 75),
///   lifespan: random(255, 300),
///   color: color(random(255), random(255), random(255)),
/// };
/// ```
///
/// **JavaScript は形を宣言しないが、Swift は宣言する。** 書く量は 5 行増えるかわりに、
/// 綴りを間違えた欄はビルドで落ちる — 原典で `flower.sizee` を読んでも `undefined` が
/// 静かに流れてしまうのと対照的である。チュートリアルが「オブジェクトとは名前と値の
/// 組である」を教える場所は、Swift では型の宣言そのものになる。
struct Flower {
    /// 横位置 (面の座標。左が 0)。
    var x: Float
    /// 縦位置 (面の座標。**上が 0** — p5 と同じ向き)。
    var y: Float
    /// 大きさ。萎れるにつれて縮む。
    var size: Float
    /// 残りの寿命 (フレーム数)。0 以下になったら抜かれる。
    var lifespan: Float
    /// 花びらの色。
    ///
    /// 原典の `color(r, g, b)` に当たる。`v0.6.0` から mokume の `color(_:_:_:)` も
    /// **0…255** を受けるので、原典の数がそのまま渡せる。型は ``LinearRGBA`` 1 つで、
    /// 0…1 で書きたいときは `LinearRGBA.display` が残っている。
    var color: LinearRGBA
}
