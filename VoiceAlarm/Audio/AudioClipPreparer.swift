import Foundation
import AVFoundation

/// Prepares the short, notification-playable copy of a recording.
///
/// ## Why this exists
/// iOS local-notification sounds are heavily constrained:
/// * they must live in the app container's `Library/Sounds` directory,
/// * they must be **≤ 30 seconds**, and
/// * they must be CAF / AIFF / WAV (not the M4A that recordings/Voice Memos use).
///
/// So for every recording attached to an alarm we render a ≤30s CAF copy into
/// `Library/Sounds`. The full-length original is still played in-app when the
/// user opens the alarm. See `docs/iOS-LIMITATIONS.md`.
public struct AudioClipPreparer {

    /// Apple's hard limit for custom notification sounds.
    public static let maxNotificationSeconds: TimeInterval = 30

    public enum PreparationError: Error {
        case couldNotReadSource
        case couldNotCreateOutput
    }

    /// Pure helper: how many audio frames to copy given the source length, its
    /// sample rate, and the maximum allowed seconds. Extracted so the trimming
    /// arithmetic can be unit-tested without real audio files.
    public static func clippedFrameCount(
        totalFrames: AVAudioFramePosition,
        sampleRate: Double,
        maxSeconds: TimeInterval = maxNotificationSeconds
    ) -> AVAudioFramePosition {
        guard sampleRate > 0, totalFrames > 0 else { return 0 }
        let maxFrames = AVAudioFramePosition((maxSeconds * sampleRate).rounded(.down))
        return min(totalFrames, max(0, maxFrames))
    }

    private let soundsDirectory: URL
    private let fileManager: FileManager

    /// - Parameter soundsDirectory: where to write notification sounds. In the
    ///   app this is `Library/Sounds`; injectable for tests.
    public init(soundsDirectory: URL, fileManager: FileManager = .default) {
        self.soundsDirectory = soundsDirectory
        self.fileManager = fileManager
    }

    /// The `Library/Sounds` directory inside the app container.
    public static func defaultSoundsDirectory(fileManager: FileManager = .default) -> URL {
        let library = (try? fileManager.url(
            for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )) ?? fileManager.temporaryDirectory
        return library.appendingPathComponent("Sounds", isDirectory: true)
    }

    /// The notification-sound file name for a given recording id (deterministic
    /// so we can find/replace it). `UNNotificationSound(named:)` takes exactly
    /// this last path component.
    public static func soundFileName(for recordingID: UUID) -> String {
        "alarm-\(recordingID.uuidString).caf"
    }

    /// Renders (or refreshes) the ≤30s CAF notification sound for a recording.
    /// Returns the sound file name to hand to `UNNotificationSound(named:)`.
    @discardableResult
    public func prepareNotificationSound(
        from sourceURL: URL,
        recordingID: UUID
    ) throws -> String {
        try fileManager.createDirectory(at: soundsDirectory, withIntermediateDirectories: true)

        let fileName = Self.soundFileName(for: recordingID)
        let outputURL = soundsDirectory.appendingPathComponent(fileName)
        if fileManager.fileExists(atPath: outputURL.path) {
            try? fileManager.removeItem(at: outputURL)
        }

        let sourceFile: AVAudioFile
        do {
            sourceFile = try AVAudioFile(forReading: sourceURL)
        } catch {
            throw PreparationError.couldNotReadSource
        }

        let processingFormat = sourceFile.processingFormat
        let sampleRate = processingFormat.sampleRate
        let framesToCopy = Self.clippedFrameCount(
            totalFrames: sourceFile.length,
            sampleRate: sampleRate
        )
        guard framesToCopy > 0 else { throw PreparationError.couldNotReadSource }

        // Write a CAF using the source's channel layout / sample rate.
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: Int(processingFormat.channelCount),
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]

        let outputFile: AVAudioFile
        do {
            outputFile = try AVAudioFile(forWriting: outputURL, settings: outputSettings)
        } catch {
            throw PreparationError.couldNotCreateOutput
        }

        let chunkSize: AVAudioFrameCount = 4096
        var remaining = framesToCopy
        while remaining > 0 {
            let thisChunk = AVAudioFrameCount(min(AVAudioFramePosition(chunkSize), remaining))
            guard let buffer = AVAudioPCMBuffer(pcmFormat: processingFormat, frameCapacity: thisChunk) else {
                break
            }
            try sourceFile.read(into: buffer, frameCount: thisChunk)
            if buffer.frameLength == 0 { break }
            try outputFile.write(from: buffer)
            remaining -= AVAudioFramePosition(buffer.frameLength)
            if buffer.frameLength < thisChunk { break } // reached EOF early
        }

        return fileName
    }

    /// Removes a recording's notification sound (called when a recording is
    /// deleted) to keep `Library/Sounds` tidy.
    public func removeNotificationSound(for recordingID: UUID) {
        let url = soundsDirectory.appendingPathComponent(Self.soundFileName(for: recordingID))
        try? fileManager.removeItem(at: url)
    }
}
