import Foundation
import mokume

/// Nebula — 4K の面に 100 万粒を撒き、3 次元の渦に巻いて瞬かせる。
///
/// **works で `makeParticles` を使う 1 本目。** 既存 6 作品はどれも粒にも GPU の計算にも
/// 触れていないので、これは作品であると同時に**粒の語彙の物差し**である。しかも
/// 上流のスケッチと検査が実際に描いている粒はいちばん多いもので 24,000 なので
/// (`Sketches/SparksAndForces.swift`)、100 万は**道具の側も描いたことのない規模**になる。
///
/// ## 撒くのは最初だけ
///
/// `emit` は CPU が 1 粒ずつ書き、書く直前に GPU の完了を待つ (mokume の `Particles.emit`)。
/// 毎フレーム撒くと 100 万粒ぶんの書き込みと待ちがそのまま毎フレームの費用になるので、
/// **最初に撒き切って寿命を長く取り、以降は力だけで動かす**。
///
/// ## キラキラは、持っているもので作る
///
/// mokume の粒に明滅は無い — 色も大きさも寿命で変わらない (`Particles.metal`)。
/// なので瞬きは次の 3 つの重ね合わせから出す:
///
/// 1. `blendMode(.add)` — 重なりが明るくなるので、**密度の揺らぎがそのまま輝度の揺らぎ**になる
/// 2. `.wander` — 押す向きが**粒ごと・フレームごと**に変わる (`mokume_particleDrift`)。
///    100 万粒が独立に震えるので、加算合成の下でチラチラした瞬きになる
/// 3. 撒く回ごとに色と濃さを変える — 明るい粒と淡い粒が混ざり、粒立ちが出る
///
/// ## 視点は Z 軸寄りに保つ
///
/// **粒の板はビルボードではない。** mokume は粒を `plane(1, 1)` — ワールドの XY 平面に
/// 貼った四角 — として描く (`Canvas+Particles.particleQuad()`) ので、視点を大きく回すと
/// 板が edge-on になって痩せる。だから振れ幅は小さく取り、立体感は**奥行きの遠近と
/// 小さな視差**から出す。
final class Nebula: Sketch {
    var settings = SketchSettings(width: 3840, height: 2160, title: "nebula")

    /// 同時に持てる粒の数。**撒き切って寿命が尽きないので、これがそのまま見えている数。**
    private let capacity = 1_000_000

    /// 撒くのを分ける回数。**1 フレームで撒き切らない** — CPU が 1 粒ずつ書くので、
    /// 100 万を 1 枚に載せると最初の 1 フレームだけが極端に長くなる。
    /// 分けた回ごとに撒く球を広げるので、**この数がそのまま層の数**でもある
    private let batches = 24

    private var dust: Particles?
    /// 撒いた数。
    private var seeded = 0

    /// 渦の中心。面の中央、奥行きは 0。
    private var center: SIMD3<Float> { SIMD3(width / 2, height / 2, 0) }

    /// 粒が落ち着く輪の半径。
    private let ring: Float = 900

    /// 渦の強さと抵抗。**釣り合う速さが `渦 ÷ 抵抗`** で、その速さで回り続けられる
    /// 半径が `速さ² ÷ 引く力`。引く力は下でそこから逆に決める
    private let swirling: Float = 55
    private let dragging: Float = 0.06
    private var attraction: Float { (swirling / dragging) * (swirling / dragging) / ring }

    /// いまの渦の強さ。**息をさせる。**
    ///
    /// 一定のまま長く回すと、粒は釣り合いの半径へ落ちて**細い輪 1 本に収束し、
    /// そこから何も起きなくなる** (実測: 10 秒で粒立ちが消えた)。渦だけを緩く上下させると
    /// 釣り合いの半径が動き、星雲は膨らんでは縮む — 収束しないので粒立ちも残り続ける
    private var breathing: Float { swirling * (1 + 0.18 * sin(time * 0.79)) }

    /// 指先が粒を寄せる強さと、押しのける強さ。
    ///
    /// **抵抗が弱いので、効きは強さそのものより `強さ ÷ 抵抗` で読む** — 320 は
    /// 5333 の速さまで加速でき、渦 (55 → 917) の 6 倍になって星雲がほどけた (実測)。
    /// 寄せるほうは渦より弱く、押すほうは中心へ引く力 (約 934) を上回るように取る
    private let pulling: Float = 80
    private let pushing: Float = 450

