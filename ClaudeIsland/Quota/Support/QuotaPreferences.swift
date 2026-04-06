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

enum QuotaPreferences {
    nonisolated private static let zaiRegionKey = "quota.zai.region"
    nonisolated private static let openCodeWorkspaceIDKey = "quota.opencode.workspace_id"
    nonisolated private static let sourcePreferencePrefix = "quota.source_preference."
    nonisolated private static let cliBinaryPathPrefix = "quota.cli_binary."

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

    nonisolated static func cliBinaryPath(for providerID: QuotaProviderID) -> String {
        UserDefaults.standard.string(forKey: cliBinaryPathPrefix + providerID.rawValue) ?? ""
    }

    nonisolated static func setCLIBinaryPath(_ value: String, for providerID: QuotaProviderID) {
        UserDefaults.standard.set(value, forKey: cliBinaryPathPrefix + providerID.rawValue)
    }
}
