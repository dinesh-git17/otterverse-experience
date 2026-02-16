# Epic: CH2_01 — Implement Chapter 2: The Packet Run

## Metadata

| Field         | Value                          |
| ------------- | ------------------------------ |
| **Epic ID**   | CH2_01                         |
| **Epic Name** | implement_packet_run_chapter   |
| **Phase**     | PH-08                          |
| **Domain**    | CH2                            |
| **Owner**     | iOS Engineer                   |
| **Status**    | Complete                       |

---

## Problem Statement

The walking skeleton (PH-02) established `PacketRunView.swift` as a placeholder containing a "Complete Chapter" button and static title labels. This placeholder provides no gameplay experience — it lacks the SpriteKit infinite runner scene, neon grid parallax background, Otter-Dinn player character, tap-to-jump and hold-to-glide input mechanics, obstacle spawning with physics-based collision, heart collectibles with SFX feedback, and the Auto-Assist adaptive difficulty system defined in Design Doc §3.3. Without replacing this placeholder, the app cannot deliver the narrative's second chapter — the metaphor of "distance as latency" that Carolina navigates through a physically grounded runner experience.

Chapter 2 is the first SpriteKit chapter in the Starlight Sync arc. It introduces the `SKScene` ↔ `SpriteView` ↔ `FlowCoordinator` integration pattern that Chapter 4 (Firewall) will reuse. The architectural decisions made here — physics category bitmask design, delta-time movement, scene cleanup in `willMove(from:)`, optional scene nil-out in `SpriteView`, and FlowCoordinator communication via weak reference — establish the canonical SpriteKit lifecycle pattern for the project. A defect in any of these patterns propagates to PH-10 (Chapter 4) and PH-14 (Cross-Chapter Transitions).

PH-08 carries the highest risk rating in the project per `docs/PHASES.md` risk register. `SpriteView` has documented memory leak behavior when scenes are not properly deallocated on chapter transitions (Design Doc §11.5). The 120fps ProMotion rendering target (CLAUDE.md §4.3) requires `preferredFramesPerSecond = 120` configuration, the `CADisableMinimumFrameDurationOnPhone` Info.plist flag, and delta-time-based movement to prevent frame-rate-dependent game speed. Physics-based collision using category bitmasks is mandated over frame-by-frame distance checks (CLAUDE.md §4.3). All of these requirements must be satisfied in a single XL-complexity delivery.

---

## Goals

- Replace the `PacketRunView` placeholder with a production-quality SpriteKit runner experience implementing Design Doc §3.3 in its entirety: neon grid parallax background (`img_bg_runner`), Otter-Dinn player character (`sprite_otter_player`), tap-to-jump and hold-to-glide input, Lag Spike obstacle spawning (`sprite_obstacle_glitch`) with `SKPhysicsBody` category bitmask collision, heart collectibles (`sprite_heart_pickup`) with `sfx_success_chime` on pickup, dual win condition (60s survival OR 20 hearts), and Auto-Assist difficulty reduction after 3 deaths.
- Create `PacketRunScene.swift` as an `SKScene` subclass in `Chapters/Chapter2_PacketRun/` with deterministic `willMove(from:)` cleanup per CLAUDE.md §4.3: `removeAllActions()`, `removeAllChildren()`, `physicsWorld.contactDelegate = nil`, coordinator reference nil-out.
- Implement `PacketRunView.swift` as a `SpriteView` wrapper using the optional scene pattern (`@State var scene: PacketRunScene?`) with `.onDisappear` nil-out per CLAUDE.md §4.3, reporting chapter completion to `FlowCoordinator`.
- Target 120fps ProMotion rendering via `preferredFramesPerSecond = 120` in the `SpriteView` initializer and `didMove(to:)`, with all movement, spawning, and game logic bound to delta time from `update(_:)` timestamps — zero frame-count-dependent behavior per CLAUDE.md §4.3.
- Validate the SpriteKit lifecycle integration pattern (scene cleanup, memory release, coordinator communication) that PH-10 (Chapter 4 Firewall) will reuse.
- Ensure all tuning values reference `GameConstants` namespace and all asset identifiers reference type-safe enums — zero magic numbers, zero stringly-typed access.

## Non-Goals

- **No modifications to FlowCoordinator, AudioManager, HapticManager, AssetPreloadCoordinator, or GameConstants.** These components are complete (PH-02 through PH-06). PacketRunScene and PacketRunView consume their public APIs only. If an API gap is discovered, it is documented as a blocking issue, not resolved within this epic.
- **No cross-chapter transition orchestration.** The `matchedGeometryEffect` spatial transitions, BGM cross-fade between chapters, and SpriteView→SwiftUI memory cleanup sequencing are PH-14 scope. This epic verifies that PacketRunScene's `willMove(from:)` cleanup is correct; PH-14 coordinates the full transition sequence.
- **No chapter-specific haptic patterns.** Design Doc §7.6 does not define an AHAP pattern for Chapter 2. Collision and collection feedback are audio-only (`sfx_success_chime` on heart pickup). No inline `CHHapticEvent` arrays are added for jump, land, or death events unless Design Doc specifies them.
- **No custom particle effects.** Design Doc §3.3 specifies character, obstacles, and hearts as the game entity types. No death explosion particles, trail effects, or environmental particles are added beyond the assets enumerated in §7.2 and §7.3.
- **No unit tests for PacketRunScene or PacketRunView.** `SKScene` game logic is validated by on-device QA (PH-16) per Design Doc §13.1 coverage matrix. Physics behavior and frame-rate-dependent interactions cannot be reliably tested in `XCTest` without device hardware.
- **No SwiftUI overlay HUD.** Game state display (heart count, remaining time) is rendered using SpriteKit `SKLabelNode` elements within the scene to avoid additional SwiftUI↔SpriteKit state synchronization complexity. This is an explicit architectural simplification.

