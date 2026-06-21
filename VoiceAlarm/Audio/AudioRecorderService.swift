import Foundation
import Combine
import AVFoundation

/// Records audio from the microphone into the recordings directory using
/// `AVAudioRecorder`. Exposes simple observable state for SwiftUI.
@MainActor
public final class AudioRecorderService: NSObject, ObservableObject {

    public enum RecorderError: LocalizedError {
        case permissionDenied
        case sessionUnavailable
        case recorderUnavailable

        public var errorDescription: String? {
            switch self {
            case .permissionDenied: return "Microphone access was denied. Enable it in Settings to record."
            case .sessionUnavailable: return "The audio session could not be started."
            case .recorderUnavailable: return "The recorder could not be created."
            }
        }
    }

    @Published public private(set) var isRecording = false
    @Published public private(set) var currentLevel: Float = 0 // 0...1, for a meter
    @Published public private(set) var elapsed: TimeInterval = 0

    private var recorder: AVAudioRecorder?
    private var levelTimer: Timer?
    private let directory: URL
    private(set) var lastOutputURL: URL?

    public init(directory: URL) {
        self.directory = directory
        super.init()
    }

    /// Requests microphone permission. Wraps the iOS-version differences.
    public func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    /// Begins recording into a new file. Returns the destination URL.
    @discardableResult
    public func start() async throws -> URL {
        guard await requestPermission() else { throw RecorderError.permissionDenied }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            throw RecorderError.sessionUnavailable
        }

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileName = "rec-\(UUID().uuidString).m4a"
        let url = directory.appendingPathComponent(fileName)

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        guard let recorder = try? AVAudioRecorder(url: url, settings: settings) else {
            throw RecorderError.recorderUnavailable
        }
        recorder.isMeteringEnabled = true
        recorder.delegate = self
        guard recorder.record() else { throw RecorderError.recorderUnavailable }

        self.recorder = recorder
        self.lastOutputURL = url
        self.isRecording = true
        self.elapsed = 0
        startMetering()
        return url
    }

    /// Stops recording and returns the finished file URL and its duration.
    @discardableResult
    public func stop() -> (url: URL, duration: TimeInterval)? {
        guard let recorder, isRecording else { return nil }
        let duration = recorder.currentTime
        recorder.stop()
        stopMetering()
        isRecording = false
        currentLevel = 0
        let url = recorder.url
        self.recorder = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return (url, duration)
    }

    /// Cancels and discards the in-progress recording.
    public func cancel() {
        guard let recorder else { return }
        recorder.stop()
        try? FileManager.default.removeItem(at: recorder.url)
        stopMetering()
        isRecording = false
        currentLevel = 0
        self.recorder = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func startMetering() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let recorder = self.recorder else { return }
                recorder.updateMeters()
                let power = recorder.averagePower(forChannel: 0) // dB, ~ -160...0
                // Map dB to a 0...1 scale with a sensible noise floor.
                let normalized = max(0, (power + 50) / 50)
                self.currentLevel = min(1, normalized)
                self.elapsed = recorder.currentTime
            }
        }
    }

    private func stopMetering() {
        levelTimer?.invalidate()
        levelTimer = nil
    }
}

extension AudioRecorderService: AVAudioRecorderDelegate {
    public nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            self.isRecording = false
            self.stopMetering()
        }
    }
}
