import SwiftUI

struct RootView: View {
    @State private var tab = 1

    var body: some View {
        TabView(selection: $tab) {
            LibraryView()
                .tabItem { Label("游戏", systemImage: "square.grid.2x2") }
                .tag(1)

            if FeatureFlags.siteSearch {
                SearchView()
                    .tabItem { Label("搜索", systemImage: "magnifyingglass") }
                    .tag(0)
            }

            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape") }
                .tag(2)
        }
        .background(Theme.background)
    }
}
