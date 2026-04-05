//
//  EventMapper.swift
//  ClaudeIslandBridge
//
//  Maps events from various AI tools into the unified ClaudeIsland protocol.
//  Supports: Claude, Codex, Gemini, Cursor, OpenCode, Copilot, Qoder, Droid, CodeBuddy, Trae.
//

import Foundation

enum EventMapper {

    /// Map raw hook input into the unified protocol format
    static func map(input: [String: Any], source: String, tty: String?, ppid: Int) -> [String: Any] {
        let eventName = extractEventName(from: input)
        let normalizedEvent = normalizeEventName(eventName)
        let sessionId = extractSessionId(from: input)
        let cwd = extractCwd(from: input)

        var payload: [String: Any] = [
            "session_id": sessionId,
            "source": source,
            "cwd": cwd,
            "event": normalizedEvent,
            "status": inferStatus(normalizedEvent),
            "approval_channel": "none",
            "_ppid": ppid
        ]

        if let tty = tty {
            payload["tty"] = tty
        }

        if let pid = input["pid"] ?? nested(input, "session", "pid") {
            payload["pid"] = pid
        } else {
            // Fallback: use bridge's parent PID (the CLI/IDE process that invoked us)
            // Ensures PID-based terminal focus works even when hook input lacks pid field
            payload["pid"] = getppid()
        }

        // Cursor-specific: infer tool name and input from event-specific fields
        if source == "cursor" {
            applyCursorFields(input: input, eventName: eventName, payload: &payload)
        }

        // Tool info (generic extraction, won't overwrite Cursor-set fields)
        if payload["tool"] == nil, let toolName = extractToolName(from: input) {
            payload["tool"] = toolName
        }

        if payload["tool_input"] == nil,
           let toolInput = input["tool_input"] ?? input["toolInput"] ?? nested(input, "tool", "input") {
            payload["tool_input"] = toolInput
        }

        if let toolUseId = firstString(
            input["tool_use_id"],
            input["toolUseId"],
            nested(input, "tool", "id")
        ) {
            payload["tool_use_id"] = toolUseId
        }

        // Permission requests need socket channel
        if normalizedEvent == "PermissionRequest" {
            payload["approval_channel"] = "socket"
            payload["status"] = "waiting_for_approval"
        }

        // Event-specific content fields (for UI display)
        // UserPromptSubmit → user's prompt text
        if let prompt = firstString(input["prompt"], input["text"]) {
            payload["prompt"] = prompt
        }

        // PostToolUseFailure → error message (Qoder-specific)
        if let error = firstString(input["error"], input["error_message"]) {
            payload["error"] = error
        }

        // PostToolUse → tool response (brief, for status display)
        if let toolResponse = input["tool_response"] as? String {
            payload["tool_response"] = String(toolResponse.prefix(500))
        }

        // Stop → last assistant message
        if let lastMsg = firstString(input["last_assistant_message"], input["lastAssistantMessage"]) {
            payload["last_assistant_message"] = String(lastMsg.prefix(500))
        }

        // Collect terminal environment variables for TTY/session correlation
        payload["_env"] = collectEnv()

        return payload
    }

    // MARK: - Event Name Extraction

    private static func extractEventName(from input: [String: Any]) -> String {
        return firstString(
            input["hook_event_name"],
            input["hookEventName"],
            input["event"],
            input["type"]
        ) ?? "unknown"
    }

    private static func extractSessionId(from input: [String: Any]) -> String {
        return firstString(
            input["session_id"],
            input["sessionId"],
            nested(input, "session", "id"),
            input["conversation_id"],   // Cursor: conversation_id as session grouping
            input["generation_id"],     // Cursor: generation_id as fallback
            input["id"]
        ) ?? "unknown"
    }

    private static func extractCwd(from input: [String: Any]) -> String {
        // Try standard fields first
        if let cwd = firstString(
            input["cwd"],
            nested(input, "session", "cwd"),
            input["workingDirectory"],
            input["workspace"]
        ) {
            return cwd
        }
        // Cursor: workspace_roots array
        if let roots = input["workspace_roots"] as? [String], let first = roots.first {
            return first
        }
        return ""
    }

    private static func extractToolName(from input: [String: Any]) -> String? {
        if let name = input["tool_name"] as? String { return name }
        if let name = input["toolName"] as? String { return name }
        if let tool = input["tool"] as? [String: Any], let name = tool["name"] as? String { return name }
        if let name = input["tool"] as? String { return name }
        return nil
    }

    // MARK: - Event Name Normalization

