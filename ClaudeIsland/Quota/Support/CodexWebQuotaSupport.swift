//
//  CodexWebQuotaSupport.swift
//  ClaudeIsland
//

import Foundation
#if os(macOS)
import AppKit
import WebKit
#if canImport(SweetCookieKit)
import SweetCookieKit
#endif
#endif

#if os(macOS)

struct CodexWebDashboardSnapshot: Sendable {
    let signedInEmail: String?
    let accountPlan: String?
    let creditsRemaining: Double?
    let primaryLimit: QuotaWindow?
    let secondaryLimit: QuotaWindow?
    let updatedAt: Date
}

enum CodexWebDashboardParser {
    static func parse(bodyText: String, html: String, now: Date = Date()) -> CodexWebDashboardSnapshot? {
        let primary = parseRateWindow(
            from: bodyText,
            lineMatcher: isFiveHourLimitLine,
            label: "Session",
            windowMinutes: 5 * 60,
            now: now
        )
        let secondary = parseRateWindow(
            from: bodyText,
            lineMatcher: isWeeklyLimitLine,
            label: "Weekly",
            windowMinutes: 7 * 24 * 60,
            now: now
        )
        let creditsRemaining = parseCreditsRemaining(bodyText: bodyText)
        let signedInEmail = parseSignedInEmail(fromHTML: html)
        let accountPlan = parsePlan(fromHTML: html)

        guard primary != nil || secondary != nil || creditsRemaining != nil || accountPlan != nil else {
            return nil
        }

        return CodexWebDashboardSnapshot(
            signedInEmail: signedInEmail,
            accountPlan: accountPlan,
            creditsRemaining: creditsRemaining,
            primaryLimit: primary,
            secondaryLimit: secondary,
            updatedAt: now
        )
    }

