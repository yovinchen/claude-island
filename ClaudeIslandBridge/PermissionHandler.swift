//
//  PermissionHandler.swift
//  ClaudeIslandBridge
//
//  Handles permission request events that require a synchronous response.
//

import Foundation

enum PermissionHandler {
    static func isPermissionRequest(payload: [String: Any]) -> Bool {
        let event = payload["event"] as? String ?? ""
        let status = payload["status"] as? String ?? ""
        return event == "PermissionRequest" && status == "waiting_for_approval"
    }

    /// Check if a PreToolUse event should be treated as an implicit permission request.
    /// Qoder and CodeBuddy don't have a dedicated PermissionRequest event;
    /// permissions are handled via PreToolUse hook's stdout `permissionDecision` field.
    static func isImplicitPermissionRequest(payload: [String: Any]) -> Bool {
        let event = payload["event"] as? String ?? ""
        let source = payload["source"] as? String ?? ""

        guard event == "PreToolUse" else { return false }
        guard source == "qoder" || source == "codebuddy" || source == "codex" else { return false }

        let tool = payload["tool"] as? String ?? ""
        let dangerousTools: Set<String> = [
            "Bash", "Write", "Edit",
            "run_in_terminal", "create_file", "search_replace",
            "execute_command", "write_to_file"
        ]
        return dangerousTools.contains(tool)
    }

    static func handle(client: SocketClient, data: Data) {
        if let responseData = client.sendAndReceive(data: data, timeout: 86400) {
            FileHandle.standardOutput.write(responseData)
        }
    }

    /// Handle implicit permission requests (Qoder/CodeBuddy PreToolUse on dangerous tools).
    /// Mutates the payload to set approval_channel and status before sending.
    static func handleImplicit(client: SocketClient, payload: [String: Any]) {
        var mutablePayload = payload
        mutablePayload["approval_channel"] = "socket"
        mutablePayload["status"] = "waiting_for_approval"

        // Generate a tool_use_id if missing
        if mutablePayload["tool_use_id"] == nil {
            let source = payload["source"] as? String ?? "unknown"
            mutablePayload["tool_use_id"] = "\(source)-pretool-\(UUID().uuidString.prefix(8))"
        }

        guard let data = try? JSONSerialization.data(withJSONObject: mutablePayload, options: []) else {
            return
        }

        if let responseData = client.sendAndReceive(data: data, timeout: 120) {
            FileHandle.standardOutput.write(responseData)
        }
    }
}
