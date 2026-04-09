//
//  QuotaWebSessionImport.swift
//  ClaudeIsland
//

import AppKit
import Foundation
import WebKit

struct QuotaWebSessionImportConfiguration: Sendable {
    let providerID: QuotaProviderID
    let windowTitle: String
    let initialURL: URL
    let allowedCookieDomains: [String]
    let readyHosts: [String]
    let readyPathHints: [String]

    func isReadyURL(_ url: URL?) -> Bool {
        guard let url, let host = url.host?.lowercased() else {
            return false
        }

        guard matches(host: host, against: readyHosts.isEmpty ? allowedCookieDomains : readyHosts) else {
            return false
        }

        if readyPathHints.isEmpty {
            return true
        }

        let path = url.path.lowercased()
        return readyPathHints.contains(where: { hint in
            path.contains(hint.lowercased())
        })
    }

    func matches(cookie: HTTPCookie) -> Bool {
        let cookieDomain = cookie.domain.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return matches(host: cookieDomain, against: allowedCookieDomains)
    }

    private func matches(host: String, against domains: [String]) -> Bool {
        let normalizedHost = host.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return domains.contains { domain in
            let normalizedDomain = domain.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
            return normalizedHost == normalizedDomain || normalizedHost.hasSuffix(".\(normalizedDomain)")
        }
    }
}

@MainActor
final class QuotaWebSessionImportRunner: NSObject {
    enum Result: Equatable {
        case success(cookieCount: Int)
        case cancelled
        case failed(String)
        case unsupported
    }

    private let configuration: QuotaWebSessionImportConfiguration
    private var webView: WKWebView?
    private var window: NSWindow?
    private var continuation: CheckedContinuation<Result, Never>?
    private var completed = false

    init(configuration: QuotaWebSessionImportConfiguration) {
        self.configuration = configuration
        super.init()
    }

    static func configuration(for providerID: QuotaProviderID) -> QuotaWebSessionImportConfiguration? {
        switch providerID {
        case .cursor:
            return QuotaWebSessionImportConfiguration(
                providerID: .cursor,
                windowTitle: "Cursor Session Import",
                initialURL: URL(string: "https://cursor.com/dashboard")!,
                allowedCookieDomains: ["cursor.com", "www.cursor.com", "cursor.sh", "authenticator.cursor.sh"],
                readyHosts: ["cursor.com", "www.cursor.com"],
                readyPathHints: ["/dashboard"]
            )
        case .claude:
            return QuotaWebSessionImportConfiguration(
                providerID: .claude,
                windowTitle: "Claude Session Import",
                initialURL: URL(string: "https://claude.ai/settings/usage")!,
                allowedCookieDomains: ["claude.ai"],
                readyHosts: ["claude.ai"],
                readyPathHints: ["/settings", "usage"]
            )
        case .opencode:
            return QuotaWebSessionImportConfiguration(
                providerID: .opencode,
                windowTitle: "OpenCode Session Import",
                initialURL: URL(string: "https://opencode.ai")!,
                allowedCookieDomains: ["opencode.ai", "www.opencode.ai"],
                readyHosts: ["opencode.ai", "www.opencode.ai"],
                readyPathHints: []
            )
        case .amp:
            return QuotaWebSessionImportConfiguration(
                providerID: .amp,
                windowTitle: "Amp Session Import",
                initialURL: URL(string: "https://ampcode.com/settings")!,
                allowedCookieDomains: ["ampcode.com", "www.ampcode.com"],
                readyHosts: ["ampcode.com", "www.ampcode.com"],
                readyPathHints: ["/settings"]
            )
        case .augment:
            return QuotaWebSessionImportConfiguration(
                providerID: .augment,
                windowTitle: "Augment Session Import",
                initialURL: URL(string: "https://app.augmentcode.com")!,
                allowedCookieDomains: ["augmentcode.com", "app.augmentcode.com"],
                readyHosts: ["app.augmentcode.com"],
                readyPathHints: []
            )
        case .alibaba:
            return QuotaWebSessionImportConfiguration(
                providerID: .alibaba,
                windowTitle: "Alibaba Session Import",
                initialURL: URL(string: "https://modelstudio.console.alibabacloud.com/ap-southeast-1/?tab=coding-plan#/efm/detail")!,
                allowedCookieDomains: ["modelstudio.console.alibabacloud.com", "bailian.console.aliyun.com", "alibabacloud.com", "aliyun.com"],
                readyHosts: ["modelstudio.console.alibabacloud.com", "bailian.console.aliyun.com"],
                readyPathHints: ["coding", "detail"]
            )
        case .factory:
            return QuotaWebSessionImportConfiguration(
                providerID: .factory,
                windowTitle: "Droid Session Import",
                initialURL: URL(string: "https://app.factory.ai/settings/billing")!,
                allowedCookieDomains: ["factory.ai", "app.factory.ai", "auth.factory.ai", "api.factory.ai"],
                readyHosts: ["app.factory.ai", "auth.factory.ai"],
                readyPathHints: ["settings", "billing"]
            )
        case .minimax:
            return QuotaWebSessionImportConfiguration(
                providerID: .minimax,
                windowTitle: "MiniMax Session Import",
                initialURL: URL(string: "https://platform.minimax.io/user-center/payment/coding-plan?cycle_type=3")!,
                allowedCookieDomains: ["platform.minimax.io", "minimax.io", "platform.minimaxi.com", "minimaxi.com"],
                readyHosts: ["platform.minimax.io", "platform.minimaxi.com"],
                readyPathHints: ["coding-plan"]
            )
        case .ollama:
            return QuotaWebSessionImportConfiguration(
                providerID: .ollama,
                windowTitle: "Ollama Session Import",
                initialURL: URL(string: "https://ollama.com/settings")!,
                allowedCookieDomains: ["ollama.com", "www.ollama.com"],
                readyHosts: ["ollama.com", "www.ollama.com"],
                readyPathHints: ["settings"]
            )
        case .perplexity:
            return QuotaWebSessionImportConfiguration(
                providerID: .perplexity,
                windowTitle: "Perplexity Session Import",
                initialURL: URL(string: "https://www.perplexity.ai/account/usage")!,
                allowedCookieDomains: ["perplexity.ai", "www.perplexity.ai"],
                readyHosts: ["perplexity.ai", "www.perplexity.ai"],
                readyPathHints: ["account", "usage"]
            )
        case .kimi:
            return QuotaWebSessionImportConfiguration(
                providerID: .kimi,
                windowTitle: "Kimi Session Import",
                initialURL: URL(string: "https://www.kimi.com/code/console")!,
                allowedCookieDomains: ["kimi.com", "www.kimi.com"],
                readyHosts: ["kimi.com", "www.kimi.com"],
                readyPathHints: ["console", "code"]
            )
        default:
            return nil
        }
    }

