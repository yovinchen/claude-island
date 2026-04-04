//
//  TerminalTitleManager.swift
//  ClaudeIsland
//
//  Manages terminal tab titles via OSC 2 for Ghostty and other supporting terminals.
//  Writes title files to /tmp/ that Ghostty can read to update tab labels.
//

import Foundation

class TerminalTitleManager {
    static let shared = TerminalTitleManager()

    private let titlePrefix = "/tmp/claude-island-osc2-title-"

    private init() {}

    /// Set the terminal title for a session via OSC 2 title file
    func setTitle(_ title: String, for session: SessionState) {
        let filePath = titlePrefix + session.sessionId
        let sanitized = title.replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: "")
        try? sanitized.write(toFile: filePath, atomically: true, encoding: .utf8)
    }

    /// Format a title string from session info
    func formatTitle(project: String, status: String, sessionId: String) -> String {
        let shortId = String(sessionId.prefix(8))
        return "\(project) \u{2014} \(status) \u{2014} \(shortId)"
    }

    /// Update the title for a session based on its current state
    func updateTitle(for session: SessionState) {
        let status: String
        switch session.phase {
        case .idle:
            status = "idle"
        case .processing:
            status = "processing"
        case .waitingForInput:
            status = "ready"
        case .waitingForApproval:
            status = "approval needed"
        case .compacting:
            status = "compacting"
        case .ended:
            clearTitle(for: session.sessionId)
            return
        }

        let title = formatTitle(
            project: session.projectName,
            status: status,
            sessionId: session.sessionId
        )
        setTitle(title, for: session)
    }

    /// Clear the title file for a session
    func clearTitle(for sessionId: String) {
        let filePath = titlePrefix + sessionId
        try? FileManager.default.removeItem(atPath: filePath)
    }
}
