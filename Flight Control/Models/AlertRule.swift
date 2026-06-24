//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                    │
//  │  Flight Control                                             │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: AlertRule.swift
//  Purpose: Forward-compatible alert rule and action architecture.
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

enum AlertRuleTrigger: String, Codable, CaseIterable, Identifiable {
    case deviceStateChanged
    case deviceCritical
    case deviceWarning
    case deviceRecovered
    case groupCritical
    case custom

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .deviceStateChanged: return "Device State Changed"
        case .deviceCritical: return "Device Critical"
        case .deviceWarning: return "Device Warning"
        case .deviceRecovered: return "Device Recovered"
        case .groupCritical: return "Group Critical"
        case .custom: return "Custom"
        }
    }
}

enum AlertRuleActionKind: String, Codable, CaseIterable, Identifiable {
    case dashboardAlert
    case inAppPopup
    case notificationCenter
    case deepSpaceNetwork
    case webhook
    case script

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .dashboardAlert: return "Dashboard Alert"
        case .inAppPopup: return "In-App Popup"
        case .notificationCenter: return "Notification Center"
        case .deepSpaceNetwork: return "Deep Space Network"
        case .webhook: return "Webhook"
        case .script: return "Script"
        }
    }
}

struct AlertRuleAction: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var kind: AlertRuleActionKind = .dashboardAlert
    var enabled: Bool = true
    var configuration: [String: String] = [:]
}

struct AlertRule: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String = "New Rule"
    var enabled: Bool = true
    var trigger: AlertRuleTrigger = .deviceCritical
    var targetGroupValue: String = ""
    var actions: [AlertRuleAction] = [AlertRuleAction(kind: .dashboardAlert)]
}
