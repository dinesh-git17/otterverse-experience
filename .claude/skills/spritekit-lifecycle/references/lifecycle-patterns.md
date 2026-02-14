# SpriteKit Scene Lifecycle State Machine

## Scene Lifecycle Phases

```
[Initialization] → [didMove(to:)] → [Game Loop] → [willMove(from:)] → [Deallocation]
```

### Phase 1: Initialization

Scene instance created via `init(size:)`. No access to `SKView` at this point.

- Set `scaleMode`, `anchorPoint`, `backgroundColor`.
- Do NOT configure physics, spawn nodes, or start actions here — `view` is nil.

### Phase 2: `didMove(to:)` — Scene Presented

Called once when the scene is presented by an `SKView`. Configure all runtime state here.

**Mandatory setup:**

1. `physicsWorld.contactDelegate = self`
2. `physicsWorld.gravity = CGVector(dx: 0, dy: GameConstants.gravity)`
3. `preferredFramesPerSecond = 120`
4. Spawn initial nodes
5. Start game loop actions

### Phase 3: Game Loop (Per-Frame)

SpriteKit calls the following methods in order each frame:

```
update(_:)
  → didEvaluateActions()
    → didSimulatePhysics()
      → didApplyConstraints()
        → didFinishUpdate()
          → [Render]
```

**Rules:**

- `update(_:)` — compute delta time, update game state. Budget: <4ms at 120fps.
- `didSimulatePhysics()` — safe location for deferred node removal.
- Never mutate the node tree inside `didBegin(_:)` contact callbacks.

### Phase 4: `willMove(from:)` — Scene Removal

Called when the scene is about to leave the `SKView`. Execute deterministic cleanup.

**Mandatory cleanup sequence (strict order):**

```swift
override func willMove(from view: SKView) {
    // 1. Stop all actions (breaks action-closure retain cycles)
    removeAllActions()

    // 2. Remove all child nodes (recursively cleans their actions and physics)
    removeAllChildren()

    // 3. Break physics delegate reference
    physicsWorld.contactDelegate = nil

    // 4. Nil out external references
    completionHandler = nil
}
```

### Phase 5: Deallocation

Scene is released when no strong references remain. Verify via `deinit` logging.

If `deinit` is not called, a retain cycle exists. Common causes:

1. `SKAction.run { }` closures capturing `self` strongly
2. `SKAction.perform(_:onTarget:)` creating hidden strong references
3. `SpriteView` holding the scene reference after SwiftUI view disappears
4. `physicsWorld.contactDelegate` retaining the scene

## SpriteView Integration State Machine

```
[SwiftUI View Appears]
  → [@State scene = Scene()]
    → [SpriteView(scene:)]
      → [scene.didMove(to:)]
        → [Game Loop]

[SwiftUI View Disappears]
  → [.onDisappear]
    → [scene.removeAllActions()]
    → [scene.removeAllChildren()]
    → [scene = nil]
      → [scene.willMove(from:)]
        → [scene.deinit]
```

## Physics Contact Resolution Flow

```
[Physics Simulation Step]
  → [Broad Phase: AABB overlap detection]
    → [Narrow Phase: Shape intersection test]
      → [contactTestBitMask AND check]
        → [didBegin(_:) callback if non-zero]

[Contact Callback]
  → [Read bodyA.categoryBitMask | bodyB.categoryBitMask]
    → [Switch on bitmask union]
      → [Queue state changes for didSimulatePhysics()]
```

**Node removal during contact resolution:**

```swift
private var nodesToRemove: [SKNode] = []

func didBegin(_ contact: SKPhysicsContact) {
    // Queue removal — do not call removeFromParent() here
    nodesToRemove.append(contact.bodyB.node)
}

override func didSimulatePhysics() {
    for node in nodesToRemove {
        node.physicsBody = nil
        node.removeFromParent()
    }
    nodesToRemove.removeAll()
}
```

## Delta Time Pattern

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

    // All movement uses deltaTime
    // velocity (points/sec) * deltaTime (sec) = displacement (points)
}
```

Reset `lastUpdateTime` to 0 when resuming from pause to prevent a large delta spike:

```swift
func resumeFromPause() {
    lastUpdateTime = 0
    isPaused = false
}
```

## Frame Budget Breakdown (120fps)

| Phase | Budget | Notes |
|---|---|---|
| `update(_:)` | <4ms | Game logic, delta time calculations, state updates |
| `didEvaluateActions()` | <1ms | Post-action state checks |
| Physics simulation | <1ms | Depends on dynamic body count and contact pairs |
| `didSimulatePhysics()` | <1ms | Deferred node removal, post-physics state |
| Rendering | <1.33ms | Draw calls, texture binding, compositing |
| **Total** | **<8.33ms** | Exceeding budget drops to 60fps |
