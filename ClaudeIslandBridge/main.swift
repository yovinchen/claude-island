//
//  main.swift
//  ClaudeIslandBridge
//
//  Native Swift CLI that replaces the Python hook script.
//  Reads hook event JSON from stdin and forwards it to the app via Unix socket.
//
//  Usage:
//    claude-island-bridge --source claude   # Claude Code hook
//    claude-island-bridge --source codex    # Codex CLI hook
//    claude-island-bridge --source gemini   # Gemini CLI hook
//    claude-island-bridge --source cursor --event beforeShellExecution  # Cursor hook
//    claude-island-bridge --source copilot  # Copilot hook
//

import Foundation

// MARK: - Argument Parsing

func parseSource() -> String {
    let args = CommandLine.arguments
    for i in 0..<args.count {
        if args[i] == "--source", i + 1 < args.count {
            return args[i + 1]
        }
    }
    return "claude"
}

/// Parse --event argument (used by Cursor hooks which don't include event name in stdin)
func parseEvent() -> String? {
    let args = CommandLine.arguments
    for i in 0..<args.count {
        if args[i] == "--event", i + 1 < args.count {
            return args[i + 1]
        }
    }
    return nil
}

// MARK: - Main

let source = parseSource()
let eventOverride = parseEvent()
let ttyPath = TTYDetector.detectTTY()
let ppid = ProcessInfo.processInfo.processIdentifier

// Read stdin
guard let inputData = try? FileHandle.standardInput.availableData,
      !inputData.isEmpty else {
    exit(0)
}

guard var inputJSON = try? JSONSerialization.jsonObject(with: inputData) as? [String: Any] else {
    exit(0)
}

// Inject event name from --event arg (used by Cursor hooks which don't include event name in stdin)
if let eventOverride = eventOverride, inputJSON["hook_event_name"] == nil && inputJSON["event"] == nil {
    inputJSON["hook_event_name"] = eventOverride
}

// Map the event to unified protocol
let payload = EventMapper.map(input: inputJSON, source: source, tty: ttyPath, ppid: Int(ppid))

// Serialize payload
guard let payloadData = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
    exit(0)
}

// Update terminal title for supported terminals (Ghostty)
let eventName = payload["event"] as? String ?? ""
if eventName == "SessionStart" || eventName == "UserPromptSubmit" {
    let sessionId = payload["session_id"] as? String ?? "unknown"
    let cwd = payload["cwd"] as? String
    let userText = eventName == "UserPromptSubmit"
        ? (inputJSON["prompt"] as? String ?? inputJSON["text"] as? String)
        : nil
    TerminalTitleManager.setTitle(
        sessionId: sessionId,
        cwd: cwd,
        userText: userText,
        ttyPath: ttyPath
    )
}

// Send to socket and optionally wait for response
let socketPath = ProcessInfo.processInfo.environment["CLAUDE_ISLAND_SOCKET_PATH"]
    ?? "/tmp/claude-island.sock"

let client = SocketClient(path: socketPath)

if PermissionHandler.isPermissionRequest(payload: payload) {
    PermissionHandler.handle(client: client, data: payloadData)
} else {
    client.send(data: payloadData)
}

exit(0)
