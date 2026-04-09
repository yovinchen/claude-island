//
//  CodexSessionIndexStore.swift
//  ClaudeIsland
//
//  Parses ~/.codex/session_index.jsonl to discover Codex App/Desktop sessions.
//

import Foundation

struct CodexSessionEntry: Equatable, Sendable {
    let sessionId: String
    let threadName: String?
    let updatedAt: Date?
}

struct CodexTranscriptMetadata: Equatable, Sendable {
    let sessionId: String
    let cwd: String
    let originator: String?
    let source: String?
}

struct CodexTranscriptDescriptor: Equatable, Sendable {
    let sessionId: String
    let path: String
    let metadata: CodexTranscriptMetadata
    let updatedAt: Date?
}

struct CodexSessionIndexStore {
    private static let iso8601WithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601Basic: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let indexPath: String = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/session_index.jsonl").path
    }()

    static func parse() -> [CodexSessionEntry] {
        guard let data = FileManager.default.contents(atPath: indexPath),
              let content = String(data: data, encoding: .utf8) else {
            return []
        }

        var entries: [CodexSessionEntry] = []
        for line in content.components(separatedBy: .newlines) where !line.isEmpty {
            guard let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                continue
            }

            let sessionId = json["id"] as? String ??
                json["session_id"] as? String ??
                json["sessionId"] as? String ??
                ""

            guard !sessionId.isEmpty else { continue }

            let threadName = json["thread_name"] as? String ?? json["threadName"] as? String
            let updatedAtString = json["updated_at"] as? String ??
                json["updatedAt"] as? String ??
                json["created_at"] as? String ??
                json["createdAt"] as? String

            entries.append(CodexSessionEntry(
                sessionId: sessionId,
                threadName: threadName,
                updatedAt: parseDate(updatedAtString)
            ))
        }

        return entries
    }

    static func transcriptPath(for sessionId: String) -> String? {
        transcriptDescriptor(for: sessionId)?.path
    }

    static func transcriptMetadata(for sessionId: String) -> CodexTranscriptMetadata? {
        transcriptDescriptor(for: sessionId)?.metadata
    }

    static func transcriptDescriptor(for sessionId: String) -> CodexTranscriptDescriptor? {
        if let transcriptPath = ConversationParser.sessionFilePath(sessionId: sessionId, cwd: "", source: .codexDesktop),
           let metadata = transcriptMetadata(atPath: transcriptPath) {
            let updatedAt = (try? FileManager.default.attributesOfItem(atPath: transcriptPath)[.modificationDate]) as? Date
            return CodexTranscriptDescriptor(
                sessionId: metadata.sessionId,
                path: transcriptPath,
                metadata: metadata,
                updatedAt: updatedAt
            )
        }

        return recentTranscriptDescriptors(limit: 200, lookback: 30 * 24 * 60 * 60)
            .first { $0.sessionId == sessionId }
    }

    static func recentTranscriptDescriptors(limit: Int = 24, lookback: TimeInterval = 48 * 60 * 60) -> [CodexTranscriptDescriptor] {
        let cutoff = Date().addingTimeInterval(-lookback)
        let fileManager = FileManager.default
        var descriptors: [CodexTranscriptDescriptor] = []

        for root in transcriptRoots where fileManager.fileExists(atPath: root.path) {
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for case let fileURL as URL in enumerator where fileURL.pathExtension == "jsonl" {
                let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .contentModificationDateKey])
                guard values?.isRegularFile == true else { continue }
                let updatedAt = values?.contentModificationDate
                if let updatedAt, updatedAt < cutoff {
                    continue
                }
                guard let metadata = transcriptMetadata(atPath: fileURL.path) else {
                    continue
                }
                descriptors.append(CodexTranscriptDescriptor(
                    sessionId: metadata.sessionId,
                    path: fileURL.path,
                    metadata: metadata,
                    updatedAt: updatedAt
                ))
            }
        }

        descriptors.sort {
            ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast)
        }

        var deduped: [CodexTranscriptDescriptor] = []
        var seenSessionIds: Set<String> = []
        for descriptor in descriptors where !seenSessionIds.contains(descriptor.sessionId) {
            seenSessionIds.insert(descriptor.sessionId)
            deduped.append(descriptor)
            if deduped.count >= limit {
                break
            }
        }

        return deduped
    }

    static var indexFileExists: Bool {
        FileManager.default.fileExists(atPath: indexPath)
    }

    static var indexFilePath: String { indexPath }

    private static var transcriptRoots: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            home.appendingPathComponent(".codex/sessions"),
            home.appendingPathComponent(".codex/archived_sessions")
        ]
    }

    private static func transcriptMetadata(atPath transcriptPath: String) -> CodexTranscriptMetadata? {
        guard let handle = FileHandle(forReadingAtPath: transcriptPath) else {
            return nil
        }
        defer { try? handle.close() }

        let data = handle.readData(ofLength: 16 * 1024)
        guard let content = String(data: data, encoding: .utf8) else { return nil }

        for line in content.components(separatedBy: .newlines) where !line.isEmpty {
            guard let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let type = json["type"] as? String,
                  type == "session_meta",
                  let payload = json["payload"] as? [String: Any],
                  let sessionId = payload["id"] as? String,
                  !sessionId.isEmpty else {
                continue
            }

            let cwd = payload["cwd"] as? String ?? ""
            return CodexTranscriptMetadata(
                sessionId: sessionId,
                cwd: cwd,
                originator: payload["originator"] as? String,
                source: payload["source"] as? String
            )
        }

        return nil
    }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        return iso8601WithFractionalSeconds.date(from: value) ?? iso8601Basic.date(from: value)
    }
}
