import SwiftUI
import UniformTypeIdentifiers

struct CoverPickerView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss

    let game: Game

    @State private var candidates: [URL] = []
    @State private var pickingFile = false

    private let columns = [GridItem(.adaptive(minimum: 90), spacing: 10)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(candidates, id: \.self) { url in
                        Button {
                            if let path = CoverStore.save(fileURL: url, for: game.id) {
                                store.setCover(game, path: path)
                            }
                            dismiss()
                        } label: {
                            thumb(url)
                        }
                    }
                }
                .padding(12)
            }
            .navigationTitle("选择封面")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("从文件") { pickingFile = true }
                }
            }
            .fileImporter(isPresented: $pickingFile,
                          allowedContentTypes: [.image],
                          allowsMultipleSelection: false) { result in
                if case .success(let urls) = result, let url = urls.first {
                    let scoped = url.startAccessingSecurityScopedResource()
                    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                    if let path = CoverStore.save(fileURL: url, for: game.id) {
                        store.setCover(game, path: path)
                    }
                    dismiss()
                }
            }
            .onAppear(perform: loadCandidates)
        }
    }

    private func loadCandidates() {
        let dir = BookmarkStore.resolve(id: game.id) ?? URL(fileURLWithPath: game.path)
        let scoped = dir.startAccessingSecurityScopedResource()
        candidates = CoverStore.candidates(in: dir)
        if scoped { dir.stopAccessingSecurityScopedResource() }
    }

    private func thumb(_ url: URL) -> some View {
        Group {
            if let img = UIImage(contentsOfFile: url.path) {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                Color(white: 0.95)
            }
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
