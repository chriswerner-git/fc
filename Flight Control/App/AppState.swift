//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                    │
//  │  Flight Control                                             │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: AppState.swift
//  Purpose: Central application state, persistence coordination, monitoring lifecycle, and dashboard status.
//
//  Created by Chris Werner / Lunar Telephone Company.
//  © 2026 Lunar Telephone Company. All rights reserved.
//
//  This source file is part of Flight Control, a macOS utility developed
//  by Lunar Telephone Company for persistent project-location device
//  inventory, network health monitoring, dashboard visibility, and future
//  Deep Space Network reporting.
//
//  This software is provided for internal operational use and project support.
//  No portion of this file may be copied, distributed, disclosed, modified,
//  or reused outside authorized Lunar Telephone Company work without prior
//  written permission.
//


import AppKit
import Combine
import Foundation
import SwiftUI

@MainActor
final class AppState: NSObject, ObservableObject {
    @Published var settings: MonitoringSettings
    @Published var devices: [MonitoredDevice]
    @Published var inventoryGroups: [DeviceInventoryGroup]
    @Published var alertRules: [AlertRule]
    @Published var statusEvents: [StatusEvent]
    @Published var networkInterfaces: [NetworkInterfaceInfo] = []
    @Published var selectedDeviceID: UUID? = nil
    @Published var selectedInventoryGroupID: UUID? = nil
    @Published var lastPersistenceError: String? = nil
    @Published var lastEngineMessage: String = "Starting"
    @Published var lastRuntimePreferenceError: String? = nil
    @Published var showingCriticalAlert: StatusEvent? = nil
    @Published var currentDate: Date = Date()

    private let monitoringEngine = MonitoringEngine()
    private let sleepPreventionService = SleepPreventionService()
    private let uptimeService = UptimeService()
    private var clockTimer: Timer?
    private var saveTimer: Timer?

    override init() {
        if let snapshot = try? PersistenceService.loadSnapshot() {
            var loadedSettings = snapshot.settings
            loadedSettings.clampValues()
            settings = loadedSettings
            devices = snapshot.devices
            inventoryGroups = snapshot.inventoryGroups
            alertRules = snapshot.alertRules
            statusEvents = snapshot.statusEvents
        } else {
            settings = MonitoringSettings()
            devices = [MonitoredDevice.sampleLightingController]
            inventoryGroups = []
            alertRules = [AlertRule(name: "Critical Device Alert", trigger: .deviceCritical)]
            statusEvents = []
        }

        super.init()

        refreshNetworkInterfaces()
        configureMonitoringEngine()
        applyRuntimePreferences()
        startClock()

        if settings.monitoringEnabled {
            monitoringEngine.start()
        }
    }

    deinit {
        clockTimer?.invalidate()
        saveTimer?.invalidate()
    }

    var uptimeDisplay: String { uptimeService.displayText }
    var monitoringRunning: Bool { monitoringEngine.isRunning && settings.monitoringEnabled }

    var overallHealth: DeviceHealthState {
        let enabledDevices = devices.filter(\.enabled)
        guard !enabledDevices.isEmpty else { return .unknown }
        if enabledDevices.contains(where: { $0.healthState == .critical }) { return .critical }
        if enabledDevices.contains(where: { $0.healthState == .warning }) { return .warning }
        if enabledDevices.contains(where: { $0.healthState == .unknown }) { return .unknown }
        return .healthy
    }

    var configurationIssues: [ConfigurationIssue] {
        ConfigurationHealthService.evaluate(devices: devices, settings: settings, interfaces: networkInterfaces)
    }

    var nextCheckDate: Date? {
        devices.compactMap(\.nextCheckAfter).min()
    }

    var lastCheckDate: Date? {
        devices.compactMap(\.lastCheckedAt).max()
    }

    var enabledDeviceCount: Int { devices.filter(\.enabled).count }

    func count(for state: DeviceHealthState) -> Int {
        devices.filter { $0.healthState == state }.count
    }

    func recentEvents(limit: Int = 8) -> [StatusEvent] {
        Array(statusEvents.sorted { $0.date > $1.date }.prefix(limit))
    }

    func dashboardOrderedDevices() -> [MonitoredDevice] {
        devices.sorted { lhs, rhs in
            let leftIndex = lhs.dashboardGridIndex ?? Int.max
            let rightIndex = rhs.dashboardGridIndex ?? Int.max
            if leftIndex != rightIndex { return leftIndex < rightIndex }
            if lhs.healthState != rhs.healthState { return lhs.healthState < rhs.healthState }
            return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
        }
    }

