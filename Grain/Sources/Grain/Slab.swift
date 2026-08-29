import Foundation
import mokume

/// 板を立体にして回す。
///
/// **これは完成していない。** 木目を立体の表面に留める手が、いまの mokume の面には
/// 無いためで、回すと模様が板の上を滑る。何が足りないかを見せるために残してある
/// (mokume 側の Issue から参照される)。
///
/// 試した順:
///
/// 1. 焼いた `Image` を立体に貼る → **貼る口が無い**。`image()` は 2D だけで、
///    立体の材質にも `ShaderValue` にも面を渡せない
/// 2. 断片で塗る → 塗れるが、断片が受け取る `Fragment` に**表面の位置も向きも
///    入っていない**。使えるのは画面の中の位置 (`place`) だけなので、模様は
///    画面に貼り付いたままになる
///
/// 光は効く (`in.color` に当てた結果が入っている)。止まっているのは
/// **模様を表面に留めること**だけである。
final class Slab: Sketch {
    var settings = SketchSettings(width: 1280, height: 720, title: "grain — slab")

    private var wood: Shader?

    func setup() {
        // 2D の板と同じ作りを断片へ移したもの。**入力が画面の位置しか無い**ので、
        // 立体のどこを塗っているのかは断片から分からない
        wood = try? makeShader(
            """
            static inline float mokume_hash(float2 p) {
                float3 q = fract(float3(p.xyx) * float3(0.1031, 0.1030, 0.0973));
                q += dot(q, q.yzx + 33.33);
                return fract((q.x + q.y) * q.z);
            }

            static inline float mokume_value(float2 p) {
                float2 i = floor(p);
                float2 f = fract(p);
                float2 u = f * f * (3.0 - 2.0 * f);
                float a = mokume_hash(i);
                float b = mokume_hash(i + float2(1.0, 0.0));
                float c = mokume_hash(i + float2(0.0, 1.0));
                float d = mokume_hash(i + float2(1.0, 1.0));
                return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
            }

            static inline float mokume_layered(float2 p) {
                float sum = 0.0, amplitude = 1.0, total = 0.0;
                for (int octave = 0; octave < 5; ++octave) {
                    sum += mokume_value(p) * amplitude;
                    total += amplitude;
                    amplitude *= 0.5;
                    p *= 2.0;
                }
                return sum / total;
            }

            float4 paint(Fragment in, Values values) {
                // **ここが行き止まり。** `in.place` は画面の中の位置なので、
                // 立体を回しても値が変わらない = 模様が画面に貼り付く。
                // 表面の位置か向きが入っていれば、木目は板に留まる
                float2 p = in.place * float2(values.scale, values.scale * 0.55);

                float drift = (mokume_layered(p * float2(2.2, 3.4)) - 0.5) * 0.11;
                float2 offset = float2((p.x - 0.4) * 2.6, p.y - 2.2);
                float radius = length(offset) + drift;
                float phase = radius * values.rings;
                float inRing = fract(phase);
                float late = smoothstep(0.78, 0.92, inRing)
                    * (1.0 - smoothstep(0.94, 1.0, inRing));
                float fibre = (mokume_layered(p * float2(3.0, 26.0)) - 0.5) * 0.075;

                float3 colour = mix(values.early.rgb, values.late.rgb, late) + fibre;
                // **`in.color` には光を当てた結果が入っている。** 無視して自前の色を
                // 返すと、断片で塗った立体だけ平坦になる (mokume の制約ではない)
                return float4(colour * in.color.rgb, 1.0);
            }
            """,
            values: [
                "scale": 3.0,
                "rings": 9.0,
                "early": .color(.display(red: 0.815, green: 0.635, blue: 0.435)),
                "late": .color(.display(red: 0.455, green: 0.300, blue: 0.180)),
            ])
    }

    func draw() {
        background(.studio)
        surroundings(.studio)
        lights()
        directionalLight(.display(red: 1.0, green: 0.95, blue: 0.88), -0.4, -0.7, -0.6)

        push()
        translate(width * 0.5, height * 0.5)
        // 自分で回す。フレーム番号から角度を作るので、同じフレームなら同じ姿勢になる
        rotateX(-0.5)
        rotateY(Float(frameCount) * 0.012)

        if let wood {
            shader(wood)
        }
        noStroke()
        // 断片は `in.color` を掛けて使う。白で塗っておくと、そこに光の強さだけが載る
        fill(.display(red: 1, green: 1, blue: 1))
        // 板 1 枚
        box(520, 26, 300)
        resetShader()
        pop()
    }
}
