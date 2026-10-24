import SwiftUI

struct SearchView: View {
    @State private var sites = Sites.load()
    @State private var query = ""
    @State private var current: Site?

    private var shown: [Site] {
        guard !query.isEmpty else { return sites }
        return sites.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.url.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let s = current {
                    SiteWebView(url: URL(string: s.url)!)
                        .navigationTitle(s.name)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("站点") { current = nil }
                            }
                        }
                } else {
                    List(shown) { s in
                        Button { current = s } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.name).foregroundStyle(Theme.text)
                                Text(s.url).font(.caption2).foregroundStyle(Theme.subText).lineLimit(1)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .searchable(text: $query, prompt: "搜索站点")
                }
            }
            .navigationTitle("站点")
        }
    }
}
