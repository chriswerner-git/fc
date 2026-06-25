//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                    │
//  │  Flight Control                                             │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: TimecodeModels.swift
//  Purpose: Defines Flight Control timecode source configuration and runtime
//           status models used by Project Preferences, dashboard display, and
//           future alert/rule evaluation.
//
//  Created by Chris Werner / Lunar Telephone Company.
//  © 2026 Lunar Telephone Company. All rights reserved.
//
//  This source file is part of Flight Control, a macOS utility developed
//  by Lunar Telephone Company for persistent project-location device
//  inventory, network health monitoring, dashboard visibility, and future
//  Deep Space Network reporting.
//

import Foundation

enum TimecodeSourceType: String, Codable, CaseIterable, Identifiable {
    case simulated
    case audioLTC
    case midiTimecode
    case networkTimecode

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .simulated: return "Simulated"
        case .audioLTC: return "Audio LTC"
        case .midiTimecode: return "MIDI Timecode (future)"
        case .networkTimecode: return "Network Timecode (future)"
        }
    }

    var isImplemented: Bool {
        switch self {
        case .simulated, .audioLTC:
            // Audio LTC can be configured now, but live decoding is still a later phase.
            return true
        case .midiTimecode, .networkTimecode:
            return false
        }
    }
}

enum TimecodeAudioChannel: String, Codable, CaseIterable, Identifiable {
    case left
    case right
    case channel1
    case channel2

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .left: return "Left"
        case .right: return "Right"
        case .channel1: return "Channel 1"
        case .channel2: return "Channel 2"
        }
    }
}

enum TimecodePolarityMode: String, Codable, CaseIterable, Identifiable {
    case automatic
    case normal
    case inverted

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .automatic: return "Auto"
        case .normal: return "Normal"
        case .inverted: return "Inverted"
        }
    }
}

enum TimecodeFrameRate: String, Codable, CaseIterable, Identifiable {
    case fps23976
    case fps24
    case fps25
    case fps2997NonDrop
    case fps2997Drop
    case fps30

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fps23976: return "23.976"
        case .fps24: return "24"
        case .fps25: return "25"
        case .fps2997NonDrop: return "29.97ndf"
        case .fps2997Drop: return "29.97df"
        case .fps30: return "30"
        }
    }

    var framesPerSecond: Int {
        switch self {
        case .fps23976, .fps24: return 24
        case .fps25: return 25
        case .fps2997NonDrop, .fps2997Drop, .fps30: return 30
        }
    }

    var isDropFrame: Bool { self == .fps2997Drop }

    var separator: String { isDropFrame ? ";" : ":" }
}

enum TimecodeFrameRateDetectionMode: String, Codable, CaseIterable, Identifiable {
    case automatic

    var id: String { rawValue }
    var displayName: String { "Auto Detect" }
}

enum TimecodeRunState: String, Codable, CaseIterable, Identifiable {
    case running
    case stale
    case lost
    case notConfigured
    case unavailable

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .running: return "Running"
        case .stale: return "Stale"
        case .lost: return "Lost"
        case .notConfigured: return "Not Configured"
        case .unavailable: return "Unavailable"
        }
    }
}

struct TimecodeSourceConfiguration: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String = "Timecode Source"
    var enabled: Bool = true
    var type: TimecodeSourceType = .audioLTC

    // Human-readable input name for display and backward compatibility.
    // For Audio LTC sources, inputSourceID should be used when available.
    var inputSourceName: String = ""

    // Stable macOS audio device identifier for future Audio LTC capture.
    // This first implementation discovers and stores the selected input device,
    // but does not open/capture/decode audio yet.
    var inputSourceID: String = ""

    var audioChannel: TimecodeAudioChannel = .left
    var frameRateDetectionMode: TimecodeFrameRateDetectionMode = .automatic
    var polarityMode: TimecodePolarityMode = .automatic
    var staleTimeoutSeconds: TimeInterval = 0.75
    var lostTimeoutSeconds: TimeInterval = 2.0
    var notes: String = ""

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Timecode Source" : trimmed
    }

    init() {}

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case enabled
        case type
        case inputSourceName
        case inputSourceID
        case audioChannel
        case frameRateDetectionMode
        case polarityMode
        case staleTimeoutSeconds
        case lostTimeoutSeconds
        case notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Timecode Source"
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        type = try container.decodeIfPresent(TimecodeSourceType.self, forKey: .type) ?? .audioLTC
        inputSourceName = try container.decodeIfPresent(String.self, forKey: .inputSourceName) ?? ""
        inputSourceID = try container.decodeIfPresent(String.self, forKey: .inputSourceID) ?? ""
        audioChannel = try container.decodeIfPresent(TimecodeAudioChannel.self, forKey: .audioChannel) ?? .left
        frameRateDetectionMode = try container.decodeIfPresent(TimecodeFrameRateDetectionMode.self, forKey: .frameRateDetectionMode) ?? .automatic
        polarityMode = try container.decodeIfPresent(TimecodePolarityMode.self, forKey: .polarityMode) ?? .automatic
        staleTimeoutSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .staleTimeoutSeconds) ?? 0.75
        lostTimeoutSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .lostTimeoutSeconds) ?? 2.0
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        clampValues()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(type, forKey: .type)
        try container.encode(inputSourceName, forKey: .inputSourceName)
        try container.encode(inputSourceID, forKey: .inputSourceID)
        try container.encode(audioChannel, forKey: .audioChannel)
        try container.encode(frameRateDetectionMode, forKey: .frameRateDetectionMode)
        try container.encode(polarityMode, forKey: .polarityMode)
        try container.encode(staleTimeoutSeconds, forKey: .staleTimeoutSeconds)
        try container.encode(lostTimeoutSeconds, forKey: .lostTimeoutSeconds)
        try container.encode(notes, forKey: .notes)
    }

    mutating func clampValues() {
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { name = "Timecode Source" }
        inputSourceName = inputSourceName.trimmingCharacters(in: .whitespacesAndNewlines)
        inputSourceID = inputSourceID.trimmingCharacters(in: .whitespacesAndNewlines)
        notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        staleTimeoutSeconds = min(max(staleTimeoutSeconds, 0.10), 30.0)
        lostTimeoutSeconds = min(max(lostTimeoutSeconds, staleTimeoutSeconds), 120.0)
    }
}

struct TimecodeRuntimeState: Codable, Hashable {
    var sourceID: UUID?
    var sourceName: String
    var timecodeText: String
    var frameRate: TimecodeFrameRate?
    var runState: TimecodeRunState
    var lastFrameDate: Date?
    var audioLevelDescription: String
    var audioLevelDecibels: Double? = nil
    var audioSignalPresent: Bool = false
    var message: String

    static let notConfigured = TimecodeRuntimeState(
        sourceID: nil,
        sourceName: "No Source",
        timecodeText: "--:--:--:--",
        frameRate: nil,
        runState: .notConfigured,
        lastFrameDate: nil,
        audioLevelDescription: "No input",
        audioLevelDecibels: nil,
        audioSignalPresent: false,
        message: "No timecode source selected."
    )
}
