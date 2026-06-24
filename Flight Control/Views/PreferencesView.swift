//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                    │
//  │  Flight Control                                             │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: PreferencesView.swift
//  Purpose: LCC/MLog-style two-pane preferences for app runtime,
//           project monitoring defaults, network interface behavior,
//           future import/export, and restore tools.
//
//  Created by Chris Werner / Lunar Telephone Company.
//  © 2026 Lunar Telephone Company. All rights reserved.
//
//  This source file is part of Flight Control.
//

import Foundation
import SwiftUI

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
            HStack(spacing: 0) {
                sidebar

                Divider()
                    .opacity(0.35)

                contentPanel
            }
            .background(
                RoundedRectangle(cornerRadius: FCDesign.Radius.panel, style: .continuous)
                    .fill(FCDesign.ColorToken.controlBackground.opacity(0.32))
            )
            .overlay(
                RoundedRectangle(cornerRadius: FCDesign.Radius.panel, style: .continuous)
                    .strokeBorder(FCDesign.ColorToken.standardBorder, lineWidth: 1)
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

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            sidebarHeader

            VStack(alignment: .leading, spacing: 8) {
                ForEach(PreferencePane.allCases) { pane in
                    sidebarButton(pane)
                }
            }

            Spacer(minLength: 0)

            Text("Changes are saved automatically.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
        .padding(18)
        .frame(width: 238, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    private var sidebarHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(FCDesign.ColorToken.active)

            VStack(alignment: .leading, spacing: 2) {
                Text("Preferences")
                    .font(.title3.bold())
                Text("Settings and future tools.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.bottom, 4)
    }

    private func sidebarButton(_ pane: PreferencePane) -> some View {
        Button {
            selectedPane = pane
        } label: {
            HStack(spacing: 10) {
                Image(systemName: pane.systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 18)

                Text(pane.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(selectedPane == pane ? .primary : .secondary)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(selectedPane == pane ? FCDesign.ColorToken.active.opacity(0.18) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    selectedPane == pane ? FCDesign.ColorToken.active.opacity(0.35) : Color.clear,
                    lineWidth: 1
                )
        )
    }

    // MARK: - Content Panel

    private var contentPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            contentHeader

            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 16) {
                    switch selectedPane {
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
                .padding(.trailing, 6)
                .padding(.bottom, 20)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var contentHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(FCDesign.ColorToken.active.opacity(0.18))
                    .frame(width: 40, height: 40)

                Image(systemName: selectedPane.systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(FCDesign.ColorToken.active)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(selectedPane.title)
                    .font(.largeTitle.bold())

                Text(selectedPane.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - App Pane

    private var appPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            preferenceCard(title: "App Runtime", subtitle: "Controls local application behavior.") {
                preferenceRow(
                    systemImage: "antenna.radiowaves.left.and.right",
                    title: "Monitoring Enabled",
                    subtitle: appState.settings.monitoringEnabled ? "Flight Control is actively evaluating due device checks." : "Monitoring is paused. Device state will not update."
                ) {
                    Toggle("", isOn: $appState.settings.monitoringEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                preferenceDivider

                preferenceRow(
                    systemImage: "power.circle.fill",
                    title: "Launch App at Startup",
                    subtitle: LoginStartupService.status.helpText
                ) {
                    Toggle("", isOn: $appState.settings.launchAtLogin)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                statusRow(
                    systemImage: "checkmark.seal",
                    title: "Launch at Startup Status",
                    value: LoginStartupService.status.displayName,
                    subtitle: "macOS controls whether unsigned development builds can be registered as login items."
                )

                preferenceRow(
                    systemImage: "moon.zzz.fill",
                    title: "Prevent System Sleep While Monitoring",
                    subtitle: appState.settings.preventSleep ? "Flight Control will request an idle sleep assertion while monitoring is enabled." : "The computer may sleep according to macOS Energy settings."
                ) {
                    Toggle("", isOn: $appState.settings.preventSleep)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                preferenceDivider

                preferenceRow(
                    systemImage: "doc.text.magnifyingglass",
                    title: "Operational Logging",
                    subtitle: appState.settings.operationalLoggingEnabled ? "Additional operational messages may be retained for troubleshooting." : "Operational logging is off. Status events are still retained."
                ) {
                    Toggle("", isOn: $appState.settings.operationalLoggingEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                preferenceRow(
                    systemImage: "clock.arrow.circlepath",
                    title: "Status Retention",
                    subtitle: "Default is 30 days. Older status events are pruned during saves."
                ) {
                    HStack(spacing: 6) {
                        TextField("30", value: $appState.settings.retentionDays, format: .number.grouping(.never))
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 72)

                        Text("days")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let error = appState.lastRuntimePreferenceError {
                preferenceNotice(
                    title: "Runtime Preference Error",
                    message: error,
                    symbol: "exclamationmark.triangle.fill",
                    accent: FCDesign.ColorToken.warning
                )
            }
        }
    }

    // MARK: - Project Pane

    private var projectPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            preferenceCard(title: "Project Identity", subtitle: "Shown on the Dashboard clock panel and future reports.") {
                preferenceRow(
                    systemImage: "folder",
                    title: "Project Name",
                    subtitle: "Optional. Leave blank to show Flight Control."
                ) {
                    TextField("Flight Control", text: $appState.settings.projectName)
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 240)
                }

                preferenceRow(
                    systemImage: "mappin.and.ellipse",
                    title: "Project Location",
                    subtitle: "Used by the Dashboard weather placeholder. Weather integration is planned."
                ) {
                    TextField("City, State / Venue / Site", text: $appState.settings.projectLocation)
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 240)
                }
            }

            preferenceCard(title: "Monitoring Defaults", subtitle: "Default values used by newly-added devices and devices set to Default.") {
                preferenceRow(
                    systemImage: "timer",
                    title: "Default Check Interval",
                    subtitle: "Used when a device's interval is set to Default."
                ) {
                    Picker("", selection: $appState.settings.defaultCheckIntervalSeconds) {
                        ForEach(CheckIntervalOption.standardOptions) { option in
                            Text(option.displayName).tag(option.seconds)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 120)
                }

                preferenceRow(
                    systemImage: "speedometer",
                    title: "Minimum Check Interval",
                    subtitle: "Safety clamp that prevents accidentally aggressive polling."
                ) {
                    secondsField(value: $appState.settings.minimumCheckIntervalSeconds, placeholder: "5")
                }

                preferenceRow(
                    systemImage: "hourglass",
                    title: "Ping Timeout",
                    subtitle: "Maximum wait time before one ping probe is considered failed."
                ) {
                    secondsField(value: $appState.settings.pingTimeoutSeconds, placeholder: "2")
                }

                preferenceRow(
                    systemImage: "rectangle.stack.badge.play",
                    title: "Ping Concurrency Limit",
                    subtitle: "Maximum number of ping checks that should run at the same time."
                ) {
                    intField(value: $appState.settings.pingConcurrencyLimit, placeholder: "24")
                }

                preferenceDivider

                preferenceRow(
                    systemImage: "exclamationmark.triangle.fill",
                    title: "Warning Miss Count",
                    subtitle: "Consecutive failed checks before a device becomes Warning."
                ) {
                    intField(value: $appState.settings.defaultWarningMissCount, placeholder: "1")
                }

                preferenceRow(
                    systemImage: "xmark.octagon.fill",
                    title: "Critical Miss Count",
                    subtitle: "Consecutive failed checks before a device becomes Critical."
                ) {
                    intField(value: $appState.settings.defaultCriticalMissCount, placeholder: "3")
                }

                preferenceRow(
                    systemImage: "bell.badge.fill",
                    title: "Show In-App Critical Popups",
                    subtitle: appState.settings.showInAppCriticalPopups ? "Critical state transitions may open an acknowledgement alert." : "Critical state transitions will only appear in the dashboard."
                ) {
                    Toggle("", isOn: $appState.settings.showInAppCriticalPopups)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }

            preferenceCard(title: "Timecode Sources", subtitle: "Source definitions for the Dashboard timecode placeholder. Inputs are not active yet.") {
                preferenceRow(
                    systemImage: "waveform.path.ecg.rectangle",
                    title: "Selected Source",
                    subtitle: "The Dashboard Timecode Feed panel will display this source."
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

                if appState.settings.timecodeSources.isEmpty {
                    Text("No timecode sources defined yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(appState.settings.timecodeSources, id: \.self) { source in
                            HStack(spacing: 8) {
                                Image(systemName: "clock.badge")
                                    .foregroundStyle(FCDesign.ColorToken.active)
                                    .frame(width: 18)
                                Text(source)
                                    .font(.subheadline)
                                Spacer()
                                Button(role: .destructive) {
                                    removeTimecodeSource(source)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(FCDesign.ColorToken.quietSurface)
                            .clipShape(RoundedRectangle(cornerRadius: FCDesign.Radius.chip, style: .continuous))
                        }
                    }
                }
            }

            preferenceCard(title: "Camera Feeds", subtitle: "Placeholder names for the Dashboard camera-feed panel. Video preview is not active yet.") {
                HStack(spacing: 8) {
                    TextField("New camera feed", text: $newCameraFeedName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addCameraFeed() }

                    Button { addCameraFeed() } label: {
                        Label("Add", systemImage: "plus")
                    }
                    .disabled(newCameraFeedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if appState.settings.cameraFeedNames.isEmpty {
                    Text("No camera feeds defined yet. Dashboard placeholders will use Camera 1, Camera 2, and Camera 3.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(appState.settings.cameraFeedNames, id: \.self) { camera in
                            HStack(spacing: 8) {
                                Image(systemName: "video.fill")
                                    .foregroundStyle(FCDesign.ColorToken.active)
                                    .frame(width: 18)
                                Text(camera)
                                    .font(.subheadline)
                                Spacer()
                                Button(role: .destructive) {
                                    removeCameraFeed(camera)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(FCDesign.ColorToken.quietSurface)
                            .clipShape(RoundedRectangle(cornerRadius: FCDesign.Radius.chip, style: .continuous))
                        }
                    }
                }
            }


            preferenceCard(title: "Future Systems", subtitle: "Visible placeholders for planned Flight Control architecture.") {
                preferenceRow(
                    systemImage: "dot.radiowaves.left.and.right",
                    title: "Deep Space Network Placeholder",
                    subtitle: "Reserved for future reporting to Mission Control. No transmission occurs yet."
                ) {
                    Toggle("", isOn: $appState.settings.deepSpaceNetworkEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                preferenceRow(
                    systemImage: "point.3.connected.trianglepath.dotted",
                    title: "Mission Control Endpoint",
                    subtitle: "Future DSN endpoint. This value is stored but unused."
                ) {
                    TextField("Mission Control endpoint", text: $appState.settings.missionControlEndpoint)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 280)
                }

                preferenceRow(
                    systemImage: "waveform.path.ecg.rectangle",
                    title: "Timecode Integration Placeholder",
                    subtitle: "Reserved for future LTC/MTC/SMPTE-related status correlation."
                ) {
                    Toggle("", isOn: $appState.settings.timecodeIntegrationEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }
        }
    }

    // MARK: - Network Pane

    private var networkPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            preferenceCard(title: "Network Interfaces", subtitle: "Interface inventory and monitoring interface behavior.") {
                preferenceRow(
                    systemImage: "network",
                    title: "Interface Mode",
                    subtitle: "Any Active Interface is recommended until per-protocol routing rules are added."
                ) {
                    Picker("", selection: $appState.settings.interfaceMode) {
                        ForEach(InterfaceMonitoringMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 210)
                }

                preferenceRow(
                    systemImage: "cable.connector",
                    title: "Selected Interface",
                    subtitle: "Used only when Interface Mode is set to Selected Interface."
                ) {
                    Picker("", selection: selectedInterfaceBinding) {
                        Text("None").tag("")
                        ForEach(appState.networkInterfaces) { interface in
                            Text("\(interface.displayName) — \(interface.detailDisplay)").tag(interface.name)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 360)
                }

                HStack {
                    Spacer()
                    Button("Refresh Interfaces") { appState.refreshNetworkInterfaces() }
                }

                preferenceDivider

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(appState.networkInterfaces) { interface in
                        networkInterfaceRow(interface)
                    }
                }
            }
        }
    }

    private func networkInterfaceRow(_ interface: NetworkInterfaceInfo) -> some View {
        HStack(spacing: 10) {
            Image(systemName: interface.isUp ? "checkmark.circle.fill" : "xmark.circle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(interface.isUp ? FCDesign.ColorToken.good : .secondary)
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
            preferenceCard(title: "Import / Export", subtitle: "Reserved for future configuration transfer.") {
                preferenceNotice(
                    title: "Reserved for Future Configuration Transfer",
                    message: "Flight Control is not importing or exporting project configurations yet. This pane is intentionally reserved for JSON configuration export, JSON import, and future CSV device inventory import.",
                    symbol: "shippingbox",
                    accent: FCDesign.ColorToken.active
                )

                HStack(spacing: 10) {
                    Button("Export Configuration…") { }
                        .disabled(true)
                    Button("Import Configuration…") { }
                        .disabled(true)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    // MARK: - Restore Pane

    private var restorePane: some View {
        VStack(alignment: .leading, spacing: 16) {
            preferenceCard(title: "Persistence", subtitle: "Current local configuration storage.") {
                preferenceRow(
                    systemImage: "doc.text",
                    title: "Configuration File",
                    subtitle: "Flight Control stores its local project configuration here."
                ) {
                    Text(PersistenceService.snapshotURL.path)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                        .frame(maxWidth: 420, alignment: .trailing)
                }

                if let error = appState.lastPersistenceError {
                    preferenceDivider
                    preferenceNotice(
                        title: "Persistence Error",
                        message: error,
                        symbol: "exclamationmark.triangle.fill",
                        accent: FCDesign.ColorToken.warning
                    )
                }

                HStack(spacing: 10) {
                    Button("Save Now") { appState.saveNow() }
                    Button("Restore Defaults…") { }
                        .disabled(true)
                    Spacer(minLength: 0)
                }
            }

            preferenceCard(title: "Restore Tools", subtitle: "Reserved for safer reset operations.") {
                preferenceNotice(
                    title: "Future Restore / Reset Tools",
                    message: "Restore tools are reserved for a future pass. Planned options include app defaults, project defaults, delete devices, delete groups, and restore from automatic backup — matching the safer reset pattern used by LCC.",
                    symbol: "arrow.counterclockwise",
                    accent: FCDesign.ColorToken.active
                )
            }
        }
    }

    // MARK: - Shared Controls

    private func preferenceCard<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: title, subtitle: subtitle)

            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: FCDesign.Radius.inset, style: .continuous)
                    .fill(FCDesign.ColorToken.textBackground.opacity(0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: FCDesign.Radius.inset, style: .continuous)
                    .strokeBorder(FCDesign.ColorToken.standardBorder, lineWidth: 1)
            )
        }
        .padding(14)
        .background(FCDesign.cardBackground())
        .overlay(FCDesign.cardBorder())
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func preferenceRow<Control: View>(systemImage: String, title: String, subtitle: String, @ViewBuilder control: () -> Control) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(FCDesign.ColorToken.active)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            control()
        }
        .padding(.vertical, 9)
    }

    private func statusRow(systemImage: String, title: String, value: String, subtitle: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 9)
    }

    private var preferenceDivider: some View {
        Rectangle()
            .fill(FCDesign.ColorToken.standardBorder)
            .frame(height: 1)
            .padding(.vertical, 4)
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
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: FCDesign.Radius.inset, style: .continuous)
                .fill(FCDesign.ColorToken.textBackground.opacity(0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: FCDesign.Radius.inset, style: .continuous)
                .strokeBorder(FCDesign.ColorToken.standardBorder, lineWidth: 1)
        )
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

    private var selectedInterfaceBinding: Binding<String> {
        Binding(
            get: { appState.settings.selectedInterfaceIdentifier ?? "" },
            set: { appState.settings.selectedInterfaceIdentifier = $0.isEmpty ? nil : $0 }
        )
    }
}

// MARK: - Preference Pane Metadata

private enum PreferencePane: String, CaseIterable, Identifiable {
    case app
    case project
    case network
    case importExport
    case restore

    var id: String { rawValue }

    var title: String {
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
