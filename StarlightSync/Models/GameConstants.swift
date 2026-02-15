import Foundation

enum GameConstants {
    // MARK: - Auto-Assist Thresholds

    enum AutoAssist {
        /// Ch. 2 runner death count before adaptive difficulty activates (§3.3, §3.8)
        static let runnerDeathThreshold: Int = 3
        /// Ch. 3 cipher incorrect attempt count before hint activates (§3.4, §3.8)
        static let cipherIncorrectThreshold: Int = 3
        /// Ch. 4 firewall missed beats before hit window widens (§3.5, §3.8)
        static let firewallMissThreshold: Int = 5
        /// Ch. 5 blueprint idle seconds before next-node pulse hint (§3.6, §3.8)
        static let blueprintIdleThreshold: TimeInterval = 10.0
    }

    // MARK: - Timing & Duration

    enum Timing {
        /// BGM cross-fade overlap between dual AVAudioPlayer instances (§7.4, §8.4)
        static let crossFadeDuration: TimeInterval = 0.5
        /// Ch. 2 runner survival target duration (§3.3)
        static let runnerDuration: TimeInterval = 60.0
        /// Ch. 4 firewall rhythm section duration (§3.5)
        static let firewallDuration: TimeInterval = 45.0
        /// Ch. 1 handshake long-press hold requirement (§3.2)
        static let handshakeHoldDuration: TimeInterval = 3.0
        /// Ch. 6 friction slider progressive resistance exponent (§3.7)
        static let sliderExponent: Double = 0.8
        /// Ch. 5 blueprint idle pulse trigger interval (§3.6)
        static let blueprintIdlePulseDuration: TimeInterval = 10.0
    }

    // MARK: - Difficulty Modifiers

    enum Difficulty {
        /// Ch. 2 Auto-Assist speed reduction fraction applied multiplicatively (§3.3)
        static let runnerSpeedReduction: Double = 0.20
        /// Ch. 2 Auto-Assist gap width increase fraction (§3.3)
        static let runnerGapIncrease: Double = 0.20
        /// Ch. 4 default beat hit tolerance window in seconds (§3.5)
        static let firewallDefaultHitWindow: TimeInterval = 0.150
        /// Ch. 4 Auto-Assist widened hit tolerance window in seconds (§3.5)
        static let firewallAssistedHitWindow: TimeInterval = 0.300
    }

    // MARK: - Physics Tuning

    enum Physics {
        /// Ch. 2 heart pickup collection target for alternative win condition (§3.3)
        static let runnerHeartTarget: Int = 20
        /// ProMotion rendering target for SpriteKit scenes (§10.2)
        static let targetFrameRate: Int = 120
    }

    // MARK: - Beat Map

    enum BeatMap {
        /// Total duration of audio_bgm_main track in seconds
        static let trackDuration: TimeInterval = 174.66
        /// Percussive hit timestamps synced to audio_bgm_main at ~85 BPM.
        /// Kicks on beats 1 and 3 of each 4/4 measure. 32 entries across ~44.5s
        /// covering the Ch. 4 firewall gameplay window. Refined in PH-16 QA.
        static let timestamps: [TimeInterval] = [
            0.706,
            2.118,
            3.530,
            4.942,
            6.353,
            7.765,
            9.176,
            10.588,
            12.000,
            13.412,
            14.824,
            16.235,
            17.647,
            19.059,
            20.471,
            21.882,
            23.294,
            24.706,
            26.118,
            27.529,
            28.941,
            30.353,
            31.765,
            33.176,
            34.588,
            36.000,
            37.412,
            38.824,
            40.235,
            41.647,
            43.059,
            44.471
        ]
    }

    // MARK: - Visual Asset Identifiers

    enum BackgroundAsset: String {
        case intro = "img_bg_intro"
        case runner = "img_bg_runner"
        case cipher = "img_bg_cipher"
        case blueprint = "img_bg_blueprint"
        case finale = "img_finale_art"
    }

    enum SpriteAsset: String {
        case otterPlayer = "sprite_otter_player"
        case obstacleGlitch = "sprite_obstacle_glitch"
        case heartPickup = "sprite_heart_pickup"
        case noiseParticle = "sprite_noise_particle"
        case bubbleShield = "img_bubble_shield"
    }

    enum SpriteAtlas: String {
        case sprites = "Sprites"
    }

    // MARK: - Audio Asset Identifiers

    enum AudioAsset: String {
        case bgmMain = "audio_bgm_main"
        case bgmFinale = "audio_bgm_finale"
        case sfxThud = "sfx_haptic_thud"
        case sfxChime = "sfx_success_chime"
        case sfxShieldImpact = "sfx_shield_impact"
        case sfxClick = "sfx_click"
        case sfxError = "sfx_error"

        static let fileExtension: String = "m4a"
    }

    // MARK: - Haptic Asset Identifiers

    enum HapticAsset: String {
        case heartbeat
        case capacitorCharge = "capacitor_charge"
        case thud

        static let fileExtension: String = "ahap"
    }

    // MARK: - Persistence Keys

    enum Persistence: String {
        case highestUnlockedChapter
    }
}
