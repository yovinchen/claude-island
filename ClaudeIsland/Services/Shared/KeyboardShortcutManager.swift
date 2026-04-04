//
//  KeyboardShortcutManager.swift
//  ClaudeIsland
//
//  Global keyboard shortcut manager using Carbon HotKey API.
//  Default: ⌘⇧I to toggle the Notch open/closed.
//

import AppKit
import Carbon

extension Notification.Name {
    static let toggleNotch = Notification.Name("com.claudeisland.toggleNotch")
}

class KeyboardShortcutManager {
    static let shared = KeyboardShortcutManager()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    private init() {}

    /// Register the global hotkey
    func register() {
        guard AppSettings.globalShortcutEnabled else { return }
        guard hotKeyRef == nil else { return }

        // ⌘⇧I = Cmd + Shift + I
        let modifiers: UInt32 = UInt32(cmdKey | shiftKey)
        let keyCode: UInt32 = 34 // 'I' key

        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x434C4944) // "CLID"
        hotKeyID.id = 1

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        // Install event handler
        let handlerResult = InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyHandler,
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )

        guard handlerResult == noErr else {
            print("Failed to install hotkey handler: \(handlerResult)")
            return
        }

        // Register the hotkey
        let registerResult = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if registerResult != noErr {
            print("Failed to register hotkey: \(registerResult)")
        }
    }

    /// Unregister the global hotkey
    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }
    }

    /// Update registration based on current settings
    func updateRegistration() {
        unregister()
        if AppSettings.globalShortcutEnabled {
            register()
        }
    }
}

// MARK: - Carbon Event Handler (C function)

private func hotKeyHandler(
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    DispatchQueue.main.async {
        NotificationCenter.default.post(name: .toggleNotch, object: nil)
    }
    return noErr
}
