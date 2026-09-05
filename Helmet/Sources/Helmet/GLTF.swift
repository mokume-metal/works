import Foundation
import simd

/// glTF 2.0 を読む。
///
/// **最小サブセットに絞ってある。** 目的は「読めること」ではなく、読んだ後に mokume で
/// 質感を出せるかを測ることなので、読むのは三角形の並びとマップの参照だけである。
/// 読まなかったものは ``skipped`` が数える (mokume の `Model.skippedLines` と同じ発想)。
///
/// **なぜ作品側にあるか。** mokume は OBJ しか読まず (`loadModel` が拡張子で弾く)、
/// `Model` / `SolidMesh` は internal なので外から組み立てられない。制作トラックの
/// 依存は一方向なので (mokume ADR-0022 決定 2)、読む段はこちらに書いて、
/// 「mokume に無い」ことを実演する側に回る。
///
/// 座標は **glTF のまま**返す (Y 上向き・メートル)。面の約束 (Y 下向き・画素) へ
/// 直すのは置く側の仕事で、``Helmet`` がやる — 読む段に混ぜると「読めたか」と
/// 「置けたか」の切り分けが効かなくなる。
struct GLTF {

    /// 材質。**参照だけ持つ。** 貼れるかどうかはこの型の関知しないことで、
    /// 測るのは置く側である。
    struct Material {
        var baseColor: String?
        var metallicRoughness: String?
        var normal: String?
        var occlusion: String?
        var emissive: String?
        var metallicFactor: Float = 1
        var roughnessFactor: Float = 1
        var emissiveFactor: SIMD3<Float> = .zero
        var isDoubleSided = false

        /// 参照しているマップの数。README の対応表へ流す。
        var mapCount: Int {
            [baseColor, metallicRoughness, normal, occlusion, emissive]
                .compactMap { $0 }.count
        }
    }

    /// 三角形の並び 1 つぶん (glTF の primitive)。
    struct Piece {
        var positions: [SIMD3<Float>]
        var normals: [SIMD3<Float>]
        var uvs: [SIMD2<Float>]
        /// 頂点番号の並び。3 つで 1 枚。
        var indices: [Int]
        /// この並びを世界へ置く行列 (node の階層を畳んだもの)。
        var transform: simd_float4x4
        var material: Material?

        var triangleCount: Int { indices.count / 3 }
    }

    var pieces: [Piece]
    /// 画像を探す基準 (`.gltf` が置かれているディレクトリ)。
    var directory: URL
    /// 読まなかったもの。「何を落としたか」を数で残す。
    var skipped: [String: Int]

    var vertexCount: Int { pieces.reduce(0) { $0 + $1.positions.count } }
    var triangleCount: Int { pieces.reduce(0) { $0 + $1.triangleCount } }

    /// 囲みの箱 (変換を掛けた後)。置くときの倍率と中心を作るのに使う。
    var bounds: (min: SIMD3<Float>, max: SIMD3<Float>)

    // MARK: - 読む

