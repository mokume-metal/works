import Foundation
import mokume
import simd

/// 手元の表示 — 速度・周回・時計・地図。
///
/// ## 2 次元は視点の変換を通らない
///
/// `rect` / `circle` / `arc` / `text` は面の座標へそのまま描かれるので、既定のカメラへ
/// 戻してから置く。3 次元の点に何かを貼りたいときだけ `screenX` / `screenY` を通す。
///
/// ## `noLights()` を呼ばない
///
/// Quarry の手元の表示は `camera()` + `perspective()` + `noLights()` の 3 行で始まる。
/// けれど**影の焼き付けはフレームの終わりに 1 度走り、そのときの光を読む**ので、
/// 光を消したまま終えると**そのフレームの影が黙って消える** (Cast が実測して
/// [mokume#1151](https://github.com/mokume-metal/mokume/issues/1151) に戻した)。
/// ここでは光を消さず、描き終えたら**場面のカメラへ戻す** — 焼き付けの箱は
/// いまの注視点を中心に取られるので、戻さないと影の箱が原点に取り残される
extension Apex {
    /// 手元の表示を 1 枚ぶん描く。
    ///
    /// **文字は ASCII だけで書く。** 日本語を 1 文字でも混ぜると、そのフレームから
    /// GPU が描き切れなくなる ([mokume#1273](https://github.com/mokume-metal/mokume/issues/1273))。
    /// 作品の言葉としては日本語で書きたいところだが、いまは出せない
    func dash() {
        camera()
        perspective()
        blendMode(.blend)
        noStroke()

        // **1 フレームに出す文字は 60 字ほどに抑える。** 超えると GPU が描き切れなく
        // なるので (mokume#1273)、出すものを場面ごとに選ぶ — 手引きを出している間は
        // 計器を控え、終わったら着順だけにする
        let guiding = race.phase == .waiting

        if race.phase == .finished {
            // chart()
            signal()
        } else {
            panel(brief: guiding)
            if !guiding { speedo() }
            // chart()
            signal()
        }

        look()
    }

    // MARK: - 左上 — 周回と時計

    private func panel(brief: Bool) {
        let x: Float = 26
        var y: Float = 44
        let me = race.runners[0]

        fill(Palette.shade.x, Palette.shade.y, Palette.shade.z, 150)
        rect(x - 12, y - 30, 232, brief ? 50 : 106)

        fill(Palette.ink.x, Palette.ink.y, Palette.ink.z, 236)
        textSize(30)
        text("LAP \(race.shownLap(of: 0)) / \(Race.laps)", x, y)
        // **手引きを出している間はここまで。** 1 フレームに描ける文字の総量に
        // 上限があるので (mokume#1273)、出すものを場面ごとに選ぶ
        guard !brief else { return }
        y += 34

        textSize(19)
        let running = race.phase == .running ? race.clock - me.lapBegan : 0
        text(Race.text(race.phase == .waiting ? nil : running), x, y)
        textSize(22)
        text("P\(race.standing(of: 0) + 1)/\(race.runners.count)", x + 150, y)
        y += 24
        fill(Palette.ink.x, Palette.ink.y, Palette.ink.z, 172)
        textSize(15)
        text("BEST \(Race.text(me.best))", x, y)
    }

    // MARK: - 右下 — 速度計

    private func speedo() {
        let centre = SIMD2<Float>(width - 116, height - 94)
        let radius: Float = 66
        // **0…260 km/h を 270° に割る。** 針は置かず、弧そのものが伸びる
        let sweep = Float.pi * 1.5
        let from = Float.pi * 0.75
        let ratio = Math.unit(car.kmh / 260)

        noFill()
        stroke(Palette.ink.x, Palette.ink.y, Palette.ink.z, 46)
        strokeWeight(10)
        // arc(centre.x, centre.y, radius * 2, radius * 2, from, from + sweep)

        // 速いほど朱に寄る
        let heat = Math.unit((car.kmh - 120) / 120)
        stroke(
            Math.mix(236, 232, heat), Math.mix(238, 96, heat), Math.mix(240, 72, heat), 245)
        strokeWeight(10)
        // arc (2 本目)
        noStroke()

        textAlign(.center)
        fill(Palette.ink.x, Palette.ink.y, Palette.ink.z, 244)
        textSize(42)
        text("\(Int(car.kmh))", centre.x, centre.y + 10)
        textSize(13)
        fill(Palette.ink.x, Palette.ink.y, Palette.ink.z, 168)
        text("km/h", centre.x, centre.y + 32)
        // **右寄せ・中央寄せにしたら左へ戻す** (Cast・Tempo と同じ作法)
        textAlign(.left)
    }

