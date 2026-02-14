---
name: spritekit-lifecycle
description: Enforce SpriteKit scene lifecycle patterns, deterministic cleanup guarantees, physics category bitmask configuration, 120fps ProMotion rendering constraints, SpriteView memory leak prevention, and texture atlas preloading integration for all SKScene subclasses. Use when a SpriteKit scene is implemented, game mechanics involving physics are built, scene lifecycle or cleanup code is written, SpriteView wrappers are created, or rendering performance tuning is performed. Triggers on SKScene creation, physics configuration, scene transition handling, SpriteView integration, frame rate targeting, or texture preloading.
---

# SpriteKit Lifecycle

Enforce deterministic scene lifecycle, physics configuration, rendering performance, and memory safety for all SpriteKit scenes in this project. Applies to Chapters 2 (PacketRunScene) and 4 (FirewallScene).

## Pre-Implementation Verification

Before writing any `SKScene` subclass code, verify:

1. The target chapter (2 or 4) is designated as SpriteKit in `Design-Doc.md` §3.
2. The scene file resides in `Chapters/Chapter{N}_{Name}/`.
3. A corresponding `SpriteView` wrapper exists in the same directory.
4. Texture atlases for the chapter are defined in `Assets.xcassets/Sprites.spriteatlas/`.

If any verification fails, **HALT** and cite the specific constraint.

## Scene Lifecycle Rules

### Mandatory `willMove(from:)` Cleanup

Every `SKScene` subclass MUST override `willMove(from:)` with the following deterministic cleanup sequence. Order matters.

```swift
override func willMove(from view: SKView) {
    removeAllActions()
    removeAllChildren()
    physicsWorld.contactDelegate = nil
    // Nil out all strong references to external objects
}
```

**Cleanup sequence (strict order):**

1. `removeAllActions()` — halts all running `SKAction` instances, breaking action-closure retain cycles.
2. `removeAllChildren()` — recursively removes all child nodes, their actions, and physics bodies.
3. `physicsWorld.contactDelegate = nil` — breaks the delegate reference to prevent retain cycles.
4. Nil out external references — any properties holding `FlowCoordinator`, completion callbacks, or data model references.

### Deallocation Verification

Every `SKScene` subclass MUST include a `deinit` guard during development:

```swift
#if DEBUG
deinit {
    let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "", category: "SceneLifecycle")
    logger.debug("Deallocated: \(String(describing: type(of: self)))")
}
#endif
```

If `deinit` is never called after scene transition, a retain cycle exists. Use Xcode Memory Graph Debugger to trace the retaining reference.

### Action Closure Safety

All `SKAction.run { }` closures MUST capture `self` weakly:

```swift
let action = SKAction.run { [weak self] in
    self?.handleEvent()
}
```

`SKAction.perform(_:onTarget:)` is **prohibited** — it creates undocumented strong references. Use `SKAction.run { [weak self] in ... }` exclusively.

### Timer Prohibition

Game timing in SpriteKit scenes MUST use `SKAction.wait(forDuration:)` sequences:

```swift
let spawnLoop = SKAction.sequence([
    SKAction.wait(forDuration: 2.0),
    SKAction.run { [weak self] in self?.spawnObstacle() }
])
run(SKAction.repeatForever(spawnLoop), withKey: "spawner")
```

**Prohibited alternatives:**

- `Foundation.Timer` / `Timer.scheduledTimer` — not pause-aware, creates strong target references.
- `DispatchQueue.asyncAfter` — violates `CLAUDE.md` §4.1 GCD prohibition.
- `Task.sleep` — not integrated with SpriteKit pause state.
- `CACurrentMediaTime()` is permitted exclusively for audio beat synchronization (`Design-Doc.md` §7.5), not for game loop timing.

## Physics Configuration Rules

### Category Bitmask Architecture

All collision detection MUST use `SKPhysicsBody` category bitmasks. Frame-by-frame distance checks are **prohibited** (`CLAUDE.md` §4.3).

Define physics categories as a `UInt32`-backed enum in the scene file:

```swift
enum PhysicsCategory {
    static let none:        UInt32 = 0
    static let player:      UInt32 = 1 << 0
    static let obstacle:    UInt32 = 1 << 1
    static let collectible: UInt32 = 1 << 2
    static let ground:      UInt32 = 1 << 3
    static let boundary:    UInt32 = 1 << 4
}
```