    static func load(_ path: String) throws -> GLTF {
        let url = URL(fileURLWithPath: path)
        let document: Document
        do {
            document = try JSONDecoder().decode(Document.self, from: Data(contentsOf: url))
        } catch let error as DecodingError {
            throw Failure.malformed(String(describing: error))
        } catch {
            throw Failure.unreadable(url.lastPathComponent)
        }

        let directory = url.deletingLastPathComponent()
        var skipped: [String: Int] = [:]

        // 外部の `.bin` を読む。**data URI も通す** — 手で書いた小さな glTF は
        // それで済むので、測るときに検体を作りやすい
        let buffers = try (document.buffers ?? []).map { buffer -> Data in
            guard let uri = buffer.uri else {
                // GLB の埋め込みチャンク。取ってきた資産は `.gltf` + `.bin` なので通らない
                throw Failure.unsupported("uri を持たない buffer (GLB の埋め込み)")
            }
            if uri.hasPrefix("data:") {
                guard let comma = uri.firstIndex(of: ","),
                    let decoded = Data(base64Encoded: String(uri[uri.index(after: comma)...]))
                else { throw Failure.unsupported("base64 でない data URI") }
                return decoded
            }
            let resolved = directory.appendingPathComponent(
                uri.removingPercentEncoding ?? uri)
            guard let data = try? Data(contentsOf: resolved) else {
                throw Failure.unreadable(uri)
            }
            return data
        }

        let materials = (document.materials ?? []).map { material in
            Material(
                baseColor: document.imageName(of: material.pbrMetallicRoughness?.baseColorTexture),
                metallicRoughness: document.imageName(
                    of: material.pbrMetallicRoughness?.metallicRoughnessTexture),
                normal: document.imageName(of: material.normalTexture),
                occlusion: document.imageName(of: material.occlusionTexture),
                emissive: document.imageName(of: material.emissiveTexture),
                metallicFactor: material.pbrMetallicRoughness?.metallicFactor ?? 1,
                roughnessFactor: material.pbrMetallicRoughness?.roughnessFactor ?? 1,
                emissiveFactor: SIMD3(material.emissiveFactor ?? [0, 0, 0]),
                isDoubleSided: material.doubleSided ?? false)
        }

        // 場面の根から node を辿る。**行列は親から掛けて畳む**
        var pieces: [Piece] = []
        let roots =
            document.scenes?[safe: document.scene ?? 0]?.nodes
            ?? Array((document.nodes ?? []).indices)
        for root in roots {
            try document.walk(
                node: root, parent: matrix_identity_float4x4, buffers: buffers,
                materials: materials, into: &pieces, skipped: &skipped)
        }

        // 囲みの箱。**変換を掛けた後の位置で測る** — 置く側が要るのはそちら
        var low = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var high = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        for piece in pieces {
            for position in piece.positions {
                let placed = piece.transform * SIMD4(position, 1)
                low = simd_min(low, placed.xyz)
                high = simd_max(high, placed.xyz)
            }
        }
        if pieces.isEmpty { (low, high) = (.zero, .zero) }

        return GLTF(
            pieces: pieces, directory: directory, skipped: skipped, bounds: (low, high))
    }

    enum Failure: Error, CustomStringConvertible {
        case unreadable(String)
        case malformed(String)
        case unsupported(String)

        var description: String {
            switch self {
            case .unreadable(let what): "読めません: \(what)"
            case .malformed(let detail): "glTF として読めません: \(detail)"
            case .unsupported(let what): "まだ読めません: \(what)"
            }
        }
    }
}

// MARK: - JSON の形

/// glTF の JSON。**要る欄だけ**を宣言してある。
private struct Document: Decodable {
    struct Accessor: Decodable {
        var bufferView: Int?
        var byteOffset: Int?
        var componentType: Int
        var count: Int
        var type: String
    }
    struct BufferView: Decodable {
        var buffer: Int
        var byteOffset: Int?
        var byteLength: Int
        var byteStride: Int?
    }
    struct Buffer: Decodable {
        var uri: String?
    }
    struct Primitive: Decodable {
        var attributes: [String: Int]
        var indices: Int?
        var material: Int?
        var mode: Int?
    }
    struct Mesh: Decodable {
        var primitives: [Primitive]
    }
    struct Node: Decodable {
        var mesh: Int?
        var children: [Int]?
        var matrix: [Float]?
        var translation: [Float]?
        var rotation: [Float]?
        var scale: [Float]?
    }
    struct Scene: Decodable {
        var nodes: [Int]?
    }
    struct TextureRef: Decodable {
        var index: Int?
    }
    struct PBR: Decodable {
        var baseColorTexture: TextureRef?
        var metallicRoughnessTexture: TextureRef?
        var metallicFactor: Float?
        var roughnessFactor: Float?
    }
    struct MaterialDoc: Decodable {
        var pbrMetallicRoughness: PBR?
        var normalTexture: TextureRef?
        var occlusionTexture: TextureRef?
        var emissiveTexture: TextureRef?
        var emissiveFactor: [Float]?
        var doubleSided: Bool?
    }
    struct TextureDoc: Decodable {
        var source: Int?
    }
    struct ImageDoc: Decodable {
        var uri: String?
    }

    var accessors: [Accessor]?
    var bufferViews: [BufferView]?
    var buffers: [Buffer]?
    var meshes: [Mesh]?
    var nodes: [Node]?
    var scenes: [Scene]?
    var scene: Int?
    var materials: [MaterialDoc]?
    var textures: [TextureDoc]?
    var images: [ImageDoc]?

