//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                    │
//  │  Flight Control                                             │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: NetworkInterfaceInventoryService.swift
//  Purpose: Local network interface inventory for multi-NIC diagnostics and future scoped checks.
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

#if os(macOS)
import Darwin
import SystemConfiguration
#endif

enum NetworkInterfaceInventoryService {
    static func currentInterfaces() -> [NetworkInterfaceInfo] {
        var addressPointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addressPointer) == 0, let firstAddress = addressPointer else {
            return []
        }
        defer { freeifaddrs(addressPointer) }

        let friendlyNames = systemFriendlyNamesByBSDName()
        var records: [String: (ipv4: [String], ipv4Masks: [String], ipv6: [String], flags: UInt32)] = [:]
        var cursor: UnsafeMutablePointer<ifaddrs>? = firstAddress

        while let interface = cursor?.pointee {
            let name = String(cString: interface.ifa_name)
            let flags = interface.ifa_flags
            var record = records[name] ?? ([], [], [], flags)
            record.flags = flags

            if let address = interface.ifa_addr {
                let family = address.pointee.sa_family
                if family == UInt8(AF_INET) {
                    if let value = numericHost(from: address), !record.ipv4.contains(value) {
                        record.ipv4.append(value)
                    }
                    if let netmask = interface.ifa_netmask, let maskValue = numericHost(from: netmask), !record.ipv4Masks.contains(maskValue) {
                        record.ipv4Masks.append(maskValue)
                    }
                } else if family == UInt8(AF_INET6) {
                    if let value = numericHost(from: address), !record.ipv6.contains(value) {
                        record.ipv6.append(value)
                    }
                }
            }

            records[name] = record
            cursor = interface.ifa_next
        }

        return records.compactMap { name, record in
            guard isUserFacingActiveInterface(name: name, record: record) else { return nil }

            return NetworkInterfaceInfo(
                name: name,
                displayName: friendlyNames[name] ?? fallbackFriendlyName(for: name),
                ipv4Addresses: record.ipv4.sorted(),
                ipv4SubnetMasks: record.ipv4Masks.sorted(),
                ipv6Addresses: record.ipv6.sorted(),
                isUp: true,
                isLoopback: false
            )
        }
        .sorted { lhs, rhs in
            if lhs.ipv4Addresses.isEmpty != rhs.ipv4Addresses.isEmpty {
                return !lhs.ipv4Addresses.isEmpty && rhs.ipv4Addresses.isEmpty
            }
            if lhs.displayName != rhs.displayName {
                return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    private static func numericHost(from socketAddress: UnsafePointer<sockaddr>) -> String? {
        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let result = getnameinfo(
            socketAddress,
            socklen_t(socketAddress.pointee.sa_len),
            &hostname,
            socklen_t(hostname.count),
            nil,
            0,
            NI_NUMERICHOST
        )
        guard result == 0 else { return nil }
        return String(cString: hostname)
    }

    /// Returns only interfaces that are useful for Flight Control device checks.
    /// macOS reports many internal, virtual, peer-to-peer, tunnel, and bridge
    /// interfaces as "up." Those are legitimate system interfaces, but they are
    /// not operator-facing NICs for project device monitoring.
    private static func isUserFacingActiveInterface(
        name: String,
        record: (ipv4: [String], ipv4Masks: [String], ipv6: [String], flags: UInt32)
    ) -> Bool {
        let isUp = (record.flags & UInt32(IFF_UP)) != 0
        let isRunning = (record.flags & UInt32(IFF_RUNNING)) != 0
        let isLoopback = (record.flags & UInt32(IFF_LOOPBACK)) != 0
        let isPointToPoint = (record.flags & UInt32(IFF_POINTOPOINT)) != 0

        guard isUp, isRunning, !isLoopback, !isPointToPoint else { return false }

        let ignoredPrefixes = [
            "awdl",     // Apple Wireless Direct Link
            "llw",      // Low-latency Wi-Fi
            "utun",     // VPN/tunnel interfaces
            "anpi",     // Apple internal peer interfaces
            "ap",       // Apple peer-to-peer interfaces
            "p2p",      // Peer-to-peer interfaces
            "gif",      // Generic tunnel
            "stf",      // IPv6 transition tunnel
            "bridge",   // Virtual bridges
            "vmenet",   // Virtual machine interfaces
            "vmnet",    // Virtual machine interfaces
            "ipsec"     // IPSec tunnel interfaces
        ]

        if ignoredPrefixes.contains(where: { name.hasPrefix($0) }) { return false }

        let usableIPv4 = record.ipv4.contains { address in
            !address.isEmpty && address != "0.0.0.0" && !address.hasPrefix("169.254.")
        }

        let usableGlobalIPv6 = record.ipv6.contains { address in
            !address.isEmpty
            && address != "::1"
            && !address.hasPrefix("fe80:")
            && !address.hasPrefix("fd")
            && !address.hasPrefix("fc")
        }

        return usableIPv4 || usableGlobalIPv6
    }

    private static func systemFriendlyNamesByBSDName() -> [String: String] {
        #if os(macOS)
        guard let interfaces = SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] else { return [:] }
        var result: [String: String] = [:]

        for interface in interfaces {
            guard let bsdNameRef = SCNetworkInterfaceGetBSDName(interface) else { continue }
            let bsdName = bsdNameRef as String

            if let displayNameRef = SCNetworkInterfaceGetLocalizedDisplayName(interface) {
                let displayName = displayNameRef as String
                if !displayName.isEmpty {
                    result[bsdName] = displayName
                }
            }
        }

        return result
        #else
        return [:]
        #endif
    }

    private static func fallbackFriendlyName(for name: String) -> String {
        if name == "lo0" { return "Loopback" }
        if name.hasPrefix("en") { return "Network Adapter" }
        if name.hasPrefix("bridge") { return "Bridge" }
        if name.hasPrefix("utun") { return "VPN/Tunnel" }
        return name
    }
}
