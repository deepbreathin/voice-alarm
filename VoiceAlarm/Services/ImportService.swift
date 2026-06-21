import Foundation
import AVFoundation

/// Imports external audio files (from the Files app, iCloud Drive, or shared
/// out of Voice Memos via the share sheet) into the recordings directory.
///
/// Direct access to the system Voice Memos library is **not possible** on iOS —
/// it lives in another app's sandbox with no public API. The supported path is
/// to share/export a memo into this app, which routes through here. See
/// `docs/iOS-LIMITATIONS.md`.
public struct ImportService {

    public enum ImportError: Error {
        case cannotAccessFile
        case copyFailed
    }

    private let directory: URL
    private let fileManager: FileManager

    public init(directory: URL, fileManager: FileManager = .default) {
        self.directory = directory
        self.fileManager = fileManager
    }

    /// Sanitises an arbitrary file name into a safe stored file name while
    /// preserving the extension. Pure and testable.
    public static func safeFileName(for originalName: String, fallbackID: UUID = UUID()) -> String {
        let ext = (originalName as NSString).pathExtension.lowercased()
        let safeExt = ext.isEmpty ? "m4a" : ext
        return "import-\(fallbackID.uuidString).\(safeExt)"
    }

    /// Derives a display title from a file name (strips extension, tidies it).
    /// Pure and testable.
    public static func displayTitle(from originalName: String) -> String {
        let base = (originalName as NSString).deletingPathExtension
        let cleaned = base
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Imported clip" : cleaned
    }

    /// Copies a security-scoped external URL into the recordings directory and
    /// returns a `Recording`. Reads the real duration from the audio file.
    public func importFile(at sourceURL: URL, isSecurityScoped: Bool = true) throws -> Recording {
        var didStartAccess = false
        if isSecurityScoped {
            didStartAccess = sourceURL.startAccessingSecurityScopedResource()
        }
        defer { if didStartAccess { sourceURL.stopAccessingSecurityScopedResource() } }

        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let id = UUID()
        let originalName = sourceURL.lastPathComponent
        let fileName = Self.safeFileName(for: originalName, fallbackID: id)
        let destination = directory.appendingPathComponent(fileName)

        do {
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: sourceURL, to: destination)
        } catch {
            throw ImportError.copyFailed
        }

        let duration = Self.duration(of: destination)
        return Recording(
            id: id,
            title: Self.displayTitle(from: originalName),
            fileName: fileName,
            duration: duration,
            source: .imported
        )
    }

    /// Best-effort duration read; returns 0 if the asset can't be read.
    static func duration(of url: URL) -> TimeInterval {
        let asset = AVURLAsset(url: url)
        let seconds = CMTimeGetSeconds(asset.duration)
        return seconds.isFinite && seconds > 0 ? seconds : 0
    }
}
