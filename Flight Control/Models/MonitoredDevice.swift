//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                    │
//  │  Flight Control                                             │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: MonitoredDevice.swift
//  Purpose: Persistent device inventory item and current runtime monitoring state.
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

struct MonitoredDevice: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String = "New Device"
    var host: String = ""
    var macAddress: String = ""
    var vendor: String = ""
    var model: String = ""
    var serialNumber: String = ""
    var notes: String = ""
    var enabled: Bool = true
    var grouping: DeviceGrouping = DeviceGrouping()
    var primaryGroupID: UUID? = nil
    var monitoringMethod: DeviceMonitoringMethod = .ping
    var checkIntervalSeconds: TimeInterval? = nil
    var preferredInterfaceIdentifier: String? = nil
    var warningMissCount: Int = 1
    var criticalMissCount: Int = 3

    // Runtime health fields are persisted intentionally so relaunches can show
    // the last known state instead of blanking the dashboard until the next scan.
    var healthState: DeviceHealthState = .unknown
    var consecutiveFailures: Int = 0
    var lastCheckedAt: Date? = nil
    var lastHealthyAt: Date? = nil
    var lastLatencyMilliseconds: Double? = nil
    var lastErrorMessage: String? = nil
    var nextCheckAfter: Date? = nil

    var displayName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? host : name
    }

    var addressDisplay: String {
        host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No host/IP" : host
    }

    var canRunImplementedCheck: Bool {
        enabled && monitoringMethod.isImplemented && !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func effectiveCheckIntervalSeconds(settings: MonitoringSettings) -> TimeInterval {
        max(settings.minimumCheckIntervalSeconds, checkIntervalSeconds ?? settings.defaultCheckIntervalSeconds)
    }

    static var sampleLightingController: MonitoredDevice {
        var device = MonitoredDevice()
        device.name = "Lighting Controller"
        device.host = "192.168.1.50"
        device.grouping.discipline = "Lighting"
        device.grouping.function = "Controller"
        device.notes = "Sample starter device. Replace or delete."
        return device
    }
}
