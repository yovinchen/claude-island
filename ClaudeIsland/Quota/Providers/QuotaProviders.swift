//
//  QuotaProviders.swift
//  ClaudeIsland
//

import Foundation

private struct UnsupportedQuotaProvider: QuotaProvider {
    let descriptor: QuotaProviderDescriptor
    let message: String

    func isConfigured() -> Bool { false }

    func fetch() async throws -> QuotaSnapshot {
        throw QuotaProviderError.unsupported(message)
    }
}

enum QuotaProviderRegistry {
    private static let providerDescriptors: [QuotaProviderDescriptor] = [
        QuotaProviderDescriptor(
            id: .codex,
            sourceKind: .oauth,
            supportedSources: [.oauth, .cli],
            cliBinaryName: "codex",
            primaryLabel: "Session",
            secondaryLabel: "Weekly",
            credentialHint: "Reads ~/.codex/auth.json or Codex app-server",
            credentialPlaceholder: nil,
            supportsManualSecret: false,
            defaultEnabled: true,
            refreshInterval: 300,
            dashboardURL: "https://chatgpt.com/codex/settings/usage",
            statusURL: "https://status.openai.com/",
            sortPriority: 0
        ),
        QuotaProviderDescriptor(
            id: .claude,
            sourceKind: .oauth,
            supportedSources: [.oauth, .cli],
            cliBinaryName: "claude",
            primaryLabel: "Session",
            secondaryLabel: "Weekly",
            credentialHint: "Reads Claude OAuth credentials from Keychain or ~/.claude/.credentials.json, with CLI /usage as a fallback.",
            credentialPlaceholder: nil,
            supportsManualSecret: false,
            defaultEnabled: true,
            refreshInterval: 300,
            dashboardURL: "https://claude.ai/settings/usage",
            statusURL: "https://status.claude.com/",
            sortPriority: 1
        ),
        QuotaProviderDescriptor(
            id: .gemini,
            sourceKind: .oauth,
            supportedSources: [.oauth],
            cliBinaryName: "gemini",
            primaryLabel: "Pro",
            secondaryLabel: "Flash",
            credentialHint: "Reads ~/.gemini/oauth_creds.json",
            credentialPlaceholder: nil,
            supportsManualSecret: false,
            defaultEnabled: true,
            refreshInterval: 300,
            dashboardURL: "https://gemini.google.com",
            statusURL: "https://www.google.com/appsstatus/dashboard/products/npdyhgECDJ6tB66MxXyo/history",
            sortPriority: 2
        ),
        QuotaProviderDescriptor(
            id: .copilot,
            sourceKind: .apiKey,
            supportedSources: [.apiKey],
            cliBinaryName: nil,
            primaryLabel: "Premium",
            secondaryLabel: "Chat",
            credentialHint: "Uses a GitHub OAuth token with read:user scope for the Copilot internal API.",
            credentialPlaceholder: "Paste GitHub OAuth token…",
            supportsManualSecret: true,
            defaultEnabled: true,
            refreshInterval: 300,
            dashboardURL: "https://github.com/settings/copilot",
            statusURL: "https://www.githubstatus.com/",
            sortPriority: 3
        ),
        QuotaProviderDescriptor(
            id: .cursor,
            sourceKind: .web,
            supportedSources: [.web],
            cliBinaryName: nil,
            primaryLabel: "Total",
            secondaryLabel: "Auto",
            credentialHint: "Paste a Cookie header from cursor.com if you want to fetch Cursor quota manually.",
            credentialPlaceholder: "WorkosCursorSessionToken=…",
            supportsManualSecret: true,
            defaultEnabled: true,
            refreshInterval: 300,
            dashboardURL: "https://cursor.com",
            statusURL: nil,
            sortPriority: 4
        ),
        QuotaProviderDescriptor(
            id: .opencode,
            sourceKind: .web,
            supportedSources: [.web],
            cliBinaryName: nil,
            primaryLabel: "5-hour",
            secondaryLabel: "Weekly",
            credentialHint: "Paste a Cookie header from opencode.ai. Optionally set a workspace ID below.",
            credentialPlaceholder: "session=…; other-cookie=…",
            supportsManualSecret: true,
            defaultEnabled: true,
            refreshInterval: 300,
            dashboardURL: "https://opencode.ai",
            statusURL: nil,
            sortPriority: 5
        ),
        QuotaProviderDescriptor(
            id: .amp,
            sourceKind: .web,
            supportedSources: [.web],
            cliBinaryName: nil,
            primaryLabel: "Amp Free",
            secondaryLabel: nil,
            credentialHint: "Paste a Cookie header containing the Amp session cookie from ampcode.com/settings.",
            credentialPlaceholder: "session=…",
            supportsManualSecret: true,
            defaultEnabled: true,
            refreshInterval: 300,
            dashboardURL: "https://ampcode.com/settings",
            statusURL: nil,
            sortPriority: 6
        ),
        QuotaProviderDescriptor(
            id: .augment,
            sourceKind: .web,
            supportedSources: [.web],
            cliBinaryName: nil,
            primaryLabel: "Credits",
            secondaryLabel: nil,
            credentialHint: "Paste a Cookie header for app.augmentcode.com to fetch Augment credits and plan data.",
            credentialPlaceholder: "__Secure-next-auth.session-token=…",
            supportsManualSecret: true,
            defaultEnabled: true,
            refreshInterval: 300,
            dashboardURL: "https://app.augmentcode.com",
            statusURL: nil,
            sortPriority: 7
        ),
        QuotaProviderDescriptor(
            id: .kimi,
            sourceKind: .apiKey,
            supportedSources: [.apiKey],
            cliBinaryName: nil,
            primaryLabel: "Weekly",
            secondaryLabel: "5h limit",
            credentialHint: "Uses KIMI_AUTH_TOKEN or a saved kimi-auth token",
            credentialPlaceholder: "Paste kimi-auth token…",
            supportsManualSecret: true,
            defaultEnabled: true,
            refreshInterval: 300,
            dashboardURL: "https://www.kimi.com/code/console",
            statusURL: nil,
            sortPriority: 8
        ),
        QuotaProviderDescriptor(
            id: .kiro,
            sourceKind: .cli,
            supportedSources: [.cli],
            cliBinaryName: "kiro-cli",
            primaryLabel: "Credits",
            secondaryLabel: "Bonus",
            credentialHint: "Uses kiro-cli chat --no-interactive /usage",
            credentialPlaceholder: nil,
            supportsManualSecret: false,
            defaultEnabled: true,
            refreshInterval: 300,
            dashboardURL: "https://app.kiro.dev/account/usage",
            statusURL: "https://health.aws.amazon.com/health/status",
            sortPriority: 9
        ),
        QuotaProviderDescriptor(
            id: .jetbrains,
            sourceKind: .local,
            supportedSources: [.local],
            cliBinaryName: nil,
            primaryLabel: "Current",
            secondaryLabel: nil,
            credentialHint: "Auto-detects JetBrains IDE quota files from local configuration.",
            credentialPlaceholder: nil,
            supportsManualSecret: false,
            defaultEnabled: true,
            refreshInterval: 300,
            dashboardURL: nil,
            statusURL: nil,
            sortPriority: 10
        ),
        QuotaProviderDescriptor(
            id: .openrouter,
            sourceKind: .apiKey,
            supportedSources: [.apiKey],
            cliBinaryName: nil,
            primaryLabel: "API key limit",
            secondaryLabel: nil,
            credentialHint: "Uses OPENROUTER_API_KEY or a saved API key",
            credentialPlaceholder: "sk-or-v1-...",
            supportsManualSecret: true,
            defaultEnabled: true,
            refreshInterval: 300,
            dashboardURL: "https://openrouter.ai/settings/credits",
            statusURL: "https://status.openrouter.ai",
            sortPriority: 11
        ),
        QuotaProviderDescriptor(
            id: .warp,
            sourceKind: .apiKey,
            supportedSources: [.apiKey],
            cliBinaryName: nil,
            primaryLabel: "Credits",
            secondaryLabel: "Add-on credits",
            credentialHint: "Uses WARP_API_KEY / WARP_TOKEN or a saved API key",
            credentialPlaceholder: "wk-...",
            supportsManualSecret: true,
            defaultEnabled: true,
            refreshInterval: 300,
            dashboardURL: "https://docs.warp.dev/reference/cli/api-keys",
            statusURL: nil,
            sortPriority: 12
        ),
        QuotaProviderDescriptor(
            id: .kimiK2,
            sourceKind: .apiKey,
            supportedSources: [.apiKey],
            cliBinaryName: nil,
            primaryLabel: "Credits",
            secondaryLabel: nil,
            credentialHint: "Uses KIMI_K2_API_KEY / KIMI_API_KEY or a saved API key",
            credentialPlaceholder: "Paste API key…",
            supportsManualSecret: true,
            defaultEnabled: true,
            refreshInterval: 300,
            dashboardURL: "https://kimi-k2.ai/my-credits",
            statusURL: nil,
            sortPriority: 13
        ),
        QuotaProviderDescriptor(
            id: .zai,
            sourceKind: .apiKey,
            supportedSources: [.apiKey],
            cliBinaryName: nil,
            primaryLabel: "Tokens",
            secondaryLabel: "MCP",
            credentialHint: "Uses Z_AI_API_KEY or a saved API key",
            credentialPlaceholder: "Paste API key…",
            supportsManualSecret: true,
            defaultEnabled: true,
            refreshInterval: 300,
            dashboardURL: "https://z.ai/manage-apikey/subscription",
            statusURL: nil,
            sortPriority: 14
        ),
    ]

