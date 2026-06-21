import Foundation

/// Where a recording came from.
public enum RecordingSource: String, Codable, Sendable {
    case recordedInApp
    case imported
}

/// Metadata for a single voice clip stored in the app's sandbox.
///
/// Only the `fileName` (a path component) is persisted — never an absolute URL.
/// Absolute container paths change between app launches/installs on iOS, so the
/// concrete file URL is always resolved at runtime against the recordings
/// directory. See `AppPaths`.
public struct Recording: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    /// File name (last path component) inside the recordings directory.
    public var fileName: String
    /// Clip length in seconds.
    public var duration: TimeInterval
    public var createdAt: Date
    public var source: RecordingSource

    public init(
        id: UUID = UUID(),
        title: String,
        fileName: String,
        duration: TimeInterval,
        createdAt: Date = Date(),
        source: RecordingSource
    ) {
        self.id = id
        self.title = title
        self.fileName = fileName
        self.duration = duration
        self.createdAt = createdAt
        self.source = source
    }

    /// Resolves the on-disk location against a recordings directory.
    public func fileURL(in directory: URL) -> URL {
        directory.appendingPathComponent(fileName)
    }
}
