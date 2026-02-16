// swiftlint:disable file_length
import AVFoundation
import os

@Observable
@MainActor
final class AudioManager {
    // MARK: - Constants

    private let crossFadeDuration: TimeInterval = 0.5
    private let bgmDefaultVolume: Float = 0.5
    private let sfxDefaultVolume: Float = 1.0
    private let bgmLoopCount = -1
    private let sfxLoopCount = 0

    // MARK: - Singleton

    static let shared = AudioManager()

    // MARK: - Observable State

    private(set) var isPlaying = false
    private(set) var isInterrupted = false
    private(set) var sessionConfigured = false

    var isMuted = false {
        didSet { applyMuteState() }
    }

    // MARK: - BGM Players

    private var playerA: AVAudioPlayer?
    private var playerB: AVAudioPlayer?
    private var activePlayer: AVAudioPlayer?
    private var nextSlotIsA = true

    // MARK: - Cross-Fade State

    private var fadingOutPlayer: AVAudioPlayer?
    private var fadeCompletionTime: TimeInterval = 0

    // MARK: - SFX State

    private var activeSFXPlayers: [(identifier: String, player: AVAudioPlayer)] = []
    private var sfxReusePool: [String: [AVAudioPlayer]] = [:]

    // MARK: - Preload Cache

    private var playerCache: [String: AVAudioPlayer] = [:]

    // MARK: - Timing

    private var playbackStartMediaTime: TimeInterval = 0
    private var pausedPlaybackPosition: TimeInterval = 0

    // MARK: - Dependencies

    private let notificationCenter: NotificationCenter
    private let assetLoader: @Sendable (String, String?) -> URL?

    // MARK: - Notification Observers

    private var interruptionObserver: (any NSObjectProtocol)?
    private var routeChangeObserver: (any NSObjectProtocol)?

    // MARK: - Diagnostics

    #if DEBUG
        private static let logger = Logger(
            subsystem: "com.otterverse.starlightsync",
            category: "AudioManager"
        )
    #endif

    // MARK: - Initialization

    init(
        notificationCenter: NotificationCenter = .default,
        assetLoader: @escaping @Sendable (String, String?) -> URL? = { name, ext in
            Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Audio/SFX")
                ?? Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Audio")
                ?? Bundle.main.url(forResource: name, withExtension: ext)
        }
    ) {
        self.notificationCenter = notificationCenter
        self.assetLoader = assetLoader
        configureAudioSession()
        registerNotifications()
    }