---

## Technical Approach

**Scene Architecture.** `PacketRunScene` is an `SKScene` subclass at `StarlightSync/Chapters/Chapter2_PacketRun/PacketRunScene.swift`. The scene uses `scaleMode = .resizeFill` to adapt to the device screen. The node hierarchy consists of four depth layers separated by `zPosition`: (1) a parallax background layer (`zPosition: -10`) composed of two side-by-side `SKSpriteNode` instances textured with `img_bg_runner` from the asset catalog, scrolling continuously leftward and looping when one tile exits the viewport — the asset is described as a "seamless texture" in Design Doc §7.2, enabling clean tiling; (2) a ground physics boundary (`zPosition: 0`) — an invisible `SKNode` with an `SKPhysicsBody(edgeFrom:to:)` positioned at an appropriate height above the scene bottom, providing the landing surface the player rests on between jumps; (3) a game entity layer (`zPosition: 1–5`) hosting the player character, obstacles, and heart pickups; and (4) a state display layer (`zPosition: 10`) with `SKLabelNode` elements showing elapsed time and collected heart count styled in neon/synthwave tones consistent with the Tron aesthetic. The scene's `didMove(to:)` configures `preferredFramesPerSecond`, sets `physicsWorld.contactDelegate = self`, configures world gravity, and initiates the background scroll and spawn timer `SKAction` sequences.

**Physics System.** Four `SKPhysicsBody` category bitmasks govern collision detection: `player` (`0x1`), `ground` (`0x2`), `obstacle` (`0x4`), and `heart` (`0x8`). The player's physics body has `categoryBitMask = player`, `collisionBitMask = ground` (physical collision with the floor only), and `contactTestBitMask = obstacle | heart` (contact notifications for game logic). Obstacles have `categoryBitMask = obstacle`, `collisionBitMask = 0` (pass-through — contact detection only, no physical deflection), `contactTestBitMask = player`. Hearts mirror this configuration with `categoryBitMask = heart`. Ground has `categoryBitMask = ground`, `collisionBitMask = player`, `isDynamic = false`. This configuration ensures the physics engine fires `didBegin(_ contact:)` callbacks only for player↔obstacle and player↔heart contacts — the two game-relevant interactions — with zero unnecessary contact pair evaluation per CLAUDE.md §4.3.

**Input Handling and Movement.** Player input uses the `SKScene` touch lifecycle. `touchesBegan(_:with:)` applies an upward impulse to the player physics body for jump and sets an `isTouching` flag. A `canJump` boolean prevents mid-air double jumps — set to `true` only when the player contacts the ground (detected via `didBegin(_ contact:)` with ground bitmask), set to `false` immediately on jump. `touchesEnded(_:with:)` and `touchesCancelled(_:with:)` clear the `isTouching` flag. The hold-to-glide mechanic operates in `update(_:)`: when `isTouching` is `true` and the player is airborne, the player's downward velocity is capped to a `glideTerminalVelocity` threshold, simulating a float with reduced fall speed. All movement values are inherently frame-rate independent: jump impulse uses the physics engine (time-integrated by SpriteKit), obstacle scroll uses `SKAction` durations (time-based), and glide capping operates on velocity magnitude (physics-domain, not pixel-per-frame). Delta time is computed as `currentTime - lastUpdateTime` in `update(_:)` for elapsed game timer tracking, with a first-frame guard to avoid a large initial delta.

**Spawning and Death/Respawn.** Obstacles and hearts spawn off-screen right and move leftward via `SKAction.moveBy(x:y:duration:)` sequences. Spawn timing uses `SKAction.wait(forDuration:withRange:)` in a `repeatForever` sequence — no `Timer`, `DispatchQueue`, or `Task.sleep` per CLAUDE.md §4.3. On player↔obstacle contact, the game transitions to a death state: a brief visual feedback fires (player alpha flash via `SKAction.fadeAlpha` sequence), then after ~0.5s (`SKAction.wait`), the scene internally resets — all obstacle and heart nodes are removed, the player repositions to start, `elapsedTime` and `heartsCollected` reset, and `deathCount` increments. The scene itself is NOT recreated; internal state resets and spawn timers re-engage. `deathCount` persists across attempts. On win (either timer or heart condition met), spawning stops, a brief victory pause plays via `SKAction.wait`, and `coordinator?.completeCurrentChapter()` fires exactly once, guarded by a `GameState` enum preventing double-fire.

