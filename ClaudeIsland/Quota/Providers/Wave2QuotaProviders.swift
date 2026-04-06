//
//  Wave2QuotaProviders.swift
//  ClaudeIsland
//

import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

// MARK: - Kimi

struct KimiUsageResponse: Codable {
    let usages: [KimiUsage]
}

struct KimiUsage: Codable {
    let scope: String
    let detail: KimiUsageDetail
    let limits: [KimiRateLimit]?
}

struct KimiUsageDetail: Codable, Sendable {
    let limit: String
    let used: String?
    let remaining: String?
    let resetTime: String?
}

struct KimiRateLimit: Codable {
    let window: KimiWindow
    let detail: KimiUsageDetail
}

struct KimiWindow: Codable {
    let duration: Int
    let timeUnit: String
}

struct KimiQuotaProvider: QuotaProvider {
    let descriptor = QuotaProviderRegistry.descriptor(for: .kimi)

    func isConfigured() -> Bool {
        authToken() != nil
    }

    func fetch() async throws -> QuotaSnapshot {
        guard let authToken = authToken() else {
            throw QuotaProviderError.missingCredentials("Kimi auth token not configured.")
        }

        let response = try await fetchUsage(authToken: authToken)
        guard let codingUsage = response.usages.first(where: { $0.scope == "FEATURE_CODING" }) else {
            throw QuotaProviderError.invalidResponse("Kimi response did not include FEATURE_CODING usage.")
        }

        let weeklyLimit = QuotaRuntimeSupport.doubleValue(codingUsage.detail.limit) ?? 0
        let weeklyRemaining = QuotaRuntimeSupport.doubleValue(codingUsage.detail.remaining) ?? 0
        let weeklyUsed = QuotaRuntimeSupport.doubleValue(codingUsage.detail.used) ?? max(0, weeklyLimit - weeklyRemaining)

        let rateLimitDetail = codingUsage.limits?.first?.detail
        let rateLimitValue = rateLimitDetail.flatMap { QuotaRuntimeSupport.doubleValue($0.limit) } ?? 0
        let rateRemaining = rateLimitDetail.flatMap { QuotaRuntimeSupport.doubleValue($0.remaining) } ?? 0
        let rateUsed = rateLimitDetail.flatMap { QuotaRuntimeSupport.doubleValue($0.used) } ?? max(0, rateLimitValue - rateRemaining)

        let primaryWindow = quotaWindow(
            label: descriptor.primaryLabel,
            usedRatio: weeklyLimit > 0 ? weeklyUsed / weeklyLimit : nil,
            detail: weeklyLimit > 0 ? String(format: "%.0f / %.0f requests", weeklyUsed, weeklyLimit) : nil,
            resetsAt: QuotaUtilities.isoDate(codingUsage.detail.resetTime)
        )

        let secondaryWindow = quotaWindow(
            label: descriptor.secondaryLabel ?? "5h limit",
            usedRatio: rateLimitValue > 0 ? rateUsed / rateLimitValue : nil,
            detail: rateLimitValue > 0 ? String(format: "%.0f / %.0f requests", rateUsed, rateLimitValue) : nil,
            resetsAt: QuotaUtilities.isoDate(rateLimitDetail?.resetTime)
        )

        return QuotaSnapshot(
            providerID: .kimi,
            source: .apiKey,
            primaryWindow: primaryWindow,
            secondaryWindow: secondaryWindow,
            credits: nil,
            identity: QuotaIdentity(
                email: nil,
                organization: nil,
                plan: nil,
                detail: "Kimi For Coding"
            ),
            updatedAt: Date(),
            note: nil
        )
    }

    private func authToken() -> String? {
        SavedProviderTokenResolver.token(for: QuotaProviderID.kimi, envKeys: ["KIMI_AUTH_TOKEN"])
    }