    static func parseSignedInEmail(fromHTML html: String) -> String? {
        guard let data = scriptJSONData(fromHTML: html, id: "client-bootstrap"),
              let json = try? JSONSerialization.jsonObject(with: data)
        else {
            return nil
        }

        if let dict = json as? [String: Any] {
            if let session = dict["session"] as? [String: Any],
               let user = session["user"] as? [String: Any],
               let email = user["email"] as? String,
               email.contains("@")
            {
                return email.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if let user = dict["user"] as? [String: Any],
               let email = user["email"] as? String,
               email.contains("@")
            {
                return email.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    static func parsePlan(fromHTML html: String) -> String? {
        if let data = scriptJSONData(fromHTML: html, id: "client-bootstrap"), let plan = findPlan(in: data) {
            return plan
        }
        if let data = scriptJSONData(fromHTML: html, id: "__NEXT_DATA__"), let plan = findPlan(in: data) {
            return plan
        }
        return nil
    }

    static func parseCreditsRemaining(bodyText: String) -> Double? {
        let cleaned = bodyText.replacingOccurrences(of: "\r", with: "\n")
        let patterns = [
            #"credits\s*remaining[^0-9]*([0-9][0-9.,]*)"#,
            #"remaining\s*credits[^0-9]*([0-9][0-9.,]*)"#,
            #"credit\s*balance[^0-9]*([0-9][0-9.,]*)"#,
        ]
        for pattern in patterns {
            if let value = QuotaRuntimeSupport.firstNumber(pattern: pattern, in: cleaned) {
                return value
            }
        }
        return nil
    }

    private static func parseRateWindow(
        from bodyText: String,
        lineMatcher: (String) -> Bool,
        label: String,
        windowMinutes: Int?,
        now: Date
    ) -> QuotaWindow? {
        let lines = bodyText
            .replacingOccurrences(of: "\r", with: "\n")
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for index in lines.indices where lineMatcher(lines[index]) {
            let windowLines = Array(lines[index...min(lines.count - 1, index + 5)])
            var percentValue: Double?
            var isRemaining = true
            for line in windowLines {
                if let parsed = parsePercent(from: line) {
                    percentValue = parsed.value
                    isRemaining = parsed.isRemaining
                    break
                }
            }
            guard let percentValue else { continue }
            let usedPercent = isRemaining ? Swift.max(0, Swift.min(100, 100 - percentValue)) : Swift.max(0, Swift.min(100, percentValue))
            let resetLine = windowLines.first { $0.localizedCaseInsensitiveContains("reset") }
            let resetsAt = resetLine.flatMap { parseResetDate(from: $0, now: now) }
            return QuotaWindow(
                label: label,
                usedRatio: usedPercent / 100.0,
                detail: resetLine,
                resetsAt: resetsAt
            )
        }
        return nil
    }

    private static func parsePercent(from line: String) -> (value: Double, isRemaining: Bool)? {
        guard let percent = QuotaRuntimeSupport.firstNumber(pattern: #"([0-9]{1,3})\s*%"#, in: line) else {
            return nil
        }
        let lower = line.lowercased()
        if lower.contains("used") || lower.contains("spent") || lower.contains("consumed") {
            return (percent, false)
        }
        return (percent, true)
    }

    private static func isFiveHourLimitLine(_ line: String) -> Bool {
        let lower = line.lowercased()
        return lower.contains("5h") || lower.contains("5-hour") || lower.contains("5 hour")
    }

    private static func isWeeklyLimitLine(_ line: String) -> Bool {
        let lower = line.lowercased()
        return lower.contains("weekly") || lower.contains("7-day") || lower.contains("7 day") || lower.contains("7d")
    }

    private static func parseResetDate(from line: String, now: Date) -> Date? {
        var raw = line.trimmingCharacters(in: .whitespacesAndNewlines)
        raw = raw.replacingOccurrences(of: #"(?i)^resets?:?\s*"#, with: "", options: .regularExpression)
        raw = raw.replacingOccurrences(of: " at ", with: " ", options: .caseInsensitive)
        raw = raw.replacingOccurrences(of: " on ", with: " ", options: .caseInsensitive)
        raw = raw.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let calendar = Calendar(identifier: .gregorian)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.defaultDate = now

        for format in ["MMM d h:mma", "MMM d, h:mma", "MMM d HH:mm", "MMM d", "M/d h:mma", "M/d"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: raw) {
                return date < now ? calendar.date(byAdding: .year, value: 1, to: date) ?? date : date
            }
        }
        return nil
    }

    private static func scriptJSONData(fromHTML html: String, id: String) -> Data? {
        let needle = Data("id=\"\(id)\"".utf8)
        let closeNeedle = Data("</script>".utf8)
        let data = Data(html.utf8)
        guard let idRange = data.range(of: needle),
              let openTagEnd = data[idRange.upperBound...].firstIndex(of: UInt8(ascii: ">"))
        else {
            return nil
        }
        let contentStart = data.index(after: openTagEnd)
        guard let closeRange = data.range(of: closeNeedle, in: contentStart..<data.endIndex) else {
            return nil
        }
        let raw = Data(data[contentStart..<closeRange.lowerBound])
        return trimASCIIWhitespace(raw)
    }

    private static func trimASCIIWhitespace(_ data: Data) -> Data {
        guard !data.isEmpty else { return data }
        var start = data.startIndex
        var end = data.endIndex
        while start < end, isASCIIWhitespace(data[start]) {
            start = data.index(after: start)
        }
        while end > start {
            let prev = data.index(before: end)
            if isASCIIWhitespace(data[prev]) {
                end = prev
            } else {
                break
            }
        }
        return data.subdata(in: start..<end)
    }

    private static func isASCIIWhitespace(_ value: UInt8) -> Bool {
        switch value {
        case 9, 10, 13, 32: return true
        default: return false
        }
    }

    private static func findPlan(in data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) else { return nil }
        var queue: [Any] = [json]
        var seen = 0
        while !queue.isEmpty, seen < 6000 {
            let current = queue.removeFirst()
            seen += 1
            if let dict = current as? [String: Any] {
                for (key, value) in dict {
                    if let plan = planCandidate(forKey: key, value: value) {
                        return plan
                    }
                    queue.append(value)
                }
            } else if let array = current as? [Any] {
                queue.append(contentsOf: array)
            }
        }
        return nil
    }

    private static func planCandidate(forKey key: String, value: Any) -> String? {
        guard isPlanKey(key) else { return nil }
        if let str = value as? String {
            return normalizePlanValue(str)
        }
        if let dict = value as? [String: Any] {
            if let name = dict["name"] as? String, let plan = normalizePlanValue(name) { return plan }
            if let displayName = dict["displayName"] as? String, let plan = normalizePlanValue(displayName) { return plan }
            if let tier = dict["tier"] as? String, let plan = normalizePlanValue(tier) { return plan }
        }
        return nil
    }

    private static func isPlanKey(_ key: String) -> Bool {
        let lower = key.lowercased()
        return lower.contains("plan") || lower.contains("tier") || lower.contains("subscription")
    }

    private static func normalizePlanValue(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let lower = trimmed.lowercased()
        let allowed = ["free", "plus", "pro", "team", "enterprise", "business", "edu", "education", "gov", "premium", "essential"]
        guard allowed.contains(where: { lower.contains($0) }) else { return nil }
        return trimmed
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
    }
}

enum CodexBrowserCookieImporter {
    private static let cookieDomains = ["chatgpt.com", "openai.com"]

    static func hasSession() -> Bool {
        !candidateSessions().isEmpty
    }

    static func candidateSessions() -> [QuotaBrowserCookieSession] {
#if canImport(SweetCookieKit)
        QuotaBrowserCookieImporter.candidateSessions(
            domains: cookieDomains,
            browserOrder: Browser.defaultImportOrder,
            requiredCookieNames: nil,
            allowDomainFallback: true
        )
#else
        []
#endif
    }
}

@MainActor
enum CodexWebDashboardFetcher {
    private static let usageURL = URL(string: "https://chatgpt.com/codex/settings/usage")!

    static func fetch(cookieHeader: String, timeout: TimeInterval = 30) async throws -> CodexWebDashboardSnapshot {
        _ = NSApplication.shared
        let dataStore = WKWebsiteDataStore.nonPersistent()
        let cookies = buildCookies(from: cookieHeader)
        guard !cookies.isEmpty else {
            throw QuotaProviderError.missingCredentials("Codex web cookie header is empty or invalid.")
        }
        for cookie in cookies {
            await withCheckedContinuation { continuation in
                dataStore.httpCookieStore.setCookie(cookie) {
                    continuation.resume()
                }
            }
        }

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = dataStore
        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1200, height: 1400), configuration: configuration)
        let window = makeHostWindow(with: webView)
        defer { window.close() }

        webView.load(URLRequest(url: usageURL))
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            try? await Task.sleep(for: .milliseconds(500))

            let href = (try? await webView.evaluateJavaScript("window.location.href")) as? String
            if let href, !href.contains("/codex/settings/usage") {
                if href.contains("/auth") || href.contains("/login") {
                    throw QuotaProviderError.unauthorized("OpenAI web dashboard requires login.")
                }
                webView.load(URLRequest(url: usageURL))
                continue
            }

            let bodyText = (try? await webView.evaluateJavaScript("document.body ? document.body.innerText : ''")) as? String ?? ""
            let html = (try? await webView.evaluateJavaScript("document.documentElement ? document.documentElement.outerHTML : ''")) as? String ?? ""
            if bodyText.lowercased().contains("log in") || html.lowercased().contains("/auth/login") {
                throw QuotaProviderError.unauthorized("OpenAI web dashboard requires login.")
            }

            if let snapshot = CodexWebDashboardParser.parse(bodyText: bodyText, html: html) {
                return snapshot
            }
        }

        throw QuotaProviderError.invalidResponse("Timed out waiting for Codex web dashboard data.")
    }