**SpriteView Integration.** `PacketRunView` replaces the PH-02 placeholder. The view holds the scene as `@State private var scene: PacketRunScene?` — the optional pattern per CLAUDE.md §4.3. On `.onAppear`, the scene is created, configured with `scaleMode = .resizeFill`, and assigned a `weak var coordinator: FlowCoordinator?` reference. `SpriteView` is initialized with `preferredFramesPerSecond: GameConstants.Physics.targetFrameRate` and `options: [.ignoresSiblingOrder]` for optimal draw call batching. On `.onDisappear`, the scene reference is set to `nil`, triggering scene deallocation and `willMove(from:)` cleanup. The `CADisableMinimumFrameDurationOnPhone` Info.plist flag must be present for 120fps to activate on iPhone ProMotion hardware — without it, iOS caps third-party apps at 60fps regardless of the `preferredFramesPerSecond` setting.

---

## Dependencies

### Inbound (Blocks This Epic)

| Dependency | Source | Status | Owner |
| --- | --- | --- | --- |
| `FlowCoordinator` with `completeCurrentChapter()` API and `@Environment` injection | COORD_01, COORD_02 (PH-02) | Complete | iOS Engineer |
| `GameConstants.Timing.runnerDuration` (60.0s), `GameConstants.Physics.runnerHeartTarget` (20), `GameConstants.Physics.targetFrameRate` (120), `GameConstants.AutoAssist.runnerDeathThreshold` (3), `GameConstants.Difficulty.runnerSpeedReduction` (0.20), `GameConstants.Difficulty.runnerGapIncrease` (0.20) | CONST_01 (PH-06) | Complete | iOS Engineer |
| `GameConstants.SpriteAsset.otterPlayer`, `.obstacleGlitch`, `.heartPickup`, `GameConstants.SpriteAtlas.sprites`, `GameConstants.BackgroundAsset.runner` | CONST_01 (PH-06) | Complete | iOS Engineer |
| `GameConstants.AudioAsset.sfxChime` (`sfx_success_chime`) | CONST_01 (PH-06) | Complete | iOS Engineer |
| `AudioManager.shared.playSFX(named:)` API with preloaded `sfx_success_chime` asset | AUDIO_01 (PH-03), ASSET_03 (PH-05) | Complete | iOS Engineer |
| `img_bg_runner` HEIC background in `Assets.xcassets/Backgrounds/`, sprite textures (`sprite_otter_player`, `sprite_obstacle_glitch`, `sprite_heart_pickup`) in `Assets.xcassets/Sprites.spriteatlas/` | ASSET_01 (PH-05) | Complete | iOS Engineer |
| `AssetPreloadCoordinator` with sprite atlas preloaded via `SKTextureAtlas.preload()` — textures resident in GPU cache before Chapter 2 begins | ASSET_02 (PH-05) | Complete | iOS Engineer |
| Chapter 1 (PH-07) complete — runtime prerequisite for sequential navigation to Chapter 2 via FlowCoordinator linear state machine | CH1_01 (PH-07) | Complete | iOS Engineer |

### Outbound (This Epic Unblocks)

| Dependency | Target | Description |
| --- | --- | --- |
| SpriteKit lifecycle pattern validated — `willMove(from:)` cleanup, optional scene nil-out, weak coordinator reference, 120fps configuration | PH-10 (Chapter 4 Firewall) | Chapter 4 reuses the identical SKScene ↔ SpriteView ↔ FlowCoordinator pattern established here |
| Chapter 2 complete — sequential chapter progression continues | PH-09 (Chapter 3 Cipher) | Chapter 3 is unlocked when Chapter 2 completes via FlowCoordinator |
| SpriteView memory cleanup verified — no retained SKScene references after chapter transition | PH-14 (Cross-Chapter Transitions) | Cross-chapter transition polish depends on confirmed clean SpriteKit deallocation |
| Chapter 2 playable for on-device validation | PH-16 (On-Device QA) | QA playtest validates runner feel, Auto-Assist activation, 120fps rendering, input responsiveness, and obstacle fairness |

---

## Stories

### Story 1: Create PacketRunScene with neon grid background and parallax scrolling

Create `PacketRunScene.swift` as an `SKScene` subclass with the neon grid parallax background layer. Two tiled instances of `img_bg_runner` scroll continuously leftward, looping seamlessly when one tile exits the viewport. The scene configures 120fps rendering, physics world gravity, the ground physics boundary, and the delta-time computation in `update(_:)`.

**Acceptance Criteria:**

- [ ] File created at `StarlightSync/Chapters/Chapter2_PacketRun/PacketRunScene.swift`.
- [ ] `PacketRunScene` is a `final class` subclass of `SKScene`, conforming to `SKPhysicsContactDelegate`.
- [ ] `didMove(to:)` sets `self.view?.preferredFramesPerSecond = GameConstants.Physics.targetFrameRate`.
- [ ] `physicsWorld.gravity` is set to a downward vector (e.g., `CGVector(dx: 0, dy: -9.8)` or a tuned value defined as a scene-internal named constant).
- [ ] `physicsWorld.contactDelegate = self` is set in `didMove(to:)`.
- [ ] Background parallax layer: two `SKSpriteNode` instances textured with `GameConstants.BackgroundAsset.runner.rawValue` positioned side-by-side horizontally, scrolling continuously leftward via `SKAction.moveBy` in a `repeatForever` sequence.
- [ ] When the leading background tile scrolls fully off-screen left, it repositions to the right edge of the trailing tile — creating an infinite seamless loop.
- [ ] Background nodes have `zPosition` lower than game entity nodes (e.g., `-10`).
- [ ] An invisible ground `SKNode` with `SKPhysicsBody(edgeFrom:to:)` spans the bottom of the scene at an appropriate height. Ground body: `categoryBitMask = groundCategory`, `collisionBitMask = playerCategory`, `isDynamic = false`.
- [ ] `update(_:)` method computes delta time: `let deltaTime = currentTime - lastUpdateTime; lastUpdateTime = currentTime`, guarding against the first-frame zero-delta case.
- [ ] All scroll speed values are named constants (not magic numbers).
- [ ] No `Timer`, `DispatchQueue`, or `Task.sleep` for any timing.

