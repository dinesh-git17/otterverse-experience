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

    // MARK: - Layer Containers

    private let backgroundLayer = SKNode()
    private let gameLayer = SKNode()

    // MARK: - Node References

    private var playerNode: SKSpriteNode?
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

        backgroundLayer.alpha = 0
        gameLayer.alpha = 0
        backgroundLayer.run(SKAction.fadeAlpha(to: 1.0, duration: sceneFadeInDuration))
        gameLayer.run(SKAction.fadeAlpha(to: 1.0, duration: sceneFadeInDuration)) { [weak self] in
            self?.showWelcomeOverlay()
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
    }

    // MARK: - HUD Setup

    private func setupHUD() {
        let neonPink = SKColor(red: 1.0, green: 0.2, blue: 0.6, alpha: 1.0)

        let hearts = SKLabelNode(fontNamed: hudFontName)
        hearts.fontSize = hudFontSize
        hearts.fontColor = neonPink
        hearts.horizontalAlignmentMode = .right
        hearts.verticalAlignmentMode = .top
        hearts.position = CGPoint(
            x: size.width - hudSideMargin,
            y: size.height - hudTopMargin
        )
        hearts.zPosition = hudZPosition
        hearts.alpha = 0
        addChild(hearts)
        heartLabel = hearts
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

        let fadeOut = SKAction.fadeAlpha(to: 0, duration: 0.3)
        let remove = SKAction.removeFromParent()
        overlay.run(SKAction.sequence([fadeOut, remove]))

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

        if heartsCollected >= GameConstants.Physics.runnerHeartTarget {
            handleWin()
            return
        }

        checkCollisions()
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
    }

    override func touchesEnded(_: Set<UITouch>, with _: UIEvent?) {}

    override func touchesCancelled(_: Set<UITouch>, with _: UIEvent?) {}

    // MARK: - Death & Game Over

    private func handleDeath() {
        gameState = .death

        guard let player = playerNode else { return }

        HapticManager.shared.play(GameConstants.HapticAsset.thud.rawValue)
        run(SKAction.playSoundFileNamed(sfxThudPath, waitForCompletion: false))

        stopSpawning()

        let flash = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.2, duration: deathFlashDuration),
            SKAction.fadeAlpha(to: 1.0, duration: deathFlashDuration),
            SKAction.fadeAlpha(to: 0.2, duration: deathFlashDuration),
            SKAction.fadeAlpha(to: 1.0, duration: deathFlashDuration)
        ])
        let showOverlay = SKAction.run { [weak self] in self?.showGameOverOverlay() }

        player.run(SKAction.sequence([flash, showOverlay]))
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

        gameLayer.enumerateChildNodes(withName: obstacleNodeName) { node, _ in
            node.removeFromParent()
        }
        gameLayer.enumerateChildNodes(withName: heartNodeName) { node, _ in
            node.removeFromParent()
        }

        if let player = playerNode {
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

    // MARK: - Heart Collection

    private func handleHeartCollection(_ node: SKNode?) {
        node?.removeFromParent()
        heartsCollected += 1
        run(SKAction.playSoundFileNamed(sfxChimePath, waitForCompletion: false))
        updateHUD()
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

        let pause = SKAction.wait(forDuration: victoryPauseDuration)
        let showWin = SKAction.run { [weak self] in self?.showWinOverlay() }
        run(SKAction.sequence([pause, showWin]))
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
        title.position = CGPoint(x: centerX, y: centerY + 100)
        overlay.addChild(title)

        let subtitle = SKLabelNode(fontNamed: hudFontName)
        subtitle.text = "All packets delivered."
        subtitle.fontSize = 18
        subtitle.fontColor = .white
        subtitle.horizontalAlignmentMode = .center
        subtitle.verticalAlignmentMode = .center
        subtitle.position = CGPoint(x: centerX, y: centerY + 40)
        overlay.addChild(subtitle)

        let scoreLabel = SKLabelNode(fontNamed: hudFontName)
        scoreLabel.text = "\(heartsCollected)/\(GameConstants.Physics.runnerHeartTarget) Hearts"
        scoreLabel.fontSize = 22
        scoreLabel.fontColor = neonPink
        scoreLabel.horizontalAlignmentMode = .center
        scoreLabel.verticalAlignmentMode = .center
        scoreLabel.position = CGPoint(x: centerX, y: centerY - 10)
        overlay.addChild(scoreLabel)

        let continueButton = SKLabelNode(fontNamed: hudFontName)
        continueButton.name = continueButtonName
        continueButton.text = "[ CONTINUE ]"
        continueButton.fontSize = 28
        continueButton.fontColor = neonCyan
        continueButton.horizontalAlignmentMode = .center
        continueButton.verticalAlignmentMode = .center
        continueButton.position = CGPoint(x: centerX, y: centerY - 90)
        overlay.addChild(continueButton)

        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.5, duration: 0.8),
            SKAction.fadeAlpha(to: 1.0, duration: 0.8)
        ])
        continueButton.run(SKAction.repeatForever(pulse))

        addChild(overlay)
        overlay.run(SKAction.fadeAlpha(to: 1.0, duration: 0.4))
    }
}
