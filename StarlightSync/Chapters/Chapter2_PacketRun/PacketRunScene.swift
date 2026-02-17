// swiftlint:disable file_length
import os
import SpriteKit
import UIKit

// swiftlint:disable:next type_body_length
final class PacketRunScene: SKScene {
    // MARK: - Diagnostics

    #if DEBUG
        private static let logger = Logger(
            subsystem: "com.otterverse.starlightsync",
            category: "PacketRunScene"
        )
    #endif

    // MARK: - Game State

    private enum GameState {
        case ready
        case playing
        case death
        case won
    }

    // MARK: - Coordinator

    weak var coordinator: FlowCoordinator?

    // MARK: - Scene Tuning Constants

    private let starsScrollSpeed: CGFloat = 30
    private let highwayScrollSpeed: CGFloat = 120
    private let baseObstacleTraversalDuration: TimeInterval = 2.8
    private let obstacleSpawnInterval: TimeInterval = 1.6
    private let obstacleSpawnRange: TimeInterval = 0.5
    private let heartSpawnInterval: TimeInterval = 2.2
    private let heartSpawnRange: TimeInterval = 0.8

    private let playerBottomFraction: CGFloat = 0.12
    private let playerHeightFraction: CGFloat = 0.08
    private let obstacleWidthFraction: CGFloat = 0.18
    private let heartWidthFraction: CGFloat = 0.10

    private let bankingSensitivity: CGFloat = 0.005
    private let maxBankingAngle: CGFloat = 0.25
    private let bankingDecay: CGFloat = 0.85

    /// Highway road surface bounds as fractions of scene width.
    /// Derived from the neon-edge positions in img_bg_runner_highway.
    private let highwayLeftEdge: CGFloat = 0.18
    private let highwayRightEdge: CGFloat = 0.82

    /// Extra inward padding for spawn positions to prevent edge-clipping.
    private let spawnInsetPadding: CGFloat = 12

    private let deathFlashDuration: TimeInterval = 0.08
    private let deathResetDelay: TimeInterval = 0.4
    private let victoryPauseDuration: TimeInterval = 1.5

    private let backgroundZPosition: CGFloat = -10
    private let gameLayerZPosition: CGFloat = 0
    private let entityZPosition: CGFloat = 1
    private let playerZPosition: CGFloat = 2
    private let hudZPosition: CGFloat = 10
    private let overlayZPosition: CGFloat = 50

    private let hudFontName = "Menlo-Bold"
    private let hudFontSize: CGFloat = 20
    private let hudTopMargin: CGFloat = 100
    private let hudSideMargin: CGFloat = 20

    private let minimumSceneSize: CGFloat = 100
    private let sceneFadeInDuration: TimeInterval = 0.8

    // MARK: - SFX File Paths (SKAction-based, no main-thread stall)

    private let sfxChimePath = "Audio/SFX/sfx_success_chime.m4a"
    private let sfxThudPath = "Audio/SFX/sfx_haptic_thud.m4a"

    // MARK: - Node Names

    private let obstacleNodeName = "obstacle"
    private let heartNodeName = "heart"
    private let obstacleSpawnTimerName = "obstacleSpawnTimer"
    private let heartSpawnTimerName = "heartSpawnTimer"
    private let welcomeOverlayName = "welcomeOverlay"
    private let gameOverOverlayName = "gameOverOverlay"
    private let winOverlayName = "winOverlay"
    private let tryAgainButtonName = "tryAgainButton"
    private let continueButtonName = "continueButton"

    // MARK: - State

    private var isContentSetUp = false
    private var gameState: GameState = .ready
    private var lastUpdateTime: TimeInterval = 0
    private var heartsCollected: Int = 0
    private var displayedHearts: Int = -1
    private var deathCount: Int = 0
    private var sessionHighScore: Int = 0
    private var lastTouchX: CGFloat = 0
    private var horizontalVelocity: CGFloat = 0
    private var currentSpeedMultiplier: CGFloat = 1.0

    // MARK: - Layer Containers

    private let backgroundLayer = SKNode()
    private let gameLayer = SKNode()

    // MARK: - Node References

    private var playerNode: SKSpriteNode?
    private var shadowNode: SKShapeNode?
    private var heartLabel: SKLabelNode?

    // MARK: - Texture Atlas

    private lazy var spriteAtlas: SKTextureAtlas = .init(named: GameConstants.SpriteAtlas.sprites.rawValue)

    // MARK: - Computed Properties

    private var isAutoAssistActive: Bool {
        deathCount >= GameConstants.AutoAssist.runnerDeathThreshold
    }

    private var effectiveTraversalDuration: TimeInterval {
        guard isAutoAssistActive else { return baseObstacleTraversalDuration }
        return baseObstacleTraversalDuration / (1.0 - GameConstants.Difficulty.runnerSpeedReduction)
    }

    private var effectiveSpawnInterval: TimeInterval {
        guard isAutoAssistActive else { return obstacleSpawnInterval }
        return obstacleSpawnInterval * (1.0 + GameConstants.Difficulty.runnerGapIncrease)
    }

