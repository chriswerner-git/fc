//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                    │
//  │  Flight Control                                             │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: DeviceInventoryView.swift
//  Purpose: Device inventory browser with nestable groups, compact filtering, tag maintenance, and editor routing.
//
//  Created by Chris Werner / Lunar Telephone Company.
//  © 2026 Lunar Telephone Company. All rights reserved.
//
//  This source file is part of Flight Control.
//

import SwiftUI
import UniformTypeIdentifiers

struct DeviceInventoryView: View {
    @EnvironmentObject private var appState: AppState
    @State private var expandedGroupIDs: Set<UUID> = []
    @State private var isUngroupedExpanded = true
    @State private var listFilterText: String = ""
    @State private var selectedFilterGroupID: UUID? = nil
    @State private var selectedFilterTag: String = ""
    @State private var showingTagMaintenance = false

    private var selectedDevice: MonitoredDevice? {
        guard let id = appState.selectedDeviceID else { return nil }
        return appState.devices.first { $0.id == id }
    }

    private var selectedGroup: DeviceInventoryGroup? {
        appState.selectedInventoryGroup()
    }

    private var knownTags: [TagCount] {
        Self.tagCounts(from: appState.devices)
    }

    private var responsiveCount: Int {
        appState.devices.filter { $0.enabled && $0.healthState == .healthy }.count
    }

    private var enabledCount: Int {
        appState.devices.filter(\.enabled).count
    }

    private var filterGroupIDs: Set<UUID>? {
        guard let selectedFilterGroupID else { return nil }
        guard let group = appState.findInventoryGroup(id: selectedFilterGroupID) else { return [selectedFilterGroupID] }
        var ids: Set<UUID> = []
        collectGroupIDs(group, into: &ids)
        return ids
    }

    private var activeFilter: DeviceInventoryFilter {
        DeviceInventoryFilter(
            searchText: listFilterText,
            groupIDs: filterGroupIDs,
            tag: selectedFilterTag.isEmpty ? nil : selectedFilterTag
        )
    }