**Dependencies:** None
**Completion Signal:** PacketRunScene renders a continuously scrolling neon grid background at 120fps with a visible ground boundary. No player, obstacles, or hearts yet.

---

### Story 2: Implement player character with tap-to-jump and hold-to-glide physics

Add the Otter-Dinn player sprite with a physics body. Implement tap-to-jump via upward impulse on `touchesBegan` with single-jump enforcement via ground contact detection. Implement hold-to-glide by capping downward velocity while the touch is held during airborne state.

**Acceptance Criteria:**

- [ ] Player `SKSpriteNode` created with texture from `GameConstants.SpriteAsset.otterPlayer.rawValue` via the preloaded `SKTextureAtlas` (`GameConstants.SpriteAtlas.sprites.rawValue`).
- [ ] Player node positioned at a fixed horizontal position in the left third of the screen, vertically resting on the ground boundary.
- [ ] Player has `SKPhysicsBody(rectangleOf:)` sized appropriately to the sprite.
- [ ] Player physics body: `categoryBitMask = playerCategory`, `collisionBitMask = groundCategory`, `contactTestBitMask = obstacleCategory | heartCategory`.
- [ ] Player physics body: `allowsRotation = false`, `restitution = 0`.
- [ ] `touchesBegan(_:with:)` applies an upward impulse (`applyImpulse(CGVector(dx: 0, dy: jumpImpulse))`) only when `canJump` is `true`.
- [ ] `canJump` is set to `false` immediately after impulse is applied. `canJump` is set to `true` in `didBegin(_ contact:)` when the player contacts the ground (detected via category bitmask comparison).
- [ ] `touchesBegan` sets `isTouching = true`. `touchesEnded` and `touchesCancelled` set `isTouching = false`.
- [ ] In `update(_:)`, when `isTouching` is `true` and `canJump` is `false` (airborne), the player's downward velocity is capped: `physicsBody?.velocity.dy = max(velocity.dy, -glideTerminalVelocity)`, simulating a glide with reduced fall speed.
- [ ] Jump impulse and glide terminal velocity are named constants (not magic numbers).
- [ ] Player cannot jump while airborne (no double-jump).
- [ ] Player sprite has `zPosition` above background, below state display labels.
- [ ] No frame-count-dependent movement. Jump uses physics engine impulse (frame-rate independent). Glide operates on velocity magnitude.
- [ ] `[weak self]` used in any `SKAction.run` closures referencing the scene.

**Dependencies:** CH2_01-S1 (scene with ground boundary must exist)
**Completion Signal:** Otter-Dinn sprite renders on the ground. Tapping causes a jump with single-jump enforcement. Holding during descent causes a visibly slower fall (glide). Releasing touch restores normal gravity descent.

---

### Story 3: Implement obstacle spawning with physics-based collision and death handling

Spawn "Lag Spike" obstacles (`sprite_obstacle_glitch`) off-screen right at timed intervals. Obstacles move leftward and are removed when off-screen. Collision between player and obstacle triggers death — a brief visual feedback fires, then the scene resets for a new attempt with the death counter incremented. Timer and heart count reset on death; death count persists across attempts.

**Acceptance Criteria:**

- [ ] Obstacles are `SKSpriteNode` instances textured with `GameConstants.SpriteAsset.obstacleGlitch.rawValue` from the preloaded sprite atlas.
- [ ] Obstacles spawn at the right edge of the scene (off-screen) at randomized vertical positions within the playable area above the ground boundary.
- [ ] Obstacle spawning uses `SKAction.sequence([.wait(forDuration:, withRange:), .run { [weak self] in self?.spawnObstacle() }])` wrapped in `repeatForever`. No `Timer`, `DispatchQueue`, or `Task.sleep`.
- [ ] Obstacles move leftward via `SKAction.moveBy(x:y:duration:)` calculated from current scroll speed, followed by `removeFromParent()`.
- [ ] Obstacle physics body: `categoryBitMask = obstacleCategory`, `collisionBitMask = 0` (no physical push), `contactTestBitMask = playerCategory`.
- [ ] Obstacle physics body: `isDynamic = false`, `affectedByGravity = false`.
- [ ] `didBegin(_ contact:)` detects player↔obstacle contact via category bitmask comparison — not by node name string matching, not by frame-by-frame distance check.
- [ ] On player↔obstacle contact: game state transitions to `.death`. A brief visual feedback fires (e.g., player alpha flash via `SKAction.sequence([.fadeAlpha(to:duration:), .fadeAlpha(to:duration:)])`) — not a `Timer` or `DispatchQueue` delay.
- [ ] After the death feedback (~0.5s via `SKAction.wait(forDuration:)`), the scene internally resets: all obstacle and heart nodes are removed, player repositions to start, `elapsedTime` resets to 0, `heartsCollected` resets to 0, `deathCount` increments by 1.
- [ ] Scene reset does NOT recreate the `SKScene` instance — it resets internal game state and re-engages spawn timer `SKAction` sequences.
- [ ] `deathCount` persists across attempts within the same chapter session (NOT reset on scene reset).
- [ ] Obstacles that move fully off-screen left are removed via `removeFromParent()` to prevent unbounded node accumulation.
- [ ] Spawn interval and obstacle scroll speed are named constants (not magic numbers).
- [ ] No `SKAction.perform(_:onTarget:)`.
- [ ] All `SKAction.run` closures use `[weak self]`.

