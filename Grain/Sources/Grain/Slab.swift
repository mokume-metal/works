import Foundation
import mokume

/// 板を立体にして回す。
///
/// **`v0.6.0` で完成した。** 木目は板の表面に留まり、回しても滑らない。
///
/// ここに至るまでに 2 つで止まっている。記録として残す:
///
/// 1. 焼いた `Image` を立体に貼る → 当時は**貼る口が無かった**。`image()` は 2D だけで、
///    立体の材質にも `ShaderValue` にも面を渡せなかった
///    ([mokume#368](https://github.com/mokume-metal/mokume/issues/368) — 閉じた)
/// 2. 断片で塗る → 塗れるが、断片が受け取る `Fragment` に**表面の位置も向きも
///    入っていなかった**。使えるのは画面の中の位置 (`place`) だけなので、模様は
///    画面に貼り付いたままになった
///    ([mokume#367](https://github.com/mokume-metal/mokume/issues/367) — 閉じた)
///
/// **いま使っているのは 2 の続きで、`Fragment.shapePosition` である。** 置き場所の
/// 変換を通す**前**の座標なので、形を動かしても回しても変わらない。単位は形を置いた
/// ときの寸法そのままなので、`box(520, 26, 300)` なら x は −260…260 を取る —
/// 板の座標へ直すのに寸法が要るから、下の ``span`` を断片へ渡している。
final class Slab: Sketch {
    var settings = SketchSettings(width: 1280, height: 720, title: "grain — slab")

    /// 板の寸法。**断片にも同じ数が要る**ので 1 か所に持つ (`shapePosition` は
    /// 形を置いたときの寸法そのままの値を返すため、0…1 へ直すのに割る数が要る)。
    private static let span = (length: Float(520), thickness: Float(26), width: Float(300))

    private var wood: Shader?

    func setup() {
        // 2D の板と同じ作りを断片へ移したもの
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
                // **ここが要。** `in.shapePosition` は形自身の座標なので、板を回しても
                // 値が変わらない = 木目が板に留まる。以前は `in.place` (画面の中の
                // 位置) しか無く、模様が画面に貼り付いていた。
                //
                // 長手 (x) と幅 (z) を板の座標 0…1 へ直す。厚みの側 (y) は使わない —
                // 挽いた板の面はこの 2 軸で決まり、木口はその断面として現れる
                float2 board = float2(
                    in.shapePosition.x / values.spanX + 0.5,
                    in.shapePosition.z / values.spanZ + 0.5);
                float2 p = board * float2(values.scale, values.scale * 0.55);

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
                "spanX": .number(Self.span.length),
                "spanZ": .number(Self.span.width),
                "early": .color(.display(red: 0.815, green: 0.635, blue: 0.435)),
                "late": .color(.display(red: 0.455, green: 0.300, blue: 0.180)),
            ])
    }

    func draw() {
        background(.studio)
        surroundings(.studio)
        lights()
        // 目盛りは 0–255 (`v0.6.0` から)。以前の `.display(1.0, 0.95, 0.88)` と同じ値
        directionalLight(255, 242.25, 224.4, -0.4, -0.7, -0.6)

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
        fill(255)
        // 板 1 枚
        box(Self.span.length, Self.span.thickness, Self.span.width)
        resetShader()
        pop()
    }
}
