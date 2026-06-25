//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                    │
//  │  Flight Control                                             │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: TimecodeMonitorService.swift
//  Purpose: Maintains lightweight runtime status for configured timecode sources.
//           This pass supports simulated-source timecode and Audio LTC runtime
//           status, including decoded SMPTE LTC frames when the audio decoder
//           establishes sync.
//
//  Created by Chris Werner / Lunar Telephone Company.
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import Foundation

@MainActor
final class TimecodeMonitorService: NSObject {
    var onStateUpdate: (([UUID: TimecodeRuntimeState]) -> Void)?

    private var timer: Timer?
    private var sources: [TimecodeSourceConfiguration] = []
    private var audioLevelStates: [UUID: TimecodeAudioLevelState] = [:]

    func configure(sources: [TimecodeSourceConfiguration]) {
        self.sources = sources
        publishCurrentStates()
        if sources.contains(where: { $0.enabled }) {
            start()
        } else {
            stop()
        }
    }

    func updateAudioLevelState(_ state: TimecodeAudioLevelState) {
        audioLevelStates[state.sourceID] = state
        publishCurrentStates()
    }

    func clearAudioLevelStates() {
        audioLevelStates.removeAll()
        publishCurrentStates()
    }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(
            timeInterval: 0.25,
            target: self,
            selector: #selector(handleTimer),
            userInfo: nil,
            repeats: true
        )
        timer?.tolerance = 0.05
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        publishCurrentStates()
    }

    @objc private func handleTimer(_ timer: Timer) {
        publishCurrentStates()
    }

    private func publishCurrentStates() {
        var states: [UUID: TimecodeRuntimeState] = [:]
        for source in sources {
            states[source.id] = state(for: source, at: Date())
        }
        onStateUpdate?(states)
    }

    private func state(for source: TimecodeSourceConfiguration, at date: Date) -> TimecodeRuntimeState {
        guard source.enabled else {
            return TimecodeRuntimeState(
                sourceID: source.id,
                sourceName: source.displayName,
                timecodeText: "--:--:--:--",
                frameRate: nil,
                runState: .unavailable,
                lastFrameDate: nil,
                audioLevelDescription: "Disabled",
                audioLevelDecibels: nil,
                audioSignalPresent: false,
                message: "Source is disabled."
            )
        }

        switch source.type {
        case .simulated:
            let frameRate = TimecodeFrameRate.fps2997Drop
            return TimecodeRuntimeState(
                sourceID: source.id,
                sourceName: source.displayName,
                timecodeText: Self.simulatedTimecodeText(at: date, frameRate: frameRate),
                frameRate: frameRate,
                runState: .running,
                lastFrameDate: date,
                audioLevelDescription: "Simulated",
                audioLevelDecibels: nil,
                audioSignalPresent: true,
                message: "Simulated timecode source is running."
            )

        case .audioLTC:
            guard source.inputSourceID.isEmpty == false else {
                return TimecodeRuntimeState(
                    sourceID: source.id,
                    sourceName: source.displayName,
                    timecodeText: "--:--:--:--",
                    frameRate: nil,
                    runState: .lost,
                    lastFrameDate: nil,
                    audioLevelDescription: "No input selected",
                    audioLevelDecibels: nil,
                    audioSignalPresent: false,
                    message: "Audio LTC input device has not been selected."
                )
            }

            let levelState = audioLevelStates[source.id]
            let levelAge = levelState.map { date.timeIntervalSince($0.updatedAt) } ?? .infinity
            let captureIsFresh = levelAge <= max(1.5, source.staleTimeoutSeconds * 2.0)
            let signalPresent = (levelState?.signalPresent == true) && captureIsFresh
            let captureRunning = (levelState?.isCaptureRunning == true) && captureIsFresh

            let decodedAge = levelState?.decodedAt.map { date.timeIntervalSince($0) } ?? .infinity

            // The first native decoder may not deliver every LTC frame yet,
            // especially with virtual/multichannel input devices. For a monitoring
            // dashboard, a recently decoded frame plus continuing audio signal is
            // enough to keep the displayed clock running for a short smoothing
            // window. This prevents rapid green/orange flicker while still allowing
            // stale/lost alerts to fire when valid LTC disappears.
            let smoothingWindow = min(
                source.lostTimeoutSeconds,
                max(1.75, source.staleTimeoutSeconds * 3.0)
            )
            let decodedIsAvailable = levelState?.decodedTimecodeText != nil
            let lostHoldDuration: TimeInterval = 120.0
            let decodedIsRunning = decodedIsAvailable && decodedAge <= smoothingWindow && signalPresent
            let decodedIsStale = decodedIsAvailable && decodedAge > smoothingWindow && decodedAge <= source.lostTimeoutSeconds
            let decodedIsHeldAfterLoss = decodedIsAvailable && decodedAge > source.lostTimeoutSeconds && decodedAge <= (source.lostTimeoutSeconds + lostHoldDuration)
            let decodedIsLost = decodedAge > source.lostTimeoutSeconds

            let runState: TimecodeRunState = {
                if decodedIsRunning { return .running }
                if decodedIsStale { return .stale }
                if signalPresent { return .stale }
                if captureRunning { return .lost }
                return .lost
            }()

            let displayedText: String = {
                guard let decodedText = levelState?.decodedTimecodeText else {
                    return "--:--:--:--"
                }

                // When LTC is lost, keep the last decoded value visible for two
                // minutes. The run state remains .lost, so the dashboard renders
                // this held value in the critical/red state rather than advancing
                // or hiding it immediately.
                if decodedIsHeldAfterLoss || decodedIsLost == false {
                    guard decodedIsRunning,
                          let decodedAt = levelState?.decodedAt,
                          let frameRate = levelState?.decodedFrameRate else {
                        return decodedText
                    }
                    return Self.advancedTimecodeText(
                        from: decodedText,
                        frameRate: frameRate,
                        elapsed: max(0.0, date.timeIntervalSince(decodedAt))
                    ) ?? decodedText
                }

                return "--:--:--:--"
            }()

            let message: String = {
                if decodedIsRunning {
                    if decodedAge > max(0.30, source.staleTimeoutSeconds) {
                        return "LTC decoded. Display is smoothing between decoded frames."
                    }
                    return levelState?.decoderMessage ?? "LTC decoded."
                }
                if decodedIsStale {
                    return "LTC signal is stale. Last decoded frame is being held briefly."
                }
                if decodedIsHeldAfterLoss {
                    return "LTC signal is lost. Holding the last decoded value for two minutes."
                }
                if signalPresent {
                    return levelState?.decoderMessage ?? "Audio signal is present. Waiting for LTC sync."
                }
                if let levelState, captureIsFresh {
                    return levelState.message
                }
                return "Audio LTC input is selected. Waiting for audio capture/level updates."
            }()

            return TimecodeRuntimeState(
                sourceID: source.id,
                sourceName: source.displayName,
                timecodeText: displayedText,
                frameRate: levelState?.decodedFrameRate,
                runState: runState,
                lastFrameDate: levelState?.decodedAt,
                audioLevelDescription: levelState?.levelDescription ?? source.inputSourceName,
                audioLevelDecibels: levelState?.decibels,
                audioSignalPresent: signalPresent,
                message: message
            )

        case .midiTimecode, .networkTimecode:
            return TimecodeRuntimeState(
                sourceID: source.id,
                sourceName: source.displayName,
                timecodeText: "--:--:--:--",
                frameRate: nil,
                runState: .unavailable,
                lastFrameDate: nil,
                audioLevelDescription: "Future",
                audioLevelDecibels: nil,
                audioSignalPresent: false,
                message: "This timecode source type is not implemented yet."
            )
        }
    }


    private static func advancedTimecodeText(from text: String, frameRate: TimecodeFrameRate, elapsed: TimeInterval) -> String? {
        let separator = frameRate.separator
        let normalized = text.replacingOccurrences(of: ";", with: ":")
        let parts = normalized.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 4 else { return nil }

        let framesPerSecond = max(1, frameRate.framesPerSecond)
        var totalFrames = (((parts[0] * 60 + parts[1]) * 60 + parts[2]) * framesPerSecond) + parts[3]
        totalFrames += max(0, Int((elapsed * Double(framesPerSecond)).rounded(.down)))

        let framesPerDay = 24 * 60 * 60 * framesPerSecond
        totalFrames = ((totalFrames % framesPerDay) + framesPerDay) % framesPerDay

        let hours = totalFrames / (60 * 60 * framesPerSecond)
        totalFrames %= 60 * 60 * framesPerSecond
        let minutes = totalFrames / (60 * framesPerSecond)
        totalFrames %= 60 * framesPerSecond
        let seconds = totalFrames / framesPerSecond
        let frames = totalFrames % framesPerSecond

        return String(format: "%02d%@%02d%@%02d%@%02d", hours, separator, minutes, separator, seconds, separator, frames)
    }

    private static func simulatedTimecodeText(at date: Date, frameRate: TimecodeFrameRate) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let second = components.second ?? 0
        let nanosecond = components.nanosecond ?? 0
        let frame = min(frameRate.framesPerSecond - 1, Int((Double(nanosecond) / 1_000_000_000.0) * Double(frameRate.framesPerSecond)))
        let separator = frameRate.separator
        return String(format: "%02d%@%02d%@%02d%@%02d", hour, separator, minute, separator, second, separator, frame)
    }
}
