/// 原典の `normalMaterial()` に当たるもの。
///
/// **mokume に `normalMaterial()` は無い。** 材質として置けるのは
/// `shininess` / `metalness` / `ambient` / `emissive` の 4 つで、
/// 「面の向きをそのまま色にする」ものは無いので断片で書く。
///
/// 原典が使う p5 の `normalMaterial()` は、面の向きを**視点の座標**で受け取って
/// そのまま色にする (`gl_FragColor = vec4(vVertexNormal, 1.0)`)。負の成分は 0 へ
/// 落ちるので、面が向きを変えるたびに色が入れ替わる — 回している間じゅう色が泳ぐ。
///
/// **こちらは泳がない。** 断片が受け取れる向き (`Fragment.shapeNormal`) は
/// **形自身の座標**なので、形を回しても値が変わらない。模様を表面へ留めるには
/// ちょうどよい約束だが、`normalMaterial()` を写すには足りない — 世界の座標でも
/// 視点の座標でも面の向きを受け取る手が無い。詳しくは README の対応表。
enum NormalPaint {
    /// 面の向きを色にする断片。
    ///
    /// 表示値と線形の値を行き来する関数は用意されていないので、`sRGB` の式を
    /// 自分で書く。**書かないと原典より暗く出る** — `paint()` が返すのは線形の色で、
    /// p5 が書き出しているのは表示値なので、そのまま返すと 1 段暗いほうへずれる。
    static let body = """
        /// 表示値 (0…1) を線形へ。mokume の `LinearRGBA.display` と同じ式。
        static inline float mokume_toLinear(float value) {
            return value <= 0.04045
                ? value / 12.92
                : pow((value + 0.055) / 1.055, 2.4);
        }

        float4 paint(Fragment in, Values values) {
            float3 normal = in.shapeNormal;
            // **向きを持たない頂点では 0 が来る。** 立体の線と点、それに面 (2D) が
            // これにあたるので、長さを見てから使う (`Fragment.shapeNormal` の但し書き)
            if (length_squared(normal) < 0.25) { return in.color; }

            // 原典と同じく、負の成分は落とす (p5 は書き出しの時点で 0 へ丸められる)
            float3 shown = max(normal, 0.0);
            return float4(
                mokume_toLinear(shown.r),
                mokume_toLinear(shown.g),
                mokume_toLinear(shown.b),
                1.0);
        }
        """
}