### Physics Body Configuration Template

```swift
node.physicsBody = SKPhysicsBody(rectangleOf: node.size)
node.physicsBody?.categoryBitMask = PhysicsCategory.player
node.physicsBody?.collisionBitMask = PhysicsCategory.ground | PhysicsCategory.boundary
node.physicsBody?.contactTestBitMask = PhysicsCategory.obstacle | PhysicsCategory.collectible
node.physicsBody?.isDynamic = true
node.physicsBody?.affectedByGravity = true
```

### Physics Performance Constraints

1. **Minimize `contactTestBitMask` scope.** Only request contact callbacks for interactions requiring game logic. Each contact event dispatches on the main thread.
2. **Prefer simple body shapes.** Performance hierarchy: `circleOfRadius:` > `rectangleOf:` > `polygonFrom:` > `texture:size:`. Avoid `texture:size:` — it generates convex hulls from alpha channels at creation time.
3. **Use static bodies for non-moving elements.** Set `isDynamic = false` on walls, floors, and boundaries. Static bodies skip physics integration.
4. **Node removal safety.** Set `physicsBody = nil` before calling `removeFromParent()`, or defer removal to `didSimulatePhysics()` to prevent mid-simulation contact resolution against stale nodes.

### Contact Delegate Pattern

The scene MUST conform to `SKPhysicsContactDelegate` and assign itself in `didMove(to:)`:

```swift
override func didMove(to view: SKView) {
    physicsWorld.contactDelegate = self
    physicsWorld.gravity = CGVector(dx: 0, dy: GameConstants.gravity)
}

func didBegin(_ contact: SKPhysicsContact) {
    let collision = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask
    // Deterministic collision resolution via bitmask union
}
```

## Rendering Performance Enforcement

### 120fps ProMotion Target

Every `SKScene` subclass MUST set the frame rate target:

```swift
override func didMove(to view: SKView) {
    preferredFramesPerSecond = 120
}
```

The corresponding `SpriteView` wrapper MUST pass the same target:

```swift
SpriteView(scene: scene, preferredFramesPerSecond: 120)
```

### Frame-Rate-Independent Logic

All movement, spawning, and game logic MUST use delta time. Never bind logic to frame count.

```swift
private var lastUpdateTime: TimeInterval = 0

override func update(_ currentTime: TimeInterval) {
    let deltaTime: TimeInterval
    if lastUpdateTime == 0 {
        deltaTime = 0
    } else {
        deltaTime = currentTime - lastUpdateTime
    }
    lastUpdateTime = currentTime

    updateGameState(deltaTime: deltaTime)
}
```

### Frame Budget Awareness

At 120fps, each frame has an **8.33ms budget**. The following constraints apply:

- Keep `update(_:)` logic under 4ms to leave headroom for physics and rendering.
- Avoid `SKEffectNode` and `SKCropNode` — each adds a full render pass.
- Limit particle emitter `birthRate` to the minimum required for visual effect.
- Use `SKBlendMode.replace` on opaque background sprites to eliminate alpha compositing cost.

### Draw Call Optimization

Configure `SpriteView` with `ignoresSiblingOrder` to enable draw call batching:

```swift
SpriteView(
    scene: scene,
    preferredFramesPerSecond: 120,
    options: [.ignoresSiblingOrder]
)
```

When enabled, nodes sharing the same `zPosition` and texture atlas are batched into a single draw call. Use explicit `zPosition` values to control render order instead of child insertion order.

## SpriteView Lifecycle Safety

### Memory Leak Prevention

`SpriteView` retains its scene reference and does not release it when removed from the SwiftUI hierarchy. The wrapper view MUST use an optional scene pattern:

```swift
struct ChapterSceneView: View {
    @State private var scene: ChapterScene? = ChapterScene(
        size: CGSize(width: 390, height: 844)
    )

    var body: some View {
        Group {
            if let scene {
                SpriteView(
                    scene: scene,
                    preferredFramesPerSecond: 120,
                    options: [.ignoresSiblingOrder]
                )
            }
        }
        .onDisappear {
            scene?.removeAllActions()
            scene?.removeAllChildren()
            scene = nil
        }
    }
}
```

### SpriteView Parameter Immutability

`SpriteView` initializer parameters are part of SwiftUI's view identity. Changing any parameter (including `isPaused`) triggers view recreation, which destroys and rebuilds the underlying `SKView`.

