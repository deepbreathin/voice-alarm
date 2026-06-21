import Foundation
import Combine
import AVFoundation

/// Plays back full-length recordings inside the app (e.g. when previewing a
/// clip or when the user opens the app from a fired alarm notification).
@MainActor
public final class AudioPlaybackService: NSObject, ObservableObject {

    @Published public private(set) var playingURL: URL?
    @Published public private(set) var isPlaying = false
    @Published public private(set) var progress: Double = 0 // 0...1

    private var player: AVAudioPlayer?
    private var progressTimer: Timer?

    public override init() { super.init() }

    /// Plays the file at `url`. Tapping an already-playing file stops it.
    public func toggle(_ url: URL) {
        if isPlaying, playingURL == url {
            stop()
        } else {
            play(url)
        }
    }

    public func play(_ url: URL) {
        stop()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.prepareToPlay()
            guard player.play() else { return }
            self.player = player
            self.playingURL = url
            self.isPlaying = true
            startProgress()
        } catch {
            isPlaying = false
            playingURL = nil
        }
    }

    public func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        playingURL = nil
        progress = 0
        stopProgress()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func startProgress() {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let player = self.player, player.duration > 0 else { return }
                self.progress = player.currentTime / player.duration
            }
        }
    }

    private func stopProgress() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
}

extension AudioPlaybackService: AVAudioPlayerDelegate {
    public nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.stop()
        }
    }
}
