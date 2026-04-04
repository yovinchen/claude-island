//
//  TerminalTitleManager.swift
//  ClaudeIslandBridge
//
//  Sets terminal tab title via OSC2 escape sequence for supported terminals
//  (Ghostty, xterm-ghostty). Writes title to TTY device and caches in tmpfile.
//

import Foundation

enum TerminalTitleManager {
    private static let env = ProcessInfo.processInfo.environment
    private static let termProgram = env["TERM_PROGRAM"] ?? ""
    private static let isInTmux = env["TMUX"] != nil

    /// Whether the current terminal supports OSC2 title setting
    static var isSupported: Bool {
        let supported = ["ghostty", "xterm-ghostty"]
        return supported.contains(termProgram) && !isInTmux
    }

    /// Set terminal tab title for the current session
    /// - Parameters:
    ///   - sessionId: The session identifier
    ///   - cwd: Working directory path
    ///   - userText: User's prompt text (optional)
    ///   - aiTitle: AI-generated session title (optional)
    ///   - ttyPath: TTY device path to write to
    static func setTitle(
        sessionId: String,
        cwd: String?,
        userText: String? = nil,
        aiTitle: String? = nil,
        ttyPath: String? = nil
    ) {
        guard isSupported else { return }

        let project = (cwd ?? env["PWD"] ?? "session")
            .components(separatedBy: "/").last ?? "session"
        let prefix = String(sessionId.replacingOccurrences(of: "opencode-", with: "").prefix(16))

        // Determine display title
        var displayTitle: String?
        if let aiTitle, !aiTitle.isEmpty {
            displayTitle = aiTitle.replacingOccurrences(of: "\n", with: " ")
            if displayTitle!.count > 30 { displayTitle = String(displayTitle!.prefix(30)) }
        } else if let userText, !userText.isEmpty {
            displayTitle = userText.replacingOccurrences(of: "\n", with: " ")
            if displayTitle!.count > 30 { displayTitle = String(displayTitle!.prefix(30)) }
        }

        let title: String
        if let displayTitle {
            title = "\(project) · \(displayTitle) · \(prefix)"
        } else {
            title = "\(project) · \(prefix)"
        }

        let osc = "\u{1B}]2;\(title)\u{07}"

        // Write to TTY device
        if let ttyPath, FileManager.default.isWritableFile(atPath: ttyPath) {
            try? osc.write(toFile: ttyPath, atomically: false, encoding: .utf8)
        }

        // Cache display title to tmpfile
        let cachePath = "/tmp/claude-island-osc2-title-\(prefix)"
        try? (displayTitle ?? "").write(toFile: cachePath, atomically: true, encoding: .utf8)
    }
}
