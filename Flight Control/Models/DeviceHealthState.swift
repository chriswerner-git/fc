//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                    │
//  │  Flight Control                                             │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: DeviceHealthState.swift
//  Purpose: Health states used by monitored devices, dashboard cards, and alerts.
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
import SwiftUI

enum DeviceHealthState: String, Codable, CaseIterable, Identifiable, Comparable {
    case healthy
    case warning
    case critical
    case unknown
    case disabled

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .healthy: return "Healthy"
        case .warning: return "Warning"
        case .critical: return "Critical"
        case .unknown: return "Unknown"
        case .disabled: return "Disabled"
        }
    }

    var sortPriority: Int {
        switch self {
        case .critical: return 0
        case .warning: return 1
        case .unknown: return 2
        case .healthy: return 3
        case .disabled: return 4
        }
    }

    var systemImageName: String {
        switch self {
        case .healthy: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.octagon.fill"
        case .unknown: return "questionmark.circle.fill"
        case .disabled: return "pause.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .healthy: return FCDesign.ColorToken.good
        case .warning: return FCDesign.ColorToken.warning
        case .critical: return FCDesign.ColorToken.critical
        case .unknown: return .secondary
        case .disabled: return .secondary.opacity(0.65)
        }
    }

    static func < (lhs: DeviceHealthState, rhs: DeviceHealthState) -> Bool {
        lhs.sortPriority < rhs.sortPriority
    }
}
