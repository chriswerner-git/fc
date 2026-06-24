//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                    │
//  │  Flight Control                                             │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: PingProbeService.swift
//  Purpose: Bounded subprocess ping probe isolated for future ICMP implementation replacement.
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

import Foundation

struct PingProbeResult: Hashable {
    var success: Bool
    var latencyMilliseconds: Double?
    var errorMessage: String?
    var rawOutput: String
}

/// Uses /sbin/ping behind a narrow service boundary.  This is intentionally
/// conservative for the first pass: it avoids raw-socket entitlement issues,
/// limits process lifetime, and can be replaced later by an ICMP or protocol-
/// specific implementation without changing AppState or dashboard code.
actor PingProbeService {
    func ping(host: String, timeoutSeconds: TimeInterval) async -> PingProbeResult {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHost.isEmpty else {
            return PingProbeResult(success: false, latencyMilliseconds: nil, errorMessage: "Missing host/IP", rawOutput: "")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/ping")

        // macOS ping's -W value is in milliseconds.  The earlier scaffold
        // rounded seconds to an integer and accidentally passed very small
        // waits such as "2", which could produce a valid-looking summary while
        // still exiting as a failed probe.  Keep the timeout bounded but convert
        // it correctly here.
        let timeoutMilliseconds = max(250, Int((timeoutSeconds * 1_000).rounded(.up)))
        process.arguments = ["-n", "-c", "1", "-W", String(timeoutMilliseconds), trimmedHost]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            return PingProbeResult(success: false, latencyMilliseconds: nil, errorMessage: "Unable to start ping: \(error.localizedDescription)", rawOutput: "")
        }

        let timeoutTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(max(0.5, timeoutSeconds + 1.0) * 1_000_000_000))
            if process.isRunning {
                process.terminate()
            }
        }

        process.waitUntilExit()
        timeoutTask.cancel()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        let latency = Self.extractLatencyMilliseconds(from: output)
        let receivedPackets = Self.extractReceivedPacketCount(from: output)
        let hasLoss = output.localizedCaseInsensitiveContains("100.0% packet loss") || output.localizedCaseInsensitiveContains("100% packet loss")

        // Treat a latency-bearing response as success even when ping returns an
        // unexpected nonzero status.  This avoids false critical alerts caused
        // by macOS ping summary/timeout edge cases while still rejecting packet
        // loss and truly missing replies.
        let success = !hasLoss && (process.terminationStatus == 0 || latency != nil || (receivedPackets ?? 0) > 0)

        return PingProbeResult(
            success: success,
            latencyMilliseconds: latency,
            errorMessage: success ? nil : Self.failureMessage(from: output),
            rawOutput: output
        )
    }

    private static func extractLatencyMilliseconds(from output: String) -> Double? {
        // Common reply line format:
        // 64 bytes from 192.168.1.10: icmp_seq=0 ttl=64 time=5.160 ms
        if let range = output.range(of: "time=") {
            let suffix = output[range.upperBound...]
            let valueString = suffix.prefix { character in
                character.isNumber || character == "."
            }
            if let value = Double(valueString) { return value }
        }

        // macOS summary format:
        // round-trip min/avg/max/stddev = 5.160/5.160/5.160/0.000 ms
        // Prefer avg for dashboard display when only the summary is available.
        guard let summaryRange = output.range(of: "round-trip", options: [.caseInsensitive]) else { return nil }
        let summary = output[summaryRange.lowerBound...]
        guard let equalsRange = summary.range(of: "=") else { return nil }
        let suffix = summary[equalsRange.upperBound...]
        let numbers = suffix
            .replacingOccurrences(of: "ms", with: "")
            .split(separator: "/")
            .compactMap { Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        if numbers.count >= 2 { return numbers[1] }
        return numbers.first
    }

    private static func extractReceivedPacketCount(from output: String) -> Int? {
        // Format:
        // 1 packets transmitted, 1 packets received, 0.0% packet loss
        guard let range = output.range(of: "packets received") ?? output.range(of: "packet received") else { return nil }
        let prefix = output[..<range.lowerBound]
        let components = prefix
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        guard let receivedComponent = components.last else { return nil }
        let digits = receivedComponent.prefix { $0.isNumber }
        return Int(digits)
    }

    private static func failureMessage(from output: String) -> String {
        let cleaned = output
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { !$0.hasPrefix("---") }
            .filter { !$0.localizedCaseInsensitiveContains("round-trip") }
            .filter { !$0.localizedCaseInsensitiveContains("packets transmitted") }
        return cleaned.last ?? "Ping failed or timed out"
    }
}
