//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                    │
//  │  Flight Control                                             │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: StartupStatusPanel.swift
//  Purpose: Non-blocking startup panel matching the LTC utility-app pattern.
//
//  Created by Chris Werner / Lunar Telephone Company.
//  © 2026 Lunar Telephone Company. All rights reserved.
//
//  This source file is part of Flight Control.
//

import AppKit
import SwiftUI

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
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 570),
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
        VStack(spacing: 16) {
            header
            startupDivider
            centeredLTCLogo
            statusGrid
            footer
        }
        .padding(24)
        .frame(width: 600, height: 570)
        .background(FCDesign.screenBackground())
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 18) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 74, height: 74)
                .accessibilityLabel("Flight Control app icon")

            VStack(alignment: .leading, spacing: 7) {
                Text(FCLayout.appNameDisplay)
                    .font(.system(size: 30, weight: .bold))
                    .tracking(2.0)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(AppInfo.versionBuildDisplay)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var centeredLTCLogo: some View {
        Image("LTCLogo")
            .resizable()
            .scaledToFit()
            .frame(height: 88)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 6)
            .accessibilityLabel("Lunar Telephone Company logo")
    }

    private var statusGrid: some View {
        VStack(spacing: 0) {
            StartupStatusRow(
                icon: "folder",
                title: "Project",
                value: projectDisplayName,
                color: FCDesign.ColorToken.active
            )

            startupDivider

            StartupStatusRow(
                icon: appState.monitoringRunning ? "checkmark.circle.fill" : "pause.circle",
                title: "Monitoring",
                value: appState.monitoringRunning ? "Monitoring active" : "Monitoring paused",
                color: appState.monitoringRunning ? FCDesign.ColorToken.good : FCDesign.ColorToken.warning
            )

            startupDivider

            StartupStatusRow(
                icon: appState.overallHealth.systemImageName,
                title: "System Health",
                value: appState.overallHealth.displayName,
                color: appState.overallHealth.color
            )

            startupDivider

            HStack(spacing: 0) {
                StartupStatusMetric(
                    icon: "network",
                    title: "Devices",
                    value: "\(appState.enabledDeviceCount) / \(appState.devices.count)",
                    color: FCDesign.ColorToken.active
                )

                startupDividerVertical

                StartupStatusMetric(
                    icon: "cable.connector",
                    title: "NICs",
                    value: "\(appState.networkInterfaces.count)",
                    color: FCDesign.ColorToken.active
                )

                startupDividerVertical

                StartupStatusMetric(
                    icon: appState.settings.preventSleep ? "moon.zzz.fill" : "moon.zzz",
                    title: "Sleep",
                    value: appState.settings.preventSleep ? "Prevented" : "System Default",
                    color: appState.settings.preventSleep ? FCDesign.ColorToken.good : .secondary
                )
            }
            .frame(height: 74)
        }
        .background(FCDesign.cardBackground(cornerRadius: 18))
        .overlay(FCDesign.cardBorder(cornerRadius: 18))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var footer: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Flight Control is starting local monitoring services.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("No Deep Space Network transmission occurs in this build.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Button("Dismiss") { dismiss() }
                .controlSize(.small)
        }
    }

    private var projectDisplayName: String {
        let trimmed = appState.settings.projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Flight Control" : trimmed
    }

    private var startupDivider: some View {
        Rectangle()
            .fill(FCDesign.ColorToken.strongBorder)
            .frame(height: 1)
    }

    private var startupDividerVertical: some View {
        Rectangle()
            .fill(FCDesign.ColorToken.strongBorder)
            .frame(width: 1)
    }
}

private struct StartupStatusRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 24)

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 118, alignment: .leading)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
    }
}

private struct StartupStatusMetric: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)

            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()

            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