    static func supports(providerID: QuotaProviderID) -> Bool {
        configuration(for: providerID) != nil
    }

    static func filteredCookieHeader(cookies: [HTTPCookie], configuration: QuotaWebSessionImportConfiguration) -> String? {
        let matchingCookies = cookies
            .filter { configuration.matches(cookie: $0) }
            .sorted { lhs, rhs in
                if lhs.domain != rhs.domain {
                    return lhs.domain < rhs.domain
                }
                return lhs.name < rhs.name
            }

        guard !matchingCookies.isEmpty else {
            return nil
        }

        let pairs = matchingCookies.map { "\($0.name)=\($0.value)" }
        let joined = pairs.joined(separator: "; ")
        return QuotaRuntimeSupport.cleaned(joined)
    }

    static func run(providerID: QuotaProviderID) async -> Result {
        guard let configuration = configuration(for: providerID) else {
            return .unsupported
        }

        let runner = QuotaWebSessionImportRunner(configuration: configuration)
        return await runner.run()
    }

    private func run() async -> Result {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            self.presentWindow()
        }
    }

    private func presentWindow() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 560, height: 760), configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 760),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = configurationTitle()
        window.contentView = webView
        window.center()
        window.delegate = self
        window.makeKeyAndOrderFront(nil)
        self.window = window

        webView.load(URLRequest(url: self.configuration.initialURL))
        NSApp.activate(ignoringOtherApps: true)
    }

    private func configurationTitle() -> String {
        configuration.windowTitle
    }

    private func finish(_ result: Result) {
        guard !completed else { return }
        completed = true

        let continuation = self.continuation
        self.continuation = nil

        self.webView?.navigationDelegate = nil
        self.window?.delegate = nil
        self.window?.close()
        self.webView = nil
        self.window = nil

        continuation?.resume(returning: result)
    }

    private func attemptCapture(after delayNanoseconds: UInt64 = 400_000_000) {
        guard !completed else { return }
        Task { @MainActor in
            if delayNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: delayNanoseconds)
            }
            await self.captureSessionIfReady()
        }
    }

    private func captureSessionIfReady() async {
        guard !completed,
              let webView,
              configuration.isReadyURL(webView.url)
        else {
            return
        }

        let cookies = await webView.configuration.websiteDataStore.httpCookieStore.allCookies()
        guard let cookieHeader = Self.filteredCookieHeader(cookies: cookies, configuration: configuration) else {
            return
        }

        QuotaSecretStore.save(
            cookieHeader,
            account: QuotaProviderRegistry.secretAccountName(for: configuration.providerID)
        )
        QuotaPreferences.setCredentialSourceLabel(
            "Imported browser session",
            account: QuotaProviderRegistry.secretAccountName(for: configuration.providerID)
        )
        finish(.success(cookieCount: cookies.filter { configuration.matches(cookie: $0) }.count))
    }
}

extension QuotaWebSessionImportRunner: WKNavigationDelegate {
    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            self.attemptCapture()
        }
    }

    nonisolated func webView(
        _ webView: WKWebView,
        didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!
    ) {
        Task { @MainActor in
            self.attemptCapture(after: 700_000_000)
        }
    }

    nonisolated func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        Task { @MainActor in
            self.finish(.failed(error.localizedDescription))
        }
    }

    nonisolated func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        Task { @MainActor in
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
                return
            }
            self.finish(.failed(error.localizedDescription))
        }
    }
}

extension QuotaWebSessionImportRunner: NSWindowDelegate {
    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            if !self.completed {
                self.finish(.cancelled)
            }
        }
    }
}
