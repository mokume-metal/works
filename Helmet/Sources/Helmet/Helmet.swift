import Foundation
import mokume
import simd

/// Khronos の DamagedHelmet を読んで、mokume で質感を出そうとする。
///
/// three.js の [webgl_loader_gltf](https://threejs.org/examples/#webgl_loader_gltf) 相当 —
/// あちらは glTF + PBR マップ 5 枚 + HDR 環境 + `ACESFilmicToneMapping` + `antialias: true`
/// で見せる。**この作品の目的は、その 5 つのうち mokume に何が無いかを踏むこと**である
/// (mokume [ADR-0022](https://github.com/mokume-metal/mokume/blob/main/docs/decisions/0022-production-track.md)
/// 決定 4「作ろうとして止まる」)。
///
/// 読む段は作品側 (``GLTF``) にある。mokume は OBJ しか読まないので、そこは
/// 回避してから**回避できない場所**を測るのが狙いである。
final class Helmet: Sketch {
    var settings = SketchSettings(width: 960, height: 540, title: "helmet")

    /// 頂点の渡し方。**段 0 の測定で切り替える。**
    ///
    /// `whole` が素直な書き方 (三角形を全部 1 回の `beginShape` / `endShape` に渡す) で、
    /// `chunked` が回避策である。回避が要ることは README の「踏んだもの」が持つ。
    enum Build: String {
        case whole
        case chunked
    }

    static var build = Build.chunked
    /// 塊 1 つに入れる三角形の数。
    static var chunk = 32
    static var modelPath = "upstream/models/DamagedHelmet/DamagedHelmet.gltf"

    private var model: GLTF?
    private var body: Shape?
    private var albedo: Image?
    /// 組み立ての記録。`--measure` が読み、README の数字の出どころになる。
    private(set) var notes: [String] = []

    func setup() {
        let clock = ContinuousClock()
        var mark = clock.now

        let model: GLTF
        do {
            model = try GLTF.load(Self.modelPath)
        } catch {
            notes.append("glTF が読めなかった: \(error)")
            report()
            return
        }
        notes.append("glTF を読む: \(elapsed(since: mark, clock))")
        notes.append(
            "  頂点 \(model.vertexCount) / 三角形 \(model.triangleCount) / 並び \(model.pieces.count)"
        )
        if let material = model.pieces.first?.material {
            notes.append("  材質が指すマップ \(material.mapCount) 枚")
        }
        for (what, count) in model.skipped.sorted(by: { $0.key < $1.key }) {
            notes.append("  読み飛ばした: \(what) × \(count)")
        }
        self.model = model

        // baseColor だけ先に読む。**残りのマップは貼る口が無い** (段 3 で測る)
        if let name = model.pieces.first?.material?.baseColor {
            mark = clock.now
            albedo = try? loadImage(model.directory.appendingPathComponent(name).path)
            let how = albedo == nil ? "読めなかった" : elapsed(since: mark, clock)
            notes.append("baseColor (\(name)): \(how)")
        }

        // 貼る絵を焼いた小さいものへ差し替える口。**読み込んだ JPEG のせいでは
        // ない**ことを示すのに使う (64x64 の焼いた絵でも同じように消える)
        if ProcessInfo.processInfo.environment["HELMET_TEXTURE"] == "small" {
            let small = try? createImage(64, 64)
            for y in 0..<64 {
                for x in 0..<64 {
                    small?.set(
                        x, y,
                        .display(
                            red: Float(x) / 64, green: Float(y) / 64,
                            blue: (x / 8 + y / 8) % 2 == 0 ? 0.9 : 0.2))
                }
            }
            albedo = small
            notes.append("  貼る絵を 64x64 の焼いたものへ差し替えた (切り分け)")
        }

        // 置く前の数字。**見えないときの切り分けはここから始まる**
        let span = model.bounds.max - model.bounds.min
        notes.append(
            String(
                format: "  囲みの箱 (%.2f, %.2f, %.2f)〜(%.2f, %.2f, %.2f)",
                model.bounds.min.x, model.bounds.min.y, model.bounds.min.z,
                model.bounds.max.x, model.bounds.max.y, model.bounds.max.z))
        let placing = placement(for: model)
        notes.append(
            String(
                format: "  差し渡し (%.2f, %.2f, %.2f) → 倍率 %.1f", span.x, span.y, span.z,
                placing.columns.0.x))
        let corner = placing * SIMD4(model.bounds.min, 1)
        let opposite = placing * SIMD4(model.bounds.max, 1)
        notes.append(
            String(
                format: "  置いた後の角 (%.1f, %.1f, %.1f)〜(%.1f, %.1f, %.1f)", corner.x,
                corner.y, corner.z, opposite.x, opposite.y, opposite.z))

        // **ここが段 0 の測定。** whole だと何秒かかるかを数字で残す
        mark = clock.now
        let built = assemble(model)
        notes.append("Shape を組む (\(Self.build.rawValue)): \(elapsed(since: mark, clock))")
        notes.append("  頂点 \(built.vertexCount) / 描画 \(built.drawCallCount) 回")
        body = built

        report()
    }

