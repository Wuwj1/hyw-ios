import SwiftUI

@main
struct HeYiWeiApp: App {
    @StateObject private var store = GameStore()
    @StateObject private var downloads = Downloader()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(downloads)
                .tint(Theme.accent)
        }
    }
}
