//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                    │
//  │  Flight Control                                             │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: MonitoringEngine.swift
//  Purpose: Scheduler for due device checks with bounded ping concurrency and future protocol expansion points.
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


import Combine
import Foundation

struct DeviceCheckResult: Hashable {
    var deviceID: UUID
    var checkedAt: Date
    var success: Bool
    var latencyMilliseconds: Double?
    var errorMessage: String?
}

@MainActor
final class MonitoringEngine: NSObject, ObservableObject {
    private let pingService = PingProbeService()
    private var timer: Timer?
    private var runningDeviceIDs: Set<UUID> = []
    private var activeTaskCount = 0

    var onResult: ((DeviceCheckResult) -> Void)?
    var onEngineMessage: ((String) -> Void)?

    var isRunning: Bool {
        timer != nil
    }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(
            timeInterval: 1.0,
            target: self,
            selector: #selector(handleTimerTick),
            userInfo: nil,
            repeats: true
        )
        timer?.tolerance = 0.25
        onEngineMessage?("Monitoring engine started.")
    }

    @objc private func handleTimerTick(_ timer: Timer) {
        onTick?()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        runningDeviceIDs.removeAll()
        activeTaskCount = 0
        onEngineMessage?("Monitoring engine stopped.")
    }

    var onTick: (() -> Void)?

    func runDueChecks(devices: [MonitoredDevice], settings: MonitoringSettings) {
        guard settings.monitoringEnabled else { return }
        let now = Date()
        let dueDevices = devices.filter { device in
            guard device.canRunImplementedCheck else { return false }
            guard runningDeviceIDs.contains(device.id) == false else { return false }
            guard activeTaskCount < settings.pingConcurrencyLimit else { return false }
            if let next = device.nextCheckAfter { return next <= now }
            if let last = device.lastCheckedAt {
                return now.timeIntervalSince(last) >= device.effectiveCheckIntervalSeconds(settings: settings)
            }
            return true
        }

        for device in dueDevices {
            guard activeTaskCount < settings.pingConcurrencyLimit else { break }
            runningDeviceIDs.insert(device.id)
            activeTaskCount += 1
            runCheck(for: device, settings: settings)
        }
    }

    private func runCheck(for device: MonitoredDevice, settings: MonitoringSettings) {
        Task.detached(priority: .utility) { [pingService] in
            let checkedAt = Date()
            let result: PingProbeResult

            switch device.monitoringMethod {
            case .ping:
                result = await pingService.ping(host: device.host, timeoutSeconds: settings.pingTimeoutSeconds)
            default:
                result = PingProbeResult(success: false, latencyMilliseconds: nil, errorMessage: "Monitoring method not implemented", rawOutput: "")
            }

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.runningDeviceIDs.remove(device.id)
                self.activeTaskCount = max(0, self.activeTaskCount - 1)
                self.onResult?(
                    DeviceCheckResult(
                        deviceID: device.id,
                        checkedAt: checkedAt,
                        success: result.success,
                        latencyMilliseconds: result.latencyMilliseconds,
                        errorMessage: result.errorMessage
                    )
                )
            }
        }
    }
}
