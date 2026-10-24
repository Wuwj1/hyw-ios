import Foundation
import UIKit

/// 「添加游戏」的分析结果：还没落库，等用户确认。
struct ImportDraft {
    var url: URL
    var title: String
    var detection: DetectionResult
    var coverCandidates: [URL]
    var chosenCover: URL?
    var kind: Int
}

enum ImportError: LocalizedError {
    case notDirectory
    case noAccess
    case emptyFolder
    case looksLikeArchive

    var errorDescription: String? {
        switch self {
        case .notDirectory: return "请选择一个文件夹（不是单个文件）"
        case .noAccess: return "无法访问这个目录，请在系统选择器里重新授权"
        case .emptyFolder: return "这个文件夹是空的"
        case .looksLikeArchive: return "这是压缩包，请先解压再选择解压后的文件夹"
        }
    }
}

enum Importer {

    /// 分析目录：识别引擎、找封面、给出默认标题。
    static func analyze(_ url: URL) throws -> ImportDraft {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else {
            throw ImportError.noAccess
        }
        guard isDir.boolValue else {
            let ext = url.pathExtension.lowercased()
            if ["zip", "rar", "7z", "tar", "gz"].contains(ext) { throw ImportError.looksLikeArchive }
            throw ImportError.notDirectory
        }
        let items = (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []
        if items.isEmpty { throw ImportError.emptyFolder }

        let detection = GameDetector.detect(url)
        return ImportDraft(url: url,
                           title: url.lastPathComponent,
                           detection: detection,
                           coverCandidates: CoverStore.candidates(in: url),
                           chosenCover: nil,
                           kind: detection.kind)
    }

    /// 落库：保存目录授权 + 封面副本 + Game 记录。
    @MainActor
    @discardableResult
    static func commit(_ draft: ImportDraft, into store: GameStore) -> Game {
        let id = Game.newID()
        var game = Game(id: id, title: draft.title, path: draft.url.path, kind: draft.kind)
        game.cover = ""

        // 目录授权：iOS 只能靠 bookmark 再次访问
        BookmarkStore.save(draft.url, for: id)

        // 封面：复制进沙盒，之后不依赖外部目录
        // 外部目录要重新开 scope 才能读，否则 copyItem 会被拒
        let scoped = draft.url.startAccessingSecurityScopedResource()
        if let cover = draft.chosenCover {
            if let path = CoverStore.save(fileURL: cover, for: id) {
                game.cover = path
            }
        } else if let first = draft.coverCandidates.first {
            if let path = CoverStore.save(fileURL: first, for: id) {
                game.cover = path
            }
        }
        if scoped { draft.url.stopAccessingSecurityScopedResource() }

        store.add(game)
        return game
    }

    /// 取回目录授权后的 URL（引擎启动前要用）
    static func resolve(_ game: Game) -> URL? {
        BookmarkStore.resolve(id: game.id)
    }
}
