# SpriteKit Chapter Template

Deterministic output structure for SpriteKit-based chapters (2, 4).

## File 1: `{Name}Scene.swift`

```swift
import SpriteKit

final class {Name}Scene: SKScene, SKPhysicsContactDelegate {

    // MARK: - Coordinator Reference

    weak var coordinator: FlowCoordinator?

    // MARK: - Game State

    private var {chapterSpecificState}: {Type} = {defaultValue}
    private var failureCount = 0
    private var autoAssistActive = false
    private var elapsedTime: TimeInterval = 0
    private var lastUpdateTime: TimeInterval = 0

    // MARK: - Physics Categories

    private struct PhysicsCategory {
        static let none: UInt32       = 0
        static let player: UInt32     = 0b0001
        static let obstacle: UInt32   = 0b0010
        static let collectible: UInt32 = 0b0100
    }

    // MARK: - Scene Lifecycle

    override func didMove(to view: SKView) {
        preferredFramesPerSecond = 120
        physicsWorld.contactDelegate = self
        physicsWorld.gravity = .zero  // Adjust per chapter

        setupScene()
    }

    override func willMove(from view: SKView) {
        // MANDATORY CLEANUP — prevents memory leaks
        removeAllChildren()
        removeAllActions()
        // Invalidate any CADisplayLink or Timer references
    }

    // MARK: - Setup

    private func setupScene() {
        // Configure background, player, spawn systems
        // All numeric values from GameConstants.Chapter{N}
    }

    // MARK: - Game Loop

    override func update(_ currentTime: TimeInterval) {
        guard lastUpdateTime > 0 else {
            lastUpdateTime = currentTime
            return
        }

        let deltaTime = currentTime - lastUpdateTime
        lastUpdateTime = currentTime
        elapsedTime += deltaTime

        updateGameState(deltaTime: deltaTime)
        evaluateWinCondition()
    }

    private func updateGameState(deltaTime: TimeInterval) {
        // Frame-level state updates
        // Apply Auto-Assist modifiers if active
    }

    // MARK: - Physics Contact

    func didBegin(_ contact: SKPhysicsContact) {
        let collision = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask
        // Handle collisions via bitmask comparison
        // No frame-by-frame distance checks
    }

    // MARK: - Input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        // Handle input
    }

    // MARK: - Win Condition

    private func evaluateWinCondition() {
        // Check against GameConstants threshold
        // guard {condition} else { return }
        // Task { @MainActor in coordinator?.completeChapter({N}) }
    }

    // MARK: - Auto-Assist

    private func recordFailure() {
        failureCount += 1
        if failureCount >= GameConstants.Chapter{N}.autoAssistThreshold {
            activateAutoAssist()
        }
    }

    private func activateAutoAssist() {
        guard !autoAssistActive else { return }
        autoAssistActive = true
        // Apply mechanism silently
    }
}
```

## File 2: `{Name}View.swift` (SpriteView Wrapper)

```swift
import SwiftUI
import SpriteKit

struct {Name}View: View {

    var coordinator: FlowCoordinator

    @State private var scene: {Name}Scene?

    var body: some View {
        Group {
            if let scene {
                SpriteView(scene: scene)
                    .ignoresSafeArea()
            }
        }
        .onAppear {
            let newScene = {Name}Scene(
                size: UIScreen.main.bounds.size
            )
            newScene.scaleMode = .resizeFill
            newScene.coordinator = coordinator
            scene = newScene
        }
        .onDisappear {
            // MANDATORY — prevent SpriteView memory retention
            scene?.removeAllChildren()
            scene?.removeAllActions()
            scene = nil
        }
    }
}

#Preview {
    {Name}View(coordinator: FlowCoordinator())
}
```

## Structural Rules

1. **Scene cleanup is mandatory.** `willMove(from:)` MUST call `removeAllChildren()` and `removeAllActions()`.
2. **SpriteView wrapper manages lifecycle.** `.onDisappear` nullifies the scene reference.
3. **Physics uses bitmasks.** Define a `PhysicsCategory` struct with `UInt32` constants.
4. **120fps target.** Set in `didMove(to:)`.
5. **Coordinator reference is `weak`.** Prevents retain cycles between scene and coordinator.
6. **Completion via MainActor.** Scene reports completion through `Task { @MainActor in }` to ensure thread safety.
7. **No Timer or DispatchQueue.** Use `update(_:)` for frame timing. Use `CACurrentMediaTime()` for audio sync.
8. **Named constants.** All speeds, spawn intervals, thresholds from `GameConstants.Chapter{N}`.