    /// 一度でも触られたか。**触られるまで指先の力を積まない。**
    ///
    /// `mouseX` / `mouseY` の初期値は 0 なので、そのまま読むと**面の左上へ引く力が
    /// 常時かかる**。ポインタが窓の外にあるときも同じ値が返るので、位置そのものからは
    /// 見分けられない — 出来事が届いたかどうかで見る
    private var touched = false

    /// 視点の距離の倍率。ホイールで動かす。
    private var zoom: Float = 1

    /// 視点の揺れに使う時計。**押している間は進めない。**
    ///
    /// 画面の位置から空間の点を逆に求める道 (`spacePosition`) は**視点に依存する**ので、
    /// マウスを止めていても視点が揺れれば指先の点は空間を移動する。粒はその履歴に
    /// 押しのけられ、印は現在の点に出るので、**押しのけた跡と印がずれて見える**。
    /// 触れている間だけ視点を止めると、両者が揃う
    private var swaying: Float = 0

    func setup() {
        randomSeed(20_260_907)
    }

    // 触られたことだけを受ける。**位置は `mouseX` / `mouseY` から毎フレーム読む**ので、
    // ここで覚えておくものは無い
    func mouseMoved() { touched = true }
    func mousePressed() { touched = true }
    func mouseDragged(deltaX: Float, deltaY: Float) { touched = true }

    /// ホイールで寄る・引く。**締めておく** — 近づきすぎると粒の板が画面を覆い、
    /// 離れすぎると星雲が点になる
    func mouseWheel(deltaX: Float, deltaY: Float) {
        touched = true
        zoom = min(max(zoom - deltaY * 0.001, 0.75), 1.5)
    }

    func draw() {
        background(3, 4, 9)
        // **粒の混ぜ方はここで焼き付く。** `makeParticles` が粒の板を `createShape` で
        // 作り、そのときの混ぜ方を形ごと保持する (`Canvas+Particles.placeFromGPU` が
        // `run.mode` で描く) ので、後から変えても粒には効かない。しかも
        // **`setup()` で積んだスタイルはどのフレームにも属さないので無視される**ため、
        // 粒を作るのはフレームの中でなければならない
        if dust == nil {
            blendMode(.add)
            dust = try? makeParticles(count: capacity)
        }
        guard let dust else { return }

        // **瞬きはここで作る。** 粒は加算で混ざってくれない (上のとおり) ので、
        // 明るい粒だけを閾値で拾って滲ませ、光っているように見せる
        effects([.bloom(amount: 0.9, threshold: 0.32, radius: 20)])

        if seeded < capacity { scatter(dust) }

        // **視点を先に置く。** 指先の位置は「いまの視点」から逆に求めるので
        // (`screenZ` → `spacePosition`)、視点を置く前に読むと 1 フレーム前の答えが返る
        look()

        // **積んだぶんがまとめて効く。** 渦と抵抗が速さの上限を、引く力が輪の半径を
        // 決める。奥行きは弱い重力がゆっくり片側へ流し、揺らぎが厚みを与える
        force(
            dust,
            .attract(center.x, center.y, center.z, strength: attraction),
            .swirl(center.x, center.y, strength: breathing),
            .drag(dragging),
            .wander(strength: 55),
            .gravity(0, 0, 14))

        // 指先。**積むのは触られてから**で、それまではこれまでどおり自分で回る。
        // 力は積み足せるので、6 つ目としてここで乗る (1 回に効くのは 8 つまで)
        if touched {
            let touch = pointer()
            force(
                dust,
                isMousePressed
                    ? .repel(touch.x, touch.y, touch.z, strength: pushing)
                    : .attract(touch.x, touch.y, touch.z, strength: pulling))
        }

        particles(dust)
        mark()

        // 押している間は視点を止める (上の `swaying`)
        if !(touched && isMousePressed) { swaying += deltaTime }

        expose("particles", seeded)
        expose("touched", touched)
        expose("pressing", touched && isMousePressed)
        expose("zoom", zoom)
    }

