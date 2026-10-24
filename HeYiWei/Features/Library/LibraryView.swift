import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var store: GameStore
    @State private var query = ""
    @State private var showAdd = false
    @State private var renameTarget: Game?
    @State private var renameText = ""
    @State private var coverTarget: Game?
    @State private var toast: String?

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    private var shown: [Game] {
        let all = store.sortedGames
        guard !query.isEmpty else { return all }
        return all.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                if store.availableGames.isEmpty {
                    ContentUnavailableView {
                        Label("还没有游戏", systemImage: "square.grid.2x2")
                    } description: {
                        Text("点右上角 + 选择游戏文件夹\n何意味会自动识别 KRKR / ONS")
                    }
                } else if shown.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(shown) { g in
                                GameCardView(game: g)
                                    .onTapGesture { launch(g) }
                                    .contextMenu {
                                        Button {
                                            renameTarget = g
                                            renameText = g.title
                                        } label: { Label("重命名", systemImage: "pencil") }

                                        Button {
                                            coverTarget = g
                                        } label: { Label("更换封面", systemImage: "photo") }

                                        Button(role: .destructive) {
                                            store.remove(g)
                                        } label: { Label("删除", systemImage: "trash") }
                                    }
                            }
                        }
                        .padding(12)
                    }
                    .refreshable { store.load() }
                }
            }
            .navigationTitle("何意味")
            .searchable(text: $query, prompt: "搜索游戏")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("排序", selection: Binding(
                            get: { store.sortMode },
                            set: { store.sortMode = $0 })) {
                            ForEach(SortMode.allCases) { m in
                                Text(m.rawValue).tag(m)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddGameView().environmentObject(store)
            }
            .sheet(item: $coverTarget) { g in
                CoverPickerView(game: g)
                    .environmentObject(store)
            }
            .alert("重命名", isPresented: Binding(
                get: { renameTarget != nil },
                set: { if !$0 { renameTarget = nil } })) {
                TextField("游戏名", text: $renameText)
                Button("取消", role: .cancel) { renameTarget = nil }
                Button("保存") {
                    if let g = renameTarget { store.rename(g, to: renameText) }
                    renameTarget = nil
                }
            }
            .alert("提示", isPresented: Binding(
                get: { toast != nil },
                set: { if !$0 { toast = nil } })) {
                Button("好", role: .cancel) { toast = nil }
            } message: { Text(toast ?? "") }
        }
    }

    private func launch(_ g: Game) {
        guard let engine = EngineRegistry.engine(for: g.kind) else {
            toast = "iOS 版不支持这个类型"
            return
        }
        guard engine.isAvailable else {
            toast = "\(engine.displayName) 引擎还没接入 iOS 版"
            return
        }
        do {
            try engine.launch(g)
            store.touch(g)
        } catch {
            toast = error.localizedDescription
        }
    }
}
