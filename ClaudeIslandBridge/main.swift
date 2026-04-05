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
//    claude-island-bridge --source codex_notify '{...}'  # Codex notify
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

/// Parse the first non-option positional argument.
/// Codex `notify = [...]` passes the JSON payload as an argv item rather than stdin.
func parsePayloadArgument() -> String? {
    let args = CommandLine.arguments
    var index = 1

    while index < args.count {
        switch args[index] {
        case "--source", "--event":
            index += 2
        default:
            if args[index].hasPrefix("--") {
                index += 1
            } else {
                return args[index]
            }
        }
    }

    return nil
}

func readInputData(preferArgument: Bool) -> Data? {
    if preferArgument, let payload = parsePayloadArgument() {
        return payload.data(using: .utf8)
    }

    let stdinData = FileHandle.standardInput.availableData
    if !stdinData.isEmpty {
        return stdinData
    }

    guard !preferArgument, let payload = parsePayloadArgument() else {
        return nil
    }

    return payload.data(using: .utf8)
}

func forwardCodexNotifyChain(rawPayload: String) {
    let chainURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".codex/claude-island/notify-chain.json")

    guard let data = try? Data(contentsOf: chainURL),
          let command = try? JSONSerialization.jsonObject(with: data) as? [String],
          let executable = command.first,
          !executable.isEmpty else {
        return
    }

    let expandedExecutable = NSString(string: executable).expandingTildeInPath
    let extraArguments = Array(command.dropFirst()) + [rawPayload]
    let process = Process()
    process.standardInput = nil
    process.standardOutput = FileHandle(forWritingAtPath: "/dev/null")
    process.standardError = FileHandle(forWritingAtPath: "/dev/null")

    if expandedExecutable.contains("/") {
        process.executableURL = URL(fileURLWithPath: expandedExecutable)
        process.arguments = extraArguments
    } else {
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [expandedExecutable] + extraArguments
    }

    try? process.run()
}

// MARK: - Main

let source = parseSource()
let eventOverride = parseEvent()
let ttyPath = TTYDetector.detectTTY()
let ppid = ProcessInfo.processInfo.processIdentifier

guard let inputData = readInputData(preferArgument: source == "codex_notify"),
      !inputData.isEmpty else {
    exit(0)
}

let rawPayload = String(data: inputData, encoding: .utf8)

if source == "codex_notify", let rawPayload, !rawPayload.isEmpty {
    forwardCodexNotifyChain(rawPayload: rawPayload)
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
    let sourceName = payload["source"] as? String ?? source
    exit(PermissionHandler.handle(client: client, data: payloadData, source: sourceName))
} else if PermissionHandler.isImplicitPermissionRequest(payload: payload) {
    // Qoder/CodeBuddy: PreToolUse on dangerous tools acts as implicit permission request
    exit(PermissionHandler.handleImplicit(client: client, payload: payload))
} else {
    client.send(data: payloadData)
}

exit(0)
