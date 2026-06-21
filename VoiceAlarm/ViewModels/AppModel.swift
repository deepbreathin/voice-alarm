import Foundation
import SwiftUI
import UserNotifications

/// Top-level coordinator. Owns the stores and services, keeps the system
/// notification schedule in sync with the alarms, and handles app lifecycle
/// events (launch re-arm, notification taps, file opens).
@MainActor
public final class AppModel: ObservableObject {

    public let recordingStore: RecordingStore
    public let alarmStore: AlarmStore
    public let recorder: AudioRecorderService
    public let playback: AudioPlaybackService
    public let notifications: NotificationService

    private let paths: AppPaths
    private let planner: AlarmTriggerPlanner
    private let clipPreparer: AudioClipPreparer
    private let importService: ImportService

    /// When set, the UI should present and auto-play this recording (e.g. after
    /// a notification tap).
    @Published public var pendingPlaybackRecordingID: UUID?
    @Published public var lastErrorMessage: String?

    public init(paths: AppPaths = .standard()) {
        self.paths = paths
        paths.ensureDirectories()

        let recordingStore = RecordingStore(paths: paths)
        self.recordingStore = recordingStore
        self.alarmStore = AlarmStore(paths: paths)
        self.recorder = AudioRecorderService(directory: paths.recordingsDirectory)
        self.playback = AudioPlaybackService()
        self.notifications = NotificationService()
        self.planner = AlarmTriggerPlanner()
        self.clipPreparer = AudioClipPreparer(soundsDirectory: AudioClipPreparer.defaultSoundsDirectory())
        self.importService = ImportService(directory: paths.recordingsDirectory)
    }

    // MARK: - Lifecycle

    public func bootstrap() async {
        notifications.registerCategories()
        await notifications.refreshAuthorizationStatus()
        await rescheduleAll()
    }

    public func requestNotificationAuthorization() async {
        _ = await notifications.requestAuthorization()
        await rescheduleAll()
    }

    // MARK: - Recordings

    public func finishRecording(title: String) async {
        guard let result = recorder.stop() else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let recording = Recording(
            title: trimmed.isEmpty ? defaultRecordingTitle() : trimmed,
            fileName: result.url.lastPathComponent,
            duration: result.duration,
            source: .recordedInApp
        )
        recordingStore.upsert(recording)
    }

    private func defaultRecordingTitle() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Recording \(formatter.string(from: Date()))"
    }

    public func importFile(at url: URL) {
        do {
            let recording = try importService.importFile(at: url)
            recordingStore.upsert(recording)
        } catch {
            lastErrorMessage = "Could not import that audio file."
        }
    }

    public func deleteRecording(_ recording: Recording) {
        recordingStore.delete(recording)
        clipPreparer.removeNotificationSound(for: recording.id)
        alarmStore.unlinkRecording(recording.id)
        Task { await rescheduleAll() }
    }

    public func previewURL(for recording: Recording) -> URL {
        recordingStore.url(for: recording)
    }

    // MARK: - Alarms

    public func saveAlarm(_ alarm: Alarm) async {
        alarmStore.upsert(alarm)
        await rescheduleAll()
    }

    public func deleteAlarm(_ alarm: Alarm) async {
        alarmStore.delete(alarm)
        await rescheduleAll()
    }

    public func setAlarm(_ alarm: Alarm, enabled: Bool) async {
        alarmStore.setEnabled(enabled, for: alarm.id)
        await rescheduleAll()
    }

    /// Recomputes the entire notification schedule from current alarms. Called
    /// on launch, on any alarm/recording change, and when returning to
    /// foreground (which re-arms "every N days" rolling windows).
    public func rescheduleAll() async {
        let now = Date()
        let alarms = alarmStore.alarms

        // Make sure every scheduled alarm has an up-to-date ≤30s sound rendered.
        var soundNames: [UUID: String] = [:]
        for alarm in alarms where alarm.isSchedulable {
            guard let recording = recordingStore.recording(withID: alarm.recordingID) else { continue }
            let sourceURL = recordingStore.url(for: recording)
            if let name = try? clipPreparer.prepareNotificationSound(from: sourceURL, recordingID: recording.id) {
                soundNames[alarm.id] = name
            }
        }

        let triggers = planner.triggers(for: alarms, now: now)

        let labels: [UUID: String] = Dictionary(
            alarms.map { ($0.id, $0.label) },
            uniquingKeysWith: { first, _ in first }
        )

        await notifications.reschedule(
            triggers: triggers,
            titleForAlarm: { labels[$0] ?? "Voice Alarm" },
            soundForAlarm: { soundNames[$0] }
        )
    }

    // MARK: - Notification handling

    /// Called when the user taps an alarm notification.
    public func handleNotificationTap(alarmIDString: String?) {
        guard
            let alarmIDString,
            let alarmID = UUID(uuidString: alarmIDString),
            let alarm = alarmStore.alarm(withID: alarmID),
            let recordingID = alarm.recordingID,
            let recording = recordingStore.recording(withID: recordingID)
        else { return }

        // Play the full-length original immediately, and surface it in the UI.
        playback.play(recordingStore.url(for: recording))
        pendingPlaybackRecordingID = recording.id

        // A delivered one-off should be re-evaluated; re-arm rolling windows.
        Task { await rescheduleAll() }
    }

    /// Handles a file opened into the app (Share sheet → "Open in VoiceAlarm",
    /// or "Open With"). Imports it as a recording.
    public func handleOpenURL(_ url: URL) {
        importFile(at: url)
    }

    /// Convenience for the UI: the next fire date for an alarm.
    public func nextFireDate(for alarm: Alarm, now: Date = Date()) -> Date? {
        alarm.nextFireDate(after: now)
    }
}
