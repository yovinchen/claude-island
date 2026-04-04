//
//  CodexDesktopApprovalWatcher.swift
//  ClaudeIsland
//
//  Monitors active Codex Desktop sessions for approval-waiting states.
//  Detects when a tool has been silent too long, suggesting it needs user approval.
//

import Foundation
import os.log

class CodexDesktopApprovalWatcher {
    static let shared = CodexDesktopApprovalWatcher()

    private let logger = Logger(subsystem: "com.claudeisland", category: "CodexApproval")
    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.claudeisland.codex-approval", qos: .utility)
    /// Interval between checks (seconds)
    private let checkInterval: TimeInterval = 5.0
    /// How long a tool must be silent before we consider it waiting for approval
    private let silenceThreshold: TimeInterval = 30.0
    /// Sessions we've already notified about to avoid duplicate notifications
    private var notifiedSessions: Set<String> = []

    private init() {}

    func start() {
        stop()

        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(
            deadline: .now() + checkInterval,
            repeating: checkInterval
        )
        source.setEventHandler { [weak self] in
            self?.checkForApprovalStates()
        }
        timer = source
        source.resume()

        logger.debug("Codex approval watcher started")
    }

    func stop() {
        timer?.cancel()
        timer = nil
        notifiedSessions.removeAll()
    }

    private func checkForApprovalStates() {
        Task {
            let sessions = await SessionStore.shared.allSessions()
            let codexSessions = sessions.filter { $0.source == .codexDesktop }

            for session in codexSessions {
                // Check if session has a tool that's been running too long
                let now = Date()
                for (_, tool) in session.toolTracker.inProgress {
                    let elapsed = now.timeIntervalSince(tool.startTime)
                    if elapsed > silenceThreshold && tool.phase == .running {
                        let key = "\(session.sessionId):\(tool.id)"
                        guard !notifiedSessions.contains(key) else { continue }
                        notifiedSessions.insert(key)

                        logger.info("Codex tool \(tool.name, privacy: .public) appears to need approval (silent \(Int(elapsed))s)")

                        // Send sound + system notification
                        await MainActor.run {
                            SoundPackManager.shared.play(.approvalRequest)
                            NotificationManager.shared.sendPermissionNotification(
                                sessionId: session.sessionId,
                                toolName: tool.name,
                                projectName: session.projectName
                            )
                        }
                    }
                }
            }
        }
    }

    /// Clear notification state for a session (when approval is handled)
    func clearNotification(sessionId: String) {
        queue.async { [weak self] in
            self?.notifiedSessions = self?.notifiedSessions.filter { !$0.hasPrefix("\(sessionId):") } ?? []
        }
    }
}
