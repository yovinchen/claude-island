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
    private static let zaiRegionKey = "quota.zai.region"

    static var zaiRegion: QuotaZAIRegion {
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
}
