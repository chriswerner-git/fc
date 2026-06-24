//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                    │
//  │  Flight Control                                             │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: Flight_ControlApp.swift
//  Purpose: Application entry point, windows, commands, and menu bar extra.
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


import AppKit
import SwiftUI
import LunarKit

@main
struct Flight_ControlApp: App {
    @StateObject private var appState: AppState
    @Environment(\.openWindow) private var openWindow

    init() {
        let state = AppState()
        _appState = StateObject(wrappedValue: state)

        if RuntimeEnvironment.isUnitTesting == false {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                StartupStatusPanelController.shared.show(appState: state)
            }
        }
    }

    var body: some Scene {
        dashboardWindow
        inventoryWindow
        preferencesWindow
        diagnosticsWindow
        aboutWindow
        helpWindow
        menuBarExtra
    }

    private var dashboardWindow: some Scene {
        Window(LTCAppIdentity.windowTitle(initials: "FC", windowName: "Dashboard"), id: "dashboard-window") {
            FCMainWindowView()
                .environmentObject(appState)
                .onAppear { activateApp() }
        }
        .defaultSize(width: FCLayout.Window.dashboard.defaultWidth, height: FCLayout.Window.dashboard.defaultHeight)
        .windowResizability(.contentMinSize)
    }

    private var inventoryWindow: some Scene {
        Window(LTCAppIdentity.windowTitle(initials: "FC", windowName: "Device Inventory"), id: "inventory-window") {
            DeviceInventoryView()
                .environmentObject(appState)
                .onAppear { activateApp() }
        }
        .defaultSize(width: FCLayout.Window.inventory.defaultWidth, height: FCLayout.Window.inventory.defaultHeight)
        .windowResizability(.contentMinSize)
    }

    private var preferencesWindow: some Scene {
        Window(LTCAppIdentity.windowTitle(initials: "FC", windowName: "Preferences"), id: "preferences-window") {
            PreferencesView()
                .environmentObject(appState)
                .onAppear { activateApp() }
        }
        .defaultSize(width: FCLayout.Window.preferences.defaultWidth, height: FCLayout.Window.preferences.defaultHeight)
        .windowResizability(.contentMinSize)
    }

    private var diagnosticsWindow: some Scene {
        Window(LTCAppIdentity.windowTitle(initials: "FC", windowName: "Diagnostics"), id: "diagnostics-window") {
            DiagnosticsView()
                .environmentObject(appState)
                .onAppear { activateApp() }
        }
        .defaultSize(width: FCLayout.Window.diagnostics.defaultWidth, height: FCLayout.Window.diagnostics.defaultHeight)
        .windowResizability(.contentMinSize)
    }

    private var aboutWindow: some Scene {
        Window(LTCAppIdentity.windowTitle(initials: "FC", windowName: "About"), id: "about-window") {
            AboutFlightControlView()
                .onAppear { activateApp() }
        }
        .defaultSize(width: FCLayout.Window.about.defaultWidth, height: FCLayout.Window.about.defaultHeight)
        .windowResizability(.contentMinSize)
    }

    private var helpWindow: some Scene {
        Window(LTCAppIdentity.windowTitle(initials: "FC", windowName: "Help"), id: "help-window") {
            HelpFlightControlView()
                .onAppear { activateApp() }
        }
        .defaultSize(width: FCLayout.Window.help.defaultWidth, height: FCLayout.Window.help.defaultHeight)
        .windowResizability(.contentMinSize)
    }

    private var menuBarExtra: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
        } label: {
            Image(systemName: appState.overallHealth == .critical ? "antenna.radiowaves.left.and.right.slash" : "antenna.radiowaves.left.and.right")
                .symbolRenderingMode(.hierarchical)
        }
        .menuBarExtraStyle(.menu)
    }

    private func activateApp() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
