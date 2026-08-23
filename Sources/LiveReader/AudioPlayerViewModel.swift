@preconcurrency import AVFAudio
import Combine
import Foundation

@MainActor
final class AudioPlayerViewModel: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var loadedURL: URL?
    @Published var errorMessage: String?

    private var player: AVAudioPlayer?
    private var progressTask: Task<Void, Never>?

    deinit {
        progressTask?.cancel()
    }

    func load(_ url: URL?) {
        guard url != loadedURL else { return }
        stop()
        player = nil
        loadedURL = url
        currentTime = 0
        duration = 0
        errorMessage = nil
        guard let url else { return }
        do {
            let audio = try AVAudioPlayer(contentsOf: url)
            audio.prepareToPlay()
            player = audio
            duration = audio.duration
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func togglePlayback() {
        guard let player else { return }
        if player.isPlaying {
            player.pause()
            isPlaying = false
            progressTask?.cancel()
        } else if player.play() {
            isPlaying = true
            observeProgress()
        }
    }

    func seek(to time: TimeInterval) {
        guard let player else { return }
        player.currentTime = min(max(0, time), duration)
        currentTime = player.currentTime
    }

    private func stop() {
        progressTask?.cancel()
        player?.stop()
        isPlaying = false
    }

    private func observeProgress() {
        progressTask?.cancel()
        progressTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, let player = self.player else { return }
                self.currentTime = player.currentTime
                if !player.isPlaying {
                    self.isPlaying = false
                    return
                }
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
    }
}