    func draw() {
        background(.display(red: 0.07, green: 0.07, blue: 0.086))
        orbitControl()

        // 光は控えめに 2 つだけ。**質感を測るのが目的**なので、光で誤魔化さない
        ambientLight(.linear(red: 0.18, green: 0.18, blue: 0.22))
        directionalLight(.linear(red: 0.9, green: 0.88, blue: 0.82), -0.4, 0.8, -0.35)

        guard let body else {
            fill(.display(red: 0.94, green: 0.94, blue: 0.96))
            textSize(16)
            text("glTF が読めていない (scripts/fetch.py を先に走らせる)", 24, 40)
            return
        }

        noStroke()

        // **どこまでが通るかを段ごとに見る口。** 絵が出ないときに、カメラ・頂点の
        // 経路・保持した形・絵を貼ること、のどれで折れているかを 1 つずつ潰せる
        // (この作品では実際に 4 段目で折れた — README の「踏んだもの」1)
        switch ProcessInfo.processInfo.environment["HELMET_PROBE"] {
        case "box":
            // 組み込みの立体。カメラが合っているか
            fill(.linear(red: 1, green: 0.3, blue: 0.2))
            push()
            translate(width / 2, height / 2, 0)
            box(150)
            pop()
            return
        case "triangle":
            // 頂点を並べた三角形 1 枚を**その場で**描く。beginShape の経路が通るか
            fill(.linear(red: 0.2, green: 1, blue: 0.3))
            push()
            translate(width / 2, height / 2, 0)
            beginShape(.triangles)
            normal(0, 0, 1)
            vertex(-100, -100, 0)
            normal(0, 0, 1)
            vertex(100, -100, 0)
            normal(0, 0, 1)
            vertex(0, 100, 0)
            endShape()
            pop()
            return
        case "textured", "textured-inline":
            // 三角形 1 枚に**絵を貼って**置く。`createShape` の中で `texture()` を
            // 使う経路が通るか — mokume の参照スケッチはこの組み合わせを 1 つも通っていない
            let picture = try? createImage(64, 64)
            for y in 0..<64 {
                for x in 0..<64 {
                    picture?.set(
                        x, y,
                        .display(
                            red: Float(x) / 64, green: Float(y) / 64,
                            blue: (x / 8 + y / 8) % 2 == 0 ? 0.9 : 0.2))
                }
            }
            let inline = ProcessInfo.processInfo.environment["HELMET_PROBE"]
                == "textured-inline"
            if inline {
                // 比較用: **その場で**描く (参照スケッチ TexturedSurfaces と同じ形)
                fill(.linear(red: 1, green: 1, blue: 1))
                if let picture { texture(picture) }
                push()
                translate(width / 2, height / 2, 0)
                beginShape(.triangles)
                normal(0, 0, 1)
                vertex(-100, -100, 0, 0, 0)
                normal(0, 0, 1)
                vertex(100, -100, 0, 64, 0)
                normal(0, 0, 1)
                vertex(0, 100, 0, 32, 64)
                endShape()
                pop()
                noTexture()
            } else {
                let one = createShape {
                    noStroke()
                    fill(.linear(red: 1, green: 1, blue: 1))
                    if let picture { texture(picture) }
                    beginShape(.triangles)
                    normal(0, 0, 1)
                    vertex(-100, -100, 0, 0, 0)
                    normal(0, 0, 1)
                    vertex(100, -100, 0, 64, 0)
                    normal(0, 0, 1)
                    vertex(0, 100, 0, 32, 64)
                    endShape()
                }
                print("  probe: 頂点 \(one.vertexCount) / 描画 \(one.drawCallCount) 回")
                push()
                translate(width / 2, height / 2, 0)
                shape(one)
                pop()
            }
            return
        case "retained":
            // 同じ三角形を**保持した形として**置く。createShape → shape の経路が通るか
            let one = createShape {
                noStroke()
                fill(.linear(red: 0.3, green: 0.5, blue: 1))
                beginShape(.triangles)
                normal(0, 0, 1)
                vertex(-100, -100, 0)
                normal(0, 0, 1)
                vertex(100, -100, 0)
                normal(0, 0, 1)
                vertex(0, 100, 0)
                endShape()
            }
            print("  probe: 頂点 \(one.vertexCount) / 描画 \(one.drawCallCount) 回")
            push()
            translate(width / 2, height / 2, 0)
            shape(one)
            pop()
            return
        default:
            break
        }

        fill(.linear(red: 1, green: 1, blue: 1))
        push()
        translate(width / 2, height / 2, 0)
        rotateY(time * 0.4)
        // **このフレームで組み直して**置く口。`setup()` で組んだものと描かれ方が違う
        // ことが [mokume#914](https://github.com/mokume-metal/mokume/issues/914) の症状
        // そのもので、この作品が段 3 以降へ進めない理由である
        if ProcessInfo.processInfo.environment["HELMET_REBUILD"] != nil, let model {
            shape(assemble(model))
        } else {
            shape(body)
        }
        pop()
    }

