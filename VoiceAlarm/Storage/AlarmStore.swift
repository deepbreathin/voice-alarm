import Foundation
import Combine

/// Persists the list of `Alarm`s. Main-actor confined to back SwiftUI state.
@MainActor
public final class AlarmStore: ObservableObject {
    @Published public private(set) var alarms: [Alarm] = []

    private let store: JSONFileStore<[Alarm]>

    public init(paths: AppPaths, fileManager: FileManager = .default) {
        self.store = JSONFileStore<[Alarm]>(fileURL: paths.alarmsFile, fileManager: fileManager)
        load()
    }

    public func load() {
        alarms = (try? store.load(default: [])) ?? []
        sort()
    }

    private func persist() {
        try? store.save(alarms)
    }

    /// Keeps alarms ordered by time of day for a stable, predictable list.
    private func sort() {
        alarms.sort { lhs, rhs in
            if lhs.time != rhs.time { return lhs.time < rhs.time }
            return lhs.createdAt < rhs.createdAt
        }
    }

    public func alarm(withID id: UUID) -> Alarm? {
        alarms.first { $0.id == id }
    }

    public func upsert(_ alarm: Alarm) {
        if let index = alarms.firstIndex(where: { $0.id == alarm.id }) {
            alarms[index] = alarm
        } else {
            alarms.append(alarm)
        }
        sort()
        persist()
    }

    public func setEnabled(_ enabled: Bool, for id: UUID) {
        guard let index = alarms.firstIndex(where: { $0.id == id }) else { return }
        alarms[index].isEnabled = enabled
        persist()
    }

    public func delete(_ alarm: Alarm) {
        alarms.removeAll { $0.id == alarm.id }
        persist()
    }

    public func delete(at offsets: IndexSet) {
        alarms.remove(atOffsets: offsets)
        persist()
    }

    /// Clears the recording reference from any alarms that used a now-deleted
    /// recording, so they stop being schedulable until reassigned.
    public func unlinkRecording(_ recordingID: UUID) {
        var changed = false
        for index in alarms.indices where alarms[index].recordingID == recordingID {
            alarms[index].recordingID = nil
            alarms[index].isEnabled = false
            changed = true
        }
        if changed { persist() }
    }
}
