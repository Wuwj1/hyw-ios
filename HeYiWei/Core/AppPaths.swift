import Foundation

/// 应用内所有可写路径集中在这里。
/// 注意：iOS 没有"全盘存储"，游戏目录来自用户授权的 bookmark，只有本 App 沙盒是固定的。
enum AppPaths {
    static let root: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("HeYiWei", isDirectory: true)
    }()

    static let covers = root.appendingPathComponent("Covers", isDirectory: true)
    static let gamesFile = root.appendingPathComponent("games.json")

    /// 下载目录放在 Documents 下，这样开启 UIFileSharingEnabled 后
    /// 用户能在「文件」App 里直接看到并解压/搬到游戏目录。
    static let downloads: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("Downloads", isDirectory: true)
    }()

    /// 目录里已有同名文件时，生成 "(1) name"、"(2) name" …，绝不覆盖
    static func uniqueFile(in dir: URL, name: String) -> URL {
        let fm = FileManager.default
        var candidate = dir.appendingPathComponent(name)
        if !fm.fileExists(atPath: candidate.path) { return candidate }
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var n = 1
        while true {
            let newName = ext.isEmpty ? "(\(n)) \(base)" : "(\(n)) \(base).\(ext)"
            candidate = dir.appendingPathComponent(newName)
            if !fm.fileExists(atPath: candidate.path) { return candidate }
            n += 1
        }
    }

    static func ensure() {
        let fm = FileManager.default
        for d in [root, covers, downloads] {
            try? fm.createDirectory(at: d, withIntermediateDirectories: true)
        }
    }
}
