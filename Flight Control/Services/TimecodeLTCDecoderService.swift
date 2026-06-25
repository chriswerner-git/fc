//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                    │
//  │  Flight Control                                             │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: TimecodeLTCDecoderService.swift
//  Purpose: Experimental native SMPTE LTC decoder used by Flight Control's
//           Audio LTC monitor. This service receives normalized audio samples,
//           detects bi-phase mark transitions, assembles LTC frames, and
//           publishes decoded timecode for dashboard display and future rules.
//
//  Created by Chris Werner / Lunar Telephone Company.
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import Foundation

struct TimecodeLTCDecodeResult: Hashable, Sendable {
    var timecodeText: String
    var frameRate: TimecodeFrameRate?
    var dropFrame: Bool
    var decodedAt: Date
    var confidence: Double
    var message: String
}

/// A small native LTC decoder designed for monitoring, not mastering.
///
/// This decoder intentionally favors safety and continuity over cleverness:
/// it tolerates clean LTC feeds well, reports confidence, and fails closed
/// when sync cannot be established. A future libltc-backed decoder may still
/// replace this layer if field testing shows that broader edge-case handling
/// is needed.
final class TimecodeLTCDecoderService {
    private var intervals: [Int] = []
    private var samplesSinceEdge: Int = 0
    private var lastSign: Int = 0
    private var lastDecodedKey: String = ""
    private var recentDecodedFrames: [DecodedFrame] = []
    private var lastDecodeAttemptUptime: TimeInterval = 0
    private var intervalCountAtLastDecodeAttempt: Int = 0

    private let threshold: Float = 0.015
    private let maxStoredIntervals = 520
    private let minimumDecodeAttemptInterval: TimeInterval = 0.08
    private let minimumNewIntervalsBeforeDecode = 36

    func reset() {
        intervals.removeAll()
        samplesSinceEdge = 0
        lastSign = 0
        lastDecodedKey = ""
        recentDecodedFrames.removeAll()
        lastDecodeAttemptUptime = 0
        intervalCountAtLastDecodeAttempt = 0
    }

    func process(samples: [Float], sampleRate: Double, polarityMode: TimecodePolarityMode) -> TimecodeLTCDecodeResult? {
        guard samples.isEmpty == false, sampleRate > 0 else { return nil }

        let polarityMultiplier: Float = polarityMode == .inverted ? -1.0 : 1.0

        for rawSample in samples {
            let sample = rawSample * polarityMultiplier
            let sign: Int
            if sample > threshold {
                sign = 1
            } else if sample < -threshold {
                sign = -1
            } else {
                sign = lastSign
            }

            samplesSinceEdge += 1

            if lastSign == 0 {
                lastSign = sign
                continue
            }

            guard sign != 0, sign != lastSign else { continue }

            let interval = samplesSinceEdge
            samplesSinceEdge = 0
            lastSign = sign

            let minimumUsefulInterval = max(2, Int(sampleRate / 10_000.0))
            let maximumUsefulInterval = max(80, Int(sampleRate / 350.0))
            guard interval >= minimumUsefulInterval, interval <= maximumUsefulInterval else { continue }

            intervals.append(interval)
            if intervals.count > maxStoredIntervals {
                intervals.removeFirst(intervals.count - maxStoredIntervals)
            }
        }

        // Edge detection is lightweight and runs on every audio buffer. Full LTC
        // frame decoding is deliberately rate-limited because the sync search is
        // more expensive and a dashboard/status monitor does not need to decode
        // every Core Audio callback. The display layer interpolates between
        // valid decoded frames while the audio signal remains present.
        let uptime = ProcessInfo.processInfo.systemUptime
        let newIntervals = intervals.count - intervalCountAtLastDecodeAttempt
        guard uptime - lastDecodeAttemptUptime >= minimumDecodeAttemptInterval || newIntervals >= minimumNewIntervalsBeforeDecode else {
            return nil
        }
        lastDecodeAttemptUptime = uptime
        intervalCountAtLastDecodeAttempt = intervals.count

        guard let halfBitSamples = estimateHalfBitSamples(sampleRate: sampleRate) else { return nil }
        guard let frame = decodeMostRecentFrame(halfBitSamples: halfBitSamples) else { return nil }

        let key = "\(frame.hours):\(frame.minutes):\(frame.seconds):\(frame.frames):\(frame.dropFrame)"
        guard key != lastDecodedKey else { return nil }
        lastDecodedKey = key

        recentDecodedFrames.append(frame)
        if recentDecodedFrames.count > 120 {
            recentDecodedFrames.removeFirst(recentDecodedFrames.count - 120)
        }

        let detectedFrameRate = inferFrameRate(for: frame)
        let separator = detectedFrameRate?.separator ?? (frame.dropFrame ? ";" : ":")
        let text = String(format: "%02d%@%02d%@%02d%@%02d", frame.hours, separator, frame.minutes, separator, frame.seconds, separator, frame.frames)
        let confidence = min(1.0, max(0.25, frame.syncScore))
        let message = detectedFrameRate.map { "Decoded LTC · \($0.displayName)" } ?? "Decoded LTC · frame rate detecting"

        return TimecodeLTCDecodeResult(
            timecodeText: text,
            frameRate: detectedFrameRate,
            dropFrame: frame.dropFrame,
            decodedAt: frame.decodedAt,
            confidence: confidence,
            message: message
        )
    }

