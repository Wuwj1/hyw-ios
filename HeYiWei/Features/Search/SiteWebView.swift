import SwiftUI
import WebKit

enum WebCommand { case back, forward, reload }

/// 注意：这里**不加** @MainActor，全部状态变更走 DispatchQueue.main，
/// 目的是不让 WKWebView 的 delegate 回调（非隔离上下文）直接访问主 actor 属性。
final class WebState: ObservableObject {
    @Published var progress: Double = 0
    @Published var isLoading = false
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var lastDownload: String?
    @Published var command: (WebCommand, Int) = (.reload, 0)
}

struct SiteWebView: View {
    let url: URL

    @StateObject private var state = WebState()

    var body: some View {
        VStack(spacing: 0) {
            if state.isLoading && state.progress > 0 && state.progress < 1 {
                ProgressView(value: state.progress).progressViewStyle(.linear)
            }
            WebViewRepresentable(url: url, state: state)
                .overlay(alignment: .bottom) {
                    if let name = state.lastDownload {
                        Text("已下载：\(name)")
                            .font(.caption)
                            .padding(8)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(.bottom, 12)
                    }
                }
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button { send(.back) } label: { Image(systemName: "chevron.left") }
                    .disabled(!state.canGoBack)
                Button { send(.forward) } label: { Image(systemName: "chevron.right") }
                    .disabled(!state.canGoForward)
                Spacer()
                Button { send(.reload) } label: { Image(systemName: "arrow.clockwise") }
                Spacer()
                ShareLink(item: url) { Image(systemName: "square.and.arrow.up") }
            }
        }
    }

    private func send(_ c: WebCommand) {
        let seq = state.command.1 + 1
        state.command = (c, seq)
    }
}

private struct WebViewRepresentable: UIViewRepresentable {
    let url: URL
    @ObservedObject var state: WebState

    func makeCoordinator() -> Coordinator { Coordinator(state: state) }

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        let w = WKWebView(frame: .zero, configuration: cfg)
        w.navigationDelegate = context.coordinator
        w.uiDelegate = context.coordinator
        w.allowsBackForwardNavigationGestures = true
        context.coordinator.webView = w
        context.coordinator.observe(w)
        w.load(URLRequest(url: url))
        return w
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        let (cmd, seq) = state.command
        guard seq != context.coordinator.lastSeq else { return }
        context.coordinator.lastSeq = seq
        switch cmd {
        case .back: if uiView.canGoBack { uiView.goBack() }
        case .forward: if uiView.canGoForward { uiView.goForward() }
        case .reload: uiView.reload()
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate {
        let state: WebState
        weak var webView: WKWebView?
        var lastSeq = 0
        private var obs: NSKeyValueObservation?

        init(state: WebState) { self.state = state }

        func observe(_ w: WKWebView) {
            obs = w.observe(\.estimatedProgress, options: [.new]) { [weak self] wv, _ in
                let p = wv.estimatedProgress
                DispatchQueue.main.async { self?.state.progress = p }
            }
        }

        private func sync(_ w: WKWebView) {
            let back = w.canGoBack
            let forward = w.canGoForward
            DispatchQueue.main.async { [weak self] in
                self?.state.canGoBack = back
                self?.state.canGoForward = forward
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async { [weak self] in self?.state.isLoading = true }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async { [weak self] in self?.state.isLoading = false }
            sync(webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async { [weak self] in self?.state.isLoading = false }
            sync(webView)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async { [weak self] in self?.state.isLoading = false }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                     decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            decisionHandler(navigationResponse.canShowMIMEType ? .allow : .download)
        }

        func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse,
                     didBecome download: WKDownload) {
            download.delegate = self
        }

        func webView(_ webView: WKWebView, navigationAction: WKNavigationAction,
                     didBecome download: WKDownload) {
            download.delegate = self
        }

        func download(_ download: WKDownload,
                      decideDestinationUsing response: URLResponse,
                      suggestedFilename: String,
                      completionHandler: @escaping (URL?) -> Void) {
            AppPaths.ensure()
            let base = suggestedFilename.isEmpty ? "download" : suggestedFilename
            completionHandler(AppPaths.uniqueFile(in: AppPaths.downloads, name: base))
        }

        func downloadDidFinish(_ download: WKDownload) {
            let name = download.originalRequest?.url?.lastPathComponent ?? "文件"
            DispatchQueue.main.async { [weak self] in self?.state.lastDownload = name }
        }

        func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
            DispatchQueue.main.async { [weak self] in self?.state.isLoading = false }
        }
    }
}
