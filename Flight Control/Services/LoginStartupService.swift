//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                    │
//  │  Flight Control                                             │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: LoginStartupService.swift
//  Purpose: Wraps macOS login item registration for Launch at Startup.
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
import ServiceManagement

/// Small service boundary for the macOS Launch at Login preference.
///
/// `SMAppService.mainApp` is the modern macOS mechanism used by the other LTC
/// desktop utilities.  Keeping this behind a service keeps AppState and
/// PreferencesView clean, and gives us one file to revisit if packaging,
/// signing, or helper-app strategy changes later.
enum LoginStartupService {
    enum StartupStatus {
        case enabled
        case disabled
        case requiresApproval
        case unavailable
        case unknown

        var displayName: String {
            switch self {
            case .enabled: return "Enabled"
            case .disabled: return "Disabled"
            case .requiresApproval: return "Requires Approval"
            case .unavailable: return "Unavailable"
            case .unknown: return "Unknown"
            }
        }

        var helpText: String {
            switch self {
            case .enabled:
                return "Flight Control is registered to open when you log in."
            case .disabled:
                return "Flight Control is not currently registered to open when you log in."
            case .requiresApproval:
                return "macOS needs approval in Login Items before Flight Control can launch at startup."
            case .unavailable:
                return "macOS did not find an app bundle that can be registered as a login item."
            case .unknown:
                return "macOS returned an unknown launch-at-login status."
            }
        }
    }

    static var status: StartupStatus {
        switch SMAppService.mainApp.status {
        case .enabled:
            return .enabled
        case .notRegistered:
            return .disabled
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .unavailable
        @unknown default:
            return .unknown
        }
    }

    static var isEnabled: Bool {
        status == .enabled
    }

    static func setEnabled(_ enabled: Bool) throws {
        let currentStatus = status

        if enabled {
            guard currentStatus != .enabled else { return }
            try SMAppService.mainApp.register()
        } else {
            guard currentStatus != .disabled else { return }
            try SMAppService.mainApp.unregister()
        }
    }
}
