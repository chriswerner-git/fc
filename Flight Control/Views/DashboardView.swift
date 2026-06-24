//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                    │
//  │  Flight Control                                             │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: DashboardView.swift
//  Purpose: Primary system health dashboard with clock, environmental placeholders,
//           system status, network interface summary, draggable device layout,
//           saved dashboard dividers, and alerts.
//
//  Created by Chris Werner / Lunar Telephone Company.
//  © 2026 Lunar Telephone Company. All rights reserved.
//
//  This source file is part of Flight Control.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers
import LunarKit

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openWindow) private var openWindow

    @State private var draggingPayload: String?
    @State private var detailDevice: MonitoredDevice?

    private let summaryCardHeight: CGFloat = 152
    private let dashboardSpacing: CGFloat = FCLayout.Spacing.card

    var body: some View {
        FCScreen(title: "Dashboard", subtitle: "Project device health, monitoring status, and recent alerts.", systemImage: "rectangle.grid.2x2.fill") {
            ScrollView {
                VStack(spacing: dashboardSpacing) {
                    clockAndSummary
                        .padding(.top, 0)
                    placeholderCards
                    statusCards
                    mainGrid
                }
                .padding(.vertical, 0)
            }
        }
        .alert(item: $appState.showingCriticalAlert) { event in
            Alert(
                title: Text("Critical Device Alert"),
                message: Text("\(event.deviceName): \(event.message)"),
                dismissButton: .default(Text("Acknowledge"))
            )
        }
        .sheet(item: $detailDevice) { device in
            DeviceDashboardDetailEditor(initialDevice: device)
                .environmentObject(appState)
        }
    }

    // MARK: - Dashboard Clock / Summary

    private var clockAndSummary: some View {
        TimelineView(.periodic(from: Date(), by: 1)) { context in
            LTCDashboardClockPanel(
                projectName: projectDisplayName,
                currentDate: context.date,
                computerUptime: computerUptimeDisplay,
                appUptime: appState.uptimeDisplay,
                aboutButtonTitle: "About FC",
                aboutAction: { openWindow(id: "about-window") }
            ) {
                futureLinkStatus
            }
        }
    }

    private func clockDisplay(for date: Date) -> some View {
        VStack(spacing: 3) {
            Text(projectDisplayName)
                .font(.system(size: FCLayout.Dashboard.clockProjectNameFontSize, weight: .medium, design: .default))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.horizontal, 4)

            Text(Self.clockFormatter.string(from: date))
                .font(.system(size: FCLayout.Dashboard.clockTimeFontSize, weight: .semibold, design: .default))
                .monospacedDigit()

            Text(Self.dateFormatter.string(from: date))
                .font(.caption)
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
        HStack(alignment: .top, spacing: dashboardSpacing) {
            equalSummaryCard { weatherCardContent }
            equalSummaryCard { sunMoonCardContent }
            equalSummaryCard { timecodeFeedCardContent }
            equalSummaryCard { cameraFeedCardContent }
        }
    }

    private var weatherCardContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            summaryHeader(systemImage: "cloud.rain.fill", title: "Weather", state: .unknown)

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "cloud.rain.fill")
                    .font(.system(size: 50, weight: .semibold))
                    .foregroundStyle(FCDesign.ColorToken.active)
                    .frame(width: 60, height: 58, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    Text(weatherLocationDisplay)
                        .font(.caption.bold())
                        .lineLimit(1)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), alignment: .leading, spacing: 6) {
                        weatherMetric(title: "Current", value: "--")
                        weatherMetric(title: "Temp", value: "--°")
                        weatherMetric(title: "Humidity", value: "--%")
                        weatherMetric(title: "Visibility", value: "-- mi")
                        weatherMetric(title: "Dew Point", value: "--°")
                        weatherMetric(title: "Forecast", value: "--")
                    }
                }
            }
        }
    }

    private var sunMoonCardContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            summaryHeader(systemImage: "sun.max.fill", title: "Sun and Moon", state: .unknown)

            HStack(alignment: .top, spacing: 14) {
                ForEach(orderedSunEvents) { event in
                    sunMoonEventBlock(event)
                }
            }

            HStack(alignment: .top, spacing: 14) {
                ForEach(orderedMoonEvents) { event in
                    sunMoonEventBlock(event)
                }
            }
        }
    }

    private func sunMoonEventBlock(_ event: SunMoonDashboardEvent) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: event.systemImage)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(event.tint)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.caption.bold())
                Text(Self.shortTimeFormatter.string(from: event.date))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                Text(event.relativeText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var orderedSunEvents: [SunMoonDashboardEvent] {
        orderedDailyEvents([
            dailyEvent(title: "Sunrise", hour: 6, minute: 12, systemImage: "sunrise.fill", tint: FCDesign.ColorToken.warning),
            dailyEvent(title: "Sunset", hour: 19, minute: 54, systemImage: "sunset.fill", tint: FCDesign.ColorToken.warning)
        ])
    }

    private var orderedMoonEvents: [SunMoonDashboardEvent] {
        orderedDailyEvents([
            dailyEvent(title: "Moonrise", hour: 21, minute: 36, systemImage: moonPhaseSystemImage, tint: .secondary, detail: "Waxing"),
            dailyEvent(title: "Moonset", hour: 7, minute: 22, systemImage: "moon.zzz.fill", tint: .secondary, detail: "Phase: Waxing")
        ])
    }

    private var moonPhaseSystemImage: String { "moonphase.waxing.crescent" }

    private func orderedDailyEvents(_ events: [SunMoonDashboardEvent]) -> [SunMoonDashboardEvent] {
        events.sorted { abs($0.date.timeIntervalSinceNow) < abs($1.date.timeIntervalSinceNow) }
    }

    private func dailyEvent(title: String, hour: Int, minute: Int, systemImage: String, tint: Color, detail: String? = nil) -> SunMoonDashboardEvent {
        let now = Date()
        let calendar = Calendar.current
        let today = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) ?? now
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today

        let candidates = [yesterday, today, tomorrow]
        let preferred = candidates
            .filter { candidate in
                let age = now.timeIntervalSince(candidate)
                return age < 0 || age <= 6 * 3600
            }
            .min { abs($0.timeIntervalSince(now)) < abs($1.timeIntervalSince(now)) } ?? tomorrow

        return SunMoonDashboardEvent(
            title: title,
            date: preferred,
            relativeText: relativeEventText(for: preferred),
            systemImage: systemImage,
            tint: tint,
            detail: detail
        )
    }

    private func relativeEventText(for date: Date) -> String {
        let interval = date.timeIntervalSinceNow
        let minutes = max(1, Int((abs(interval) / 60.0).rounded(.down)))
        if interval >= 0 { return "in \(minutes)m" }
        return "\(minutes)m ago"
    }

    private var timecodeFeedCardContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                summaryHeader(systemImage: "waveform.path.ecg.rectangle", title: "Timecode", state: timecodeHealthState)
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
                .frame(width: 170)
                .controlSize(.small)
            }

            Spacer(minLength: 2)

            Text(simulatedTimecodeDisplay)
                .font(.system(size: 34, weight: .semibold, design: .monospaced))
                .foregroundStyle(timecodeTextColor)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, alignment: .center)

            HStack(spacing: 8) {
                Label("29.97df", systemImage: "speedometer")
                Spacer(minLength: 0)
                Text(selectedTimecodeSourceBinding.wrappedValue.isEmpty ? "lost / offline" : "selected / offline")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var simulatedTimecodeDisplay: String {
        // Colons indicate non-drop timecode; semicolons indicate drop-frame timecode.
        // This placeholder is drop-frame because the simulated source is labeled 29.97df.
        "00;00;00;00"
    }

    private var timecodeHealthState: DeviceHealthState {
        selectedTimecodeSourceBinding.wrappedValue.isEmpty ? .critical : .unknown
    }

    private var timecodeTextColor: Color {
        // Future live integration should map active/running to green, post-roll/stale to yellow,
        // and lost/not-running to red. The placeholder is intentionally lost/offline.
        selectedTimecodeSourceBinding.wrappedValue.isEmpty ? FCDesign.ColorToken.critical : FCDesign.ColorToken.warning
    }

    private var cameraFeedCardContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            summaryHeader(systemImage: "video.fill", title: "Camera Feeds", state: .unknown)

            HStack(spacing: 8) {
                let feeds = dashboardCameraFeedNames
                ForEach(feeds.indices, id: \.self) { index in
                    cameraPlaceholder(name: feeds[index])
                }
            }

            Text(appState.settings.cameraFeedNames.isEmpty ? "Define camera feeds in Project Preferences." : "Camera preview integration planned.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    private var dashboardCameraFeedNames: [String] {
        let configured = appState.settings.cameraFeedNames.prefix(3)
        if configured.isEmpty { return ["Camera 1", "Camera 2", "Camera 3"] }
        return Array(configured)
    }

    private func cameraPlaceholder(name: String) -> some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(FCDesign.ColorToken.quietSurface)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(FCDesign.ColorToken.standardBorder, lineWidth: 1)
                )

            Image(systemName: "video.slash")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Text(name)
                .font(.caption2.bold())
                .lineLimit(1)
                .padding(5)
        }
        .frame(maxWidth: .infinity)
    }

    private func weatherMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
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
        HStack(alignment: .top, spacing: dashboardSpacing) {
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
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 2), alignment: .leading, spacing: 5) {
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
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Circle()
                    .fill(FCDesign.ColorToken.good)
                    .frame(width: 6, height: 6)
                Text(interface.dashboardDisplayName)
                    .font(.caption2.bold())
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Text(interface.dashboardAddressDisplay)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FCDesign.ColorToken.quietSurface)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .help(interface.detailDisplay)
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
        GeometryReader { proxy in
            let columnWidth = max((proxy.size.width - (dashboardSpacing * 3)) / 4, 220)
            HStack(alignment: .top, spacing: dashboardSpacing) {
                deviceStatusGrid
                    .frame(width: (columnWidth * 3) + (dashboardSpacing * 2))
                recentAlerts
                    .frame(width: columnWidth)
            }
        }
        .frame(minHeight: 360)
    }

    private var deviceStatusGrid: some View {
        FCCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Device Status").font(.headline)
                        Text("Drag blocks to arrange. Use dividers to separate rows. Double-click a block for details and confirmed edits.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        appState.addDashboardDivider()
                    } label: {
                        Label("Divider", systemImage: "plus.rectangle.on.rectangle")
                    }
                    .controlSize(.small)
                    Button("Check Now") { appState.forceCheckNow() }
                    Button("Inventory") { openWindow(id: "inventory-window") }
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(dashboardRows) { row in
                            switch row.kind {
                            case .divider:
                                if let divider = row.divider {
                                    DashboardDividerRow(
                                        divider: divider,
                                        title: dividerTitleBinding(divider.id),
                                        moveUpAction: { appState.moveDashboardDividerUp(divider.id) },
                                        moveDownAction: { appState.moveDashboardDividerDown(divider.id) },
                                        deleteAction: { appState.deleteDashboardDivider(divider.id) }
                                    )
                                    .onDrag {
                                        let payload = dragPayload(kind: .divider, id: divider.id)
                                        draggingPayload = payload
                                        return NSItemProvider(object: payload as NSString)
                                    }
                                    .onDrop(of: [UTType.text], isTargeted: nil) { _ in
                                        guard let anchorItem = row.anchorItem else { return false }
                                        return dropDashboardItem(before: anchorItem)
                                    }
                                }
                            case .devices:
                                deviceGridRow(row.devices)
                            }
                        }

                        if appState.dashboardLayoutItems().isEmpty {
                            Text("No devices configured yet.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, minHeight: 250, alignment: .center)
                        }
                    }
                    .padding(.trailing, 4)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .frame(minHeight: 360)
                .animation(.snappy(duration: 0.18), value: appState.dashboardLayoutItems().map(\.sortIndex))
            }
        }
    }

    @ViewBuilder
    private func deviceGridRow(_ devices: [MonitoredDevice]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 12), alignment: .leading, spacing: 7) {
            ForEach(devices) { device in
                DeviceDashboardBlock(device: device)
                    .onTapGesture(count: 2) {
                        detailDevice = device
                    }
                    .onDrag {
                        let payload = dragPayload(kind: .device, id: device.id)
                        draggingPayload = payload
                        return NSItemProvider(object: payload as NSString)
                    }
                    .onDrop(of: [UTType.text], isTargeted: nil) { _ in
                        dropDashboardItem(before: DashboardLayoutItem(
                            id: device.id,
                            kind: .device,
                            device: device,
                            divider: nil,
                            sortIndex: device.dashboardGridIndex ?? Int.max
                        ))
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var dashboardRows: [DashboardGridRow] {
        var rows: [DashboardGridRow] = []
        var pendingDevices: [MonitoredDevice] = []

        func flushDevices() {
            guard !pendingDevices.isEmpty else { return }
            rows.append(DashboardGridRow(kind: .devices, devices: pendingDevices))
            pendingDevices.removeAll()
        }

        for item in appState.dashboardLayoutItems() {
            switch item.kind {
            case .device:
                if let device = item.device {
                    pendingDevices.append(device)
                }
            case .divider:
                flushDevices()
                rows.append(DashboardGridRow(kind: .divider, divider: item.divider, anchorItem: item))
            }
        }
        flushDevices()
        return rows
    }

    private func dividerTitleBinding(_ id: UUID) -> Binding<String> {
        Binding(
            get: { appState.settings.dashboardDividers.first(where: { $0.id == id })?.title ?? "" },
            set: { appState.updateDashboardDividerTitle(id, title: $0) }
        )
    }

    private func dropDashboardItem(before target: DashboardLayoutItem) -> Bool {
        guard let draggingPayload, let source = parseDragPayload(draggingPayload) else { return false }
        appState.moveDashboardItem(sourceID: source.id, sourceKind: source.kind, before: target.id, targetKind: target.kind)
        self.draggingPayload = nil
        return true
    }

    private func dragPayload(kind: DashboardItemKind, id: UUID) -> String {
        "\(kind.rawValue):\(id.uuidString)"
    }

    private func parseDragPayload(_ payload: String) -> (kind: DashboardItemKind, id: UUID)? {
        let parts = payload.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2,
              let kind = DashboardItemKind(rawValue: parts[0]),
              let id = UUID(uuidString: parts[1]) else { return nil }
        return (kind, id)
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
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 330, alignment: .topLeading)
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

    private static let shortTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

private struct SunMoonDashboardEvent: Identifiable {
    let id = UUID()
    let title: String
    let date: Date
    let relativeText: String
    let systemImage: String
    let tint: Color
    let detail: String?
}

private struct DeviceDashboardBlock: View {
    let device: MonitoredDevice

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: device.healthState.systemImageName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(device.healthState.color)
                .frame(width: 12)

            Text(device.displayName)
                .font(.system(size: 10, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, minHeight: 26)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(device.healthState.color.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(device.healthState.color.opacity(0.28), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .help("\(device.displayName) · \(device.healthState.displayName)")
    }
}

private struct DashboardDividerRow: View {
    let divider: DashboardDivider
    @Binding var title: String
    let moveUpAction: () -> Void
    let moveDownAction: () -> Void
    let deleteAction: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            TextField("Section label", text: $title)
                .textFieldStyle(.plain)
                .font(.caption.bold())
                .lineLimit(1)
                .frame(maxWidth: 180, alignment: .leading)

            Rectangle()
                .fill(FCDesign.ColorToken.standardBorder)
                .frame(height: 1)

            HStack(spacing: 4) {
                Button(action: moveUpAction) {
                    Image(systemName: "chevron.up")
                }
                .help("Move divider up")

                Button(action: moveDownAction) {
                    Image(systemName: "chevron.down")
                }
                .help("Move divider down")

                Button(role: .destructive, action: deleteAction) {
                    Image(systemName: "minus.circle.fill")
                }
                .foregroundStyle(FCDesign.ColorToken.critical)
                .help("Remove this dashboard divider")
            }
            .buttonStyle(.borderless)
            .font(.caption.bold())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
        .background(FCDesign.ColorToken.quietSurface.opacity(0.42))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .help("Dashboard divider: \(divider.displayTitle)")
    }
}

private enum DashboardGridRowKind: Hashable {
    case devices
    case divider
}

private struct DashboardGridRow: Identifiable, Hashable {
    let id = UUID()
    var kind: DashboardGridRowKind
    var devices: [MonitoredDevice] = []
    var divider: DashboardDivider? = nil
    var anchorItem: DashboardLayoutItem? = nil
}

private struct DeviceDashboardDetailEditor: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let initialDevice: MonitoredDevice
    @State private var draft: MonitoredDevice

    init(initialDevice: MonitoredDevice) {
        self.initialDevice = initialDevice
        _draft = State(initialValue: initialDevice)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Device Details")
                        .font(.largeTitle.bold())
                    Text("Review current status and confirm any configuration edits.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Apply Changes") {
                    appState.updateDevice(draft)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }

            statusPanel

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    editorSection(title: "Identity") {
                        editRow("Name") { TextField("Device name", text: $draft.name).textFieldStyle(.roundedBorder) }
                        editRow("Hostname / IP") { TextField("Hostname or IP address", text: $draft.host).textFieldStyle(.roundedBorder) }
                        editRow("MAC Address") { TextField("Optional", text: $draft.macAddress).textFieldStyle(.roundedBorder) }
                        editRow("Enabled") { Toggle("", isOn: $draft.enabled).labelsHidden().toggleStyle(.switch) }
                    }

                    editorSection(title: "Hardware") {
                        editRow("Vendor") { TextField("Optional", text: $draft.vendor).textFieldStyle(.roundedBorder) }
                        editRow("Model") { TextField("Optional", text: $draft.model).textFieldStyle(.roundedBorder) }
                        editRow("Serial Number") { TextField("Optional", text: $draft.serialNumber).textFieldStyle(.roundedBorder) }
                    }

                    editorSection(title: "Monitoring") {
                        editRow("Method") {
                            Picker("", selection: $draft.monitoringMethod) {
                                ForEach(DeviceMonitoringMethod.allCases) { method in
                                    Text(method.isImplemented ? method.displayName : "\(method.displayName) (future)").tag(method)
                                }
                            }
                            .labelsHidden()
                        }
                        editRow("Warning Miss Count") { Stepper("\(draft.warningMissCount)", value: $draft.warningMissCount, in: 1...99) }
                        editRow("Critical Miss Count") { Stepper("\(draft.criticalMissCount)", value: $draft.criticalMissCount, in: max(1, draft.warningMissCount)...99) }
                    }

                    editorSection(title: "Notes") {
                        TextEditor(text: $draft.notes)
                            .frame(minHeight: 90)
                            .scrollContentBackground(.hidden)
                            .background(FCDesign.ColorToken.textBackground.opacity(0.18))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
                .padding(.trailing, 6)
            }
        }
        .padding(22)
        .frame(minWidth: 620, minHeight: 640)
    }

    private var statusPanel: some View {
        HStack(spacing: 14) {
            Image(systemName: initialDevice.healthState.systemImageName)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(initialDevice.healthState.color)
                .frame(width: 42)

            VStack(alignment: .leading, spacing: 4) {
                Text(initialDevice.healthState.displayName)
                    .font(.title3.bold())
                Text(statusSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(FCDesign.cardBackground())
        .overlay(FCDesign.cardBorder())
    }

    private var statusSummary: String {
        if let latency = initialDevice.lastLatencyMilliseconds {
            return "Last latency: \(String(format: "%.1f", latency)) ms"
        }
        if let error = initialDevice.lastErrorMessage, !error.isEmpty {
            return error
        }
        return "No status check has completed yet."
    }

    private func editorSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            VStack(alignment: .leading, spacing: 0) { content() }
                .padding(10)
                .background(FCDesign.ColorToken.quietSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func editRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 145, alignment: .leading)
            content()
        }
        .padding(.vertical, 7)
    }
}