    // MARK: - Scene Lifecycle

    override func didMove(to view: SKView) {
        view.preferredFramesPerSecond = GameConstants.Physics.targetFrameRate
        backgroundColor = .black
        physicsWorld.gravity = .zero
    }

    override func willMove(from _: SKView) {
        removeAllActions()
        removeAllChildren()
        coordinator = nil
    }

    private func setupContent() {
        guard !isContentSetUp else { return }
        isContentSetUp = true

        backgroundLayer.zPosition = backgroundZPosition
        addChild(backgroundLayer)

        gameLayer.zPosition = gameLayerZPosition
        addChild(gameLayer)

        setupBackground()
        setupPlayer()
        setupHUD()
        prewarmSFX()

        // Dark Dive Entry
        // 1. Scene fades in from Black
        backgroundLayer.alpha = 0
        gameLayer.alpha = 0

        backgroundLayer.run(SKAction.fadeAlpha(to: 1.0, duration: sceneFadeInDuration))
        gameLayer.run(SKAction.fadeAlpha(to: 1.0, duration: sceneFadeInDuration)) { [weak self] in
            self?.showWelcomeOverlay()
        }

        // 2. Hero Entry (Fly in from bottom)
        if let player = playerNode {
            let targetY = player.position.y
            player.position.y = -player.size.height // Start off-screen bottom

            let flyIn = SKAction.moveTo(y: targetY, duration: 0.8)
            flyIn.timingMode = .easeOut
            player.run(flyIn)

            // Shadow follows
            if let shadow = shadowNode {
                shadow.alpha = 0
                let shadowFade = SKAction.fadeAlpha(to: 0.4, duration: 0.8)
                shadow.run(shadowFade)
            }
        }
    }

    // MARK: - SFX Pre-Warm

    private func prewarmSFX() {
        for path in [sfxChimePath, sfxThudPath] {
            let node = SKAudioNode(fileNamed: path)
            node.autoplayLooped = false
            node.isPositional = false
            addChild(node)
            node.run(SKAction.sequence([
                SKAction.changeVolume(to: 0, duration: 0),
                SKAction.play(),
                SKAction.wait(forDuration: 0.05),
                SKAction.removeFromParent()
            ]))
        }
    }

    // MARK: - Background Setup (Two-Layer Parallax)

    private func setupBackground() {
        let preloader = AssetPreloadCoordinator.shared

        let starsTexture: SKTexture
        if let cgRef = preloader.backgroundImage(for: .runnerStars)?.cgImage {
            starsTexture = SKTexture(cgImage: cgRef)
        } else {
            starsTexture = SKTexture(imageNamed: GameConstants.BackgroundAsset.runnerStars.rawValue)
        }
        addScrollingPair(
            texture: starsTexture,
            speed: starsScrollSpeed,
            zPosition: 0
        )

        let highwayTexture: SKTexture
        if let cgRef = preloader.backgroundImage(for: .runnerHighway)?.cgImage {
            highwayTexture = SKTexture(cgImage: cgRef)
        } else {
            highwayTexture = SKTexture(imageNamed: GameConstants.BackgroundAsset.runnerHighway.rawValue)
        }
        addScrollingPair(
            texture: highwayTexture,
            speed: highwayScrollSpeed,
            zPosition: 1,
            blendMode: .add
        )
    }

    private func addScrollingPair(
        texture: SKTexture,
        speed: CGFloat,
        zPosition: CGFloat,
        blendMode: SKBlendMode = .alpha
    ) {
        let nodeA = SKSpriteNode(texture: texture)
        nodeA.anchorPoint = .zero
        nodeA.position = .zero
        nodeA.size = size
        nodeA.zPosition = zPosition
        nodeA.blendMode = blendMode
        backgroundLayer.addChild(nodeA)

        let nodeB = SKSpriteNode(texture: texture)
        nodeB.anchorPoint = .zero
        nodeB.position = CGPoint(x: 0, y: size.height)
        nodeB.size = size
        nodeB.zPosition = zPosition
        nodeB.blendMode = blendMode
        backgroundLayer.addChild(nodeB)

        let scrollDuration = TimeInterval(size.height / speed)
        let moveDown = SKAction.moveBy(x: 0, y: -size.height, duration: scrollDuration)
        let resetUp = SKAction.moveBy(x: 0, y: size.height, duration: 0)
        let scrollLoop = SKAction.repeatForever(SKAction.sequence([moveDown, resetUp]))

        nodeA.run(scrollLoop)
        nodeB.run(scrollLoop)
    }

    // MARK: - Player Setup

