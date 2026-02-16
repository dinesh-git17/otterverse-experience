// swiftlint:disable file_length
import os
import SpriteKit
import UIKit

// swiftlint:disable:next type_body_length
final class FirewallScene: SKScene {
    // MARK: - Diagnostics

    #if DEBUG
        private static let logger = Logger(
            subsystem: "com.otterverse.starlightsync",
            category: "FirewallScene"
        )
    #endif

    // MARK: - Game State

    private enum GameState {
        case ready
        case playing
        case won
    }

    // MARK: - Approach Direction

    private enum ApproachDirection: CaseIterable {
        case left
        case right
        case top

        var spriteAsset: GameConstants.SpriteAsset {
            switch self {
            case .left: return .noiseLeft
            case .right: return .noiseRight
            case .top: return .noiseTop
            }
        }
    }

    // MARK: - Coordinator

    weak var coordinator: FlowCoordinator?

    // MARK: - Accessibility

    var reduceMotion = false

    // MARK: - Scene Tuning Constants

    private let spawnLeadTime: TimeInterval = 2.0
    private let shieldSizeFraction: CGFloat = 0.38
    private let particleSizeFraction: CGFloat = 0.05
    private let minimumTravelDuration: TimeInterval = 0.05
    private let victoryPauseDuration: TimeInterval = 1.5

    // MARK: - Floating Animation

    private let floatAmplitude: CGFloat = 8
    private let floatCycleDuration: TimeInterval = 2.4

    // MARK: - Plasma Arc Constants

    private let plasmaArcRadiusPadding: CGFloat = 12
    private let plasmaArcSweep: CGFloat = .pi / 2.2
    private let plasmaStrokeWidth: CGFloat = 5
    private let plasmaGlowWidth: CGFloat = 12
    private let plasmaColor = SKColor(red: 0.2, green: 0.85, blue: 1.0, alpha: 1.0)
    private let plasmaFlashDuration: TimeInterval = 0.08
    private let plasmaFadeDuration: TimeInterval = 0.35
    private let plasmaZPosition: CGFloat = 3

    // MARK: - Tap Zones

    private let deadZoneCeiling: CGFloat = 0.22
    private let topZoneFloor: CGFloat = 0.58

    // MARK: - Z Positions

    private let shieldZPosition: CGFloat = 0
    private let particleZPosition: CGFloat = 2
    private let hudZPosition: CGFloat = 10
    private let overlayZPosition: CGFloat = 50

    // MARK: - HUD Layout

    private let hudFontName = "Menlo-Bold"
    private let hudFontSize: CGFloat = 18
    private let hudTopMargin: CGFloat = 100
    private let overlayTitleFontSize: CGFloat = 36
    private let overlaySubtitleFontSize: CGFloat = 18
    private let overlayHintFontSize: CGFloat = 14
    private let overlayButtonFontSize: CGFloat = 28
    private let victoryTitleFontSize: CGFloat = 30
    private let victoryStatsFontSize: CGFloat = 20

    // MARK: - Overlay Layout Offsets

    private let titleOffsetY: CGFloat = 100
    private let contextOffsetY: CGFloat = 40
    private let hint1OffsetY: CGFloat = -20
    private let hint2OffsetY: CGFloat = -44
    private let buttonOffsetY: CGFloat = -130
    private let statsOffsetY: CGFloat = 30
    private let victoryButtonOffsetY: CGFloat = -90

    // MARK: - Color Palette (Deep-Space Sci-Fi)

    private let hudTextColor = SKColor(red: 0.3, green: 0.8, blue: 0.9, alpha: 0.7)
    private let accentCyan = SKColor(red: 0.3, green: 0.9, blue: 0.85, alpha: 1.0)
    private let hintTextColor = SKColor(white: 1, alpha: 0.7)
    private let welcomeDimAlpha: CGFloat = 0.65
    private let victoryDimAlpha: CGFloat = 0.75

    // MARK: - Animation Constants

