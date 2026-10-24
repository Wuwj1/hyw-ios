import SwiftUI

struct LicensesView: View {
    /// XcodeGen 可能把资源打平到 bundle 根，也可能保留子目录，这里都试一遍。
    private var files: [URL] {
        var found: [URL] = []
        let names = ["KiriKiri-Z-LICENSE", "THIRD_PARTY_NOTICE"]
        for n in names {
            if let u = Bundle.main.url(forResource: n, withExtension: "txt", subdirectory: "Licenses") {
                found.append(u)
            } else if let u = Bundle.main.url(forResource: n, withExtension: "txt") {
                found.append(u)
            }
        }
        return found
    }

    var body: some View {
        List(files, id: \.self) { f in
            NavigationLink(f.deletingPathExtension().lastPathComponent) {
                ScrollView {
                    Text((try? String(contentsOf: f, encoding: .utf8)) ?? "读取失败")
                        .font(.caption.monospaced())
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .navigationTitle(f.deletingPathExtension().lastPathComponent)
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .navigationTitle("开源许可")
        .overlay {
            if files.isEmpty {
                ContentUnavailableView("没有许可文件", systemImage: "doc.text")
            }
        }
    }
}
