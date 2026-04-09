//
//  Wave2WebQuotaProviders.swift
//  ClaudeIsland
//

import Foundation
#if canImport(SweetCookieKit)
import SweetCookieKit
#endif

private func normalizedCookieHeader(_ raw: String?) -> String? {
    guard var value = QuotaRuntimeSupport.cleaned(raw), !value.isEmpty else {
        return nil
    }
    value = value.replacingOccurrences(of: #"(?i)^cookie:\s*"#, with: "", options: .regularExpression)
    return value.isEmpty ? nil : value
}

private func mergedQuotaNote(_ notes: String?...) -> String? {
    let parts: [String] = notes.compactMap { note -> String? in
        guard let cleaned = QuotaUtilities.cleaned(note) else { return nil }
        return cleaned
    }
    guard !parts.isEmpty else { return nil }
    return parts.joined(separator: " • ")
}

private func quotaDebugProbe(
    providerID: QuotaProviderID,
    attemptedSource: String?,
    resolvedSource: String? = nil,
    provenanceLabel: String? = nil,
    requestContext: String? = nil,
    lastValidation: String? = nil,
    lastFailure: String? = nil
) -> QuotaDebugProbeSnapshot {
    QuotaDebugProbeSnapshot(
        providerID: providerID,
        attemptedSource: attemptedSource,
        resolvedSource: resolvedSource,
        provenanceLabel: provenanceLabel,
        requestContext: requestContext,
        lastValidation: lastValidation,
        lastFailure: lastFailure
    )
}

private func quotaProviderFailure(
    providerID: QuotaProviderID,
    sourceLabel: String?,
    attemptedSource: String?,
    resolvedSource: String? = nil,
    provenanceLabel: String? = nil,
    requestContext: String? = nil,
    message: String
) -> QuotaProviderFailure {
    QuotaProviderFailure(
        message: message,
        sourceLabel: sourceLabel,
        debugProbe: quotaDebugProbe(
            providerID: providerID,
            attemptedSource: attemptedSource,
            resolvedSource: resolvedSource,
            provenanceLabel: provenanceLabel,
            requestContext: requestContext,
            lastValidation: nil,
            lastFailure: message
        )
    )
}

#if os(macOS) && canImport(SweetCookieKit)
private enum CursorBrowserCookieImporter {
    private static let sessionCookieNames: Set<String> = [
        "WorkosCursorSessionToken",
        "__Secure-next-auth.session-token",
        "next-auth.session-token",
        "wos-session",
        "__Secure-wos-session",
        "authjs.session-token",
        "__Secure-authjs.session-token",
    ]
    private static let cookieDomains = [
        "cursor.com",
        "www.cursor.com",
        "cursor.sh",
        "authenticator.cursor.sh",
    ]

    private static var browserOrder: [Browser] {
        let defaults = Browser.defaultImportOrder
        if defaults.contains(.safari) {
            return [.safari] + defaults.filter { $0 != .safari }
        }
        return defaults
    }

    static func hasSession() -> Bool {
        !candidateSessions().isEmpty
    }

    static func candidateSessions() -> [QuotaBrowserCookieSession] {
        QuotaBrowserCookieImporter.candidateSessions(
            domains: cookieDomains,
            browserOrder: browserOrder,
            requiredCookieNames: sessionCookieNames,
            allowDomainFallback: true
        )
    }
}

private enum OpenCodeBrowserCookieImporter {
    private static let cookieDomains = ["opencode.ai", "app.opencode.ai"]
    private static let requiredCookieNames: Set<String> = ["auth", "__Host-auth"]
    private static let browserOrder: [Browser] = {
        let preferred: [Browser] = [.chrome, .arc, .brave, .edge, .firefox, .safari]
        let defaults = Browser.defaultImportOrder
        return preferred.filter(defaults.contains) + defaults.filter { !preferred.contains($0) }
    }()

    static func hasSession() -> Bool {
        !candidateSessions().isEmpty
    }

    static func candidateSessions() -> [QuotaBrowserCookieSession] {
        QuotaBrowserCookieImporter.candidateSessions(
            domains: cookieDomains,
            browserOrder: browserOrder,
            requiredCookieNames: requiredCookieNames,
            allowDomainFallback: false
        )
    }
}

private enum AmpBrowserCookieImporter {
    private static let cookieDomains = ["ampcode.com", "www.ampcode.com"]
    private static let requiredCookieNames: Set<String> = ["session"]

    static func hasSession() -> Bool {
        !candidateSessions().isEmpty
    }

    static func candidateSessions() -> [QuotaBrowserCookieSession] {
        QuotaBrowserCookieImporter.candidateSessions(
            domains: cookieDomains,
            browserOrder: Browser.defaultImportOrder,
            requiredCookieNames: requiredCookieNames,
            allowDomainFallback: false
        ).map { session in
            let filtered = session.cookies.filter { requiredCookieNames.contains($0.name) }
            return QuotaBrowserCookieSession(cookies: filtered, sourceLabel: session.sourceLabel)
        }
    }
}

private enum AugmentBrowserCookieImporter {
    private static let cookieDomains = ["augmentcode.com", "app.augmentcode.com"]
    private static let requiredCookieNames: Set<String> = [
        "_session",
        "auth0",
        "auth0.is.authenticated",
        "a0.spajs.txs",
        "__Secure-next-auth.session-token",
        "next-auth.session-token",
        "__Host-authjs.csrf-token",
        "authjs.session-token",
    ]

    static func hasSession() -> Bool {
        !candidateSessions().isEmpty
    }

    static func candidateSessions() -> [QuotaBrowserCookieSession] {
        QuotaBrowserCookieImporter.candidateSessions(
            domains: cookieDomains,
            browserOrder: Browser.defaultImportOrder,
            requiredCookieNames: requiredCookieNames,
            allowDomainFallback: false
        )
    }
}
#endif

// MARK: - Cursor

struct CursorUsageSummary: Codable, Sendable {
    let billingCycleStart: String?
    let billingCycleEnd: String?
    let membershipType: String?
    let limitType: String?
    let isUnlimited: Bool?
    let autoModelSelectedDisplayMessage: String?
    let namedModelSelectedDisplayMessage: String?
    let individualUsage: CursorIndividualUsage?
    let teamUsage: CursorTeamUsage?
}

struct CursorIndividualUsage: Codable, Sendable {
    let plan: CursorPlanUsage?
    let onDemand: CursorOnDemandUsage?
}

struct CursorPlanUsage: Codable, Sendable {
    let enabled: Bool?
    let used: Int?
    let limit: Int?
    let remaining: Int?
    let breakdown: CursorPlanBreakdown?
    let autoPercentUsed: Double?
    let apiPercentUsed: Double?
    let totalPercentUsed: Double?
}

struct CursorPlanBreakdown: Codable, Sendable {
    let included: Int?
    let bonus: Int?
    let total: Int?
}

struct CursorOnDemandUsage: Codable, Sendable {
    let enabled: Bool?
    let used: Int?
    let limit: Int?
    let remaining: Int?
}

struct CursorTeamUsage: Codable, Sendable {
    let onDemand: CursorOnDemandUsage?
}

struct CursorUsageResponse: Codable, Sendable {
    let gpt4: CursorModelUsage?
    let startOfMonth: String?

    enum CodingKeys: String, CodingKey {
        case gpt4 = "gpt-4"
        case startOfMonth
    }
}

struct CursorModelUsage: Codable, Sendable {
    let numRequests: Int?
    let numRequestsTotal: Int?
    let numTokens: Int?
    let maxRequestUsage: Int?
    let maxTokenUsage: Int?
}

struct CursorUserInfo: Codable, Sendable {
    let email: String?
    let name: String?
    let sub: String?
}

struct CursorQuotaProvider: QuotaProvider {
    let descriptor = QuotaProviderRegistry.descriptor(for: .cursor)

    func isConfigured() -> Bool {
        !cookieCandidates().isEmpty
    }

    func fetch() async throws -> QuotaSnapshot {
        try await fetchOutcome().snapshot
    }

    func fetchOutcome() async throws -> QuotaProviderFetchOutcome {
        let candidates = cookieCandidates()
        let requestContext = "https://cursor.com/api/usage-summary"
        guard !candidates.isEmpty else {
            throw quotaProviderFailure(
                providerID: .cursor,
                sourceLabel: "Web login",
                attemptedSource: QuotaPreferences.webCredentialMode(for: .cursor).rawValue,
                requestContext: requestContext,
                message: "Cursor session not found. Sign in on cursor.com, use Import Session, or paste a Cookie header."
            )
        }

        var lastError: Error?
        for candidate in candidates {
            do {
                let snapshot = try await fetchSnapshot(
                    cookieHeader: candidate.cookieHeader,
                    sourceNote: candidate.provenanceLabel
                )
                if candidate.shouldCacheOnSuccess {
                    QuotaCookieCache.store(
                        providerID: .cursor,
                        cookieHeader: candidate.cookieHeader,
                        sourceLabel: candidate.provenanceLabel
                    )
                }
                return QuotaProviderFetchOutcome(
                    snapshot: snapshot,
                    sourceLabel: candidate.sourceLabel,
                    debugProbe: quotaDebugProbe(
                        providerID: .cursor,
                        attemptedSource: candidate.sourceKind.rawValue,
                        resolvedSource: candidate.sourceKind.rawValue,
                        provenanceLabel: candidate.provenanceLabel,
                        requestContext: requestContext,
                        lastValidation: "Cursor usage summary accepted."
                    )
                )
            } catch let error as QuotaProviderError {
                lastError = error
                if case .unauthorized = error {
                    if candidate.sourceKind == .cache {
                        QuotaCookieCache.clear(providerID: .cursor)
                    }
                    if candidate.sourceKind != .manual {
                        continue
                    }
                }
            } catch {
                lastError = error
            }
        }

        let message = lastError?.localizedDescription
            ?? "Cursor session not found. Sign in on cursor.com, use Import Session, or paste a Cookie header."
        throw quotaProviderFailure(
            providerID: .cursor,
            sourceLabel: "Web login",
            attemptedSource: candidates.map(\.sourceLabel).joined(separator: " -> "),
            provenanceLabel: candidates.last?.provenanceLabel,
            requestContext: requestContext,
            message: message
        )
    }

    func _test_snapshot(
        summary: CursorUsageSummary,
        userInfo: CursorUserInfo? = nil,
        requestUsage: CursorUsageResponse? = nil,
        updatedAt: Date = Date()
    ) -> QuotaSnapshot {
        makeSnapshot(summary: summary, userInfo: userInfo, requestUsage: requestUsage, updatedAt: updatedAt)
    }

    private func makeSnapshot(
        summary: CursorUsageSummary,
        userInfo: CursorUserInfo?,
        requestUsage: CursorUsageResponse?,
        updatedAt: Date = Date(),
        sourceNote: String? = nil
    ) -> QuotaSnapshot {
        let billingCycleEnd = summary.billingCycleEnd.flatMap { QuotaUtilities.isoDate($0) }
        let autoPercent = cursorPercentRatio(summary.individualUsage?.plan?.autoPercentUsed)
        let apiPercent = cursorPercentRatio(summary.individualUsage?.plan?.apiPercentUsed)
        let hasPlanUsageSignal = summary.individualUsage?.plan?.totalPercentUsed != nil
            || summary.individualUsage?.plan?.autoPercentUsed != nil
            || summary.individualUsage?.plan?.apiPercentUsed != nil
            || (summary.individualUsage?.plan?.limit ?? 0) > 0
            || (summary.individualUsage?.plan?.used ?? 0) > 0

        let planPercentUsed: Double? = {
            if let totalPercentUsed = summary.individualUsage?.plan?.totalPercentUsed {
                return cursorPercentRatio(totalPercentUsed)
            }
            if let autoPercent, let apiPercent {
                return max(0, min(1, (autoPercent + apiPercent) / 2))
            }
            if let autoPercent {
                return autoPercent
            }
            if let apiPercent {
                return apiPercent
            }
            let rawUsed = Double(summary.individualUsage?.plan?.used ?? 0)
            let rawLimit = Double(summary.individualUsage?.plan?.limit ?? 0)
            guard rawLimit > 0 else {
                return nil
            }
            return min(max(rawUsed / rawLimit, 0), 1)
        }()

        let requestsUsed = requestUsage?.gpt4?.numRequestsTotal ?? requestUsage?.gpt4?.numRequests
        let requestsLimit = requestUsage?.gpt4?.maxRequestUsage
        let requestRatio = quotaRatio(
            used: requestsUsed.map(Double.init),
            total: requestsLimit.map(Double.init)
        )
        let primaryDetail: String? = {
            if let requestsUsed, let requestsLimit, requestsLimit > 0 {
                return "\(requestsUsed) / \(requestsLimit) requests"
            }
            return billingCycleEnd.map { "Billing cycle ends \($0.formatted(date: .abbreviated, time: .omitted))" }
        }()

        let primaryWindow = quotaWindow(
            label: descriptor.primaryLabel,
            usedRatio: requestRatio ?? (hasPlanUsageSignal ? planPercentUsed : nil),
            detail: primaryDetail,
            resetsAt: billingCycleEnd
        )

        let secondaryWindow = quotaWindow(
            label: descriptor.secondaryLabel ?? "Auto",
            usedRatio: autoPercent,
            detail: apiPercent.map { "API \(Int(($0 * 100).rounded()))%" },
            resetsAt: billingCycleEnd
        )

        let tertiaryWindow = quotaWindow(
            label: "API",
            usedRatio: apiPercent,
            detail: autoPercent.map { "Auto \(Int(($0 * 100).rounded()))%" },
            resetsAt: billingCycleEnd
        )

        let onDemandUsed = Double(summary.individualUsage?.onDemand?.used ?? 0) / 100.0
        let onDemandLimit = summary.individualUsage?.onDemand?.limit.map { Double($0) / 100.0 }
        let teamOnDemandUsed = summary.teamUsage?.onDemand?.used.map { Double($0) / 100.0 }
        let teamOnDemandLimit = summary.teamUsage?.onDemand?.limit.map { Double($0) / 100.0 }

        let onDemandNote: String? = {
            if let onDemandLimit, onDemandLimit > 0 {
                return String(format: "On-demand $%.2f / $%.2f", onDemandUsed, onDemandLimit)
            }
            if let teamOnDemandUsed, let teamOnDemandLimit {
                return String(format: "Team on-demand $%.2f / $%.2f", teamOnDemandUsed, teamOnDemandLimit)
            }
            return nil
        }()

        return QuotaSnapshot(
            providerID: .cursor,
            source: .web,
            primaryWindow: primaryWindow,
            secondaryWindow: secondaryWindow,
            tertiaryWindow: tertiaryWindow,
            credits: nil,
            identity: QuotaIdentity(
                email: userInfo?.email,
                organization: nil,
                plan: summary.membershipType.map { formatMembershipType($0) },
                detail: userInfo?.name
            ),
            updatedAt: updatedAt,
            note: mergedQuotaNote(onDemandNote, sourceNote)
        )
    }

    private func fetchSnapshot(cookieHeader: String, sourceNote: String?) async throws -> QuotaSnapshot {
        async let summaryTask = fetchUsageSummary(cookieHeader: cookieHeader)
        async let userTask = fetchUserInfo(cookieHeader: cookieHeader)

        let summary = try await summaryTask
        let userInfo = try? await userTask
        let requestUsage: CursorUsageResponse?
        if let userID = userInfo?.sub, !userID.isEmpty {
            requestUsage = try? await fetchRequestUsage(userID: userID, cookieHeader: cookieHeader)
        } else {
            requestUsage = nil
        }

        return makeSnapshot(
            summary: summary,
            userInfo: userInfo,
            requestUsage: requestUsage,
            sourceNote: sourceNote
        )
    }

    private func cookieCandidates() -> [QuotaResolvedCookieCandidate] {
#if os(macOS) && canImport(SweetCookieKit)
        let sessions = CursorBrowserCookieImporter.candidateSessions()
#else
        let sessions: [QuotaBrowserCookieSession] = []
#endif
        return QuotaCookieCandidateResolver.candidates(
            providerID: .cursor,
            envKeys: ["CURSOR_COOKIE_HEADER"],
            browserSessions: sessions
        )
    }

    private func fetchUsageSummary(cookieHeader: String) async throws -> CursorUsageSummary {
        var request = URLRequest(url: URL(string: "https://cursor.com/api/usage-summary")!)
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")

        let (data, response) = try await QuotaRuntimeSupport.data(for: request)
        switch response.statusCode {
        case 200:
            return try JSONDecoder().decode(CursorUsageSummary.self, from: data)
        case 401, 403:
            throw QuotaProviderError.unauthorized("Cursor cookie header is invalid or expired.")
        default:
            throw QuotaProviderError.invalidResponse("Cursor usage-summary returned HTTP \(response.statusCode)")
        }
    }

    private func fetchUserInfo(cookieHeader: String) async throws -> CursorUserInfo {
        var request = URLRequest(url: URL(string: "https://cursor.com/api/auth/me")!)
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")

        let (data, response) = try await QuotaRuntimeSupport.data(for: request)
        guard response.statusCode == 200 else {
            throw QuotaProviderError.invalidResponse("Cursor auth/me returned HTTP \(response.statusCode)")
        }
        return try JSONDecoder().decode(CursorUserInfo.self, from: data)
    }

    private func fetchRequestUsage(userID: String, cookieHeader: String) async throws -> CursorUsageResponse {
        var components = URLComponents(string: "https://cursor.com/api/usage")!
        components.queryItems = [URLQueryItem(name: "user", value: userID)]

        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")

        let (data, response) = try await QuotaRuntimeSupport.data(for: request)
        guard response.statusCode == 200 else {
            throw QuotaProviderError.invalidResponse("Cursor usage returned HTTP \(response.statusCode)")
        }
        return try JSONDecoder().decode(CursorUsageResponse.self, from: data)
    }

    private func cursorPercentRatio(_ raw: Double?) -> Double? {
        guard let raw else { return nil }
        if raw > 100 { return 1 }
        return min(max(raw / 100.0, 0), 1)
    }

    private func formatMembershipType(_ type: String) -> String {
        switch type.lowercased() {
        case "enterprise":
            return "Cursor Enterprise"
        case "pro":
            return "Cursor Pro"
        case "hobby":
            return "Cursor Hobby"
        case "team":
            return "Cursor Team"
        default:
            return "Cursor \(type.capitalized)"
        }
    }
}

// MARK: - OpenCode

private struct OpenCodeUsageSnapshot: Sendable {
    let rollingUsagePercent: Double
    let weeklyUsagePercent: Double
    let rollingResetInSec: Int
    let weeklyResetInSec: Int
    let updatedAt: Date
}

struct OpenCodeQuotaProvider: QuotaProvider {
    let descriptor = QuotaProviderRegistry.descriptor(for: .opencode)

    func isConfigured() -> Bool {
        !cookieCandidates().isEmpty
    }

    func fetch() async throws -> QuotaSnapshot {
        try await fetchOutcome().snapshot
    }

    func fetchOutcome() async throws -> QuotaProviderFetchOutcome {
        let candidates = cookieCandidates()
        let requestContext = "https://opencode.ai/_server"
        guard !candidates.isEmpty else {
            throw quotaProviderFailure(
                providerID: .opencode,
                sourceLabel: "Web login",
                attemptedSource: QuotaPreferences.webCredentialMode(for: .opencode).rawValue,
                requestContext: requestContext,
                message: "OpenCode session not found. Sign in on opencode.ai, import session, or paste a Cookie header."
            )
        }

        var lastError: Error?
        for candidate in candidates {
            do {
                let snapshot = try await fetchSnapshot(cookieHeader: candidate.cookieHeader, sourceNote: candidate.provenanceLabel)
                if candidate.shouldCacheOnSuccess {
                    QuotaCookieCache.store(providerID: .opencode, cookieHeader: candidate.cookieHeader, sourceLabel: candidate.provenanceLabel)
                }
                return QuotaProviderFetchOutcome(
                    snapshot: snapshot,
                    sourceLabel: candidate.sourceLabel,
                    debugProbe: quotaDebugProbe(
                        providerID: .opencode,
                        attemptedSource: candidate.sourceKind.rawValue,
                        resolvedSource: candidate.sourceKind.rawValue,
                        provenanceLabel: candidate.provenanceLabel,
                        requestContext: requestContext,
                        lastValidation: "OpenCode workspace usage accepted."
                    )
                )
            } catch let error as QuotaProviderError {
                lastError = error
                if case .unauthorized = error {
                    if candidate.sourceKind == .cache { QuotaCookieCache.clear(providerID: .opencode) }
                    if candidate.sourceKind != .manual { continue }
                }
            } catch {
                lastError = error
            }
        }

        throw quotaProviderFailure(
            providerID: .opencode,
            sourceLabel: "Web login",
            attemptedSource: candidates.map(\.sourceLabel).joined(separator: " -> "),
            provenanceLabel: candidates.last?.provenanceLabel,
            requestContext: requestContext,
            message: lastError?.localizedDescription ?? "OpenCode session not found. Sign in on opencode.ai, import session, or paste a Cookie header."
        )
    }

    private func cookieCandidates() -> [QuotaResolvedCookieCandidate] {
#if os(macOS) && canImport(SweetCookieKit)
        let sessions = OpenCodeBrowserCookieImporter.candidateSessions()
#else
        let sessions: [QuotaBrowserCookieSession] = []
#endif
        return QuotaCookieCandidateResolver.candidates(
            providerID: .opencode,
            envKeys: ["OPENCODE_COOKIE_HEADER"],
            browserSessions: sessions
        )
    }

    private func normalizeWorkspaceID(_ raw: String?) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        if raw.hasPrefix("wrk_") { return raw }
        if let url = URL(string: raw) {
            let parts = url.pathComponents
            if let index = parts.firstIndex(of: "workspace"), parts.count > index + 1 {
                let candidate = parts[index + 1]
                if candidate.hasPrefix("wrk_") { return candidate }
            }
        }
        if let match = raw.range(of: #"wrk_[A-Za-z0-9]+"#, options: .regularExpression) {
            return String(raw[match])
        }
        return nil
    }

    #if DEBUG
    func _test_normalizeWorkspaceID(_ raw: String?) -> String? {
        normalizeWorkspaceID(raw)
    }
    #endif

    private func fetchSnapshot(cookieHeader: String, sourceNote: String?) async throws -> QuotaSnapshot {
        let workspaceID = if let override = normalizeWorkspaceID(QuotaPreferences.openCodeWorkspaceID) {
            override
        } else {
            try await fetchWorkspaceID(cookieHeader: cookieHeader)
        }

        let subscriptionText = try await fetchSubscriptionInfo(workspaceID: workspaceID, cookieHeader: cookieHeader)
        let usage = try parseSubscription(text: subscriptionText, now: Date())

        return QuotaSnapshot(
            providerID: .opencode,
            source: .web,
            primaryWindow: quotaWindow(
                label: descriptor.primaryLabel,
                usedRatio: usage.rollingUsagePercent > 1 ? usage.rollingUsagePercent / 100.0 : usage.rollingUsagePercent,
                detail: "Workspace \(workspaceID)",
                resetsAt: usage.updatedAt.addingTimeInterval(TimeInterval(usage.rollingResetInSec))
            ),
            secondaryWindow: quotaWindow(
                label: descriptor.secondaryLabel ?? "Weekly",
                usedRatio: usage.weeklyUsagePercent > 1 ? usage.weeklyUsagePercent / 100.0 : usage.weeklyUsagePercent,
                detail: nil,
                resetsAt: usage.updatedAt.addingTimeInterval(TimeInterval(usage.weeklyResetInSec))
            ),
            tertiaryWindow: nil,
            credits: nil,
            identity: QuotaIdentity(
                email: nil,
                organization: workspaceID,
                plan: nil,
                detail: nil
            ),
            updatedAt: usage.updatedAt,
            note: sourceNote
        )
    }

    private func fetchWorkspaceID(cookieHeader: String) async throws -> String {
        let text = try await fetchServerText(
            serverID: "def39973159c7f0483d8793a822b8dbb10d067e12c65455fcb4608459ba0234f",
            args: nil,
            method: "GET",
            referer: URL(string: "https://opencode.ai")!,
            cookieHeader: cookieHeader
        )

        if looksSignedOut(text: text) {
            throw QuotaProviderError.unauthorized("OpenCode cookie header is invalid or expired.")
        }

        let workspaceIDs = parseWorkspaceIDs(text: text)
        guard let workspaceID = workspaceIDs.first else {
            throw QuotaProviderError.invalidResponse("OpenCode workspace id was not found.")
        }
        return workspaceID
    }

    private func fetchSubscriptionInfo(workspaceID: String, cookieHeader: String) async throws -> String {
        let referer = URL(string: "https://opencode.ai/workspace/\(workspaceID)/billing")!
        let text = try await fetchServerText(
            serverID: "7abeebee372f304e050aaaf92be863f4a86490e382f8c79db68fd94040d691b4",
            args: [workspaceID],
            method: "GET",
            referer: referer,
            cookieHeader: cookieHeader
        )

        if looksSignedOut(text: text) {
            throw QuotaProviderError.unauthorized("OpenCode cookie header is invalid or expired.")
        }
        return text
    }

    private func fetchServerText(
        serverID: String,
        args: [Any]?,
        method: String,
        referer: URL,
        cookieHeader: String
    ) async throws -> String {
        let url = serverRequestURL(serverID: serverID, args: args, method: method)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 15
        request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        request.setValue(serverID, forHTTPHeaderField: "X-Server-Id")
        request.setValue("server-fn:\(UUID().uuidString)", forHTTPHeaderField: "X-Server-Instance")
        request.setValue("https://opencode.ai", forHTTPHeaderField: "Origin")
        request.setValue(referer.absoluteString, forHTTPHeaderField: "Referer")
        request.setValue("text/javascript, application/json;q=0.9, */*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )

        if method.uppercased() != "GET", let args {
            request.httpBody = try JSONSerialization.data(withJSONObject: args)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await QuotaRuntimeSupport.data(for: request)
        guard response.statusCode == 200 else {
            throw QuotaProviderError.invalidResponse("OpenCode server returned HTTP \(response.statusCode)")
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw QuotaProviderError.invalidResponse("OpenCode response was not UTF-8.")
        }
        return text
    }

    private func serverRequestURL(serverID: String, args: [Any]?, method: String) -> URL {
        guard method.uppercased() == "GET" else {
            return URL(string: "https://opencode.ai/_server")!
        }

        var components = URLComponents(string: "https://opencode.ai/_server")!
        var queryItems = [URLQueryItem(name: "id", value: serverID)]
        if let args, !args.isEmpty,
           let data = try? JSONSerialization.data(withJSONObject: args),
           let encodedArgs = String(data: data, encoding: .utf8)
        {
            queryItems.append(URLQueryItem(name: "args", value: encodedArgs))
        }
        components.queryItems = queryItems
        return components.url!
    }

    private func parseWorkspaceIDs(text: String) -> [String] {
        let regex = try? NSRegularExpression(pattern: #"id\s*:\s*\"(wrk_[^\"]+)\""#)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex?.matches(in: text, options: [], range: range).compactMap { match in
            guard let valueRange = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[valueRange])
        } ?? []
    }

    private func parseSubscription(text: String, now: Date) throws -> OpenCodeUsageSnapshot {
        if let snapshot = parseSubscriptionJSON(text: text, now: now) {
            return snapshot
        }

        guard let rollingPercent = extractDouble(pattern: #"rollingUsage[^}]*?usagePercent\s*:\s*([0-9]+(?:\.[0-9]+)?)"#, text: text),
              let rollingReset = extractInt(pattern: #"rollingUsage[^}]*?resetInSec\s*:\s*([0-9]+)"#, text: text),
              let weeklyPercent = extractDouble(pattern: #"weeklyUsage[^}]*?usagePercent\s*:\s*([0-9]+(?:\.[0-9]+)?)"#, text: text),
              let weeklyReset = extractInt(pattern: #"weeklyUsage[^}]*?resetInSec\s*:\s*([0-9]+)"#, text: text)
        else {
            throw QuotaProviderError.invalidResponse("OpenCode usage fields were not found.")
        }

        return OpenCodeUsageSnapshot(
            rollingUsagePercent: rollingPercent,
            weeklyUsagePercent: weeklyPercent,
            rollingResetInSec: rollingReset,
            weeklyResetInSec: weeklyReset,
            updatedAt: now
        )
    }

    private func parseSubscriptionJSON(text: String, now: Date) -> OpenCodeUsageSnapshot? {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data)
        else {
            return nil
        }
        return parseUsageJSON(object: object, now: now)
    }

    private func parseUsageJSON(object: Any, now: Date) -> OpenCodeUsageSnapshot? {
        guard let dict = object as? [String: Any] else { return nil }
        if let snapshot = parseUsageDictionary(dict, now: now) {
            return snapshot
        }
        for key in ["data", "result", "usage", "billing", "payload"] {
            if let nested = dict[key] as? [String: Any],
               let snapshot = parseUsageDictionary(nested, now: now)
            {
                return snapshot
            }
        }
        return nil
    }

    private func parseUsageDictionary(_ dict: [String: Any], now: Date) -> OpenCodeUsageSnapshot? {
        if let usage = dict["usage"] as? [String: Any],
           let snapshot = parseUsageDictionary(usage, now: now)
        {
            return snapshot
        }
        let rollingKeys = ["rollingUsage", "rolling", "rolling_usage", "rollingWindow", "rolling_window"]
        let weeklyKeys = ["weeklyUsage", "weekly", "weekly_usage", "weeklyWindow", "weekly_window"]

        let rolling = rollingKeys.compactMap { dict[$0] as? [String: Any] }.first
        let weekly = weeklyKeys.compactMap { dict[$0] as? [String: Any] }.first

        guard let rolling, let weekly,
              let rollingWindow = parseWindow(rolling, now: now),
              let weeklyWindow = parseWindow(weekly, now: now)
        else {
            return nil
        }

        return OpenCodeUsageSnapshot(
            rollingUsagePercent: rollingWindow.percent,
            weeklyUsagePercent: weeklyWindow.percent,
            rollingResetInSec: rollingWindow.resetInSec,
            weeklyResetInSec: weeklyWindow.resetInSec,
            updatedAt: now
        )
    }

    private func parseWindow(_ dict: [String: Any], now: Date) -> (percent: Double, resetInSec: Int)? {
        let percentKeys = [
            "usagePercent", "usedPercent", "percentUsed", "percent", "usage_percent",
            "used_percent", "utilization", "utilizationPercent", "utilization_percent", "usage",
        ]
        let resetInKeys = [
            "resetInSec", "resetInSeconds", "resetSeconds", "reset_sec",
            "reset_in_sec", "resetsInSec", "resetsInSeconds", "resetIn", "resetSec",
        ]
        let resetAtKeys = [
            "resetAt", "resetsAt", "reset_at", "resets_at", "nextReset", "next_reset", "renewAt", "renew_at",
        ]

        guard let percent = percentKeys.compactMap({ QuotaRuntimeSupport.doubleValue(dict[$0]) }).first else { return nil }

        var resetInSec = resetInKeys.compactMap({ QuotaRuntimeSupport.intValue(dict[$0]) }).first
        if resetInSec == nil,
           let resetAtValue = resetAtKeys.compactMap({ QuotaRuntimeSupport.stringValue(dict[$0]) }).first,
           let resetAt = QuotaUtilities.isoDate(resetAtValue)
        {
            resetInSec = max(0, Int(resetAt.timeIntervalSince(now)))
        }

        return (percent: percent, resetInSec: max(0, resetInSec ?? 0))
    }

    private func extractDouble(pattern: String, text: String) -> Double? {
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex?.firstMatch(in: text, options: [], range: range),
              let valueRange = Range(match.range(at: 1), in: text)
        else {
            return nil
        }
        return Double(text[valueRange])
    }

    private func extractInt(pattern: String, text: String) -> Int? {
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex?.firstMatch(in: text, options: [], range: range),
              let valueRange = Range(match.range(at: 1), in: text)
        else {
            return nil
        }
        return Int(text[valueRange])
    }

    private func looksSignedOut(text: String) -> Bool {
        let lower = text.lowercased()
        return lower.contains("login") || lower.contains("sign in") || lower.contains("auth/authorize")
    }
}

// MARK: - Amp

private struct AmpUsageSnapshot {
    let freeQuota: Double
    let freeUsed: Double
    let hourlyReplenishment: Double
    let windowHours: Double?
    let updatedAt: Date
}

struct AmpQuotaProvider: QuotaProvider {
    let descriptor = QuotaProviderRegistry.descriptor(for: .amp)

    func isConfigured() -> Bool {
        !cookieCandidates().isEmpty
    }

    func fetch() async throws -> QuotaSnapshot {
        try await fetchOutcome().snapshot
    }

    func fetchOutcome() async throws -> QuotaProviderFetchOutcome {
        let candidates = cookieCandidates()
        let requestContext = "https://ampcode.com/settings"
        guard !candidates.isEmpty else {
            throw quotaProviderFailure(
                providerID: .amp,
                sourceLabel: "Web login",
                attemptedSource: QuotaPreferences.webCredentialMode(for: .amp).rawValue,
                requestContext: requestContext,
                message: "Amp session not found. Sign in on ampcode.com, import session, or paste a Cookie header."
            )
        }

        var lastError: Error?
        for candidate in candidates {
            do {
                let snapshot = try await fetchSnapshot(cookieHeader: candidate.cookieHeader, sourceNote: candidate.provenanceLabel)
                if candidate.shouldCacheOnSuccess {
                    QuotaCookieCache.store(providerID: .amp, cookieHeader: candidate.cookieHeader, sourceLabel: candidate.provenanceLabel)
                }
                return QuotaProviderFetchOutcome(
                    snapshot: snapshot,
                    sourceLabel: candidate.sourceLabel,
                    debugProbe: quotaDebugProbe(
                        providerID: .amp,
                        attemptedSource: candidate.sourceKind.rawValue,
                        resolvedSource: candidate.sourceKind.rawValue,
                        provenanceLabel: candidate.provenanceLabel,
                        requestContext: requestContext,
                        lastValidation: "Amp settings usage accepted."
                    )
                )
            } catch let error as QuotaProviderError {
                lastError = error
                if case .unauthorized = error {
                    if candidate.sourceKind == .cache { QuotaCookieCache.clear(providerID: .amp) }
                    if candidate.sourceKind != .manual { continue }
                }
            } catch {
                lastError = error
            }
        }

        throw quotaProviderFailure(
            providerID: .amp,
            sourceLabel: "Web login",
            attemptedSource: candidates.map(\.sourceLabel).joined(separator: " -> "),
            provenanceLabel: candidates.last?.provenanceLabel,
            requestContext: requestContext,
            message: lastError?.localizedDescription ?? "Amp session not found. Sign in on ampcode.com, import session, or paste a Cookie header."
        )
    }

    private func cookieCandidates() -> [QuotaResolvedCookieCandidate] {
#if os(macOS) && canImport(SweetCookieKit)
        let sessions = AmpBrowserCookieImporter.candidateSessions()
#else
        let sessions: [QuotaBrowserCookieSession] = []
#endif
        return QuotaCookieCandidateResolver.candidates(
            providerID: .amp,
            envKeys: ["AMP_COOKIE_HEADER"],
            browserSessions: sessions
        )
    }

    private func fetch(cookieHeader: String) async throws -> AmpUsageSnapshot {
        var request = URLRequest(url: URL(string: "https://ampcode.com/settings")!)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        request.setValue("https://ampcode.com", forHTTPHeaderField: "Origin")
        request.setValue("https://ampcode.com/settings", forHTTPHeaderField: "Referer")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, response) = try await QuotaRuntimeSupport.data(for: request)
        switch response.statusCode {
        case 200:
            break
        case 401, 403:
            throw QuotaProviderError.unauthorized("Amp session cookie is invalid or expired.")
        default:
            throw QuotaProviderError.invalidResponse("Amp settings returned HTTP \(response.statusCode)")
        }

        let html = String(data: data, encoding: .utf8) ?? ""
        return try parseHTML(html, now: Date())
    }

    private func fetchSnapshot(cookieHeader: String, sourceNote: String?) async throws -> QuotaSnapshot {
        let snapshot = try await fetch(cookieHeader: cookieHeader)
        let quota = max(0, snapshot.freeQuota)
        let used = max(0, snapshot.freeUsed)
        let resetsAt: Date? = {
            guard quota > 0, snapshot.hourlyReplenishment > 0 else { return nil }
            let hoursToFull = used / snapshot.hourlyReplenishment
            return snapshot.updatedAt.addingTimeInterval(max(0, hoursToFull * 3600))
        }()

        return QuotaSnapshot(
            providerID: .amp,
            source: .web,
            primaryWindow: quotaWindow(
                label: descriptor.primaryLabel,
                usedRatio: quota > 0 ? used / quota : nil,
                detail: String(format: "%.0f / %.0f used", used, quota),
                resetsAt: resetsAt
            ),
            secondaryWindow: nil,
            tertiaryWindow: nil,
            credits: nil,
            identity: QuotaIdentity(
                email: nil,
                organization: nil,
                plan: "Amp Free",
                detail: nil
            ),
            updatedAt: snapshot.updatedAt,
            note: mergedQuotaNote(snapshot.windowHours.map { "Window \($0)h" }, sourceNote)
        )
    }

    private func parseHTML(_ html: String, now: Date) throws -> AmpUsageSnapshot {
        guard let usage = parseFreeTierUsage(html) else {
            let lower = html.lowercased()
            if lower.contains("sign in") || lower.contains("login") {
                throw QuotaProviderError.unauthorized("Not logged in to Amp.")
            }
            throw QuotaProviderError.invalidResponse("Amp Free usage data was not found.")
        }

        return AmpUsageSnapshot(
            freeQuota: usage.quota,
            freeUsed: usage.used,
            hourlyReplenishment: usage.hourlyReplenishment,
            windowHours: usage.windowHours,
            updatedAt: now
        )
    }

    private struct FreeTierUsage {
        let quota: Double
        let used: Double
        let hourlyReplenishment: Double
        let windowHours: Double?
    }

    private func parseFreeTierUsage(_ html: String) -> FreeTierUsage? {
        for token in ["freeTierUsage", "getFreeTierUsage"] {
            if let object = extractObject(named: token, in: html),
               let usage = parseFreeTierUsageObject(object)
            {
                return usage
            }
        }
        return nil
    }

    private func parseFreeTierUsageObject(_ object: String) -> FreeTierUsage? {
        guard let quota = number(for: "quota", in: object),
              let used = number(for: "used", in: object),
              let hourly = number(for: "hourlyReplenishment", in: object)
        else { return nil }

        return FreeTierUsage(
            quota: quota,
            used: used,
            hourlyReplenishment: hourly,
            windowHours: number(for: "windowHours", in: object)
        )
    }

    private func extractObject(named token: String, in text: String) -> String? {
        guard let tokenRange = text.range(of: token),
              let braceIndex = text[tokenRange.upperBound...].firstIndex(of: "{")
        else {
            return nil
        }

        var depth = 0
        var inString = false
        var escaped = false
        var index = braceIndex

        while index < text.endIndex {
            let char = text[index]
            if inString {
                if escaped {
                    escaped = false
                } else if char == "\\" {
                    escaped = true
                } else if char == "\"" {
                    inString = false
                }
            } else {
                if char == "\"" {
                    inString = true
                } else if char == "{" {
                    depth += 1
                } else if char == "}" {
                    depth -= 1
                    if depth == 0 {
                        return String(text[braceIndex...index])
                    }
                }
            }
            index = text.index(after: index)
        }

        return nil
    }

    private func number(for key: String, in text: String) -> Double? {
        let pattern = "\\b\(NSRegularExpression.escapedPattern(for: key))\\b\\s*:\\s*([0-9]+(?:\\.[0-9]+)?)"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex?.firstMatch(in: text, options: [], range: range),
              let valueRange = Range(match.range(at: 1), in: text)
        else {
            return nil
        }
        return Double(text[valueRange])
    }
}

// MARK: - Augment

private struct AugmentCreditsResponse: Codable, Sendable {
    let usageUnitsRemaining: Double?
    let usageUnitsConsumedThisBillingCycle: Double?
    let usageUnitsAvailable: Double?

    var credits: Double? { usageUnitsRemaining }
    var creditsUsed: Double? { usageUnitsConsumedThisBillingCycle }
    var creditsLimit: Double? {
        guard let remaining = usageUnitsRemaining, let consumed = usageUnitsConsumedThisBillingCycle else { return nil }
        return remaining + consumed
    }
}

private struct AugmentSubscriptionResponse: Codable, Sendable {
    let planName: String?
    let billingPeriodEnd: String?
    let email: String?
    let organization: String?
}

struct AugmentQuotaProvider: QuotaProvider {
    let descriptor = QuotaProviderRegistry.descriptor(for: .augment)

    func isConfigured() -> Bool {
        !cookieCandidates().isEmpty
    }

    func fetch() async throws -> QuotaSnapshot {
        try await fetchOutcome().snapshot
    }

    func fetchOutcome() async throws -> QuotaProviderFetchOutcome {
        let candidates = cookieCandidates()
        let requestContext = "https://app.augmentcode.com/api/credits"
        guard !candidates.isEmpty else {
            throw quotaProviderFailure(
                providerID: .augment,
                sourceLabel: "Web login",
                attemptedSource: QuotaPreferences.webCredentialMode(for: .augment).rawValue,
                requestContext: requestContext,
                message: "Augment session not found. Sign in on app.augmentcode.com, import session, or paste a Cookie header."
            )
        }

        var lastError: Error?
        for candidate in candidates {
            do {
                let snapshot = try await fetchSnapshot(cookieHeader: candidate.cookieHeader, sourceNote: candidate.provenanceLabel)
                if candidate.shouldCacheOnSuccess {
                    QuotaCookieCache.store(providerID: .augment, cookieHeader: candidate.cookieHeader, sourceLabel: candidate.provenanceLabel)
                }
                return QuotaProviderFetchOutcome(
                    snapshot: snapshot,
                    sourceLabel: candidate.sourceLabel,
                    debugProbe: quotaDebugProbe(
                        providerID: .augment,
                        attemptedSource: candidate.sourceKind.rawValue,
                        resolvedSource: candidate.sourceKind.rawValue,
                        provenanceLabel: candidate.provenanceLabel,
                        requestContext: requestContext,
                        lastValidation: "Augment credits accepted."
                    )
                )
            } catch let error as QuotaProviderError {
                lastError = error
                if case .unauthorized = error {
                    if candidate.sourceKind == .cache { QuotaCookieCache.clear(providerID: .augment) }
                    if candidate.sourceKind != .manual { continue }
                }
            } catch {
                lastError = error
            }
        }

        throw quotaProviderFailure(
            providerID: .augment,
            sourceLabel: "Web login",
            attemptedSource: candidates.map(\.sourceLabel).joined(separator: " -> "),
            provenanceLabel: candidates.last?.provenanceLabel,
            requestContext: requestContext,
            message: lastError?.localizedDescription ?? "Augment session not found. Sign in on app.augmentcode.com, import session, or paste a Cookie header."
        )
    }

    private func cookieCandidates() -> [QuotaResolvedCookieCandidate] {
#if os(macOS) && canImport(SweetCookieKit)
        let sessions = AugmentBrowserCookieImporter.candidateSessions()
#else
        let sessions: [QuotaBrowserCookieSession] = []
#endif
        return QuotaCookieCandidateResolver.candidates(
            providerID: .augment,
            envKeys: ["AUGMENT_COOKIE_HEADER"],
            browserSessions: sessions
        )
    }

    private func fetchCredits(cookieHeader: String) async throws -> AugmentCreditsResponse {
        var request = URLRequest(url: URL(string: "https://app.augmentcode.com/api/credits")!)
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")

        let (data, response) = try await QuotaRuntimeSupport.data(for: request)
        switch response.statusCode {
        case 200:
            return try JSONDecoder().decode(AugmentCreditsResponse.self, from: data)
        case 401:
            throw QuotaProviderError.unauthorized("Augment session expired.")
        case 403:
            throw QuotaProviderError.unauthorized("Not logged in to Augment.")
        default:
            throw QuotaProviderError.invalidResponse("Augment credits API returned HTTP \(response.statusCode)")
        }
    }

    private func fetchSubscription(cookieHeader: String) async throws -> AugmentSubscriptionResponse {
        var request = URLRequest(url: URL(string: "https://app.augmentcode.com/api/subscription")!)
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")

        let (data, response) = try await QuotaRuntimeSupport.data(for: request)
        switch response.statusCode {
        case 200:
            return try JSONDecoder().decode(AugmentSubscriptionResponse.self, from: data)
        case 401:
            throw QuotaProviderError.unauthorized("Augment session expired.")
        case 403:
            throw QuotaProviderError.unauthorized("Not logged in to Augment.")
        default:
            throw QuotaProviderError.invalidResponse("Augment subscription API returned HTTP \(response.statusCode)")
        }
    }

    private func fetchSnapshot(cookieHeader: String, sourceNote: String?) async throws -> QuotaSnapshot {
        async let creditsTask = fetchCredits(cookieHeader: cookieHeader)
        async let subscriptionTask = fetchSubscription(cookieHeader: cookieHeader)

        let credits = try await creditsTask
        let subscription = try? await subscriptionTask
        let billingCycleEnd = subscription?.billingPeriodEnd.flatMap { QuotaUtilities.isoDate($0) }

        return QuotaSnapshot(
            providerID: .augment,
            source: .web,
            primaryWindow: quotaWindow(
                label: descriptor.primaryLabel,
                usedRatio: quotaRatio(used: credits.creditsUsed, total: credits.creditsLimit),
                detail: {
                    guard let used = credits.creditsUsed, let limit = credits.creditsLimit else { return nil }
                    return String(format: "%.0f / %.0f credits", used, limit)
                }(),
                resetsAt: billingCycleEnd
            ),
            secondaryWindow: nil,
            tertiaryWindow: nil,
            credits: QuotaCredits(
                label: "Credits",
                used: credits.creditsUsed,
                total: credits.creditsLimit,
                remaining: credits.credits,
                currencyCode: nil,
                isUnlimited: false
            ),
            identity: QuotaIdentity(
                email: subscription?.email,
                organization: subscription?.organization,
                plan: subscription?.planName,
                detail: nil
            ),
            updatedAt: Date(),
            note: sourceNote
        )
    }
}
