//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                    │
//  │  Flight Control                                             │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: PreferencesView.swift
//  Purpose: Flight Control preferences using LunarKit's shared
//           two-pane preferences shell and shared preference components.
//
//  Created by Chris Werner / Lunar Telephone Company.
//  © 2026 Lunar Telephone Company. All rights reserved.
//
//  This source file is part of Flight Control.
//

import Foundation
import SwiftUI
import LunarKit

struct PreferencesView: View {
    // MARK: - Environment

    @EnvironmentObject private var appState: AppState

    // MARK: - State

    @State private var selectedPane: PreferencePane = .app
    @State private var newTimecodeSourceName: String = ""
    @State private var newCameraFeedName: String = ""

    // MARK: - Body

    var body: some View {
        FCScreen(
            title: "FC - Preferences",
            subtitle: "Configure app behavior, project defaults, network interfaces, and future configuration tools."
        ) {
            LTCPreferencesShell(
                identity: .flightControlPreferences,
                panes: preferencePanes,
                selection: $selectedPane
            ) { pane in
                paneContent(for: pane.id)
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: LTCDesign.Spacing.cornerRadius, style: .continuous)
                    .fill(LTCDesign.ColorToken.elevatedCardBackground.opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: LTCDesign.Spacing.cornerRadius, style: .continuous)
                    .strokeBorder(LTCDesign.ColorToken.border, lineWidth: 1)
            )
            .onAppear {
                appState.refreshNetworkInterfaces()
                appState.applySettings()
            }
            .onDisappear {
                appState.applySettings()
            }
            .onChange(of: appState.settings.launchAtLogin) { _, _ in
                appState.applySettings()
            }
            .onChange(of: appState.settings.preventSleep) { _, _ in
                appState.applySettings()
            }
            .onChange(of: appState.settings.monitoringEnabled) { _, _ in
                appState.applySettings()
            }
        }
    }

    // MARK: - LunarKit Pane Bridge

    private var preferencePanes: [LTCPreferencesPane<PreferencePane>] {
        PreferencePane.allCases.map {
            LTCPreferencesPane(
                id: $0,
                title: $0.title,
                subtitle: $0.subtitle,
                systemImage: $0.systemImage,
                sidebarTitle: $0.sidebarTitle,
                detailTitle: $0.title
            )
        }
    }

    @ViewBuilder
    private func paneContent(for pane: PreferencePane) -> some View {
        switch pane {
        case .app:
            appPane
        case .project:
            projectPane
        case .network:
            networkPane
        case .importExport:
            importExportPane
        case .restore:
            restorePane
        }
    }

    // MARK: - App Pane

    private var appPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            LTCPreferenceCard(
                title: "Time Preferences",
                subtitle: "Clock and timestamp display settings.",
                systemImage: "clock"
            ) {
                rowStack {
                    LTCPreferenceRow(
                        title: "Time Format",
                        description: "Used by clocks, timestamps, and date-sensitive dashboard text."
                    ) {
                        LTCTimeFormatPicker(selection: timeFormatBinding)
                    }
                }
            }

            LTCPreferenceCard(
                title: "Runtime Preferences",
                subtitle: "Local launch, sleep, startup, and logging behavior.",
                systemImage: "power"
            ) {
                rowStack {
                    LTCPreferenceRow(
                        title: "Launch at Startup",
                        description: "Open Flight Control automatically after login when supported by this build."
                    ) {
                        Toggle("", isOn: $appState.settings.launchAtLogin)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }

                    LTCPreferenceRow(
                        title: "Prevent System Sleep",
                        description: appState.settings.preventSleep ? "Request idle sleep prevention while monitoring is enabled." : "Allow macOS sleep settings to apply normally."
                    ) {
                        Toggle("", isOn: $appState.settings.preventSleep)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }

                    LTCPreferenceRow(
                        title: "Show Startup Panel",
                        description: "Show a brief status panel when Flight Control launches."
                    ) {
                        Toggle("", isOn: $appState.settings.showStartupPanel)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }

                    preferenceDivider

                    LTCPreferenceRow(
                        title: "Operational Logging",
                        description: appState.settings.operationalLoggingEnabled ? "Additional operational messages may be retained for troubleshooting." : "Operational logging is off. Status events are still retained."
                    ) {
                        Toggle("", isOn: $appState.settings.operationalLoggingEnabled)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }

                    LTCPreferenceRow(
                        title: "Retention Days",
                        description: "Number of days to retain status history."
                    ) {
                        TextField("30", text: retentionDaysTextBinding)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                    }
                }
            }

            LTCPreferenceCard(
                title: "Monitoring Preferences",
                subtitle: "Global monitoring runtime state.",
                systemImage: "waveform.path.ecg"
            ) {
                rowStack {
                    LTCPreferenceRow(
                        title: "Monitoring Enabled",
                        description: appState.settings.monitoringEnabled ? "Flight Control is actively evaluating due device checks." : "Monitoring is paused. Device state will not update."
                    ) {
                        Toggle("", isOn: $appState.settings.monitoringEnabled)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                }
            }

            if let error = visibleRuntimePreferenceError {
                LTCAlertBanner(
                    title: "Runtime Preference Error",
                    message: error,
                    level: .warning
                )
            }
        }
    }

    // MARK: - Project Pane

    private var projectPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            projectInformationCard

            LTCPreferenceCard(
                title: "Monitoring Defaults",
                subtitle: "Default values used by newly-added devices and devices set to Default.",
                systemImage: "timer"
            ) {
                rowStack {
                    LTCPreferenceRow(
                        title: "Default Check Interval",
                        description: "Used when a device's interval is set to Default."
                    ) {
                        Picker("", selection: $appState.settings.defaultCheckIntervalSeconds) {
                            ForEach(CheckIntervalOption.standardOptions) { option in
                                Text(option.displayName).tag(option.seconds)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 120)
                    }

                    LTCPreferenceRow(
                        title: "Minimum Check Interval",
                        description: "Safety clamp that prevents accidentally aggressive polling."
                    ) {
                        secondsField(value: $appState.settings.minimumCheckIntervalSeconds, placeholder: "5")
                    }

                    LTCPreferenceRow(
                        title: "Ping Timeout",
                        description: "Maximum wait time before one ping probe is considered failed."
                    ) {
                        secondsField(value: $appState.settings.pingTimeoutSeconds, placeholder: "2")
                    }

                    LTCPreferenceRow(
                        title: "Ping Concurrency Limit",
                        description: "Maximum number of ping checks that should run at the same time."
                    ) {
                        intField(value: $appState.settings.pingConcurrencyLimit, placeholder: "24")
                    }

                    preferenceDivider

                    LTCPreferenceRow(
                        title: "Warning Miss Count",
                        description: "Consecutive failed checks before a device becomes Warning."
                    ) {
                        intField(value: $appState.settings.defaultWarningMissCount, placeholder: "1")
                    }

                    LTCPreferenceRow(
                        title: "Critical Miss Count",
                        description: "Consecutive failed checks before a device becomes Critical."
                    ) {
                        intField(value: $appState.settings.defaultCriticalMissCount, placeholder: "3")
                    }

                    LTCPreferenceRow(
                        title: "Show In-App Critical Popups",
                        description: appState.settings.showInAppCriticalPopups ? "Critical state transitions may open an acknowledgement alert." : "Critical state transitions will only appear in the dashboard."
                    ) {
                        Toggle("", isOn: $appState.settings.showInAppCriticalPopups)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                }
            }

            LTCPreferenceCard(
                title: "Timecode Sources",
                subtitle: "Source definitions for the Dashboard timecode placeholder. Inputs are not active yet.",
                systemImage: "waveform.path.ecg.rectangle"
            ) {
                rowStack {
                    LTCPreferenceRow(
                        title: "Selected Source",
                        description: "The Dashboard Timecode Feed panel will display this source."
                    ) {
                        Picker("", selection: $appState.settings.selectedTimecodeSource) {
                            Text("None").tag("")
                            ForEach(appState.settings.timecodeSources, id: \.self) { source in
                                Text(source).tag(source)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 220)
                    }

                    preferenceDivider

                    HStack(spacing: 8) {
                        TextField("New timecode source", text: $newTimecodeSourceName)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { addTimecodeSource() }

                        Button { addTimecodeSource() } label: {
                            Label("Add", systemImage: "plus")
                        }
                        .disabled(newTimecodeSourceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.vertical, 7)

                    sourceList(
                        values: appState.settings.timecodeSources,
                        emptyMessage: "No timecode sources defined yet.",
                        symbol: "clock.badge",
                        removeAction: removeTimecodeSource
                    )
                }
            }

            LTCPreferenceCard(
                title: "Camera Feeds",
                subtitle: "Placeholder names for the Dashboard camera-feed panel. Video preview is not active yet.",
                systemImage: "video.fill"
            ) {
                rowStack {
                    HStack(spacing: 8) {
                        TextField("New camera feed", text: $newCameraFeedName)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { addCameraFeed() }

                        Button { addCameraFeed() } label: {
                            Label("Add", systemImage: "plus")
                        }
                        .disabled(newCameraFeedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.vertical, 7)

                    sourceList(
                        values: appState.settings.cameraFeedNames,
                        emptyMessage: "No camera feeds defined yet. Dashboard placeholders will use Camera 1, Camera 2, and Camera 3.",
                        symbol: "video.fill",
                        removeAction: removeCameraFeed
                    )
                }
            }

            LTCPreferenceCard(
                title: "Future Systems",
                subtitle: "Visible placeholders for planned Flight Control architecture.",
                systemImage: "dot.radiowaves.left.and.right"
            ) {
                rowStack {
                    LTCPreferenceRow(
                        title: "Deep Space Network Placeholder",
                        description: "Reserved for future reporting to Mission Control. No transmission occurs yet."
                    ) {
                        Toggle("", isOn: $appState.settings.deepSpaceNetworkEnabled)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }

                    LTCPreferenceRow(
                        title: "Mission Control Endpoint",
                        description: "Future DSN endpoint. This value is stored but unused."
                    ) {
                        TextField("Mission Control endpoint", text: $appState.settings.missionControlEndpoint)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 260)
                    }

                    LTCPreferenceRow(
                        title: "Timecode Integration Placeholder",
                        description: "Reserved for future LTC/MTC/SMPTE-related status correlation."
                    ) {
                        Toggle("", isOn: $appState.settings.timecodeIntegrationEnabled)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                }
            }
        }
    }

private var projectInformationCard: some View {
        LTCPreferenceCard(
            title: "Project Information",
            subtitle: "Basic identity and location fields.",
            systemImage: "folder.fill"
        ) {
            rowStack {
                LTCPreferenceRow(
                    title: "Project Name",
                    description: "Shown on dashboards and startup panels."
                ) {
                    TextField("Project name", text: $appState.settings.projectName)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 300)
                }

                LTCPreferenceRow(
                    title: "Project Location",
                    description: "Friendly label, such as Los Angeles, CA."
                ) {
                    TextField("City, State or venue", text: $appState.settings.projectLocation)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 300)
                }

                LTCPreferenceRow(
                    title: "Weather Source",
                    description: "ZIP, METAR station, or coordinates."
                ) {
                    TextField("ZIP, METAR, or coordinates", text: $appState.settings.projectWeatherSource)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 300)
                }

                LTCPreferenceRow(
                    title: "Project Notes",
                    description: "Optional local project notes."
                ) {
                    TextField("Project notes", text: $appState.settings.projectNotes, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...5)
                        .frame(width: 300)
                }
            }
        }
    }

    // MARK: - Network Pane

    private var networkPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            LTCPreferenceCard(
                title: "Network Interfaces",
                subtitle: "Interface inventory and monitoring interface behavior.",
                systemImage: "network"
            ) {
                rowStack {
                    LTCPreferenceRow(
                        title: "Interface Mode",
                        description: "Any Active Interface is recommended until per-protocol routing rules are added."
                    ) {
                        Picker("", selection: $appState.settings.interfaceMode) {
                            ForEach(InterfaceMonitoringMode.allCases) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 210)
                    }

                    LTCPreferenceRow(
                        title: "Selected Interface",
                        description: "Used only with Selected Interface mode."
                    ) {
                        Picker("", selection: selectedInterfaceBinding) {
                            Text("None").tag("")
                            ForEach(appState.networkInterfaces) { interface in
                                Text("\(interface.displayName) — \(interface.detailDisplay)").tag(interface.name)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 280)
                    }

                    HStack {
                        Spacer()
                        Button("Refresh Interfaces") { appState.refreshNetworkInterfaces() }
                    }
                    .padding(.vertical, 6)

                    preferenceDivider

                    LTCNetworkInterfaceGrid(interfaces: ltcNetworkInterfaces, maxVisible: 12)
                        .padding(.top, 4)
                }
            }
        }
    }

    private func networkInterfaceRow(_ interface: NetworkInterfaceInfo) -> some View {
        HStack(spacing: 10) {
            Image(systemName: interface.isUp ? "checkmark.circle.fill" : "xmark.circle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(interface.isUp ? LTCDesign.ColorToken.healthy : .secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(interface.displayName)
                    .font(.system(size: 13, weight: .semibold))
                Text(interface.detailDisplay)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Import / Export Pane

    private var importExportPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            LTCAlertBanner(
                title: "Import / Export In Progress",
                message: "Flight Control will use this shared LunarKit tool pattern for JSON project export, JSON project import, and future CSV device inventory import. The controls are visible now but intentionally disabled until the data-transfer workflow is implemented.",
                level: .info
            )

            LTCConfigurationToolShell(
                title: "Configuration Transfer",
                subtitle: "Shared import/export tool structure for project configuration files.",
                systemImage: "square.and.arrow.up.on.square"
            ) {
                LTCConfigurationToolActionRow(
                    title: "Export Configuration",
                    description: "Future tool for saving the current Flight Control project configuration as a portable file.",
                    systemImage: "square.and.arrow.up",
                    buttonTitle: "Export…",
                    level: .info,
                    isEnabled: false
                ) { }

                Divider().overlay(LTCDesign.ColorToken.divider)

                LTCConfigurationToolActionRow(
                    title: "Import and Merge",
                    description: "Future tool for importing compatible devices, groups, rules, and dashboard layout without replacing the whole project.",
                    systemImage: "square.and.arrow.down",
                    buttonTitle: "Import…",
                    level: .info,
                    isEnabled: false
                ) { }

                LTCConfigurationToolActionRow(
                    title: "Import and Replace",
                    description: "Future protected tool for replacing the current project configuration after validation and confirmation.",
                    systemImage: "arrow.triangle.2.circlepath",
                    buttonTitle: "Replace…",
                    level: .warning,
                    isEnabled: false
                ) { }

                LTCConfigurationSummaryRow(title: "Current Status", value: "Reserved", level: .inactive)
                LTCConfigurationSummaryRow(title: "Planned Format", value: "JSON", level: .info)
                LTCConfigurationSummaryRow(title: "Future Inventory Import", value: "CSV", level: .info)
            }
        }
    }

    // MARK: - Restore Pane

    private var restorePane: some View {
        VStack(alignment: .leading, spacing: 16) {
            LTCPreferenceActionRow(
                title: "Save Current Configuration",
                description: "Immediately writes the current Flight Control configuration to local persistence.",
                systemImage: "externaldrive.fill",
                buttonTitle: "Save Now",
                level: .info
            ) {
                appState.saveNow()
            }

            LTCRestoreDefaultsTool(
                restoreAppDefaults: {},
                restoreProjectDefaults: {},
                restoreAllDefaults: {}
            ) {
                LTCConfigurationToolActionRow(
                    title: "Delete Devices and Groups",
                    description: "Future destructive reset for inventory data. This will require confirmation before activation.",
                    systemImage: "trash.fill",
                    buttonTitle: "Delete…",
                    level: .critical,
                    isEnabled: false
                ) { }

                Divider().overlay(LTCDesign.ColorToken.divider)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Configuration File")
                        .font(LTCDesign.FontToken.rowTitle)
                        .foregroundStyle(LTCDesign.ColorToken.primaryText)

                    Text(PersistenceService.snapshotURL.path)
                        .font(.caption.monospaced())
                        .foregroundStyle(LTCDesign.ColorToken.secondaryText)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .textSelection(.enabled)

                    if let error = appState.lastPersistenceError {
                        LTCAlertBanner(title: "Persistence Error", message: error, level: .warning)
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Shared Controls

    private func rowStack<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statusRow(title: String, value: String, description: String) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(LTCDesign.ColorToken.primaryText)
                Text(description)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(LTCDesign.ColorToken.secondaryText)
                    .lineLimit(2)
            }
            Spacer(minLength: 16)
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(LTCDesign.ColorToken.secondaryText)
        }
        .padding(.vertical, 5)
    }

    private var preferenceDivider: some View {
        Rectangle()
            .fill(LTCDesign.ColorToken.divider)
            .frame(height: 1)
            .padding(.vertical, 6)
    }

    private func preferenceNotice(title: String, message: String, symbol: String, accent: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(LTCDesign.ColorToken.primaryText)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(LTCDesign.ColorToken.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: LTCDesign.Spacing.smallCornerRadius, style: .continuous)
                .fill(LTCDesign.ColorToken.elevatedCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LTCDesign.Spacing.smallCornerRadius, style: .continuous)
                .strokeBorder(LTCDesign.ColorToken.border, lineWidth: 1)
        )
    }

    private func sourceList(values: [String], emptyMessage: String, symbol: String, removeAction: @escaping (String) -> Void) -> some View {
        Group {
            if values.isEmpty {
                Text(emptyMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(values, id: \.self) { value in
                        HStack(spacing: 8) {
                            Image(systemName: symbol)
                                .foregroundStyle(LTCDesign.ColorToken.accent)
                                .frame(width: 18)
                            Text(value)
                                .font(.subheadline)
                            Spacer()
                            Button(role: .destructive) {
                                removeAction(value)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(LTCDesign.ColorToken.elevatedCardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: LTCDesign.Spacing.smallCornerRadius, style: .continuous))
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private func intField(value: Binding<Int>, placeholder: String) -> some View {
        TextField(placeholder, value: value, format: .number.grouping(.never))
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.trailing)
            .frame(width: 72)
    }

    private func secondsField(value: Binding<TimeInterval>, placeholder: String) -> some View {
        HStack(spacing: 6) {
            TextField(placeholder, value: value, format: .number.precision(.fractionLength(0...2)))
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 72)
            Text("sec")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func addTimecodeSource() {
        let value = newTimecodeSourceName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }

        if !appState.settings.timecodeSources.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) {
            appState.settings.timecodeSources.append(value)
            appState.settings.timecodeSources.sort { $0.localizedStandardCompare($1) == .orderedAscending }
        }

        appState.settings.selectedTimecodeSource = value
        newTimecodeSourceName = ""
        appState.applySettings()
    }

    private func removeTimecodeSource(_ source: String) {
        appState.settings.timecodeSources.removeAll { $0.caseInsensitiveCompare(source) == .orderedSame }
        if appState.settings.selectedTimecodeSource.caseInsensitiveCompare(source) == .orderedSame {
            appState.settings.selectedTimecodeSource = ""
        }
        appState.applySettings()
    }

    private func addCameraFeed() {
        let value = newCameraFeedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }

        if !appState.settings.cameraFeedNames.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) {
            appState.settings.cameraFeedNames.append(value)
            appState.settings.cameraFeedNames.sort { $0.localizedStandardCompare($1) == .orderedAscending }
        }

        newCameraFeedName = ""
        appState.applySettings()
    }

    private func removeCameraFeed(_ camera: String) {
        appState.settings.cameraFeedNames.removeAll { $0.caseInsensitiveCompare(camera) == .orderedSame }
        appState.applySettings()
    }

    private var timeFormatBinding: Binding<LTCTimeFormat> {
        Binding(
            get: { LTCTimeFormat(rawValue: appState.settings.timeFormatRawValue) ?? .twentyFourHour },
            set: { newValue in
                appState.settings.timeFormatRawValue = newValue.rawValue
                appState.applySettings()
            }
        )
    }

    private var retentionDaysTextBinding: Binding<String> {
        Binding(
            get: { String(appState.settings.retentionDays) },
            set: { newValue in
                let filtered = newValue.filter { $0.isNumber }
                if let value = Int(filtered) {
                    appState.settings.retentionDays = min(max(1, value), 365)
                } else if newValue.isEmpty {
                    appState.settings.retentionDays = 30
                }
            }
        )
    }

    private var visibleRuntimePreferenceError: String? {
        guard let error = appState.lastRuntimePreferenceError?.trimmingCharacters(in: .whitespacesAndNewlines), !error.isEmpty else { return nil }

        let lowercased = error.lowercased()
        if lowercased.contains("operation not permitted") || lowercased.contains("not find an app bundle") {
            return nil
        }

        return error
    }

    private var ltcNetworkInterfaces: [LTCNetworkInterfaceDisplayInfo] {
        var mapped = appState.networkInterfaces.map { interface in
            LTCNetworkInterfaceDisplayInfo(
                friendlyName: interface.displayName,
                interfaceID: interface.name,
                isActive: interface.isUp,
                ipv4Address: interface.ipv4Addresses.first,
                cidrPrefix: interface.primaryCIDRPrefix.flatMap { Int($0.replacingOccurrences(of: "/", with: "")) },
                detailLines: interface.detailDisplay.components(separatedBy: "\n")
            )
        }

        if !mapped.contains(where: { $0.interfaceID == "lo0" }) {
            mapped.insert(
                LTCNetworkInterfaceDisplayInfo(
                    friendlyName: "Local Loopback",
                    interfaceID: "lo0",
                    isActive: true,
                    ipv4Address: "127.0.0.1",
                    cidrPrefix: 8,
                    detailLines: ["IPv4: 127.0.0.1 /8", "Purpose: Local host loopback"]
                ),
                at: 0
            )
        }

        return mapped
    }

    private var selectedInterfaceBinding: Binding<String> {
        Binding(
            get: { appState.settings.selectedInterfaceIdentifier ?? "" },
            set: { appState.settings.selectedInterfaceIdentifier = $0.isEmpty ? nil : $0 }
        )
    }
}

// MARK: - Preference Pane Metadata

private enum PreferencePane: String, CaseIterable, Identifiable, Hashable {
    case app
    case project
    case network
    case importExport
    case restore

    var id: String { rawValue }

    var title: String {
        switch self {
        case .app: return "App Preferences"
        case .project: return "Project Preferences"
        case .network: return "Network Preferences"
        case .importExport: return "Import / Export"
        case .restore: return "Restore"
        }
    }

    var sidebarTitle: String {
        switch self {
        case .app: return "App"
        case .project: return "Project"
        case .network: return "Network"
        case .importExport: return "Import / Export"
        case .restore: return "Restore"
        }
    }

    var subtitle: String {
        switch self {
        case .app:
            return "Runtime behavior, launch settings, and local app operation."
        case .project:
            return "Project monitoring defaults and future system placeholders."
        case .network:
            return "Network interface discovery and monitoring interface behavior."
        case .importExport:
            return "Future configuration transfer and inventory exchange tools."
        case .restore:
            return "Persistence details and future restore/reset utilities."
        }
    }

    var systemImage: String {
        switch self {
        case .app: return "app.badge"
        case .project: return "folder"
        case .network: return "network"
        case .importExport: return "square.and.arrow.up.on.square"
        case .restore: return "arrow.counterclockwise"
        }
    }
}

// MARK: - LunarKit Identity

private extension LTCAppIdentity {
    static let flightControlPreferences = LTCAppIdentity(
        initials: "FC",
        displayName: "Flight Control",
        headerTitle: "FLIGHT CONTROL",
        appIconName: "AppIcon",
        companyIconName: "LTCIcon",
        companyLogoName: "LTCLogo"
    )
}
