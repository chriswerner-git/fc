//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                    │
//  │  Flight Control                                             │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: AudioInputDeviceService.swift
//  Purpose: Discovers macOS audio input devices for future Audio LTC timecode
//           monitoring. This service enumerates selectable inputs only; it does
//           not open, capture, or decode live audio yet.
//
//  Created by Chris Werner / Lunar Telephone Company.
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import AVFoundation
import Foundation

struct AudioInputDeviceInfo: Identifiable, Codable, Hashable, Sendable {
    var id: String { uniqueID }

    var uniqueID: String
    var name: String
    var manufacturer: String?
    var modelID: String?
    var isConnected: Bool

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Unnamed Audio Input" : trimmed
    }

    var detailText: String {
        var parts: [String] = []
        if let manufacturer, manufacturer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            parts.append(manufacturer)
        }
        if let modelID, modelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            parts.append(modelID)
        }
        parts.append(uniqueID)
        return parts.joined(separator: " · ")
    }
}

@MainActor
final class AudioInputDeviceService {
    func requestAuthorizationIfNeeded(completion: @escaping () -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { _ in
                DispatchQueue.main.async { completion() }
            }
        default:
            completion()
        }
    }

    func discoverInputDevices() -> [AudioInputDeviceInfo] {
        AVCaptureDevice.devices(for: .audio)
            .map { device in
                AudioInputDeviceInfo(
                    uniqueID: device.uniqueID,
                    name: device.localizedName,
                    manufacturer: nil,
                    modelID: nil,
                    isConnected: true
                )
            }
            .sorted { lhs, rhs in
                lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
            }
    }

    var authorizationStatusText: String {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return "Audio input permission granted"
        case .notDetermined:
            return "Audio input permission not requested yet"
        case .denied:
            return "Audio input permission denied"
        case .restricted:
            return "Audio input permission restricted"
        @unknown default:
            return "Audio input permission unknown"
        }
    }
}
