//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                    │
//  │  Flight Control                                             │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: DeviceMonitoringMethod.swift
//  Purpose: Monitoring method definitions prepared for ping now and future protocols later.
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

enum DeviceMonitoringMethod: String, Codable, CaseIterable, Identifiable {
    case ping
    case arp
    case sACN
    case citp
    case tcpPort
    case http
    case timecode
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ping: return "Ping"
        case .arp: return "ARP"
        case .sACN: return "sACN"
        case .citp: return "CITP"
        case .tcpPort: return "TCP Port"
        case .http: return "HTTP"
        case .timecode: return "Timecode"
        case .custom: return "Custom"
        }
    }

    var isImplemented: Bool {
        switch self {
        case .ping: return true
        default: return false
        }
    }

    var implementationNote: String {
        isImplemented ? "Available now" : "Planned for a future Flight Control build"
    }
}