    // MARK: - 組む

    /// 読んだ並びを 1 つの ``Shape`` へ焼く。
    ///
    /// **`texture()` を `beginShape` より前に置くのが必須。** 後だと `vertex(x,y,z,u,v)` の
    /// uv が黙って捨てられ、面の白い区画を読む (mokume の `Canvas+Vertices.swift` の
    /// `guard let currentPicture`)。
    private func assemble(_ model: GLTF) -> Shape {
        let placing = placement(for: model)
        // 切り分け用: 絵を貼らずに単色で組む (消す)
        let bare = ProcessInfo.processInfo.environment["HELMET_NOTEXTURE"] != nil
        return createShape {
            if let albedo, !bare { texture(albedo) }
            // **呼び忘れると三角形 1 枚ごとに輪郭の帯が出る** (1 枚あたり約 36 頂点)
            noStroke()
            // **塗りを明示する。** `hasFill` は原始形ごとに 1 度見られるので、
            // 塗りが無い状態で並べると 1 枚も置かれない。貼る絵は塗りに掛かるので白
            fill(.linear(red: 1, green: 1, blue: 1))
            for piece in model.pieces {
                emit(piece, placing: placing, bare: bare)
            }
        }
    }

    private func emit(_ piece: GLTF.Piece, placing: simd_float4x4, bare: Bool = false) {
        let matrix = placing * piece.transform
        // 法線は逆転置で運ぶ (倍率が一様でも、Y の裏返しが入るため素の行列では狂う)
        let rotation = simd_float3x3(
            matrix.columns.0.xyz, matrix.columns.1.xyz, matrix.columns.2.xyz)
        let forNormals = simd_transpose(simd_inverse(rotation))

        let triangles = piece.triangleCount
        // **whole は素直な書き方。** mokume の `endShape` が原始形ごとに全頂点を
        // 走るので、ここで渡す三角形の数がそのまま二次で効く
        let step = Self.build == .whole ? max(triangles, 1) : Self.chunk

        var first = 0
        while first < triangles {
            let last = min(first + step, triangles)
            beginShape(.triangles)
            for triangle in first..<last {
                for corner in 0..<3 {
                    let index = piece.indices[triangle * 3 + corner]
                    guard index < piece.positions.count else { continue }

                    // **法線は頂点ごとに呼ぶ。** `beginShape` で消えるうえ、
                    // 書き換えるまで効き続けるので、1 度でも抜けると隣の面の向きが漏れる
                    if index < piece.normals.count {
                        let n = simd_normalize(forNormals * piece.normals[index])
                        normal(n.x, n.y, n.z)
                    }

                    let placed = (matrix * SIMD4(piece.positions[index], 1)).xyz
                    if index < piece.uvs.count, let albedo, !bare {
                        // **UV は画像の画素で書く** (mokume は 0…1 を取らない)
                        // **読み取り位置は 0…1 の外へ出る。** glTF は繰り返しを
                        // 前提にするので (DamagedHelmet の v は 1.26 まで行く)、
                        // mokume の読み取り方 (端で留める) とは意味が違う
                        let uv = piece.uvs[index]
                        vertex(
                            placed.x, placed.y, placed.z, uv.x * Float(albedo.width),
                            uv.y * Float(albedo.height))
                    } else {
                        vertex(placed.x, placed.y, placed.z)
                    }
                }
            }
            endShape()
            first = last
        }
    }

    /// 中心を原点へ寄せ、Y を面の向き (下向き) へ裏返し、画面に収まる倍率へ。
    ///
    /// glTF は Y 上向き・メートルで、mokume は Y 下向き・画素である。**直すのは置く側の
    /// 仕事**で、読む段 (``GLTF``) は glTF のまま返す。
    private func placement(for model: GLTF) -> simd_float4x4 {
        let span = model.bounds.max - model.bounds.min
        let longest = max(span.x, max(span.y, span.z))
        let scale = longest > 0 ? min(width, height) * 0.55 / longest : 1
        let center = (model.bounds.min + model.bounds.max) / 2
        let toOrigin = simd_float4x4(
            columns: (
                SIMD4(1, 0, 0, 0), SIMD4(0, 1, 0, 0), SIMD4(0, 0, 1, 0),
                SIMD4(-center.x, -center.y, -center.z, 1)
            ))
        return simd_float4x4(diagonal: SIMD4(scale, -scale, scale, 1)) * toOrigin
    }

    // MARK: - 記録

    private func report() {
        for note in notes { print(note) }
        // **そのつど流す。** パイプへ溜めると、測っている途中で殺されたときに
        // そこまでの数字ごと消える
        fflush(stdout)
    }

    private func elapsed(since mark: ContinuousClock.Instant, _ clock: ContinuousClock) -> String {
        let duration = clock.now - mark
        let ms =
            Double(duration.components.seconds) * 1000
            + Double(duration.components.attoseconds) / 1e15
        return ms < 1000 ? String(format: "%.1f ms", ms) : String(format: "%.2f s", ms / 1000)
    }
}