    private static let providers: [QuotaProviderID: any QuotaProvider] = Dictionary(
        uniqueKeysWithValues: providerDescriptors.map { descriptor in
            let provider: any QuotaProvider
            switch descriptor.id {
            case .codex:
                provider = CodexQuotaProvider()
            case .claude:
                provider = ClaudeQuotaProvider()
            case .gemini:
                provider = GeminiQuotaProvider()
            case .copilot:
                provider = CopilotQuotaProvider()
            case .cursor:
                provider = CursorQuotaProvider()
            case .opencode:
                provider = OpenCodeQuotaProvider()
            case .amp:
                provider = AmpQuotaProvider()
            case .augment:
                provider = AugmentQuotaProvider()
            case .kimi:
                provider = KimiQuotaProvider()
            case .kiro:
                provider = KiroQuotaProvider()
            case .jetbrains:
                provider = JetBrainsQuotaProvider()
            case .openrouter:
                provider = OpenRouterQuotaProvider()
            case .warp:
                provider = WarpQuotaProvider()
            case .kimiK2:
                provider = KimiK2QuotaProvider()
            case .zai:
                provider = ZAIQuotaProvider()
            }
            return (descriptor.id, provider)
        }
    )

    static func provider(for id: QuotaProviderID) -> (any QuotaProvider)? {
        providers[id]
    }

    static func descriptor(for id: QuotaProviderID) -> QuotaProviderDescriptor {
        descriptors.first(where: { $0.id == id })!
    }

    static var descriptors: [QuotaProviderDescriptor] {
        providerDescriptors.sorted { lhs, rhs in
            if lhs.sortPriority != rhs.sortPriority {
                return lhs.sortPriority < rhs.sortPriority
            }
            return lhs.id.rawValue < rhs.id.rawValue
        }
    }

    static func secretAccountName(for id: QuotaProviderID) -> String {
        "quota.token.\(id.rawValue)"
    }
}
