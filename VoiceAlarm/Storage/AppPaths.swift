import Foundation

/// Resolves the on-disk locations the app uses. Centralised so that both the
/// app and tests agree on directory layout, and so paths are always computed
/// fresh (iOS container paths are not stable across launches).
public struct AppPaths {
    public let baseDirectory: URL
    private let fileManager: FileManager

    /// - Parameter baseDirectory: the root under which app data lives. In the
    ///   app this is Application Support; in tests it's a temp directory.
    public init(baseDirectory: URL, fileManager: FileManager = .default) {
        self.baseDirectory = baseDirectory
        self.fileManager = fileManager
    }

    /// The default production paths, rooted at Application Support.
    public static func standard(fileManager: FileManager = .default) -> AppPaths {
        let appSupport = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fileManager.temporaryDirectory
        let base = appSupport.appendingPathComponent("VoiceAlarm", isDirectory: true)
        return AppPaths(baseDirectory: base, fileManager: fileManager)
    }

    /// Directory holding the audio clips.
    public var recordingsDirectory: URL {
        baseDirectory.appendingPathComponent("Recordings", isDirectory: true)
    }

    /// JSON file holding recording metadata.
    public var recordingsFile: URL {
        baseDirectory.appendingPathComponent("recordings.json")
    }

    /// JSON file holding alarms.
    public var alarmsFile: URL {
        baseDirectory.appendingPathComponent("alarms.json")
    }

    /// Ensures all required directories exist.
    @discardableResult
    public func ensureDirectories() -> Bool {
        do {
            try fileManager.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true)
            return true
        } catch {
            return false
        }
    }
}
