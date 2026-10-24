
import Foundation

/// iOS 沙盒只能访问用户授权的目录，用 security-scoped bookmark 记住授权。
enum BookmarkStore {
    private static let key = "hmy.bookmarks"

    static func save(_ url: URL, for id: String) {
        // 注意：startAccessing 返回 false 不代表不能建 bookmark
        //（例如刚从选择器拿到、已经处于访问中，或目录已不可访问）。
        // 建 bookmark 本身不需要成功 start；能否访问是之后 resolve 时才知道。
        let started = url.startAccessingSecurityScopedResource()
        defer { if started { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? url.bookmarkData(options: .minimalBookmark,
                                              includingResourceValuesForKeys: nil,
                                              relativeTo: nil) else {
            return
        }
        var all = UserDefaults.standard.dictionary(forKey: key) as? [String: Data] ?? [:]
        all[id] = data
        UserDefaults.standard.set(all, forKey: key)
    }

    static func resolve(id: String) -> URL? {
        guard let all = UserDefaults.standard.dictionary(forKey: key) as? [String: Data],
              let data = all[id] else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &stale) else {
            // bookmark 彻底失效（目录被删/移动）：清掉，避免每次都失败
            remove(id: id)
            return nil
        }
        if stale {
            // 目录还在只是 bookmark 过期：重建一次，下次就能直接用
            save(url, for: id)
        }
        return url
    }

    static func remove(id: String) {
        var all = UserDefaults.standard.dictionary(forKey: key) as? [String: Data] ?? [:]
        all.removeValue(forKey: id)
        UserDefaults.standard.set(all, forKey: key)
    }
}
