//
//  QuotaProviderProtocol.swift
//  ClaudeIsland
//

import Foundation

protocol QuotaProvider: Sendable {
    var descriptor: QuotaProviderDescriptor { get }

    func isConfigured() -> Bool
    func fetch() async throws -> QuotaSnapshot
    func fetchOutcome() async throws -> QuotaProviderFetchOutcome
}

extension QuotaProvider {
    func fetchOutcome() async throws -> QuotaProviderFetchOutcome {
        QuotaProviderFetchOutcome(snapshot: try await fetch())
    }
}

struct QuotaProviderFetchOutcome: Sendable {
    let snapshot: QuotaSnapshot
    let sourceLabel: String?
    let debugProbe: QuotaDebugProbeSnapshot?

    init(
        snapshot: QuotaSnapshot,
        sourceLabel: String? = nil,
        debugProbe: QuotaDebugProbeSnapshot? = nil
    ) {
        self.snapshot = snapshot
        self.sourceLabel = sourceLabel
        self.debugProbe = debugProbe
    }
}

protocol QuotaDebugDiagnosticCarrier: Error {
    var quotaSourceLabelOverride: String? { get }
    var quotaDebugProbeSnapshot: QuotaDebugProbeSnapshot? { get }
}

struct QuotaProviderFailure: LocalizedError, Sendable, QuotaDebugDiagnosticCarrier {
    let message: String
    let sourceLabel: String?
    let debugProbe: QuotaDebugProbeSnapshot?

    init(
        message: String,
        sourceLabel: String? = nil,
        debugProbe: QuotaDebugProbeSnapshot? = nil
    ) {
        self.message = message
        self.sourceLabel = sourceLabel
        self.debugProbe = debugProbe
    }

    var errorDescription: String? { message }
    var quotaSourceLabelOverride: String? { sourceLabel }
    var quotaDebugProbeSnapshot: QuotaDebugProbeSnapshot? { debugProbe }
}

enum QuotaProviderError: LocalizedError, Sendable {
    case missingCredentials(String)
    case unauthorized(String)
    case invalidResponse(String)
    case network(String)
    case commandFailed(String)
    case unsupported(String)

    var errorDescription: String? {
        switch self {
        case .missingCredentials(let message),
             .unauthorized(let message),
             .invalidResponse(let message),
             .network(let message),
             .commandFailed(let message),
             .unsupported(let message):
            return message
        }
    }
}
