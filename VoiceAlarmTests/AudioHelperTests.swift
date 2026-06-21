import XCTest
import AVFoundation
@testable import VoiceAlarm

final class AudioClipPreparerTests: XCTestCase {
    func testClipUnderLimitKeepsAllFrames() {
        // 10s at 44.1kHz, max 30s → keep everything.
        let frames = AVAudioFramePosition(44_100 * 10)
        let result = AudioClipPreparer.clippedFrameCount(totalFrames: frames, sampleRate: 44_100, maxSeconds: 30)
        XCTAssertEqual(result, frames)
    }

    func testClipOverLimitIsTruncated() {
        // 60s at 44.1kHz, max 30s → 30s worth of frames.
        let frames = AVAudioFramePosition(44_100 * 60)
        let result = AudioClipPreparer.clippedFrameCount(totalFrames: frames, sampleRate: 44_100, maxSeconds: 30)
        XCTAssertEqual(result, AVAudioFramePosition(44_100 * 30))
    }

    func testZeroSampleRateReturnsZero() {
        XCTAssertEqual(AudioClipPreparer.clippedFrameCount(totalFrames: 1000, sampleRate: 0), 0)
    }

    func testZeroFramesReturnsZero() {
        XCTAssertEqual(AudioClipPreparer.clippedFrameCount(totalFrames: 0, sampleRate: 44_100), 0)
    }

    func testSoundFileNameIsDeterministicAndCaf() {
        let id = UUID()
        let name = AudioClipPreparer.soundFileName(for: id)
        XCTAssertEqual(name, AudioClipPreparer.soundFileName(for: id))
        XCTAssertTrue(name.hasSuffix(".caf"))
        XCTAssertTrue(name.contains(id.uuidString))
    }

    func testDefaultMaxIsThirtySeconds() {
        XCTAssertEqual(AudioClipPreparer.maxNotificationSeconds, 30)
    }
}

final class ImportServiceTests: XCTestCase {
    func testSafeFileNamePreservesExtension() {
        let id = UUID()
        let name = ImportService.safeFileName(for: "My Memo.m4a", fallbackID: id)
        XCTAssertTrue(name.hasSuffix(".m4a"))
        XCTAssertTrue(name.contains(id.uuidString))
    }

    func testSafeFileNameLowercasesExtension() {
        let name = ImportService.safeFileName(for: "CLIP.WAV")
        XCTAssertTrue(name.hasSuffix(".wav"))
    }

    func testSafeFileNameDefaultsExtensionWhenMissing() {
        let name = ImportService.safeFileName(for: "noextension")
        XCTAssertTrue(name.hasSuffix(".m4a"))
    }

    func testDisplayTitleStripsExtensionAndTidies() {
        XCTAssertEqual(ImportService.displayTitle(from: "morning_wake-up.m4a"), "morning wake up")
        XCTAssertEqual(ImportService.displayTitle(from: "Reminder.wav"), "Reminder")
    }

    func testDisplayTitleFallback() {
        XCTAssertEqual(ImportService.displayTitle(from: ".m4a"), "Imported clip")
    }
}
