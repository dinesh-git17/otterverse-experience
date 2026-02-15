import os
import SpriteKit
import UIKit

@Observable
@MainActor
final class AssetPreloadCoordinator {
    // MARK: - Background Asset Identifiers

    private let backgroundIdentifiers = [
        "Backgrounds/img_bg_intro",
        "Backgrounds/img_bg_runner",
        "Backgrounds/img_bg_cipher",
        "Backgrounds/img_bg_blueprint",
        "Backgrounds/img_finale_art"
    ]

    // MARK: - Sprite Atlas Identifier

    private let spriteAtlasName = "Sprites"

    // MARK: - Audio Manifest

    private let audioManifest: [(identifier: String, fileExtension: String)] = [
        (identifier: "audio_bgm_main", fileExtension: "m4a"),
        (identifier: "audio_bgm_finale", fileExtension: "m4a"),
        (identifier: "sfx_haptic_thud", fileExtension: "m4a"),
        (identifier: "sfx_success_chime", fileExtension: "m4a"),
        (identifier: "sfx_shield_impact", fileExtension: "m4a"),
        (identifier: "sfx_click", fileExtension: "m4a"),
        (identifier: "sfx_error", fileExtension: "m4a")
    ]

    // MARK: - Font Identifier

    private let customFontName = "SFProRounded-Bold"

    // MARK: - Singleton

    static let shared = AssetPreloadCoordinator()

    // MARK: - Observable State

    private(set) var preloadComplete: Bool = false

    // MARK: - Session-Lifetime Storage

    private var decodedBackgrounds: [String: UIImage] = [:]
    private var spriteAtlas: SKTextureAtlas?

    // MARK: - Diagnostics

    #if DEBUG
        private static let logger = Logger(
            subsystem: "com.otterverse.starlightsync",
            category: "AssetPreloadCoordinator"
        )
    #endif

    // MARK: - Initialization

    private init() {}

    // MARK: - Preload Entry Point

    func preloadAllAssets() async {
        HapticManager.shared.preloadPatterns()

        AudioManager.shared.preloadAssets(audioManifest)

        await decodeBackgrounds()

        await preloadSpriteAtlas()

        verifyFontRegistration()

        preloadComplete = true
    }

    // MARK: - Background Image Decoding

    private func decodeBackgrounds() async {
        await withTaskGroup(of: (String, UIImage?).self) { group in
            for identifier in backgroundIdentifiers {
                group.addTask { @Sendable [identifier] in
                    guard let image = UIImage(named: identifier) else {
                        return (identifier, nil)
                    }
                    let prepared = await image.byPreparingForDisplay()
                    return (identifier, prepared)
                }
            }

            for await (identifier, image) in group {
                if let image {
                    decodedBackgrounds[identifier] = image
                } else {
                    #if DEBUG
                        Self.logger.warning("Background decode skipped: \(identifier)")
                    #endif
                }
            }
        }

        #if DEBUG
            let decodedCount = decodedBackgrounds.count
            let totalCount = backgroundIdentifiers.count
            Self.logger.info("Decoded \(decodedCount)/\(totalCount) backgrounds")
        #endif
    }

    // MARK: - Sprite Atlas Preloading

    private func preloadSpriteAtlas() async {
        let atlas = SKTextureAtlas(named: spriteAtlasName)
        let textureNames = atlas.textureNames

        guard !textureNames.isEmpty else {
            #if DEBUG
                let atlasName = spriteAtlasName
                Self.logger.warning("Sprite atlas '\(atlasName)' contains no textures")
            #endif
            return
        }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            atlas.preload { continuation.resume() }
        }

        spriteAtlas = atlas

        #if DEBUG
            Self.logger.info("Sprite atlas preloaded: \(textureNames.count) textures")
        #endif
    }

    // MARK: - Font Verification

    private func verifyFontRegistration() {
        let font = UIFont(name: customFontName, size: 17)
        #if DEBUG
            let fontName = customFontName
            if font != nil {
                Self.logger.info("Custom font registered: \(fontName)")
            } else {
                Self.logger.info("Custom font not registered: \(fontName) — using system fallback")
            }
        #endif
        _ = font
    }
}
