//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                    │
//  │  Flight Control                                             │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: TimecodeMonitorService.swift
//  Purpose: Maintains lightweight runtime status for configured timecode sources.
//           This first pass provides simulated-source evaluation and safe
//           placeholders for future audio LTC decoding from Dante Virtual
//           Soundcard or other macOS audio inputs.
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
    func configure(sources: [TimecodeSourceConfiguration]) {
        self.sources = sources
        publishCurrentStates()
        if sources.contains(where: { $0.enabled }) {
            start()
        } else {
            stop()
        }
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
                message: "Simulated timecode source is running."
            )
        case .audioLTC:
            return TimecodeRuntimeState(
                sourceID: source.id,
                sourceName: source.displayName,
                timecodeText: "--:--:--:--",
                frameRate: nil,
                runState: .lost,
                lastFrameDate: nil,
                audioLevelDescription: source.inputSourceName.isEmpty ? "No input selected" : source.inputSourceName,
                message: source.inputSourceID.isEmpty ? "Audio LTC input device has not been selected." : "Audio LTC input is selected. Capture and decoding are planned for the next phase."
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
