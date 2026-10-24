import SwiftUI
import UniformTypeIdentifiers

struct AddGameView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss

    @State private var picking = false
    @State private var draft: ImportDraft?
    @State private var title = ""
    @State private var kind = Game.krkr
    @State private var chosenCover: URL?
    @State private var errorText: String?
    @State private var busy = false

    var body: some View {
        NavigationStack {
            Group {
                if let d = draft {
                    confirmForm(d)
                } else {
                    pickPrompt
                }
            }
            .navigationTitle("添加游戏")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                if draft != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("添加") { commit() }.disabled(busy)
                    }
                }
            }
            .fileImporter(isPresented: $picking,
                          allowedContentTypes: [.folder],
                          allowsMultipleSelection: false) { result in
                handlePick(result)
            }
            .alert("无法添加", isPresented: Binding(
                get: { errorText != nil },
                set: { if !$0 { errorText = nil } })) {
                Button("好", role: .cancel) { errorText = nil }
            } message: { Text(errorText ?? "") }
        }
    }

    // MARK: - 未选择时
    private var pickPrompt: some View {
        VStack(spacing: 18) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 46))
                .foregroundStyle(Theme.accent)
            Text("选择游戏文件夹").font(.headline)
            Text("包含 startup.tjs / .xp3（KRKR）或 nscript.dat / .nsa（ONS）\n何意味会先判断内容，再让你确认")
                .font(.footnote)
                .foregroundStyle(Theme.subText)
                .multilineTextAlignment(.center)
            Button("选择文件夹…") { picking = true }
                .buttonStyle(.borderedProminent)
            Spacer()
        }
        .padding(28)
    }

    // MARK: - 已分析，等确认
    private func confirmForm(_ d: ImportDraft) -> some View {
        Form {
            Section("名称") {
                TextField("游戏名", text: $title)
            }
            Section("识别结果") {
                Text(GameDetector.summary(d.detection))
                    .font(.footnote)
                    .foregroundStyle(Theme.subText)
                Picker("类型", selection: $kind) {
                    Text("KRKR（KiriKiri）").tag(Game.krkr)
                    Text("ONS（ONScripter）").tag(Game.ons)
                }
                if d.detection.confidence == .weak {
                    Text("特征不明显，已按默认类型填好，可以手动改。")
                        .font(.caption2)
                        .foregroundStyle(Theme.subText)
                }
            }
            Section("封面") {
                if d.coverCandidates.isEmpty {
                    Text("目录里没有找到图片，添加后可以手动更换封面。")
                        .font(.caption)
                        .foregroundStyle(Theme.subText)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(d.coverCandidates, id: \.self) { url in
                                coverThumb(url)
                                    .onTapGesture { chosenCover = url }
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(chosenCover == url ? Theme.accent : .clear, lineWidth: 2)
                                    )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            Section("目录") {
                Text(d.url.path)
                    .font(.caption2)
                    .foregroundStyle(Theme.subText)
                    .lineLimit(2)
            }
        }
    }

    private func coverThumb(_ url: URL) -> some View {
        Group {
            if let img = UIImage(contentsOfFile: url.path) {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                Color(white: 0.95)
            }
        }
        .frame(width: 76, height: 100)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - 动作
    private func handlePick(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let e):
            errorText = e.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            busy = true
            defer { busy = false }
            do {
                let d = try Importer.analyze(url)
                draft = d
                title = d.title
                kind = d.kind
                chosenCover = d.coverCandidates.first
            } catch {
                errorText = error.localizedDescription
            }
        }
    }

    private func commit() {
        guard var d = draft else { return }
        d.title = title.isEmpty ? d.title : title
        d.kind = kind
        d.chosenCover = chosenCover
        Importer.commit(d, into: store)
        dismiss()
    }
}