    /// 材質が指しているテクスチャの画像ファイル名。
    func imageName(of reference: TextureRef?) -> String? {
        guard let index = reference?.index,
            let source = textures?[safe: index]?.source,
            let uri = images?[safe: source]?.uri
        else { return nil }
        return uri.removingPercentEncoding ?? uri
    }

    /// node を辿って、三角形の並びを集める。
    func walk(
        node index: Int, parent: simd_float4x4, buffers: [Data], materials: [GLTF.Material],
        into pieces: inout [GLTF.Piece], skipped: inout [String: Int]
    ) throws {
        guard let node = nodes?[safe: index] else { return }
        let transform = parent * Document.localTransform(node)

        if let meshIndex = node.mesh, let mesh = meshes?[safe: meshIndex] {
            for primitive in mesh.primitives {
                // mode を書かない glTF は TRIANGLES (仕様の既定は 4)
                guard primitive.mode ?? 4 == 4 else {
                    skipped["三角形でない並び (mode \(primitive.mode ?? 4))", default: 0] += 1
                    continue
                }
                guard let positionAccessor = primitive.attributes["POSITION"] else {
                    skipped["POSITION を持たない並び", default: 0] += 1
                    continue
                }
                for name in primitive.attributes.keys
                where !["POSITION", "NORMAL", "TEXCOORD_0"].contains(name) {
                    // TANGENT・COLOR_0・JOINTS_0 など。**数えるだけ**
                    skipped["読まない属性 \(name)", default: 0] += 1
                }

                let positions = try vectors3(positionAccessor, buffers)
                let normals =
                    try primitive.attributes["NORMAL"].map { try vectors3($0, buffers) } ?? []
                let uvs =
                    try primitive.attributes["TEXCOORD_0"].map { try vectors2($0, buffers) } ?? []
                let indices =
                    try primitive.indices.map { try scalars($0, buffers) }
                    ?? Array(positions.indices)

                pieces.append(
                    GLTF.Piece(
                        positions: positions, normals: normals, uvs: uvs, indices: indices,
                        transform: transform,
                        material: primitive.material.flatMap { materials[safe: $0] }))
            }
        }

        for child in node.children ?? [] {
            try walk(
                node: child, parent: transform, buffers: buffers, materials: materials,
                into: &pieces, skipped: &skipped)
        }
    }

    /// node 1 つぶんの行列。`matrix` があればそれ、無ければ T * R * S。
    static func localTransform(_ node: Node) -> simd_float4x4 {
        if let m = node.matrix, m.count == 16 {
            // glTF は列優先で並べる
            return simd_float4x4(
                columns: (
                    SIMD4(m[0], m[1], m[2], m[3]), SIMD4(m[4], m[5], m[6], m[7]),
                    SIMD4(m[8], m[9], m[10], m[11]), SIMD4(m[12], m[13], m[14], m[15])
                ))
        }
        var result = matrix_identity_float4x4
        if let t = node.translation, t.count == 3 {
            result = simd_float4x4(
                columns: (
                    SIMD4(1, 0, 0, 0), SIMD4(0, 1, 0, 0), SIMD4(0, 0, 1, 0),
                    SIMD4(t[0], t[1], t[2], 1)
                ))
        }
        if let r = node.rotation, r.count == 4 {
            // glTF のクォータニオンは [x, y, z, w] の順
            result *= simd_float4x4(simd_quatf(ix: r[0], iy: r[1], iz: r[2], r: r[3]))
        }
        if let s = node.scale, s.count == 3 {
            result *= simd_float4x4(diagonal: SIMD4(s[0], s[1], s[2], 1))
        }
        return result
    }

    // MARK: accessor を読む

