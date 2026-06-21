import Foundation

/// A tiny, dependency-free persistence primitive: encodes a `Codable` value to
/// a JSON file and decodes it back. Atomic writes guard against corruption if
/// the app is killed mid-write. The directory is injectable so tests can use a
/// temporary location.
public struct JSONFileStore<Value: Codable> {
    private let fileURL: URL
    private let fileManager: FileManager

    public init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    /// Loads the stored value, or returns `defaultValue` if the file is missing.
    /// Throws only on a genuine decode failure of an existing file.
    public func load(default defaultValue: Value) throws -> Value {
        guard fileManager.fileExists(atPath: fileURL.path) else { return defaultValue }
        let data = try Data(contentsOf: fileURL)
        if data.isEmpty { return defaultValue }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Value.self, from: data)
    }

    /// Persists the value, creating the parent directory if needed. Atomic.
    public func save(_ value: Value) throws {
        let directory = fileURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        try data.write(to: fileURL, options: .atomic)
    }
}