    private static func makeHostWindow(with webView: WKWebView) -> NSWindow {
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let frame = NSRect(
            x: visibleFrame.maxX - 1,
            y: visibleFrame.maxY - 1,
            width: min(1200, visibleFrame.width),
            height: min(1400, visibleFrame.height)
        )
        let window = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.alphaValue = 0.001
        window.ignoresMouseEvents = true
        window.level = .screenSaver
        window.contentView = webView
        window.orderFrontRegardless()
        return window
    }

    private static func buildCookies(from cookieHeader: String) -> [HTTPCookie] {
        let pairs = CookieHeaderNormalizer.pairs(from: cookieHeader)
        let domains = ["chatgpt.com", "openai.com"]
        var cookies: [HTTPCookie] = []
        for pair in pairs {
            for domain in domains {
                var properties: [HTTPCookiePropertyKey: Any] = [
                    .domain: domain,
                    .path: "/",
                    .name: pair.name,
                    .value: pair.value,
                ]
                if pair.name.hasPrefix("__Secure-") || pair.name.hasPrefix("__Host-") {
                    properties[.secure] = true
                }
                if let cookie = HTTPCookie(properties: properties) {
                    cookies.append(cookie)
                }
            }
        }
        return cookies
    }
}

#if DEBUG
enum CodexWebQuotaTestingSupport {
    static func parseDashboard(bodyText: String, html: String) -> CodexWebDashboardSnapshot? {
        CodexWebDashboardParser.parse(bodyText: bodyText, html: html)
    }
}
#endif

#endif
