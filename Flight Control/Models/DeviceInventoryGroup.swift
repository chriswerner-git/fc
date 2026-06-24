//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                    │
//  │  Flight Control                                             │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: DeviceInventoryGroup.swift
//  Purpose: Nestable inventory grouping model for organizing monitored devices.
//
//  Created by Chris Werner / Lunar Telephone Company.
//  © 2026 Lunar Telephone Company. All rights reserved.
//
//  This source file is part of Flight Control.
//

import Foundation

struct DeviceInventoryGroup: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String = "New Group"
    var category: String = ""
    var notes: String = ""
    var children: [DeviceInventoryGroup] = []

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Unnamed Group" : trimmed
    }

    var categoryDisplay: String {
        let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Group" : trimmed
    }

    var menuDisplayName: String {
        category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? displayName : "\(categoryDisplay): \(displayName)"
    }

    static let suggestedCategories = ["Location", "Discipline", "System", "Function", "Scene", "Responsible Party", "Network", "Custom"]
}

struct DeviceInventoryGroupOption: Identifiable, Hashable {
    var id: UUID
    var name: String
    var depth: Int

    var menuTitle: String {
        String(repeating: "   ", count: depth) + name
    }
}
