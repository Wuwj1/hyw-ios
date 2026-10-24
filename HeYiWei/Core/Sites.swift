import Foundation

struct Site: Codable, Identifiable, Hashable {
    var name: String
    var url: String
    var id: String { url }
}

enum Sites {
    static func load() -> [Site] {
        guard let u = Bundle.main.url(forResource: "sites", withExtension: "json"),
              let d = try? Data(contentsOf: u),
              let list = try? JSONDecoder().decode([Site].self, from: d) else { return [] }
        return list
    }
}
