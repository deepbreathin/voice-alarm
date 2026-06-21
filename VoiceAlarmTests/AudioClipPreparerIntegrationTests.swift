import XCTest
import AVFoundation
@testable import VoiceAlarm

/// Exercises the real audio read/trim/write path (runs on the simulator).
final class AudioClipPreparerIntegrationTests: XCTestCase {
    private var dir: URL!

    override func setUp() {
        super.setUp()
        dir = TestSupport.makeTempDirectory()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
        super.tearDown()
    }

    /// Writes a mono PCM WAV tone of the given length to a temp file.
    private func writeTone(seconds: Double, sampleRate: Double = 44_100) throws -> URL {
        let url = dir.appendingPathComponent("source-\(UUID().uuidString).wav")
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false)!
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]
        let file = try AVAudioFile(forWriting: url, settings: settings)
        let totalFrames = AVAudioFrameCount(seconds * sampleRate)
        let chunk: AVAudioFrameCount = 4096
        var written: AVAudioFrameCount = 0
        var phase: Float = 0
        let increment = Float(2.0 * Double.pi * 440.0 / sampleRate)
        while written < totalFrames {
            let thisChunk = min(chunk, totalFrames - written)
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: thisChunk)!
            buffer.frameLength = thisChunk
            let channel = buffer.floatChannelData![0]
            for i in 0..<Int(thisChunk) {
                channel[i] = sin(phase) * 0.2
                phase += increment
            }
            try file.write(from: buffer)
            written += thisChunk
        }
        return url
    }

    private func duration(of url: URL) throws -> Double {
        let file = try AVAudioFile(forReading: url)
        return Double(file.length) / file.processingFormat.sampleRate
    }

    func testShortClipIsCopiedWhole() throws {
        let source = try writeTone(seconds: 3)
        let preparer = AudioClipPreparer(soundsDirectory: dir.appendingPathComponent("Sounds"))
        let recordingID = UUID()
        let name = try preparer.prepareNotificationSound(from: source, recordingID: recordingID)

        let output = dir.appendingPathComponent("Sounds").appendingPathComponent(name)
        XCTAssertTrue(FileManager.default.fileExists(atPath: output.path))
        XCTAssertEqual(try duration(of: output), 3, accuracy: 0.2)
    }

    func testLongClipIsTrimmedTo30Seconds() throws {
        let source = try writeTone(seconds: 40)
        let preparer = AudioClipPreparer(soundsDirectory: dir.appendingPathComponent("Sounds"))
        let name = try preparer.prepareNotificationSound(from: source, recordingID: UUID())

        let output = dir.appendingPathComponent("Sounds").appendingPathComponent(name)
        XCTAssertEqual(try duration(of: output), 30, accuracy: 0.3)
    }

    func testPreparingTwiceReplacesOutput() throws {
        let preparer = AudioClipPreparer(soundsDirectory: dir.appendingPathComponent("Sounds"))
        let id = UUID()
        let shortSource = try writeTone(seconds: 2)
        _ = try preparer.prepareNotificationSound(from: shortSource, recordingID: id)
        let longSource = try writeTone(seconds: 10)
        let name = try preparer.prepareNotificationSound(from: longSource, recordingID: id)

        let output = dir.appendingPathComponent("Sounds").appendingPathComponent(name)
        XCTAssertEqual(try duration(of: output), 10, accuracy: 0.2)
    }

    func testRemoveNotificationSound() throws {
        let preparer = AudioClipPreparer(soundsDirectory: dir.appendingPathComponent("Sounds"))
        let id = UUID()
        let source = try writeTone(seconds: 2)
        let name = try preparer.prepareNotificationSound(from: source, recordingID: id)
        let output = dir.appendingPathComponent("Sounds").appendingPathComponent(name)
        XCTAssertTrue(FileManager.default.fileExists(atPath: output.path))

        preparer.removeNotificationSound(for: id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: output.path))
    }
}