- **Never** bind `isPaused` to dynamic SwiftUI state.
- Manage pause state via `scene.isPaused` directly.
- Treat all `SpriteView` init parameters as write-once constants.

## Texture Atlas Preloading

### Preload Requirement

All texture atlases MUST be preloaded before the first sprite is spawned. Preloading occurs during the app launch sequence (`Design-Doc.md` §7.9.2).

```swift
let atlas = SKTextureAtlas(named: "Sprites")
atlas.preload {
    // Textures decompressed and uploaded to GPU memory
}
```

For multiple atlases:

```swift
SKTextureAtlas.preloadTextureAtlases([atlas1, atlas2]) {
    // All atlases resident in GPU memory
}
```

### Atlas Organization

Textures are grouped by chapter context per `Design-Doc.md` §7.3:

| Atlas Group           | Contents                                                               | Chapter |
| --------------------- | ---------------------------------------------------------------------- | ------- |
| `Sprites.spriteatlas` | `sprite_otter_player`, `sprite_obstacle_glitch`, `sprite_heart_pickup` | Ch. 2   |
| `Sprites.spriteatlas` | `sprite_noise_particle`, `img_bubble_shield`                           | Ch. 4   |

This grouping reduces per-frame GPU texture binding. Chapter 2 requires 1 bind instead of 3. Chapter 4 requires 1 bind instead of 2.

### Texture Lifetime

Per `Design-Doc.md` §7.9.4, preloaded textures remain in the GPU texture cache for the session. Scene teardown in `willMove(from:)` removes nodes and actions but does NOT release the underlying atlas data. This is by design — zero-latency chapter transitions depend on persistent texture residency.

## Anti-Patterns (Reject)

- **Missing `willMove(from:)` override.** Every `SKScene` subclass must implement deterministic cleanup.
- **Strong `self` capture in `SKAction.run`.** Always use `[weak self]`.
- **`SKAction.perform(_:onTarget:)`.** Creates undocumented retain cycles. Use `SKAction.run` with weak capture.
- **Frame-by-frame distance checks.** Use `SKPhysicsBody` category bitmasks.
- **`Timer`, `DispatchQueue`, or `Task.sleep` for game timing.** Use `SKAction.wait(forDuration:)`.
- **Frame-count-dependent logic.** Use delta time for all movement and spawning.
- **Dynamic `SpriteView` init parameters.** Treat as write-once. Manage pause via scene property.
- **Missing texture preload.** All atlases loaded during launch sequence, never on-demand during gameplay.
- **`SKPhysicsBody(texture:size:)` without justification.** Prefer rectangle or circle bodies for performance.
- **`SKEffectNode` / `SKCropNode` nesting.** Each adds a full render pass. Never nest.
- **Node removal inside `didBegin(_:)`.** Defer to `didSimulatePhysics()` or queue for end-of-frame.

## Post-Implementation Checklist

Before declaring any `SKScene` implementation complete, verify:

- [ ] `willMove(from:)` overridden with full cleanup sequence
- [ ] `physicsWorld.contactDelegate` set to `nil` in cleanup
- [ ] All `SKAction.run` closures use `[weak self]`
- [ ] No `Timer`, `DispatchQueue`, or `Task.sleep` for game timing
- [ ] `preferredFramesPerSecond = 120` set in `didMove(to:)`
- [ ] `SpriteView` wrapper passes `preferredFramesPerSecond: 120`
- [ ] `SpriteView` wrapper uses optional scene with `.onDisappear` nil-out
- [ ] All movement uses delta time, not frame count
- [ ] Physics uses category bitmasks — no distance checks
- [ ] `contactTestBitMask` scoped to minimum required contacts
- [ ] Simple body shapes used (circle/rectangle preferred)
- [ ] Static bodies (`isDynamic = false`) for non-moving elements
- [ ] Texture atlases preloaded before scene presentation
- [ ] `#if DEBUG deinit` logger present for deallocation verification
- [ ] No `SKEffectNode` / `SKCropNode` nesting
- [ ] `update(_:)` logic stays under 4ms at 120fps
- [ ] Background sprites use `SKBlendMode.replace`
- [ ] `SpriteView` uses `.ignoresSiblingOrder` option

## Resources

- **Lifecycle Patterns**: See [references/lifecycle-patterns.md](references/lifecycle-patterns.md) for detailed scene lifecycle state machine and cleanup sequence
