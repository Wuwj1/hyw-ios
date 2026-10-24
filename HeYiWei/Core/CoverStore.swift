import Foundation
import UIKit

/// 封面：候选图来自游戏目录，选中的复制进 App 沙盒（不依赖外部目录长期可访问）。
enum CoverStore {

    private static let imageExts = ["jpg", "jpeg", "png", "webp", "bmp"]

    /// 目录里像封面的图，优先根目录、优先名字像 cover/title/package/icon。
    static func candidates(in dir: URL, limit: Int = 8) -> [URL] {
        let fm = FileManager.default
        let items = (try? fm.contentsOfDirectory(at: dir,
                                                includingPropertiesForKeys: [.fileSizeKey],
                                                options: [.skipsHiddenFiles])) ?? []
        let images = items.filter { imageExts.contains($0.pathExtension.lowercased()) }

        func rank(_ u: URL) -> Int {
            let n = u.lastPathComponent.lowercased()
            if n.hasPrefix("cover") { return 0 }
            if n.hasPrefix("title") || n.hasPrefix("package") { return 1 }
            if n.hasPrefix("icon") || n.hasPrefix("logo") { return 2 }
            let size = (try? u.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return size > 60_000 ? 3 : 4
        }
        return images.sorted { rank($0) < rank($1) }.prefix(limit).map { $0 }
    }

    /// 从候选文件复制进沙盒
    @discardableResult
    static func save(fileURL: URL, for gameID: String) -> String? {
        AppPaths.ensure()
        let ext = fileURL.pathExtension.lowercased()
        let dest = AppPaths.covers.appendingPathComponent("\(gameID).\(ext.isEmpty ? "jpg" : ext)")
        try? FileManager.default.removeItem(at: dest)
        do {
            try FileManager.default.copyItem(at: fileURL, to: dest)
            return dest.path
        } catch {
            // 外部目录不可复制时退回"仅记录原路径"，至少不会静默失败
            return fileURL.path
        }
    }

    /// 用户从相册/文件里挑了一张图
    @discardableResult
    static func save(image: UIImage, for gameID: String) -> String? {
        AppPaths.ensure()
        guard let data = image.jpegData(compressionQuality: 0.9) else { return nil }
        let dest = AppPaths.covers.appendingPathComponent("\(gameID).jpg")
        do {
            try data.write(to: dest, options: .atomic)
            return dest.path
        } catch {
            return nil
        }
    }

    static func load(path: String) -> UIImage? {
        guard !path.isEmpty else { return nil }
        return UIImage(contentsOfFile: path)
    }
}
