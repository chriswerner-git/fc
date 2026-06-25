//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                    │
//  │  Flight Control                                             │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: TimecodeLTCDecoderService.swift
//  Purpose: libltc-backed SMPTE LTC decoder used by Flight Control's Audio LTC
//           monitor. This service receives normalized audio samples, forwards
//           them to the vendored x42/libltc decoder package, and publishes
//           decoded timecode for dashboard display and future alert/rule logic.
//
//  Created by Chris Werner / Lunar Telephone Company.
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import Foundation
import LTCLib

struct TimecodeLTCDecodeResult: Hashable, Sendable {
    var timecodeText: String
    var frameRate: TimecodeFrameRate?
    var dropFrame: Bool
    var decodedAt: Date
    var confidence: Double
    var message: String
}

/// Flight Control's production LTC decoder facade.
///
/// The first native decoder proved that the monitoring flow worked, but it was
/// too CPU-heavy for persistent operation. This replacement delegates actual
/// LTC parsing to x42/libltc through the local LTCLib Swift Package. Multiple
/// decoder instances are maintained with different starting APV assumptions so
/// auto-detection is resilient across common LTC rates without requiring the
/// operator to preselect a frame rate.
final class TimecodeLTCDecoderService {
    private struct Backend {
        let assumedFrameRate: Double
        let decoder: LTCLibDecoder
    }

    private var backends: [Backend] = []
    private var currentSampleRate: Double = 0
    private var lastDecodedKey: String = ""
    private var lastFrameRate: TimecodeFrameRate?
    private var lockedBackendIndex: Int?
    private var lockedBackendMissCount: Int = 0
    private var nextSearchBackendIndex: Int = 0

    static let backendDisplayName = "libltc"

    /// These assumptions are only used for libltc's initial audio-frames-per-
    /// video-frame setting. libltc tracks speed dynamically after sync.
    private let assumedFrameRates: [Double] = [23.976, 25.0, 29.97]

    func reset() {
        backends.removeAll()
        currentSampleRate = 0
        lastDecodedKey = ""
        lastFrameRate = nil
        lockedBackendIndex = nil
        lockedBackendMissCount = 0
        nextSearchBackendIndex = 0
    }

    func process(samples: [Float], sampleRate: Double, polarityMode: TimecodePolarityMode) -> TimecodeLTCDecodeResult? {
        guard samples.isEmpty == false, sampleRate > 0 else { return nil }
        ensureBackends(sampleRate: sampleRate)

        let samplesForDecode: [Float]
        switch polarityMode {
        case .inverted:
            samplesForDecode = samples.map { -$0 }
        case .normal, .automatic:
            samplesForDecode = samples
        }

        guard let decoded = decodeWithPreferredBackend(samples: samplesForDecode) else { return nil }

        let frame = decoded.frame
        let frameRate = decoded.frameRate
        let timecodeText = normalizedTimecodeText(from: frame, frameRate: frameRate)
        let key = "\(timecodeText)|\(frameRate.rawValue)|\(frame.dropFrame)"
        guard key != lastDecodedKey else { return nil }
        lastDecodedKey = key
        lastFrameRate = frameRate

        return TimecodeLTCDecodeResult(
            timecodeText: timecodeText,
            frameRate: frameRate,
            dropFrame: frame.dropFrame,
            decodedAt: frame.decodedAt,
            confidence: 1.0,
            message: "Decoded LTC · \(Self.backendDisplayName) · \(frameRate.displayName)"
        )
    }


    private func decodeWithPreferredBackend(samples: [Float]) -> (frame: LTCLibDecodedFrame, frameRate: TimecodeFrameRate)? {
        guard backends.isEmpty == false else { return nil }

        // Once a backend has lock, stay with it. Calling every possible APV
        // assumption for every audio chunk is reliable but expensive. If the
        // locked backend misses repeatedly, fall back to a rotating search.
        if let lockedBackendIndex, backends.indices.contains(lockedBackendIndex) {
            let backend = backends[lockedBackendIndex]
            if let frame = backend.decoder.process(samples: samples) {
                lockedBackendMissCount = 0
                let frameRate = inferFrameRate(from: frame, assumedFrameRate: backend.assumedFrameRate)
                return (frame, frameRate)
            }

            lockedBackendMissCount += 1
            if lockedBackendMissCount < 36 {
                return nil
            }

            self.lockedBackendIndex = nil
            lockedBackendMissCount = 0
        }

        // During acquisition, test one backend per audio chunk and rotate. This
        // keeps CPU bounded while still allowing auto-detect across common LTC
        // rates within a short lock-on window.
        let index = nextSearchBackendIndex % backends.count
        nextSearchBackendIndex = (index + 1) % backends.count
        let backend = backends[index]

        guard let frame = backend.decoder.process(samples: samples) else { return nil }

        lockedBackendIndex = index
        lockedBackendMissCount = 0
        let frameRate = inferFrameRate(from: frame, assumedFrameRate: backend.assumedFrameRate)
        return (frame, frameRate)
    }

    private func ensureBackends(sampleRate: Double) {
        guard backends.isEmpty || abs(currentSampleRate - sampleRate) > 1.0 else { return }
        currentSampleRate = sampleRate
        backends = assumedFrameRates.map { assumedRate in
            Backend(
                assumedFrameRate: assumedRate,
                decoder: LTCLibDecoder(sampleRate: sampleRate, assumedFrameRate: assumedRate, queueSize: 64)
            )
        }
        lastDecodedKey = ""
        lastFrameRate = nil
        lockedBackendIndex = nil
        lockedBackendMissCount = 0
        nextSearchBackendIndex = 0
    }

    private func inferFrameRate(from frame: LTCLibDecodedFrame, assumedFrameRate: Double) -> TimecodeFrameRate {
        if frame.dropFrame { return .fps2997Drop }

        let fps = frame.estimatedFPS > 1 ? frame.estimatedFPS : assumedFrameRate

        if fps < 24.5 {
            return fps < 23.99 ? .fps23976 : .fps24
        }

        if fps < 27.0 {
            return .fps25
        }

        if fps < 29.985 {
            return .fps2997NonDrop
        }

        return .fps30
    }

    private func normalizedTimecodeText(from frame: LTCLibDecodedFrame, frameRate: TimecodeFrameRate) -> String {
        let separator = frameRate.separator
        return String(
            format: "%02d%@%02d%@%02d%@%02d",
            frame.hours,
            separator,
            frame.minutes,
            separator,
            frame.seconds,
            separator,
            frame.frames
        )
    }
}
