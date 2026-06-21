import Foundation
import Combine

/// Persists the list of `Recording` metadata and owns the audio files on disk.
/// Thread-confined to the main actor because it backs SwiftUI state.
@MainActor
public final class RecordingStore: ObservableObject {
    @Published public private(set) var recordings: [Recording] = []

    private let paths: AppPaths
    private let store: JSONFileStore<[Recording]>
    private let fileManager: FileManager

    public init(paths: AppPaths, fileManager: FileManager = .default) {
        self.paths = paths
        self.fileManager = fileManager
        self.store = JSONFileStore<[Recording]>(fileURL: paths.recordingsFile, fileManager: fileManager)
        paths.ensureDirectories()
        load()
    }

    public var recordingsDirectory: URL { paths.recordingsDirectory }

    public func url(for recording: Recording) -> URL {
        recording.fileURL(in: paths.recordingsDirectory)
    }

    public func recording(withID id: UUID?) -> Recording? {
        guard let id else { return nil }
        return recordings.first { $0.id == id }
    }

    public func load() {
        recordings = (try? store.load(default: [])) ?? []
        // Drop any entries whose audio file has gone missing so the UI never
        // references a dead file.
        recordings = recordings.filter { fileManager.fileExists(atPath: url(for: $0).path) }
    }

    private func persist() {
        try? store.save(recordings)
    }

    /// Adds (or replaces by id) a recording and persists.
    public func upsert(_ recording: Recording) {
        if let index = recordings.firstIndex(where: { $0.id == recording.id }) {
            recordings[index] = recording
        } else {
            recordings.insert(recording, at: 0)
        }
        persist()
    }

    public func rename(_ recording: Recording, to title: String) {
        guard let index = recordings.firstIndex(where: { $0.id == recording.id }) else { return }
        recordings[index].title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        persist()
    }

    /// Deletes a recording's metadata and its audio file.
    public func delete(_ recording: Recording) {
        try? fileManager.removeItem(at: url(for: recording))
        recordings.removeAll { $0.id == recording.id }
        persist()
    }
}