    func dashboardLayoutItems() -> [DashboardLayoutItem] {
        var items: [DashboardLayoutItem] = []

        for (fallbackIndex, divider) in settings.dashboardDividers.enumerated() {
            items.append(DashboardLayoutItem(
                id: divider.id,
                kind: .divider,
                device: nil,
                divider: divider,
                sortIndex: divider.dashboardGridIndex ?? (10_000 + fallbackIndex)
            ))
        }

        for (fallbackIndex, device) in dashboardOrderedDevices().enumerated() {
            items.append(DashboardLayoutItem(
                id: device.id,
                kind: .device,
                device: device,
                divider: nil,
                sortIndex: device.dashboardGridIndex ?? (20_000 + fallbackIndex)
            ))
        }

        return items.sorted { lhs, rhs in
            if lhs.sortIndex != rhs.sortIndex { return lhs.sortIndex < rhs.sortIndex }
            if lhs.kind != rhs.kind { return lhs.kind == .divider }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    func addDashboardDivider() {
        let nextIndex = (dashboardLayoutItems().map(\.sortIndex).max() ?? -1) + 1
        var divider = DashboardDivider()
        divider.title = "Section"
        divider.dashboardGridIndex = nextIndex
        settings.dashboardDividers.append(divider)
        scheduleSave()
    }

    func deleteDashboardDivider(_ dividerID: UUID) {
        settings.dashboardDividers.removeAll { $0.id == dividerID }
        normalizeDashboardLayoutOrder()
        scheduleSave()
    }

    func updateDashboardDividerTitle(_ dividerID: UUID, title: String) {
        guard let index = settings.dashboardDividers.firstIndex(where: { $0.id == dividerID }) else { return }
        settings.dashboardDividers[index].title = title
        scheduleSave()
    }

    func moveDeviceInDashboard(_ sourceID: UUID, before targetID: UUID) {
        moveDashboardItem(sourceID: sourceID, sourceKind: .device, before: targetID, targetKind: .device)
    }

    func moveDashboardDividerUp(_ dividerID: UUID) {
        moveDashboardItemByOffset(sourceID: dividerID, sourceKind: .divider, offset: -1)
    }

    func moveDashboardDividerDown(_ dividerID: UUID) {
        moveDashboardItemByOffset(sourceID: dividerID, sourceKind: .divider, offset: 1)
    }

    private func moveDashboardItemByOffset(sourceID: UUID, sourceKind: DashboardItemKind, offset: Int) {
        guard offset != 0 else { return }
        var ordered = dashboardLayoutItems()
        guard let sourceIndex = ordered.firstIndex(where: { $0.id == sourceID && $0.kind == sourceKind }) else { return }
        let destinationIndex = min(max(sourceIndex + offset, 0), ordered.count - 1)
        guard destinationIndex != sourceIndex else { return }
        let moving = ordered.remove(at: sourceIndex)
        ordered.insert(moving, at: destinationIndex)
        applyDashboardLayoutOrder(ordered)
        scheduleSave()
    }

    func moveDashboardItem(sourceID: UUID, sourceKind: DashboardItemKind, before targetID: UUID, targetKind: DashboardItemKind) {
        guard sourceID != targetID || sourceKind != targetKind else { return }
        var ordered = dashboardLayoutItems()
        guard let sourceIndex = ordered.firstIndex(where: { $0.id == sourceID && $0.kind == sourceKind }),
              let targetIndex = ordered.firstIndex(where: { $0.id == targetID && $0.kind == targetKind }) else { return }

        let moving = ordered.remove(at: sourceIndex)
        let adjustedTargetIndex = sourceIndex < targetIndex ? max(targetIndex - 1, 0) : targetIndex
        ordered.insert(moving, at: adjustedTargetIndex)
        applyDashboardLayoutOrder(ordered)
        scheduleSave()
    }

    private func normalizeDashboardLayoutOrder() {
        applyDashboardLayoutOrder(dashboardLayoutItems())
    }

    private func applyDashboardLayoutOrder(_ orderedItems: [DashboardLayoutItem]) {
        for (position, item) in orderedItems.enumerated() {
            switch item.kind {
            case .device:
                if let index = devices.firstIndex(where: { $0.id == item.id }) {
                    devices[index].dashboardGridIndex = position
                }
            case .divider:
                if let index = settings.dashboardDividers.firstIndex(where: { $0.id == item.id }) {
                    settings.dashboardDividers[index].dashboardGridIndex = position
                }
            }
        }
    }

    func toggleMonitoring() {
        settings.monitoringEnabled.toggle()
        settings.monitoringEnabled ? monitoringEngine.start() : monitoringEngine.stop()
        applyRuntimePreferences()
        scheduleSave()
    }

    func refreshNetworkInterfaces() {
        networkInterfaces = NetworkInterfaceInventoryService.currentInterfaces()
    }

    func addDevice() {
        var device = MonitoredDevice()
        device.checkIntervalSeconds = nil
        device.primaryGroupID = selectedInventoryGroupID
        device.warningMissCount = settings.defaultWarningMissCount
        device.criticalMissCount = settings.defaultCriticalMissCount
        devices.append(device)
        selectedDeviceID = device.id
        selectedInventoryGroupID = nil
        scheduleSave()
    }

    func duplicateDevice(_ device: MonitoredDevice) {
        var copy = device
        copy.id = UUID()
        copy.name += " Copy"
        copy.healthState = .unknown
        copy.consecutiveFailures = 0
        copy.lastCheckedAt = nil
        copy.lastHealthyAt = nil
        copy.lastLatencyMilliseconds = nil
        copy.lastErrorMessage = nil
        copy.nextCheckAfter = nil
        devices.append(copy)
        selectedDeviceID = copy.id
        scheduleSave()
    }

    func deleteDevice(_ device: MonitoredDevice) {
        devices.removeAll { $0.id == device.id }
        if selectedDeviceID == device.id { selectedDeviceID = devices.first?.id }
        scheduleSave()
    }

    func updateDevice(_ updatedDevice: MonitoredDevice) {
        guard let index = devices.firstIndex(where: { $0.id == updatedDevice.id }) else { return }
        var device = updatedDevice
        if let interval = device.checkIntervalSeconds {
            device.checkIntervalSeconds = max(settings.minimumCheckIntervalSeconds, interval)
        }
        device.criticalMissCount = max(device.warningMissCount, device.criticalMissCount)
        devices[index] = device
        scheduleSave()
    }

    func forceCheckNow(_ device: MonitoredDevice? = nil) {
        if let device, let index = devices.firstIndex(where: { $0.id == device.id }) {
            devices[index].nextCheckAfter = Date.distantPast
        } else {
            for index in devices.indices where devices[index].enabled {
                devices[index].nextCheckAfter = Date.distantPast
            }
        }
        monitoringEngine.runDueChecks(devices: devices, settings: settings)
    }

    func selectedInventoryGroup() -> DeviceInventoryGroup? {
        guard let selectedInventoryGroupID else { return nil }
        return findInventoryGroup(id: selectedInventoryGroupID)
    }

    func findInventoryGroup(id: UUID?) -> DeviceInventoryGroup? {
        guard let id else { return nil }
        return Self.findGroup(id: id, in: inventoryGroups)
    }

    func flattenedInventoryGroupOptions(excluding excludedGroupID: UUID? = nil) -> [DeviceInventoryGroupOption] {
        var options: [DeviceInventoryGroupOption] = []
        Self.appendGroupOptions(from: inventoryGroups, depth: 0, excluding: excludedGroupID, into: &options)
        return options
    }

    func addInventoryGroup(parentID: UUID? = nil) {
        let group = DeviceInventoryGroup()
        if let parentID {
            inventoryGroups = Self.addGroup(group, under: parentID, in: inventoryGroups)
        } else {
            inventoryGroups.append(group)
        }
        selectedInventoryGroupID = group.id
        selectedDeviceID = nil
        scheduleSave()
    }

    func updateInventoryGroup(_ updatedGroup: DeviceInventoryGroup) {
        inventoryGroups = Self.updateGroup(updatedGroup, in: inventoryGroups)
        scheduleSave()
    }

    func deleteInventoryGroup(_ group: DeviceInventoryGroup) {
        var idsToClear: Set<UUID> = []
        Self.collectGroupIDs(from: [group], into: &idsToClear)
        inventoryGroups = Self.removeGroup(id: group.id, from: inventoryGroups)
        for index in devices.indices where devices[index].primaryGroupID.map(idsToClear.contains) == true {
            devices[index].primaryGroupID = nil
        }
        if idsToClear.contains(selectedInventoryGroupID ?? UUID()) {
            selectedInventoryGroupID = nil
        }
        scheduleSave()
    }

    func moveInventoryGroup(_ groupID: UUID, toParent parentID: UUID?) {
        guard groupID != parentID else { return }
        guard let movingGroup = findInventoryGroup(id: groupID) else { return }
        var excludedIDs: Set<UUID> = []
        Self.collectGroupIDs(from: [movingGroup], into: &excludedIDs)
        guard parentID.map({ excludedIDs.contains($0) }) != true else { return }
        inventoryGroups = Self.removeGroup(id: groupID, from: inventoryGroups)
        if let parentID {
            inventoryGroups = Self.addGroup(movingGroup, under: parentID, in: inventoryGroups)
        } else {
            inventoryGroups.append(movingGroup)
        }
        scheduleSave()
    }

    func assignDevice(_ deviceID: UUID, toGroup groupID: UUID?) {
        guard let index = devices.firstIndex(where: { $0.id == deviceID }) else { return }
        devices[index].primaryGroupID = groupID
        scheduleSave()
    }

    func allInventoryGroups() -> [DeviceInventoryGroup] {
        Self.flattenGroups(inventoryGroups)
    }

    func renameTag(_ oldTag: String, to newTag: String) {
        let oldValue = oldTag.trimmingCharacters(in: .whitespacesAndNewlines)
        let newValue = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !oldValue.isEmpty, !newValue.isEmpty else { return }

        for index in devices.indices {
            var tags = devices[index].grouping.tags.filter { $0.caseInsensitiveCompare(oldValue) != .orderedSame }
            if !tags.contains(where: { $0.caseInsensitiveCompare(newValue) == .orderedSame }) {
                tags.append(newValue)
            }
            tags.sort { $0.localizedStandardCompare($1) == .orderedAscending }
            devices[index].grouping.tags = tags
        }
        scheduleSave()
    }

    func deleteTag(_ tag: String) {
        let value = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }

        for index in devices.indices {
            devices[index].grouping.tags.removeAll { $0.caseInsensitiveCompare(value) == .orderedSame }
        }
        scheduleSave()
    }

    func saveNow() {
        settings.clampValues()
        pruneStatusEvents()
        let snapshot = FlightControlSnapshot(settings: settings, devices: devices, inventoryGroups: inventoryGroups, alertRules: alertRules, statusEvents: statusEvents)
        do {
            try PersistenceService.saveSnapshot(snapshot)
            lastPersistenceError = nil
        } catch {
            lastPersistenceError = error.localizedDescription
        }
    }

    func applySettings() {
        settings.clampValues()
        applyRuntimePreferences()
        if settings.monitoringEnabled { monitoringEngine.start() } else { monitoringEngine.stop() }
        scheduleSave()
    }

    private func configureMonitoringEngine() {
        monitoringEngine.onTick = { [weak self] in
            guard let self else { return }
            self.monitoringEngine.runDueChecks(devices: self.devices, settings: self.settings)
        }

        monitoringEngine.onResult = { [weak self] result in
            self?.processCheckResult(result)
        }

        monitoringEngine.onEngineMessage = { [weak self] message in
            self?.lastEngineMessage = message
        }
    }

    private func processCheckResult(_ result: DeviceCheckResult) {
        guard let index = devices.firstIndex(where: { $0.id == result.deviceID }) else { return }
        let previousState = devices[index].healthState
        devices[index].lastCheckedAt = result.checkedAt
        devices[index].lastLatencyMilliseconds = result.latencyMilliseconds
        devices[index].lastErrorMessage = result.errorMessage
        devices[index].nextCheckAfter = result.checkedAt.addingTimeInterval(devices[index].effectiveCheckIntervalSeconds(settings: settings))

        if result.success {
            devices[index].consecutiveFailures = 0
            devices[index].healthState = .healthy
            devices[index].lastHealthyAt = result.checkedAt
        } else {
            devices[index].consecutiveFailures += 1
            let failures = devices[index].consecutiveFailures
            if failures >= devices[index].criticalMissCount {
                devices[index].healthState = .critical
            } else if failures >= devices[index].warningMissCount {
                devices[index].healthState = .warning
            } else {
                devices[index].healthState = .unknown
            }
        }

        let newState = devices[index].healthState
        if previousState != newState || newState == .critical || newState == .warning {
            let event = StatusEvent(
                date: result.checkedAt,
                deviceID: devices[index].id,
                deviceName: devices[index].displayName,
                previousState: previousState,
                newState: newState,
                message: result.success ? "Device responded" : (result.errorMessage ?? "Device did not respond"),
                latencyMilliseconds: result.latencyMilliseconds
            )
            statusEvents.append(event)
            if newState == .critical && previousState != .critical && settings.showInAppCriticalPopups {
                showingCriticalAlert = event
            }
        }

        scheduleSave()
    }

    private static func findGroup(id: UUID, in groups: [DeviceInventoryGroup]) -> DeviceInventoryGroup? {
        for group in groups {
            if group.id == id { return group }
            if let child = findGroup(id: id, in: group.children) { return child }
        }
        return nil
    }

    private static func appendGroupOptions(from groups: [DeviceInventoryGroup], depth: Int, excluding excludedGroupID: UUID?, into options: inout [DeviceInventoryGroupOption]) {
        for group in groups {
            if group.id != excludedGroupID {
                options.append(DeviceInventoryGroupOption(id: group.id, name: group.menuDisplayName, depth: depth))
                appendGroupOptions(from: group.children, depth: depth + 1, excluding: excludedGroupID, into: &options)
            }
        }
    }

    private static func addGroup(_ newGroup: DeviceInventoryGroup, under parentID: UUID, in groups: [DeviceInventoryGroup]) -> [DeviceInventoryGroup] {
        groups.map { group in
            var copy = group
            if copy.id == parentID {
                copy.children.append(newGroup)
            } else {
                copy.children = addGroup(newGroup, under: parentID, in: copy.children)
            }
            return copy
        }
    }

    private static func updateGroup(_ updatedGroup: DeviceInventoryGroup, in groups: [DeviceInventoryGroup]) -> [DeviceInventoryGroup] {
        groups.map { group in
            if group.id == updatedGroup.id { return updatedGroup }
            var copy = group
            copy.children = updateGroup(updatedGroup, in: copy.children)
            return copy
        }
    }


    private static func flattenGroups(_ groups: [DeviceInventoryGroup]) -> [DeviceInventoryGroup] {
        groups.flatMap { group in
            [group] + flattenGroups(group.children)
        }
    }

    private static func removeGroup(id: UUID, from groups: [DeviceInventoryGroup]) -> [DeviceInventoryGroup] {
        groups.compactMap { group in
            guard group.id != id else { return nil }
            var copy = group
            copy.children = removeGroup(id: id, from: copy.children)
            return copy
        }
    }

    private static func collectGroupIDs(from groups: [DeviceInventoryGroup], into ids: inout Set<UUID>) {
        for group in groups {
            ids.insert(group.id)
            collectGroupIDs(from: group.children, into: &ids)
        }
    }

    private func applyRuntimePreferences() {
        lastRuntimePreferenceError = nil

        do {
            if settings.preventSleep && settings.monitoringEnabled {
                try sleepPreventionService.enable(reason: "Flight Control monitoring is active")
            } else {
                sleepPreventionService.disable()
            }
        } catch {
            lastRuntimePreferenceError = error.localizedDescription
        }

        do {
            try LoginStartupService.setEnabled(settings.launchAtLogin)
        } catch {
            lastRuntimePreferenceError = error.localizedDescription
        }
    }

    private func startClock() {
        clockTimer = Timer.scheduledTimer(
            timeInterval: 1.0,
            target: self,
            selector: #selector(handleClockTimer),
            userInfo: nil,
            repeats: true
        )
        clockTimer?.tolerance = 0.15
    }

    @objc private func handleClockTimer(_ timer: Timer) {
        currentDate = Date()
    }

    private func scheduleSave() {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(
            timeInterval: 0.8,
            target: self,
            selector: #selector(handleSaveTimer),
            userInfo: nil,
            repeats: false
        )
        saveTimer?.tolerance = 0.2
    }

    @objc private func handleSaveTimer(_ timer: Timer) {
        saveNow()
    }

    private func pruneStatusEvents() {
        let cutoff = Date().addingTimeInterval(-TimeInterval(settings.retentionDays) * 86400)
        statusEvents = statusEvents.filter { $0.date >= cutoff }
    }
}
