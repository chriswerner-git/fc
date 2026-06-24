//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                    │
//  │  Flight Control                                             │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: PersistenceService.swift
//  Purpose: Atomic JSON persistence for Flight Control configuration and recent status history.
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

struct FlightControlSnapshot: Codable {
    var settings: MonitoringSettings
    var devices: [MonitoredDevice]
    var inventoryGroups: [DeviceInventoryGroup]
    var alertRules: [AlertRule]
    var statusEvents: [StatusEvent]

    init(
        settings: MonitoringSettings,
        devices: [MonitoredDevice],
        inventoryGroups: [DeviceInventoryGroup] = [],
        alertRules: [AlertRule],
        statusEvents: [StatusEvent]
    ) {
        self.settings = settings
        self.devices = devices
        self.inventoryGroups = inventoryGroups
        self.alertRules = alertRules
        self.statusEvents = statusEvents
    }

    private enum CodingKeys: String, CodingKey {
        case settings
        case devices
        case inventoryGroups
        case alertRules
        case statusEvents
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        settings = try container.decode(MonitoringSettings.self, forKey: .settings)
        devices = try container.decode([MonitoredDevice].self, forKey: .devices)
        inventoryGroups = try container.decodeIfPresent([DeviceInventoryGroup].self, forKey: .inventoryGroups) ?? []
        alertRules = try container.decode([AlertRule].self, forKey: .alertRules)
        statusEvents = try container.decode([StatusEvent].self, forKey: .statusEvents)
    }
}

enum PersistenceService {
    static let folderName = "Flight Control"
    static let fileName = "FlightControlConfiguration.json"

    static var applicationSupportFolderURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent(folderName, isDirectory: true)
    }

    static var snapshotURL: URL {
        applicationSupportFolderURL.appendingPathComponent(fileName, isDirectory: false)
    }

    static func loadSnapshot() throws -> FlightControlSnapshot? {
        let url = snapshotURL
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try JSONDecoder.flightControl.decode(FlightControlSnapshot.self, from: data)
    }

    static func saveSnapshot(_ snapshot: FlightControlSnapshot) throws {
        try FileManager.default.createDirectory(at: applicationSupportFolderURL, withIntermediateDirectories: true)
        let data = try JSONEncoder.flightControl.encode(snapshot)
        let tempURL = applicationSupportFolderURL.appendingPathComponent(".\(fileName).tmp", isDirectory: false)
        try data.write(to: tempURL, options: [.atomic])
        if FileManager.default.fileExists(atPath: snapshotURL.path) {
            try FileManager.default.removeItem(at: snapshotURL)
        }
        try FileManager.default.moveItem(at: tempURL, to: snapshotURL)
    }
}

private extension JSONEncoder {
    static var flightControl: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var flightControl: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
