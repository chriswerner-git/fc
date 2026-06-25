//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                    │
//  │  Flight Control                                             │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: AudioInputLevelMonitorService.swift
//  Purpose: Opens the selected macOS audio input for Audio LTC sources,
//           publishes lightweight signal/level information, and feeds audio
//           samples into Flight Control's native SMPTE LTC decoder.
//
//  Created by Chris Werner / Lunar Telephone Company.
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import AVFoundation
import CoreMedia
import Foundation

/// Lightweight runtime level state for a configured Audio LTC source.
/// This is intentionally app-local and not persisted.
struct TimecodeAudioLevelState: Hashable, Sendable {
    var sourceID: UUID
    var updatedAt: Date
    var decibels: Double?
    var linearRMS: Double
    var peak: Double
    var signalPresent: Bool
    var isCaptureRunning: Bool
    var message: String
    var decodedTimecodeText: String? = nil
    var decodedFrameRate: TimecodeFrameRate? = nil
    var decodedAt: Date? = nil
    var decoderMessage: String? = nil

    static func inactive(sourceID: UUID, message: String = "Audio capture inactive") -> TimecodeAudioLevelState {
        TimecodeAudioLevelState(
            sourceID: sourceID,
            updatedAt: Date(),
            decibels: nil,
            linearRMS: 0,
            peak: 0,
            signalPresent: false,
            isCaptureRunning: false,
            message: message,
            decodedTimecodeText: nil,
            decodedFrameRate: nil,
            decodedAt: nil,
            decoderMessage: nil
        )
    }

    var levelDescription: String {
        guard let decibels else { return message }
        return String(format: "%.1f dBFS%@", decibels, signalPresent ? "" : " · no signal")
    }
}

/// Captures audio from one selected macOS input device, reports level, and
/// performs a first-pass native SMPTE LTC decode.
///
/// Notes:
/// - This implementation monitors the selected dashboard/source input.
/// - Multiple simultaneous audio devices will require one capture session per
///   device or a more advanced Core Audio HAL path in a later pass.
/// - The native decoder is intentionally conservative; it reports level even
///   when LTC sync has not yet been established.
final class AudioInputLevelMonitorService: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate {
    var onLevelUpdate: ((TimecodeAudioLevelState) -> Void)?

    private let sessionQueue = DispatchQueue(label: "com.lunartelephone.flightcontrol.audio-level-session", qos: .utility)
    private let sampleQueue = DispatchQueue(label: "com.lunartelephone.flightcontrol.audio-level-samples", qos: .utility)

    private var session: AVCaptureSession?
    private var monitoredSource: TimecodeSourceConfiguration?
    private var lastPublishTime: Date = .distantPast
    private let ltcDecoder = TimecodeLTCDecoderService()
    private var lastDecodeResult: TimecodeLTCDecodeResult?
    private var decodeSampleBuffer: [Float] = []
    private var decodeBufferSampleRate: Double = 0

    @MainActor
    func startMonitoring(source: TimecodeSourceConfiguration) {
        guard source.type == .audioLTC, source.enabled else {
            stopMonitoring(reason: "Audio LTC source is disabled or not selected.")
            return
        }

        guard source.inputSourceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            stopMonitoring(reason: "Audio input device has not been selected.")
            return
        }

        // macOS will terminate an app that touches audio capture without this privacy key.
        // During development this is easy to miss because the key lives in target Info
        // settings rather than Swift source. Fail closed and report a useful status instead
        // of allowing AVCaptureSession to trigger a privacy abort.
        guard Self.hasMicrophoneUsageDescription else {
            stopMonitoring(reason: "Audio input monitoring requires the app Info setting: Privacy - Microphone Usage Description.")
            return
        }

        let previousSourceID = monitoredSource?.id
        let previousInputID = monitoredSource?.inputSourceID
        let previousChannel = monitoredSource?.audioChannel
        monitoredSource = source

        // Avoid tearing down and rebuilding the capture graph if nothing important changed.
        guard session == nil || previousSourceID != source.id || previousInputID != source.inputSourceID || previousChannel != source.audioChannel else { return }

