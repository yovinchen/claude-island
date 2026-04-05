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
    let cwd: String
    let originator: String?
    let source: String?
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
        ConversationParser.sessionFilePath(sessionId: sessionId, cwd: "", source: .codexDesktop)
    }

    static func transcriptMetadata(for sessionId: String) -> CodexTranscriptMetadata? {
        guard let transcriptPath = transcriptPath(for: sessionId),
              let handle = FileHandle(forReadingAtPath: transcriptPath) else {
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
                  let payload = json["payload"] as? [String: Any] else {
                continue
            }

            let cwd = payload["cwd"] as? String ?? ""
            return CodexTranscriptMetadata(
                cwd: cwd,
                originator: payload["originator"] as? String,
                source: payload["source"] as? String
            )
        }

        return nil
    }

    static var indexFileExists: Bool {
        FileManager.default.fileExists(atPath: indexPath)
    }

    static var indexFilePath: String { indexPath }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        return iso8601WithFractionalSeconds.date(from: value) ?? iso8601Basic.date(from: value)
    }
}