    var body: some View {
        FCScreen(title: "FC - Device Inventory", subtitle: "Add devices manually now; discovery tools can plug into this model later.") {
            HStack(spacing: FCLayout.Spacing.section) {
                listPane
                    .frame(width: 340)

                if let selectedDevice {
                    DeviceEditorView(device: selectedDevice) { updated in
                        appState.updateDevice(updated)
                    }
                    .id(selectedDevice.id)
                } else if let selectedGroup {
                    DeviceGroupEditorView(group: selectedGroup)
                        .id(selectedGroup.id)
                } else {
                    FCCard {
                        VStack(spacing: 10) {
                            Image(systemName: "folder.badge.plus")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("Select a device or group.")
                                .font(.headline)
                            Text("Use groups to organize devices by location, discipline, scene, responsible party, system type, or whatever the project needs.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 420)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .sheet(isPresented: $showingTagMaintenance) {
            TagMaintenanceView()
                .environmentObject(appState)
                .frame(minWidth: 560, minHeight: 460)
        }
        .onAppear {
            if expandedGroupIDs.isEmpty {
                expandedGroupIDs = allGroupIDs()
            }
        }
    }

    private var listPane: some View {
        FCCard {
            VStack(alignment: .leading, spacing: 8) {
                headerTools
                inventoryCounts
                filterTools

                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(appState.inventoryGroups) { group in
                            InventoryGroupRow(group: group, level: 0, expandedGroupIDs: $expandedGroupIDs, filter: activeFilter)
                        }

                        UngroupedDevicesSection(isExpanded: $isUngroupedExpanded, filter: activeFilter)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var headerTools: some View {
        VStack(alignment: .leading, spacing: 7) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Inventory")
                    .font(.headline)
                Text("Nest groups, assign devices, and filter large systems.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 6) {
                Button("Collapse All") {
                    expandedGroupIDs.removeAll()
                    isUngroupedExpanded = false
                }
                Button("Expand All") {
                    expandedGroupIDs = allGroupIDs()
                    isUngroupedExpanded = true
                }
                Spacer(minLength: 6)
                Button { showingTagMaintenance = true } label: { Image(systemName: "tag") }
                    .help("Tag Maintenance")
                Button { appState.addInventoryGroup() } label: { Image(systemName: "folder.badge.plus") }
                    .help("Add Group")
                Button { appState.addDevice() } label: { Image(systemName: "plus") }
                    .help("Add Device")
            }
            .font(.caption)
        }
    }

    private var inventoryCounts: some View {
        HStack(spacing: 8) {
            InventoryMiniCount(title: "Responsive", value: responsiveCount, color: FCDesign.ColorToken.good)
            InventoryMiniCount(title: "Enabled", value: enabledCount, color: FCDesign.ColorToken.active)
            InventoryMiniCount(title: "Inventory", value: appState.devices.count, color: .secondary)
        }
    }

    private var filterTools: some View {
        VStack(alignment: .leading, spacing: 5) {
            TextField("Filter devices", text: $listFilterText, prompt: Text("Name, IP, MAC, notes, or tag"))
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 6) {
                Picker("Group", selection: $selectedFilterGroupID) {
                    Text("All Groups").tag(Optional<UUID>.none)
                    ForEach(appState.flattenedInventoryGroupOptions()) { option in
                        Text(option.menuTitle).tag(Optional(option.id))
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)

                Picker("Tag", selection: $selectedFilterTag) {
                    Text("All Tags").tag("")
                    ForEach(knownTags, id: \.name) { tag in
                        Text("\(tag.name) (\(tag.count))").tag(tag.name)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .disabled(knownTags.isEmpty)
            }

            if activeFilter.isActive {
                Button("Clear Filters") {
                    listFilterText = ""
                    selectedFilterGroupID = nil
                    selectedFilterTag = ""
                }
                .font(.caption)
            }
        }
    }

    private func allGroupIDs() -> Set<UUID> {
        var ids: Set<UUID> = []
        for group in appState.inventoryGroups {
            collectGroupIDs(group, into: &ids)
        }
        return ids
    }

    private func collectGroupIDs(_ group: DeviceInventoryGroup, into ids: inout Set<UUID>) {
        ids.insert(group.id)
        for child in group.children {
            collectGroupIDs(child, into: &ids)
        }
    }

    fileprivate static func tagCounts(from devices: [MonitoredDevice]) -> [TagCount] {
        let pairs = devices.flatMap { device in
            device.grouping.tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        }
        let counts = Dictionary(grouping: pairs.filter { !$0.isEmpty }, by: { $0.lowercased() })
            .compactMap { _, values -> TagCount? in
                guard let label = values.sorted(by: { $0.localizedStandardCompare($1) == .orderedAscending }).first else { return nil }
                return TagCount(name: label, count: values.count)
            }
        return counts.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

private struct InventoryMiniCount: View {
    var title: String
    var value: Int
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.title3.monospacedDigit().bold())
                .foregroundStyle(color)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(FCDesign.ColorToken.quietSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct DeviceInventoryFilter: Equatable {
    var searchText: String = ""
    var groupIDs: Set<UUID>? = nil
    var tag: String? = nil

    var isActive: Bool {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false || groupIDs != nil || tag != nil
    }

    func includes(_ device: MonitoredDevice) -> Bool {
        if let groupIDs, groupIDs.contains(device.primaryGroupID ?? UUID()) == false {
            return false
        }

        if let tag, device.grouping.tags.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) == false {
            return false
        }

        let needle = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard needle.isEmpty == false else { return true }

        let haystack = [
            device.name,
            device.host,
            device.macAddress,
            device.vendor,
            device.model,
            device.serialNumber,
            device.grouping.responsibleParty,
            device.notes,
            device.grouping.tags.joined(separator: " ")
        ]
        .joined(separator: " ")
        .lowercased()

        return haystack.contains(needle)
    }
}

private struct InventoryGroupRow: View {
    @EnvironmentObject private var appState: AppState
    let group: DeviceInventoryGroup
    let level: Int
    @Binding var expandedGroupIDs: Set<UUID>
    let filter: DeviceInventoryFilter
    @State private var dropTargeted = false

    private var devicesInGroup: [MonitoredDevice] {
        appState.devices
            .filter { $0.primaryGroupID == group.id }
            .filter { filter.includes($0) }
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    private var visibleChildren: [DeviceInventoryGroup] {
        group.children.filter { childHasVisibleContent($0) }
    }

    private var allDevicesInGroup: [MonitoredDevice] {
        appState.devices.filter { $0.primaryGroupID == group.id }
    }

    private var hasVisibleContent: Bool {
        !filter.isActive || !devicesInGroup.isEmpty || !visibleChildren.isEmpty
    }

    private var isExpandedBinding: Binding<Bool> {
        Binding(
            get: { expandedGroupIDs.contains(group.id) },
            set: { isExpanded in
                if isExpanded { expandedGroupIDs.insert(group.id) }
                else { expandedGroupIDs.remove(group.id) }
            }
        )
    }

    @ViewBuilder
    var body: some View {
        if hasVisibleContent {
            DisclosureGroup(isExpanded: isExpandedBinding) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(devicesInGroup) { device in
                        DeviceInventoryRow(device: device, level: level + 1)
                    }
                    ForEach(visibleChildren) { child in
                        InventoryGroupRow(group: child, level: level + 1, expandedGroupIDs: $expandedGroupIDs, filter: filter)
                    }
                }
                .padding(.leading, 12)
                .padding(.top, 2)
            } label: {
                Button {
                    appState.selectedInventoryGroupID = group.id
                    appState.selectedDeviceID = nil
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "folder.fill")
                            .font(.caption2)
                            .foregroundStyle(appState.selectedInventoryGroupID == group.id ? .primary : .secondary)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(group.displayName)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                            Text(group.categoryDisplay)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 4)
                        Text("\(activeCount)/\(allDevicesInGroup.count)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .help("Responsive / total devices directly in this group")
                    }
                    .padding(.vertical, 2)
                    .padding(.horizontal, 4)
                    .background(appState.selectedInventoryGroupID == group.id ? Color.accentColor.opacity(0.18) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Add Subgroup") { appState.addInventoryGroup(parentID: group.id) }
                    Button("Add Device Here") {
                        appState.selectedInventoryGroupID = group.id
                        appState.addDevice()
                    }
                    Divider()
                    Button("Delete Group", role: .destructive) { appState.deleteInventoryGroup(group) }
                }
                .onDrop(of: [.text], isTargeted: $dropTargeted) { providers in
                    handleDeviceDrop(providers: providers, groupID: group.id)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(dropTargeted ? FCDesign.ColorToken.warning : .clear, lineWidth: 1)
                }
            }
            .padding(.leading, CGFloat(level) * 6)
        }
    }

    private var activeCount: Int {
        allDevicesInGroup.filter { $0.enabled && $0.healthState == .healthy }.count
    }

    private func childHasVisibleContent(_ child: DeviceInventoryGroup) -> Bool {
        let directMatches = appState.devices
            .filter { $0.primaryGroupID == child.id }
            .contains { filter.includes($0) }
        let childMatches = child.children.contains { childHasVisibleContent($0) }
        return !filter.isActive || directMatches || childMatches
    }

    private func handleDeviceDrop(providers: [NSItemProvider], groupID: UUID?) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadObject(ofClass: NSString.self) { item, _ in
            guard let nsString = item as? NSString, let deviceID = UUID(uuidString: nsString as String) else { return }
            Task { @MainActor in
                appState.assignDevice(deviceID, toGroup: groupID)
            }
        }
        return true
    }
}

private struct DeviceInventoryRow: View {
    @EnvironmentObject private var appState: AppState
    let device: MonitoredDevice
    let level: Int

    var body: some View {
        Button {
            appState.selectedDeviceID = device.id
            appState.selectedInventoryGroupID = nil
        } label: {
            HStack(spacing: 5) {
                Image(systemName: device.healthState.systemImageName)
                    .font(.caption2)
                    .foregroundStyle(device.healthState.color)
                VStack(alignment: .leading, spacing: 0) {
                    Text(device.displayName)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text(device.addressDisplay)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                if device.enabled == false {
                    Image(systemName: "pause.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
            .background(appState.selectedDeviceID == device.id ? Color.accentColor.opacity(0.18) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .padding(.leading, CGFloat(level) * 7)
        .onDrag { NSItemProvider(object: device.id.uuidString as NSString) }
        .contextMenu {
            Button("Check Now") { appState.forceCheckNow(device) }
            Button("Duplicate") { appState.duplicateDevice(device) }
            Button("Move to Ungrouped") { appState.assignDevice(device.id, toGroup: nil) }
            Divider()
            Button("Delete", role: .destructive) { appState.deleteDevice(device) }
        }
    }
}

private struct UngroupedDevicesSection: View {
    @EnvironmentObject private var appState: AppState
    @Binding var isExpanded: Bool
    @State private var dropTargeted = false
    let filter: DeviceInventoryFilter

    private var ungroupedDevices: [MonitoredDevice] {
        appState.devices
            .filter { $0.primaryGroupID == nil }
            .filter { filter.includes($0) }
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    private var allUngroupedDevices: [MonitoredDevice] {
        appState.devices.filter { $0.primaryGroupID == nil }
    }

    private var shouldShow: Bool {
        !filter.isActive || !ungroupedDevices.isEmpty
    }

    @ViewBuilder
    var body: some View {
        if shouldShow {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(ungroupedDevices) { device in
                        DeviceInventoryRow(device: device, level: 1)
                    }
                    if ungroupedDevices.isEmpty {
                        Text(filter.isActive ? "No matching ungrouped devices" : "No ungrouped devices")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 20)
                            .padding(.vertical, 3)
                    }
                }
                .padding(.leading, 12)
                .padding(.top, 2)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "tray")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Ungrouped")
                            .font(.caption.weight(.semibold))
                        Text("No group")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(activeCount)/\(allUngroupedDevices.count)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .help("Responsive / total ungrouped devices")
                }
                .padding(.vertical, 2)
                .padding(.horizontal, 4)
            }
            .onDrop(of: [.text], isTargeted: $dropTargeted) { providers in
                guard let provider = providers.first else { return false }
                provider.loadObject(ofClass: NSString.self) { item, _ in
                    guard let nsString = item as? NSString, let deviceID = UUID(uuidString: nsString as String) else { return }
                    Task { @MainActor in appState.assignDevice(deviceID, toGroup: nil) }
                }
                return true
            }
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(dropTargeted ? FCDesign.ColorToken.warning : .clear, lineWidth: 1)
            }
        }
    }

    private var activeCount: Int {
        allUngroupedDevices.filter { $0.enabled && $0.healthState == .healthy }.count
    }
}

private struct TagMaintenanceView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTag: String?
    @State private var editedName: String = ""

    private var tagCounts: [TagCount] {
        DeviceInventoryView.tagCounts(from: appState.devices)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tag Maintenance")
                        .font(.title2.bold())
                    Text("Rename or remove inventory tags across all devices.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }
            }

            Divider()

            HStack(spacing: 14) {
                List(tagCounts, selection: $selectedTag) { tag in
                    HStack {
                        Text(tag.name)
                        Spacer()
                        Text("\(tag.count)")
                            .font(.caption.monospacedDigit().bold())
                            .foregroundStyle(.secondary)
                    }
                    .tag(tag.name)
                }
                .frame(minWidth: 210)

                VStack(alignment: .leading, spacing: 10) {
                    if let selectedTag {
                        Text("Edit Tag")
                            .font(.headline)
                        TextField("Tag name", text: $editedName, prompt: Text("Required"))
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { renameSelectedTag() }

                        HStack {
                            Button("Rename") { renameSelectedTag() }
                                .disabled(trimmedEditedName.isEmpty || trimmedEditedName.caseInsensitiveCompare(selectedTag) == .orderedSame)
                            Button("Delete", role: .destructive) {
                                appState.deleteTag(selectedTag)
                                self.selectedTag = nil
                                editedName = ""
                            }
                            Spacer()
                        }

                        Text("Renaming a tag updates every device using that tag. Deleting removes it from devices; it does not delete devices.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ContentUnavailableView("Select a Tag", systemImage: "tag", description: Text("Choose a tag to rename or delete."))
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .padding(20)
        .onChange(of: selectedTag) { _, newValue in
            editedName = newValue ?? ""
        }
    }

    private var trimmedEditedName: String {
        editedName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func renameSelectedTag() {
        guard let selectedTag else { return }
        let newName = trimmedEditedName
        guard !newName.isEmpty else { return }
        appState.renameTag(selectedTag, to: newName)
        self.selectedTag = newName
        editedName = newName
    }
}

fileprivate struct TagCount: Identifiable, Hashable {
    var name: String
    var count: Int
    var id: String { name.lowercased() }
}