**Dependencies:** CH2_01-S2 (player with physics body must exist for collision)
**Completion Signal:** Lag Spike obstacles spawn from the right edge, scroll leftward, and disappear off-screen. Colliding with an obstacle causes a brief visual flash, then the scene resets with the death counter incremented. Player can attempt again immediately.

---

### Story 4: Implement heart collectible spawning with SFX pickup feedback

Spawn heart collectibles (`sprite_heart_pickup`) at randomized intervals between obstacles. On player↔heart contact, increment the heart counter, remove the heart from the scene, and play `sfx_success_chime` via `AudioManager`.

**Acceptance Criteria:**

- [ ] Hearts are `SKSpriteNode` instances textured with `GameConstants.SpriteAsset.heartPickup.rawValue` from the preloaded sprite atlas.
- [ ] Hearts spawn at the right edge of the scene at randomized vertical positions, offset from obstacle spawn logic to prevent spatial overlap with active obstacles.
- [ ] Heart spawning uses `SKAction.sequence([.wait(forDuration:, withRange:), .run { [weak self] in self?.spawnHeart() }])` wrapped in `repeatForever`. No `Timer`, `DispatchQueue`, or `Task.sleep`.
- [ ] Hearts move leftward at the same base scroll speed as obstacles (paralleling the game world movement).
- [ ] Heart physics body: `categoryBitMask = heartCategory`, `collisionBitMask = 0`, `contactTestBitMask = playerCategory`.
- [ ] Heart physics body: `isDynamic = false`, `affectedByGravity = false`.
- [ ] `didBegin(_ contact:)` detects player↔heart contact via category bitmask comparison.
- [ ] On player↔heart contact: `heartsCollected` increments by 1, the heart node is removed via `removeFromParent()`, and `AudioManager.shared.playSFX(named: GameConstants.AudioAsset.sfxChime.rawValue)` is called.
- [ ] If `AudioManager` fails to play the SFX, collection still succeeds — audio failure does not block gameplay per CLAUDE.md §4.5.
- [ ] Heart count label (`SKLabelNode`) updates to reflect the new `heartsCollected` value.
- [ ] Hearts that move fully off-screen left without collection are removed via `removeFromParent()`.
- [ ] No direct `AVAudioPlayer` access from PacketRunScene — all SFX routes through `AudioManager` per CLAUDE.md §4.5.
- [ ] All `SKAction.run` closures use `[weak self]`.

**Dependencies:** CH2_01-S2 (player must exist for collection), CH2_01-S3 (obstacle spawning establishes the spawn/scroll pattern reused here)
**Completion Signal:** Hearts spawn between obstacles, scroll leftward, and can be collected by the player. Collection removes the heart, increments the visible counter, and plays the chime SFX. Uncollected hearts disappear off-screen.

---

### Story 5: Implement game timer, dual win condition evaluation, and chapter completion

Add a game timer that tracks elapsed seconds using delta time in `update(_:)`. Evaluate both win conditions each frame: survive `GameConstants.Timing.runnerDuration` (60s) OR collect `GameConstants.Physics.runnerHeartTarget` (20) hearts. On either condition met, stop gameplay and report chapter completion to `FlowCoordinator`.

**Acceptance Criteria:**

- [ ] `elapsedTime: TimeInterval` accumulates delta time in `update(_:)` while the game state is `.playing`.
- [ ] An `SKLabelNode` displays remaining time (e.g., `String(format: "%.0f", max(0, GameConstants.Timing.runnerDuration - elapsedTime))`) at a fixed position in the upper region of the scene (`zPosition: 10`).
- [ ] An `SKLabelNode` displays hearts collected (e.g., formatted as current/target) at a fixed position in the upper region of the scene (`zPosition: 10`).
- [ ] Label nodes use chapter-appropriate font and color styling consistent with the neon/synthwave Tron aesthetic (Design Doc §3.3) — not default white `SKLabelNode` styling, not system colors.
- [ ] Win condition check runs each frame in `update(_:)`: if `elapsedTime >= GameConstants.Timing.runnerDuration` OR `heartsCollected >= GameConstants.Physics.runnerHeartTarget`, transition game state to `.won`.
- [ ] On win: all spawn timer actions are stopped (on the spawn timer action nodes, not `removeAllActions()` on the entire scene), game state transitions to `.won`, and after a brief victory pause (`SKAction.wait(forDuration:)` followed by `SKAction.run { [weak self] in self?.coordinator?.completeCurrentChapter() }`), the coordinator advances to Chapter 3.
- [ ] `completeCurrentChapter()` is called exactly once per win. The `.won` state guard prevents double-fire on subsequent `update(_:)` frames.
- [ ] Game state is tracked via `private enum GameState { case playing, death, won }`. The `update(_:)` timer accumulation, spawning, and input handling are gated on `.playing` state.
- [ ] Timer does not accumulate during the `.death` state (pause during scene reset feedback).
- [ ] `elapsedTime` and `heartsCollected` reset to 0 on death (each attempt is a fresh run toward either win condition).
- [ ] No `Timer`, `DispatchQueue.asyncAfter`, or `Task.sleep` for the victory pause or any timing.
- [ ] `[weak self]` in all `SKAction.run` closures.

