//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                    │
//  │  Flight Control                                             │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: AppInfo.swift
//  Purpose: App identity and user-facing version/build metadata.
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

enum AppInfo {
    static let appName = "Flight Control"
    static let shortName = "FC"
    static let displayName = "FLIGHT CONTROL"
    static let bundleIdentifier = "com.lunartelephone.flightcontrol"
    static let copyrightLine = "© 2026 Lunar Telephone Company. All rights reserved."

    static var versionString: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1"
    }

    static var buildString: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    static var versionBuildDisplay: String {
        "Version \(versionString) (\(buildString))"
    }
}
