//
//  QuotaPreferences.swift
//  ClaudeIsland
//

import Foundation

enum QuotaZAIRegion: String, CaseIterable, Sendable {
    case global
    case chinaMainland = "china_mainland"

    var displayName: String {
        switch self {
        case .global:
            return "Global"
        case .chinaMainland:
            return "China Mainland"
        }
    }

    var baseURL: URL {
        switch self {
        case .global:
            return URL(string: "https://api.z.ai/")!
        case .chinaMainland:
            return URL(string: "https://open.bigmodel.cn/")!
        }
    }
}

enum QuotaAlibabaRegion: String, CaseIterable, Sendable {
    case international = "intl"
    case chinaMainland = "cn"

    var displayName: String {
        switch self {
        case .international:
            return "International"
        case .chinaMainland:
            return "China Mainland"
        }
    }
}

enum QuotaMiniMaxRegion: String, CaseIterable, Sendable {
    case global
    case chinaMainland = "china_mainland"

    var displayName: String {
        switch self {
        case .global:
            return "Global"
        case .chinaMainland:
            return "China Mainland"
        }
    }
}

enum QuotaPreferences {
    nonisolated private static let zaiRegionKey = "quota.zai.region"
    nonisolated private static let alibabaRegionKey = "quota.alibaba.region"
    nonisolated private static let minimaxRegionKey = "quota.minimax.region"
    nonisolated private static let openCodeWorkspaceIDKey = "quota.opencode.workspace_id"
    nonisolated private static let sourcePreferencePrefix = "quota.source_preference."
    nonisolated private static let webCredentialModePrefix = "quota.web_credential_mode."
    nonisolated private static let cliBinaryPathPrefix = "quota.cli_binary."
    nonisolated private static let credentialSourceLabelPrefix = "quota.credential_source_label."

    nonisolated static var zaiRegion: QuotaZAIRegion {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: zaiRegionKey),
                  let region = QuotaZAIRegion(rawValue: rawValue)
            else {
                return .global
            }
            return region
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: zaiRegionKey)
        }
    }

    nonisolated static var openCodeWorkspaceID: String {
        get {
            UserDefaults.standard.string(forKey: openCodeWorkspaceIDKey) ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: openCodeWorkspaceIDKey)
        }
    }

    nonisolated static var alibabaRegion: QuotaAlibabaRegion {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: alibabaRegionKey),
                  let region = QuotaAlibabaRegion(rawValue: rawValue)
            else {
                return .international
            }
            return region
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: alibabaRegionKey)
        }
    }

    nonisolated static var minimaxRegion: QuotaMiniMaxRegion {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: minimaxRegionKey),
                  let region = QuotaMiniMaxRegion(rawValue: rawValue)
            else {
                return .global
            }
            return region
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: minimaxRegionKey)
        }
    }

    nonisolated static func sourcePreference(for providerID: QuotaProviderID) -> QuotaSourcePreference {
        guard let rawValue = UserDefaults.standard.string(forKey: sourcePreferencePrefix + providerID.rawValue),
              let preference = QuotaSourcePreference(rawValue: rawValue)
        else {
            return .auto
        }
        return preference
    }

    nonisolated static func setSourcePreference(_ preference: QuotaSourcePreference, for providerID: QuotaProviderID) {
        UserDefaults.standard.set(preference.rawValue, forKey: sourcePreferencePrefix + providerID.rawValue)
    }

    nonisolated static func webCredentialMode(for providerID: QuotaProviderID) -> QuotaWebCredentialMode {
        guard let rawValue = UserDefaults.standard.string(forKey: webCredentialModePrefix + providerID.rawValue),
              let mode = QuotaWebCredentialMode(rawValue: rawValue)
        else {
            return .auto
        }
        return mode
    }

    nonisolated static func setWebCredentialMode(_ mode: QuotaWebCredentialMode, for providerID: QuotaProviderID) {
        UserDefaults.standard.set(mode.rawValue, forKey: webCredentialModePrefix + providerID.rawValue)
    }

    nonisolated static func cliBinaryPath(for providerID: QuotaProviderID) -> String {
        UserDefaults.standard.string(forKey: cliBinaryPathPrefix + providerID.rawValue) ?? ""
    }

    nonisolated static func setCLIBinaryPath(_ value: String, for providerID: QuotaProviderID) {
        UserDefaults.standard.set(value, forKey: cliBinaryPathPrefix + providerID.rawValue)
    }

    nonisolated static func credentialSourceLabel(account: String) -> String? {
        UserDefaults.standard.string(forKey: credentialSourceLabelPrefix + account)
    }

    nonisolated static func setCredentialSourceLabel(_ value: String?, account: String) {
        let key = credentialSourceLabelPrefix + account
        if let value, !value.isEmpty {
            UserDefaults.standard.set(value, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
