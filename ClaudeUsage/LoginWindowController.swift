import Cocoa
import WebKit
import os

private let loginLogger = Logger(subsystem: "com.serendipitynz.ClaudeUsage", category: "login")

@MainActor
final class LoginWindowController: NSWindowController, WKNavigationDelegate, WKHTTPCookieStoreObserver, NSWindowDelegate {
    private let webView: WKWebView
    private let onCaptured: (String) -> Void
    private var latestHeader: String?
    private var delivered = false
    private var urlObservation: NSKeyValueObservation?
    private let baseTitle = "Sign in to Claude.ai"
    private let readyTitle = "Signed in — switch to your Team if needed, then close this window"

    init(onCaptured: @escaping (String) -> Void) {
        self.onCaptured = onCaptured

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        self.webView = WKWebView(frame: .zero, configuration: config)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 720),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Sign in to Claude.ai"
        window.contentView = webView
        window.center()

        super.init(window: window)
        window.delegate = self

        webView.navigationDelegate = self
        config.websiteDataStore.httpCookieStore.add(self)

        // SPA pushState changes don't fire navigation delegates, but they do
        // update `webView.url`. Observe KVO on url to catch them.
        urlObservation = webView.observe(\.url, options: [.new]) { [weak self] _, change in
            let newURL = change.newValue?.flatMap { $0 }?.absoluteString ?? "nil"
            loginLogger.log("url KVO changed to \(newURL, privacy: .public)")
            Task { @MainActor [weak self] in
                await self?.captureIfReady()
            }
        }

        loginLogger.log("init")
        if let url = URL(string: "https://claude.ai/login") {
            webView.load(URLRequest(url: url))
        }
    }

    deinit {
        urlObservation?.invalidate()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    nonisolated func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        Task { @MainActor in
            loginLogger.log("cookiesDidChange")
            await self.captureIfReady()
        }
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        loginLogger.log("didCommit url=\(webView.url?.absoluteString ?? "nil", privacy: .public)")
        Task { await captureIfReady() }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loginLogger.log("didFinish url=\(webView.url?.absoluteString ?? "nil", privacy: .public)")
        Task { await captureIfReady() }
    }

    func windowWillClose(_ notification: Notification) {
        loginLogger.log("windowWillClose latestHeader=\(self.latestHeader != nil, privacy: .public) delivered=\(self.delivered, privacy: .public)")
        guard !delivered, let header = latestHeader else { return }
        delivered = true
        onCaptured(header)
    }

    private func captureIfReady() async {
        let store = webView.configuration.websiteDataStore.httpCookieStore
        let cookies = await store.allCookies()
        let claude = cookies.filter { $0.domain.hasSuffix("claude.ai") }
        guard let sessionKey = claude.first(where: { $0.name == "sessionKey" }),
              sessionKey.value.count > 20
        else { return }

        let header = claude.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
        let orgId = claude.first(where: { $0.name == "lastActiveOrg" })?.value ?? "(none)"
        let isNew = latestHeader != header
        latestHeader = header
        if isNew {
            loginLogger.log("header updated length=\(header.count, privacy: .public) org=\(orgId, privacy: .public)")
            window?.title = readyTitle
        }
    }
}
