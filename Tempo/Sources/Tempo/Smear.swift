import mokume

/// 拍で走る後処理。**自作の効果 (`makeEffect`) を通す 1 本目。**
///
/// 組み込みの効果 (`.bloom` / `.blur` / `.fringe`) は「どのくらい」しか渡せないので、
/// **拍頭でだけ・進行方向へだけ引きずる**ことができない。ここでは引きずる向きを画素で
/// 渡し、打点の強さで混ぜ具合を決める — 動いた後にだけ尾が出るので、止まっている
/// 1.3 拍がよりはっきり止まって見える。
///
/// 粒は常に乗せている。平らな色だけで描いた絵は、拡大すると帯 (バンディング) が出る。
enum Smear {
    /// 渡す値の初期値。**宣言していない名前は後から足せない**ので、ここが正本。
    static let starting: [String: ShaderValue] = [
        "drag": .pair(0, 0),
        "amount": 0,
        "grain": 0.009,
    ]

    static let body = """
        float4 effect(Pixel in, Values values) {
            float4 colour = in.color;

            // 引きずり。**進行方向の後ろだけ**を混ぜるので、前には滲まない
            if (values.amount > 0.001) {
                float2 step = values.drag / max(in.size, float2(1.0, 1.0));
                float4 sum = colour;
                float total = 1.0;
                for (int i = 1; i <= 6; i++) {
                    float weight = 1.0 - float(i) / 7.0;
                    sum += mokume_at(in, in.place - step * (float(i) / 6.0)) * weight;
                    total += weight;
                }
                colour = mix(colour, sum / total, values.amount);
            }

            // 粒。位置から決まるので、同じフレームからは同じ粒が出る
            float noise = fract(sin(dot(in.position, float2(12.9898, 78.233))) * 43758.5453);
            colour.rgb += (noise - 0.5) * values.grain;
            return colour;
        }
        """
}