    private func estimateHalfBitSamples(sampleRate: Double) -> Double? {
        let expectedMinimum = sampleRate / (30.0 * 80.0 * 2.0) * 0.55
        let expectedMaximum = sampleRate / (23.976 * 80.0) * 1.30
        let useful = intervals
            .suffix(360)
            .filter { Double($0) >= expectedMinimum && Double($0) <= expectedMaximum }
            .sorted()

        guard useful.count >= 24 else { return nil }

        // LTC transition intervals are usually a mix of half-bit and full-bit
        // distances. The lower cluster is the half-bit distance. Using a lower
        // quantile is more stable than a full median when zero bits dominate.
        let lowerCount = max(8, useful.count / 3)
        let lowerCluster = Array(useful.prefix(lowerCount))
        guard lowerCluster.isEmpty == false else { return nil }
        let mid = lowerCluster.count / 2
        return Double(lowerCluster[mid])
    }

    private func decodeMostRecentFrame(halfBitSamples: Double) -> DecodedFrame? {
        guard intervals.count >= 120 else { return nil }

        let recentIntervals = Array(intervals.suffix(260))
        let halfUnits = recentIntervals.map { interval -> Int in
            let ratio = Double(interval) / halfBitSamples
            if ratio < 0.55 || ratio > 2.85 { return 0 }
            if ratio < 1.48 { return 1 }
            return 2
        }

        var bestFrame: DecodedFrame?

        let searchStart = max(0, halfUnits.count - 190)
        for startIndex in searchStart..<halfUnits.count {
            guard let bits = decodeBits(from: halfUnits, startingAt: startIndex), bits.count >= 80 else { continue }

            for windowStart in 0...(bits.count - 80) {
                let candidate = Array(bits[windowStart..<(windowStart + 80)])
                guard let syncScore = syncScore(for: Array(candidate[64..<80])), syncScore >= 0.92 else { continue }
                guard let frame = DecodedFrame(bits: candidate, syncScore: syncScore) else { continue }
                if bestFrame == nil || frame.syncScore > (bestFrame?.syncScore ?? 0) {
                    bestFrame = frame
                }
            }
        }

        return bestFrame
    }

    private func decodeBits(from halfUnits: [Int], startingAt startIndex: Int) -> [Int]? {
        var bits: [Int] = []
        var index = startIndex

        while index < halfUnits.count, bits.count < 104 {
            let unit = halfUnits[index]
            if unit == 2 {
                bits.append(0)
                index += 1
            } else if unit == 1 {
                guard index + 1 < halfUnits.count, halfUnits[index + 1] == 1 else {
                    return bits.count >= 80 ? bits : nil
                }
                bits.append(1)
                index += 2
            } else {
                return bits.count >= 80 ? bits : nil
            }
        }

        return bits.count >= 80 ? bits : nil
    }

    private func syncScore(for bits: [Int]) -> Double? {
        guard bits.count == 16 else { return nil }
        let syncA = "0011111111111101".map { $0 == "1" ? 1 : 0 }
        let syncB = bitsOfUInt16(0x3FFD)
        let matchesA = zip(bits, syncA).filter { $0.0 == $0.1 }.count
        let matchesB = zip(bits, syncB).filter { $0.0 == $0.1 }.count
        return Double(max(matchesA, matchesB)) / 16.0
    }

    private func bitsOfUInt16(_ value: UInt16) -> [Int] {
        (0..<16).map { index in
            ((value >> UInt16(index)) & 1) == 1 ? 1 : 0
        }
    }

    private func inferFrameRate(for frame: DecodedFrame) -> TimecodeFrameRate? {
        if frame.dropFrame { return .fps2997Drop }

        let observedFrames = recentDecodedFrames.map(\.frames)
        let maxFrame = observedFrames.max() ?? frame.frames

        if maxFrame >= 29 { return .fps30 }
        if maxFrame >= 25 { return .fps2997NonDrop }
        if maxFrame == 24 { return .fps25 }

        // If we have watched across at least two second changes without seeing
        // frames above 23, it is most likely 24 fps. Before that, keep detecting.
        let uniqueSeconds = Set(recentDecodedFrames.map { "\($0.hours):\($0.minutes):\($0.seconds)" })
        if uniqueSeconds.count >= 3, maxFrame <= 23 { return .fps24 }
        return nil
    }
}

private struct DecodedFrame: Hashable {
    var hours: Int
    var minutes: Int
    var seconds: Int
    var frames: Int
    var dropFrame: Bool
    var syncScore: Double
    var decodedAt: Date

    init?(bits: [Int], syncScore: Double) {
        guard bits.count >= 80 else { return nil }

        let frameUnits = Self.bcdValue(bits, [0, 1, 2, 3])
        let frameTens = Self.bcdValue(bits, [8, 9])
        let secondUnits = Self.bcdValue(bits, [16, 17, 18, 19])
        let secondTens = Self.bcdValue(bits, [24, 25, 26])
        let minuteUnits = Self.bcdValue(bits, [32, 33, 34, 35])
        let minuteTens = Self.bcdValue(bits, [40, 41, 42])
        let hourUnits = Self.bcdValue(bits, [48, 49, 50, 51])
        let hourTens = Self.bcdValue(bits, [56, 57])

        let frames = frameTens * 10 + frameUnits
        let seconds = secondTens * 10 + secondUnits
        let minutes = minuteTens * 10 + minuteUnits
        let hours = hourTens * 10 + hourUnits

        guard hours >= 0, hours <= 23,
              minutes >= 0, minutes <= 59,
              seconds >= 0, seconds <= 59,
              frames >= 0, frames <= 39 else {
            return nil
        }

        self.hours = hours
        self.minutes = minutes
        self.seconds = seconds
        self.frames = frames
        self.dropFrame = bits[10] == 1
        self.syncScore = syncScore
        self.decodedAt = Date()
    }

    private static func bcdValue(_ bits: [Int], _ positions: [Int]) -> Int {
        var value = 0
        for (offset, position) in positions.enumerated() where position < bits.count {
            if bits[position] == 1 {
                value += 1 << offset
            }
        }
        return value
    }
}
