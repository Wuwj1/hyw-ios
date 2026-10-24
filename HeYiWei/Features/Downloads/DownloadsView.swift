import SwiftUI

struct DownloadsView: View {
    @EnvironmentObject var downloads: Downloader

    @State private var localFiles: [URL] = []

    var body: some View {
        List {
            if !downloads.tasks.isEmpty {
                Section("进行中") {
                    ForEach(downloads.tasks) { t in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(t.name).font(.subheadline).lineLimit(1)
                            ProgressView(value: t.progress)
                            HStack {
                                Text(label(t)).font(.caption2).foregroundStyle(Theme.subText)
                                Spacer()
                                if t.state == .running {
                                    Button("取消") { downloads.cancel(t.id) }
                                        .font(.caption2)
                                } else {
                                    Button("移除", role: .destructive) { downloads.remove(t.id) }
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                }
            }

            Section {
                if localFiles.isEmpty {
                    Text("还没有下载的文件").font(.caption).foregroundStyle(Theme.subText)
                } else {
                    ForEach(localFiles, id: \.self) { f in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(f.lastPathComponent).font(.subheadline).lineLimit(1)
                                Text(sizeText(f)).font(.caption2).foregroundStyle(Theme.subText)
                            }
                            Spacer()
                            ShareLink(item: f) { Image(systemName: "square.and.arrow.up") }
                        }
                    }
                    .onDelete { idx in
                        for i in idx { try? FileManager.default.removeItem(at: localFiles[i]) }
                        refresh()
                    }
                }
            } header: {
                Text("已下载")
            } footer: {
                Text("游戏压缩包不会自动解压：点右上角分享按钮，用「文件」或解压 App 解压后，回到游戏库 → + → 选择解压出来的文件夹。")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("下载")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { refresh() } label: { Image(systemName: "arrow.clockwise") }
            }
        }
        .onAppear(perform: refresh)
    }

    private func refresh() {
        AppPaths.ensure()
        localFiles = ((try? FileManager.default.contentsOfDirectory(
            at: AppPaths.downloads,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles])) ?? [])
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func sizeText(_ url: URL) -> String {
        let b = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return ByteCountFormatter.string(fromByteCount: Int64(b), countStyle: .file)
    }

    private func label(_ t: HMYDownload) -> String {
        switch t.state {
        case .running: return "\(Int(t.progress * 100))%"
        case .done: return "已完成"
        case .failed: return "失败"
        case .cancelled: return "已取消"
        }
    }
}
