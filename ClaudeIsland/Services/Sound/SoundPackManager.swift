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

    /// Cached NSSound instances, invalidated on device change
    private var soundCache: [String: NSSound] = [:]

    private init() {
        SoundOutputDeviceObserver.shared.onDeviceChanged = { [weak self] in
            self?.invalidateCache()
        }
        SoundOutputDeviceObserver.shared.startObserving()
    }

    /// Invalidate cached sound instances (called on audio device change)
    private func invalidateCache() {
        for (_, sound) in soundCache {
            sound.stop()
        }
        soundCache.removeAll()
    }

    /// Get or create a cached NSSound
    private func sound(named name: String) -> NSSound? {
        if let cached = soundCache[name] {
            return cached
        }
        if let sound = NSSound(named: name) {
            soundCache[name] = sound
            return sound
        }
        return nil
    }

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
        sound(named: name)?.play()
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
        sound(named: name)?.play()
    }
}