    /// マウスが指している点。**星雲の中心と同じ奥行きの面の上へ戻す。**
    ///
    /// 面 1 枚ぶんの位置からは空間の 1 点が決まらないので、戻し先の奥行きを渡す側が
    /// 選ぶ (mokume の `spacePosition(screenX:screenY:depth:)`)。掴む物の `screenZ` を
    /// 渡すのが道具側の想定した使い方で、ここで掴んでいるのは星雲そのものである。
    private func pointer() -> SIMD3<Float> {
        let depth = screenZ(center.x, center.y, center.z)
        return spacePosition(screenX: mouseX, screenY: mouseY, depth: depth)
    }

    /// 押している場所へ輪を置く。
    ///
    /// **押しのけている中心が見えないと、粒が何に反応しているのか 1 枚では読めない**
    /// (mokume の `SparksAndForces` が渦の目に円を置いているのと同じ理由)。
    /// 混ぜ方は名指しする — 粒と違って、この輪は加算で重ねると背景に沈む。
    ///
    /// **線は太く取る。** 3 次元に置いた線は視点までの距離で細るので、4K の面でも
    /// `strokeWeight(5)` では実寸の絵から消えた (実測)。20 で確実に出たので間を取る
    private func mark() {
        guard touched, isMousePressed else { return }
        let touch = pointer()
        blendMode(.blend)
        noFill()
        stroke(150, 200, 255, 220)
        strokeWeight(12)
        push()
        translate(touch.x, touch.y, touch.z)
        circle(0, 0, 220)
        pop()
    }

    /// 3 次元の球へ撒く。**回ごとに色と濃さを変える。**
    ///
    /// `rate` は毎秒の数なので、1 フレームで出したい数を `deltaTime` で割って渡す。
    /// 初速が面内 (`vz = 0`) にしかならないのは mokume の `emit` の作りなので、
    /// 奥行きの動きは初期位置と力のほうから作っている。
    private func scatter(_ dust: Particles) {
        let batch = min(capacity / batches, capacity - seeded)
        let index = seeded / max(capacity / batches, 1)
        // **1 回おきに濃さを変える。** 淡く大きい霞と、濃く小さい星を混ぜると、
        // 滲みの閾値を越えるのは星だけになり、霞の中で星が光る
        let star = index % 2 == 1
        // 撒く球を回ごとに広げる。**同じ球から撒くと密度が一様になって構造が出ない**
        let spread = ring * (0.3 + 1.0 * Float(index) / Float(max(batches - 1, 1)))
        emit(
            dust, from: .sphere(center.x, center.y, center.z, radius: spread),
            rate: Float(batch) / max(deltaTime, 1e-6),
            speed: 0...500, angle: 0...(2 * Float.pi),
            // 撒き切りで動かし続けるので、寿命は走らせる時間より長く取る
            life: 900...1200, size: star ? 2...4 : 4...9,
            color: tint(index, bright: star))
        seeded += batch
    }

    /// 撒く回ごとの色。
    private func tint(_ index: Int, bright: Bool) -> LinearRGBA {
        let alpha: Float = bright ? 235 : 26
        // 3 つ飛ばしで巡らせる。**順に巡らせると色が層と揃って同心円の帯になる**
        switch (index * 3) % 4 {
        case 0: return color(150, 200, 255, alpha)  // 青白
        case 1: return color(255, 255, 255, alpha)  // 白
        case 2: return color(255, 176, 108, alpha)  // 橙
        default: return color(255, 138, 190, alpha)  // 桃
        }
    }

    /// 視点。**小さく揺らして視差だけ作る** (板が痩せない範囲に留める)。
    private func look() {
        let distance = ring * 2.6 * zoom
        let yaw = sin(swaying * 0.31) * 0.62
        let pitch = sin(swaying * 0.23) * 0.45
        // 縦軸は下向きなので、見下ろす (正の仰角) と視点は -y へ上がる (mokume の `Orbit.eye`)
        let offset = SIMD3<Float>(
            sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
        let eye = center + offset * distance
        camera(eye.x, eye.y, eye.z, center.x, center.y, center.z, 0, 1, 0)
    }
}