**Dependencies:** CH2_01-S3 (death handling provides the `.death` state), CH2_01-S4 (heart collection provides `heartsCollected`)
**Completion Signal:** Game timer counts remaining seconds from 60. Reaching 0s remaining or collecting 20 hearts triggers a win state. FlowCoordinator advances to Chapter 3 after a brief victory pause. Timer pauses during death reset. Each attempt is a fresh run.

---

### Story 6: Implement Auto-Assist difficulty reduction after repeated failures

Track death count across attempts. After `GameConstants.AutoAssist.runnerDeathThreshold` (3) deaths, reduce obstacle scroll speed by `GameConstants.Difficulty.runnerSpeedReduction` (20%) and increase spawn gap between obstacles by `GameConstants.Difficulty.runnerGapIncrease` (20%). The difficulty reduction is silent and persists for the remainder of the chapter session.

**Acceptance Criteria:**

- [ ] `deathCount: Int` is a scene property that increments on each death and persists across scene resets (NOT reset when the game restarts after death).
- [ ] `isAutoAssistActive: Bool` is computed as `deathCount >= GameConstants.AutoAssist.runnerDeathThreshold`.
- [ ] When `isAutoAssistActive` is `true`, the obstacle scroll speed is multiplied by `(1.0 - GameConstants.Difficulty.runnerSpeedReduction)` — effectively 0.8× speed. This is applied when calculating `SKAction.moveBy` duration for newly spawned obstacles.
- [ ] When `isAutoAssistActive` is `true`, the spawn interval between consecutive obstacles is multiplied by `(1.0 + GameConstants.Difficulty.runnerGapIncrease)` — effectively 1.2× gap, giving the player more reaction time between obstacles.
- [ ] Auto-Assist activates on the attempt immediately following the 3rd death (the 4th attempt runs with reduced difficulty).
- [ ] Auto-Assist activation is silent — no UI notification, no visual indicator, no text overlay. The difficulty eases transparently, preserving the "illusion of skill and success" per Design Doc §3.8.
- [ ] Auto-Assist does not reset if the player dies again after activation. Once active, it remains active for the session.
- [ ] Auto-Assist modifiers apply to newly spawned obstacles only — obstacles already in-flight when Auto-Assist activates are not retroactively modified.
- [ ] All threshold and modifier values are sourced from `GameConstants` — zero hardcoded numbers for Auto-Assist logic.

**Dependencies:** CH2_01-S3 (death handling provides `deathCount`), CH2_01-S5 (spawn timing and scroll speed affected by Auto-Assist modifiers)
**Completion Signal:** After dying 3 times, the 4th attempt visibly exhibits slower-moving obstacles with wider spacing. The reduced difficulty makes survival meaningfully easier without any on-screen notification of the change.

---

### Story 7: Implement PacketRunView SpriteView wrapper with lifecycle management

Replace the `PacketRunView` placeholder with a `SpriteView` wrapper that creates and manages the `PacketRunScene` lifecycle. Use the optional scene pattern (`@State var scene: PacketRunScene?`) with `.onDisappear` nil-out. Wire `FlowCoordinator` communication via weak reference injection. Configure `SpriteView` for 120fps ProMotion rendering with draw call optimization.

**Acceptance Criteria:**

- [ ] `PacketRunView.swift` body is replaced entirely — the placeholder `ZStack` with `Color.black`, `Text` labels, and `Button` are removed.
- [ ] `@State private var scene: PacketRunScene?` holds the scene as an optional.
- [ ] `@Environment(FlowCoordinator.self) private var coordinator` reads the coordinator from the SwiftUI environment.
- [ ] On `.onAppear`: a new `PacketRunScene` is created with `size` derived from the screen bounds, `scaleMode` set to `.resizeFill`, and the coordinator assigned via a `weak var coordinator: FlowCoordinator?` property on the scene.
- [ ] `SpriteView` is initialized with `preferredFramesPerSecond: GameConstants.Physics.targetFrameRate` and `options: [.ignoresSiblingOrder]`.
- [ ] The view body uses `Group` or `if let scene` to conditionally render `SpriteView` only when the scene is non-nil. No force unwraps on the optional scene.
- [ ] On `.onDisappear`: `scene = nil`. Scene deallocation triggers `willMove(from:)` cleanup.
- [ ] `CADisableMinimumFrameDurationOnPhone` key is present in `Info.plist` with value `true`. If absent, this story adds it.
- [ ] `#Preview` macro is present with a functioning preview that provides a `FlowCoordinator` environment object.
- [ ] View body does not exceed 80 lines.
- [ ] No `ObservableObject`, `@Published`, `@StateObject`, `@EnvironmentObject`, or Combine usage.
- [ ] No UIKit imports (`UIViewController`, `UIView`, `UIHostingController`).