    static func normalizeEventName(_ raw: String) -> String {
        let key = raw
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .lowercased()

        let aliases: [String: String] = [
            // Standard Claude Code events
            "sessionstart": "SessionStart",
            "sessionend": "SessionEnd",
            "userpromptsubmitted": "UserPromptSubmit",
            "userpromptsubmit": "UserPromptSubmit",
            "pretooluse": "PreToolUse",
            "posttooluse": "PostToolUse",
            "permissionrequest": "PermissionRequest",
            "agentstop": "Stop",
            "stop": "Stop",
            "subagentstop": "SubagentStop",
            "notification": "Notification",
            "precompact": "PreCompact",
            "posttoolusefailure": "PostToolUseFailure",
            "erroroccurred": "Notification",
            // Cursor-specific events
            "beforesubmitprompt": "UserPromptSubmit",
            "beforeshellexecution": "PermissionRequest",
            "beforemcpexecution": "PermissionRequest",
            "beforereadfile": "PreToolUse",
            "afterfileedit": "PostToolUse",
        ]

        return aliases[key] ?? raw
    }

    // MARK: - Status Inference

    static func inferStatus(_ event: String) -> String {
        switch event {
        case "PreToolUse":
            return "running_tool"
        case "PostToolUse", "PostToolUseFailure", "UserPromptSubmit":
            return "processing"
        case "PermissionRequest":
            return "waiting_for_approval"
        case "SessionStart", "Stop", "SubagentStop":
            return "waiting_for_input"
        case "SessionEnd":
            return "ended"
        case "PreCompact":
            return "compacting"
        default:
            return "unknown"
        }
    }

    // MARK: - Cursor-Specific Field Extraction

    /// Extract tool name, tool_input, and other fields from Cursor's event-specific stdin format.
    /// Cursor events use different field names than Claude Code:
    /// - beforeShellExecution: {command, cwd}
    /// - beforeMCPExecution: {server, tool_name, tool_input}
    /// - beforeReadFile: {content, file_path}
    /// - afterFileEdit: {file_path, edits}
    /// - beforeSubmitPrompt: {conversation_id, generation_id, prompt, attachments, workspace_roots}
    /// - stop: {status}
    private static func applyCursorFields(input: [String: Any], eventName: String, payload: inout [String: Any]) {
        let key = eventName.lowercased()

        switch key {
        case "beforeshellexecution":
            payload["tool"] = "Bash"
            if let command = input["command"] as? String {
                payload["tool_input"] = ["command": command]
            }
            // Generate a stable tool_use_id for permission correlation
            payload["tool_use_id"] = "cursor-shell-\(UUID().uuidString.prefix(8))"

        case "beforemcpexecution":
            if let toolName = input["tool_name"] as? String {
                // Prefix with MCP server name if available
                if let server = input["server"] as? String {
                    payload["tool"] = "mcp__\(server)__\(toolName)"
                } else {
                    payload["tool"] = toolName
                }
            }
            if let toolInput = input["tool_input"] {
                payload["tool_input"] = toolInput
            }
            payload["tool_use_id"] = "cursor-mcp-\(UUID().uuidString.prefix(8))"

        case "beforereadfile":
            payload["tool"] = "Read"
            if let filePath = input["file_path"] as? String {
                payload["tool_input"] = ["file_path": filePath]
            }

        case "afterfileedit":
            payload["tool"] = "Edit"
            if let filePath = input["file_path"] as? String {
                payload["tool_input"] = ["file_path": filePath]
            }

        case "beforesubmitprompt":
            if let prompt = input["prompt"] as? String {
                payload["prompt"] = prompt
            }
            // Use conversation_id as session_id for better session grouping
            if let convId = input["conversation_id"] as? String {
                payload["session_id"] = convId
            }

        case "stop":
            if let status = input["status"] as? String {
                payload["last_assistant_message"] = "Cursor agent \(status)"
            }

        default:
            break
        }

        // Extract workspace_roots for cwd if cwd is empty
        if (payload["cwd"] as? String)?.isEmpty == true,
           let roots = input["workspace_roots"] as? [String], let first = roots.first {
            payload["cwd"] = first
        }
    }

    // MARK: - Helpers

    private static func firstString(_ values: Any?...) -> String? {
        for value in values {
            if let str = value as? String, !str.isEmpty {
                return str
            }
        }
        return nil
    }

    private static func nested(_ dict: [String: Any], _ keys: String...) -> Any? {
        var current: Any = dict
        for key in keys {
            guard let d = current as? [String: Any] else { return nil }
            guard let next = d[key] else { return nil }
            current = next
        }
        return current
    }

    // MARK: - Environment Collection

    private static let envKeys = [
        "TERM_PROGRAM", "ITERM_SESSION_ID", "TERM_SESSION_ID",
        "TMUX", "TMUX_PANE", "KITTY_WINDOW_ID", "__CFBundleIdentifier",
        "CONDUCTOR_WORKSPACE_NAME", "CONDUCTOR_PORT", "CURSOR_TRACE_ID",
        "CMUX_WORKSPACE_ID", "CMUX_SURFACE_ID", "CMUX_SOCKET_PATH",
    ]

    private static func collectEnv() -> [String: String] {
        var env: [String: String] = [:]
        let processEnv = ProcessInfo.processInfo.environment
        for key in envKeys {
            if let value = processEnv[key] {
                env[key] = value
            }
        }
        return env
    }
}