    private func setupPlayer() {
        let texture = spriteAtlas.textureNamed(
            GameConstants.SpriteAsset.otterPlayer.rawValue
        )
        let player = SKSpriteNode(texture: texture)
        let targetHeight = size.height * playerHeightFraction
        let texSize = texture.size()
        let aspectRatio = texSize.width / max(texSize.height, 1)
        player.size = CGSize(
            width: aspectRatio > 0 ? targetHeight * aspectRatio : targetHeight,
            height: targetHeight
        )
        let highwayCenterX = size.width * (highwayLeftEdge + highwayRightEdge) / 2
        player.position = CGPoint(
            x: highwayCenterX,
            y: size.height * playerBottomFraction
        )
        player.zPosition = playerZPosition

        gameLayer.addChild(player)
        playerNode = player

        // Shadow
        let shadow = SKShapeNode(ellipseOf: CGSize(width: player.size.width * 0.6, height: player.size.width * 0.2))
        shadow.fillColor = .black
        shadow.strokeColor = .clear
        shadow.alpha = 0.4
        // Position shadow slightly below player
        shadow.position = CGPoint(x: player.position.x, y: player.position.y - player.size.height * 0.4)
        shadow.zPosition = playerZPosition - 1
        gameLayer.addChild(shadow)
        shadowNode = shadow

        // Levitation Animation (Idle Hover)
        let hoverUp = SKAction.moveBy(x: 0, y: 8, duration: 1.2)
        hoverUp.timingMode = .easeInEaseOut
        let hoverDown = hoverUp.reversed()
        let hoverSeq = SKAction.repeatForever(SKAction.sequence([hoverUp, hoverDown]))
        player.run(hoverSeq)

        // Shadow breathes with hover (scales inversely slightly to sell height)
        let shadowShrink = SKAction.scale(to: 0.9, duration: 1.2)
        shadowShrink.timingMode = .easeInEaseOut
        let shadowGrow = shadowShrink.reversed()
        let shadowSeq = SKAction.repeatForever(SKAction.sequence([shadowShrink, shadowGrow]))
        shadow.run(shadowSeq)
    }

    // MARK: - HUD Setup

    private func setupHUD() {
        let neonCyan = SKColor(red: 0.0, green: 0.95, blue: 0.85, alpha: 1.0)
        let containerWidth: CGFloat = 100
        let containerHeight: CGFloat = 40

        let container = SKShapeNode(rectOf: CGSize(width: containerWidth, height: containerHeight), cornerRadius: 10)
        container.fillColor = SKColor(white: 0, alpha: 0.5) // Glass dark
        container.strokeColor = neonCyan
        container.lineWidth = 1
        container.zPosition = hudZPosition
        container.position = CGPoint(
            x: size.width - hudSideMargin - containerWidth / 2,
            y: size.height - hudTopMargin
        )
        container.alpha = 0 // Fade in with scene
        addChild(container)

        // Label inside container
        let hearts = SKLabelNode(fontNamed: hudFontName)
        hearts.fontSize = 18
        hearts.fontColor = neonCyan
        hearts.horizontalAlignmentMode = .center
        hearts.verticalAlignmentMode = .center
        hearts.position = .zero // Geometric center
        container.addChild(hearts)

        heartLabel = hearts

        // Store container ref for fading? Or just set alpha on container directly.
        // The scene fade-in sets gameLayer/backgroundLayer alpha.
        // We need to animate this container separately in setupContent.
        container.run(SKAction.fadeAlpha(to: 1.0, duration: sceneFadeInDuration))
    }

    private func updateHUD() {
        guard heartsCollected != displayedHearts else { return }
        displayedHearts = heartsCollected
        heartLabel?.text = "\(heartsCollected)/\(GameConstants.Physics.runnerHeartTarget)"
    }

    // MARK: - Welcome Overlay

    // swiftlint:disable:next function_body_length
    private func showWelcomeOverlay() {
        let overlay = SKNode()
        overlay.name = welcomeOverlayName
        overlay.zPosition = overlayZPosition

        let dimmer = SKSpriteNode(color: SKColor(white: 0, alpha: 0.65), size: size)
        dimmer.anchorPoint = .zero
        dimmer.position = .zero
        overlay.addChild(dimmer)

        let centerX = size.width / 2
        let centerY = size.height / 2

        let title = SKLabelNode(fontNamed: hudFontName)
        title.text = "PACKET RUN"
        title.fontSize = 36
        title.fontColor = SKColor(red: 0.0, green: 0.95, blue: 0.85, alpha: 1.0)
        title.horizontalAlignmentMode = .center
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: centerX, y: centerY + 100)
        overlay.addChild(title)

        let desc1 = SKLabelNode(fontNamed: hudFontName)
        desc1.text = "Dodge the glitches."
        desc1.fontSize = 18
        desc1.fontColor = .white
        desc1.horizontalAlignmentMode = .center
        desc1.verticalAlignmentMode = .center
        desc1.position = CGPoint(x: centerX, y: centerY + 40)
        overlay.addChild(desc1)

        let desc2 = SKLabelNode(fontNamed: hudFontName)
        desc2.text = "Collect \(GameConstants.Physics.runnerHeartTarget) hearts"
        desc2.fontSize = 18
        desc2.fontColor = SKColor(red: 1.0, green: 0.2, blue: 0.6, alpha: 1.0)
        desc2.horizontalAlignmentMode = .center
        desc2.verticalAlignmentMode = .center
        desc2.position = CGPoint(x: centerX, y: centerY + 10)
        overlay.addChild(desc2)

