import XCTest
@testable import VoiceAlarm

final class JSONFileStoreTests: XCTestCase {
    private var dir: URL!

    override func setUp() {
        super.setUp()
        dir = TestSupport.makeTempDirectory()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
        super.tearDown()
    }

    func testLoadMissingReturnsDefault() throws {
        let store = JSONFileStore<[Int]>(fileURL: dir.appendingPathComponent("missing.json"))
        XCTAssertEqual(try store.load(default: [1, 2, 3]), [1, 2, 3])
    }

    func testSaveThenLoadRoundTrip() throws {
        let store = JSONFileStore<[String]>(fileURL: dir.appendingPathComponent("x.json"))
        try store.save(["a", "b"])
        XCTAssertEqual(try store.load(default: []), ["a", "b"])
    }

    func testSaveCreatesIntermediateDirectories() throws {
        let nested = dir.appendingPathComponent("a/b/c/data.json")
        let store = JSONFileStore<[Int]>(fileURL: nested)
        try store.save([42])
        XCTAssertTrue(FileManager.default.fileExists(atPath: nested.path))
    }

    func testEmptyFileReturnsDefault() throws {
        let url = dir.appendingPathComponent("empty.json")
        try Data().write(to: url)
        let store = JSONFileStore<[Int]>(fileURL: url)
        XCTAssertEqual(try store.load(default: [7]), [7])
    }
}

@MainActor
final class RecordingStoreTests: XCTestCase {
    private var paths: AppPaths!

    override func setUp() {
        super.setUp()
        paths = AppPaths(baseDirectory: TestSupport.makeTempDirectory())
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: paths.baseDirectory)
        super.tearDown()
    }

    /// Writes a dummy audio file so the store's existence-filter keeps the entry.
    private func makeRecording(title: String = "Clip") -> Recording {
        let id = UUID()
        let fileName = "rec-\(id.uuidString).m4a"
        try? FileManager.default.createDirectory(at: paths.recordingsDirectory, withIntermediateDirectories: true)
        let url = paths.recordingsDirectory.appendingPathComponent(fileName)
        try? Data("audio".utf8).write(to: url)
        return Recording(id: id, title: title, fileName: fileName, duration: 12, source: .recordedInApp)
    }

    func testUpsertAndPersistAcrossInstances() {
        let store = RecordingStore(paths: paths)
        let recording = makeRecording()
        store.upsert(recording)
        XCTAssertEqual(store.recordings.count, 1)

        let reloaded = RecordingStore(paths: paths)
        XCTAssertEqual(reloaded.recordings.count, 1)
        XCTAssertEqual(reloaded.recordings.first?.id, recording.id)
    }

    func testUpsertReplacesExisting() {
        let store = RecordingStore(paths: paths)
        var recording = makeRecording(title: "Original")
        store.upsert(recording)
        recording.title = "Updated"
        store.upsert(recording)
        XCTAssertEqual(store.recordings.count, 1)
        XCTAssertEqual(store.recordings.first?.title, "Updated")
    }

    func testRename() {
        let store = RecordingStore(paths: paths)
        let recording = makeRecording()
        store.upsert(recording)
        store.rename(recording, to: "  New Name  ")
        XCTAssertEqual(store.recordings.first?.title, "New Name")
    }

    func testDeleteRemovesMetadataAndFile() {
        let store = RecordingStore(paths: paths)
        let recording = makeRecording()
        store.upsert(recording)
        let url = store.url(for: recording)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        store.delete(recording)
        XCTAssertTrue(store.recordings.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testLoadDropsEntriesWithMissingFiles() {
        let store = RecordingStore(paths: paths)
        let recording = makeRecording()
        store.upsert(recording)
        // Delete the underlying file behind the store's back.
        try? FileManager.default.removeItem(at: store.url(for: recording))
        let reloaded = RecordingStore(paths: paths)
        XCTAssertTrue(reloaded.recordings.isEmpty)
    }

    func testLookupByID() {
        let store = RecordingStore(paths: paths)
        let recording = makeRecording()
        store.upsert(recording)
        XCTAssertEqual(store.recording(withID: recording.id)?.id, recording.id)
        XCTAssertNil(store.recording(withID: UUID()))
        XCTAssertNil(store.recording(withID: nil))
    }
}

@MainActor
final class AlarmStoreTests: XCTestCase {
    private var paths: AppPaths!

    override func setUp() {
        super.setUp()
        paths = AppPaths(baseDirectory: TestSupport.makeTempDirectory())
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: paths.baseDirectory)
        super.tearDown()
    }

    private func alarm(hour: Int, minute: Int = 0, recordingID: UUID? = UUID()) -> Alarm {
        Alarm(recordingID: recordingID, time: TimeOfDay(hour: hour, minute: minute), recurrence: .weekly(days: [.monday]))
    }

    func testUpsertSortsByTime() {
        let store = AlarmStore(paths: paths)
        store.upsert(alarm(hour: 9))
        store.upsert(alarm(hour: 6))
        store.upsert(alarm(hour: 7, minute: 30))
        XCTAssertEqual(store.alarms.map { $0.time.hour }, [6, 7, 9])
    }

    func testPersistAcrossInstances() {
        let store = AlarmStore(paths: paths)
        store.upsert(alarm(hour: 8))
        let reloaded = AlarmStore(paths: paths)
        XCTAssertEqual(reloaded.alarms.count, 1)
    }

    func testSetEnabled() {
        let store = AlarmStore(paths: paths)
        let a = alarm(hour: 8)
        store.upsert(a)
        store.setEnabled(false, for: a.id)
        XCTAssertEqual(store.alarm(withID: a.id)?.isEnabled, false)
    }

    func testDelete() {
        let store = AlarmStore(paths: paths)
        let a = alarm(hour: 8)
        store.upsert(a)
        store.delete(a)
        XCTAssertTrue(store.alarms.isEmpty)
    }

    func testUnlinkRecordingDisablesAffectedAlarms() {
        let store = AlarmStore(paths: paths)
        let recID = UUID()
        let a = alarm(hour: 8, recordingID: recID)
        let b = alarm(hour: 9, recordingID: UUID())
        store.upsert(a)
        store.upsert(b)
        store.unlinkRecording(recID)
        XCTAssertNil(store.alarm(withID: a.id)?.recordingID)
        XCTAssertEqual(store.alarm(withID: a.id)?.isEnabled, false)
        XCTAssertNotNil(store.alarm(withID: b.id)?.recordingID)
    }
}
