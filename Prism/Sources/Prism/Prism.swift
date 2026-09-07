import Foundation
import mokume
import simd

/// Prism — 白色光をプリズムに通し、波長ごとの屈折率差で虹に分ける。
///
/// **絵を作り込むのではなく、幾何光学を回してその帰結として虹が出る形にしてある。**
/// 波長ごとに Cauchy の式で屈折率を決め、面ごとに Snell で曲げ、臨界角を越えたら
/// 全反射させ、フレネルで反射と屈折へ力を分ける — 虹はその結果として出てくるので、
/// 分散を 0 にすれば消えるし (スクロールで確かめられる)、入射角を浅くすれば
/// 紫から順に閉じ込められる。
///
/// ## 描いているのは光ではなく、散った光である
///
/// 真空を進む光は横から見えない。ここに見えている帯は**微小な塵が横へ散らした
/// ぶん**という約束で、だから強度は光の力に比例し、進むほど暗くなる。硝子の中だけは
/// 散乱を 1.6 倍にしてある — これは物理ではなく、300 画素で数画素しか開かない
/// 内部の扇を読ませるための嘘である (`Tracer.glassScattering`)。
///
/// ## 線ではなく帯を描く
///
/// 光線を線で引くと、どれだけ本数を積んでもレーザーの束にしか見えない。ここでは
/// 波長ごとに**幅を持つ帯**を追い、断面の明るさを端で 0 に落としてある。隣り合う
/// 波長の帯が裾で混ざるので、扇は連続したグラデーションになる (`Beam`)。
///
/// ## 見せ場は全反射の窓
///
/// 正三角形・n = 1.64〜1.73 では、2 枚目の面から出られる入射角の下限が波長ごとに
/// 違う (赤 38.8 度、紫 45.9 度)。**この 7 度を横切ると、紫から順に色が剥がれて
/// 硝子の中へ閉じ込められる。** 手で描いた虹には出せない、光線を追ったからこそ
/// 出る絵である。
final class Prism: Sketch {
    var settings = SketchSettings(width: 1920, height: 1080, title: "prism")

    // MARK: - 場面

    /// 硝子の重心。
    ///
    /// **偏角から逆に決めてある。** 曲がる角は 50〜60 度あり、しかも底辺の側 (この
    /// 置き方では下) へ曲がるので、素直に中央へ置くと出て行った光が即座に下端から
    /// 抜けて虹の乗る面が無くなる
    private let center = SIMD2<Float>(1000, 300)
    /// 正三角形の 1 辺 (画素)。
    private let side: Float = 380
    /// 重心から頂点までの距離。
    private var circumradius: Float { side / sqrt(3) }

    /// 受け面の位置 (画素)。**投射距離をここで打ち切る。**
    ///
    /// 硝子から 620 画素。**遠いほど虹は広がるが、紫が下端から落ちる。** 全反射で
    /// 紫が消える直前 (入射角 46 度) にちょうど扇が面へ収まる距離がここ
    private let screenX: Float = 1620

    /// 束の幅 (画素)。
    ///
    /// **細いほど虹は澄む。** 分光の純度は「扇の広がり ÷ 束の幅」で決まるので、
    /// 太い束は隣り合う色が混ざって白く濁る。辺の 7% にしてある。
    ///
    /// **硝子の中が読めるかどうかもここで決まる。** 中で分かれる量は出口の面で
    /// 8〜13 画素しかない。しかも束は入るときに 1.3〜1.8 倍へ広がる (`spread`) ので、
    /// 60 画素で入れると中では 80〜105 画素になり、分離は 1 割そこそこに埋もれて
    /// 白い棒にしか見えなかった (実測で r−b の振れが ±10)。26 画素なら中でも
    /// 34〜46 画素で、分離が 2〜3 割を占めるので**紫の縁と赤の縁**として読める
    private let beamWidth: Float = 26

