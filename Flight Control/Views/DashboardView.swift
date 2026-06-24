//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                    │
//  │  Flight Control                                             │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: DashboardView.swift
//  Purpose: Primary system health dashboard.
//
//  Created by Chris Werner / Lunar Telephone Company.
//  © 2026 Lunar Telephone Company. All rights reserved.
//
//  This source file is part of Flight Control.
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openWindow) private var openWindow

    private let summaryCardHeight: CGFloat = 152

    var body: some View {
        FCScreen(title: "Dashboard", subtitle: "Project device health, monitoring status, and recent alerts.", systemImage: "rectangle.grid.2x2.fill") {
            ScrollView {
                VStack(spacing: FCLayout.Spacing.card) {
                    clockAndSummary
                        .padding(.top, -10)
                    placeholderCards
                    statusCards
                    mainGrid
                }
                .padding(.vertical, 2)
            }
        }
        .alert(item: $appState.showingCriticalAlert) { event in
            Alert(
                title: Text("Critical Device Alert"),
                message: Text("\(event.deviceName): \(event.message)"),
                dismissButton: .default(Text("Acknowledge"))
            )
        }
    }

    // MARK: - Dashboard Clock / Summary

    private var clockAndSummary: some View {
        TimelineView(.periodic(from: Date(), by: 1)) { context in
            ZStack(alignment: .bottomLeading) {
                clockDisplay(for: context.date)

                lowerLeftDiagnostics
                    .frame(maxWidth: .infinity, alignment: .bottomLeading)

                futureLinkStatus
                    .frame(maxWidth: .infinity, alignment: .bottomTrailing)
            }
            .padding(.vertical, FCLayout.Dashboard.clockPanelVerticalPadding)
            .padding(.horizontal, FCLayout.Dashboard.clockPanelHorizontalPadding)
            .background(FCDesign.cardBackground(cornerRadius: 20))
            .overlay(FCDesign.cardBorder(cornerRadius: 20))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .frame(height: FCLayout.Dashboard.clockPanelHeight)
    }

    private func clockDisplay(for date: Date) -> some View {
        VStack(spacing: 4) {
            Text(projectDisplayName)
                .font(.system(size: FCLayout.Dashboard.clockProjectNameFontSize, weight: .medium, design: .default))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.horizontal, 4)

            Text(Self.clockFormatter.string(from: date))
                .font(.system(size: FCLayout.Dashboard.clockTimeFontSize, weight: .semibold, design: .default))
                .monospacedDigit()

            Text(Self.dateFormatter.string(from: date))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var lowerLeftDiagnostics: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Computer Uptime: \(computerUptimeDisplay)")
            Text("App Uptime: \(appState.uptimeDisplay)")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .monospacedDigit()
        .padding(.leading, 2)
        .padding(.bottom, 2)
    }

    private var futureLinkStatus: some View {
        VStack(alignment: .trailing, spacing: 4) {
            dashboardStatusLine(title: "Deep Space Network", value: "offline", systemImage: "antenna.radiowaves.left.and.right")
            dashboardStatusLine(title: "Mission Control", value: "offline", systemImage: "building.2")
        }
        .font(.caption2)
        .padding(.trailing, 2)
        .padding(.bottom, 2)
    }

    private func dashboardStatusLine(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .foregroundStyle(.secondary)
            Text("[\(value)]")
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 14)
        }
        .monospacedDigit()
    }

    private var projectDisplayName: String {
        let trimmed = appState.settings.projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Flight Control" : trimmed
    }

    private var weatherLocationDisplay: String {
        let trimmed = appState.settings.projectLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Location not set" : trimmed
    }

    private var computerUptimeDisplay: String {
        DurationFormatterService.compact(ProcessInfo.processInfo.systemUptime)
    }

    // MARK: - Placeholder Cards

    private var placeholderCards: some View {
        HStack(alignment: .top, spacing: FCLayout.Spacing.card) {
            equalSummaryCard { weatherCardContent }
            equalSummaryCard { timecodeFeedCardContent }
            equalSummaryCard { cameraFeedCardContent }
            equalSummaryCard { tbdCardContent }
        }
    }

    private var weatherCardContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            summaryHeader(systemImage: "cloud.sun.fill", title: "Weather", state: .unknown)

            Text(weatherLocationDisplay)
                .font(.caption.bold())
                .lineLimit(1)

            HStack(alignment: .top, spacing: 14) {
                weatherMetric(title: "Current", value: "--")
                weatherMetric(title: "Temp", value: "--°")
                weatherMetric(title: "Humidity", value: "--%")
            }

            Text("Forecast placeholder — weather provider integration planned.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    private var timecodeFeedCardContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            summaryHeader(systemImage: "waveform.path.ecg.rectangle", title: "Timecode Feed", state: .unknown)

            Picker("", selection: selectedTimecodeSourceBinding) {
                if appState.settings.timecodeSources.isEmpty {
                    Text("No Sources Defined").tag("")
                } else {
                    Text("None").tag("")
                    ForEach(appState.settings.timecodeSources, id: \.self) { source in
                        Text(source).tag(source)
                    }
                }
            }
            .labelsHidden()
            .frame(maxWidth: .infinity)

            Text(selectedTimecodeSourceBinding.wrappedValue.isEmpty ? "Define sources in Project Preferences." : "Selected source is offline until timecode input is implemented.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
    }

    private var cameraFeedCardContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            summaryHeader(systemImage: "video.fill", title: "Camera Feed", state: .unknown)
            Text("No Camera Source")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .lineLimit(1)
            Text("Placeholder for future camera preview or status feed.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
    }

    private var tbdCardContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            summaryHeader(systemImage: "square.dashed", title: "TBD", state: .unknown)
            Text("Reserved")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .lineLimit(1)
            Text("Placeholder for the next project-specific dashboard module.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
    }

    private func weatherMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var selectedTimecodeSourceBinding: Binding<String> {
        Binding(
            get: { appState.settings.selectedTimecodeSource },
            set: { newValue in
                appState.settings.selectedTimecodeSource = newValue
                appState.applySettings()
            }
        )
    }

    // MARK: - Status Cards

    private var statusCards: some View {
        HStack(alignment: .top, spacing: FCLayout.Spacing.card) {
            equalSummaryCard { deviceInventoryCardContent }
            equalSummaryCard { alertSummaryCardContent }
            equalSummaryCard { configurationHealthCardContent }
            equalSummaryCard { networkInterfacesCardContent }
        }
    }

    private func equalSummaryCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        FCCard {
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity)
        .frame(height: summaryCardHeight)
    }

    private func summaryHeader(systemImage: String, title: String, state: DeviceHealthState) -> some View {
        HStack {
            Image(systemName: systemImage)
                .foregroundStyle(state.color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }

    private var deviceInventoryCardContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            summaryHeader(systemImage: appState.overallHealth.systemImageName, title: "Devices", state: appState.overallHealth)

            HStack(alignment: .firstTextBaseline, spacing: 18) {
                deviceCountColumn(title: "Responsive", value: responsiveDeviceCount)
                deviceCountColumn(title: "Enabled", value: appState.enabledDeviceCount)
                deviceCountColumn(title: "Inventory", value: appState.devices.count)
            }

            Text("Responsive / enabled / total inventory")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    private var alertSummaryCardContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            summaryHeader(systemImage: alertSummaryState.systemImageName, title: "Alerts", state: alertSummaryState)

            HStack(alignment: .firstTextBaseline, spacing: 28) {
                deviceCountColumn(title: "Critical", value: appState.count(for: .critical))
                deviceCountColumn(title: "Warnings", value: appState.count(for: .warning))
            }

            Text(alertSummaryDetail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    private var configurationHealthCardContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            summaryHeader(systemImage: configurationHealthState.systemImageName, title: "Configuration Health", state: configurationHealthState)

            if appState.configurationIssues.isEmpty {
                Text("No Issues")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                Text("Configuration checks passed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(appState.configurationIssues.count)")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(appState.configurationIssues.prefix(2)) { issue in
                        Text(issue.title)
                            .font(.caption)
                            .foregroundStyle(issue.state.color)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 2)

            HStack(spacing: 8) {
                Label(appState.monitoringRunning ? "Monitoring Active" : "Monitoring Paused", systemImage: appState.monitoringRunning ? "play.circle.fill" : "pause.circle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Button(appState.monitoringRunning ? "Pause" : "Start") {
                    appState.toggleMonitoring()
                }
                .controlSize(.mini)
            }
        }
    }

    private var networkInterfacesCardContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "network")
                    .foregroundStyle(FCDesign.ColorToken.good)
                Text("Network Interfaces")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(appState.networkInterfaces.count)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            if appState.networkInterfaces.isEmpty {
                Text("No active local interfaces detected.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxHeight: .infinity, alignment: .center)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 2), alignment: .leading, spacing: 6) {
                    ForEach(appState.networkInterfaces.prefix(8)) { interface in
                        nicMiniBlock(interface)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)

                if appState.networkInterfaces.count > 8 {
                    Text("+ \(appState.networkInterfaces.count - 8) more")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func nicMiniBlock(_ interface: NetworkInterfaceInfo) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Circle()
                    .fill(FCDesign.ColorToken.good)
                    .frame(width: 6, height: 6)
                Text(interface.dashboardDisplayName)
                    .font(.caption2.bold())
                    .lineLimit(1)
            }
            Text(interface.detailDisplay.replacingOccurrences(of: "Up · ", with: ""))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FCDesign.ColorToken.quietSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func deviceCountColumn(title: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 58, alignment: .leading)
    }

    private var responsiveDeviceCount: Int {
        appState.devices.filter { device in
            device.enabled && device.healthState == .healthy
        }.count
    }

    private var alertSummaryState: DeviceHealthState {
        if appState.count(for: .critical) > 0 { return .critical }
        if appState.count(for: .warning) > 0 { return .warning }
        return .healthy
    }

    private var alertSummaryDetail: String {
        if appState.count(for: .critical) > 0 { return "Immediate attention required" }
        if appState.count(for: .warning) > 0 { return "Warning conditions active" }
        return "No active alerts"
    }

    private var configurationHealthState: DeviceHealthState {
        appState.configurationIssues.isEmpty ? .healthy : .warning
    }

    // MARK: - Main Dashboard Grid

    private var mainGrid: some View {
        HStack(alignment: .top, spacing: FCLayout.Spacing.section) {
            deviceStatusList.frame(maxWidth: .infinity)
            recentAlerts.frame(width: 380)
        }
    }

    private var deviceStatusList: some View {
        FCCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Device Status").font(.headline)
                    Spacer()
                    Button("Check Now") { appState.forceCheckNow() }
                    Button("Inventory") { openWindow(id: "inventory-window") }
                }
                ForEach(appState.devices.sorted { lhs, rhs in
                    if lhs.healthState != rhs.healthState { return lhs.healthState < rhs.healthState }
                    return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
                }) { device in
                    DeviceDashboardRow(device: device)
                    Divider()
                }
            }
        }
    }

    private var recentAlerts: some View {
        FCCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Recent Alerts").font(.headline)
                let events = appState.recentEvents().filter(\.isAlert)
                if events.isEmpty {
                    Text("No recent warning or critical events.").foregroundStyle(.secondary)
                } else {
                    ForEach(events.prefix(8)) { event in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(event.deviceName).font(.subheadline.bold())
                            Text("\(event.timeDisplay) · \(event.newState.displayName) · \(event.message)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private static let clockFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d, yyyy"
        return formatter
    }()
}

private struct DeviceDashboardRow: View {
    let device: MonitoredDevice

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: device.healthState.systemImageName)
                .foregroundStyle(device.healthState.color)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(device.displayName).font(.subheadline.bold())
                Text("\(device.addressDisplay) · \(device.grouping.compactDisplay)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(device.healthState.displayName).font(.caption.bold())
                if let latency = device.lastLatencyMilliseconds {
                    Text(String(format: "%.1f ms", latency)).font(.caption).foregroundStyle(.secondary)
                } else if let error = device.lastErrorMessage {
                    Text(error).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                } else {
                    Text("Not checked").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}