        let desc3 = SKLabelNode(fontNamed: hudFontName)
        desc3.text = "to keep the signal alive."
        desc3.fontSize = 18
        desc3.fontColor = .white
        desc3.horizontalAlignmentMode = .center
        desc3.verticalAlignmentMode = .center
        desc3.position = CGPoint(x: centerX, y: centerY - 20)
        overlay.addChild(desc3)

        let hint = SKLabelNode(fontNamed: hudFontName)
        hint.text = "Drag left & right to move"
        hint.fontSize = 14
        hint.fontColor = SKColor(white: 1, alpha: 0.5)
        hint.horizontalAlignmentMode = .center
        hint.verticalAlignmentMode = .center
        hint.position = CGPoint(x: centerX, y: centerY - 70)
        overlay.addChild(hint)

        let playButton = SKLabelNode(fontNamed: hudFontName)
        playButton.name = "playButton"
        playButton.text = "[ PLAY ]"
        playButton.fontSize = 28
        playButton.fontColor = SKColor(red: 0.0, green: 0.95, blue: 0.85, alpha: 1.0)
        playButton.horizontalAlignmentMode = .center
        playButton.verticalAlignmentMode = .center
        playButton.position = CGPoint(x: centerX, y: centerY - 130)
        overlay.addChild(playButton)

        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.5, duration: 0.8),
            SKAction.fadeAlpha(to: 1.0, duration: 0.8)
        ])
        playButton.run(SKAction.repeatForever(pulse))

        addChild(overlay)
    }

    private func dismissWelcomeAndStart() {
        guard let overlay = childNode(withName: welcomeOverlayName) else { return }

        let flyThrough = SKAction.group([
            SKAction.scale(to: 2.5, duration: 0.4),
            SKAction.fadeOut(withDuration: 0.4)
        ])
        flyThrough.timingMode = .easeIn

        let remove = SKAction.removeFromParent()
        overlay.run(SKAction.sequence([flyThrough, remove]))

        heartLabel?.alpha = 1
        updateHUD()

        gameState = .playing
        startSpawning()
    }

    // MARK: - Spawning

    private func startSpawning() {
        let obstacleSequence = SKAction.sequence([
            SKAction.wait(
                forDuration: effectiveSpawnInterval,
                withRange: obstacleSpawnRange
            ),
            SKAction.run { [weak self] in self?.spawnObstacle() }
        ])
        let obstacleTimer = SKNode()
        obstacleTimer.name = obstacleSpawnTimerName
        gameLayer.addChild(obstacleTimer)
        obstacleTimer.run(SKAction.repeatForever(obstacleSequence))

        let heartSequence = SKAction.sequence([
            SKAction.wait(
                forDuration: heartSpawnInterval,
                withRange: heartSpawnRange
            ),
            SKAction.run { [weak self] in self?.spawnHeart() }
        ])
        let heartTimer = SKNode()
        heartTimer.name = heartSpawnTimerName
        gameLayer.addChild(heartTimer)
        heartTimer.run(SKAction.repeatForever(heartSequence))
    }

    private func spawnObstacle() {
        guard gameState == .playing else { return }

        let texture = spriteAtlas.textureNamed(
            GameConstants.SpriteAsset.obstacleGlitch.rawValue
        )
        let obstacle = SKSpriteNode(texture: texture)

        let targetWidth = size.width * obstacleWidthFraction
        let aspectRatio = texture.size().height / max(texture.size().width, 1)
        obstacle.size = CGSize(width: targetWidth, height: targetWidth * aspectRatio)

        let minX = size.width * highwayLeftEdge + obstacle.size.width / 2 + spawnInsetPadding
        let maxX = size.width * highwayRightEdge - obstacle.size.width / 2 - spawnInsetPadding
        obstacle.position = CGPoint(
            x: CGFloat.random(in: minX ... maxX),
            y: size.height + obstacle.size.height / 2
        )
        obstacle.zPosition = entityZPosition
        obstacle.name = obstacleNodeName
        obstacle.speed = currentSpeedMultiplier // Inherit current game speed

        gameLayer.addChild(obstacle)

        let moveDistance = size.height + obstacle.size.height * 2
        let move = SKAction.moveBy(
            x: 0,
            y: -moveDistance,
            duration: effectiveTraversalDuration
        )
        obstacle.run(SKAction.sequence([move, SKAction.removeFromParent()]))
    }

    private func spawnHeart() {
        guard gameState == .playing else { return }

        let texture = spriteAtlas.textureNamed(
            GameConstants.SpriteAsset.heartPickup.rawValue
        )
        let heart = SKSpriteNode(texture: texture)

        let targetWidth = size.width * heartWidthFraction
        let aspectRatio = texture.size().height / max(texture.size().width, 1)
        heart.size = CGSize(width: targetWidth, height: targetWidth * aspectRatio)

        let minX = size.width * highwayLeftEdge + heart.size.width / 2 + spawnInsetPadding
        let maxX = size.width * highwayRightEdge - heart.size.width / 2 - spawnInsetPadding
        heart.position = CGPoint(
            x: CGFloat.random(in: minX ... maxX),
            y: size.height + heart.size.height / 2
        )
        heart.zPosition = entityZPosition
        heart.name = heartNodeName
        heart.speed = currentSpeedMultiplier // Inherit current game speed

        gameLayer.addChild(heart)

        let moveDistance = size.height + heart.size.height * 2
        let move = SKAction.moveBy(
            x: 0,
            y: -moveDistance,
            duration: effectiveTraversalDuration
        )
        heart.run(SKAction.sequence([move, SKAction.removeFromParent()]))
    }

    // MARK: - Update Loop

    override func update(_ currentTime: TimeInterval) {
        if !isContentSetUp, size.width > minimumSceneSize, size.height > minimumSceneSize {
            setupContent()
        }

        guard gameState == .playing else { return }

        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
            return
        }
        lastUpdateTime = currentTime

        applyBanking()
        updateShadow()
        updateSpeedLines()

        if heartsCollected >= GameConstants.Physics.runnerHeartTarget {
            handleWin()
            return
        }

        checkCollisions()
    }

    private func updateShadow() {
        guard let player = playerNode, let shadow = shadowNode else { return }
        shadow.position.x = player.position.x
        // Y position remains fixed relative to lane

        // Scale shadow slightly with banking for 3D feel?
        // Simple X scale reduction when banked
        let bankFactor = 1.0 - abs(player.zRotation) * 0.5
        shadow.xScale = bankFactor
    }

    private func updateSpeedLines() {
        // 30% chance per frame to spawn a speed line
        if Double.random(in: 0 ... 1) < 0.3 {
            spawnSpeedLine()
        }
    }

    private func spawnSpeedLine() {
        let line = SKSpriteNode(color: .white, size: CGSize(width: 2, height: CGFloat.random(in: 30 ... 80)))
        line.alpha = CGFloat.random(in: 0.05 ... 0.15)

        // Spawn across the full width
        let randomX = CGFloat.random(in: 0 ... size.width)
        line.position = CGPoint(x: randomX, y: size.height + 50)
        line.zPosition = entityZPosition - 0.5 // Behind obstacles

        gameLayer.addChild(line)

        let duration = TimeInterval.random(in: 0.3 ... 0.6)
        let move = SKAction.moveBy(x: 0, y: -(size.height + 100), duration: duration)
        let remove = SKAction.removeFromParent()

        line.run(SKAction.sequence([move, remove]))
    }

    private func applyBanking() {
        guard let player = playerNode else { return }

        // Calculate target angle based on velocity (negative because +X move = clockwise rotation)
        let targetAngle = -horizontalVelocity * bankingSensitivity
        let clampedAngle = max(-maxBankingAngle, min(maxBankingAngle, targetAngle))

        // Smoothly interpolate current rotation to target
        let currentAngle = player.zRotation
        player.zRotation = currentAngle + (clampedAngle - currentAngle) * 0.2

        // Decay velocity to simulate friction/return-to-center
        horizontalVelocity *= bankingDecay

        // Snap to 0 if very small
        if abs(horizontalVelocity) < 0.1 {
            horizontalVelocity = 0
        }
    }

    // MARK: - Collision Inset Fractions

    private let playerHitboxInset: CGFloat = 0.40
    private let obstacleHitboxInset: CGFloat = 0.20
    private let heartPickupInset: CGFloat = 0.10

    // MARK: - Frame-Based Collision Detection

    /// Reusable buffer to avoid per-frame allocation.
    private var collectedHearts: [SKSpriteNode] = []

    private func checkCollisions() {
        guard let player = playerNode else { return }

        let playerFrame = player.frame
        let playerRect = playerFrame.insetBy(
            dx: playerFrame.width * playerHitboxInset,
            dy: playerFrame.height * playerHitboxInset
        )

        collectedHearts.removeAll(keepingCapacity: true)

        for child in gameLayer.children {
            guard let sprite = child as? SKSpriteNode else { continue }

            if sprite.name == obstacleNodeName {
                let spriteFrame = sprite.frame
                let obstacleRect = spriteFrame.insetBy(
                    dx: spriteFrame.width * obstacleHitboxInset,
                    dy: spriteFrame.height * obstacleHitboxInset
                )
                if playerRect.intersects(obstacleRect) {
                    handleDeath()
                    return
                }
            } else if sprite.name == heartNodeName {
                let spriteFrame = sprite.frame
                let heartRect = spriteFrame.insetBy(
                    dx: spriteFrame.width * heartPickupInset,
                    dy: spriteFrame.height * heartPickupInset
                )
                if playerRect.intersects(heartRect) {
                    collectedHearts.append(sprite)
                }
            }
        }

        for heart in collectedHearts {
            handleHeartCollection(heart)
        }
    }

    // MARK: - Input

    override func touchesBegan(_ touches: Set<UITouch>, with _: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let tapped = nodes(at: location)

        if gameState == .ready {
            if tapped.contains(where: { $0.name == "playButton" }) {
                dismissWelcomeAndStart()
            }
            return
        }

        if gameState == .death {
            if tapped.contains(where: { $0.name == tryAgainButtonName }) {
                dismissGameOverAndRestart()
            }
            return
        }

        if gameState == .won {
            if tapped.contains(where: { $0.name == continueButtonName }) {
                coordinator?.completeCurrentChapter()
            }
            return
        }

        guard gameState == .playing else { return }
        lastTouchX = location.x
    }

    override func touchesMoved(_ touches: Set<UITouch>, with _: UIEvent?) {
        guard gameState == .playing,
              let touch = touches.first,
              let player = playerNode else { return }

        let currentX = touch.location(in: self).x
        let deltaX = currentX - lastTouchX
        lastTouchX = currentX

        let halfWidth = player.size.width / 2
        let leftBound = size.width * highwayLeftEdge + halfWidth
        let rightBound = size.width * highwayRightEdge - halfWidth
        let newX = min(max(leftBound, player.position.x + deltaX), rightBound)
        player.position.x = newX

        // Update velocity for banking (decay handled in update)
        horizontalVelocity = deltaX
    }

    override func touchesEnded(_: Set<UITouch>, with _: UIEvent?) {
        horizontalVelocity = 0
    }

    override func touchesCancelled(_: Set<UITouch>, with _: UIEvent?) {
        horizontalVelocity = 0
    }

    // MARK: - Death & Game Over

    private func handleDeath() {
        gameState = .death

        guard let player = playerNode else { return }

        HapticManager.shared.play(GameConstants.HapticAsset.thud.rawValue)
        run(SKAction.playSoundFileNamed(sfxThudPath, waitForCompletion: false))

        stopSpawning()

        // 1. Camera Shake (Signal Instability)
        let shakeAction = SKAction.sequence([
            SKAction.run { [weak self] in
                self?.gameLayer.position.x = CGFloat.random(in: -15 ... 15)
            },
            SKAction.wait(forDuration: 0.03),
            SKAction.run { [weak self] in
                self?.gameLayer.position.x = 0
            }
        ])
        gameLayer.run(SKAction.repeat(shakeAction, count: 10))

        // 2. Player Glitch (Distortion & Signal Loss)
        // Store original scale to reset later if needed
        let originalScaleX = player.xScale
        let originalScaleY = player.yScale

        let glitchAction = SKAction.sequence([
            SKAction.group([
                SKAction.scaleX(to: originalScaleX * 1.5, y: originalScaleY * 0.2, duration: 0.05),
                SKAction.colorize(with: .red, colorBlendFactor: 1.0, duration: 0.05)
            ]),
            SKAction.group([
                SKAction.scaleX(to: originalScaleX * 0.8, y: originalScaleY * 1.5, duration: 0.05),
                SKAction.colorize(with: .white, colorBlendFactor: 0.0, duration: 0.05)
            ]),
            SKAction.scaleX(to: originalScaleX, y: originalScaleY, duration: 0.05),
            SKAction.fadeOut(withDuration: 0.1),
            SKAction.run { [weak self] in self?.showGameOverOverlay() }
        ])

        player.run(glitchAction)
    }

    // swiftlint:disable:next function_body_length
    private func showGameOverOverlay() {
        deathCount += 1
        if heartsCollected > sessionHighScore {
            sessionHighScore = heartsCollected
        }

        let overlay = SKNode()
        overlay.name = gameOverOverlayName
        overlay.zPosition = overlayZPosition
        overlay.alpha = 0

        let dimmer = SKSpriteNode(color: SKColor(white: 0, alpha: 0.75), size: size)
        dimmer.anchorPoint = .zero
        dimmer.position = .zero
        overlay.addChild(dimmer)

        let centerX = size.width / 2
        let centerY = size.height / 2
        let neonCyan = SKColor(red: 0.0, green: 0.95, blue: 0.85, alpha: 1.0)
        let neonPink = SKColor(red: 1.0, green: 0.2, blue: 0.6, alpha: 1.0)

        let title = SKLabelNode(fontNamed: hudFontName)
        title.text = "SIGNAL LOST"
        title.fontSize = 36
        title.fontColor = neonPink
        title.horizontalAlignmentMode = .center
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: centerX, y: centerY + 100)
        overlay.addChild(title)

        let scoreLabel = SKLabelNode(fontNamed: hudFontName)
        scoreLabel.text = "Hearts: \(heartsCollected)/\(GameConstants.Physics.runnerHeartTarget)"
        scoreLabel.fontSize = 20
        scoreLabel.fontColor = .white
        scoreLabel.horizontalAlignmentMode = .center
        scoreLabel.verticalAlignmentMode = .center
        scoreLabel.position = CGPoint(x: centerX, y: centerY + 30)
        overlay.addChild(scoreLabel)

        let highScoreLabel = SKLabelNode(fontNamed: hudFontName)
        highScoreLabel.text = "Best: \(sessionHighScore)/\(GameConstants.Physics.runnerHeartTarget)"
        highScoreLabel.fontSize = 16
        highScoreLabel.fontColor = SKColor(white: 1, alpha: 0.6)
        highScoreLabel.horizontalAlignmentMode = .center
        highScoreLabel.verticalAlignmentMode = .center
        highScoreLabel.position = CGPoint(x: centerX, y: centerY - 10)
        overlay.addChild(highScoreLabel)

        let tryAgainButton = SKLabelNode(fontNamed: hudFontName)
        tryAgainButton.name = tryAgainButtonName
        tryAgainButton.text = "[ TRY AGAIN ]"
        tryAgainButton.fontSize = 28
        tryAgainButton.fontColor = neonCyan
        tryAgainButton.horizontalAlignmentMode = .center
        tryAgainButton.verticalAlignmentMode = .center
        tryAgainButton.position = CGPoint(x: centerX, y: centerY - 90)
        overlay.addChild(tryAgainButton)

        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.5, duration: 0.8),
            SKAction.fadeAlpha(to: 1.0, duration: 0.8)
        ])
        tryAgainButton.run(SKAction.repeatForever(pulse))

        addChild(overlay)
        overlay.run(SKAction.fadeAlpha(to: 1.0, duration: 0.3))
    }

    private func dismissGameOverAndRestart() {
        guard let overlay = childNode(withName: gameOverOverlayName) else { return }

        let fadeOut = SKAction.fadeAlpha(to: 0, duration: 0.3)
        let remove = SKAction.removeFromParent()
        overlay.run(SKAction.sequence([fadeOut, remove]))

        resetForNewAttempt()
    }

    private func stopSpawning() {
        gameLayer.enumerateChildNodes(withName: obstacleSpawnTimerName) { node, _ in
            node.removeAllActions()
            node.removeFromParent()
        }
        gameLayer.enumerateChildNodes(withName: heartSpawnTimerName) { node, _ in
            node.removeAllActions()
            node.removeFromParent()
        }
    }

    private func resetForNewAttempt() {
        heartsCollected = 0
        lastUpdateTime = 0
        horizontalVelocity = 0
        currentSpeedMultiplier = 1.0
        updateGameSpeed()

        gameLayer.enumerateChildNodes(withName: obstacleNodeName) { node, _ in
            node.removeFromParent()
        }
        gameLayer.enumerateChildNodes(withName: heartNodeName) { node, _ in
            node.removeFromParent()
        }

        if let player = playerNode {
            player.removeAllActions()
            player.alpha = 1.0
            player.setScale(1.0)
            player.zRotation = 0.0
            player.colorBlendFactor = 0.0

            // Restart hover
            setupPlayerHover()

            let highwayCenterX = size.width * (highwayLeftEdge + highwayRightEdge) / 2
            player.position = CGPoint(
                x: highwayCenterX,
                y: size.height * playerBottomFraction
            )
        }

        updateHUD()
        startSpawning()
        gameState = .playing
    }

    private func setupPlayerHover() {
        guard let player = playerNode, let shadow = shadowNode else { return }

        let hoverUp = SKAction.moveBy(x: 0, y: 8, duration: 1.2)
        hoverUp.timingMode = .easeInEaseOut
        let hoverDown = hoverUp.reversed()
        let hoverSeq = SKAction.repeatForever(SKAction.sequence([hoverUp, hoverDown]))
        player.run(hoverSeq)

        let shadowShrink = SKAction.scale(to: 0.9, duration: 1.2)
        shadowShrink.timingMode = .easeInEaseOut
        let shadowGrow = shadowShrink.reversed()
        let shadowSeq = SKAction.repeatForever(SKAction.sequence([shadowShrink, shadowGrow]))
        shadow.run(shadowSeq)
    }

    // MARK: - Heart Collection

    private func handleHeartCollection(_ node: SKNode?) {
        guard let heart = node else { return }

        // Prevent double-collection while animating out
        heart.name = nil
        heart.physicsBody = nil

        heartsCollected += 1
        run(SKAction.playSoundFileNamed(sfxChimePath, waitForCompletion: false))

        // Haptic Pop (Crisp tactile reward)
        HapticManager.shared.playTransientEvent(intensity: 0.7, sharpness: 0.8)

        updateHUD()
        checkSpeedProgression()

        // Juice: Pop up, scale up, fade out
        let juiceAction = SKAction.group([
            SKAction.scale(by: 1.5, duration: 0.15),
            SKAction.moveBy(x: 0, y: 30, duration: 0.15),
            SKAction.fadeOut(withDuration: 0.15)
        ])

        heart.run(SKAction.sequence([
            juiceAction,
            SKAction.removeFromParent()
        ]))
    }

    private func checkSpeedProgression() {
        let oldSpeed = currentSpeedMultiplier

        // More aggressive difficulty curve
        switch heartsCollected {
        case 0 ..< 5:
            currentSpeedMultiplier = 1.0
        case 5 ..< 10:
            currentSpeedMultiplier = 1.3
        case 10 ..< 15:
            currentSpeedMultiplier = 1.6
        default:
            currentSpeedMultiplier = 2.0 // High speed "bullet hell" finale
        }

        if oldSpeed != currentSpeedMultiplier {
            updateGameSpeed()
        }
    }

    private func updateGameSpeed() {
        // Speed up background parallax
        backgroundLayer.speed = currentSpeedMultiplier

        // Speed up spawn timers (spawn faster)
        gameLayer.childNode(withName: obstacleSpawnTimerName)?.speed = currentSpeedMultiplier
        gameLayer.childNode(withName: heartSpawnTimerName)?.speed = currentSpeedMultiplier

        // Speed up existing entities (move faster)
        gameLayer.enumerateChildNodes(withName: obstacleNodeName) { node, _ in
            node.speed = self.currentSpeedMultiplier
        }
        gameLayer.enumerateChildNodes(withName: heartNodeName) { node, _ in
            node.speed = self.currentSpeedMultiplier
        }
    }

    // MARK: - Win

    private func handleWin() {
        gameState = .won

        stopSpawning()
        updateHUD()
        run(SKAction.playSoundFileNamed(sfxChimePath, waitForCompletion: false))

        if heartsCollected > sessionHighScore {
            sessionHighScore = heartsCollected
        }

        // Animate Player Exit (Fly Up/Forward)
        if let player = playerNode {
            let exitAction = SKAction.moveBy(x: 0, y: size.height, duration: 0.6)
            exitAction.timingMode = .easeIn
            player.run(exitAction)
            shadowNode?.run(exitAction)
        }

        let pause = SKAction.wait(forDuration: 1.0)
        let showWin = SKAction.run { [weak self] in self?.showWinOverlay() }

        // Auto-advance sequence: Show overlay -> Wait -> Complete
        let autoAdvance = SKAction.sequence([
            pause,
            showWin,
            SKAction.wait(forDuration: 3.0),
            SKAction.run { [weak self] in
                self?.coordinator?.completeCurrentChapter()
            }
        ])

        run(autoAdvance)
    }

    // swiftlint:disable:next function_body_length
    private func showWinOverlay() {
        let overlay = SKNode()
        overlay.name = winOverlayName
        overlay.zPosition = overlayZPosition
        overlay.alpha = 0

        let dimmer = SKSpriteNode(color: SKColor(white: 0, alpha: 0.75), size: size)
        dimmer.anchorPoint = .zero
        dimmer.position = .zero
        overlay.addChild(dimmer)

        let centerX = size.width / 2
        let centerY = size.height / 2
        let neonCyan = SKColor(red: 0.0, green: 0.95, blue: 0.85, alpha: 1.0)
        let neonPink = SKColor(red: 1.0, green: 0.2, blue: 0.6, alpha: 1.0)

        let title = SKLabelNode(fontNamed: hudFontName)
        title.text = "CONNECTION SECURED"
        title.fontSize = 30
        title.fontColor = neonCyan
        title.horizontalAlignmentMode = .center
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: centerX, y: centerY + 40)
        overlay.addChild(title)

        // Glitch effect for title
        let glitch = SKAction.sequence([
            SKAction.wait(forDuration: Double.random(in: 0.1 ... 0.3)),
            SKAction.run { title.alpha = 0.5; title.position.x += 2 },
            SKAction.wait(forDuration: 0.05),
            SKAction.run { title.alpha = 1.0; title.position.x -= 2 },
            SKAction.wait(forDuration: Double.random(in: 0.1 ... 0.5))
        ])
        title.run(SKAction.repeatForever(glitch))

        let subtitle = SKLabelNode(fontNamed: hudFontName)
        subtitle.text = "All packets delivered."
        subtitle.fontSize = 18
        subtitle.fontColor = .white
        subtitle.horizontalAlignmentMode = .center
        subtitle.verticalAlignmentMode = .center
        subtitle.position = CGPoint(x: centerX, y: centerY)
        overlay.addChild(subtitle)

        let scoreLabel = SKLabelNode(fontNamed: hudFontName)
        scoreLabel.text = "\(heartsCollected)/\(GameConstants.Physics.runnerHeartTarget) Hearts"
        scoreLabel.fontSize = 22
        scoreLabel.fontColor = neonPink
        scoreLabel.horizontalAlignmentMode = .center
        scoreLabel.verticalAlignmentMode = .center
        scoreLabel.position = CGPoint(x: centerX, y: centerY - 40)
        overlay.addChild(scoreLabel)

        let autoAdvLabel = SKLabelNode(fontNamed: hudFontName)
        autoAdvLabel.text = "Establishing uplink..."
        autoAdvLabel.fontSize = 14
        autoAdvLabel.fontColor = SKColor(white: 1, alpha: 0.6)
        autoAdvLabel.horizontalAlignmentMode = .center
        autoAdvLabel.verticalAlignmentMode = .center
        autoAdvLabel.position = CGPoint(x: centerX, y: centerY - 80)
        overlay.addChild(autoAdvLabel)

        // Blink "Establishing uplink..."
        let blink = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.3, duration: 0.5),
            SKAction.fadeAlpha(to: 0.8, duration: 0.5)
        ])
        autoAdvLabel.run(SKAction.repeatForever(blink))

        addChild(overlay)
        overlay.run(SKAction.fadeAlpha(to: 1.0, duration: 0.4))
    }
}