    private let overlayFadeOutDuration: TimeInterval = 0.3
    private let overlayFadeInDuration: TimeInterval = 0.4
    private let hitDestroyDuration: TimeInterval = 0.25
    private let hitScaleTarget: CGFloat = 1.5
    private let shieldPulseScale: CGFloat = 1.06
    private let shieldPulseDuration: TimeInterval = 0.1
    private let shieldReducedAlpha: CGFloat = 0.7
    private let missFlashBlend: CGFloat = 0.5
    private let missFlashDuration: TimeInterval = 0.1
    private let missRecoverDuration: TimeInterval = 0.2
    private let missFadeDuration: TimeInterval = 0.2
    private let pulseMinAlpha: CGFloat = 0.5
    private let pulseCycleDuration: TimeInterval = 0.8
    private let sfxPrewarmDuration: TimeInterval = 0.05

    // MARK: - SFX File Paths

    private let sfxShieldImpactPath = [
        "Audio/SFX",
        GameConstants.AudioAsset.sfxShieldImpact.rawValue
    ].joined(separator: "/") + ".\(GameConstants.AudioAsset.fileExtension)"

    // MARK: - Node Names

    private let welcomeOverlayName = "welcomeOverlay"
    private let victoryOverlayName = "victoryOverlay"
    private let playButtonName = "playButton"
    private let continueButtonName = "continueButton"

    // MARK: - Content Guard

    private let minimumSceneSize: CGFloat = 100

    // MARK: - State

    private var isContentSetUp = false
    private var gameState: GameState = .ready
    private var lastUpdateTime: TimeInterval = 0
    private var audioStartTime: CFTimeInterval = 0
    private var nextBeatIndex: Int = 0
    private var missCheckIndex: Int = 0
    private var hitCount: Int = 0
    private var missCount: Int = 0
    private var beatResolved: [Bool] = []
    private var completionFired = false

    // MARK: - Particle Tracking

    private var activeParticles: [Int: (node: SKSpriteNode, direction: ApproachDirection)] = [:]

    // MARK: - Node References

    private var shieldNode: SKSpriteNode?
    private var progressLabel: SKLabelNode?
    private var shieldBaseY: CGFloat = 0

    // MARK: - Texture Atlas

    private lazy var spriteAtlas: SKTextureAtlas = .init(
        named: GameConstants.SpriteAtlas.sprites.rawValue
    )

    // MARK: - Computed Properties

    private var isAutoAssistActive: Bool {
        missCount >= GameConstants.AutoAssist.firewallMissThreshold
    }

    private var activeHitWindow: TimeInterval {
        isAutoAssistActive
            ? GameConstants.Difficulty.firewallAssistedHitWindow
            : GameConstants.Difficulty.firewallDefaultHitWindow
    }

    // MARK: - Scene Lifecycle

    override func didMove(to view: SKView) {
        view.preferredFramesPerSecond = GameConstants.Physics.targetFrameRate
        backgroundColor = .black
    }

    override func willMove(from _: SKView) {
        removeAllActions()
        removeAllChildren()
        physicsWorld.contactDelegate = nil
        coordinator = nil
    }

    // MARK: - Content Setup

    private func setupContent() {
        guard !isContentSetUp else { return }
        isContentSetUp = true

        let beatCount = GameConstants.BeatMap.timestamps.count
        beatResolved = Array(repeating: false, count: beatCount)

        setupShield()
        setupHUD()
        prewarmSFX()
        showWelcomeOverlay()
    }

    private func setupShield() {
        let texture = spriteAtlas.textureNamed(
            GameConstants.SpriteAsset.bubbleShield.rawValue
        )
        let shield = SKSpriteNode(texture: texture)
        let smaller = min(size.width, size.height)
        let targetSize = smaller * shieldSizeFraction
        let texSize = texture.size()
        let aspect = texSize.width / max(texSize.height, 1)
        shield.size = CGSize(width: targetSize * aspect, height: targetSize)
        shieldBaseY = size.height * 0.4
        shield.position = CGPoint(x: size.width / 2, y: shieldBaseY)
        shield.zPosition = shieldZPosition
        addChild(shield)
        shieldNode = shield

        guard !reduceMotion else { return }
        let floatUp = SKAction.moveBy(x: 0, y: floatAmplitude, duration: floatCycleDuration / 2)
        let floatDown = SKAction.moveBy(x: 0, y: -floatAmplitude, duration: floatCycleDuration / 2)
        floatUp.timingMode = .easeInEaseOut
        floatDown.timingMode = .easeInEaseOut
        shield.run(SKAction.repeatForever(SKAction.sequence([floatUp, floatDown])))
    }

