//
//  KimiWireWatcher.swift
//  ClaudeIsland
//
//  Watches the latest ~/.kimi/sessions/*/wire.jsonl file for supplemental
//  status and failure notifications. This is intentionally notification-first
//  and does not attempt to recreate Kimi's full runtime schema.
//

import Foundation
import os.log

private let kimiWatcherLogger = Logger(subsystem: "com.claudeisland", category: "KimiWatcher")

final class KimiWireWatcher {
    private var fileHandle: FileHandle?
    private var source: DispatchSourceFileSystemObject?
    private var lastOffset: UInt64 = 0
    private var lastSignature: String?
    private let sessionId: String
    private let cwd: String
    private let startedAt: Date
    private let queue = DispatchQueue(label: "com.claudeisland.kimiwatcher", qos: .utility)

    init(sessionId: String, cwd: String) {
        self.sessionId = sessionId
        self.cwd = cwd
        self.startedAt = Date()
    }

    func start() {
        queue.async { [weak self] in
            self?.startWatching()
        }
    }

    private func startWatching() {
        stopInternal()

        guard let path = latestWirePath(),
              let handle = FileHandle(forReadingAtPath: path) else {
            kimiWatcherLogger.debug("Kimi wire log not found for session \(self.sessionId.prefix(8), privacy: .public)")
            return
        }

        fileHandle = handle

        do {
            lastOffset = try handle.seekToEnd()
        } catch {
            kimiWatcherLogger.error("Failed to seek Kimi wire log: \(error.localizedDescription, privacy: .public)")
            return
        }

        let fd = handle.fileDescriptor
        let newSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend],
            queue: queue
        )

        newSource.setEventHandler { [weak self] in
            self?.consumeDelta()
        }

        newSource.setCancelHandler { [weak self] in
            try? self?.fileHandle?.close()
            self?.fileHandle = nil
        }

        source = newSource
        newSource.resume()
    }

    private func latestWirePath() -> String? {
        let root = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".kimi/sessions")

        guard let children = try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        let candidates = children
            .map { $0.appendingPathComponent("wire.jsonl") }
            .filter { FileManager.default.fileExists(atPath: $0.path) }

        let recentCandidates = candidates.filter { candidate in
            let modifiedAt = (try? candidate.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return modifiedAt >= startedAt.addingTimeInterval(-300)
        }

        let preferredCandidates = recentCandidates.isEmpty ? candidates : recentCandidates

        let sorted = preferredCandidates.sorted { lhs, rhs in
            let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return lhsDate > rhsDate
        }

        return sorted.first?.path
    }

    private func consumeDelta() {
        guard let handle = fileHandle else { return }

        let currentSize: UInt64
        do {
            currentSize = try handle.seekToEnd()
        } catch {
            return
        }

        guard currentSize > lastOffset else { return }

        do {
            try handle.seek(toOffset: lastOffset)
        } catch {
            return
        }

        guard let newData = try? handle.readToEnd(),
              let newContent = String(data: newData, encoding: .utf8) else {
            return
        }

        lastOffset = currentSize

        let lines = newContent
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for line in lines {
            processLine(line)
        }
    }

    private func processLine(_ line: String) {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        let wireMessage = json["message"] as? [String: Any]
        let payload = wireMessage?["payload"] as? [String: Any] ?? [:]
        let eventName = firstString(
            nested(json, "message", "type"),
            json["type"],
            json["event"],
            json["name"],
            json["kind"]
        ) ?? "unknown"

        if !sessionId.hasPrefix("kimi-print-"), eventName == "ToolCall" {
            let toolCall = payload["function"] as? [String: Any] ?? [:]
            let toolName = firstString(toolCall["name"], payload["name"])
            let toolId = firstString(payload["id"], payload["tool_call_id"])
            var toolInput: [String: AnyCodable]?
            if let arguments = toolCall["arguments"] as? String, !arguments.isEmpty {
                if let data = arguments.data(using: .utf8),
                   let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    toolInput = anyCodableMap(parsed)
                } else {
                    toolInput = ["raw": AnyCodable(arguments)]
                }
            }

            if let toolName, let toolId {
                emit(event: HookEvent(
                    sessionId: sessionId,
                    source: .kimiCLI,
                    cwd: cwd,
                    event: "PreToolUse",
                    status: "running_tool",
                    pid: nil,
                    tty: nil,
                    approvalChannel: .none,
                    tool: toolName,
                    toolInput: toolInput,
                    toolUseId: toolId,
                    notificationType: "kimi_wire",
                    message: nil
                ))
                return
            }
        }

        if !sessionId.hasPrefix("kimi-print-"), eventName == "ToolResult" {
            let returnValue = payload["return_value"] as? [String: Any] ?? [:]
            let toolId = firstString(payload["tool_call_id"], payload["id"])
            let isError = (returnValue["is_error"] as? Bool) == true
            let output = firstString(returnValue["output"], returnValue["message"])
            emit(event: HookEvent(
                sessionId: sessionId,
                source: .kimiCLI,
                cwd: cwd,
                event: isError ? "PostToolUseFailure" : "PostToolUse",
                status: "processing",
                pid: nil,
                tty: nil,
                approvalChannel: .none,
                tool: nil,
                toolInput: nil,
                toolUseId: toolId,
                notificationType: "kimi_wire",
                message: output,
                error: isError ? output : nil,
                toolResponse: output
            ))
            return
        }

        if eventName == "StatusUpdate" {
            let message = firstString(
                payload["message"],
                payload["status"],
                payload["title"],
                payload["body"],
                json["message"],
                json["status"]
            ) ?? "Kimi status updated"
            emitDedupedNotification(kind: "status", message: "Kimi status: \(String(message.prefix(250)))")
            return
        }

        if eventName == "TurnEnd" {
            let errorMessage = firstString(
                payload["error_message"],
                payload["error"],
                payload["reason"],
                json["error_message"],
                json["error"],
                json["reason"],
                nested(json, "error", "message")
            )
            if let errorMessage {
                emitDedupedNotification(kind: "turn-end", message: "Kimi turn ended with error: \(String(errorMessage.prefix(300)))")
            }
        }
    }

    private func emitDedupedNotification(kind: String, message: String) {
        let signature = "\(kind)|\(message)"
        guard signature != lastSignature else { return }
        lastSignature = signature
        emitNotification(message: message)
    }

    private func emitNotification(message: String) {
        emit(event: HookEvent(
            sessionId: sessionId,
            source: .kimiCLI,
            cwd: cwd,
            event: "Notification",
            status: "unknown",
            pid: nil,
            tty: nil,
            approvalChannel: .none,
            tool: nil,
            toolInput: nil,
            toolUseId: nil,
            notificationType: "kimi_wire",
            message: message
        ))
    }

    private func emit(event: HookEvent) {
        Task {
            await SessionStore.shared.process(.hookReceived(event))
        }
    }

    private func anyCodableMap(_ dict: [String: Any]) -> [String: AnyCodable] {
        dict.reduce(into: [String: AnyCodable]()) { partialResult, entry in
            partialResult[entry.key] = AnyCodable(entry.value)
        }
    }

    private func emitNotificationLegacy(message: String) {
        let event = HookEvent(
            sessionId: sessionId,
            source: .kimiCLI,
            cwd: cwd,
            event: "Notification",
            status: "unknown",
            pid: nil,
            tty: nil,
            approvalChannel: .none,
            tool: nil,
            toolInput: nil,
            toolUseId: nil,
            notificationType: "kimi_wire",
            message: message
        )

        Task {
            await SessionStore.shared.process(.hookReceived(event))
        }
    }

    private func nested(_ dict: [String: Any], _ keys: String...) -> Any? {
        var current: Any = dict
        for key in keys {
            guard let dictionary = current as? [String: Any], let next = dictionary[key] else { return nil }
            current = next
        }
        return current
    }

    private func firstString(_ values: Any?...) -> String? {
        for value in values {
            if let text = value as? String, !text.isEmpty {
                return text
            }
        }
        return nil
    }

    func stop() {
        queue.async { [weak self] in
            self?.stopInternal()
        }
    }

    private func stopInternal() {
        source?.cancel()
        source = nil
    }

    deinit {
        source?.cancel()
    }
}

@MainActor
final class KimiWireWatcherManager {
    static let shared = KimiWireWatcherManager()

    private var watchers: [String: KimiWireWatcher] = [:]

    private init() {}

    func startWatching(sessionId: String, cwd: String) {
        guard watchers[sessionId] == nil else { return }

        let watcher = KimiWireWatcher(sessionId: sessionId, cwd: cwd)
        watcher.start()
        watchers[sessionId] = watcher
    }

    func stopWatching(sessionId: String) {
        watchers[sessionId]?.stop()
        watchers.removeValue(forKey: sessionId)
    }
}