    /// accessor が指す範囲を、要素ごとに切って渡す。
    ///
    /// **`byteStride` を持つ bufferView がある** (NormalTangentTest がそう) ので、
    /// 進み幅は宣言があればそれに従い、無ければ要素の大きさを使う。
    private func each(
        _ index: Int, expecting type: String, components: Int, buffers: [Data],
        _ body: (Data, Int) -> Void
    ) throws {
        guard let accessor = accessors?[safe: index] else {
            throw GLTF.Failure.malformed("accessor \(index) が無い")
        }
        guard accessor.type == type else {
            throw GLTF.Failure.unsupported("\(accessor.type) を \(type) として読もうとした")
        }
        guard let viewIndex = accessor.bufferView, let view = bufferViews?[safe: viewIndex] else {
            // bufferView を持たない accessor は「全部 0」の意味だが、測る対象に無い
            throw GLTF.Failure.unsupported("bufferView を持たない accessor")
        }
        guard let buffer = buffers[safe: view.buffer] else {
            throw GLTF.Failure.malformed("buffer \(view.buffer) が無い")
        }

        let unit = Document.componentSize(accessor.componentType)
        guard unit > 0 else {
            throw GLTF.Failure.unsupported("componentType \(accessor.componentType)")
        }
        let stride = view.byteStride ?? unit * components
        let start = (view.byteOffset ?? 0) + (accessor.byteOffset ?? 0)
        guard start + stride * (accessor.count - 1) + unit * components <= buffer.count else {
            throw GLTF.Failure.malformed("accessor \(index) が buffer の外を指している")
        }
        for element in 0..<accessor.count {
            body(buffer, start + stride * element)
        }
    }

    static func componentSize(_ componentType: Int) -> Int {
        switch componentType {
        case 5120, 5121: 1  // BYTE / UNSIGNED_BYTE
        case 5122, 5123: 2  // SHORT / UNSIGNED_SHORT
        case 5125, 5126: 4  // UNSIGNED_INT / FLOAT
        default: 0
        }
    }

    func vectors3(_ index: Int, _ buffers: [Data]) throws -> [SIMD3<Float>] {
        var result: [SIMD3<Float>] = []
        result.reserveCapacity(accessors?[safe: index]?.count ?? 0)
        try each(index, expecting: "VEC3", components: 3, buffers: buffers) { data, offset in
            result.append(
                SIMD3(
                    data.float(at: offset), data.float(at: offset + 4),
                    data.float(at: offset + 8)))
        }
        return result
    }

    func vectors2(_ index: Int, _ buffers: [Data]) throws -> [SIMD2<Float>] {
        var result: [SIMD2<Float>] = []
        result.reserveCapacity(accessors?[safe: index]?.count ?? 0)
        try each(index, expecting: "VEC2", components: 2, buffers: buffers) { data, offset in
            result.append(SIMD2(data.float(at: offset), data.float(at: offset + 4)))
        }
        return result
    }

    /// 頂点番号。**UNSIGNED_SHORT と UNSIGNED_INT だけ**読む (取ってきた検体はどちらも前者)。
    func scalars(_ index: Int, _ buffers: [Data]) throws -> [Int] {
        guard let componentType = accessors?[safe: index]?.componentType else {
            throw GLTF.Failure.malformed("accessor \(index) が無い")
        }
        var result: [Int] = []
        result.reserveCapacity(accessors?[safe: index]?.count ?? 0)
        try each(index, expecting: "SCALAR", components: 1, buffers: buffers) { data, offset in
            switch componentType {
            case 5121: result.append(Int(data.integer(at: offset, as: UInt8.self)))
            case 5123: result.append(Int(data.integer(at: offset, as: UInt16.self)))
            case 5125: result.append(Int(data.integer(at: offset, as: UInt32.self)))
            default: break
            }
        }
        guard result.count == accessors?[safe: index]?.count else {
            throw GLTF.Failure.unsupported("componentType \(componentType) の頂点番号")
        }
        return result
    }
}

// MARK: - 小道具

extension Data {
    fileprivate func float(at offset: Int) -> Float {
        withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: Float.self) }
    }
    fileprivate func integer<T: FixedWidthInteger>(at offset: Int, as type: T.Type) -> T {
        withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: T.self) }
    }
}

extension Array {
    /// 範囲の外を nil で返す。glTF の索引は外から来るので、落ちるより数えたい。
    fileprivate subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

extension SIMD4 where Scalar == Float {
    var xyz: SIMD3<Float> { SIMD3(x, y, z) }
}

extension SIMD3 where Scalar == Float {
    init(_ values: [Float]) {
        self.init(
            values.count > 0 ? values[0] : 0, values.count > 1 ? values[1] : 0,
            values.count > 2 ? values[2] : 0)
    }
}