    private func setupHUD() {
        let label = SKLabelNode(fontNamed: hudFontName)
        label.fontSize = hudFontSize
        label.fontColor = hudTextColor
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .top
        label.position = CGPoint(x: size.width / 2, y: size.height - hudTopMargin)
        label.zPosition = hudZPosition
        label.text = "0 / \(GameConstants.BeatMap.timestamps.count)"
        label.alpha = 0
        addChild(label)
        progressLabel = label
    }

    private func updateHUD() {
        let processed = hitCount + missCount
        progressLabel?.text = "\(processed) / \(GameConstants.BeatMap.timestamps.count)"
    }

    private func prewarmSFX() {
        let node = SKAudioNode(fileNamed: sfxShieldImpactPath)
        node.autoplayLooped = false
        node.isPositional = false
        addChild(node)
        node.run(SKAction.sequence([
            SKAction.changeVolume(to: 0, duration: 0),
            SKAction.play(),
            SKAction.wait(forDuration: sfxPrewarmDuration),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - Welcome Overlay

    // swiftlint:disable:next function_body_length
    private func showWelcomeOverlay() {
        let overlay = SKNode()
        overlay.name = welcomeOverlayName
        overlay.zPosition = overlayZPosition

        let dimmer = SKSpriteNode(color: SKColor(white: 0, alpha: welcomeDimAlpha), size: size)
        dimmer.anchorPoint = .zero
        overlay.addChild(dimmer)

        let centerX = size.width / 2
        let centerY = size.height / 2

        let title = SKLabelNode(fontNamed: hudFontName)
        title.text = "THE FIREWALL"
        title.fontSize = overlayTitleFontSize
        title.fontColor = accentCyan
        title.horizontalAlignmentMode = .center
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: centerX, y: centerY + titleOffsetY)
        overlay.addChild(title)

        let context = SKLabelNode(fontNamed: hudFontName)
        context.text = "Protecting the Peace"
        context.fontSize = overlaySubtitleFontSize
        context.fontColor = .white
        context.horizontalAlignmentMode = .center
        context.verticalAlignmentMode = .center
        context.position = CGPoint(x: centerX, y: centerY + contextOffsetY)
        overlay.addChild(context)

        let hint1 = SKLabelNode(fontNamed: hudFontName)
        hint1.text = "Tap left, right, or above"
        hint1.fontSize = overlayHintFontSize
        hint1.fontColor = hintTextColor
        hint1.horizontalAlignmentMode = .center
        hint1.verticalAlignmentMode = .center
        hint1.position = CGPoint(x: centerX, y: centerY + hint1OffsetY)
        overlay.addChild(hint1)

        let hint2 = SKLabelNode(fontNamed: hudFontName)
        hint2.text = "to raise a plasma shield"
        hint2.fontSize = overlayHintFontSize
        hint2.fontColor = hintTextColor
        hint2.horizontalAlignmentMode = .center
        hint2.verticalAlignmentMode = .center
        hint2.position = CGPoint(x: centerX, y: centerY + hint2OffsetY)
        overlay.addChild(hint2)

        let play = SKLabelNode(fontNamed: hudFontName)
        play.name = playButtonName
        play.text = "[ PLAY ]"
        play.fontSize = overlayButtonFontSize
        play.fontColor = accentCyan
        play.horizontalAlignmentMode = .center
        play.verticalAlignmentMode = .center
        play.position = CGPoint(x: centerX, y: centerY + buttonOffsetY)
        overlay.addChild(play)

        play.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: pulseMinAlpha, duration: pulseCycleDuration),
            SKAction.fadeAlpha(to: 1.0, duration: pulseCycleDuration)
        ])))

        addChild(overlay)
    }

    private func dismissWelcomeAndStart() {
        guard let overlay = childNode(withName: welcomeOverlayName) else { return }

        overlay.run(SKAction.sequence([
            SKAction.fadeAlpha(to: 0, duration: overlayFadeOutDuration),
            SKAction.removeFromParent()
        ]))

        AudioManager.shared.crossFadeToBGM(
            named: GameConstants.AudioAsset.bgmMain.rawValue,
            fileExtension: GameConstants.AudioAsset.fileExtension
        )
        audioStartTime = CACurrentMediaTime()

        progressLabel?.alpha = 1
        gameState = .playing
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

        let elapsed = CACurrentMediaTime() - audioStartTime
        processSpawning(elapsed: elapsed)
        processMissDetection(elapsed: elapsed)
        processWinCondition(elapsed: elapsed)
    }

    // MARK: - Beat Spawning

    private func processSpawning(elapsed: TimeInterval) {
        let timestamps = GameConstants.BeatMap.timestamps
        while nextBeatIndex < timestamps.count {
            let threshold = timestamps[nextBeatIndex] - spawnLeadTime
            guard elapsed >= threshold else { break }
            spawnNoiseParticle(beatIndex: nextBeatIndex)
            nextBeatIndex += 1
        }
    }

    // swiftlint:disable:next function_body_length
    private func spawnNoiseParticle(beatIndex: Int) {
        let direction = ApproachDirection.allCases[beatIndex % ApproachDirection.allCases.count]
        let texture = spriteAtlas.textureNamed(direction.spriteAsset.rawValue)
        let particle = SKSpriteNode(texture: texture)

        let smaller = min(size.width, size.height)
        let target = smaller * particleSizeFraction
        let texSize = texture.size()
        let aspect = texSize.width / max(texSize.height, 1)
        particle.size = CGSize(width: target * aspect, height: target)
        particle.zPosition = particleZPosition

        guard let shield = shieldNode else { return }
        let shieldPos = shield.position
        let shieldRadius = max(shield.size.width, shield.size.height) / 2

        let halfW = particle.size.width / 2
        let halfH = particle.size.height / 2
        let contactPoint: CGPoint
        switch direction {
        case .left:
            contactPoint = CGPoint(x: shieldPos.x - shieldRadius - halfW, y: shieldPos.y)
        case .right:
            contactPoint = CGPoint(x: shieldPos.x + shieldRadius + halfW, y: shieldPos.y)
        case .top:
            contactPoint = CGPoint(x: shieldPos.x, y: shieldPos.y + shieldRadius + halfH)
        }

        if reduceMotion {
            particle.position = contactPoint
        } else {
            let spawnPosition: CGPoint
            switch direction {
            case .left:
                spawnPosition = CGPoint(
                    x: -particle.size.width / 2,
                    y: shieldPos.y
                )
            case .right:
                spawnPosition = CGPoint(
                    x: size.width + particle.size.width / 2,
                    y: shieldPos.y
                )
            case .top:
                spawnPosition = CGPoint(
                    x: shieldPos.x,
                    y: size.height + particle.size.height / 2
                )
            }
            particle.position = spawnPosition

            let beatTime = GameConstants.BeatMap.timestamps[beatIndex]
            let now = CACurrentMediaTime() - audioStartTime
            let travel = max(beatTime - now, minimumTravelDuration)
            let moveAction = SKAction.move(to: contactPoint, duration: travel)
            particle.run(SKAction.sequence([
                moveAction,
                SKAction.run { [weak self] in
                    self?.handleThreatArrival(beatIndex: beatIndex)
                }
            ]))
        }

        addChild(particle)
        activeParticles[beatIndex] = (node: particle, direction: direction)
    }

    // MARK: - Threat Arrival

    private func handleThreatArrival(beatIndex: Int) {
        guard !beatResolved[beatIndex] else { return }
        resolveMiss(beatIndex: beatIndex)
    }

    // MARK: - Miss Detection

    private func processMissDetection(elapsed: TimeInterval) {
        let timestamps = GameConstants.BeatMap.timestamps
        while missCheckIndex < timestamps.count {
            let deadline = timestamps[missCheckIndex] + activeHitWindow
            guard elapsed > deadline else { break }
            if !beatResolved[missCheckIndex] {
                resolveMiss(beatIndex: missCheckIndex)
            }
            missCheckIndex += 1
        }
    }

    private func resolveMiss(beatIndex: Int) {
        beatResolved[beatIndex] = true
        missCount += 1

        HapticManager.shared.playTransientEvent(intensity: 0.8, sharpness: 0.6)

        if let shield = shieldNode {
            shield.run(SKAction.sequence([
                SKAction.colorize(
                    with: .red,
                    colorBlendFactor: missFlashBlend,
                    duration: missFlashDuration
                ),
                SKAction.colorize(withColorBlendFactor: 0, duration: missRecoverDuration)
            ]))
        }

        if let entry = activeParticles.removeValue(forKey: beatIndex) {
            entry.node.removeAllActions()
            explodeNode(entry.node)
        }

        updateHUD()
    }

    // MARK: - Win Condition

    private func processWinCondition(elapsed: TimeInterval) {
        let timestamps = GameConstants.BeatMap.timestamps
        guard nextBeatIndex >= timestamps.count,
              missCheckIndex >= timestamps.count,
              elapsed >= GameConstants.Timing.firewallDuration else { return }

        gameState = .won
        run(SKAction.sequence([
            SKAction.wait(forDuration: victoryPauseDuration),
            SKAction.run { [weak self] in self?.showVictoryOverlay() }
        ]))
    }

    // MARK: - Victory Overlay

    private func showVictoryOverlay() {
        let overlay = SKNode()
        overlay.name = victoryOverlayName
        overlay.zPosition = overlayZPosition
        overlay.alpha = 0

        let dimmer = SKSpriteNode(color: SKColor(white: 0, alpha: victoryDimAlpha), size: size)
        dimmer.anchorPoint = .zero
        overlay.addChild(dimmer)

        let centerX = size.width / 2
        let centerY = size.height / 2

        let title = SKLabelNode(fontNamed: hudFontName)
        title.text = "NOISE NEUTRALIZED"
        title.fontSize = victoryTitleFontSize
        title.fontColor = accentCyan
        title.horizontalAlignmentMode = .center
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: centerX, y: centerY + titleOffsetY)
        overlay.addChild(title)

        let stats = SKLabelNode(fontNamed: hudFontName)
        stats.text = "\(hitCount)/\(GameConstants.BeatMap.timestamps.count) Deflected"
        stats.fontSize = victoryStatsFontSize
        stats.fontColor = .white
        stats.horizontalAlignmentMode = .center
        stats.verticalAlignmentMode = .center
        stats.position = CGPoint(x: centerX, y: centerY + statsOffsetY)
        overlay.addChild(stats)

        let button = SKLabelNode(fontNamed: hudFontName)
        button.name = continueButtonName
        button.text = "[ CONTINUE ]"
        button.fontSize = overlayButtonFontSize
        button.fontColor = accentCyan
        button.horizontalAlignmentMode = .center
        button.verticalAlignmentMode = .center
        button.position = CGPoint(x: centerX, y: centerY + victoryButtonOffsetY)
        overlay.addChild(button)

        button.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: pulseMinAlpha, duration: pulseCycleDuration),
            SKAction.fadeAlpha(to: 1.0, duration: pulseCycleDuration)
        ])))

        addChild(overlay)
        overlay.run(SKAction.fadeAlpha(to: 1.0, duration: overlayFadeInDuration))
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with _: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let tapped = nodes(at: location)

        switch gameState {
        case .ready:
            if tapped.contains(where: { $0.name == playButtonName }) {
                dismissWelcomeAndStart()
            }
        case .playing:
            guard let direction = directionForTap(at: location) else { return }
            showPlasmaArc(direction: direction)
            let tapTime = CACurrentMediaTime() - audioStartTime
            evaluateZoneTap(direction: direction, tapTime: tapTime)
        case .won:
            if tapped.contains(where: { $0.name == continueButtonName }) {
                guard !completionFired else { return }
                completionFired = true
                coordinator?.completeCurrentChapter()
            }
        }
    }

    override func touchesMoved(_: Set<UITouch>, with _: UIEvent?) {}
    override func touchesEnded(_: Set<UITouch>, with _: UIEvent?) {}
    override func touchesCancelled(_: Set<UITouch>, with _: UIEvent?) {}

    // MARK: - Tap Zone Detection

    private func directionForTap(at location: CGPoint) -> ApproachDirection? {
        if location.y < size.height * deadZoneCeiling {
            return nil
        }
        if location.y > size.height * topZoneFloor {
            return .top
        }
        return location.x < size.width / 2 ? .left : .right
    }

    // MARK: - Plasma Arc

    private func showPlasmaArc(direction: ApproachDirection) {
        guard let shield = shieldNode else { return }

        let radius = max(shield.size.width, shield.size.height) / 2 + plasmaArcRadiusPadding

        let centerAngle: CGFloat
        switch direction {
        case .left: centerAngle = .pi
        case .right: centerAngle = 0
        case .top: centerAngle = .pi / 2
        }

        let startAngle = centerAngle - plasmaArcSweep / 2
        let endAngle = centerAngle + plasmaArcSweep / 2

        let path = UIBezierPath(
            arcCenter: .zero,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: true
        )

        let arc = SKShapeNode(path: path.cgPath)
        arc.strokeColor = plasmaColor
        arc.lineWidth = plasmaStrokeWidth
        arc.glowWidth = plasmaGlowWidth
        arc.fillColor = .clear
        arc.lineCap = .round
        arc.position = shield.position
        arc.zPosition = plasmaZPosition
        arc.alpha = 0
        addChild(arc)

        if reduceMotion {
            arc.run(SKAction.sequence([
                SKAction.fadeAlpha(to: 1.0, duration: 0),
                SKAction.wait(forDuration: plasmaFlashDuration + plasmaFadeDuration),
                SKAction.removeFromParent()
            ]))
        } else {
            arc.run(SKAction.sequence([
                SKAction.fadeAlpha(to: 1.0, duration: plasmaFlashDuration),
                SKAction.fadeAlpha(to: 0, duration: plasmaFadeDuration),
                SKAction.removeFromParent()
            ]))
        }
    }

    // MARK: - Explosion Effect

    private func explodeNode(_ node: SKSpriteNode) {
        if reduceMotion {
            node.run(SKAction.sequence([
                SKAction.fadeOut(withDuration: hitDestroyDuration),
                SKAction.removeFromParent()
            ]))
            return
        }

        let flashWhite = SKAction.colorize(with: .white, colorBlendFactor: 1.0, duration: 0.04)
        let burstScale = SKAction.scale(to: 2.0, duration: hitDestroyDuration)
        let fadeOut = SKAction.fadeOut(withDuration: hitDestroyDuration)
        burstScale.timingMode = .easeOut
        fadeOut.timingMode = .easeIn

        node.run(SKAction.sequence([
            flashWhite,
            SKAction.group([burstScale, fadeOut]),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - Hit Evaluation

    private func evaluateZoneTap(direction: ApproachDirection, tapTime: TimeInterval) {
        let timestamps = GameConstants.BeatMap.timestamps

        var bestIndex: Int?
        var bestDelta: TimeInterval = .greatestFiniteMagnitude

        for (beatIndex, entry) in activeParticles {
            guard !beatResolved[beatIndex] else { continue }
            guard entry.direction == direction else { continue }

            let delta = abs(tapTime - timestamps[beatIndex])
            guard delta <= activeHitWindow else { continue }
            if delta < bestDelta {
                bestDelta = delta
                bestIndex = beatIndex
            }
        }

        guard let matched = bestIndex else { return }
        resolveHit(beatIndex: matched)
    }

    private func resolveHit(beatIndex: Int) {
        beatResolved[beatIndex] = true
        hitCount += 1

        run(SKAction.playSoundFileNamed(sfxShieldImpactPath, waitForCompletion: false))

        if let entry = activeParticles.removeValue(forKey: beatIndex) {
            entry.node.removeAllActions()
            explodeNode(entry.node)
        }

        if let shield = shieldNode {
            if reduceMotion {
                shield.run(SKAction.sequence([
                    SKAction.fadeAlpha(to: shieldReducedAlpha, duration: shieldPulseDuration),
                    SKAction.fadeAlpha(to: 1.0, duration: shieldPulseDuration)
                ]))
            } else {
                shield.run(SKAction.sequence([
                    SKAction.scale(to: shieldPulseScale, duration: shieldPulseDuration),
                    SKAction.scale(to: 1.0, duration: shieldPulseDuration)
                ]))
            }
        }

        updateHUD()
    }
}