        stopSessionOnly()
        ltcDecoder.reset()
        lastDecodeResult = nil
        decodeSampleBuffer.removeAll(keepingCapacity: true)
        decodeBufferSampleRate = 0

        let selectedDeviceID = source.inputSourceID
        let selectedSourceID = source.id

        sessionQueue.async { [weak self] in
            guard let self else { return }

            let status = AVCaptureDevice.authorizationStatus(for: .audio)

            if status == .notDetermined {
                AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                    guard let self else { return }
                    if granted {
                        Task { @MainActor in
                            self.startMonitoring(source: source)
                        }
                    } else {
                        self.publishInactive(sourceID: selectedSourceID, message: Self.authorizationMessage(for: .denied))
                    }
                }
                return
            }

            guard status == .authorized else {
                self.publishInactive(sourceID: selectedSourceID, message: Self.authorizationMessage(for: status))
                return
            }

            guard let device = AVCaptureDevice.devices(for: .audio).first(where: { $0.uniqueID == selectedDeviceID }) else {
                self.publishInactive(sourceID: selectedSourceID, message: "Selected audio input is not currently available.")
                return
            }

            do {
                let session = AVCaptureSession()
                session.beginConfiguration()

                let input = try AVCaptureDeviceInput(device: device)
                guard session.canAddInput(input) else {
                    self.publishInactive(sourceID: selectedSourceID, message: "Selected audio input could not be added to the capture session.")
                    return
                }
                session.addInput(input)

                let output = AVCaptureAudioDataOutput()
                if session.canAddOutput(output) == false {
                    self.publishInactive(sourceID: selectedSourceID, message: "Audio level output could not be added to the capture session.")
                    return
                }
                output.setSampleBufferDelegate(self, queue: self.sampleQueue)
                session.addOutput(output)

                session.commitConfiguration()
                self.session = session
                session.startRunning()

                self.publish(
                    TimecodeAudioLevelState(
                        sourceID: selectedSourceID,
                        updatedAt: Date(),
                        decibels: nil,
                        linearRMS: 0,
                        peak: 0,
                        signalPresent: false,
                        isCaptureRunning: true,
                        message: "Audio capture started. Waiting for signal."
                    )
                )
            } catch {
                self.publishInactive(sourceID: selectedSourceID, message: "Could not open audio input: \(error.localizedDescription)")
            }
        }
    }

    @MainActor
    func stopMonitoring(reason: String = "Audio capture stopped") {
        let sourceID = monitoredSource?.id
        monitoredSource = nil
        stopSessionOnly()
        if let sourceID {
            publishInactive(sourceID: sourceID, message: reason)
        }
    }

    private func stopSessionOnly() {
        let existingSession = session
        session = nil
        ltcDecoder.reset()
        lastDecodeResult = nil
        decodeSampleBuffer.removeAll(keepingCapacity: true)
        decodeBufferSampleRate = 0
        sessionQueue.async {
            if existingSession?.isRunning == true {
                existingSession?.stopRunning()
            }
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let source = monitoredSource else { return }

        let extracted = Self.extractChannelSamples(sampleBuffer: sampleBuffer, channelIndex: source.audioChannel.zeroBasedChannelIndex)
        let samples = extracted.samples
        let level = Self.measureLevel(samples: samples)
        let decibels = level.rms > 0.000_001 ? max(-120.0, min(0.0, 20.0 * log10(level.rms))) : -120.0
        let signalPresent = decibels > -55.0

        // Only run the LTC decoder when there is meaningful signal present.
        // Audio callbacks can arrive very frequently. To reduce CPU, collect a
        // short contiguous chunk before calling the decoder rather than crossing
        // the Swift/C decoder boundary for every individual callback buffer.
        if signalPresent {
            appendSamplesForDecode(
                samples,
                sampleRate: extracted.sampleRate,
                polarityMode: source.polarityMode
            )
        } else {
            ltcDecoder.reset()
            lastDecodeResult = nil
            decodeSampleBuffer.removeAll(keepingCapacity: true)
            decodeBufferSampleRate = 0
        }

        // Publish at a bounded rate. We need continuous audio samples for the
        // decoder, but UI/status updates do not need every audio buffer.
        let now = Date()
        guard now.timeIntervalSince(lastPublishTime) >= 0.20 else { return }
        lastPublishTime = now

        let decodeResult = lastDecodeResult
        let decodeIsRecent = decodeResult.map { now.timeIntervalSince($0.decodedAt) <= max(0.5, source.staleTimeoutSeconds) } ?? false

        publish(
            TimecodeAudioLevelState(
                sourceID: source.id,
                updatedAt: now,
                decibels: decibels,
                linearRMS: level.rms,
                peak: level.peak,
                signalPresent: signalPresent,
                isCaptureRunning: true,
                message: signalPresent ? "Audio signal present" : "No meaningful audio signal detected",
                decodedTimecodeText: decodeResult?.timecodeText,
                decodedFrameRate: decodeResult?.frameRate,
                decodedAt: decodeResult?.decodedAt,
                decoderMessage: decodeIsRecent ? decodeResult?.message : (signalPresent ? "Audio signal present. Waiting for LTC sync." : nil)
            )
        )
    }


    private func appendSamplesForDecode(_ samples: [Float], sampleRate: Double, polarityMode: TimecodePolarityMode) {
        guard samples.isEmpty == false, sampleRate > 0 else { return }

        if decodeBufferSampleRate <= 0 || abs(decodeBufferSampleRate - sampleRate) > 1.0 {
            decodeSampleBuffer.removeAll(keepingCapacity: true)
            decodeBufferSampleRate = sampleRate
            ltcDecoder.reset()
            lastDecodeResult = nil
        }

        decodeSampleBuffer.append(contentsOf: samples)

        // Approximately 50 ms is long enough to include a full LTC frame at
        // common rates while keeping dashboard latency low. Cap retained data so
        // a temporarily stalled decoder cannot grow memory.
        let targetChunkSize = max(512, Int(sampleRate * 0.050))
        let maximumBufferedSamples = max(targetChunkSize * 3, Int(sampleRate * 0.20))

        if decodeSampleBuffer.count > maximumBufferedSamples {
            decodeSampleBuffer.removeFirst(decodeSampleBuffer.count - maximumBufferedSamples)
        }

        guard decodeSampleBuffer.count >= targetChunkSize else { return }

        let chunk = Array(decodeSampleBuffer.prefix(targetChunkSize))
        decodeSampleBuffer.removeFirst(min(targetChunkSize, decodeSampleBuffer.count))

        if let decodeResult = ltcDecoder.process(
            samples: chunk,
            sampleRate: sampleRate,
            polarityMode: polarityMode
        ) {
            lastDecodeResult = decodeResult
        }
    }

    private func publishInactive(sourceID: UUID, message: String) {
        publish(.inactive(sourceID: sourceID, message: message))
    }

    private func publish(_ state: TimecodeAudioLevelState) {
        DispatchQueue.main.async { [onLevelUpdate] in
            onLevelUpdate?(state)
        }
    }

    private static var hasMicrophoneUsageDescription: Bool {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "NSMicrophoneUsageDescription") as? String else {
            return false
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private static func authorizationMessage(for status: AVAuthorizationStatus) -> String {
        switch status {
        case .authorized:
            return "Audio input permission granted."
        case .notDetermined:
            return "Audio input permission has not been granted yet. Refresh inputs or open the source to trigger macOS permission."
        case .denied:
            return "Audio input permission denied in macOS Privacy & Security settings."
        case .restricted:
            return "Audio input permission is restricted by this Mac."
        @unknown default:
            return "Audio input permission status is unknown."
        }
    }

    private static func extractChannelSamples(sampleBuffer: CMSampleBuffer, channelIndex: Int) -> (samples: [Float], sampleRate: Double) {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbdPointer = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) else {
            return ([], 0)
        }

        let asbd = asbdPointer.pointee
        let sampleRate = asbd.mSampleRate
        let bytesPerSample = max(1, Int(asbd.mBitsPerChannel / 8))
        let channelCount = max(1, Int(asbd.mChannelsPerFrame))
        let selectedChannel = min(max(0, channelIndex), channelCount - 1)
        let isFloat = (asbd.mFormatFlags & kAudioFormatFlagIsFloat) != 0
        let isSignedInteger = (asbd.mFormatFlags & kAudioFormatFlagIsSignedInteger) != 0
        let isNonInterleaved = (asbd.mFormatFlags & kAudioFormatFlagIsNonInterleaved) != 0

        var neededSize = 0
        var blockBuffer: CMBlockBuffer?
        var status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: &neededSize,
            bufferListOut: nil,
            bufferListSize: 0,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: 0,
            blockBufferOut: &blockBuffer
        )

        guard status == noErr, neededSize > 0 else { return ([], sampleRate) }

        let rawPointer = UnsafeMutableRawPointer.allocate(byteCount: neededSize, alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { rawPointer.deallocate() }

        let audioBufferListPointer = rawPointer.bindMemory(to: AudioBufferList.self, capacity: 1)
        status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: audioBufferListPointer,
            bufferListSize: neededSize,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: 0,
            blockBufferOut: &blockBuffer
        )

        guard status == noErr else { return ([], sampleRate) }

        let buffers = UnsafeMutableAudioBufferListPointer(audioBufferListPointer)
        var samples: [Float] = []
        samples.reserveCapacity(4096)

        for bufferIndex in buffers.indices {
            let buffer = buffers[bufferIndex]
            guard let data = buffer.mData else { continue }

            if isNonInterleaved, buffers.count > 1, bufferIndex != selectedChannel { continue }

            let byteCount = Int(buffer.mDataByteSize)
            if isFloat, bytesPerSample == 4 {
                let values = data.bindMemory(to: Float.self, capacity: byteCount / MemoryLayout<Float>.size)
                let valueCount = byteCount / MemoryLayout<Float>.size
                let stride = isNonInterleaved ? 1 : channelCount
                let start = isNonInterleaved ? 0 : selectedChannel
                var index = start
                while index < valueCount {
                    samples.append(max(-1.0, min(1.0, values[index])))
                    index += stride
                }
            } else if isSignedInteger, bytesPerSample == 2 {
                let values = data.bindMemory(to: Int16.self, capacity: byteCount / MemoryLayout<Int16>.size)
                let valueCount = byteCount / MemoryLayout<Int16>.size
                let stride = isNonInterleaved ? 1 : channelCount
                let start = isNonInterleaved ? 0 : selectedChannel
                var index = start
                while index < valueCount {
                    samples.append(Float(Double(values[index]) / Double(Int16.max)))
                    index += stride
                }
            } else if isSignedInteger, bytesPerSample == 4 {
                let values = data.bindMemory(to: Int32.self, capacity: byteCount / MemoryLayout<Int32>.size)
                let valueCount = byteCount / MemoryLayout<Int32>.size
                let stride = isNonInterleaved ? 1 : channelCount
                let start = isNonInterleaved ? 0 : selectedChannel
                var index = start
                while index < valueCount {
                    samples.append(Float(Double(values[index]) / Double(Int32.max)))
                    index += stride
                }
            }
        }

        return (samples, sampleRate)
    }

    private static func measureLevel(samples: [Float]) -> (rms: Double, peak: Double) {
        guard samples.isEmpty == false else { return (0, 0) }
        var sumSquares = 0.0
        var peak = 0.0
        for sample in samples {
            let value = Double(sample)
            let magnitude = abs(value)
            sumSquares += value * value
            peak = max(peak, magnitude)
        }
        return (sqrt(sumSquares / Double(samples.count)), min(1.0, peak))
    }

}

private extension TimecodeAudioChannel {
    var zeroBasedChannelIndex: Int {
        switch self {
        case .left, .channel1:
            return 0
        case .right, .channel2:
            return 1
        }
    }
}
