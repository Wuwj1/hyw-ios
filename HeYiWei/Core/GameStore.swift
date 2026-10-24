
import Foundation
import Combine

/// 排序方式（仅 iOS 版内部使用，不写进 games.json）
enum SortMode: String, CaseIterable, Identifiable {
    case lastPlayed = "最近启动"
    case title = "名称"
    case added = "添加顺序"
    var id: String { rawValue }
}

@MainActor
final class GameStore: ObservableObject {
    /// 完整列表：包含 iOS 不展示的类型（例如 Android 的 Windows 卡片）。
    /// 读盘/存盘都不丢数据，只有 UI 用 availableGames 过滤。
    @Published private(set) var games: [Game] = []

    @Published var sortMode: SortMode {
        didSet { UserDefaults.standard.set(sortMode.rawValue, forKey: "hmy.sortMode") }
    }

    init() {
        AppPaths.ensure()
        let saved = UserDefaults.standard.string(forKey: "hmy.sortMode") ?? ""
        sortMode = SortMode(rawValue: saved) ?? .lastPlayed
        load()
    }

    /// 当前 iOS 版可以展示的游戏（kind=6 Windows 不显示，但数据仍保留在 games 里，
    /// 保存时原样写回，避免 Android/iOS 共用同一份 games.json 时丢记录）。
    var availableGames: [Game] {
        games.filter { $0.kind != Game.windows }
    }

    /// 给 UI 用的排序结果
    var sortedGames: [Game] {
        let list = availableGames
        switch sortMode {
        case .lastPlayed:
            return list.sorted { $0.lastPlayed > $1.lastPlayed }
        case .title:
            return list.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case .added:
            return list
        }
    }

    func load() {
        guard let data = try? Data(contentsOf: AppPaths.gamesFile),
              let list = try? JSONDecoder().decode([Game].self, from: data) else {
            games = []
            return
        }
        games = list            // 不做任何过滤
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(games) else { return }
        // 原子写：异常退出不会留下半截 games.json
        try? data.write(to: AppPaths.gamesFile, options: .atomic)
    }

    func add(_ game: Game) {
        games.append(game)
        save()
    }

    func remove(_ game: Game) {
        games.removeAll { $0.id == game.id }
        BookmarkStore.remove(id: game.id)
        removeCoverCopy(for: game)
        save()
    }

    func rename(_ game: Game, to title: String) {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, let i = games.firstIndex(where: { $0.id == game.id }) else { return }
        games[i].title = t
        save()
    }

    func setCover(_ game: Game, path: String) {
        guard let i = games.firstIndex(where: { $0.id == game.id }) else { return }
        games[i].cover = path
        save()
    }

    func setKind(_ game: Game, kind: Int) {
        guard let i = games.firstIndex(where: { $0.id == game.id }) else { return }
        games[i].kind = kind
        save()
    }

    func touch(_ game: Game) {
        guard let i = games.firstIndex(where: { $0.id == game.id }) else { return }
        games[i].lastPlayed = Int64(Date().timeIntervalSince1970)
        save()
    }

    /// 只删沙盒里的封面副本；外面目录里的原图不动
    private func removeCoverCopy(for game: Game) {
        let cover = game.cover
        guard !cover.isEmpty, cover.hasPrefix(AppPaths.covers.path) else { return }
        try? FileManager.default.removeItem(atPath: cover)
    }
}
