//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                    │
//  │  Flight Control                                             │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: NetworkInterfaceInfo.swift
//  Purpose: Serializable local network interface summary used by Preferences and Diagnostics.
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

struct NetworkInterfaceInfo: Identifiable, Codable, Hashable {
    var id: String { name }
    var name: String
    var displayName: String
    var ipv4Addresses: [String]
    var ipv4SubnetMasks: [String]
    var ipv6Addresses: [String]
    var isUp: Bool
    var isLoopback: Bool

    var primaryAddress: String {
        ipv4Addresses.first ?? ipv6Addresses.first ?? "No address"
    }

    var primarySubnetMask: String {
        ipv4SubnetMasks.first ?? "No subnet"
    }

    var dashboardDisplayName: String {
        displayName == name ? name : "\(displayName) · \(name)"
    }

    var detailDisplay: String {
        var parts: [String] = []
        if isUp { parts.append("Up") } else { parts.append("Down") }
        if isLoopback { parts.append("Loopback") }

        if let ipv4 = ipv4Addresses.first {
            if let mask = ipv4SubnetMasks.first {
                parts.append("\(ipv4) / \(mask)")
            } else {
                parts.append(ipv4)
            }
        } else {
            parts.append(primaryAddress)
        }

        return parts.joined(separator: " · ")
    }
}