    private func fetchUsage(authToken: String) async throws -> KimiUsageResponse {
        var request = URLRequest(url: URL(string: "https://www.kimi.com/apiv2/kimi.gateway.billing.v1.BillingService/GetUsages")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("kimi-auth=\(authToken)", forHTTPHeaderField: "Cookie")
        request.setValue("https://www.kimi.com", forHTTPHeaderField: "Origin")
        request.setValue("https://www.kimi.com/code/console", forHTTPHeaderField: "Referer")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("1", forHTTPHeaderField: "connect-protocol-version")
        request.setValue("en-US", forHTTPHeaderField: "x-language")
        request.setValue("web", forHTTPHeaderField: "x-msh-platform")
        request.setValue(TimeZone.current.identifier, forHTTPHeaderField: "r-timezone")

        if let claims = QuotaUtilities.decodeJWTClaims(authToken) {
            if let deviceID = QuotaRuntimeSupport.stringValue(claims["device_id"]) {
                request.setValue(deviceID, forHTTPHeaderField: "x-msh-device-id")
            }
            if let sessionID = QuotaRuntimeSupport.stringValue(claims["ssid"]) {
                request.setValue(sessionID, forHTTPHeaderField: "x-msh-session-id")
            }
            if let trafficID = QuotaRuntimeSupport.stringValue(claims["sub"]) {
                request.setValue(trafficID, forHTTPHeaderField: "x-traffic-id")
            }
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: ["scope": ["FEATURE_CODING"]])

        let (data, response) = try await QuotaRuntimeSupport.data(for: request)
        switch response.statusCode {
        case 200:
            return try JSONDecoder().decode(KimiUsageResponse.self, from: data)
        case 401, 403:
            throw QuotaProviderError.unauthorized("Kimi auth token is invalid or expired.")
        default:
            throw QuotaProviderError.invalidResponse("Kimi API returned HTTP \(response.statusCode)")
        }
    }
}

// MARK: - JetBrains

struct JetBrainsIDEInfo: Sendable, Equatable, Hashable {
    let name: String
    let version: String
    let basePath: String
    let quotaFilePath: String

    var displayName: String {
        "\(name) \(version)"
    }
}

struct JetBrainsQuotaInfo: Sendable, Equatable {
    let type: String?
    let used: Double
    let maximum: Double
    let available: Double
    let until: Date?

    var usedPercent: Double {
        guard maximum > 0 else { return 0 }
        return min(100, max(0, (used / maximum) * 100))
    }
}

struct JetBrainsRefillInfo: Sendable, Equatable {
    let type: String?
    let next: Date?
    let amount: Double?
    let duration: String?
}

enum JetBrainsIDEDetector {
    private static let idePatterns: [(prefix: String, displayName: String)] = [
        ("IntelliJIdea", "IntelliJ IDEA"),
        ("PyCharm", "PyCharm"),
        ("WebStorm", "WebStorm"),
        ("GoLand", "GoLand"),
        ("CLion", "CLion"),
        ("DataGrip", "DataGrip"),
        ("RubyMine", "RubyMine"),
        ("Rider", "Rider"),
        ("PhpStorm", "PhpStorm"),
        ("Fleet", "Fleet"),
        ("AndroidStudio", "Android Studio"),
        ("RustRover", "RustRover"),
        ("Aqua", "Aqua"),
        ("DataSpell", "DataSpell"),
    ]

    static func detectLatestIDE() -> JetBrainsIDEInfo? {
        let fileManager = FileManager.default
        let bases = [
            "\(NSHomeDirectory())/Library/Application Support/JetBrains",
            "\(NSHomeDirectory())/Library/Application Support/Google",
        ]

        var latest: JetBrainsIDEInfo?
        var latestModificationDate: Date?

        for base in bases where fileManager.fileExists(atPath: base) {
            guard let directories = try? fileManager.contentsOfDirectory(atPath: base) else { continue }
            for directory in directories {
                guard let ide = parse(directory: directory, basePath: base),
                      fileManager.fileExists(atPath: ide.quotaFilePath),
                      let attributes = try? fileManager.attributesOfItem(atPath: ide.quotaFilePath),
                      let modifiedAt = attributes[.modificationDate] as? Date
                else {
                    continue
                }

                if latestModificationDate == nil || modifiedAt > latestModificationDate! {
                    latestModificationDate = modifiedAt
                    latest = ide
                }
            }
        }

        return latest
    }

    static func quotaFilePath(for ideBasePath: String) -> String {
        "\(ideBasePath)/options/AIAssistantQuotaManager2.xml"
    }

    private static func parse(directory: String, basePath: String) -> JetBrainsIDEInfo? {
        let lowered = directory.lowercased()
        for pattern in idePatterns {
            guard lowered.hasPrefix(pattern.prefix.lowercased()) else { continue }
            let versionPart = String(directory.dropFirst(pattern.prefix.count))
            let version = versionPart.isEmpty ? "Unknown" : versionPart
            let fullPath = "\(basePath)/\(directory)"
            return JetBrainsIDEInfo(
                name: pattern.displayName,
                version: version,
                basePath: fullPath,
                quotaFilePath: quotaFilePath(for: fullPath)
            )
        }
        return nil
    }
}

enum JetBrainsQuotaParser {
    static func parseQuotaFile(at path: String) throws -> (JetBrainsQuotaInfo, JetBrainsRefillInfo?) {
        guard FileManager.default.fileExists(atPath: path) else {
            throw QuotaProviderError.missingCredentials("JetBrains quota file not found.")
        }

        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try parseXMLData(data)
    }

