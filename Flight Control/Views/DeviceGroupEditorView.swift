//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                    │
//  │  Flight Control                                             │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: DeviceGroupEditorView.swift
//  Purpose: Editor for nestable inventory groups used by the Device Inventory window.
//
//  Created by Chris Werner / Lunar Telephone Company.
//  © 2026 Lunar Telephone Company. All rights reserved.
//
//  This source file is part of Flight Control.
//

import SwiftUI

struct DeviceGroupEditorView: View {
    @EnvironmentObject private var appState: AppState
    @State private var draft: DeviceInventoryGroup
    @State private var parentSelection: UUID?

    init(group: DeviceInventoryGroup) {
        _draft = State(initialValue: group)
        _parentSelection = State(initialValue: nil)
    }

    private var knownCategories: [String] {
        let existing = appState.allInventoryGroups()
            .map { $0.category.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let combined = DeviceInventoryGroup.suggestedCategories + existing
        return Array(Set(combined)).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private var groupDevices: [MonitoredDevice] {
        appState.devices
            .filter { $0.primaryGroupID == draft.id }
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    var body: some View {
        FCCard {
            VStack(spacing: 10) {
                Form {
                    Section("Group") {
                        TextField("Category", text: $draft.category, prompt: Text("Optional — Location, Discipline, Scene, Responsible Party, etc."))

                        if !knownCategories.isEmpty {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 6)], alignment: .leading, spacing: 6) {
                                ForEach(knownCategories, id: \.self) { category in
                                    Button {
                                        draft.category = category
                                    } label: {
                                        Text(category)
                                            .lineLimit(1)
                                            .font(.caption)
                                            .padding(.vertical, 4)
                                            .padding(.horizontal, 8)
                                            .background(categoryButtonBackground(category))
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                    .help("Use category")
                                }
                            }
                            .padding(.vertical, 2)
                        }

                        TextField("Name", text: $draft.name, prompt: Text("Required"))

                        Picker("Nest Under", selection: parentBinding) {
                            Text("Top Level").tag(Optional<UUID>.none)
                            ForEach(appState.flattenedInventoryGroupOptions(excluding: draft.id)) { option in
                                Text(option.menuTitle).tag(Optional(option.id))
                            }
                        }
                    }

                    Section("Notes") {
                        TextEditor(text: $draft.notes)
                            .frame(minHeight: 100)
                            .overlay(alignment: .topLeading) {
                                if draft.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text("Optional notes about what belongs in this group")
                                        .foregroundStyle(.tertiary)
                                        .padding(.top, 8)
                                        .padding(.leading, 5)
                                }
                            }
                    }

                    Section("Devices in This Group") {
                        if groupDevices.isEmpty {
                            Text("No devices assigned yet. Drag devices here or select a device and choose this group.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(groupDevices) { device in
                                HStack {
                                    Image(systemName: device.healthState.systemImageName)
                                        .foregroundStyle(device.healthState.color)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(device.displayName)
                                        Text(device.addressDisplay)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button("Select") {
                                        appState.selectedDeviceID = device.id
                                        appState.selectedInventoryGroupID = nil
                                    }
                                }
                            }
                        }
                    }
                }
                .formStyle(.grouped)
                .onChange(of: draft) { _, updatedGroup in
                    appState.updateInventoryGroup(updatedGroup)
                }
                .onChange(of: parentSelection) { _, newParentID in
                    appState.moveInventoryGroup(draft.id, toParent: newParentID)
                }

                HStack {
                    Button("Delete Group", role: .destructive) {
                        appState.deleteInventoryGroup(draft)
                    }
                    Spacer()
                    Text("Changes save automatically.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Add Subgroup") {
                        appState.addInventoryGroup(parentID: draft.id)
                    }
                }
            }
        }
        .onAppear {
            parentSelection = currentParentID(for: draft.id, in: appState.inventoryGroups)
        }
    }

    private func categoryButtonBackground(_ category: String) -> Color {
        draft.category.caseInsensitiveCompare(category) == .orderedSame
            ? FCDesign.ColorToken.active.opacity(0.22)
            : FCDesign.ColorToken.quietSurface
    }

    private var parentBinding: Binding<UUID?> {
        Binding(
            get: { parentSelection },
            set: { parentSelection = $0 }
        )
    }

    private func currentParentID(for groupID: UUID, in groups: [DeviceInventoryGroup], parentID: UUID? = nil) -> UUID? {
        for group in groups {
            if group.id == groupID { return parentID }
            if let match = currentParentID(for: groupID, in: group.children, parentID: group.id) {
                return match
            }
        }
        return nil
    }
}
