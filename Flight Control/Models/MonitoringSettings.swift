//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                    │
//  │  Flight Control                                             │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: MonitoringSettings.swift
//  Purpose: User-editable monitoring preferences and future integration placeholders.
//
//  Created by Chris Werner / Lunar Telephone Company.
//  © 2026 Lunar Telephone Company. All rights reserved.
//
//  This source file is part of Flight Control, a macOS utility developed
//  by Lunar Telephone Company for persistent project-location device
//  inventory, network health monitoring, dashboard visibility, and future
//  Deep Space Network reporting.
//
//  This software is provided for internal operational use and project support.
//  No portion of this file may be copied, distributed, disclosed, modified,
//  or reused outside authorized Lunar Telephone Company work without prior
//  written permission.
//


import Foundation

enum InterfaceMonitoringMode: String, Codable, CaseIterable, Identifiable {
    case anyActive
    case selectedInterface

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .anyActive: return "Any Active Interface"
        case .selectedInterface: return "Selected Interface"
        }
    }
}


struct CheckIntervalOption: Identifiable, Hashable {
    var seconds: TimeInterval
    var id: TimeInterval { seconds }

    var displayName: String {
        switch seconds {
        case 10: return "10s"
        case 30: return "30s"
        case 60: return "1m"
        case 120: return "2m"
        case 300: return "5m"
        case 600: return "10m"
        case 900: return "15m"
        case 1800: return "30m"
        case 3600: return "60m"
        default:
            if seconds < 60 { return "\(Int(seconds))s" }
            return "\(Int(seconds / 60))m"
        }
    }

    static let standardOptions: [CheckIntervalOption] = [
        CheckIntervalOption(seconds: 10),
        CheckIntervalOption(seconds: 30),
        CheckIntervalOption(seconds: 60),
        CheckIntervalOption(seconds: 120),
        CheckIntervalOption(seconds: 300),
        CheckIntervalOption(seconds: 600),
        CheckIntervalOption(seconds: 900),
        CheckIntervalOption(seconds: 1800),
        CheckIntervalOption(seconds: 3600)
    ]

    static func displayName(for seconds: TimeInterval) -> String {
        CheckIntervalOption(seconds: seconds).displayName
    }
}

struct MonitoringSettings: Codable, Hashable {
    var projectName: String = "Flight Control"
    var projectLocation: String = ""
    var monitoringEnabled: Bool = true
    var defaultCheckIntervalSeconds: TimeInterval = 60
    var minimumCheckIntervalSeconds: TimeInterval = 5
    var pingTimeoutSeconds: TimeInterval = 2
    var pingConcurrencyLimit: Int = 24
    var defaultWarningMissCount: Int = 1
    var defaultCriticalMissCount: Int = 3
    var retentionDays: Int = 30
    var interfaceMode: InterfaceMonitoringMode = .anyActive
    var selectedInterfaceIdentifier: String? = nil
    var showInAppCriticalPopups: Bool = true
    var launchAtLogin: Bool = false
    var preventSleep: Bool = true
    var operationalLoggingEnabled: Bool = false

    // Visible placeholders, intentionally not active yet.
    var deepSpaceNetworkEnabled: Bool = false
    var missionControlEndpoint: String = ""
    var timecodeIntegrationEnabled: Bool = false
    var timecodeSources: [String] = []
    var selectedTimecodeSource: String = ""



    enum CodingKeys: String, CodingKey {
        case projectName
        case projectLocation
        case monitoringEnabled
        case defaultCheckIntervalSeconds
        case minimumCheckIntervalSeconds
        case pingTimeoutSeconds
        case pingConcurrencyLimit
        case defaultWarningMissCount
        case defaultCriticalMissCount
        case retentionDays
        case interfaceMode
        case selectedInterfaceIdentifier
        case showInAppCriticalPopups
        case launchAtLogin
        case preventSleep
        case operationalLoggingEnabled
        case deepSpaceNetworkEnabled
        case missionControlEndpoint
        case timecodeIntegrationEnabled
        case timecodeSources
        case selectedTimecodeSource
    }