**Dependencies:** CH2_01-S1 through CH2_01-S6 (complete scene implementation)
**Completion Signal:** PacketRunView renders a playable SpriteKit runner scene via SpriteView at 120fps. The scene is created on appear, plays the full game loop, and is set to nil on disappear. FlowCoordinator advances to Chapter 3 on win. No SpriteView memory retention after transition.

---

### Story 8: Register source files in pbxproj, implement willMove(from:) cleanup, and validate governance compliance

Register the new `PacketRunScene.swift` in `project.pbxproj`. Implement deterministic `willMove(from:)` cleanup in `PacketRunScene` per CLAUDE.md §4.3. Validate that the full Chapter 2 implementation passes all build and governance checks.

**Acceptance Criteria:**

- [ ] `PacketRunScene.swift` has a `PBXFileReference` entry in `project.pbxproj` (FileRef 13: `B7D1E38A2D5F6A0100000013`).
- [ ] A `PBXBuildFile` entry references the `PacketRunScene.swift` file reference (BuildFile 12: `B7D1E38A2D5F6A0100000112`).
- [ ] The file reference is listed in the `Chapter2_PacketRun` `PBXGroup` children array.
- [ ] The build file is listed in the `PBXSourcesBuildPhase` files array.
- [ ] `PacketRunView.swift` already has pbxproj registration from COORD_02 — no new registration needed for the modified file.
- [ ] `PacketRunScene.willMove(from:)` implements deterministic cleanup in strict order per CLAUDE.md §4.3:
  1. `removeAllActions()`
  2. `removeAllChildren()`
  3. `physicsWorld.contactDelegate = nil`
  4. `coordinator = nil` (nil-out external weak reference)
- [ ] `xcodebuild build -project StarlightSync.xcodeproj -scheme StarlightSync -destination 'generic/platform=iOS Simulator'` exits with code 0, zero errors, zero warnings (excluding benign `appintentsmetadataprocessor` warning).
- [ ] `python3 scripts/audit.py --all` passes with zero violations (7/7 checks: PZ-001, FU-001, DA-001, DP-001, SL-001, CC-001, CB-001).
- [ ] No Protocol Zero violations in either file — no AI attribution in headers, comments, or identifiers.
- [ ] No force unwraps (`!`) except the guarded `SpriteView(scene:)` initializer path.
- [ ] No `print` statements. Diagnostics use `os.Logger` gated behind `#if DEBUG` if needed.
- [ ] No Combine imports or `ObservableObject` / `@Published` / `@StateObject` / `@EnvironmentObject` usage.
- [ ] No deprecated APIs.
- [ ] No `SKAction.perform(_:onTarget:)` calls anywhere in `PacketRunScene`.
- [ ] All `SKAction.run` closures use `[weak self]`.
- [ ] All timing uses `SKAction.wait(forDuration:)` or delta time — no `Timer`, `DispatchQueue`, `Task.sleep`.
- [ ] All asset references use `GameConstants` type-safe enums — zero string literals for asset identifiers.
- [ ] All tuning values are named constants — zero magic numbers.
- [ ] `#Preview` macro present on `PacketRunView`.
- [ ] `PacketRunView` body ≤80 lines.

**Dependencies:** CH2_01-S1 through CH2_01-S7 (all implementation stories complete)
**Completion Signal:** Clean build with zero errors. Audit passes 7/7. PacketRunScene registered in all 4 pbxproj sections. `willMove(from:)` cleanup implements the deterministic 4-step teardown. All governance rules satisfied. PH-08 is ready for on-device validation.

---

## Risks

| Risk | Impact (1-5) | Likelihood (1-5) | Score | Mitigation | Owner |
| --- | :---: | :---: | :---: | --- | --- |
| `SpriteView` retains `SKScene` reference after `.onDisappear`, causing memory leak on chapter transition (Design Doc §11.5) | 5 | 3 | 15 | Use optional scene pattern: `@State var scene: PacketRunScene?` set to `nil` in `.onDisappear`. Implement `willMove(from:)` deterministic cleanup as secondary defense. Verify deallocation with Instruments Allocations trace during PH-16. If leak persists, force recreation via `.id()` modifier on the `SpriteView`. | iOS Engineer |
| Game speed varies between 60fps and 120fps devices due to frame-rate-dependent movement | 4 | 3 | 12 | All movement uses frame-rate-independent mechanisms: jump uses physics engine impulse (time-integrated by SpriteKit), obstacle scroll uses `SKAction` durations (time-based), glide operates on velocity magnitude. Elapsed timer uses delta time. Validate by toggling `preferredFramesPerSecond` between 60 and 120 during development to confirm identical game behavior at different frame rates. | iOS Engineer |
| Physics collision detection misses fast-moving small sprites at 120fps (tunneling) | 3 | 2 | 6 | SpriteKit uses swept collision by default. Enable `usesPreciseCollisionDetection = true` on the player body if edge cases occur. Obstacle and heart physics bodies are non-dynamic (positioned via `SKAction`), eliminating tunneling risk on those nodes. Validate with high scroll speeds during PH-16 tuning. | iOS Engineer |
| Obstacle spawn timing feels unfair or hearts spawn too rarely, making the 60s/20-heart win conditions unachievable on first attempt | 3 | 3 | 9 | All spawn intervals and scroll speeds are named constants, trivially tunable during PH-16 QA. Auto-Assist activates after 3 deaths, ensuring eventual completion. Initial spawn values should be conservative (generous gaps, frequent hearts) — tighten during on-device tuning. | iOS Engineer |
| `SKTextureAtlas` texture lookup returns nil for sprites if atlas was not preloaded by `AssetPreloadCoordinator` | 4 | 1 | 4 | ASSET_02 (PH-05) preloads all sprite atlas textures during the launch sequence, completed well within the Chapter 1 interaction window. Atlas textures are retained for the session per Design Doc §7.9.4. Texture lookup uses `SKTextureAtlas(named:).textureNamed(:)` which returns a placeholder texture rather than crashing if the atlas is missing. | iOS Engineer |
| Background parallax tiling produces a visible seam due to sub-pixel positioning | 2 | 2 | 4 | Use `round()` on background reposition calculations to avoid fractional pixel gaps. Set `SKSpriteNode.texture?.filteringMode = .nearest` if aliasing artifacts appear at tile boundaries. The `img_bg_runner` asset is authored as a "seamless texture" per Design Doc §7.2. | iOS Engineer |

