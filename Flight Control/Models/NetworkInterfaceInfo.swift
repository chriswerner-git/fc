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

    var primaryCIDRPrefix: String? {
        guard let mask = ipv4SubnetMasks.first else { return nil }
        let parts = mask.split(separator: ".").compactMap { UInt8($0) }
        guard parts.count == 4 else { return nil }
        let count = parts.reduce(0) { partial, octet in
            partial + octet.nonzeroBitCount
        }
        return "/\(count)"
    }

    var dashboardDisplayName: String {
        displayName == name ? name : "\(displayName) · \(name)"
    }

    var dashboardAddressDisplay: String {
        if let ipv4 = ipv4Addresses.first {
            return "\(ipv4) \(primaryCIDRPrefix ?? "")".trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return primaryAddress
    }

    var detailDisplay: String {
        var lines: [String] = []
        lines.append(displayName == name ? name : "\(displayName) · \(name)")
        lines.append(isUp ? "Status: Up" : "Status: Down")
        if isLoopback { lines.append("Loopback interface") }
        if !ipv4Addresses.isEmpty {
            let addresses = ipv4Addresses.enumerated().map { index, address in
                let mask = ipv4SubnetMasks.indices.contains(index) ? ipv4SubnetMasks[index] : ""
                let prefix = Self.cidrPrefix(from: mask) ?? ""
                return "\(address) \(prefix)".trimmingCharacters(in: .whitespacesAndNewlines)
            }
            lines.append("IPv4: \(addresses.joined(separator: ", "))")
        }
        if !ipv6Addresses.isEmpty {
            lines.append("IPv6: \(ipv6Addresses.joined(separator: ", "))")
        }
        return lines.joined(separator: "\n")
    }

    private static func cidrPrefix(from mask: String) -> String? {
        let parts = mask.split(separator: ".").compactMap { UInt8($0) }
        guard parts.count == 4 else { return nil }
        let count = parts.reduce(0) { partial, octet in
            partial + octet.nonzeroBitCount
        }
        return "/\(count)"
    }
}
