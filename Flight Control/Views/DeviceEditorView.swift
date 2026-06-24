//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                    │
//  │  Flight Control                                             │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: DeviceEditorView.swift
//  Purpose: Form for editing a single monitored device.
//
//  Created by Chris Werner / Lunar Telephone Company.
//  © 2026 Lunar Telephone Company. All rights reserved.
//
//  This source file is part of Flight Control.
//

import SwiftUI

struct DeviceEditorView: View {
    @EnvironmentObject private var appState: AppState
    @State private var draft: MonitoredDevice
    @State private var pendingTagText: String = ""

    let onSave: (MonitoredDevice) -> Void

    init(device: MonitoredDevice, onSave: @escaping (MonitoredDevice) -> Void) {
        _draft = State(initialValue: device)
        self.onSave = onSave
    }

    private var knownTags: [TagCount] {
        let pairs = appState.devices.flatMap { device in
            device.grouping.tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        }
        let counts = Dictionary(grouping: pairs.filter { !$0.isEmpty }, by: { $0.lowercased() })
            .compactMap { _, values -> TagCount? in
                guard let label = values.sorted(by: { $0.localizedStandardCompare($1) == .orderedAscending }).first else { return nil }
                return TagCount(name: label, count: values.count)
            }
        return counts.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var matchingKnownTags: [TagCount] {
        let needle = pendingTagText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let available = knownTags.filter { tag in
            draft.grouping.tags.contains { $0.caseInsensitiveCompare(tag.name) == .orderedSame } == false
        }
        guard !needle.isEmpty else { return available }
        return available.filter { $0.name.lowercased().contains(needle) }
    }

    var body: some View {
        FCCard {
            VStack(spacing: 10) {
                Form {
                    identitySection
                    hardwareSection
                    groupSection
                    tagsSection
                    notesSection
                    monitoringSection
                    currentStatusSection
                }
                .formStyle(.grouped)
                .onChange(of: draft) { _, updatedDraft in
                    onSave(updatedDraft)
                }

                HStack {
                    Button("Check Now") { appState.forceCheckNow(draft) }
                    Spacer()
                    Text("Changes save automatically.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var identitySection: some View {
        Section("Identity") {
            TextField("Name", text: $draft.name, prompt: Text("Required"))
            TextField("Hostname / IP Address", text: $draft.host, prompt: Text("Required for Ping"))
            TextField("MAC Address", text: $draft.macAddress, prompt: Text("Optional"))
            Toggle("Enabled", isOn: $draft.enabled)
        }
    }

    private var hardwareSection: some View {
        Section("Hardware") {
            TextField("Vendor", text: $draft.vendor, prompt: Text("Optional"))
            TextField("Model", text: $draft.model, prompt: Text("Optional"))
            TextField("Serial Number", text: $draft.serialNumber, prompt: Text("Optional"))
        }
    }

    private var groupSection: some View {
        Section("Group Assignment") {
            Picker("Inventory Group", selection: groupBinding) {
                Text("Ungrouped").tag(Optional<UUID>.none)
                ForEach(appState.flattenedInventoryGroupOptions()) { option in
                    Text(option.menuTitle).tag(Optional(option.id))
                }
            }
        }
    }

    private var tagsSection: some View {
        Section("Tags") {
            if draft.grouping.tags.isEmpty {
                Text("Optional")
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 6)], alignment: .leading, spacing: 6) {
                    ForEach(draft.grouping.tags, id: \.self) { tag in
                        tagChip(tag)
                    }
                }
                .padding(.vertical, 2)
            }

            HStack(spacing: 8) {
                TextField("Add tag", text: $pendingTagText, prompt: Text("Type a new or existing tag"))
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addPendingTag() }

                Button {
                    addPendingTag()
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(pendingTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help("Add Tag")
            }

            if matchingKnownTags.isEmpty == false {
                VStack(alignment: .leading, spacing: 6) {
                    Text(pendingTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Known Tags" : "Matching Tags")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 6)], alignment: .leading, spacing: 6) {
                        ForEach(matchingKnownTags.prefix(18)) { tag in
                            Button {
                                addTag(tag.name)
                            } label: {
                                HStack(spacing: 5) {
                                    Text(tag.name)
                                        .lineLimit(1)
                                    Text("\(tag.count)")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(FCDesign.ColorToken.quietSurface)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .help("Add existing tag")
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            TextField("Responsible Party / Contact Info", text: $draft.grouping.responsibleParty, prompt: Text("Optional"))
            TextEditor(text: $draft.notes)
                .frame(minHeight: 90)
                .overlay(alignment: .topLeading) {
                    if draft.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Optional notes")
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                    }
                }
        }
    }

    private var monitoringSection: some View {
        Section("Monitoring") {
            Picker("Method", selection: $draft.monitoringMethod) {
                ForEach(DeviceMonitoringMethod.allCases) { method in
                    Text(method.isImplemented ? method.displayName : "\(method.displayName) (future)").tag(method)
                }
            }

            Picker("Check Interval", selection: intervalBinding) {
                Text("Default (\(CheckIntervalOption.displayName(for: appState.settings.defaultCheckIntervalSeconds)))").tag(Optional<TimeInterval>.none)
                ForEach(CheckIntervalOption.standardOptions) { option in
                    Text(option.displayName).tag(Optional(option.seconds))
                }
            }

            TextField("Warning Miss Count", value: $draft.warningMissCount, format: .number)
            TextField("Critical Miss Count", value: $draft.criticalMissCount, format: .number)

            Picker("Preferred Interface", selection: preferredInterfaceBinding) {
                Text("Default / Automatic").tag("")
                ForEach(appState.networkInterfaces) { interface in
                    Text("\(interface.displayName) — \(interface.detailDisplay)").tag(interface.name)
                }
            }
        }
    }

    private var currentStatusSection: some View {
        Section("Current Status") {
            LabeledContent("State", value: draft.healthState.displayName)
            LabeledContent("Consecutive Failures", value: "\(draft.consecutiveFailures)")
            LabeledContent("Last Checked", value: draft.lastCheckedAt?.formatted(date: .abbreviated, time: .standard) ?? "Never")
            LabeledContent("Latency", value: draft.lastLatencyMilliseconds.map { String(format: "%.3f ms", $0) } ?? "—")
            LabeledContent("Last Error", value: draft.lastErrorMessage ?? "None")
        }
    }

    private func tagChip(_ tag: String) -> some View {
        HStack(spacing: 5) {
            Text(tag)
                .lineLimit(1)
            Button {
                removeTag(tag)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Remove Tag")
        }
        .font(.caption)
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(FCDesign.ColorToken.active.opacity(0.16))
        .clipShape(Capsule())
    }

    private func addPendingTag() {
        addTag(pendingTagText)
        pendingTagText = ""
    }

    private func addTag(_ rawTag: String) {
        let tag = rawTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard tag.isEmpty == false else { return }
        guard draft.grouping.tags.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) == false else { return }
        draft.grouping.tags.append(tag)
        draft.grouping.tags.sort { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private func removeTag(_ tag: String) {
        draft.grouping.tags.removeAll { $0.caseInsensitiveCompare(tag) == .orderedSame }
    }

    private var groupBinding: Binding<UUID?> {
        Binding(
            get: { draft.primaryGroupID },
            set: { draft.primaryGroupID = $0 }
        )
    }

    private var intervalBinding: Binding<TimeInterval?> {
        Binding(
            get: { draft.checkIntervalSeconds },
            set: { draft.checkIntervalSeconds = $0 }
        )
    }

    private var preferredInterfaceBinding: Binding<String> {
        Binding(
            get: { draft.preferredInterfaceIdentifier ?? "" },
            set: { draft.preferredInterfaceIdentifier = $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        )
    }
}

private struct TagCount: Identifiable, Hashable {
    var name: String
    var count: Int
    var id: String { name.lowercased() }
}
