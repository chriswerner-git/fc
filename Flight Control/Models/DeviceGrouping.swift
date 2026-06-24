//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                    │
//  │  Flight Control                                             │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: DeviceGrouping.swift
//  Purpose: Flexible grouping fields for location, discipline, function, responsible party, scene, and tags.
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

struct DeviceGrouping: Codable, Hashable {
    var location: String = ""
    var discipline: String = ""
    var function: String = ""
    var responsibleParty: String = ""
    var scene: String = ""
    var tags: [String] = []

    static let suggestedDisciplines = ["Lighting", "Audio", "Video", "Show Control", "Network", "Cameras", "Power", "Other"]
    static let suggestedFunctions = ["Controller", "Gateway", "Switch", "Server", "Workstation", "Camera", "Node", "Fixture", "Other"]

    var compactDisplay: String {
        let values = [location, discipline, function]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return values.isEmpty ? "Ungrouped" : values.joined(separator: " / ")
    }
}
