//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                    │
//  │  Flight Control                                             │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: MenuBarView.swift
//  Purpose: Menu bar controls for Flight Control windows and monitoring lifecycle.
//
//  Created by Chris Werner / Lunar Telephone Company.
//  © 2026 Lunar Telephone Company. All rights reserved.
//
//  This source file is part of Flight Control.
//


import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading) {
            Text("Flight Control")
                .font(.headline)
            Text("Status: \(appState.overallHealth.displayName)")
                .font(.caption)
                .foregroundStyle(appState.overallHealth.color)
            Divider()
            Button("Dashboard") { openWindow(id: "dashboard-window") }
            Button("Device Inventory") { openWindow(id: "inventory-window") }
            Button("Diagnostics") { openWindow(id: "diagnostics-window") }
            Divider()
            Button(appState.monitoringRunning ? "Pause Monitoring" : "Start Monitoring") { appState.toggleMonitoring() }
            Button("Check All Now") { appState.forceCheckNow() }
            Divider()
            Button("Preferences") { openWindow(id: "preferences-window") }
            Button("Help") { openWindow(id: "help-window") }
            Button("About Flight Control") { openWindow(id: "about-window") }
            Divider()
            Button("Quit Flight Control") { NSApp.terminate(nil) }
        }
        .frame(minWidth: 220)
        .padding(.vertical, 6)
    }
}
