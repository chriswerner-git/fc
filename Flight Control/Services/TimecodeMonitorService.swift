//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                    │
//  │  Flight Control                                             │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: TimecodeMonitorService.swift
//  Purpose: Maintains lightweight runtime status for configured timecode sources.
//           This pass supports simulated-source timecode and Audio LTC input
//           level/status reporting. Actual SMPTE LTC decoding is still a
//           future decoder layer.
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

            let runState: TimecodeRunState = {
                if signalPresent { return .stale }
                if captureRunning { return .lost }
                return .lost
            }()

            let message: String = {
                if signalPresent {
                    return "Audio signal is present. LTC decoding is not active yet."
                }
                if let levelState, captureIsFresh {
                    return levelState.message
                }
                return "Audio LTC input is selected. Waiting for audio capture/level updates."
            }()

            return TimecodeRuntimeState(
                sourceID: source.id,
                sourceName: source.displayName,
                timecodeText: "--:--:--:--",
                frameRate: nil,
                runState: runState,
                lastFrameDate: nil,
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
