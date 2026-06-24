//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                    │
//  │  Flight Control                                             │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: ConfigurationHealthService.swift
//  Purpose: Configuration self-checks for dashboard diagnostics.
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

struct ConfigurationIssue: Identifiable, Hashable {
    var id = UUID()
    var title: String
    var detail: String
    var state: DeviceHealthState
}

enum ConfigurationHealthService {
    static func evaluate(devices: [MonitoredDevice], settings: MonitoringSettings, interfaces: [NetworkInterfaceInfo]) -> [ConfigurationIssue] {
        var issues: [ConfigurationIssue] = []

        if devices.isEmpty {
            issues.append(ConfigurationIssue(title: "No devices configured", detail: "Add devices in Device Inventory to begin monitoring.", state: .unknown))
        }

        let enabledDevices = devices.filter(\.enabled)
        if !devices.isEmpty && enabledDevices.isEmpty {
            issues.append(ConfigurationIssue(title: "All devices disabled", detail: "Monitoring is enabled, but no inventory devices are active.", state: .warning))
        }

        let missingHostCount = enabledDevices.filter { $0.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
        if missingHostCount > 0 {
            issues.append(ConfigurationIssue(title: "Missing host/IP", detail: "\(missingHostCount) enabled device(s) need a host or IP address.", state: .warning))
        }

        if settings.interfaceMode == .selectedInterface, let selected = settings.selectedInterfaceIdentifier {
            let selectedInterface = interfaces.first { $0.name == selected }
            if selectedInterface == nil || selectedInterface?.isUp == false {
                issues.append(ConfigurationIssue(title: "Selected NIC unavailable", detail: "The selected interface is not currently available or up.", state: .critical))
            }
        }

        if settings.deepSpaceNetworkEnabled {
            issues.append(ConfigurationIssue(title: "DSN placeholder only", detail: "Deep Space Network transmission is not implemented in this build.", state: .warning))
        }

        return issues
    }
}