    static func parseXMLData(_ data: Data) throws -> (JetBrainsQuotaInfo, JetBrainsRefillInfo?) {
        #if os(macOS)
        let document = try XMLDocument(data: data)
        let quotaInfoRaw = try document
            .nodes(forXPath: "//component[@name='AIAssistantQuotaManager2']/option[@name='quotaInfo']/@value")
            .first?
            .stringValue
        let nextRefillRaw = try document
            .nodes(forXPath: "//component[@name='AIAssistantQuotaManager2']/option[@name='nextRefill']/@value")
            .first?
            .stringValue
        #else
        let quotaInfoRaw: String? = nil
        let nextRefillRaw: String? = nil
        #endif

        guard let quotaInfoRaw, !quotaInfoRaw.isEmpty else {
            throw QuotaProviderError.invalidResponse("JetBrains quotaInfo was not found.")
        }

        let quotaInfo = try parseQuotaInfoJSON(decodeHTMLEntities(quotaInfoRaw))
        let refillInfo = nextRefillRaw.flatMap { raw in
            try? parseRefillInfoJSON(decodeHTMLEntities(raw))
        }

        return (quotaInfo, refillInfo)
    }

    private static func decodeHTMLEntities(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&#10;", with: "\n")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&apos;", with: "'")
    }

    private static func parseQuotaInfoJSON(_ jsonString: String) throws -> JetBrainsQuotaInfo {
        guard let data = jsonString.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw QuotaProviderError.invalidResponse("JetBrains quotaInfo JSON is invalid.")
        }

        let tariffQuota = json["tariffQuota"] as? [String: Any]
        let available = QuotaRuntimeSupport.doubleValue(tariffQuota?["available"])
        let used = QuotaRuntimeSupport.doubleValue(json["current"]) ?? 0
        let maximum = QuotaRuntimeSupport.doubleValue(json["maximum"]) ?? 0
        let until = QuotaUtilities.isoDate(QuotaRuntimeSupport.stringValue(json["until"]))

        return JetBrainsQuotaInfo(
            type: QuotaRuntimeSupport.stringValue(json["type"]),
            used: used,
            maximum: maximum,
            available: available ?? max(0, maximum - used),
            until: until
        )
    }

    private static func parseRefillInfoJSON(_ jsonString: String) throws -> JetBrainsRefillInfo {
        guard let data = jsonString.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw QuotaProviderError.invalidResponse("JetBrains nextRefill JSON is invalid.")
        }

        let tariff = json["tariff"] as? [String: Any]
        return JetBrainsRefillInfo(
            type: QuotaRuntimeSupport.stringValue(json["type"]),
            next: QuotaUtilities.isoDate(QuotaRuntimeSupport.stringValue(json["next"])),
            amount: QuotaRuntimeSupport.doubleValue(json["amount"]) ?? QuotaRuntimeSupport.doubleValue(tariff?["amount"]),
            duration: QuotaRuntimeSupport.stringValue(json["duration"]) ?? QuotaRuntimeSupport.stringValue(tariff?["duration"])
        )
    }
}

struct JetBrainsQuotaProvider: QuotaProvider {
    let descriptor = QuotaProviderRegistry.descriptor(for: .jetbrains)

    func isConfigured() -> Bool {
        JetBrainsIDEDetector.detectLatestIDE() != nil
    }

    func fetch() async throws -> QuotaSnapshot {
        guard let ide = JetBrainsIDEDetector.detectLatestIDE() else {
            throw QuotaProviderError.missingCredentials("No JetBrains IDE quota file was detected.")
        }

        let (quotaInfo, refillInfo) = try JetBrainsQuotaParser.parseQuotaFile(at: ide.quotaFilePath)
        let primaryWindow = quotaWindow(
            label: descriptor.primaryLabel,
            usedRatio: quotaInfo.maximum > 0 ? quotaInfo.used / quotaInfo.maximum : nil,
            detail: String(format: "%.0f / %.0f credits", quotaInfo.used, quotaInfo.maximum),
            resetsAt: refillInfo?.next
        )

        return QuotaSnapshot(
            providerID: .jetbrains,
            source: .local,
            primaryWindow: primaryWindow,
            secondaryWindow: nil,
            credits: nil,
            identity: QuotaIdentity(
                email: nil,
                organization: ide.displayName,
                plan: quotaInfo.type,
                detail: nil
            ),
            updatedAt: Date(),
            note: refillInfo?.next.map { "Refill \(QuotaRuntimeSupport.relativeResetDescription(for: $0))" }
        )
    }
}