    /// 白い芯の明るさ。
    ///
    /// **1.0 に届かせない。** 混ぜ方が `.add` でも合成は 1 描画ごとに 0…1 へ丸められる
    /// ので、芯を 1.0 にすると分かれる前と後の差が消える。足りないぶんは出口の
    /// `exposure` で持ち上げる
    private let coreGain: Float = 0.52

    // MARK: - 手で動かすもの

    /// 硝子の向き (ラジアン)。ドラッグで回る。
    private var angle: Float = 0
    /// 分散の強さ (Cauchy の B)。スクロールで動く。**0 にすると虹が消える。**
    private var dispersion: Float = 0.020
    /// Cauchy の A。
    ///
    /// **分散は実在の重フリント (SF11) 相当で、基底の屈折率だけ低い架空の硝子**である。
    /// SF11 そのもの (A = 1.727) だと最小偏角が 68 度になり、曲がった先が画面から
    /// 外れてしまう
    private let cauchyA: Float = 1.60

    /// 光源のいまの位置。**狙いは常に硝子の重心**なので、これが動くと入射角が変わる。
    private var source = SIMD2<Float>(558, 461)
    /// 手で置いた光源の位置。
    private var aimed = SIMD2<Float>(558, 461)
    /// 手で触っているか。**放っておくと自動の往復へ戻る。**
    private var manual = false
    /// 最後に触った時刻。
    private var touchedAt: Float = -100
    /// 自動へ戻るまでの間 (秒)。
    private let idleTimeout: Float = 6

    // MARK: - 中身

    private var spectrum = Spectrum()
    private var tracer = Tracer()
    private var prism: [SIMD2<Float>] = []

    func setup() {
        // **画面の性質なのでフレームを越える。** 合成では飽和させず、出口で持ち上げて
        // 肩を丸める — 明るいところが一様な白い塊にならない
        exposure(1.35)
        toneMapping(.roll)
        textSize(24)
        prism.reserveCapacity(3)
    }

    func draw() {
        background(LinearRGBA.display(red: 0.028, green: 0.032, blue: 0.045))

        if time - touchedAt > idleTimeout { manual = false }
        let target = manual ? aimed : automaticSource()
        // 手と自動を行き来しても跳ばない
        source += (target - source) * min(deltaTime * 6, 1)

        spectrum.refresh(cauchyA: cauchyA, cauchyB: dispersion)
        shapePrism()

        let screenTop = SIMD2<Float>(screenX, 0)
        let screenBottom = SIMD2<Float>(screenX, height)
        tracer.run(
            spectrum: spectrum, from: source, toward: center,
            prism: prism, screenA: screenTop, screenB: screenBottom,
            width: beamWidth, gain: coreGain)

        drawGlass(prism)

        blendMode(.add)
        strokeCap(.round)
        drawBands(tracer.bands)
        drawSpots(tracer.spots)
        drawEdges(prism)
        drawScreen(tracer.screen, a: screenTop, b: screenBottom)
        // **灯りは帯より後。** 胴が `.blend` なので、束の切り口をここで覆える
        drawLamp(
            at: source, toward: aiming(), halfWidth: beamWidth / 2)
        drawGuide()

        effects([.bloom(amount: 0.55, threshold: 0.30, radius: 14), .vignette(amount: 0.25)])

        expose("incidence_deg", degrees(tracer.firstIncidence))
        expose("dispersion", dispersion)
        expose("bands", tracer.bands.count)
        expose("spots", tracer.spots.count)
        expose("angle_deg", degrees(angle))
        expose("manual", manual)
    }

    // MARK: - 形

    /// 硝子の 3 頂点を今の向きで置く。**先頭が頂点 (apex)** で、`Beam` の濃さがそれに従う。
    private func shapePrism() {
        prism.removeAll(keepingCapacity: true)
        for i in 0..<3 {
            // 縦軸が下向きなので、−90 度が画面の上
            let step = -Float.pi / 2 + Float(i) * (2 * Float.pi / 3) + angle
            prism.append(center + SIMD2(cos(step), sin(step)) * circumradius)
        }
    }

