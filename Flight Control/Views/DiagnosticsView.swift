//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                    │
//  │  Flight Control                                             │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: DiagnosticsView.swift
//  Purpose: Diagnostics screen for monitoring engine, configuration, devices, and network interfaces.
//
//  Created by Chris Werner / Lunar Telephone Company.
//  © 2026 Lunar Telephone Company. All rights reserved.
//
//  This source file is part of Flight Control.
//

import SwiftUI
import LunarKit

struct DiagnosticsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        FCScreen(title: "FC - Diagnostics", subtitle: "Operational details for long-running monitoring stability.") {
            LTCDiagnosticsShell(
                summaryTitle: summaryTitle,
                summaryDescription: summaryDescription,
                level: summaryLevel
            ) {
                runtimeSection
                configurationSection
                networkSection
                servicesSection
                integrationsSection
            }
        }
    }

    private var summaryTitle: String {
        switch appState.overallHealth {
        case .healthy:
            return "Monitoring Stable"
        case .warning:
            return "Warnings Detected"
        case .critical:
            return "Critical Issues Detected"
        case .unknown:
            return "Monitoring Status Unknown"
        case .disabled:
            return "Monitoring Disabled"
        }
    }

    private var summaryDescription: String {
        let enabled = appState.enabledDeviceCount
        let total = appState.devices.count
        let issueCount = appState.configurationIssues.count
        let issueText = issueCount == 1 ? "1 configuration issue" : "\(issueCount) configuration issues"
        return "\(enabled) of \(total) inventory devices are enabled. \(issueText) currently reported."
    }

    private var summaryLevel: LTCStatusLevel {
        statusLevel(for: appState.overallHealth)
    }

    private var runtimeSection: some View {
        LTCDiagnosticsSection(category: .runtime, subtitle: "Monitoring engine state, scheduling, and polling behavior.") {
            LTCDiagnosticRows([
                LTCDiagnosticItem(
                    title: "Monitoring Engine",
                    detail: appState.monitoringRunning ? "Running" : "Stopped",
                    level: appState.monitoringRunning ? .good : .inactive
                ),
                LTCDiagnosticItem(
                    title: "Last Engine Message",
                    detail: appState.lastEngineMessage,
                    level: .info
                ),
                LTCDiagnosticItem(
                    title: "Last Check",
                    detail: formattedDate(appState.lastCheckDate),
                    level: appState.lastCheckDate == nil ? .unknown : .info
                ),
                LTCDiagnosticItem(
                    title: "Next Check",
                    detail: formattedDate(appState.nextCheckDate),
                    level: appState.nextCheckDate == nil ? .unknown : .info
                ),
                LTCDiagnosticItem(
                    title: "Ping Concurrency Limit",
                    detail: "\(appState.settings.pingConcurrencyLimit)",
                    level: .info,
                    monospacedDetail: true
                ),
                LTCDiagnosticItem(
                    title: "App Uptime",
                    detail: appState.uptimeDisplay,
                    level: .info
                )
            ])
        }
    }

    private var configurationSection: some View {
        LTCDiagnosticsSection(category: .configuration, subtitle: "Self-checks for inventory, preferences, and monitoring setup.") {
            if appState.configurationIssues.isEmpty {
                LTCDiagnosticRows([
                    LTCDiagnosticItem(
                        title: "Configuration Health",
                        detail: "No current configuration issues.",
                        level: .good
                    )
                ])
            } else {
                LTCDiagnosticRows(appState.configurationIssues.map { issue in
                    LTCDiagnosticItem(
                        title: issue.title,
                        detail: issue.detail,
                        level: statusLevel(for: issue.state)
                    )
                })
            }
        }
    }

    private var networkSection: some View {
        LTCDiagnosticsSection(category: .network, subtitle: "Local active interfaces visible to Flight Control.") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Interfaces")
                        .font(LTCDesign.FontToken.rowTitle)
                        .foregroundStyle(LTCDesign.ColorToken.primaryText)

                    Spacer()

                    Button("Refresh") {
                        appState.refreshNetworkInterfaces()
                    }
                    .buttonStyle(.bordered)
                }

                if appState.networkInterfaces.isEmpty {
                    LTCEmptyStateView(
                        title: "No Interfaces Found",
                        message: "Flight Control did not find any active local interfaces in the current filtered inventory.",
                        systemImage: "network.slash"
                    )
                } else {
                    LTCDiagnosticRows(appState.networkInterfaces.map { interface in
                        LTCDiagnosticItem(
                            title: interface.dashboardDisplayName,
                            detail: interface.dashboardAddressDisplay,
                            level: interface.isUp ? .good : .inactive,
                            monospacedDetail: true
                        )
                    })
                }
            }
        }
    }

    private var servicesSection: some View {
        LTCDiagnosticsSection(category: .services, subtitle: "Device probe state and most recent per-device results.") {
            if appState.devices.isEmpty {
                LTCEmptyStateView(
                    title: "No Devices Configured",
                    message: "Add devices in Device Inventory to begin monitoring.",
                    systemImage: "network.badge.shield.half.filled"
                )
            } else {
                LTCDiagnosticRows(appState.devices.map { device in
                    LTCDiagnosticItem(
                        title: device.displayName,
                        detail: deviceDiagnosticDetail(device),
                        level: statusLevel(for: device.healthState),
                        monospacedDetail: false
                    )
                })
            }
        }
    }

    private var integrationsSection: some View {
        LTCDiagnosticsSection(category: .integrations, subtitle: "Future project-location integrations reserved by Flight Control.") {
            LTCDiagnosticRows([
                LTCDiagnosticItem(
                    title: "Deep Space Network",
                    detail: appState.settings.deepSpaceNetworkEnabled ? "Enabled placeholder only" : "Offline / not configured",
                    level: appState.settings.deepSpaceNetworkEnabled ? .warning : .inactive
                ),
                LTCDiagnosticItem(
                    title: "Mission Control",
                    detail: "Offline / not configured",
                    level: .inactive
                ),
                LTCDiagnosticItem(
                    title: "Timecode Integration",
                    detail: appState.settings.timecodeSources.isEmpty ? "No sources defined" : "\(appState.settings.timecodeSources.count) source(s) defined",
                    level: appState.settings.timecodeSources.isEmpty ? .inactive : .info
                ),
                LTCDiagnosticItem(
                    title: "Camera Feeds",
                    detail: appState.settings.cameraFeedNames.isEmpty ? "No feeds defined" : "\(appState.settings.cameraFeedNames.count) feed(s) defined",
                    level: appState.settings.cameraFeedNames.isEmpty ? .inactive : .info
                )
            ])
        }
    }

    private func statusLevel(for state: DeviceHealthState) -> LTCStatusLevel {
        switch state {
        case .healthy:
            return .good
        case .warning:
            return .warning
        case .critical:
            return .critical
        case .unknown:
            return .unknown
        case .disabled:
            return .disabled
        }
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date else { return "Never" }
        return date.formatted(date: .abbreviated, time: .standard)
    }

    private func deviceDiagnosticDetail(_ device: MonitoredDevice) -> String {
        var parts = [
            "Host: \(device.addressDisplay)",
            "Method: \(device.monitoringMethod.displayName)",
            "Fails: \(device.consecutiveFailures)",
            "Last: \(formattedDate(device.lastCheckedAt))"
        ]

        if let error = device.lastErrorMessage, !error.isEmpty {
            parts.append("Error: \(error)")
        }

        return parts.joined(separator: " · ")
    }
}