---

## Definition of Done

- [ ] All 8 stories completed and individually verified.
- [ ] `PacketRunScene.swift` created at `Chapters/Chapter2_PacketRun/PacketRunScene.swift` with full runner game implementation per Design Doc §3.3.
- [ ] `PacketRunView.swift` replaces the PH-02 placeholder with `SpriteView` wrapper and optional scene pattern.
- [ ] Neon grid parallax background (`img_bg_runner`) scrolls continuously and tiles seamlessly.
- [ ] Otter-Dinn player character (`sprite_otter_player`) jumps on tap and glides on hold.
- [ ] Lag Spike obstacles (`sprite_obstacle_glitch`) spawn, scroll leftward, and trigger death on player collision.
- [ ] Heart collectibles (`sprite_heart_pickup`) spawn, scroll leftward, and trigger `sfx_success_chime` on pickup via `AudioManager`.
- [ ] Collision detection uses `SKPhysicsBody` category bitmasks — no frame-by-frame distance checks.
- [ ] Win condition: survive 60s (`GameConstants.Timing.runnerDuration`) OR collect 20 hearts (`GameConstants.Physics.runnerHeartTarget`).
- [ ] Auto-Assist: after 3 deaths (`GameConstants.AutoAssist.runnerDeathThreshold`), obstacle speed ×0.8, spawn gap ×1.2.
- [ ] Auto-Assist activation is silent — no player notification, preserving the illusion of skill.
- [ ] `FlowCoordinator.completeCurrentChapter()` advances to Chapter 3 on win, called exactly once.
- [ ] `willMove(from:)` implements deterministic cleanup: `removeAllActions()`, `removeAllChildren()`, `physicsWorld.contactDelegate = nil`, coordinator nil-out.
- [ ] `SpriteView` uses optional scene pattern with `.onDisappear` nil-out.
- [ ] `preferredFramesPerSecond = 120` configured in both `SpriteView` initializer and `didMove(to:)`.
- [ ] `CADisableMinimumFrameDurationOnPhone = true` present in `Info.plist`.
- [ ] All movement uses delta time from `update(_:)` or `SKAction` durations — no frame-count-dependent logic.
- [ ] All timing uses `SKAction.wait(forDuration:)` — no `Timer`, `DispatchQueue`, `Task.sleep`.
- [ ] All `SKAction.run` closures use `[weak self]`. No `SKAction.perform(_:onTarget:)`.
- [ ] All asset references use `GameConstants` type-safe enums — zero string literals for asset identifiers.
- [ ] All tuning values are named constants — zero magic numbers.
- [ ] `xcodebuild build` succeeds with zero errors and zero warnings.
- [ ] `scripts/audit.py --all` passes with zero violations (7/7 checks).
- [ ] No Protocol Zero violations.
- [ ] No force unwraps (except guarded `SpriteView` init), no `print` statements, no Combine, no deprecated APIs.
- [ ] `#Preview` macro present on `PacketRunView`.
- [ ] `PacketRunView` body ≤80 lines.
- [ ] `PacketRunScene.swift` registered in all 4 required `project.pbxproj` sections.

## Exit Criteria

- [ ] All Definition of Done conditions satisfied.
- [ ] PH-09 (Chapter 3) is unblocked — Chapter 2 completes and FlowCoordinator advances to Chapter 3.
- [ ] PH-10 (Chapter 4) is unblocked — SpriteKit lifecycle pattern (`willMove(from:)` cleanup, optional scene nil-out, weak coordinator reference, 120fps configuration) validated and documented as the canonical pattern for reuse.
- [ ] PH-14 (Cross-Chapter Transitions) is unblocked — SpriteView memory cleanup verified, no retained SKScene references after chapter transition.
- [ ] PH-16 (On-Device QA) can begin Chapter 2 testing — runner feel, Auto-Assist activation, 120fps rendering, input responsiveness, obstacle fairness, heart collection feedback.
- [ ] Epic ID `CH2_01` recorded in `.claude/context/progress/active.md` upon start and `.claude/context/progress/completed.md` upon completion.
