//
//  SoundPackManager.swift
//  ClaudeIsland
//
//  Manages sound theme packs for different notification events.
//  Each pack defines sounds for: task complete, approval request, and error.
//

import AppKit
import Foundation

/// Sound event types
enum SoundEvent {
    case taskComplete
    case approvalRequest
    case error
}

class SoundPackManager {
    static let shared = SoundPackManager()

    private init() {}

    /// Play the sound for a given event using the current theme pack
    func play(_ event: SoundEvent) {
        let pack = AppSettings.soundThemePack

        let soundName: String?
        switch event {
        case .taskComplete:
            soundName = pack.taskCompleteSound
        case .approvalRequest:
            soundName = pack.approvalRequestSound
        case .error:
            soundName = pack.errorSound
        }

        guard let name = soundName else { return }
        NSSound(named: name)?.play()
    }

    /// Preview a sound from a specific pack
    func preview(_ event: SoundEvent, pack: SoundThemePack) {
        let soundName: String?
        switch event {
        case .taskComplete:
            soundName = pack.taskCompleteSound
        case .approvalRequest:
            soundName = pack.approvalRequestSound
        case .error:
            soundName = pack.errorSound
        }

        guard let name = soundName else { return }
        NSSound(named: name)?.play()
    }
}