    /// 触られていないときの光源の位置。
    ///
    /// **往復の幅は、全反射の窓を必ず横切るように取ってある。** 一定の速さで回すと
    /// 光が出てこない角度に長く留まるので、往復にして見せ場の前後を行き来させる
    private func automaticSource() -> SIMD2<Float> {
        // 160 度 ± 10 度。**入射角でいえば 40〜60 度を往復する** — 端の 6 度が
        // 全反射の窓で、そこへ入ると紫から順に色が剥がれる
        let sweep = radians(160) + radians(10) * sin(2 * Float.pi * time / 16)
        return center + SIMD2(cos(sweep), sin(sweep)) * 470
    }

    /// 光源が狙っている向き。**灯りの向きと、追跡が使う向きは同じものである。**
    private func aiming() -> SIMD2<Float> {
        let heading = center - source
        let distance = simd_length(heading)
        // 重心に重なることは `clampedSource` が防いでいるが、割り算の下限は持つ
        return distance > 1e-3 ? heading / distance : SIMD2(1, 0)
    }

    /// 操作の手引き。
    private func drawGuide() {
        blendMode(.blend)
        noStroke()
        fill(LinearRGBA.display(red: 0.62, green: 0.66, blue: 0.74, alpha: 0.75))
        let baseline = height - 155
        text("動かす — 光を向ける", 56, baseline)
        text("ドラッグ — 硝子を回す", 56, baseline + 33)
        text("スクロール — 分散 \(String(format: "%.4f", dispersion))", 56, baseline + 66)
        text("スペース — 往復へ返す", 56, baseline + 99)
        text("R — はじめの置き方へ戻す", 56, baseline + 132)
        blendMode(.add)
    }

    // MARK: - 触る

    func mouseMoved() {
        aimed = clampedSource(SIMD2(mouseX, mouseY))
        manual = true
        touchedAt = time
    }

    /// ドラッグは**硝子を回す**。掴んでいる間は光源を動かさない。
    func mouseDragged(deltaX: Float, deltaY: Float) {
        let now = atan2(mouseY - center.y, mouseX - center.x)
        let before = atan2(mouseY - deltaY - center.y, mouseX - deltaX - center.x)
        var turn = now - before
        // ±π を跨いだときに 1 周ぶん跳ねないように畳む
        if turn > .pi { turn -= 2 * .pi }
        if turn < -.pi { turn += 2 * .pi }
        angle += turn
        manual = true
        touchedAt = time
    }

    /// スクロールは**分散の強さ**を変える。
    ///
    /// 0 にすると屈折だけが残って白い 1 本になり、上げると扇が開く。
    /// **「なぜ虹になるのか」を手で確かめられる**ので、シミュレーションとしての芯はここ
    func mouseWheel(deltaX: Float, deltaY: Float) {
        dispersion = min(max(dispersion + deltaY * 0.0004, 0), 0.055)
        manual = true
        touchedAt = time
    }

    func keyPressed() {
        if keyCode == .space {
            manual = false
            touchedAt = -100
        }
        if keyCode == .r {
            angle = 0
            dispersion = 0.020
            manual = false
            touchedAt = -100
        }
    }

    /// 光源が硝子へ近づきすぎないように押し戻す。
    ///
    /// **近すぎると束が面より太くなり**、どこから入ってどこへ出たのかが読めなくなる
    private func clampedSource(_ point: SIMD2<Float>) -> SIMD2<Float> {
        let offset = point - center
        let distance = simd_length(offset)
        let minimum = circumradius + 150
        if distance < minimum {
            let direction = distance > 1e-3 ? offset / distance : SIMD2<Float>(-1, 0)
            return center + direction * minimum
        }
        return point
    }
}
