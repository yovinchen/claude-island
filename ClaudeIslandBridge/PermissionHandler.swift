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

    static func handle(client: SocketClient, data: Data) {
        if let responseData = client.sendAndReceive(data: data, timeout: 86400) {
            FileHandle.standardOutput.write(responseData)
        }
    }
}
