import Foundation

/// 与 Android 版 Game.java 的 JSON 结构一一对应，kind 编号保持一致，
/// 同一份 games.json 在两个平台都能读。
struct Game: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var path: String
    var cover: String
    var engine: String
    var kind: Int
    var safUri: String
    var flags: String
    var lastPlayed: Int64

    static let krkr = 0
    static let ons = 1
    static let external = 2
    static let joiplay = 3
    static let ppsspp = 4
    static let maldives = 5
    /// Android 的 Windows 类型：iOS 版不支持，读到直接跳过。
    static let windows = 6

    init(id: String = Game.newID(), title: String, path: String, kind: Int = Game.krkr) {
        self.id = id
        self.title = title
        self.path = path
        self.cover = ""
        self.engine = ""
        self.kind = kind
        self.safUri = ""
        self.flags = ""
        self.lastPlayed = 0
    }

    static func newID() -> String {
        String(UInt64(Date().timeIntervalSince1970 * 1000), radix: 16)
            + String(UInt16.random(in: 0...0xFFFF), radix: 16)
    }

    var subtitle: String {
        switch kind {
        case Game.krkr: return "KRKR"
        case Game.ons: return "ONS"
        case Game.external: return "外部应用"
        case Game.joiplay: return "JoiPlay（待移植）"
        case Game.maldives: return "Maldives（待移植）"
        case Game.ppsspp: return "PPSSPP"
        case Game.windows: return "Windows（iOS 不支持）"
        default: return "未知"
        }
    }

    var typeName: String {
        switch kind {
        case Game.krkr: return "KRKR（KiriKiri）"
        case Game.ons: return "ONS（ONScripter）"
        case Game.external: return "其他应用"
        default: return "iOS 版不支持的类型"
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, path, cover, engine, kind, safUri, flags, lastPlayed
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? Game.newID()
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        path = try c.decodeIfPresent(String.self, forKey: .path) ?? ""
        cover = try c.decodeIfPresent(String.self, forKey: .cover) ?? ""
        engine = try c.decodeIfPresent(String.self, forKey: .engine) ?? ""
        kind = try c.decodeIfPresent(Int.self, forKey: .kind) ?? Game.krkr
        safUri = try c.decodeIfPresent(String.self, forKey: .safUri) ?? ""
        flags = try c.decodeIfPresent(String.self, forKey: .flags) ?? ""
        lastPlayed = try c.decodeIfPresent(Int64.self, forKey: .lastPlayed) ?? 0
    }
}
