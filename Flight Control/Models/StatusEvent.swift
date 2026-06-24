//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                    │
//  │  Flight Control                                             │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: StatusEvent.swift
//  Purpose: Lightweight health history events for dashboard visibility and future charting.
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

struct StatusEvent: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var date: Date = Date()
    var deviceID: UUID? = nil
    var deviceName: String = ""
    var previousState: DeviceHealthState? = nil
    var newState: DeviceHealthState = .unknown
    var message: String = ""
    var latencyMilliseconds: Double? = nil

    var isAlert: Bool {
        newState == .warning || newState == .critical
    }

    var timeDisplay: String {
        date.formatted(date: .omitted, time: .standard)
    }
}
