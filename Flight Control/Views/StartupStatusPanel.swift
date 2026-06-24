//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                    │
//  │  Flight Control                                             │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: StartupStatusPanel.swift
//  Purpose: Non-blocking startup panel using LunarKit shared layout.
//
//  Created by Chris Werner / Lunar Telephone Company.
//  © 2026 Lunar Telephone Company. All rights reserved.
//
//  This source file is part of Flight Control.
//

import AppKit
import SwiftUI
import LunarKit

final class StartupStatusPanelController {
    static let shared = StartupStatusPanelController()

    private var panel: NSPanel?
    private var autoDismissWorkItem: DispatchWorkItem?

    private init() { }

    func show(appState: AppState, duration: TimeInterval = 7.5) {
        DispatchQueue.main.async {
            self.showOnMain(appState: appState, duration: duration)
        }
    }

    func dismiss() {
        DispatchQueue.main.async {
            self.autoDismissWorkItem?.cancel()
            self.autoDismissWorkItem = nil
            self.panel?.close()
            self.panel = nil
        }
    }

    private func showOnMain(appState: AppState, duration: TimeInterval) {
        autoDismissWorkItem?.cancel()

        let contentView = StartupStatusPanelView(appState: appState) { [weak self] in
            self?.dismiss()
        }

        let hostingView = NSHostingView(rootView: contentView)
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 430),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.title = "FC - Launch"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = hostingView
        panel.center()

        self.panel = panel
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        NSApplication.shared.activate(ignoringOtherApps: true)

        let dismissWorkItem = DispatchWorkItem { [weak self] in
            self?.dismiss()
        }

        autoDismissWorkItem = dismissWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: dismissWorkItem)
    }
}

private struct StartupStatusPanelView: View {
    @ObservedObject var appState: AppState
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            LTCStartupPanelShell(
                identity: flightControlIdentity,
                version: appVersion,
                build: appBuild,
                projectName: projectDisplayName,
                statusItems: statusItems
            )

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Flight Control is starting local monitoring services.")
                        .font(LTCDesign.FontToken.cardCaption)
                        .foregroundStyle(LTCDesign.ColorToken.secondaryText)

                    Text("No Deep Space Network transmission occurs in this build.")
                        .font(.caption2)
                        .foregroundStyle(LTCDesign.ColorToken.tertiaryText)
                }

                Spacer()

                Button("Dismiss") { dismiss() }
                    .controlSize(.small)
            }
            .frame(width: 520)
        }
        .padding(20)
        .background(LTCDesign.ColorToken.windowBackground)
    }

    private var statusItems: [LTCStartupStatusItem] {
        [
            LTCStartupStatusItem(
                title: "Monitoring",
                value: appState.monitoringRunning ? "Active" : "Paused",
                severity: appState.monitoringRunning ? .healthy : .warning
            ),
            LTCStartupStatusItem(
                title: "System Health",
                value: appState.overallHealth.displayName,
                severity: severity(for: appState.overallHealth.displayName)
            ),
            LTCStartupStatusItem(
                title: "Devices",
                value: "\(appState.enabledDeviceCount) / \(appState.devices.count)",
                severity: appState.enabledDeviceCount > 0 ? .healthy : .unknown
            ),
            LTCStartupStatusItem(
                title: "Network Interfaces",
                value: "\(appState.networkInterfaces.count)",
                severity: appState.networkInterfaces.isEmpty ? .warning : .healthy
            ),
            LTCStartupStatusItem(
                title: "Sleep Prevention",
                value: appState.settings.preventSleep ? "Enabled" : "System Default",
                severity: appState.settings.preventSleep ? .healthy : .unknown
            )
        ]
    }

    private func severity(for displayName: String) -> LTCStatusSeverity {
        switch displayName.lowercased() {
        case let value where value.contains("healthy"):
            return .healthy
        case let value where value.contains("warning"):
            return .warning
        case let value where value.contains("critical"):
            return .critical
        case let value where value.contains("disabled"):
            return .disabled
        default:
            return .unknown
        }
    }

    private var projectDisplayName: String {
        let trimmed = appState.settings.projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Flight Control" : trimmed
    }

    private var flightControlIdentity: LTCAppIdentity {
        LTCAppIdentity(
            initials: "FC",
            displayName: "Flight Control",
            headerTitle: "FLIGHT CONTROL",
            appIconName: "AppIcon",
            companyIconName: "LTCIcon",
            companyLogoName: "LTCLogo"
        )
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }

    private var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }
}
