//
//  QuotaCookieSupport.swift
//  ClaudeIsland
//

import Foundation
#if canImport(SweetCookieKit)
import SweetCookieKit
#endif

struct QuotaCookieCacheEntry: Codable, Sendable {
    let cookieHeader: String
    let sourceLabel: String
    let storedAt: Date
}

enum CookieHeaderNormalizer {
    struct Pair: Equatable, Sendable {
        let name: String
        let value: String
    }

    static func pairs(from raw: String) -> [Pair] {
        raw.split(separator: ";").compactMap { segment in
            let trimmed = segment.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, let equals = trimmed.firstIndex(of: "=") else {
                return nil
            }
            let name = String(trimmed[..<equals]).trimmingCharacters(in: .whitespacesAndNewlines)
            let value = String(trimmed[trimmed.index(after: equals)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, !value.isEmpty else { return nil }
            return Pair(name: name, value: value)
        }
    }
}

enum QuotaCookieCache {
    static func load(providerID: QuotaProviderID) -> QuotaCookieCacheEntry? {
        guard let data = try? Data(contentsOf: fileURL(providerID: providerID)) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(QuotaCookieCacheEntry.self, from: data)
    }

    static func store(
        providerID: QuotaProviderID,
        cookieHeader: String,
        sourceLabel: String,
        now: Date = Date()
    ) {
        guard let normalized = normalizedCacheCookieHeader(cookieHeader) else {
            clear(providerID: providerID)
            return
        }

        let entry = QuotaCookieCacheEntry(
            cookieHeader: normalized,
            sourceLabel: sourceLabel,
            storedAt: now
        )

        do {
            let url = fileURL(providerID: providerID)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(entry)
            try data.write(to: url, options: Data.WritingOptions.atomic)
        } catch {
            // Ignore cache write failures; quota fetch can still continue with live credentials.
        }
    }

    static func clear(providerID: QuotaProviderID) {
        try? FileManager.default.removeItem(at: fileURL(providerID: providerID))
    }

    private static func fileURL(providerID: QuotaProviderID) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("ClaudeIsland", isDirectory: true)
            .appendingPathComponent("QuotaCookieCache", isDirectory: true)
            .appendingPathComponent("\(providerID.rawValue).json")
    }

    private static func normalizedCacheCookieHeader(_ raw: String?) -> String? {
        guard var value = QuotaRuntimeSupport.cleaned(raw), !value.isEmpty else {
            return nil
        }
        value = value.replacingOccurrences(of: #"(?i)^cookie:\s*"#, with: "", options: .regularExpression)
        return value.isEmpty ? nil : value
    }
}

#if os(macOS) && canImport(SweetCookieKit)
struct QuotaBrowserCookieSession: Sendable {
    let cookies: [HTTPCookie]
    let sourceLabel: String

    var cookieHeader: String {
        cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
    }

    func cookieValue(named name: String) -> String? {
        cookies.first(where: { $0.name == name })?.value
    }
}

enum QuotaBrowserCookieImporter {
    private static let cookieClient = BrowserCookieClient()

    static func candidateSessions(
        domains: [String],
        browserOrder: [Browser],
        requiredCookieNames: Set<String>? = nil,
        allowDomainFallback: Bool = false
    ) -> [QuotaBrowserCookieSession] {
        let strict = browserOrder.flatMap {
            importSessions(
                from: $0,
                domains: domains,
                requiredCookieNames: requiredCookieNames,
                requireKnownSessionName: requiredCookieNames != nil
            )
        }

        if !strict.isEmpty || !allowDomainFallback {
            return deduplicated(strict)
        }

        let fallback = browserOrder.flatMap {
            importSessions(
                from: $0,
                domains: domains,
                requiredCookieNames: requiredCookieNames,
                requireKnownSessionName: false
            )
        }
        return deduplicated(fallback)
    }

    private static func deduplicated(_ sessions: [QuotaBrowserCookieSession]) -> [QuotaBrowserCookieSession] {
        var seen: Set<String> = []
        return sessions.filter { session in
            seen.insert(session.cookieHeader).inserted
        }
    }

    private static func importSessions(
        from browser: Browser,
        domains: [String],
        requiredCookieNames: Set<String>?,
        requireKnownSessionName: Bool
    ) -> [QuotaBrowserCookieSession] {
        do {
            let query = BrowserCookieQuery(domains: domains)
            let sources = try cookieClient.records(matching: query, in: browser, logger: nil)
            var sessions: [QuotaBrowserCookieSession] = []

            for source in sources where !source.records.isEmpty {
                let cookies = BrowserCookieClient.makeHTTPCookies(source.records, origin: query.origin)
                guard !cookies.isEmpty else { continue }

                if let requiredCookieNames {
                    let matching = cookies.filter { requiredCookieNames.contains($0.name) }
                    if !matching.isEmpty {
                        sessions.append(QuotaBrowserCookieSession(cookies: cookies, sourceLabel: source.label))
                        continue
                    }
                    if requireKnownSessionName {
                        continue
                    }
                }

                if !requireKnownSessionName {
                    sessions.append(QuotaBrowserCookieSession(cookies: cookies, sourceLabel: "\(source.label) (domain cookies)"))
                }
            }

            return sessions
        } catch {
            return []
        }
    }
}
#endif
