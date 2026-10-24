import SwiftUI

struct SettingsView: View {
    @State private var copied = false

    var body: some View {
        NavigationStack {
            List {
                Section("引擎") {
                    ForEach(EngineRegistry.all, id: \.displayName) { e in
                        HStack {
                            Text(e.displayName)
                            Spacer()
                            Text(e.isAvailable ? "可用" : "未接入")
                                .foregroundStyle(e.isAvailable ? Theme.accent : Theme.subText)
                                .font(.caption)
                        }
                    }
                    Text("KRKR / ONS 引擎需要 macOS 上构建的原生库；当前版本只提供游戏库、站点、下载与配置。")
                        .font(.caption2)
                        .foregroundStyle(Theme.subText)
                }

                Section("文件") {
                    NavigationLink("下载") { DownloadsView() }
                    LabeledContent("下载目录", value: "文件 App / 何意味 / Downloads")
                        .font(.caption)
                    Text("游戏目录由你自己选择并授权，何意味不会扫描整个存储。")
                        .font(.caption2)
                        .foregroundStyle(Theme.subText)
                }

                Section("关于") {
                    LabeledContent("版本", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-")
                    Button(copied ? "已复制群号" : "复制 QQ 群号 1031042168") {
                        UIPasteboard.general.string = "1031042168"
                        copied = true
                    }
                    NavigationLink("开源许可") { LicensesView() }
                    Text("iOS 版不含 Windows / Winlator 功能。")
                        .font(.caption2)
                        .foregroundStyle(Theme.subText)
                }
            }
            .navigationTitle("设置")
        }
    }
}
