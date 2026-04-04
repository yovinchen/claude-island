//
//  DiagnosticLogger.swift
//  ClaudeIsland
//
//  Structured diagnostic logger for troubleshooting hook connections,
//  socket events, and session lifecycle issues.
//

import Foundation

actor DiagnosticLogger {
    static let shared = DiagnosticLogger()

    enum LogCategory: String, Sendable {
        case hook, socket, session, bridge, repair, sound, usage, codex
    }

    enum LogLevel: String, Sendable {
        case debug, info, warning, error
    }

    struct LogEntry: Sendable {
        let timestamp: Date
        let level: LogLevel
        let category: LogCategory
        let message: String
    }

    private var entries: [LogEntry] = []
    private let maxEntries = 500

    private init() {}

    func log(_ message: String, category: LogCategory, level: LogLevel = .info) {
        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            category: category,
            message: message
        )
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    func export() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

        var lines: [String] = []
        lines.append("Claude Island Diagnostic Log")
        lines.append("Exported: \(formatter.string(from: Date()))")
        lines.append("Entries: \(entries.count)")
        lines.append(String(repeating: "-", count: 60))

        for entry in entries {
            let ts = formatter.string(from: entry.timestamp)
            let lvl = entry.level.rawValue.uppercased().padding(toLength: 7, withPad: " ", startingAt: 0)
            lines.append("[\(ts)] [\(lvl)] [\(entry.category.rawValue)] \(entry.message)")
        }

        return lines.joined(separator: "\n")
    }

    func clear() {
        entries.removeAll()
    }

    func recentEntries(count: Int = 50) -> [LogEntry] {
        Array(entries.suffix(count))
    }
}
