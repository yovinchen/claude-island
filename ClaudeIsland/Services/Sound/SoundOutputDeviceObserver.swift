//
//  SoundOutputDeviceObserver.swift
//  ClaudeIsland
//
//  Monitors the default audio output device for changes using CoreAudio.
//  When the user switches audio devices (e.g., from speakers to headphones),
//  notifies SoundPackManager to refresh NSSound instances so sounds play
//  on the correct device.
//

import AudioToolbox
import Foundation
import os.log

class SoundOutputDeviceObserver {
    static let shared = SoundOutputDeviceObserver()

    private let logger = Logger(subsystem: "com.claudeisland", category: "AudioDevice")
    private var isObserving = false
    var onDeviceChanged: (() -> Void)?

    private init() {}

    func startObserving() {
        guard !isObserving else { return }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectAddPropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            audioDeviceChangeListener,
            Unmanaged.passUnretained(self).toOpaque()
        )

        if status == noErr {
            isObserving = true
            logger.info("Audio output device observer started")
        } else {
            logger.warning("Failed to add audio device listener: \(status)")
        }
    }

    func stopObserving() {
        guard isObserving else { return }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectRemovePropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            audioDeviceChangeListener,
            Unmanaged.passUnretained(self).toOpaque()
        )

        isObserving = false
        logger.info("Audio output device observer stopped")
    }

    deinit {
        stopObserving()
    }
}

private func audioDeviceChangeListener(
    _ objectID: AudioObjectID,
    _ numberAddresses: UInt32,
    _ addresses: UnsafePointer<AudioObjectPropertyAddress>,
    _ clientData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let clientData = clientData else { return noErr }
    let observer = Unmanaged<SoundOutputDeviceObserver>.fromOpaque(clientData).takeUnretainedValue()

    DispatchQueue.main.async {
        observer.onDeviceChanged?()
        Task {
            await DiagnosticLogger.shared.log("Audio output device changed", category: .sound)
        }
    }

    return noErr
}
