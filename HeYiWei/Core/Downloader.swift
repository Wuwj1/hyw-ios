import Foundation
import Combine

struct HMYDownload: Identifiable {
    let id = UUID()
    let url: URL
    var name: String { url.lastPathComponent }
    var progress: Double = 0
    var state: State = .running
    var fileURL: URL?

    enum State { case running, done, failed, cancelled }
}

/// 下载到 Documents/Downloads。
/// 第一版**不做自动解压**：下载完成后由用户在「文件」里处理，再回到何意味选目录添加。
@MainActor
final class Downloader: NSObject, ObservableObject {
    @Published private(set) var tasks: [HMYDownload] = []
    private var session: URLSession!
    private var idMap: [Int: UUID] = [:]

    override init() {
        super.init()
        AppPaths.ensure()
        session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }

    func start(_ url: URL) {
        tasks.insert(HMYDownload(url: url), at: 0)
        let t = session.downloadTask(with: url)
        idMap[t.taskIdentifier] = tasks[0].id
        t.resume()
    }

    func cancel(_ id: UUID) {
        session.getAllTasks { list in
            for t in list where self.idMap[t.taskIdentifier] == id { t.cancel() }
        }
        setState(id, .cancelled)
    }

    /// 删除下载记录；有文件的一并删掉
    func remove(_ id: UUID) {
        if let t = tasks.first(where: { $0.id == id }), let f = t.fileURL {
            try? FileManager.default.removeItem(at: f)
        }
        tasks.removeAll { $0.id == id }
    }

    private func setProgress(_ taskID: Int, _ p: Double) {
        guard let id = idMap[taskID], let i = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[i].progress = p
    }

    private func setState(_ id: UUID, _ s: HMYDownload.State) {
        guard let i = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[i].state = s
    }

    private func finish(_ taskID: Int, temp: URL?) {
        guard let id = idMap[taskID], let i = tasks.firstIndex(where: { $0.id == id }) else { return }
        guard let temp else { tasks[i].state = .failed; return }
        let dest = AppPaths.uniqueFile(in: AppPaths.downloads, name: tasks[i].name)
        do {
            try FileManager.default.moveItem(at: temp, to: dest)
            tasks[i].state = .done
            tasks[i].progress = 1
            tasks[i].fileURL = dest
        } catch {
            tasks[i].state = .failed
        }
    }
}

extension Downloader: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ s: URLSession, downloadTask: URLSessionDownloadTask,
                                didWriteData bytes: Int64, totalBytesWritten written: Int64,
                                totalBytesExpectedToWrite total: Int64) {
        guard total > 0 else { return }
        let p = Double(written) / Double(total)
        let tid = downloadTask.taskIdentifier
        Task { @MainActor in self.setProgress(tid, p) }
    }

    nonisolated func urlSession(_ s: URLSession, downloadTask: URLSessionDownloadTask,
                                didFinishDownloadingTo location: URL) {
        // location 在回调返回后会被删除，先搬到临时目录
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.moveItem(at: location, to: tmp)
        let tid = downloadTask.taskIdentifier
        Task { @MainActor in self.finish(tid, temp: tmp) }
    }

    nonisolated func urlSession(_ s: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard error != nil else { return }
        let tid = task.taskIdentifier
        Task { @MainActor in
            if let id = self.idMap[tid] { self.setState(id, .failed) }
        }
    }
}