    init() { }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        projectName = try container.decodeIfPresent(String.self, forKey: .projectName) ?? "Flight Control"
        projectLocation = try container.decodeIfPresent(String.self, forKey: .projectLocation) ?? ""
        monitoringEnabled = try container.decodeIfPresent(Bool.self, forKey: .monitoringEnabled) ?? true
        defaultCheckIntervalSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .defaultCheckIntervalSeconds) ?? 60
        minimumCheckIntervalSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .minimumCheckIntervalSeconds) ?? 5
        pingTimeoutSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .pingTimeoutSeconds) ?? 2
        pingConcurrencyLimit = try container.decodeIfPresent(Int.self, forKey: .pingConcurrencyLimit) ?? 24
        defaultWarningMissCount = try container.decodeIfPresent(Int.self, forKey: .defaultWarningMissCount) ?? 1
        defaultCriticalMissCount = try container.decodeIfPresent(Int.self, forKey: .defaultCriticalMissCount) ?? 3
        retentionDays = try container.decodeIfPresent(Int.self, forKey: .retentionDays) ?? 30
        interfaceMode = try container.decodeIfPresent(InterfaceMonitoringMode.self, forKey: .interfaceMode) ?? .anyActive
        selectedInterfaceIdentifier = try container.decodeIfPresent(String.self, forKey: .selectedInterfaceIdentifier)
        showInAppCriticalPopups = try container.decodeIfPresent(Bool.self, forKey: .showInAppCriticalPopups) ?? true
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        preventSleep = try container.decodeIfPresent(Bool.self, forKey: .preventSleep) ?? true
        operationalLoggingEnabled = try container.decodeIfPresent(Bool.self, forKey: .operationalLoggingEnabled) ?? false
        deepSpaceNetworkEnabled = try container.decodeIfPresent(Bool.self, forKey: .deepSpaceNetworkEnabled) ?? false
        missionControlEndpoint = try container.decodeIfPresent(String.self, forKey: .missionControlEndpoint) ?? ""
        timecodeIntegrationEnabled = try container.decodeIfPresent(Bool.self, forKey: .timecodeIntegrationEnabled) ?? false
        timecodeSources = try container.decodeIfPresent([String].self, forKey: .timecodeSources) ?? []
        selectedTimecodeSource = try container.decodeIfPresent(String.self, forKey: .selectedTimecodeSource) ?? ""
        clampValues()
    }

    mutating func clampValues() {
        let allowed = CheckIntervalOption.standardOptions.map(\.seconds)
        if allowed.contains(defaultCheckIntervalSeconds) == false { defaultCheckIntervalSeconds = 60 }
        minimumCheckIntervalSeconds = max(1, minimumCheckIntervalSeconds)
        pingTimeoutSeconds = min(max(0.25, pingTimeoutSeconds), 10)
        pingConcurrencyLimit = min(max(1, pingConcurrencyLimit), 128)
        defaultWarningMissCount = max(1, defaultWarningMissCount)
        defaultCriticalMissCount = max(defaultWarningMissCount, defaultCriticalMissCount)
        retentionDays = min(max(1, retentionDays), 365)

        projectName = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        projectLocation = projectLocation.trimmingCharacters(in: .whitespacesAndNewlines)

        var cleanedSources: [String] = []
        for source in timecodeSources.map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }) where !source.isEmpty {
            if !cleanedSources.contains(where: { $0.caseInsensitiveCompare(source) == .orderedSame }) {
                cleanedSources.append(source)
            }
        }
        timecodeSources = cleanedSources.sorted { $0.localizedStandardCompare($1) == .orderedAscending }

        selectedTimecodeSource = selectedTimecodeSource.trimmingCharacters(in: .whitespacesAndNewlines)
        if !selectedTimecodeSource.isEmpty, !timecodeSources.contains(where: { $0.caseInsensitiveCompare(selectedTimecodeSource) == .orderedSame }) {
            selectedTimecodeSource = ""
        }
    }
}