    // MARK: - 右上 — 地図

    private func chart() {
        let box: Float = 168
        let origin = SIMD2<Float>(width - box - 26, 26)

        fill(Palette.shade.x, Palette.shade.y, Palette.shade.z, 140)
        rect(origin.x - 10, origin.y - 10, box + 20, box + 20)

        guard mapScale > 0 else { return }
        noFill()
        stroke(Palette.ink.x, Palette.ink.y, Palette.ink.z, 70)
        strokeWeight(7)
        ribbon(origin: origin, box: box)
        stroke(Palette.ink.x, Palette.ink.y, Palette.ink.z, 210)
        strokeWeight(2.5)
        ribbon(origin: origin, box: box)
        noStroke()

        // スタートライン
        let line = chartPoint(track.frame(at: 0).point, origin: origin, box: box)
        fill(238, 238, 236, 230)
        rect(line.x - 5, line.y - 5, 10, 10)

        // **相手を先に、自分を最後に置く。** 重なったとき自分が見えるように
        for (index, other) in cars.enumerated().reversed() {
            let spot = chartPoint(other.place, origin: origin, box: box)
            let tint = Palette.cars[index % Palette.cars.count]
            fill(Palette.shade.x, Palette.shade.y, Palette.shade.z, 220)
            circle(spot.x, spot.y, index == 0 ? 15 : 12)
            fill(tint.x, tint.y, tint.z, 250)
            circle(spot.x, spot.y, index == 0 ? 11 : 8)
        }
    }

    /// 地図の線。**`line` を 1 本ずつ引く。**
    ///
    /// 既定のカメラ (面の座標) で `beginShape(.lines)` へ頂点を流したら、
    /// **GPU が 1 フレームを描き切れなくなった** (アドレス違反で待たされる)。
    /// 2 次元の図形は視点の変換を通らない別の経路なので、そちらの口で描く
    private func ribbon(origin: SIMD2<Float>, box: Float) {
        for index in 0..<mapLine.count {
            let a = chartPoint(mapLine[index], origin: origin, box: box)
            let b = chartPoint(mapLine[(index + 1) % mapLine.count], origin: origin, box: box)
            line(a.x, a.y, b.x, b.y)
        }
    }

    /// コースの点を地図の画素へ。**z を反転する** — 3 次元の +z は奥、面の +y は下なので、
    /// そのまま写すと地図が上下鏡になる
    private func chartPoint(_ p: SIMD2<Float>, origin: SIMD2<Float>, box: Float) -> SIMD2<Float> {
        let span = mapHigh - mapLow
        let pad = (box - SIMD2(span.x, span.y) * mapScale) / 2
        return SIMD2(
            origin.x + pad.x + (p.x - mapLow.x) * mapScale,
            origin.y + pad.y + (mapHigh.y - p.y) * mapScale)
    }

    // MARK: - 中央 — 合図と結果

    private func signal() {
        if race.phase == .finished {
            fill(Palette.shade.x, Palette.shade.y, Palette.shade.z, 190)
            rect(width / 2 - 210, height / 2 - 120, 420, 240)
            // **新しい字を 1 つも出さない。** 使う字の種類が増えると、そのフレームから
            // GPU が描き切れなくなる (mokume#1273) — 着順は一度しか出ない場面なので、
            // ここで落ちると取り返しがつかない
            textAlign(.center)
            fill(Palette.ink.x, Palette.ink.y, Palette.ink.z, 245)
            textSize(56)
            text("P\(race.standing(of: 0) + 1) / \(race.runners.count)", width / 2, height / 2 - 26)
            textSize(19)
            fill(Palette.ink.x, Palette.ink.y, Palette.ink.z, 205)
            text("BEST \(Race.text(race.runners[0].best))", width / 2, height / 2 + 26)
            textSize(15)
            text("R", width / 2, height / 2 + 66)
            textAlign(.left)
            return
        }

        guard let light = race.light else { return }
        // **合図は残り秒の関数。** 薄れながら消える。
        //
        // **大きさは動かさない。** `textSize` へ毎フレーム違う値を渡したら
        // (拡大して出したかった)、**GPU がアドレス違反で落ちて 1 フレームも
        // 描けなくなった**。動かしてよいのは色のほうだけである
        let age = Math.unit(light.age)
        textAlign(.center)
        fill(Palette.ink.x, Palette.ink.y, Palette.ink.z, 250 * age)
        textSize(84)
        text(light.text, width / 2, height / 2 - 40)
        textAlign(.left)
    }

}
