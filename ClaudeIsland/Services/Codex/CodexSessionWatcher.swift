//
//  CodexSessionWatcher.swift
//  ClaudeIsland
//
//  Monitors ~/.codex/session_index.jsonl for Codex Desktop session changes.
//  Creates SessionState entries for new sessions via SessionStore.
//

import Foundation
import os.log

class CodexSessionWatcher {
    static let shared = CodexSessionWatcher()

    private let logger = Logger(subsystem: "com.claudeisland", category: "CodexWatcher")
    private var fileDescriptor: Int32 = -1
    private var dispatchSource: DispatchSourceFileSystemObject?
    private var knownSessionIds: Set<String> = []
    private let queue = DispatchQueue(label: "com.claudeisland.codex-watcher", qos: .utility)

    private init() {}

    func start() {
        guard CodexSessionIndexStore.indexFileExists else {
            logger.debug("Codex session_index.jsonl not found, skipping watcher")
            return
        }

        stop()

        let path = CodexSessionIndexStore.indexFilePath
        fileDescriptor = open(path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            logger.warning("Failed to open session_index.jsonl for watching")
            return
        }

        // Initial parse
        let initial = CodexSessionIndexStore.parse()
        knownSessionIds = Set(initial.map { $0.sessionId })

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .extend, .rename],
            queue: queue
        )

        source.setEventHandler { [weak self] in
            self?.handleFileChange()
        }

        source.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd >= 0 {
                close(fd)
                self?.fileDescriptor = -1
            }
        }

        dispatchSource = source
        source.resume()

        logger.info("Codex session watcher started, tracking \(initial.count) existing sessions")
    }

    func stop() {
        dispatchSource?.cancel()
        dispatchSource = nil
    }

    private func handleFileChange() {
        let entries = CodexSessionIndexStore.parse()
        let currentIds = Set(entries.map { $0.sessionId })

        // Find new sessions
        let newIds = currentIds.subtracting(knownSessionIds)
        let removedIds = knownSessionIds.subtracting(currentIds)

        for entry in entries where newIds.contains(entry.sessionId) {
            logger.info("New Codex Desktop session: \(entry.sessionId.prefix(8), privacy: .public)")

            let hookEvent = HookEvent(
                sessionId: entry.sessionId,
                source: .codexDesktop,
                cwd: entry.projectDir,
                event: "SessionStart",
                status: "waiting_for_input",
                pid: nil,
                tty: nil,
                approvalChannel: .none,
                tool: nil,
                toolInput: nil,
                toolUseId: nil,
                notificationType: nil,
                message: nil
            )

            Task {
                await SessionStore.shared.process(.hookReceived(hookEvent))
            }
        }

        for sessionId in removedIds {
            logger.info("Codex Desktop session ended: \(sessionId.prefix(8), privacy: .public)")
            Task {
                await SessionStore.shared.process(.sessionEnded(sessionId: sessionId))
            }
        }

        knownSessionIds = currentIds
    }
}