    // MARK: - Audio Session Configuration (S1)

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            sessionConfigured = true
        } catch {
            #if DEBUG
                Self.logger.error("Audio session configuration failed: \(error.localizedDescription)")
            #endif
            sessionConfigured = false
        }
    }

    // MARK: - Cross-Fade BGM (S3)

    func crossFadeToBGM(named identifier: String, fileExtension: String = "m4a") {
        cleanupCompletedFade()
        cancelInProgressFade()

        guard let url = resolveURL(for: identifier, fileExtension: fileExtension) else {
            #if DEBUG
                Self.logger.warning("Cannot resolve URL for BGM: \(identifier)")
            #endif
            return
        }

        do {
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.numberOfLoops = bgmLoopCount
            newPlayer.volume = 0.0
            newPlayer.prepareToPlay()
            newPlayer.play()

            let targetVolume = isMuted ? Float(0.0) : bgmDefaultVolume

            if let current = activePlayer, current.isPlaying {
                current.setVolume(0.0, fadeDuration: crossFadeDuration)
                fadingOutPlayer = current
                fadeCompletionTime = CACurrentMediaTime() + crossFadeDuration
                newPlayer.setVolume(targetVolume, fadeDuration: crossFadeDuration)
            } else {
                newPlayer.volume = targetVolume
            }

            if nextSlotIsA {
                playerA = newPlayer
            } else {
                playerB = newPlayer
            }
            activePlayer = newPlayer
            nextSlotIsA.toggle()

            playbackStartMediaTime = CACurrentMediaTime()
            isPlaying = true
        } catch {
            #if DEBUG
                Self.logger.error("BGM player creation failed for \(identifier): \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - SFX Playback (S4)

    func playSFX(named identifier: String, fileExtension: String = "m4a") {
        recycleFinishedSFXPlayers()

        if let player = reclaimSFXPlayer(for: identifier) {
            player.currentTime = 0
            player.volume = isMuted ? 0.0 : sfxDefaultVolume
            player.play()
            activeSFXPlayers.append((identifier: identifier, player: player))
            return
        }

        guard let url = resolveURL(for: identifier, fileExtension: fileExtension) else {
            #if DEBUG
                Self.logger.warning("Cannot resolve URL for SFX: \(identifier)")
            #endif
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = sfxLoopCount
            player.volume = isMuted ? 0.0 : sfxDefaultVolume
            player.prepareToPlay()
            player.play()
            activeSFXPlayers.append((identifier: identifier, player: player))
        } catch {
            #if DEBUG
                Self.logger.error("SFX player creation failed for \(identifier): \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Preload API (S5)

    private let sfxPoolSeedCount = 2

    func preloadAssets(_ manifest: [(identifier: String, fileExtension: String)]) {
        for descriptor in manifest {
            guard let url = assetLoader(descriptor.identifier, descriptor.fileExtension) else {
                #if DEBUG
                    Self.logger.warning("Preload: URL not found for \(descriptor.identifier)")
                #endif
                continue
            }

            if playerCache[descriptor.identifier] == nil {
                do {
                    let player = try AVAudioPlayer(contentsOf: url)
                    player.prepareToPlay()
                    playerCache[descriptor.identifier] = player
                } catch {
                    #if DEBUG
                        let ident = descriptor.identifier
                        Self.logger.warning("Preload failed for \(ident): \(error.localizedDescription)")
                    #endif
                }
            }

            if descriptor.identifier.hasPrefix("sfx_") {
                var pool = sfxReusePool[descriptor.identifier] ?? []
                while pool.count < sfxPoolSeedCount {
                    guard let poolPlayer = try? AVAudioPlayer(contentsOf: url) else { break }
                    poolPlayer.numberOfLoops = sfxLoopCount
                    poolPlayer.prepareToPlay()
                    pool.append(poolPlayer)
                }
                sfxReusePool[descriptor.identifier] = pool
            }
        }
    }

    // MARK: - Timing API (S8)

    func currentPlaybackTimestamp() -> TimeInterval {
        guard let player = activePlayer, player.isPlaying else { return 0 }
        return CACurrentMediaTime() - playbackStartMediaTime
    }

    // MARK: - Playback Controls (S9)

    func stopBGM() {
        cleanupCompletedFade()
        cancelInProgressFade()
        activePlayer?.stop()
        activePlayer?.currentTime = 0
        isPlaying = false
        playbackStartMediaTime = 0
    }

    func pauseBGM() {
        cleanupCompletedFade()
        cancelInProgressFade()
        guard let player = activePlayer, player.isPlaying else { return }
        pausedPlaybackPosition = CACurrentMediaTime() - playbackStartMediaTime
        player.pause()
        isPlaying = false
    }

    func resumeBGM() {
        guard let player = activePlayer, !player.isPlaying, !isInterrupted else { return }
        player.play()
        playbackStartMediaTime = CACurrentMediaTime() - pausedPlaybackPosition
        isPlaying = true
    }

    // MARK: - Interruption Handling (S6)

    private func handleInterruption(typeRaw: UInt?, optionsRaw: UInt?) {
        guard let typeRaw,
              let type = AVAudioSession.InterruptionType(rawValue: typeRaw) else { return }

        switch type {
        case .began:
            pauseAllPlayersForInterruption()
            isInterrupted = true
            isPlaying = false

        case .ended:
            isInterrupted = false
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsRaw ?? 0)
            if options.contains(.shouldResume) {
                resumeAfterInterruption()
            }

        @unknown default:
            break
        }
    }

    // MARK: - Route Change Handling (S7)

    private func handleRouteChange(reasonRaw: UInt?) {
        guard let reasonRaw,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonRaw) else { return }

        if reason == .oldDeviceUnavailable {
            activePlayer?.pause()
            pauseActiveSFXPlayers()
            isPlaying = false
        }
    }
}

// MARK: - Notification Registration

private extension AudioManager {
    func registerNotifications() {
        interruptionObserver = notificationCenter.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            let typeRaw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let optionsRaw = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt
            Task { @MainActor [weak self] in
                self?.handleInterruption(typeRaw: typeRaw, optionsRaw: optionsRaw)
            }
        }

        routeChangeObserver = notificationCenter.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            let reasonRaw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            Task { @MainActor [weak self] in
                self?.handleRouteChange(reasonRaw: reasonRaw)
            }
        }
    }
}

// MARK: - Private Helpers

private extension AudioManager {
    func resolveURL(for identifier: String, fileExtension: String) -> URL? {
        if let cached = playerCache[identifier], let url = cached.url {
            return url
        }
        return assetLoader(identifier, fileExtension)
    }

    func applyMuteState() {
        let bgmVolume: Float = isMuted ? 0.0 : bgmDefaultVolume
        let sfxVolume: Float = isMuted ? 0.0 : sfxDefaultVolume
        activePlayer?.setVolume(bgmVolume, fadeDuration: 0)
        for entry in activeSFXPlayers {
            entry.player.volume = sfxVolume
        }
    }

    func cleanupCompletedFade() {
        guard let outgoing = fadingOutPlayer else { return }
        guard CACurrentMediaTime() >= fadeCompletionTime else { return }
        outgoing.stop()
        if playerA === outgoing { playerA = nil }
        if playerB === outgoing { playerB = nil }
        fadingOutPlayer = nil
    }

    func cancelInProgressFade() {
        guard let outgoing = fadingOutPlayer else { return }
        outgoing.stop()
        if playerA === outgoing { playerA = nil }
        if playerB === outgoing { playerB = nil }
        fadingOutPlayer = nil
    }

    func reclaimSFXPlayer(for identifier: String) -> AVAudioPlayer? {
        guard var pool = sfxReusePool[identifier], !pool.isEmpty else { return nil }
        let player = pool.removeLast()
        sfxReusePool[identifier] = pool
        return player
    }

    func recycleFinishedSFXPlayers() {
        var stillActive: [(identifier: String, player: AVAudioPlayer)] = []
        for entry in activeSFXPlayers {
            if entry.player.isPlaying {
                stillActive.append(entry)
            } else {
                sfxReusePool[entry.identifier, default: []].append(entry.player)
            }
        }
        activeSFXPlayers = stillActive
    }

    func pauseAllPlayersForInterruption() {
        if let player = activePlayer, player.isPlaying {
            pausedPlaybackPosition = CACurrentMediaTime() - playbackStartMediaTime
            player.pause()
        }
        pauseActiveSFXPlayers()
    }

    func pauseActiveSFXPlayers() {
        for entry in activeSFXPlayers {
            entry.player.pause()
        }
    }

    func resumeAfterInterruption() {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            #if DEBUG
                Self.logger.error("Session reactivation failed: \(error.localizedDescription)")
            #endif
            return
        }

        if let player = activePlayer {
            player.play()
            playbackStartMediaTime = CACurrentMediaTime() - pausedPlaybackPosition
            isPlaying = true
        }
    }
}
